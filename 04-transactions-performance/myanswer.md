# 第4回 自己解答: トランザクションと性能 (Transactions & Performance)

---

## 演習1: トランザクション制御の基本

ECサイトの注文処理を1トランザクションで実装せよ。

1. `orders` テーブルに注文レコードを挿入
2. `order_items` テーブルに明細を2件挿入
3. `inventory` テーブルの在庫数を減らす（CHECK 制約あり）

在庫不足で3が失敗した場合、SAVEPOINT を使って明細の1件目まで戻り、2件目をスキップして注文を確定する方法も示せ。

```sql

```

---

## 演習2: 分離レベルと競合現象

以下の同時実行シナリオで、各分離レベルにおいて TX1 の2回目の SELECT は何を返すか答えよ。

```
TX1: SELECT price → 1000 → (TX2 が 1500 に UPDATE & COMMIT) → SELECT price → ???
```

```

READ COMMITTED:

REPEATABLE READ:

SERIALIZABLE:
```

---

## 演習3: ファントムリードと直列化異常

以下のシナリオで何が起こるか説明せよ（SERIALIZABLE 分離レベル、同時実行）。

```sql
-- TX1: SELECT sum(balance) → 1000 → UPDATE balance+100 WHERE id=1 → COMMIT
-- TX2: SELECT sum(balance) → 1000 → UPDATE balance+100 WHERE id=2 → COMMIT
-- 制約: balance の合計は常に1000
```

```

```

---

## 演習4: ロックと同時実行

ジョブキューから複数ワーカーが安全に1件ずつジョブを取得する SQL を書け。

- `job_queue (id SERIAL, payload TEXT, status TEXT DEFAULT 'pending', created_at TIMESTAMP)`
- `pending` の最も古いジョブを1件取得し `processing` に更新
- 複数ワーカーが同時実行しても同じジョブを取得しないこと

```sql

```

---

## 演習5: EXPLAIN 実行計画の読解 (1)

以下の実行計画を読んで答えよ。

```
Hash Join  (cost=15.00..45.20 rows=200 width=48) (actual time=0.30..1.50 rows=180 loops=1)
  Hash Cond: (o.customer_id = c.id)
  ->  Seq Scan on orders o  ...  rows=1200
  ->  Hash  ...
        ->  Bitmap Heap Scan on customers c  ...  rows=150
              Recheck Cond: (city = 'Tokyo')
              ->  Bitmap Index Scan on idx_customers_city  ...
```

```

1. このクエリは何をしているか？

2. customers のスキャン方法は？なぜ Seq Scan ではないか？

3. 推定行数と実際の行数の乖離はあるか？問題か？

4. ボトルネックはどこか？
```

---

## 演習6: EXPLAIN 実行計画の読解 (2)

以下の実行計画の性能上の問題点を指摘し、改善策を述べよ。

```
Sort  ...  Sort Method: external merge  Disk: 5120kB
  ->  Nested Loop  ...  rows=80000  loops=1
        ->  Seq Scan on orders  ...  rows=100000
        ->  Index Scan using customers_pkey  ...  loops=100000
Execution Time: 510.00 ms
```

```

問題点:

改善策:
```

---

## 演習7: クエリ最適化

以下の遅いクエリの問題点を特定し、最適化せよ。

```sql
-- users 100万行、orders 500万行
-- インデックス: users_pkey, orders_pkey, idx_orders_user_id
SELECT u.id, u.name,
       (SELECT SUM(o.amount) FROM orders o WHERE o.user_id = u.id) AS total_amount
FROM users u
WHERE EXTRACT(YEAR FROM u.created_at) = 2024
ORDER BY total_amount DESC NULLS LAST;
```

**問題点:**

```

```

**最適化後のクエリ:**

```sql

```

---

## 演習8: デッドロックの分析と防止

以下のコードがデッドロックを引き起こす原因を説明し、修正せよ。

```python
# ワーカーA: user_id=1 → 2 への送金（id=1 を先にロック）
# ワーカーB: user_id=2 → 1 への送金（id=2 を先にロック）
```

**原因:**

```

```

**修正後のコード:**

```python

```

---

## 演習9: MVCC の理解

以下の操作後、`n_dead_tup` はおおよそいくつになるか。また解消方法を述べよ。

```sql
INSERT INTO test SELECT i, 'original' FROM generate_series(1, 10000) AS i;
UPDATE test SET val = 'updated' WHERE id <= 5000;
DELETE FROM test WHERE id > 8000;
```

```

n_dead_tup の推定値:

理由:

解消方法:
```

---

## 演習10: 総合問題 — スロークエリの診断

以下のクエリが3秒かかる原因を特定し、対策を述べよ。

```sql
-- products 50万行、categories 100行、reviews 200万行
-- インデックス: 各テーブルのPKのみ
SELECT p.id, p.name, p.price, c.name AS category_name,
       AVG(r.rating) AS avg_rating
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN reviews r ON p.id = r.product_id
WHERE p.is_active = true AND c.name = 'Electronics'
GROUP BY p.id, p.name, p.price, c.name
ORDER BY avg_rating DESC NULLS LAST
LIMIT 20;
```

**原因:**

```

```

**改善策:**

```sql

```
