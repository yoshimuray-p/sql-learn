# 第3回 解答: テーブル設計 (Table Design)

---

## 演習1: ECサイトの基本テーブル作成

```sql
CREATE TABLE customers (
    customer_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT NOT NULL CHECK (char_length(name) <= 100),
    email       TEXT NOT NULL UNIQUE,
    phone       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    order_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  INTEGER NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    ordered_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    status       TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'shipped', 'delivered', 'cancelled')),
    total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0)
);
```

---

## 演習2: ALTER TABLE によるスキーマ変更

```sql
-- 1. カラム追加
ALTER TABLE customers ADD COLUMN address TEXT;

-- 2. カラム名変更
ALTER TABLE customers RENAME COLUMN phone TO phone_number;

-- 3. カラム分割（既存データがある場合はマイグレーション処理が別途必要）
ALTER TABLE customers ADD COLUMN first_name TEXT;
ALTER TABLE customers ADD COLUMN last_name TEXT;
-- 既存データの移行（例: nameを姓名に分割する場合）
-- UPDATE customers SET first_name = split_part(name, ' ', 1), last_name = split_part(name, ' ', 2);
ALTER TABLE customers ALTER COLUMN first_name SET NOT NULL;
ALTER TABLE customers ALTER COLUMN last_name SET NOT NULL;
ALTER TABLE customers DROP COLUMN name;

-- 4. CHECK制約の追加
ALTER TABLE customers ADD CONSTRAINT email_length_check
    CHECK (char_length(email) <= 254);
```

---

## 演習3: 外部キーの ON DELETE 挙動

1. **`ON DELETE SET NULL`** または **`ON DELETE RESTRICT`**
   - ブログ記事はユーザー削除後も公開を続けたい場合が多い。`SET NULL` で著者を「不明」にする。
   - 記事が残るとまずい場合は `RESTRICT` で削除を拒否し、先に記事を処理させる。

```sql
author_id INTEGER REFERENCES users(user_id) ON DELETE SET NULL
```

2. **`ON DELETE CASCADE`**
   - セッションログはユーザーに完全に従属するデータ。ユーザー削除時に一緒に消して問題ない。

```sql
user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE
```

3. **`ON DELETE SET NULL`**
   - タスクは社員退職後も残すべき。担当者を `NULL`（未アサイン）にして再割り当てできるようにする。

```sql
assignee_id INTEGER REFERENCES employees(employee_id) ON DELETE SET NULL
```

---

## 演習4: 正規形の判定

**1NF** である（すべてのカラムが原子値を持つ）。しかし 2NF ではない。

**2NF 違反の理由**:
- `student_id → student_name`: 候補キーの一部（`student_id`）のみへの部分関数従属
- `course_id → course_name, instructor, instructor_office`: 候補キーの一部（`course_id`）のみへの部分関数従属

さらに 3NF 違反もある:
- `instructor → instructor_office`: 非キー属性間の推移的関数従属

**3NF への正規化**:

```sql
CREATE TABLE students (
    student_id   INTEGER PRIMARY KEY,
    student_name TEXT NOT NULL
);

CREATE TABLE instructors (
    instructor_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          TEXT NOT NULL,
    office        TEXT NOT NULL
);

CREATE TABLE courses (
    course_id     TEXT PRIMARY KEY,
    course_name   TEXT NOT NULL,
    instructor_id INTEGER NOT NULL REFERENCES instructors(instructor_id)
);

CREATE TABLE enrollments (
    student_id INTEGER REFERENCES students(student_id),
    course_id  TEXT REFERENCES courses(course_id),
    PRIMARY KEY (student_id, course_id)
);
```

---

## 演習5: 非正規テーブルの正規化

**Step 1: 1NF** — 繰り返しグループ（items, prices）を展開

**Step 2: 2NF** — 部分関数従属を除去

**Step 3: 3NF** — 推移的関数従属を除去（`store_name → store_city`、`customer_name → customer_city`）

