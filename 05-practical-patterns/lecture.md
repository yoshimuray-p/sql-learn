# 第5回: 実務応用パターン (Practical Patterns)

---

## 1. ビュー (VIEW)

### 1.1 基本構文

ビューは保存されたクエリに名前を付けたもの。データ自体は持たない。

```sql
CREATE VIEW active_users AS
SELECT id, name, email, last_login
FROM users
WHERE status = 'active';

-- 通常のテーブルと同様に使用
SELECT * FROM active_users WHERE last_login > CURRENT_DATE - 30;
```

```sql
-- 置き換え（存在すれば上書き）
CREATE OR REPLACE VIEW active_users AS
SELECT id, name, email, last_login, role
FROM users
WHERE status = 'active';

DROP VIEW IF EXISTS active_users;
```

### 1.2 更新可能ビュー (Updatable Views)

以下の条件をすべて満たすビューは直接 INSERT / UPDATE / DELETE できる:

- FROM に単一テーブル
- DISTINCT, GROUP BY, HAVING, LIMIT, OFFSET なし
- UNION / INTERSECT / EXCEPT なし
- 集約関数・ウィンドウ関数なし

```sql
CREATE VIEW tokyo_users AS
SELECT id, name, email, city
FROM users
WHERE city = '東京';

-- ビュー経由の更新
UPDATE tokyo_users SET email = 'new@example.com' WHERE id = 1;
```

`WITH CHECK OPTION` を付けるとビュー条件を満たさない行の挿入・更新を防止できる:

```sql
CREATE VIEW tokyo_users AS
SELECT id, name, email, city
FROM users
WHERE city = '東京'
WITH CHECK OPTION;

-- エラー: city が条件を満たさない
INSERT INTO tokyo_users (name, email, city) VALUES ('太郎', 'a@b.com', '大阪');
```

### 1.3 ユースケース

| 用途 | 説明 |
|------|------|
| アクセス制御 | 特定カラムだけ公開するビューを作成し権限を付与 |
| 複雑なクエリの抽象化 | 多段 JOIN を隠蔽して利用側を簡素化 |
| 後方互換 | テーブル構造変更時に旧インタフェースをビューで維持 |

---

## 2. マテリアライズドビュー (MATERIALIZED VIEW)

通常のビューと異なり**結果を物理的に保存**する。読み取り専用。

```sql
CREATE MATERIALIZED VIEW monthly_sales AS
SELECT
    date_trunc('month', order_date) AS month,
    SUM(amount)                     AS total,
    COUNT(*)                        AS order_count
FROM orders
GROUP BY 1;
```

### 2.1 リフレッシュ (REFRESH)

```sql
-- 排他ロックあり（読み取りもブロック）
REFRESH MATERIALIZED VIEW monthly_sales;

-- CONCURRENTLY: ロックせずリフレッシュ（UNIQUE INDEX が必要）
CREATE UNIQUE INDEX ON monthly_sales (month);
REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_sales;
```

### 2.2 VIEW vs MATERIALIZED VIEW

| 項目 | VIEW | MATERIALIZED VIEW |
|------|------|-------------------|
| データ保持 | なし（毎回クエリ実行） | あり（物理保存） |
| 更新 | 自動（元テーブル反映） | 手動 REFRESH |
| 速度 | 元クエリ依存 | 事前計算済みで高速 |
| 用途 | 抽象化・アクセス制御 | 集計キャッシュ・レポート |

---

## 3. JSON/JSONB

PostgreSQL は JSON 型を2種サポート。実務では**常に JSONB を使う**（バイナリ格納で高速・インデックス可能）。

### 3.1 格納

```sql
CREATE TABLE events (
    id    SERIAL PRIMARY KEY,
    name  TEXT NOT NULL,
    data  JSONB NOT NULL DEFAULT '{}'
);

INSERT INTO events (name, data) VALUES
('click', '{"page": "/home", "x": 120, "y": 450}'),
('purchase', '{"item_id": 42, "price": 1980, "tags": ["sale", "electronics"]}');
```

### 3.2 演算子 (Operators)

