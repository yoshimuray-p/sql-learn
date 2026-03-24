# 第2回: 高度なクエリ (Advanced Queries)

## サンプルスキーマ

本講義では以下のテーブルを使用する。

```sql
CREATE TABLE departments (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(100)
);

CREATE TABLE employees (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    department_id INT REFERENCES departments(id),
    salary        NUMERIC(10,2),
    hire_date     DATE,
    manager_id    INT REFERENCES employees(id)  -- 自己参照（再帰CTE用）
);

CREATE TABLE projects (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(200) NOT NULL,
    budget     NUMERIC(12,2),
    start_date DATE,
    end_date   DATE
);

CREATE TABLE assignments (
    employee_id   INT REFERENCES employees(id),
    project_id    INT REFERENCES projects(id),
    role          VARCHAR(50),
    assigned_date DATE,
    PRIMARY KEY (employee_id, project_id)
);
```

---

## 1. CTE — WITH句 (Common Table Expressions)

CTE は `WITH` 句でクエリの一部に名前を付けて再利用する仕組みである。サブクエリの入れ子を減らし、可読性を大幅に向上させる。

### 基本構文

```sql
WITH cte_name AS (
    SELECT ...
)
SELECT * FROM cte_name;
```

### 実践例: 部門別平均給与を超える社員

サブクエリ版は読みにくい:

```sql
SELECT e.name, e.salary, d.name AS dept
FROM employees e
JOIN departments d ON e.department_id = d.id
WHERE e.salary > (
    SELECT AVG(e2.salary)
    FROM employees e2
    WHERE e2.department_id = e.department_id
);
```

CTE版:

```sql
WITH dept_avg AS (
    SELECT department_id, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY department_id
)
SELECT e.name, e.salary, d.name AS dept, da.avg_salary
FROM employees e
JOIN departments d ON e.department_id = d.id
JOIN dept_avg da ON e.department_id = da.department_id
WHERE e.salary > da.avg_salary;
```

### 複数CTEの連鎖

CTE はカンマ区切りで複数定義でき、後続のCTEが先行のCTEを参照できる。

```sql
WITH high_budget_projects AS (
    SELECT id, name, budget
    FROM projects
    WHERE budget > 1000000
),
assigned_employees AS (
    SELECT DISTINCT a.employee_id, hbp.name AS project_name
    FROM assignments a
    JOIN high_budget_projects hbp ON a.project_id = hbp.id
)
SELECT e.name, ae.project_name
FROM employees e
JOIN assigned_employees ae ON e.id = ae.employee_id;
```

### CTE のマテリアライズ制御

PostgreSQL 12以降では、CTEがデフォルトでインライン化（展開）される場合がある。明示的に制御するには:

```sql
WITH cte AS MATERIALIZED (
    SELECT ...  -- 結果を一時的に実体化して再利用
)
...

WITH cte AS NOT MATERIALIZED (
    SELECT ...  -- クエリ内にインライン展開（オプティマイザが最適化）
)
...
```

---

## 2. 再帰CTE (Recursive CTE)

再帰CTEは木構造（tree）やグラフ構造のデータを走査するための仕組みである。

### 構文

```sql
WITH RECURSIVE cte_name AS (
    -- 非再帰部（ベースケース）
    SELECT ...
    UNION ALL
    -- 再帰部（前回の結果を参照）
    SELECT ... FROM cte_name JOIN ...
)
SELECT * FROM cte_name;
```

### 実践例: 組織階層の走査

`employees.manager_id` を使って上司→部下の木構造を辿る:

```sql
WITH RECURSIVE org_tree AS (
    -- ベースケース: トップ（manager_id が NULL）
    SELECT id, name, manager_id, 1 AS depth,
           ARRAY[name] AS path
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- 再帰部: 子ノードを辿る
    SELECT e.id, e.name, e.manager_id, ot.depth + 1,
           ot.path || e.name
    FROM employees e
    JOIN org_tree ot ON e.manager_id = ot.id
)
SELECT id, name, depth, array_to_string(path, ' → ') AS hierarchy
FROM org_tree
ORDER BY path;
```

