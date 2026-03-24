# 第5回 自己解答: 実務応用パターン (Practical Patterns)

スキーマ参照:
```sql
-- departments(id, name, location)
-- employees(id, name, email, department_id, salary, hire_date, manager_id)
-- products(id, name, category, price)
-- orders(id, user_id, product_id, quantity, amount, order_date)
-- api_logs(id, endpoint, payload JSONB, created_at)
-- logins(user_id, login_date)
-- inventory(product_id, stock)
-- user_preferences(user_id, key, value, updated_at)
```

---

## 問題1: VIEW の作成と利用

各部署の人数と平均給与を返すビュー `department_stats` を作成せよ。カラムは `department_id`, `department_name`, `employee_count`, `avg_salary`（整数に丸める）とする。

```sql

```

---

## 問題2: MATERIALIZED VIEW とリフレッシュ

月別の注文集計（月、合計金額、注文数）をマテリアライズドビュー `monthly_order_summary` として作成せよ。さらに、ロックなしでリフレッシュできるようにせよ。

```sql

```

---

## 問題3: JSONB クエリ

以下の3つのクエリを書け:

1. `action` が `'purchase'` のログを取得
2. `metadata` の `device` が `'mobile'` のログを取得
3. `payload` に `items` キーが存在するログの件数を取得

**1. purchase のログ:**

```sql

```

**2. mobile のログ:**

```sql

```

**3. items キーの件数:**

```sql

```

---

## 問題4: PL/pgSQL 関数

引数として `department_id` を受け取り、その部署の従業員数に応じて以下の文字列を返す関数 `dept_size(dept_id INT)` を作成せよ:

- 0人: `'empty'`
- 1〜5人: `'small'`
- 6〜20人: `'medium'`
- 21人以上: `'large'`

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

**(a) 攻撃例:**

```

```

**(b) 修正版:**

```python

```

---

## 問題6: Upsert (INSERT ... ON CONFLICT)

`user_preferences` テーブルに対して、`(user_id, key)` の組が既に存在すれば `value` と `updated_at` を更新し、なければ新規挿入するクエリを書け。

```sql

```

---

## 問題7: ページネーション

`products` テーブルを `price DESC, id ASC` の順で表示する一覧画面（1ページ10件）を実装する。

1. OFFSET 方式で3ページ目を取得するクエリを書け。
2. OFFSET 方式の問題点を述べ、カーソルベース方式で「前ページ最後の行が `(price=500, id=42)`」のとき次のページを取得するクエリを書け。

**1. OFFSET 方式:**

```sql

```

**2. OFFSET の問題点:**

```

```

**カーソルベース方式:**

```sql

```

---

## 問題8: Top-N per Group

各カテゴリ（`category`）の中で価格が高い上位2件の商品を取得するクエリを書け。同価格の場合は `id` が小さい方を優先する。

```sql

```

---

## 問題9: ギャップ・アンド・アイランド

`logins` テーブルを使い、各ユーザの**最長連続ログイン日数**を求めるクエリを書け。

```sql
-- logins(user_id, login_date) のサンプルデータ:
-- user_id=1: 1/1〜1/5 (5日連続), 1/8〜1/10 (3日連続) → 最長5日
-- user_id=2: 1/1〜1/3 (3日連続), 1/6〜1/9 (4日連続) → 最長4日
-- user_id=3: 1/2〜1/3 (2日連続), 1/7 (1日)          → 最長2日
```

```sql

```

---

## 問題10: 総合問題 — トリガーによる在庫管理

`orders` テーブルに INSERT されたとき、対応する `inventory.stock` を `quantity` 分だけ自動的に減らすトリガーを作成せよ。在庫不足の場合は例外を発生させること。

**トリガー関数:**

```sql

```

**トリガー作成:**

```sql

```
