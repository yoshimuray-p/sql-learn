# 第4回: トランザクションと性能 (Transactions & Performance)

---

## 1. ACID特性 (ACID Properties)

トランザクションが満たすべき4つの性質:

| 性質 | 意味 | 具体例 |
|------|------|--------|
| **原子性 (Atomicity)** | 全操作が成功するか、全て取り消されるか | 銀行振込: 出金と入金が両方成功するか、両方取り消される |
| **一貫性 (Consistency)** | トランザクション前後でDB制約が保たれる | 残高が負にならない CHECK 制約が常に満たされる |
| **分離性 (Isolation)** | 同時実行中のトランザクションが互いに干渉しない | 2人が同時に同じ口座から引き出しても正しい残高になる |
| **永続性 (Durability)** | COMMIT後のデータは障害があっても失われない | COMMIT後にサーバがクラッシュしてもデータは残る |

---

## 2. トランザクション制御 (Transaction Control)

### 基本構文

```sql
BEGIN;  -- トランザクション開始（START TRANSACTION も可）

UPDATE accounts SET balance = balance - 1000 WHERE id = 1;
UPDATE accounts SET balance = balance + 1000 WHERE id = 2;

COMMIT;  -- 確定
```

失敗時は `ROLLBACK` で全変更を取り消す:

```sql
BEGIN;
UPDATE accounts SET balance = balance - 1000 WHERE id = 1;
-- エラー発生を検知
ROLLBACK;  -- 全変更を取り消し
```

### SAVEPOINT

トランザクション内に部分的な復帰点を作る:

```sql
BEGIN;
INSERT INTO orders (customer_id, total) VALUES (1, 5000);
SAVEPOINT sp1;

INSERT INTO order_items (order_id, product_id, qty) VALUES (1, 99, 1);
-- product_id = 99 が存在しない → FK違反
ROLLBACK TO sp1;  -- sp1 の時点に戻る（orders の INSERT は残る）

INSERT INTO order_items (order_id, product_id, qty) VALUES (1, 10, 1);
COMMIT;
```

> **注意**: PostgreSQL ではトランザクション内でエラーが発生すると、`ROLLBACK TO savepoint` しない限りそのトランザクション内の以降のコマンドは全て失敗する。これは他のDBMSと異なる挙動。

---

## 3. 分離レベル (Isolation Levels)

### 同時実行で起こりうる問題

| 現象 | 説明 |
|------|------|
| **ダーティリード (Dirty Read)** | 他のトランザクションの未コミットデータが見える |
| **ノンリピータブルリード (Non-Repeatable Read)** | 同じ行を2回読むと値が変わっている |
| **ファントムリード (Phantom Read)** | 同じ条件で検索すると行数が変わっている |
| **直列化異常 (Serialization Anomaly)** | 並行実行の結果がどの直列実行とも一致しない |

### PostgreSQLの分離レベル

```sql
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;  -- デフォルト
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
```

| 分離レベル | Dirty Read | Non-Repeatable Read | Phantom Read | Serialization Anomaly |
|------------|-----------|--------------------|--------------|-----------------------|
| READ UNCOMMITTED* | 発生しない | 発生する | 発生する | 発生する |
| **READ COMMITTED** | 発生しない | 発生する | 発生する | 発生する |
| REPEATABLE READ | 発生しない | 発生しない | 発生しない** | 発生する |
| SERIALIZABLE | 発生しない | 発生しない | 発生しない | 発生しない |

\* PostgreSQLでは READ UNCOMMITTED を指定しても READ COMMITTED として動作する（MVCCにより Dirty Read は原理的に発生しない）。

\** SQL標準ではファントムリードが許容されるが、PostgreSQLの REPEATABLE READ 実装ではファントムリードも防止される。

### 具体例: Non-Repeatable Read (READ COMMITTED)

```
TX1                                 TX2
BEGIN;
SELECT balance FROM accounts
  WHERE id = 1;
-- → 10000
                                    BEGIN;
                                    UPDATE accounts SET balance = 5000
                                      WHERE id = 1;
                                    COMMIT;
SELECT balance FROM accounts
  WHERE id = 1;
-- → 5000 (値が変わっている！)
COMMIT;
```

REPEATABLE READ ではTX1開始時のスナップショットが使われるため、2回目の読み取りでも `10000` が返る。

### 具体例: Serialization Anomaly

