# 第5回 演習: 実務応用パターン (Practical Patterns)

> 解答は [answers.md](./answers.md) を参照してください。自分で解いてから確認することを推奨します。

## サンプルデータ

`make setup` でサンプルデータが投入されます（`setup/schema.sql` + `setup/seed.sql`）。

```
departments : 6行  (開発部/営業部/人事部/経理部/マーケティング部/法務部)
employees   : 14行 (給与 350,000〜600,000、2019〜2024年入社)
products    : 8行  (電子機器/家具/文具)
orders      : 15行 (2024年1月〜8月)
api_logs    : 6行  (JSONB ペイロード付き)
logins      : 19行 (ユーザー3名分の連続ログイン履歴)
inventory   : 8行  (商品在庫)
```

スキーマ参照:
```sql
-- departments(id, name, location)
-- employees(id, name, email, department_id, salary, hire_date, manager_id)
-- products(id, name, category, price)
-- orders(id, user_id, product_id, quantity, amount, order_date)
-- api_logs(id, endpoint, payload JSONB, created_at)
-- logins(user_id, login_date)
-- inventory(product_id, stock)
```

---

## 問題1: VIEW の作成と利用

各部署の人数と平均給与を返すビュー `department_stats` を作成せよ。カラムは `department_id`, `department_name`, `employee_count`, `avg_salary`（整数に丸める）とする。

**期待される出力 (`SELECT * FROM department_stats ORDER BY avg_salary DESC NULLS LAST;`):**
```
 department_id | department_name   | employee_count | avg_salary
---------------+-------------------+----------------+------------
             4 | 経理部            |              1 |     550000
             1 | 開発部            |              4 |     512500
             5 | マーケティング部   |              3 |     493333
             3 | 人事部            |              2 |     455000
             2 | 営業部            |              3 |     436667
             6 | 法務部            |              0 |       NULL
```
※ 法務部は従業員0人のため avg_salary = NULL。

**あなたの解答:**

```sql

```

---

## 問題2: MATERIALIZED VIEW とリフレッシュ

月別の注文集計（月、合計金額、注文数）をマテリアライズドビュー `monthly_order_summary` として作成せよ。さらに、ロックなしでリフレッシュできるようにせよ。

**期待される出力 (作成後に `SELECT * FROM monthly_order_summary ORDER BY month;`):**
```
    month     | total_amount | order_count
--------------+--------------+-------------
 2024-01-01   |       129000 |           2
 2024-02-01   |       150000 |           2
 2024-03-01   |       248000 |           2
 2024-04-01   |        85000 |           2
 2024-05-01   |        19000 |           2
 2024-06-01   |       165000 |           2
 2024-07-01   |       136000 |           2
 2024-08-01   |       120000 |           1
```

**あなたの解答:**

```sql

```

---

## 問題3: JSONB クエリ

以下のテーブルがある (`setup/seed.sql` で6件挿入済み):

```sql
CREATE TABLE api_logs (
    id         SERIAL PRIMARY KEY,
    endpoint   TEXT NOT NULL,
    payload    JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

サンプルデータの `payload`:
```json
{"user_id": 5, "action": "login",    "metadata": {"ip": "192.168.1.1", "device": "mobile"}}
{"user_id": 3, "action": "login",    "metadata": {"ip": "10.0.0.5",    "device": "desktop"}}
{"user_id": 3, "action": "purchase", "items": [{"sku": "A001", "qty": 2}, {"sku": "B010", "qty": 1}]}
{"user_id": 5, "action": "purchase", "items": [{"sku": "C003", "qty": 1}]}
{"user_id": 1, "action": "logout",   "metadata": {"ip": "192.168.1.2", "device": "mobile"}}
{"user_id": 2, "action": "update",   "metadata": {"ip": "172.16.0.1",  "device": "desktop"}}
```

以下の3つのクエリを書け:

1. `action` が `'purchase'` のログを取得
2. `metadata` の `device` が `'mobile'` のログを取得
3. `payload` に `items` キーが存在するログの件数を取得

**期待される出力:**

1. purchase (2行):
```
 id | endpoint    | payload
----+-------------+--------------------------
  3 | /api/orders | {"user_id": 3, "action": "purchase", ...}
  4 | /api/orders | {"user_id": 5, "action": "purchase", ...}
```

2. mobile (2行):
```
 id | endpoint  | payload
----+-----------+-------------------------------------
  1 | /api/auth | {"user_id": 5, "action": "login", "metadata": {"device": "mobile", ...}}
  5 | /api/auth | {"user_id": 1, "action": "logout", "metadata": {"device": "mobile", ...}}
```

3. items キー存在 (1行):
```
 count
-------
     2
```

**あなたの解答:**

```sql

