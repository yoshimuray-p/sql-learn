# 第4回 演習: トランザクションと性能 (Transactions & Performance)

> **学習の進め方**: 各演習に自力で取り組んだ後、AIアシスタントに自分の解答を見せてレビューしてもらおう。
> 行き詰まったときはヒントを求め、いきなり答えを聞くのではなく対話的に考えを深めよう。
> 解答例は `answers.md` にまとめてある。


---

## 演習1: トランザクション制御の基本

以下のシナリオをSQLで実装せよ。

ECサイトで注文を処理する。以下の3つの操作を1つのトランザクションとして実行し、途中でエラーが起きた場合は全て取り消す:

1. `orders` テーブルに注文レコードを挿入
2. `order_items` テーブルに明細を2件挿入
3. `inventory` テーブルで在庫数を減らす（在庫が0未満にならないようCHECK制約あり）

在庫不足で3が失敗した場合、SAVEPOINT を使って明細の1件目まで戻り、2件目をスキップして注文を確定する方法も示せ。


**あなたの解答:**

```

```

---

## 演習2: 分離レベルと競合現象

以下の2つのトランザクションが同時に実行される。各分離レベル（READ COMMITTED / REPEATABLE READ / SERIALIZABLE）で TX1 の2回目の `SELECT` は何を返すか答えよ。

```
TX1                                     TX2
BEGIN;
SELECT price FROM products
  WHERE id = 1;
-- → 1000
                                        BEGIN;
                                        UPDATE products SET price = 1500
                                          WHERE id = 1;
                                        COMMIT;
SELECT price FROM products
  WHERE id = 1;
-- → ???
COMMIT;
```


**あなたの解答:**

```

```

---

## 演習3: ファントムリードと直列化異常

以下のシナリオで何が起こるか説明せよ。

```sql
-- テーブル: accounts (id, balance)
-- 行: (1, 500), (2, 500)
-- 制約: balance の合計は常に1000であるべき

-- TX1 (SERIALIZABLE)
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT sum(balance) FROM accounts;  -- → 1000
UPDATE accounts SET balance = balance + 100 WHERE id = 1;
COMMIT;

-- TX2 (SERIALIZABLE, TX1と同時実行)
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT sum(balance) FROM accounts;  -- → 1000
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;
```


**あなたの解答:**

```

```

---

## 演習4: ロックと同時実行

ジョブキューテーブルから複数のワーカーが安全にジョブを取得する SQL を書け。条件:

- `job_queue (id SERIAL, payload TEXT, status TEXT DEFAULT 'pending', created_at TIMESTAMP DEFAULT now())`
- ワーカーは `pending` 状態の最も古いジョブを1件取得し、`processing` に更新する
- 複数ワーカーが同時に実行しても同じジョブを取得しないこと


**あなたの解答:**

```

```

---

## 演習5: EXPLAIN 実行計画の読解 (1)

以下の実行計画を読んで、各質問に答えよ。

```
Hash Join  (cost=15.00..45.20 rows=200 width=48) (actual time=0.30..1.50 rows=180 loops=1)
  Hash Cond: (o.customer_id = c.id)
  ->  Seq Scan on orders o  (cost=0.00..22.00 rows=1200 width=28) (actual time=0.01..0.40 rows=1200 loops=1)
  ->  Hash  (cost=12.50..12.50 rows=200 width=20) (actual time=0.25..0.25 rows=150 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 15kB
        ->  Bitmap Heap Scan on customers c  (cost=4.50..12.50 rows=200 width=20) (actual time=0.05..0.20 rows=150 loops=1)
              Recheck Cond: (city = 'Tokyo')
              Heap Blocks: exact=10
              ->  Bitmap Index Scan on idx_customers_city  (cost=0.00..4.45 rows=200 width=0) (actual time=0.03..0.03 rows=150 loops=1)
                    Index Cond: (city = 'Tokyo')
Planning Time: 0.15 ms
Execution Time: 1.70 ms
```

1. このクエリは何をしているか？
2. `customers` テーブルのスキャン方法は？なぜ Seq Scan ではないのか？
3. 推定行数と実際の行数の乖離はあるか？それは問題か？
4. ボトルネックはどこか？


**あなたの解答:**

```

```

---

## 演習6: EXPLAIN 実行計画の読解 (2)