`ARRAY` と `path` を使うことで、ルートからの経路を文字列として表示できる。

### 実践例: 連番生成

```sql
WITH RECURSIVE seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 10
)
SELECT n FROM seq;
```

### 注意点

- 無限ループを防ぐため、再帰部に終了条件を入れるか、`CYCLE` 句（PostgreSQL 14+）を使う
- `UNION ALL` を `UNION` にすると重複排除されるが性能が落ちる
- PostgreSQL 14+ では `SEARCH` / `CYCLE` 句で深さ優先・幅優先の探索順序とループ検出を宣言的に書ける

```sql
WITH RECURSIVE org_tree AS (
    SELECT id, name, manager_id FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, e.manager_id
    FROM employees e JOIN org_tree ot ON e.manager_id = ot.id
) SEARCH DEPTH FIRST BY id SET order_col
  CYCLE id SET is_cycle USING path
SELECT * FROM org_tree WHERE NOT is_cycle;
```

---

## 3. ウィンドウ関数 (Window Functions)

ウィンドウ関数は、`GROUP BY` で行を潰さずに集約・順位付けを行う。各行が元の行として残る点が通常の集約関数と異なる。

### 基本構文

```sql
function_name() OVER (
    [PARTITION BY col1, col2, ...]
    [ORDER BY col3, col4, ...]
    [frame_clause]
)
```

- `PARTITION BY` — グループ分け（省略時は全行が1パーティション）
- `ORDER BY` — パーティション内の順序
- `frame_clause` — 計算対象の行範囲

### 3.1 順位関数 (Ranking Functions)

```sql
SELECT
    name, department_id, salary,
    ROW_NUMBER() OVER (ORDER BY salary DESC)  AS row_num,   -- 連番（重複なし）
    RANK()       OVER (ORDER BY salary DESC)  AS rank,      -- 同値は同順位、次はスキップ
    DENSE_RANK() OVER (ORDER BY salary DESC)  AS dense_rank,-- 同値は同順位、次はスキップなし
    NTILE(4)     OVER (ORDER BY salary DESC)  AS quartile   -- N等分
FROM employees;
```

| salary | row_num | rank | dense_rank | quartile |
|--------|---------|------|------------|----------|
| 900    | 1       | 1    | 1          | 1        |
| 900    | 2       | 1    | 1          | 1        |
| 800    | 3       | 3    | 2          | 2        |
| 700    | 4       | 4    | 3          | 2        |

**部門別ランキング** — `PARTITION BY` を加える:

```sql
SELECT
    name, department_id, salary,
    RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS dept_rank
FROM employees;
```

### 3.2 行アクセス関数 (Offset Functions)

前後の行の値を参照する:

```sql
SELECT
    name, hire_date, salary,
    LAG(salary, 1)  OVER (ORDER BY hire_date) AS prev_salary,  -- 1つ前の行
    LEAD(salary, 1) OVER (ORDER BY hire_date) AS next_salary,  -- 1つ後の行
    salary - LAG(salary, 1) OVER (ORDER BY hire_date) AS salary_diff
FROM employees;
```

- `LAG(expr, offset, default)` — offset行前の値（デフォルトはNULL）
- `LEAD(expr, offset, default)` — offset行後の値

**先頭・末尾の値:**

```sql
SELECT
    name, department_id, salary,
    FIRST_VALUE(name) OVER (
        PARTITION BY department_id ORDER BY salary DESC
    ) AS highest_paid,
    LAST_VALUE(name) OVER (
        PARTITION BY department_id ORDER BY salary DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS lowest_paid
FROM employees;
```

> **注意**: `LAST_VALUE` はデフォルトのフレーム（`RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`）では現在行までしか見ないため、パーティション全体を見るには `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` を明示する必要がある。

