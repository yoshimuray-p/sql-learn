# 第4回 解答: トランザクションと性能 (Transactions & Performance)

---

## 演習1: トランザクション制御の基本

```sql
-- パターンA: 全体をロールバック
BEGIN;

INSERT INTO orders (id, customer_id, total)
  VALUES (101, 1, 3000);

INSERT INTO order_items (order_id, product_id, qty, price)
  VALUES (101, 10, 1, 2000);
INSERT INTO order_items (order_id, product_id, qty, price)
  VALUES (101, 20, 1, 1000);

UPDATE inventory SET stock = stock - 1 WHERE product_id = 10;
UPDATE inventory SET stock = stock - 1 WHERE product_id = 20;
-- ↑ CHECK制約違反が発生した場合、以下を実行:
-- ROLLBACK;

COMMIT;

-- パターンB: SAVEPOINTで部分ロールバック
BEGIN;

INSERT INTO orders (id, customer_id, total)
  VALUES (101, 1, 2000);

INSERT INTO order_items (order_id, product_id, qty, price)
  VALUES (101, 10, 1, 2000);
UPDATE inventory SET stock = stock - 1 WHERE product_id = 10;

SAVEPOINT before_item2;

INSERT INTO order_items (order_id, product_id, qty, price)
  VALUES (101, 20, 1, 1000);
UPDATE inventory SET stock = stock - 1 WHERE product_id = 20;
-- 在庫不足でエラー発生 →
ROLLBACK TO before_item2;
-- 1件目のみで注文確定

COMMIT;
```

---

## 演習2: 分離レベルと競合現象

| 分離レベル | 2回目のSELECT結果 | 理由 |
|-----------|-------------------|------|
| **READ COMMITTED** | **1500** | 各SQL文の実行時点でコミット済みの最新データを読む。TX2がコミット済みなので新しい値が見える |
| **REPEATABLE READ** | **1000** | TX1開始時のスナップショットを使い続ける。TX2の変更はTX1には見えない |
| **SERIALIZABLE** | **1000** | REPEATABLE READと同じスナップショットを使用。加えて直列化異常の検出も行う |

READ COMMITTED ではノンリピータブルリード（Non-Repeatable Read）が発生する。REPEATABLE READ 以上ではスナップショット分離により防止される。

---

## 演習3: ファントムリードと直列化異常

**SERIALIZABLE レベルの場合:**

両方のトランザクションが `sum(balance) = 1000` を読み取り、それに基づいて更新を行っている。もし両方がコミットされると合計は `1200` になり、「合計1000に基づいて判断した」という前提が崩れる。

これは直列化異常（Serialization Anomaly）である。TX1→TX2 の順で直列実行すれば TX2 は sum=1100 を読むはずだし、TX2→TX1 なら TX1 が sum=1100 を読むはず。実際の並行実行結果はどちらとも一致しない。

PostgreSQL の SERIALIZABLE 実装（SSI: Serializable Snapshot Isolation）は、この依存関係を検出し、後からコミットしようとした方に `ERROR: could not serialize access due to read/write dependencies among transactions` を返す。

アプリケーション側ではこのエラーをキャッチし、トランザクションをリトライする必要がある。

**READ COMMITTED / REPEATABLE READ の場合:**

両方が正常にコミットし、合計は1200になる。DBMS はこの矛盾を検出しない。ビジネスロジックでの整合性保証が必要なら SERIALIZABLE を使うか、明示的ロック（`SELECT ... FOR UPDATE`）を使用する。

---

## 演習4: ロックと同時実行

```sql
BEGIN;

UPDATE job_queue
SET status = 'processing'
WHERE id = (
  SELECT id FROM job_queue
  WHERE status = 'pending'
  ORDER BY created_at
  LIMIT 1
  FOR UPDATE SKIP LOCKED
)
RETURNING *;

COMMIT;
```

**ポイント:**

- `FOR UPDATE SKIP LOCKED` により、他のワーカーがロック中の行をスキップして次の `pending` 行を取得する
- `SKIP LOCKED` がない場合、他のワーカーはロック解放を待つため、並列性が損なわれる
- `NOWAIT` を使うとロック競合時にエラーになるが、`SKIP LOCKED` は単にスキップするため、キュー処理に適している
- サブクエリで `FOR UPDATE SKIP LOCKED` を使い、外側の `UPDATE` でステータスを更新するパターンが典型的

---

## 演習5: EXPLAIN 実行計画の読解 (1)

**1. クエリの内容:**

`orders` テーブルと `customers` テーブルを `customer_id` で結合（Hash Join）している。`customers` は `city = 'Tokyo'` で絞り込まれている。おそらく元のクエリは:

```sql
SELECT ... FROM orders o JOIN customers c ON o.customer_id = c.id WHERE c.city = 'Tokyo';
```

**2. customers のスキャン方法:**