以下の実行計画には性能上の問題がある。問題点を指摘し、改善策を述べよ。

```
Sort  (cost=25000.00..25200.00 rows=80000 width=36) (actual time=450.00..480.00 rows=80000 loops=1)
  Sort Key: created_at
  Sort Method: external merge  Disk: 5120kB
  ->  Nested Loop  (cost=0.00..18000.00 rows=80000 width=36) (actual time=0.05..300.00 rows=80000 loops=1)
        ->  Seq Scan on orders  (cost=0.00..5000.00 rows=100000 width=20) (actual time=0.01..50.00 rows=100000 loops=1)
        ->  Index Scan using customers_pkey on customers  (cost=0.00..0.13 rows=1 width=16) (actual time=0.002..0.002 rows=1 loops=100000)
              Index Cond: (id = orders.customer_id)
Planning Time: 0.20 ms
Execution Time: 510.00 ms
```


**あなたの解答:**

```

```

---

## 演習7: クエリ最適化

以下のクエリは遅い。問題点を特定し、最適化せよ。

```sql
-- テーブル定義:
-- users (id, name, email, created_at)  -- 100万行
-- orders (id, user_id, amount, ordered_at)  -- 500万行
-- インデックス: users_pkey, orders_pkey, idx_orders_user_id

-- 遅いクエリ: 2024年に登録したユーザーの注文合計金額
SELECT u.id, u.name,
       (SELECT SUM(o.amount) FROM orders o WHERE o.user_id = u.id) AS total_amount
FROM users u
WHERE EXTRACT(YEAR FROM u.created_at) = 2024
ORDER BY total_amount DESC NULLS LAST;
```


**あなたの解答:**

```

```

---

## 演習8: デッドロックの分析と防止

以下のアプリケーションコード（擬似コード）はデッドロックを引き起こす可能性がある。原因を説明し、修正せよ。

```python
# ワーカーA: ユーザー1からユーザー2への送金
def transfer_a():
    db.execute("BEGIN")
    db.execute("SELECT * FROM accounts WHERE user_id = 1 FOR UPDATE")
    db.execute("SELECT * FROM accounts WHERE user_id = 2 FOR UPDATE")
    db.execute("UPDATE accounts SET balance = balance - 100 WHERE user_id = 1")
    db.execute("UPDATE accounts SET balance = balance + 100 WHERE user_id = 2")
    db.execute("COMMIT")

# ワーカーB: ユーザー2からユーザー1への送金（同時実行）
def transfer_b():
    db.execute("BEGIN")
    db.execute("SELECT * FROM accounts WHERE user_id = 2 FOR UPDATE")
    db.execute("SELECT * FROM accounts WHERE user_id = 1 FOR UPDATE")
    db.execute("UPDATE accounts SET balance = balance - 100 WHERE user_id = 2")
    db.execute("UPDATE accounts SET balance = balance + 100 WHERE user_id = 1")
    db.execute("COMMIT")
```


**あなたの解答:**

```

```

---

## 演習9: MVCC の理解

以下の操作を順に実行した後、`pg_stat_user_tables` で `n_dead_tup` はおおよそいくつになるか。また、その状態を解消するにはどうすればよいか。

```sql
CREATE TABLE test (id INT PRIMARY KEY, val TEXT);
INSERT INTO test SELECT i, 'original' FROM generate_series(1, 10000) AS i;
UPDATE test SET val = 'updated' WHERE id <= 5000;
DELETE FROM test WHERE id > 8000;
```


**あなたの解答:**

```

```

---

## 演習10: 総合問題 — スロークエリの診断

以下の状況で原因を特定し、対策を述べよ。

**状況**: ECサイトの商品一覧ページが遅い。以下のクエリに3秒かかる。

```sql
SELECT p.id, p.name, p.price, c.name AS category_name,
       AVG(r.rating) AS avg_rating
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN reviews r ON p.id = r.product_id
WHERE p.is_active = true
  AND c.name = 'Electronics'
GROUP BY p.id, p.name, p.price, c.name
ORDER BY avg_rating DESC NULLS LAST
LIMIT 20;
```

テーブルサイズ: products 50万行、categories 100行、reviews 200万行。
インデックス: 各テーブルのPKのみ。


**あなたの解答:**

```

```