### 3.3 集約関数をウィンドウ関数として使う

通常の集約関数に `OVER` を付けると、行を潰さずに集約結果を各行に付与できる。

**累計 (Running Total):**

```sql
SELECT
    name, hire_date, salary,
    SUM(salary) OVER (ORDER BY hire_date) AS running_total
FROM employees;
```

`ORDER BY` を指定すると、デフォルトのフレームは `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` となり、累計が計算される。

**移動平均 (Moving Average):**

```sql
SELECT
    name, hire_date, salary,
    AVG(salary) OVER (
        ORDER BY hire_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3
FROM employees;
```

**部門別の割合:**

```sql
SELECT
    name, department_id, salary,
    ROUND(salary / SUM(salary) OVER (PARTITION BY department_id) * 100, 1)
        AS pct_of_dept
FROM employees;
```

### 3.4 ウィンドウフレーム (Window Frame)

フレームは `ROWS` または `RANGE` で指定する。

| 指定 | 意味 |
|------|------|
| `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | 先頭から現在行まで（物理行数） |
| `ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING` | 前後2行ずつ（計5行） |
| `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | 先頭から現在行と同値の行まで（論理範囲） |

`ROWS` は物理的な行数、`RANGE` は `ORDER BY` の値に基づく論理範囲である。

```sql
-- ROWS vs RANGE の違い（同値がある場合に差が出る）
SELECT salary,
    SUM(salary) OVER (ORDER BY salary ROWS  BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rows_sum,
    SUM(salary) OVER (ORDER BY salary RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS range_sum
FROM employees;
```

`RANGE` では同じ `salary` の行がすべて同時に加算されるが、`ROWS` では物理的な行順に1行ずつ加算される。

### 3.5 名前付きウィンドウ (WINDOW句)

同じウィンドウ定義を繰り返し書くのを避けるために `WINDOW` 句を使う:

```sql
SELECT
    name, department_id, salary,
    RANK()       OVER w AS rank,
    SUM(salary)  OVER w AS running_sum,
    AVG(salary)  OVER w AS running_avg
FROM employees
WINDOW w AS (PARTITION BY department_id ORDER BY salary DESC);
```

---

## 4. CASE式 (CASE Expression)

条件分岐を行うSQL標準の式。`SELECT`, `WHERE`, `ORDER BY`, 集約関数の中など、式が書ける場所ならどこでも使える。

### 単純CASE式 (Simple CASE)

```sql
SELECT name, department_id,
    CASE department_id
        WHEN 1 THEN '営業'
        WHEN 2 THEN '開発'
        WHEN 3 THEN '人事'
        ELSE 'その他'
    END AS dept_label
FROM employees;
```

### 検索CASE式 (Searched CASE)

```sql
SELECT name, salary,
    CASE
        WHEN salary >= 800 THEN '高'
        WHEN salary >= 500 THEN '中'
        ELSE '低'
    END AS salary_grade
FROM employees;
```

### CASE式と集約関数の組み合わせ

ピボット（クロス集計）を手動で行う:

```sql
SELECT
    d.name AS department,
    COUNT(*)                                         AS total,
    COUNT(*) FILTER (WHERE e.salary >= 600)          AS high_salary_count,
    -- FILTER が使えない環境では CASE を使う:
    SUM(CASE WHEN e.salary >= 600 THEN 1 ELSE 0 END) AS high_salary_count_v2
FROM employees e
JOIN departments d ON e.department_id = d.id
GROUP BY d.name;
```

> PostgreSQL は `FILTER (WHERE ...)` をサポートしており、`CASE` より読みやすい場合が多い。ただし他のDBMSとの互換性を考えると `CASE` も知っておく必要がある。

### CASE式でのNULL判定

```sql
-- NG: 単純CASEではNULLを判定できない（NULL = NULL は UNKNOWN）
CASE manager_id WHEN NULL THEN 'トップ' END  -- 常にNULL

-- OK: 検索CASEを使う
CASE WHEN manager_id IS NULL THEN 'トップ' ELSE '部下あり' END
```

