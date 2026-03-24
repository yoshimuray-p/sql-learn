# 第1回: SQLクエリの基礎 (SQL Query Basics)

## サンプルスキーマ (Sample Schema)

本講義では以下のスキーマを使用する。

```sql
CREATE TABLE departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(100)
);

CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    department_id INTEGER REFERENCES departments(id),
    salary NUMERIC(10, 2),
    hire_date DATE
);

CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    budget NUMERIC(12, 2),
    start_date DATE,
    end_date DATE
);

CREATE TABLE assignments (
    employee_id INTEGER REFERENCES employees(id),
    project_id INTEGER REFERENCES projects(id),
    role VARCHAR(50),
    assigned_date DATE,
    PRIMARY KEY (employee_id, project_id)
);
```

---

## 1. データ型の概要 (Data Types)

PostgreSQLの主要なデータ型:

| 型 | 説明 | 例 |
|---|---|---|
| `INTEGER` / `INT` | 32ビット整数 | `42` |
| `BIGINT` | 64ビット整数 | `9999999999` |
| `NUMERIC(p, s)` | 任意精度の固定小数点数 | `NUMERIC(10, 2)` → `12345678.90` |
| `TEXT` | 可変長文字列（無制限） | `'任意の長さの文字列'` |
| `VARCHAR(n)` | 最大n文字の可変長文字列 | `VARCHAR(100)` |
| `BOOLEAN` | 真偽値 | `TRUE`, `FALSE`, `NULL` |
| `DATE` | 日付 | `'2025-04-01'` |
| `TIMESTAMP` | 日時 | `'2025-04-01 09:30:00'` |
| `SERIAL` | 自動採番整数（`INTEGER` + シーケンス） | — |

`TEXT` vs `VARCHAR(n)`: PostgreSQLでは性能差はほぼない。長さ制約が意味的に必要な場合のみ `VARCHAR(n)` を使う。

---

## 2. SELECT, WHERE, ORDER BY, LIMIT, OFFSET

### 基本形

```sql
SELECT name, salary
FROM employees
WHERE salary > 500000
ORDER BY salary DESC
LIMIT 10
OFFSET 5;
```

- `SELECT`: 取得する列を指定。`*` で全列。
- `WHERE`: 行のフィルタリング。
- `ORDER BY`: ソート。`ASC`（昇順、デフォルト）/ `DESC`（降順）。複数列指定可。
- `LIMIT`: 取得行数の上限。
- `OFFSET`: 先頭からスキップする行数。ページネーションに使うが、大量データでは性能に注意。

### エイリアス (Alias)

```sql
SELECT e.name AS employee_name, e.salary
FROM employees AS e
WHERE e.hire_date >= '2024-01-01';
```

---

## 3. 演算子とフィルタリング (Operators and Filtering)

### 比較演算子

```sql
-- 等価・不等価
WHERE salary = 600000
WHERE salary <> 600000    -- != も可だが <> が標準SQL

-- 範囲
WHERE salary BETWEEN 400000 AND 700000
-- ↑ は WHERE salary >= 400000 AND salary <= 700000 と等価

-- リストとの照合
WHERE department_id IN (1, 3, 5)
```

### パターンマッチ

```sql
-- LIKE: 大文字小文字を区別
WHERE name LIKE '田中%'       -- '田中' で始まる
WHERE name LIKE '%太郎'       -- '太郎' で終わる
WHERE name LIKE '_田%'        -- 2文字目が '田'

-- ILIKE: 大文字小文字を区別しない（PostgreSQL独自）
WHERE name ILIKE '%tanaka%'
```

- `%`: 0文字以上の任意の文字列
- `_`: 任意の1文字

### 論理演算子

```sql
WHERE department_id = 1 AND salary > 500000
WHERE department_id = 1 OR department_id = 2
WHERE NOT (salary < 300000)
```

---

## 4. JOIN

### INNER JOIN

両テーブルで一致する行のみ返す。

```sql
SELECT e.name, d.name AS department
FROM employees e
INNER JOIN departments d ON e.department_id = d.id;
```

### LEFT JOIN (LEFT OUTER JOIN)

左テーブルの全行を返す。右テーブルに一致がなければ `NULL`。

```sql
-- 部署に所属していない従業員も含めて取得
SELECT e.name, d.name AS department
FROM employees e
LEFT JOIN departments d ON e.department_id = d.id;
```