| 演算子 | 返り値型 | 説明 | 例 |
|--------|---------|------|-----|
| `->` | JSON | キーまたはインデックスで要素取得 | `data -> 'page'` → `"/home"` |
| `->>` | TEXT | テキストとして取得 | `data ->> 'page'` → `/home` |
| `#>` | JSON | パスで深い要素取得 | `data #> '{a,b}'` |
| `#>>` | TEXT | パスでテキスト取得 | `data #>> '{a,b}'` |
| `@>` | BOOL | 左が右を含むか | `data @> '{"page":"/home"}'` |
| `?` | BOOL | キーが存在するか | `data ? 'page'` |
| `?|` | BOOL | いずれかのキーが存在 | `data ?| array['page','user']` |
| `?&` | BOOL | すべてのキーが存在 | `data ?& array['page','user']` |

```sql
-- page が '/home' のイベントを取得
SELECT * FROM events WHERE data ->> 'page' = '/home';

-- tags 配列に 'sale' を含む
SELECT * FROM events WHERE data @> '{"tags": ["sale"]}';

-- price が 1000 以上（テキスト比較を避けるためキャスト）
SELECT * FROM events WHERE (data ->> 'price')::int >= 1000;
```

### 3.3 JSONB 関数

```sql
-- オブジェクト構築
SELECT jsonb_build_object('name', u.name, 'email', u.email)
FROM users u;

-- 集約: 複数行を JSON 配列に
SELECT jsonb_agg(jsonb_build_object('id', id, 'name', name))
FROM users
WHERE status = 'active';

-- キー・値の展開
SELECT * FROM jsonb_each_text('{"a":"1","b":"2"}'::jsonb);

-- 配列要素の展開
SELECT * FROM jsonb_array_elements('[1,2,3]'::jsonb);

-- マージ（||演算子）
SELECT '{"a":1}'::jsonb || '{"b":2}'::jsonb;
-- => {"a":1, "b":2}
```

### 3.4 GIN インデックス

```sql
-- デフォルト: @>, ?, ?|, ?& をサポート
CREATE INDEX idx_events_data ON events USING GIN (data);

-- jsonb_path_ops: @> のみだがサイズが小さく高速
CREATE INDEX idx_events_data ON events USING GIN (data jsonb_path_ops);
```

GIN インデックスがあれば `data @> '{"page":"/home"}'` はインデックススキャンになる。`data ->> 'key' = 'val'` は GIN では効かないため、B-tree 式インデックスを使う:

```sql
CREATE INDEX idx_events_page ON events ((data ->> 'page'));
```

---

## 4. PL/pgSQL 基礎

### 4.1 基本構造

```sql
CREATE OR REPLACE FUNCTION greet(username TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    result TEXT;
BEGIN
    result := 'こんにちは、' || username || 'さん';
    RETURN result;
END;
$$;

SELECT greet('太郎');  -- => 'こんにちは、太郎さん'
```

### 4.2 制御構文

```sql
CREATE OR REPLACE FUNCTION classify_score(score INT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    IF score >= 90 THEN
        RETURN 'A';
    ELSIF score >= 70 THEN
        RETURN 'B';
    ELSIF score >= 50 THEN
        RETURN 'C';
    ELSE
        RETURN 'F';
    END IF;
END;
$$;
```

### 4.3 ループ

```sql
CREATE OR REPLACE FUNCTION factorial(n INT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    result BIGINT := 1;
    i INT;
BEGIN
    FOR i IN 1..n LOOP
        result := result * i;
    END LOOP;
    RETURN result;
END;
$$;
```

### 4.4 テーブル操作とレコード返却

```sql
-- SETOF で複数行返却
CREATE OR REPLACE FUNCTION get_recent_orders(user_id INT, n INT DEFAULT 5)
RETURNS SETOF orders
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
        SELECT *
        FROM orders o
        WHERE o.user_id = get_recent_orders.user_id
        ORDER BY o.order_date DESC
        LIMIT n;
END;
$$;

SELECT * FROM get_recent_orders(42, 10);
```

### 4.5 いつ使うか

