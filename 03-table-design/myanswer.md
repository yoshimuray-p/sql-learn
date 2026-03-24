# 第3回 自己解答: テーブル設計 (Table Design)

---

## 演習1: ECサイトの基本テーブル作成

`customers` テーブルと `orders` テーブルを要件に従って作成せよ。

- customers: 自動採番PK（IDENTITY）、氏名（必須・最大100文字）、メール（必須・一意）、電話番号（任意）、登録日時（TZ付き・デフォルト現在時刻）
- orders: 自動採番PK、顧客FK（削除拒否）、注文日時（必須・デフォルト現在時刻）、ステータス（`pending`/`shipped`/`delivered`/`cancelled`・デフォルト `pending`）、合計金額（0以上・必須）

```sql

```

---

## 演習2: ALTER TABLE によるスキーマ変更

演習1の `customers` テーブルに対して以下の変更を順に行う DDL を書け。

1. `address` カラム（TEXT型、NULLable）を追加
2. `phone` カラムの名前を `phone_number` に変更
3. `name` カラムを `first_name` と `last_name` に分割（`name` を削除し、2つの `TEXT NOT NULL` カラムを追加）
4. メールアドレスの文字数を254文字以下に制限する CHECK 制約を追加

```sql

```

---

## 演習3: 外部キーの ON DELETE 挙動

以下の3つのシナリオについて、適切な `ON DELETE` アクションを選び、理由を述べよ。

1. `blog_posts.author_id` → `users`。ユーザーがアカウントを削除した場合。
2. `session_logs.user_id` → `users`。ユーザーがアカウントを削除した場合。
3. `project_tasks.assignee_id` → `employees`。社員が退職した場合。

```

1.

2.

3.
```

---

## 演習4: 正規形の判定

以下のテーブルは何正規形か判定し、問題点を指摘せよ。

```
student_courses
| student_id | student_name | course_id | course_name | instructor   | instructor_office |
候補キー: {student_id, course_id}
```

```

```

---

## 演習5: 非正規テーブルの正規化

以下の `sales_raw` テーブルを 3NF まで正規化せよ（テーブル定義を DDL で記述）。

```
sales_raw
| sale_id | date | customer_name | customer_city | items | prices | store_name | store_city |
```

```sql

```

---

## 演習6: インデックス設計

以下の各クエリに対して適切なインデックスを設計せよ。

```sql
-- クエリA: 特定ユーザーの最近の注文
SELECT * FROM orders WHERE user_id = $1 ORDER BY ordered_at DESC LIMIT 20;

-- クエリB: メールアドレスで大文字小文字を区別しない検索
SELECT * FROM users WHERE lower(email) = lower($1);

-- クエリC: 未発送の注文を日付順に取得
SELECT * FROM orders WHERE status = 'pending' ORDER BY ordered_at;

-- クエリD: 商品の JSONB 属性で検索
SELECT * FROM products WHERE attributes @> '{"color": "red", "size": "L"}';

-- クエリE: 特定カテゴリのアクティブ商品を価格順に取得
SELECT * FROM products WHERE category_id = $1 AND is_active = true ORDER BY price;
```

```sql

```

---

## 演習7: 複合インデックスの有効性判定

以下のインデックスが定義されている場合、各クエリでインデックスが使われるか答えよ。

```sql
CREATE INDEX idx_emp ON employees (department_id, hire_date, salary);
```

```sql
-- (1) WHERE department_id = 5
-- (2) WHERE hire_date = '2024-01-01'
-- (3) WHERE department_id = 5 AND salary > 50000
-- (4) WHERE department_id = 5 AND hire_date > '2024-01-01' ORDER BY salary
-- (5) WHERE department_id IN (1, 2, 3) ORDER BY hire_date
```

```

(1):

(2):

(3):

(4):

(5):
```

---

## 演習8: 制約設計の総合問題

図書館の貸出管理システムのテーブルを設計せよ（業務ルールを制約で表現）。

- 書籍: ISBN（13桁・一意）、タイトル、著者、出版年（1450以上・現在年以下）
- 利用者: 氏名、メール（一意）、会員種別（`regular`/`student`/`staff`）
- 貸出: 利用者・書籍・貸出日・返却予定日（貸出日より後）・返却日（NULL可・貸出日より後）
- 同一書籍の未返却貸出は1件まで

```sql

```

---

## 演習9: データ型の選択

以下の各カラムに最適なデータ型を選び、理由を述べよ。

1. ユーザーの外部公開用 ID
2. 商品の価格（日本円、税込）
3. ユーザーのプロフィール文（最大5000文字）
4. イベントの開催日時（複数タイムゾーン対応）
5. 商品のタグ（1商品に複数タグ）
6. ユーザーの IP アドレス
7. フラグ的なステータス（有効/無効）
8. 商品の詳細スペック（項目が商品ごとに異なる）

```

1.
2.
3.
4.
5.
6.
7.
8.
```

---

## 演習10: インデックスの要否判断

以下の各シナリオについて、インデックスを作成すべきか否かを判断し、理由を述べよ。

1. 100行程度の `prefectures (prefecture_id, name)` テーブルの `name` カラム
2. 1000万行の `access_logs` テーブルの `created_at` カラム（日時範囲検索が頻繁）
3. `users` テーブルの `gender` カラム（3値、500万行）
4. 1日10万件 INSERT される `iot_sensor_data` テーブルの `sensor_id` カラム（検索は月次バッチのみ）
5. `products.description` への `LIKE '%keyword%'` 検索

```

1.
2.
3.
4.
5.
```