### RIGHT JOIN (RIGHT OUTER JOIN)

右テーブルの全行を返す。実務では `LEFT JOIN` のテーブル順を入れ替えることが多い。

### FULL OUTER JOIN

両テーブルの全行を返す。どちらかに一致がなければ `NULL`。

```sql
SELECT e.name, d.name AS department
FROM employees e
FULL OUTER JOIN departments d ON e.department_id = d.id;
```

### CROSS JOIN

全行の直積（Cartesian product）。`m行 × n行 = m*n行`。

```sql
SELECT e.name, p.name AS project
FROM employees e
CROSS JOIN projects p;
```

### 自己結合 (Self-Join)

同じテーブルを異なるエイリアスで結合する。

```sql
-- 同じ部署の他の従業員を列挙
SELECT e1.name, e2.name AS colleague
FROM employees e1
INNER JOIN employees e2
    ON e1.department_id = e2.department_id
    AND e1.id <> e2.id;
```

### 複数テーブルの結合

```sql
-- 従業員、所属部署、担当プロジェクトを一覧
SELECT e.name AS employee,
       d.name AS department,
       p.name AS project,
       a.role
FROM employees e
INNER JOIN departments d ON e.department_id = d.id
INNER JOIN assignments a ON e.id = a.employee_id
INNER JOIN projects p ON a.project_id = p.id;
```

---

## 5. GROUP BY, HAVING, 集約関数 (Aggregate Functions)

### 基本的な集約関数

| 関数 | 説明 |
|---|---|
| `COUNT(*)` | 行数 |
| `COUNT(column)` | `NULL` を除いた行数 |
| `COUNT(DISTINCT column)` | 重複を除いた行数 |
| `SUM(column)` | 合計 |
| `AVG(column)` | 平均 |
| `MIN(column)` / `MAX(column)` | 最小値 / 最大値 |
| `ARRAY_AGG(column)` | 値を配列に集約（PostgreSQL） |
| `STRING_AGG(column, delimiter)` | 値を文字列に連結（PostgreSQL） |

### GROUP BY

```sql
-- 部署ごとの平均給与と人数
SELECT d.name AS department,
       COUNT(*) AS employee_count,
       AVG(e.salary) AS avg_salary
FROM employees e
INNER JOIN departments d ON e.department_id = d.id
GROUP BY d.name;
```

### HAVING

`GROUP BY` の結果に対するフィルタ。`WHERE` は集約前、`HAVING` は集約後。

```sql
-- 平均給与が500000以上の部署のみ
SELECT d.name, AVG(e.salary) AS avg_salary
FROM employees e
INNER JOIN departments d ON e.department_id = d.id
GROUP BY d.name
HAVING AVG(e.salary) >= 500000;
```

### ARRAY_AGG / STRING_AGG

```sql
-- 部署ごとの従業員名リスト
SELECT d.name AS department,
       STRING_AGG(e.name, ', ' ORDER BY e.name) AS members,
       ARRAY_AGG(e.name ORDER BY e.name) AS members_array
FROM employees e
INNER JOIN departments d ON e.department_id = d.id
GROUP BY d.name;
```

---

## 6. サブクエリ (Subqueries)

### スカラーサブクエリ (Scalar Subquery)

1行1列を返すサブクエリ。`SELECT` 句や `WHERE` 句で使う。

```sql
-- 平均給与より高い従業員
SELECT name, salary
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees);
```

### IN サブクエリ

```sql
-- プロジェクトに1つ以上アサインされている従業員
SELECT name
FROM employees
WHERE id IN (SELECT DISTINCT employee_id FROM assignments);
```

### EXISTS サブクエリ

行の存在を確認する。相関サブクエリ（Correlated Subquery）と組み合わせることが多い。

```sql
-- プロジェクトにアサインされている従業員
SELECT e.name
FROM employees e
WHERE EXISTS (
    SELECT 1
    FROM assignments a
    WHERE a.employee_id = e.id
);
```

`IN` vs `EXISTS`: 外側のテーブルが小さく内側が大きい場合は `EXISTS` が有利になることが多い。逆の場合は `IN` が有利。PostgreSQLのオプティマイザは多くの場合同等の実行計画を生成する。