```

---

## 問題4: PL/pgSQL 関数

引数として `department_id` を受け取り、その部署の従業員数に応じて以下の文字列を返す関数 `dept_size(dept_id INT)` を作成せよ:

- 0人: `'empty'`
- 1〜5人: `'small'`
- 6〜20人: `'medium'`
- 21人以上: `'large'`

**期待される出力 (`SELECT d.id, d.name, dept_size(d.id) FROM departments d ORDER BY d.id;`):**
```
 id |    name          | dept_size
----+------------------+-----------
  1 | 開発部            | small
  2 | 営業部            | small
  3 | 人事部            | small
  4 | 経理部            | small
  5 | マーケティング部   | small
  6 | 法務部            | empty
```

**あなたの解答:**

```sql

```

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

---

## 問題6: Upsert (INSERT ... ON CONFLICT)

以下の `user_preferences` テーブルに対して、`(user_id, key)` の組が既に存在すれば `value` と `updated_at` を更新し、なければ新規挿入するクエリを書け。

```sql
-- テーブルは setup/schema.sql で作成済み
-- user_preferences(user_id, key, value, updated_at)
```

**期待される動作:**

```sql
-- 1回目: 新規挿入される
INSERT INTO user_preferences (user_id, key, value) VALUES (1, 'language', 'en')
ON CONFLICT ... ;
-- → INSERT 1

-- 2回目: 同じ (user_id=1, key='language') で value を更新
INSERT INTO user_preferences (user_id, key, value) VALUES (1, 'language', 'ja')
ON CONFLICT ... ;
-- → UPDATE 1  (value が 'en' → 'ja' に更新される)
```

**あなたの解答:**

```sql

```

---

## 問題7: ページネーション

`products` テーブルを `price DESC, id ASC` の順で表示する一覧画面を実装する。1ページ10件とする。

1. OFFSET 方式で3ページ目を取得するクエリを書け。
2. OFFSET 方式の問題点を述べ、カーソルベース方式で「前ページ最後の行が `(price=500, id=42)`」のとき次のページを取得するクエリを書け。

**あなたの解答:**

```sql

```

---

## 問題8: Top-N per Group

各カテゴリ（`category`）の中で価格が高い上位2件の商品を取得するクエリを書け。同価格の場合は `id` が小さい方を優先する。

**期待される出力 (6行):**
```
 id |    name      | category | price
----+--------------+----------+--------
  6 | デスク        | 家具     |  80000
  5 | デスクチェア   | 家具     |  60000
  1 | ノートPC      | 電子機器  | 120000
  4 | モニター       | 電子機器  |  45000
  7 | ノート         | 文具    |    500
  8 | ボールペン     | 文具    |    200
```

**あなたの解答:**

```sql

```

---

## 問題9: ギャップ・アンド・アイランド

`logins` テーブル（`setup/seed.sql` で3ユーザー分の連続ログイン履歴を投入済み）を使い、各ユーザの**最長連続ログイン日数**を求めるクエリを書け。

```sql
-- logins(user_id, login_date) のサンプルデータ:
-- user_id=1: 1/1〜1/5 (5日連続), 1/8〜1/10 (3日連続) → 最長5日
-- user_id=2: 1/1〜1/3 (3日連続), 1/6〜1/9 (4日連続) → 最長4日
-- user_id=3: 1/2〜1/3 (2日連続), 1/7 (1日)          → 最長2日
```

**期待される出力 (3行):**
```
 user_id | max_streak
---------+------------
       1 |          5
       2 |          4
       3 |          2
```

**あなたの解答:**

```sql

```

---

## 問題10: 総合問題 — トリガーによる在庫管理

以下のテーブルがある (`setup/schema.sql` / `setup/seed.sql` で作成・投入済み):

```sql
-- inventory(product_id, stock)  ← 現在の在庫数
-- orders(id, user_id, product_id, quantity, amount, order_date)
```

`orders` テーブルに INSERT されたとき、対応する `inventory.stock` を `quantity` 分だけ自動的に減らすトリガーを作成せよ。在庫不足の場合は例外を発生させること。

**動作確認用:**
```sql
-- ノートPC(product_id=1)の在庫確認: stock=5
SELECT * FROM inventory WHERE product_id = 1;

-- 在庫を超える注文 → RAISE EXCEPTION が発生すること
INSERT INTO orders (user_id, product_id, quantity, amount)
VALUES (1, 1, 10, 1200000);
-- ERROR: 在庫不足: 商品ID 1, 現在庫 5, 要求数 10

-- 正常注文: stock が 5→3 に減ること
INSERT INTO orders (user_id, product_id, quantity, amount)
VALUES (1, 1, 2, 240000);
SELECT stock FROM inventory WHERE product_id = 1;  -- → 3
```

**あなたの解答:**

```sql

```