```
-- テーブル: summary (category, total), items (category, amount)
TX1                                 TX2
BEGIN ISOLATION LEVEL SERIALIZABLE; BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT sum(amount) FROM items
  WHERE category = 'A';
-- → 100
                                    SELECT sum(amount) FROM items
                                      WHERE category = 'B';
                                    -- → 200
INSERT INTO summary
  VALUES ('B_sum', 100);
                                    INSERT INTO summary
                                      VALUES ('A_sum', 200);
COMMIT;                             COMMIT;
-- → どちらかが serialization failure でロールバックされる
```

SERIALIZABLE レベルでは、結果が何らかの直列実行順序と一致しない場合、エラー `ERROR: could not serialize access` が発生する。アプリケーション側でリトライが必要。

---

## 4. MVCC (Multi-Version Concurrency Control)

PostgreSQLの同時実行制御の中核メカニズム。読み取りが書き込みをブロックしない。

### タプルバージョニング (Tuple Versioning)

各行(タプル)は以下のシステムカラムを持つ:

| カラム | 意味 |
|--------|------|
| `xmin` | この行を挿入（作成）したトランザクションID |
| `xmax` | この行を削除/更新したトランザクションID (未削除なら0) |

```sql
-- システムカラムの確認
SELECT xmin, xmax, * FROM accounts WHERE id = 1;
```

### UPDATE の仕組み

PostgreSQLの UPDATE は「旧タプルに削除マーク + 新タプル挿入」:

```
1. 旧タプル: xmax に現在のTX IDを書き込む（論理削除）
2. 新タプル: xmin に現在のTX IDを設定して挿入
```

これにより、他のトランザクションは自分のスナップショットに応じて旧タプルまたは新タプルを参照できる。

### 可視性チェック (Visibility Check)

あるタプルが「見える」条件（簡略化）:
1. `xmin` のトランザクションがコミット済み
2. `xmax` が0、または `xmax` のトランザクションが未コミット

### VACUUM

MVCCの副作用として不要タプル（dead tuple）が蓄積する。`VACUUM` がこれを回収する:

```sql
VACUUM accounts;          -- 不要タプルの回収
VACUUM FULL accounts;     -- テーブルを書き直して領域を圧縮（排他ロック必要）
VACUUM ANALYZE accounts;  -- VACUUM + 統計情報の更新
```

- **autovacuum**: PostgreSQLがバックグラウンドで自動実行（デフォルト有効）
- VACUUM しないと: テーブル肥大化（table bloat）、トランザクションIDの周回問題（wraparound）

---

## 5. ロック (Locking)

### 行レベルロック (Row-Level Locks)

```sql
-- 排他ロック: 他のトランザクションの読み書きをブロック
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;

-- 共有ロック: 他の FOR SHARE は許可、FOR UPDATE はブロック
SELECT * FROM accounts WHERE id = 1 FOR SHARE;

-- ロック待ちせずにスキップ
SELECT * FROM accounts WHERE id = 1 FOR UPDATE SKIP LOCKED;

-- ロック待ちせずにエラー
SELECT * FROM accounts WHERE id = 1 FOR UPDATE NOWAIT;
```

`FOR UPDATE` の典型的な用途: 楽観的ロックでは不十分な場合の在庫管理、座席予約など。

`SKIP LOCKED` の用途: ジョブキューの実装（ワーカーが未処理行をロック競合なしで取得）。

```sql
-- ジョブキューパターン
BEGIN;
SELECT * FROM job_queue
  WHERE status = 'pending'
  ORDER BY created_at
  LIMIT 1
  FOR UPDATE SKIP LOCKED;
-- → 取得した行を処理し、statusを更新
UPDATE job_queue SET status = 'done' WHERE id = <取得したid>;
COMMIT;
```

### アドバイザリロック (Advisory Locks)

アプリケーション定義のロック。行やテーブルに紐付かない:

```sql
-- セッションレベル: 明示的に解放するまで保持
SELECT pg_advisory_lock(12345);
-- ... 処理 ...
SELECT pg_advisory_unlock(12345);

-- トランザクションレベル: COMMIT/ROLLBACK で自動解放
SELECT pg_advisory_xact_lock(12345);
```

用途: バッチ処理の二重実行防止、外部リソースの排他制御。

### デッドロック検出 (Deadlock Detection)

