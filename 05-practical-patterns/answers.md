# 第5回 解答: 実務応用パターン (Practical Patterns)

---

## 問題1: VIEW の作成と利用

```sql
CREATE VIEW department_stats AS
SELECT
    d.id   AS department_id,
    d.name AS department_name,
    COUNT(e.id)              AS employee_count,
    ROUND(AVG(e.salary))::INT AS avg_salary
FROM departments d
LEFT JOIN employees e ON e.department_id = d.id
GROUP BY d.id, d.name;

-- 使用例
SELECT * FROM department_stats ORDER BY avg_salary DESC NULLS LAST;
```

**ポイント**: LEFT JOIN にすることで従業員0人の部署も含まれる。

---

## 問題2: MATERIALIZED VIEW とリフレッシュ

```sql
CREATE MATERIALIZED VIEW monthly_order_summary AS
SELECT
    date_trunc('month', order_date)::DATE AS month,
    SUM(amount)   AS total_amount,
    COUNT(*)      AS order_count
FROM orders
GROUP BY 1;

-- CONCURRENTLY にはユニークインデックスが必要
CREATE UNIQUE INDEX idx_mos_month ON monthly_order_summary (month);

-- ロックなしリフレッシュ
REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_order_summary;
```

**ポイント**: `CONCURRENTLY` を使うと既存データへの SELECT をブロックせずにリフレッシュできる。

---

## 問題3: JSONB クエリ

```sql
-- 1. action が 'purchase'
SELECT * FROM api_logs
WHERE payload ->> 'action' = 'purchase';

-- または containment 演算子（GIN インデックスが効く）
SELECT * FROM api_logs
WHERE payload @> '{"action": "purchase"}';

-- 2. metadata.device が 'mobile'
SELECT * FROM api_logs
WHERE payload #>> '{metadata,device}' = 'mobile';

-- または
SELECT * FROM api_logs
WHERE payload @> '{"metadata": {"device": "mobile"}}';

-- 3. items キーの存在確認
SELECT COUNT(*) FROM api_logs
WHERE payload ? 'items';
```

**ポイント**: パフォーマンスを考慮する場合、`@>` と GIN インデックスの組み合わせが最適。

---

## 問題4: PL/pgSQL 関数

```sql
CREATE OR REPLACE FUNCTION dept_size(dept_id INT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    cnt INT;
BEGIN
    SELECT COUNT(*) INTO cnt
    FROM employees
    WHERE department_id = dept_id;

    IF cnt = 0 THEN
        RETURN 'empty';
    ELSIF cnt <= 5 THEN
        RETURN 'small';
    ELSIF cnt <= 20 THEN
        RETURN 'medium';
    ELSE
        RETURN 'large';
    END IF;
END;
$$;

-- 使用例
SELECT d.id, d.name, dept_size(d.id) FROM departments d ORDER BY d.id;
```

---

## 問題5: SQL インジェクションの識別

**(a) 攻撃例:**

`category` に `' OR '1'='1' --` を渡すと:

```sql
SELECT * FROM products
WHERE category = '' OR '1'='1' --'
  AND price >= 100
ORDER BY price
```

全商品が返される。`min_price` に `0; DROP TABLE products --` を渡せばテーブル削除も可能。

**(b) 修正版:**

```python
def search_products(conn, category, min_price):
    query = """
        SELECT * FROM products
        WHERE category = %s
          AND price >= %s
        ORDER BY price
    """
    return conn.execute(query, (category, min_price)).fetchall()
```

**ポイント**: パラメタライズドクエリを使うことで、入力値は SQL 構文として解釈されず、常にリテラル値として扱われる。

---

## 問題6: Upsert (INSERT ... ON CONFLICT)

```sql
INSERT INTO user_preferences (user_id, key, value, updated_at)
VALUES (1, 'language', 'ja', NOW())
ON CONFLICT (user_id, key)
DO UPDATE SET
    value      = EXCLUDED.value,
    updated_at = NOW();
```

**ポイント**: `EXCLUDED` は挿入しようとした行を参照する擬似テーブル。`ON CONFLICT` 句には主キーまたはユニーク制約のカラムを指定する。

---

## 問題7: ページネーション

```sql
-- 1. OFFSET 方式（3ページ目）
SELECT * FROM products
ORDER BY price DESC, id ASC
LIMIT 10 OFFSET 20;

-- 2. カーソルベース方式
SELECT * FROM products
WHERE price < 500
   OR (price = 500 AND id > 42)
ORDER BY price DESC, id ASC
LIMIT 10;
```

**OFFSET の問題点:**
- OFFSET 値が大きいほどスキップ対象行もスキャンするため O(n) で遅くなる
- ページ間でデータの挿入・削除があると行の重複・抜けが発生する

---

## 問題8: Top-N per Group

```sql
SELECT id, name, category, price
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY price DESC, id ASC
        ) AS rn
    FROM products
) ranked
WHERE rn <= 2
ORDER BY category, price DESC;
```

**ポイント**: `ROW_NUMBER()` は同値でも必ず異なる番号を振るため、Top-N の取得に適している。`RANK()` を使うと同値が同順位になり、N 件を超える可能性がある。

---

## 問題9: ギャップ・アンド・アイランド

```sql
WITH grouped AS (
    SELECT
        user_id,
        login_date,
        login_date - (ROW_NUMBER() OVER (
            PARTITION BY user_id ORDER BY login_date
        ))::int AS grp
    FROM logins
),
streaks AS (
    SELECT
        user_id,
        grp,
        COUNT(*) AS streak_days
    FROM grouped
    GROUP BY user_id, grp
)
SELECT
    user_id,
    MAX(streak_days) AS max_streak
FROM streaks
GROUP BY user_id
ORDER BY max_streak DESC;
```

**原理**: 連続する日付から連番を引くと、同じ連続グループでは同じ `grp` 値になる。

例: 日付 `1/1, 1/2, 1/3` から連番 `1, 2, 3` を引くと `12/31, 12/31, 12/31` → 同一グループ。日付 `1/1, 1/3` から `1, 2` を引くと `12/31, 1/1` → 別グループ。

---

## 問題10: 総合問題 — トリガーによる在庫管理

```sql
-- 1. トリガー関数
CREATE OR REPLACE FUNCTION reduce_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    current_stock INT;
BEGIN
    SELECT stock INTO current_stock
    FROM inventory
    WHERE product_id = NEW.product_id
    FOR UPDATE;  -- 行ロックで競合防止

    IF current_stock IS NULL THEN
        RAISE EXCEPTION '商品ID % の在庫レコードが存在しません', NEW.product_id;
    END IF;

    IF current_stock < NEW.quantity THEN
        RAISE EXCEPTION '在庫不足: 商品ID %, 現在庫 %, 要求数 %',
            NEW.product_id, current_stock, NEW.quantity;
    END IF;

    UPDATE inventory
    SET stock = stock - NEW.quantity
    WHERE product_id = NEW.product_id;

    RETURN NEW;
END;
$$;

-- 2. トリガー作成
CREATE TRIGGER trg_order_reduce_stock
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION reduce_stock();
```

**ポイント**: `FOR UPDATE` で在庫行をロックすることで、同時注文時の競合（レースコンディション）を防止する。`RAISE EXCEPTION` によりトランザクション全体がロールバックされ、不正な注文は確定しない。