```sql
CREATE TABLE customers (
    customer_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT NOT NULL,
    city        TEXT NOT NULL
);

CREATE TABLE stores (
    store_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name     TEXT NOT NULL,
    city     TEXT NOT NULL
);

CREATE TABLE products (
    product_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE,
    price      NUMERIC(10, 2) NOT NULL
);

CREATE TABLE sales (
    sale_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sale_date   DATE NOT NULL,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    store_id    INTEGER NOT NULL REFERENCES stores(store_id)
);

CREATE TABLE sale_items (
    sale_id    INTEGER REFERENCES sales(sale_id),
    product_id INTEGER REFERENCES products(product_id),
    quantity   INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL,  -- 販売時点の価格
    PRIMARY KEY (sale_id, product_id)
);
```

---

## 演習6: インデックス設計

```sql
-- クエリA: 複合インデックス（等値 → ソート順）
CREATE INDEX idx_orders_user_date ON orders (user_id, ordered_at DESC);

-- クエリB: 式インデックス
CREATE INDEX idx_users_email_lower ON users (lower(email));

-- クエリC: 部分インデックス（pendingのみインデックス化）
CREATE INDEX idx_orders_pending ON orders (ordered_at)
    WHERE status = 'pending';

-- クエリD: GINインデックス（JSONB用）
CREATE INDEX idx_products_attrs ON products USING gin (attributes);

-- クエリE: 複合インデックス + 部分インデックス
CREATE INDEX idx_products_category_price ON products (category_id, price)
    WHERE is_active = true;
```

**解説**:
- **A**: `user_id` で等値フィルタした後、`ordered_at DESC` でソート。インデックスのソート順を `DESC` にすることで `ORDER BY` のソートを回避
- **B**: `lower()` 関数の結果をインデックス化。クエリ側も `lower()` を使う必要がある
- **C**: `status = 'pending'` の行だけにインデックスを限定。全注文の中で pending は少数であることが多く、インデックスサイズが小さくなる
- **D**: JSONB の包含演算子 `@>` は GIN インデックスで高速化される
- **E**: アクティブ商品のみの部分インデックス。`category_id`（等値）を先、`price`（ソート）を後に配置

---

## 演習7: 複合インデックスの有効性判定

1. **使われる** — 左端カラム `department_id` を使用
2. **使われない** — 左端カラム `department_id` をスキップしている（Index Skip Scan が使える場合もあるが、PostgreSQL では限定的）
3. **部分的に使われる** — `department_id` でインデックスを絞り込むが、`hire_date` をスキップして `salary` でフィルタするため、`salary > 50000` の条件はインデックス内で効率的に使えない。`department_id = 5` での絞り込みのみインデックスが使われる
4. **部分的に使われる** — `department_id`（等値）と `hire_date`（範囲）はインデックスで処理できる。ただし `hire_date` が範囲条件のため、その後ろの `salary` でのソートにはインデックスが使えず、追加のソートが発生する
5. **使われる** — `department_id IN (...)` は複数の等値条件として扱われ、各値に対して `hire_date` のソート順でインデックスを走査できる

---

## 演習8: 制約設計の総合問題

```sql
CREATE TABLE books (
    book_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    isbn         CHAR(13) NOT NULL UNIQUE
                     CHECK (isbn ~ '^\d{13}$'),
    title        TEXT NOT NULL,
    author       TEXT NOT NULL,
    publish_year INTEGER NOT NULL
                     CHECK (publish_year >= 1450
                            AND publish_year <= extract(year FROM current_date))
);

CREATE TABLE members (
    member_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT NOT NULL,
    email       TEXT NOT NULL UNIQUE,
    member_type TEXT NOT NULL DEFAULT 'regular'
                    CHECK (member_type IN ('regular', 'student', 'staff'))
);

CREATE TABLE loans (
    loan_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    member_id   INTEGER NOT NULL REFERENCES members(member_id) ON DELETE RESTRICT,
    book_id     INTEGER NOT NULL REFERENCES books(book_id) ON DELETE RESTRICT,
    loaned_at   DATE NOT NULL DEFAULT current_date,
    due_date    DATE NOT NULL,
    returned_at DATE,
    CONSTRAINT due_after_loan CHECK (due_date > loaned_at),
    CONSTRAINT return_after_loan CHECK (returned_at IS NULL OR returned_at > loaned_at)
);

-- 同じ書籍を同じ利用者が未返却で2件以上持てない（部分ユニークインデックス）
CREATE UNIQUE INDEX idx_loans_active_unique
    ON loans (member_id, book_id)
    WHERE returned_at IS NULL;
```

**ポイント**:
- ISBN のフォーマットは `CHECK` + 正規表現で検証
- 出版年の上限を `extract(year FROM current_date)` で動的に設定
- 「未返却の貸出は同一書籍・同一利用者で1件まで」は通常の `UNIQUE` 制約では表現できない。`WHERE returned_at IS NULL` の部分ユニークインデックスで実現する
- `ON DELETE RESTRICT` で書籍や利用者の削除時に貸出記録があれば拒否する

---

## 演習9: データ型の選択

1. **`UUID`** — 連番の INTEGER を外部に公開するとリソースの総数が推測される。UUID は推測困難で、分散システムでも衝突しない。`gen_random_uuid()` で生成。

2. **`INTEGER`**（円単位で格納）または **`NUMERIC(10, 0)`** — 日本円に小数点以下はないため、INTEGER で十分。将来的に税計算の端数を扱う可能性がある場合は `NUMERIC(12, 2)`。

3. **`TEXT`** + `CHECK (char_length(profile) <= 5000)` — PostgreSQL では `TEXT` と `VARCHAR(n)` に性能差はない。長さ制約は CHECK で明示する。

4. **`TIMESTAMPTZ`** — タイムゾーン情報を保持し、異なるタイムゾーンのクライアントに正しい現地時間を表示できる。

5. **正規化する場合**: 別テーブル（`product_tags`）に分離。**簡易的な場合**: `TEXT[]`（配列型）+ GIN インデックス。タグの検索頻度やタグ自体のマスタ管理が必要かで判断。

6. **`INET`** — IPv4 と IPv6 の両方を格納可能。ネットワーク演算（サブネット判定など）も可能。`TEXT` で格納するより型安全。

7. **`BOOLEAN`** — `TRUE` / `FALSE` の2値。`INTEGER` の 0/1 で代用しない。

8. **`JSONB`** — スキーマレスな構造を格納でき、GIN インデックスで検索可能。`JSON` 型ではなく `JSONB` を使う（バイナリ格納で検索が高速）。

---

## 演習10: インデックスの要否判断

1. **不要** — 100行程度ならシーケンシャルスキャンの方が速い。インデックスのメンテナンスコストが無駄。

2. **必要** — 1000万行に対する範囲検索は B-tree インデックスで大幅に高速化される。
   ```sql
   CREATE INDEX idx_access_logs_created ON access_logs (created_at);
   ```

3. **不要（通常のインデックスは）** — カーディナリティが3しかなく、各値がテーブルの約33%にヒットする。インデックスを使うよりシーケンシャルスキャンが選ばれる。ただし `gender = 'other'` のように少数派のみ検索する場合は部分インデックスが有効。
   ```sql
   CREATE INDEX idx_users_other ON users (user_id) WHERE gender = 'other';
   ```

4. **場合による** — INSERT が極めて多いため、インデックスの更新コストが高い。月次バッチでしか検索しないなら、バッチ実行前にインデックスを作成し、完了後に削除する方法もある。または検索頻度が低いのでインデックスなしで許容する。

5. **B-tree インデックスでは不可** — 前方一致（`LIKE 'keyword%'`）なら B-tree が使えるが、中間一致（`LIKE '%keyword%'`）では使えない。全文検索が必要な場合は GIN + `pg_trgm` 拡張を検討する。
   ```sql
   CREATE EXTENSION IF NOT EXISTS pg_trgm;
   CREATE INDEX idx_products_desc_trgm ON products USING gin (description gin_trgm_ops);
   ```