```
TX1: SELECT * FROM a WHERE id=1 FOR UPDATE;  -- aの行1をロック
TX2: SELECT * FROM b WHERE id=1 FOR UPDATE;  -- bの行1をロック
TX1: SELECT * FROM b WHERE id=1 FOR UPDATE;  -- TX2の解放待ち
TX2: SELECT * FROM a WHERE id=1 FOR UPDATE;  -- TX1の解放待ち → デッドロック!
```

PostgreSQLはデッドロックを自動検出し、一方のトランザクションをアボートする（`ERROR: deadlock detected`）。

**防止策**: 常に同じ順序でロックを取得する（例: テーブルのアルファベット順、IDの昇順）。

---

## 6. EXPLAIN / EXPLAIN ANALYZE

### 基本的な使い方

```sql
-- 推定コストのみ（実行しない）
EXPLAIN SELECT * FROM orders WHERE customer_id = 5;

-- 実際に実行して実測値も表示
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 5;

-- より詳細な情報
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
  SELECT * FROM orders WHERE customer_id = 5;
```

### 実行計画の読み方

```
Hash Join  (cost=1.05..2.38 rows=5 width=40) (actual time=0.05..0.07 rows=5 loops=1)
  Hash Cond: (o.customer_id = c.id)
  ->  Seq Scan on orders o  (cost=0.00..1.10 rows=10 width=20) (actual time=0.01..0.02 rows=10 loops=1)
  ->  Hash  (cost=1.03..1.03 rows=3 width=20) (actual time=0.01..0.01 rows=3 loops=1)
        ->  Seq Scan on customers c  (cost=0.00..1.03 rows=3 width=20) (actual time=0.00..0.01 rows=3 loops=1)
```

| 要素 | 意味 |
|------|------|
| `cost=1.05..2.38` | 推定コスト（起動コスト..総コスト）。単位は任意のコスト単位 |
| `rows=5` | 推定行数（ANALYZE付きなら actual rows が実測行数） |
| `width=40` | 推定行幅（バイト） |
| `actual time=0.05..0.07` | 実測時間（ms）（起動..総時間） |
| `loops=1` | このノードの実行回数。Nested Loopの内側で増える |

**重要**: actual time と rows は1ループあたりの値。総時間 = actual time × loops。

### 主要ノードタイプ (Node Types)

#### スキャン系

| ノード | 説明 | 発生条件 |
|--------|------|----------|
| **Seq Scan** | テーブル全行の順次読み取り | インデックスなし or 大部分の行を取得する場合 |
| **Index Scan** | インデックスで行を特定し、テーブルからデータを取得 | 選択性の高い条件 + インデックスあり |
| **Index Only Scan** | インデックスのみで結果を返す（テーブルアクセス不要） | 必要カラムが全てインデックスに含まれる |
| **Bitmap Index Scan → Bitmap Heap Scan** | インデックスでビットマップを作成し、まとめてテーブルアクセス | 中程度の選択性。複数インデックスのOR/AND結合 |

#### 結合系

| ノード | 説明 | 適するケース |
|--------|------|-------------|
| **Nested Loop** | 外側テーブルの各行に対して内側テーブルをスキャン | 外側が小さい + 内側にインデックスあり |
| **Hash Join** | 小さいテーブルのハッシュテーブルを作成し、大きいテーブルを走査 | 等値結合。一方のテーブルがメモリに収まる |
| **Merge Join** | 両テーブルをソート済みの状態でマージ | 両側がソート済み or 大きなテーブル同士の結合 |

#### その他

| ノード | 説明 |
|--------|------|
| **Sort** | ソート処理（メモリ内 or ディスク）。`Sort Method: quicksort Memory: 25kB` 等 |
| **Aggregate** | 集約処理（SUM, COUNT など）。HashAggregate / GroupAggregate |
| **Limit** | 行数制限 |
| **Materialize** | 結果をメモリに保持して再利用 |

---

## 7. クエリチューニング (Query Tuning)

### インデックス活用の原則

```sql
-- インデックスが使われる
SELECT * FROM orders WHERE customer_id = 5;

-- インデックスが使われない: 関数でカラムを包む
SELECT * FROM orders WHERE LOWER(email) = 'test@example.com';
-- 対策: 式インデックスを作成
CREATE INDEX idx_orders_email_lower ON orders (LOWER(email));

-- インデックスが使われない: 暗黙の型変換
-- customer_id が integer なのに text で比較
SELECT * FROM orders WHERE customer_id = '5';  -- 動くが非効率な場合あり
```

