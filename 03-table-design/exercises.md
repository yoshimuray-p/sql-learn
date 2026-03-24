# 第3回 演習: テーブル設計 (Table Design)

> **学習の進め方**: 各演習に自力で取り組んだ後、AIアシスタントに自分の解答を見せてレビューしてもらおう。
> 行き詰まったときはヒントを求め、いきなり答えを聞くのではなく対話的に考えを深めよう。
> 解答例は `answers.md` にまとめてある。


---

## 演習1: ECサイトの基本テーブル作成

以下の要件を満たす `customers` テーブルと `orders` テーブルを作成せよ。

**customers テーブル**:
- 自動採番の主キー（IDENTITY 使用）
- 氏名（必須、最大100文字）
- メールアドレス（必須、一意）
- 電話番号（任意）
- 登録日時（タイムゾーン付き、デフォルト: 現在時刻）

**orders テーブル**:
- 自動採番の主キー
- 顧客への外部キー（顧客削除時は注文の削除を拒否）
- 注文日時（必須、デフォルト: 現在時刻）
- ステータス（`pending`, `shipped`, `delivered`, `cancelled` のいずれか、デフォルト: `pending`）
- 合計金額（0以上、必須）


**あなたの解答:**

```

```

---

## 演習2: ALTER TABLE によるスキーマ変更

演習1で作成した `customers` テーブルに対して、以下の変更を順に行う DDL を書け。

1. `address` カラム（TEXT型、NULLable）を追加
2. `phone` カラムの名前を `phone_number` に変更
3. `name` カラムを `first_name` と `last_name` に分割する（`name` を削除し、2つの `TEXT NOT NULL` カラムを追加）
4. メールアドレスの文字数を254文字以下に制限する CHECK 制約を追加


**あなたの解答:**

```

```

---

## 演習3: 外部キーの ON DELETE 挙動

以下の3つのシナリオについて、それぞれ適切な `ON DELETE` アクションを選び、理由を述べよ。

1. `blog_posts` テーブルの `author_id` が `users` テーブルを参照。ユーザーがアカウントを削除した場合。
2. `session_logs` テーブルの `user_id` が `users` テーブルを参照。ユーザーがアカウントを削除した場合。
3. `project_tasks` テーブルの `assignee_id` が `employees` テーブルを参照。社員が退職した場合。


**あなたの解答:**

```

```

---

## 演習4: 正規形の判定

以下のテーブルは何正規形か判定し、問題点を指摘せよ。

```
student_courses
| student_id | student_name | course_id | course_name | instructor   | instructor_office |
|------------|-------------|-----------|-------------|-------------|-------------------|
| 1          | 山田一郎    | CS101     | データベース  | 鈴木教授     | A棟301            |
| 1          | 山田一郎    | CS201     | アルゴリズム  | 佐藤教授     | B棟205            |
| 2          | 田中花子    | CS101     | データベース  | 鈴木教授     | A棟301            |
```

候補キー: `{student_id, course_id}`

関数従属:
- `student_id → student_name`
- `course_id → course_name, instructor, instructor_office`
- `instructor → instructor_office`


**あなたの解答:**

```

```

---

## 演習5: 非正規テーブルの正規化

以下の非正規テーブルを 3NF まで正規化せよ。

```
sales_raw
| sale_id | date       | customer_name | customer_city | items                    | prices       | store_name | store_city |
|---------|------------|--------------|---------------|--------------------------|-------------|------------|------------|
| 1       | 2024-01-15 | 田中太郎     | 東京          | ペン, ノート, 消しゴム      | 200,500,100 | 渋谷店      | 東京       |
| 2       | 2024-01-16 | 佐藤花子     | 大阪          | ノート                    | 500         | 梅田店      | 大阪       |
```


**あなたの解答:**

```

```

---

## 演習6: インデックス設計

以下のクエリが頻繁に実行される。適切なインデックスを設計せよ。

```sql
-- クエリA: 特定ユーザーの最近の注文を取得
SELECT * FROM orders
WHERE user_id = $1
ORDER BY ordered_at DESC
LIMIT 20;

-- クエリB: メールアドレスでユーザー検索（大文字小文字を区別しない）
SELECT * FROM users
WHERE lower(email) = lower($1);

-- クエリC: 未発送の注文を日付順に取得
SELECT * FROM orders
WHERE status = 'pending'
ORDER BY ordered_at;

-- クエリD: 商品の属性（JSONB）で検索
SELECT * FROM products
WHERE attributes @> '{"color": "red", "size": "L"}';

-- クエリE: 特定カテゴリの商品を価格順に取得
SELECT * FROM products
WHERE category_id = $1 AND is_active = true
ORDER BY price;
```


**あなたの解答:**

```

```

---

## 演習7: 複合インデックスの有効性判定

以下のインデックスが定義されている場合、各クエリでインデックスが使われるか答えよ。

```sql
CREATE INDEX idx_emp ON employees (department_id, hire_date, salary);
```

```sql
-- (1)
SELECT * FROM employees WHERE department_id = 5;

-- (2)
SELECT * FROM employees WHERE hire_date = '2024-01-01';

-- (3)
SELECT * FROM employees WHERE department_id = 5 AND salary > 50000;

-- (4)
SELECT * FROM employees
WHERE department_id = 5 AND hire_date > '2024-01-01'
ORDER BY salary;

-- (5)
SELECT * FROM employees
WHERE department_id IN (1, 2, 3)
ORDER BY hire_date;
```


**あなたの解答:**

```

```

---

## 演習8: 制約設計の総合問題

図書館の貸出管理システムのテーブルを設計せよ。以下の業務ルールを制約で表現すること。

**業務ルール**:
- 書籍には ISBN（13桁の文字列）、タイトル、著者、出版年がある
- ISBN は一意である
- 出版年は 1450 以上、現在の年以下
- 利用者には氏名、メールアドレス（一意）、会員種別（`regular`, `student`, `staff`）がある
- 1つの貸出記録には、どの利用者がどの書籍をいつ借りたか、返却予定日、実際の返却日を記録する
- 返却予定日は貸出日より後でなければならない
- 実際の返却日は貸出日より後でなければならない（NULLable: 未返却を表す）
- 同じ書籍を同じ利用者が同時に2冊借りることはできない（未返却の貸出は1件まで）


**あなたの解答:**

```

```

---

## 演習9: データ型の選択

以下の各カラムに最適なデータ型を選び、理由を述べよ。

1. ユーザーの外部公開用 ID（API レスポンスに含める）
2. 商品の価格（日本円、税込）
3. ユーザーのプロフィール文（最大5000文字）
4. イベントの開催日時（国際的なサービスで複数タイムゾーン対応）
5. 商品のタグ（1商品に複数タグ）
6. ユーザーのIPアドレス
7. フラグ的なステータス（有効/無効）
8. 商品の詳細スペック（項目が商品ごとに異なる）


**あなたの解答:**

```

```

---

## 演習10: インデックスの要否判断

以下の各シナリオについて、インデックスを作成すべきか否かを判断し、理由を述べよ。

1. 100行程度のマスタテーブル `prefectures (prefecture_id, name)` の `name` カラム
2. 1000万行の `access_logs` テーブルの `created_at` カラム（日時範囲での検索が頻繁）
3. `users` テーブルの `gender` カラム（`male`, `female`, `other` の3値、500万行）
4. 1日に10万件 INSERT される `iot_sensor_data` テーブルの `sensor_id` カラム（検索は月次バッチのみ）
5. `products` テーブルの `description` カラムに対する部分一致検索（`LIKE '%keyword%'`）


**あなたの解答:**

```

```