---

## 5. 集合演算 (Set Operations)

複数の `SELECT` 結果を集合演算で結合する。

### 演算子一覧

| 演算子 | 意味 | 重複 |
|--------|------|------|
| `UNION` | 和集合 | 除去 |
| `UNION ALL` | 和集合 | 保持 |
| `INTERSECT` | 積集合 | 除去 |
| `EXCEPT` | 差集合 | 除去 |

- 各SELECTのカラム数とデータ型が一致する必要がある
- `ORDER BY` は最後のSELECTの後に1つだけ記述可能

### 実践例

```sql
-- 営業部または開発部に所属する社員（重複除去）
SELECT e.name FROM employees e JOIN departments d ON e.department_id = d.id WHERE d.name = '営業'
UNION
SELECT e.name FROM employees e JOIN departments d ON e.department_id = d.id WHERE d.name = '開発';

-- プロジェクトAにもBにも参加している社員
SELECT employee_id FROM assignments WHERE project_id = 1
INTERSECT
SELECT employee_id FROM assignments WHERE project_id = 2;

-- プロジェクトAに参加しているがBには参加していない社員
SELECT employee_id FROM assignments WHERE project_id = 1
EXCEPT
SELECT employee_id FROM assignments WHERE project_id = 2;
```

### UNION vs UNION ALL

`UNION` は暗黙的に `DISTINCT` 処理を行うため遅い。重複がないことが分かっている場合や、重複を許容する場合は `UNION ALL` を使う。

```sql
-- 異なるテーブルからの結合なので重複しない → UNION ALL が効率的
SELECT name, 'employee' AS type FROM employees
UNION ALL
SELECT name, 'department' AS type FROM departments;
```

---

## 6. LATERAL JOIN

`LATERAL` は `FROM` 句の中で、直前のテーブルのカラムを参照できるサブクエリを可能にする。相関サブクエリを `FROM` 句で使いたい場合に有効。

### 構文

```sql
SELECT ...
FROM table_a AS a
JOIN LATERAL (
    SELECT ... FROM table_b WHERE table_b.col = a.col  -- a を参照できる
    LIMIT n
) AS sub ON true;
```

### 実践例: 各部門の上位2名

```sql
SELECT d.name AS department, top.name AS employee, top.salary
FROM departments d
JOIN LATERAL (
    SELECT e.name, e.salary
    FROM employees e
    WHERE e.department_id = d.id
    ORDER BY e.salary DESC
    LIMIT 2
) AS top ON true;
```

`LEFT JOIN LATERAL ... ON true` にすると、該当する行がない部門も結果に含まれる。

### LATERAL vs ウィンドウ関数

上記と同等のことはウィンドウ関数でも実現できる:

```sql
WITH ranked AS (
    SELECT e.name, e.salary, e.department_id,
           ROW_NUMBER() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rn
    FROM employees e
)
SELECT d.name AS department, r.name AS employee, r.salary
FROM ranked r
JOIN departments d ON r.department_id = d.id
WHERE r.rn <= 2;
```

使い分けの目安:
- **LATERAL**: `LIMIT` で行数を制限したい場合、JOINが複雑な場合に有利
- **ウィンドウ関数**: ランキング全体が必要な場合、フィルタ条件が柔軟な場合に有利

---

## まとめ

| 機能 | 主な用途 |
|------|----------|
| CTE | クエリの分割・可読性向上 |
| 再帰CTE | 木構造・階層データの走査 |
| ウィンドウ関数 | 行を潰さない集約・順位付け・前後行比較 |
| CASE式 | 条件分岐・ピボット |
| 集合演算 | 複数SELECTの結合・差分 |
| LATERAL JOIN | FROM句での相関サブクエリ |

これらを組み合わせることで、アプリケーション側で行っていた複雑なデータ加工の多くをSQL単体で処理できるようになる。