- **使うべき場面**: 複雑なビジネスロジックの一括処理、データマイグレーション、監査ログ
- **避けるべき場面**: 単純な CRUD（アプリ側で十分）、頻繁に変更されるロジック（デプロイが煩雑）

---

## 5. トリガー (Triggers)

テーブルへの INSERT / UPDATE / DELETE 時に自動的に関数を実行する仕組み。

### 5.1 基本構文

```sql
-- 1. トリガー関数を作成（RETURNS TRIGGER）
CREATE OR REPLACE FUNCTION audit_log_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO audit_log (table_name, operation, row_id, changed_at, old_data, new_data)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        COALESCE(NEW.id, OLD.id),
        NOW(),
        to_jsonb(OLD),
        to_jsonb(NEW)
    );
    RETURN NEW;  -- BEFORE トリガーでは RETURN NEW が必須
END;
$$;

-- 2. トリガーを紐づけ
CREATE TRIGGER trg_users_audit
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_trigger();
```

### 5.2 BEFORE vs AFTER

| タイミング | 用途 |
|-----------|------|
| BEFORE | 値の検証・自動補完（例: `NEW.updated_at := NOW()`） |
| AFTER | 監査ログ・通知・他テーブルへの連鎖更新 |

`FOR EACH ROW`（行レベル）と `FOR EACH STATEMENT`（文レベル）がある。実務では行レベルが多い。

---

## 6. SQL インジェクション (SQL Injection)

### 6.1 仕組み

ユーザ入力を文字列連結で SQL に埋め込むと、意図しない SQL が実行される。

```python
# 危険: 文字列連結
username = request.form['username']
query = f"SELECT * FROM users WHERE name = '{username}'"
# username に ' OR '1'='1 を入れると全行が返る
```

攻撃例:
```
入力: ' OR '1'='1' --
結果: SELECT * FROM users WHERE name = '' OR '1'='1' --'
```

### 6.2 対策: パラメタライズドクエリ (Parameterized Queries)

```python
# Python (psycopg2)
cursor.execute("SELECT * FROM users WHERE name = %s", (username,))

# Python (SQLAlchemy)
stmt = text("SELECT * FROM users WHERE name = :name")
result = conn.execute(stmt, {"name": username})
```

```sql
-- PostgreSQL PREPARE 文
PREPARE user_query(text) AS
    SELECT * FROM users WHERE name = $1;

EXECUTE user_query('太郎');
```

**原則**: ユーザ入力は常にパラメータとしてバインドし、SQL 文字列に直接埋め込まない。

---

## 7. 実務頻出クエリパターン

### 7.1 Upsert (INSERT ... ON CONFLICT)

「存在すれば更新、なければ挿入」を1文で実現。

```sql
INSERT INTO user_settings (user_id, key, value)
VALUES (1, 'theme', 'dark')
ON CONFLICT (user_id, key)
DO UPDATE SET value = EXCLUDED.value;

-- 何もしない場合
INSERT INTO users (email, name)
VALUES ('a@b.com', '太郎')
ON CONFLICT (email) DO NOTHING;
```

`EXCLUDED` は挿入しようとした行を指す擬似テーブル。

### 7.2 バルク操作 (Bulk Operations)

```sql
-- 複数行 INSERT
INSERT INTO products (name, price) VALUES
    ('A', 100),
    ('B', 200),
    ('C', 300);

-- COPY: 大量データのインポート/エクスポート（最速）
COPY products (name, price) FROM '/tmp/products.csv' WITH (FORMAT csv, HEADER true);
COPY (SELECT * FROM products) TO '/tmp/export.csv' WITH (FORMAT csv, HEADER true);
```

`COPY` は INSERT の 10〜100 倍高速。数万行以上のデータ投入では必ず検討する。

### 7.3 ページネーション (Pagination)

**OFFSET 方式**（小規模向け）:

```sql
-- ページ3（1ページ20件）
SELECT * FROM products ORDER BY id LIMIT 20 OFFSET 40;
```

問題: OFFSET が大きいほど遅くなる（スキップ分もスキャンする）。

**カーソルベース方式**（大規模向け・推奨）:

```sql
-- 最初のページ
SELECT * FROM products ORDER BY id LIMIT 20;

-- 次のページ（前ページ最後の id を使用）
SELECT * FROM products WHERE id > 前ページ最後のid ORDER BY id LIMIT 20;
```

インデックスが効くため O(log n) で安定した速度。

### 7.4 ピボット / クロス集計 (Pivoting / Crosstab)

行を列に変換する。

```sql
-- CASE + 集約で手動ピボット
SELECT
    product_id,
    SUM(CASE WHEN quarter = 'Q1' THEN revenue END) AS q1,
    SUM(CASE WHEN quarter = 'Q2' THEN revenue END) AS q2,
    SUM(CASE WHEN quarter = 'Q3' THEN revenue END) AS q3,
    SUM(CASE WHEN quarter = 'Q4' THEN revenue END) AS q4
FROM quarterly_sales
GROUP BY product_id;
```

```sql
-- tablefunc 拡張の crosstab
CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT * FROM crosstab(
    'SELECT product_id, quarter, revenue FROM quarterly_sales ORDER BY 1, 2',
    $$VALUES ('Q1'), ('Q2'), ('Q3'), ('Q4')$$
) AS ct(product_id INT, q1 NUMERIC, q2 NUMERIC, q3 NUMERIC, q4 NUMERIC);
```

### 7.5 ギャップ・アンド・アイランド問題 (Gap-and-Island)

連続する値のグループ（島）と欠落（ギャップ）を検出するパターン。

例: 連続ログイン日数を求める。

```sql
-- テーブル: logins(user_id, login_date) ※重複なし
WITH numbered AS (
    SELECT
        user_id,
        login_date,
        login_date - ROW_NUMBER() OVER (
            PARTITION BY user_id ORDER BY login_date
        )::int AS grp
    FROM logins
)
SELECT
    user_id,
    MIN(login_date) AS streak_start,
    MAX(login_date) AS streak_end,
    COUNT(*)        AS streak_days
FROM numbered
GROUP BY user_id, grp
ORDER BY user_id, streak_start;
```

**原理**: 連続する日付から連番を引くと、連続グループ内では同じ値になる。

### 7.6 累積差分・累積計算 (Running Difference / Cumulative)

```sql
-- 前日比の売上差分
SELECT
    order_date,
    daily_total,
    daily_total - LAG(daily_total) OVER (ORDER BY order_date) AS diff,
    SUM(daily_total) OVER (ORDER BY order_date) AS cumulative
FROM daily_sales;

-- 在庫の残高推移
SELECT
    transaction_date,
    quantity,
    SUM(quantity) OVER (
        PARTITION BY product_id
        ORDER BY transaction_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_stock
FROM inventory_transactions;
```

### 7.7 グループ内 Top-N (Top-N per Group)

各カテゴリの上位 N 件を取得する。

```sql
-- 各部署の給与上位3名
SELECT *
FROM (
    SELECT
        e.*,
        ROW_NUMBER() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rn
    FROM employees e
) ranked
WHERE rn <= 3;

-- LATERAL JOIN を使う方法
SELECT d.name AS dept, e.*
FROM departments d
CROSS JOIN LATERAL (
    SELECT *
    FROM employees
    WHERE department_id = d.id
    ORDER BY salary DESC
    LIMIT 3
) e;
```

---

## まとめ

| パターン | キーワード | 主な用途 |
|---------|-----------|---------|
| VIEW | CREATE VIEW | クエリの抽象化・権限制御 |
| MATERIALIZED VIEW | REFRESH CONCURRENTLY | 集計キャッシュ |
| JSONB | `@>`, `?`, GIN | スキーマレスデータ |
| PL/pgSQL | CREATE FUNCTION | サーバサイドロジック |
| TRIGGER | BEFORE/AFTER | 監査・自動更新 |
| Upsert | ON CONFLICT | 冪等な挿入 |
| Bulk | COPY | 大量データ投入 |
| Pagination | カーソルベース | 大規模一覧表示 |
| Pivot | CASE + 集約 | レポート |
| Gap-and-Island | ROW_NUMBER 差分 | 連続区間検出 |
| Top-N per Group | ROW_NUMBER + PARTITION | カテゴリ別ランキング |