Bitmap Index Scan → Bitmap Heap Scan の2段階。`idx_customers_city` インデックスを使って `city = 'Tokyo'` の行をビットマップに記録し、ヒープ（テーブル）からまとめて取得している。Seq Scan ではないのは、`city = 'Tokyo'` の行が全体の一部（200/全行）であり、インデックスを使う方が効率的とプランナが判断したため。

**3. 推定行数と実際の行数の乖離:**

- customers の Bitmap Scan: 推定 200行 vs 実際 150行（1.3倍の過大推定）
- Hash Join: 推定 200行 vs 実際 180行（軽微な差）
- orders の Seq Scan: 推定 1200行 vs 実際 1200行（一致）

乖離は軽微であり、問題ない範囲。10倍以上乖離する場合は `ANALYZE` を実行して統計情報を更新すべき。

**4. ボトルネック:**

全体の実行時間が 1.70ms と非常に高速で、明確なボトルネックはない。強いて言えば、`orders` テーブルの Seq Scan（0.40ms）が最も時間を消費している。orders が大きくなった場合は `customer_id` へのインデックスが有効（ただし全行取得なのでこのクエリでは Seq Scan が妥当）。

---

## 演習6: EXPLAIN 実行計画の読解 (2)

**問題点:**

1. **ディスクソート**: `Sort Method: external merge  Disk: 5120kB` — ソートがメモリに収まらずディスクに溢れている。これが 450〜480ms を消費している（全体510msの大部分）。

2. **Nested Loop の非効率**: 外側 `orders` が100,000行のため、内側 `customers` の Index Scan が100,000回実行されている。1回あたりの時間は短い（0.002ms）が、回数が膨大。

3. **orders テーブルの Seq Scan**: フィルタ条件がないため全100,000行を読んでいる。

**改善策:**

1. **work_mem の増加**（一時的対策）:
   ```sql
   SET work_mem = '16MB';  -- デフォルト4MBから増やしてディスクソートを回避
   ```

2. **結合方式の改善**: 100,000行同士の結合なら Hash Join の方が効率的。プランナが Nested Loop を選んだのは統計情報の問題かもしれない:
   ```sql
   ANALYZE orders;
   ANALYZE customers;
   ```

3. **必要に応じてインデックス追加**:
   ```sql
   -- created_at でのソートが頻繁なら
   CREATE INDEX idx_orders_created_at ON orders (created_at);
   ```

4. **不要な行の絞り込み**: WHERE 句で orders を絞れるなら追加する（例: 日付範囲）。

---

## 演習7: クエリ最適化

**問題点:**

1. **`EXTRACT(YEAR FROM u.created_at)`**: created_at カラムに関数を適用しており、インデックスが使われない。100万行全てで関数評価が発生する。

2. **相関サブクエリ**: `(SELECT SUM(...) WHERE o.user_id = u.id)` がユーザーごとに実行される。2024年登録のユーザーが10万人なら10万回サブクエリが走る（N+1 に類似）。

3. **`SELECT *` ではないが `total_amount` でソート**: NULLの扱いも含めソートコストが高い。

**最適化後:**

```sql
SELECT u.id, u.name, COALESCE(SUM(o.amount), 0) AS total_amount
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at >= '2024-01-01' AND u.created_at < '2025-01-01'
GROUP BY u.id, u.name
ORDER BY total_amount DESC;
```

**改善ポイント:**

1. **範囲条件に変更**: `EXTRACT(YEAR FROM ...)` を `created_at >= ... AND created_at < ...` に置き換え。`created_at` にインデックスがあれば使われる。なければ追加:
   ```sql
   CREATE INDEX idx_users_created_at ON users (created_at);
   ```

2. **JOIN + GROUP BY に変換**: 相関サブクエリを LEFT JOIN + GROUP BY に書き換え。プランナが Hash Join や Merge Join を選択でき、1回のスキャンで完了する。

3. **COALESCE**: 注文がないユーザーでも 0 を返し、NULL ハンドリングを簡略化。

---

## 演習8: デッドロックの分析と防止

**デッドロックの原因:**

```
ワーカーA                              ワーカーB
BEGIN                                  BEGIN
LOCK user_id=1 ✓                       LOCK user_id=2 ✓
LOCK user_id=2 → Bの解放待ち           LOCK user_id=1 → Aの解放待ち
→ デッドロック!
```

ワーカーAは user_id=1→2 の順でロック、ワーカーBは user_id=2→1 の順でロックしているため、循環待ちが発生する。

**修正方法: ロック順序を統一する**

```python
def transfer(from_id, to_id, amount):
    db.execute("BEGIN")
    # 常にIDが小さい方を先にロック
    first_id = min(from_id, to_id)
    second_id = max(from_id, to_id)
    db.execute(f"SELECT * FROM accounts WHERE user_id = {first_id} FOR UPDATE")
    db.execute(f"SELECT * FROM accounts WHERE user_id = {second_id} FOR UPDATE")
    db.execute(f"UPDATE accounts SET balance = balance - {amount} WHERE user_id = {from_id}")
    db.execute(f"UPDATE accounts SET balance = balance + {amount} WHERE user_id = {to_id}")
    db.execute("COMMIT")
```