### 相関サブクエリ (Correlated Subquery)

外側のクエリの値を参照するサブクエリ。行ごとに評価される。

```sql
-- 各従業員について、同じ部署の最高給与との差を表示
SELECT e.name,
       e.salary,
       e.salary - (
           SELECT MAX(e2.salary)
           FROM employees e2
           WHERE e2.department_id = e.department_id
       ) AS diff_from_max
FROM employees e;
```

### FROM句のサブクエリ (Derived Table)

```sql
-- 部署ごとの統計を計算してからフィルタ
SELECT *
FROM (
    SELECT department_id,
           COUNT(*) AS cnt,
           AVG(salary) AS avg_sal
    FROM employees
    GROUP BY department_id
) AS dept_stats
WHERE cnt >= 3;
```

---

## 7. NULLの扱い (NULL Handling)

### 三値論理 (Three-Valued Logic)

SQLでは `NULL` は「不明（unknown）」を表す。比較演算の結果は `TRUE`, `FALSE`, `UNKNOWN` の3値になる。

```
NULL = NULL   → UNKNOWN  （TRUE ではない！）
NULL <> 1     → UNKNOWN
NULL AND TRUE → UNKNOWN
NULL OR TRUE  → TRUE
```

**重要**: `WHERE` 句は `TRUE` の行のみ返す。`UNKNOWN` は除外される。

### IS NULL / IS NOT NULL

```sql
-- NULLの検出には = ではなく IS NULL を使う
SELECT name FROM employees WHERE department_id IS NULL;
SELECT name FROM employees WHERE department_id IS NOT NULL;
```

### COALESCE

最初の非NULL値を返す。

```sql
-- department_id が NULL なら '未配属' を表示
SELECT name, COALESCE(department_id::TEXT, '未配属') AS dept
FROM employees;

-- 複数の引数を取れる
SELECT COALESCE(nickname, name, 'Unknown') AS display_name
FROM employees;
```

### NULLIF

2つの値が等しければ `NULL` を返す。ゼロ除算の回避に有用。

```sql
-- budget が 0 の場合にゼロ除算を防ぐ
SELECT name, salary / NULLIF(budget, 0) AS ratio
FROM projects;
```

### 集約関数とNULL

集約関数は `NULL` を無視する（`COUNT(*)` を除く）。

```sql
-- COUNT(*) は NULL行も数える
-- COUNT(salary) は salary が NULL の行を除外
SELECT COUNT(*) AS total,
       COUNT(salary) AS with_salary,
       AVG(salary) AS avg_salary  -- NULLの行は除外して平均
FROM employees;
```

---

## 8. SQL句の実行順序 (Execution Order)

SQLの論理的な評価順序は記述順序と異なる:

```
1. FROM / JOIN    — テーブルの結合
2. WHERE          — 行のフィルタリング
3. GROUP BY       — グループ化
4. HAVING         — グループのフィルタリング
5. SELECT         — 列の選択・式の評価
6. DISTINCT       — 重複排除
7. ORDER BY       — ソート
8. LIMIT / OFFSET — 行数の制限
```

この順序を理解することで、以下のようなエラーの原因がわかる:

```sql
-- エラー: WHERE句でエイリアスは使えない（SELECTはWHEREの後に評価）
SELECT salary * 12 AS annual_salary
FROM employees
WHERE annual_salary > 6000000;  -- NG

-- 正しい書き方
SELECT salary * 12 AS annual_salary
FROM employees
WHERE salary * 12 > 6000000;    -- OK

-- ORDER BY ではエイリアスが使える（SELECTの後に評価）
SELECT salary * 12 AS annual_salary
FROM employees
ORDER BY annual_salary DESC;    -- OK
```

---

## まとめ

| 概念 | ポイント |
|---|---|
| `SELECT` / `WHERE` | 列の選択と行のフィルタリング |
| `JOIN` | テーブル結合。`INNER`, `LEFT`, `RIGHT`, `FULL OUTER`, `CROSS`, 自己結合 |
| `GROUP BY` / `HAVING` | 集約。`HAVING` は集約後のフィルタ |
| サブクエリ | スカラー、`IN`、`EXISTS`、相関、派生テーブル |
| `NULL` | 三値論理。`IS NULL`, `COALESCE`, `NULLIF` |
| 実行順序 | FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT |
