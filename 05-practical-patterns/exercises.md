# 第5回 演習: 実務応用パターン (Practical Patterns)

以下のスキーマを前提とする（一部の問題では追加テーブルを定義）。

```sql
CREATE TABLE departments (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE employees (
    id            SERIAL PRIMARY KEY,
    name          TEXT NOT NULL,
    email         TEXT UNIQUE NOT NULL,
    department_id INT REFERENCES departments(id),
    salary        INT NOT NULL,
    hired_at      DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE products (
    id       SERIAL PRIMARY KEY,
    name     TEXT NOT NULL,
    category TEXT NOT NULL,
    price    INT NOT NULL
);

CREATE TABLE orders (
    id         SERIAL PRIMARY KEY,
    user_id    INT NOT NULL,
    product_id INT REFERENCES products(id),
    quantity   INT NOT NULL DEFAULT 1,
    amount     INT NOT NULL,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE
);
```

---

## 問題1: VIEW の作成と利用

各部署の人数と平均給与を返すビュー `department_stats` を作成せよ。カラムは `department_id`, `department_name`, `employee_count`, `avg_salary`（整数に丸める）とする。


**あなたの解答:**

```

```

<details><summary>解答</summary>

```sql
CREATE VIEW department_stats AS
SELECT
    d.id   AS department_id,
    d.name AS department_name,
    COUNT(e.id)        AS employee_count,
    ROUND(AVG(e.salary))::INT AS avg_salary
FROM departments d
LEFT JOIN employees e ON e.department_id = d.id
GROUP BY d.id, d.name;

-- 使用例
SELECT * FROM department_stats ORDER BY avg_salary DESC;
```

LEFT JOIN にすることで従業員0人の部署も含まれる。

</details>

---

## 問題2: MATERIALIZED VIEW とリフレッシュ

月別の注文集計（月、合計金額、注文数）をマテリアライズドビュー `monthly_order_summary` として作成せよ。さらに、ロックなしでリフレッシュできるようにせよ。


**あなたの解答:**

```

```

<details><summary>解答</summary>

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

`CONCURRENTLY` を使うと既存データへの SELECT をブロックせずにリフレッシュできる。

</details>

---

## 問題3: JSONB クエリ

以下のテーブルがある:

```sql
CREATE TABLE api_logs (
    id         SERIAL PRIMARY KEY,
    endpoint   TEXT NOT NULL,
    payload    JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

`payload` の例:

```json
{"user_id": 5, "action": "login", "metadata": {"ip": "192.168.1.1", "device": "mobile"}}
{"user_id": 3, "action": "purchase", "items": [{"sku": "A001", "qty": 2}, {"sku": "B010", "qty": 1}]}
```

以下の3つのクエリを書け:

1. `action` が `'purchase'` のログを取得
2. `metadata` の `device` が `'mobile'` のログを取得
3. `payload` に `items` キーが存在するログの件数を取得


**あなたの解答:**

```

```

<details><summary>解答</summary>

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

パフォーマンスを考慮する場合、`@>` と GIN インデックスの組み合わせが最適。

</details>

---

## 問題4: PL/pgSQL 関数

引数として `department_id` を受け取り、その部署の従業員数に応じて以下の文字列を返す関数 `dept_size(dept_id INT)` を作成せよ:

- 0人: `'empty'`
- 1〜5人: `'small'`
- 6〜20人: `'medium'`
- 21人以上: `'large'`


**あなたの解答:**

```

```

<details><summary>解答</summary>

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
SELECT d.id, d.name, dept_size(d.id) FROM departments d;
```

</details>

---

## 問題5: SQL インジェクションの識別

以下の Python コードには SQL インジェクションの脆弱性がある。(a) どのような攻撃が可能か説明し、(b) 安全な書き方に修正せよ。

```python
def search_products(conn, category, min_price):
    query = f"""
        SELECT * FROM products
        WHERE category = '{category}'
          AND price >= {min_price}
        ORDER BY price
    """
    return conn.execute(query).fetchall()
```


**あなたの解答:**

```

```

<details><summary>解答</summary>

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

パラメタライズドクエリを使うことで、入力値は SQL 構文として解釈されず、常にリテラル値として扱われる。

</details>

---

## 問題6: Upsert (INSERT ... ON CONFLICT)

以下の `user_preferences` テーブルに対して、`(user_id, key)` の組が既に存在すれば `value` と `updated_at` を更新し、なければ新規挿入するクエリを書け。

```sql
CREATE TABLE user_preferences (
    user_id    INT NOT NULL,
    key        TEXT NOT NULL,
    value      TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, key)
);
```


**あなたの解答:**

```

```

<details><summary>解答</summary>

```sql
INSERT INTO user_preferences (user_id, key, value, updated_at)
VALUES (1, 'language', 'ja', NOW())
ON CONFLICT (user_id, key)
DO UPDATE SET
    value      = EXCLUDED.value,
    updated_at = NOW();
```

`EXCLUDED` は挿入しようとした行を参照する擬似テーブル。`ON CONFLICT` 句には主キーまたはユニーク制約のカラムを指定する。

</details>

---

## 問題7: ページネーション

`products` テーブルを `price DESC, id ASC` の順で表示する一覧画面を実装する。1ページ10件とする。

1. OFFSET 方式で3ページ目を取得するクエリを書け。
2. OFFSET 方式の問題点を述べ、カーソルベース方式で「前ページ最後の行が `(price=500, id=42)`」のとき次のページを取得するクエリを書け。


**あなたの解答:**

```

```

<details><summary>解答</summary>

```sql
-- 1. OFFSET 方式（3ページ目）
SELECT * FROM products
ORDER BY price DESC, id ASC
LIMIT 10 OFFSET 20;

-- 2. カーソルベース方式
SELECT * FROM products
WHERE (price, id) < (500, 42)
   -- price DESC なので < を使う（同価格は id ASC で区別）
   -- 正確には行値比較: (price < 500) OR (price = 500 AND id > 42)
ORDER BY price DESC, id ASC
LIMIT 10;
```

**OFFSET の問題点:**

- OFFSET 値が大きいほどスキップ対象行もスキャンするため O(n) で遅くなる
- ページ間でデータの挿入・削除があると行の重複・抜けが発生する

**補足:** 複合ソートでの行値比較 `(price, id) < (500, 42)` は辞書順比較になるため、`price DESC, id ASC` の混合順序では正確に機能しない場合がある。その場合は条件を明示的に書く:

```sql
WHERE price < 500
   OR (price = 500 AND id > 42)
```

</details>

---

## 問題8: Top-N per Group

各カテゴリ（`category`）の中で価格が高い上位2件の商品を取得するクエリを書け。同価格の場合は `id` が小さい方を優先する。


**あなたの解答:**

```

```

<details><summary>解答</summary>

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

`ROW_NUMBER()` は同値でも必ず異なる番号を振るため、Top-N の取得に適している。`RANK()` を使うと同値が同順位になり、N 件を超える可能性がある。

</details>

---

## 問題9: ギャップ・アンド・アイランド

以下のテーブルで、各ユーザの**最長連続ログイン日数**を求めるクエリを書け。

```sql
CREATE TABLE logins (
    user_id    INT NOT NULL,
    login_date DATE NOT NULL,
    PRIMARY KEY (user_id, login_date)
);
```


**あなたの解答:**

```

```

<details><summary>解答</summary>

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

</details>

---

## 問題10: 総合問題 — トリガーによる在庫管理

以下のテーブルがある:

```sql
CREATE TABLE inventory (
    product_id INT PRIMARY KEY REFERENCES products(id),
    stock      INT NOT NULL DEFAULT 0 CHECK (stock >= 0)
);
```

`orders` テーブルに INSERT されたとき、対応する `inventory.stock` を `quantity` 分だけ自動的に減らすトリガーを作成せよ。在庫不足の場合は例外を発生させること。


**あなたの解答:**

```

```

<details><summary>解答</summary>

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

`FOR UPDATE` で在庫行をロックすることで、同時注文時の競合（レースコンディション）を防止する。`RAISE EXCEPTION` によりトランザクション全体がロールバックされ、不正な注文は確定しない。

</details>