**ポイント:**

- ロック順序を user_id の昇順に統一することで、循環待ちが原理的に発生しなくなる
- この原則はテーブルが複数ある場合にも適用する（例: テーブル名のアルファベット順）
- 別のアプローチ: `SELECT ... FOR UPDATE NOWAIT` を使い、ロック取得失敗時にリトライする
- PostgreSQL はデッドロックを自動検出してくれるが、防止する設計の方が望ましい

**注意**: 上記の擬似コードでは文字列フォーマットを使っているが、実際のアプリケーションではSQLインジェクション防止のためパラメータバインディングを使用すること。

---

## 演習9: MVCC の理解

**dead tuple の数: 約 7,000**

内訳:
- `INSERT`: 10,000行作成。dead tuple = 0
- `UPDATE ... WHERE id <= 5000`: 5,000行が更新される。PostgreSQLのMVCCでは UPDATE = 旧タプル削除 + 新タプル挿入。旧タプル5,000個が dead tuple になる
- `DELETE ... WHERE id > 8000`: 2,000行（id 8001〜10000）が削除される。これらの2,000個も dead tuple になる

合計: 5,000 + 2,000 = **7,000 dead tuples**

```sql
-- 確認
SELECT n_live_tup, n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'test';
-- n_live_tup ≈ 8000, n_dead_tup ≈ 7000
```

**解消方法:**

```sql
-- dead tuple の回収（領域はOS に返さない）
VACUUM test;

-- 実行後: n_dead_tup ≈ 0
-- テーブルサイズは変わらない（空き領域は再利用可能になる）

-- テーブルを完全に書き直してサイズも縮小する場合:
VACUUM FULL test;
-- ただし排他ロックが必要（テーブルへのアクセスがブロックされる）
```

**補足:**
- autovacuum が有効なら、しばらくすると自動で VACUUM される
- `VACUUM FULL` は最後の手段。通常は `VACUUM`（+ `REINDEX` が必要なら）で十分
- `pg_repack` 拡張を使えば排他ロックなしでテーブルを再編成できる

---

## 演習10: 総合問題 — スロークエリの診断

**問題点の分析:**

1. **`p.category_id` にインデックスがない**: products と categories の結合で Seq Scan が発生する可能性。

2. **`r.product_id` にインデックスがない**: reviews との結合で大量の Seq Scan。200万行を毎回フルスキャンするのが最大のボトルネック。

3. **`p.is_active` のフィルタ**: 多くの商品が active であれば選択性が低く、インデックスの効果は薄い。ただし少数なら有効。

4. **`c.name = 'Electronics'` を LEFT JOIN 側で指定**: LEFT JOIN した上で `c.name = 'Electronics'` を WHERE で指定しているため、実質 INNER JOIN と同じ動作になる（NULL行が除外される）。意図が INNER JOIN なら明示すべき。

5. **GROUP BY + ORDER BY + LIMIT**: 全行の平均評価を計算してからソート・制限するため、不要な集約処理が多い。

**対策:**

```sql
-- 1. 必須インデックスの追加
CREATE INDEX idx_reviews_product_id ON reviews (product_id);
CREATE INDEX idx_products_category_id ON products (category_id);

-- 2. 部分インデックス（is_active = true が少数の場合有効）
CREATE INDEX idx_products_active ON products (category_id) WHERE is_active = true;

-- 3. クエリの改善
SELECT p.id, p.name, p.price, c.name AS category_name,
       AVG(r.rating) AS avg_rating
FROM products p
JOIN categories c ON p.category_id = c.id  -- LEFT JOIN → JOIN に変更
LEFT JOIN reviews r ON p.id = r.product_id
WHERE p.is_active = true
  AND c.id = (SELECT id FROM categories WHERE name = 'Electronics')
GROUP BY p.id, p.name, p.price, c.name
ORDER BY avg_rating DESC NULLS LAST
LIMIT 20;
```

**さらなる改善案:**

```sql
-- reviews の集計をサブクエリで先に行い、結合する行数を減らす
SELECT p.id, p.name, p.price, 'Electronics' AS category_name,
       rs.avg_rating
FROM products p
JOIN categories c ON p.category_id = c.id
LEFT JOIN (
  SELECT product_id, AVG(rating) AS avg_rating
  FROM reviews
  GROUP BY product_id
) rs ON p.id = rs.product_id
WHERE p.is_active = true
  AND c.name = 'Electronics'
ORDER BY rs.avg_rating DESC NULLS LAST
LIMIT 20;
```

**統計情報の更新も忘れずに:**

```sql
ANALYZE products;
ANALYZE reviews;
ANALYZE categories;
```

**確認:**

```sql
EXPLAIN (ANALYZE, BUFFERS) <改善後のクエリ>;
```

改善後は Index Scan / Hash Join が使われ、実行時間が大幅に短縮されるはず。