### 結合順序

PostgreSQLのプランナは結合順序を自動最適化するが、テーブル数が多い場合（`join_collapse_limit` 超過時）は FROM 句の記述順序に依存する。小さなテーブルから結合するよう意識する。

### データの早期絞り込み

```sql
-- 悪い例: 全行を結合してからフィルタ
SELECT * FROM orders o
JOIN order_items oi ON o.id = oi.order_id
WHERE o.created_at > '2024-01-01';

-- 良い例: 同じ結果だがプランナに意図が伝わりやすい
-- （通常PostgreSQLは自動で最適化するが、複雑なクエリでは差が出る）
SELECT * FROM (
  SELECT * FROM orders WHERE created_at > '2024-01-01'
) o
JOIN order_items oi ON o.id = oi.order_id;
```

### 不要なソートの回避

```sql
-- ORDER BY がなければソート不要
-- DISTINCT より EXISTS の方が効率的な場合がある
-- UNION より UNION ALL（重複排除のソートが不要）
```

---

## 8. パフォーマンスのアンチパターン (Anti-Patterns)

### SELECT *

```sql
-- 悪い: 不要なカラムも全て転送。Index Only Scan が使えない
SELECT * FROM large_table WHERE id = 1;

-- 良い: 必要なカラムのみ
SELECT name, email FROM large_table WHERE id = 1;
```

### N+1 クエリ

```sql
-- 悪い: 顧客ごとに1クエリ（100顧客 → 101クエリ）
SELECT * FROM customers;
-- ループ内で:
SELECT * FROM orders WHERE customer_id = ?;

-- 良い: 1回の結合で取得
SELECT c.*, o.*
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id;
```

### インデックスカラムへの関数適用

```sql
-- 悪い: インデックスが無効化される
SELECT * FROM events WHERE EXTRACT(YEAR FROM event_date) = 2024;

-- 良い: 範囲条件でインデックスを使う
SELECT * FROM events
WHERE event_date >= '2024-01-01' AND event_date < '2025-01-01';
```

### 暗黙の型変換 (Implicit Type Cast)

```sql
-- phone_number が text 型の場合
-- 悪い: 数値と比較 → 全行で型変換が発生しインデックス無効
SELECT * FROM users WHERE phone_number = 09012345678;

-- 良い: 型を合わせる
SELECT * FROM users WHERE phone_number = '09012345678';
```

---

## 9. ANALYZE と統計情報 (Statistics)

プランナはテーブルの統計情報に基づいてコストを推定する:

```sql
-- 統計情報の更新
ANALYZE orders;

-- 統計情報の確認
SELECT attname, n_distinct, most_common_vals, histogram_bounds
FROM pg_stats
WHERE tablename = 'orders';
```

| 統計項目 | 意味 |
|----------|------|
| `n_distinct` | カーディナリティ（正: 値の種類数、負: -1/種類数の割合） |
| `most_common_vals` | 最頻値リスト |
| `most_common_freqs` | 最頻値の出現頻度 |
| `histogram_bounds` | 値の分布（等頻度ヒストグラム） |
| `correlation` | 物理順序と論理順序の相関（1に近い→Index Scanが有利） |

統計情報が古いとプランナが不適切な実行計画を選ぶ。`autovacuum` は `ANALYZE` も自動実行するが、大量データ投入後は手動で `ANALYZE` を実行すべき。

---

## まとめ

| トピック | 要点 |
|----------|------|
| ACID | 原子性・一貫性・分離性・永続性の4性質 |
| トランザクション制御 | BEGIN/COMMIT/ROLLBACK、SAVEPOINT で部分ロールバック |
| 分離レベル | PostgreSQLデフォルトは READ COMMITTED。SERIALIZABLE が最も厳格 |
| MVCC | タプルバージョニングで読み書きが非ブロック。VACUUMで不要タプル回収 |
| ロック | FOR UPDATE/FOR SHARE で行ロック。SKIP LOCKED でキュー実装 |
| EXPLAIN | cost, rows, actual time を読む。ノードタイプで処理内容を把握 |
| チューニング | インデックス活用、早期絞り込み、アンチパターン回避 |
| 統計情報 | ANALYZE でプランナの推定精度を維持 |
