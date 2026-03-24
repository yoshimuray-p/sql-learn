# 第1回 演習: SQLクエリの基礎

以下のスキーマを使用する（`lecture.md` と同一）。

```sql
-- departments(id, name, location)
-- employees(id, name, department_id, salary, hire_date)
-- projects(id, name, budget, start_date, end_date)
-- assignments(employee_id, project_id, role, assigned_date)
```

---

## 演習1: 基本的なSELECTとフィルタリング

2024年以降に入社し、給与が450,000以上の従業員の名前と給与を、給与の降順で取得せよ。

**あなたの解答:**

```sql

```

<details><summary>解答</summary>

```sql
SELECT name, salary
FROM employees
WHERE hire_date >= '2024-01-01'
  AND salary >= 450000
ORDER BY salary DESC;
```

**解説**: `WHERE` で複数条件を `AND` で結合する。日付の比較は文字列リテラル `'YYYY-MM-DD'` 形式で行える。`ORDER BY ... DESC` で降順ソート。

</details>

---

## 演習2: パターンマッチとIN

部署IDが 1, 3, 5 のいずれかに所属し、名前に「田」を含む従業員を取得せよ。

**あなたの解答:**

```sql

```

<details><summary>解答</summary>

```sql
SELECT id, name, department_id
FROM employees
WHERE department_id IN (1, 3, 5)
  AND name LIKE '%田%';
```

**解説**: `IN` でリスト照合、`LIKE '%田%'` で部分一致検索。`ILIKE` を使えば英字の大文字小文字を無視できる（この例では日本語なので差はない）。

</details>

---

## 演習3: INNER JOINと複数テーブル結合

全従業員について、名前、部署名、担当プロジェクト名、役割を取得せよ。プロジェクトにアサインされていない従業員も含めること。

**あなたの解答:**

```sql

```

<details><summary>解答</summary>

```sql
SELECT e.name AS employee,
       d.name AS department,
       p.name AS project,
       a.role
FROM employees e
LEFT JOIN departments d ON e.department_id = d.id
LEFT JOIN assignments a ON e.id = a.employee_id
LEFT JOIN projects p ON a.project_id = p.id
ORDER BY e.name;
```

**解説**: 「アサインされていない従業員も含める」ため、`assignments` と `projects` への結合は `LEFT JOIN` を使う。`INNER JOIN` にすると、アサインのない従業員が結果から除外される。`departments` も `LEFT JOIN` にすることで、部署未配属の従業員も含まれる。

</details>

---

## 演習4: 集約関数とGROUP BY

部署ごとに、従業員数、平均給与（小数点以下2桁）、最高給与を求めよ。従業員数が2人以上の部署のみ表示し、平均給与の降順でソートせよ。

**あなたの解答:**

```sql

```

<details><summary>解答</summary>

```sql
SELECT d.name AS department,
       COUNT(*) AS employee_count,
       ROUND(AVG(e.salary), 2) AS avg_salary,
       MAX(e.salary) AS max_salary
FROM employees e
INNER JOIN departments d ON e.department_id = d.id
GROUP BY d.name
HAVING COUNT(*) >= 2
ORDER BY avg_salary DESC;
```

**解説**: `HAVING` は `GROUP BY` の結果に対してフィルタをかける。`WHERE` は集約前、`HAVING` は集約後のフィルタであることを区別する。`ROUND` で小数点以下の桁数を指定できる。`ORDER BY` では `SELECT` で定義したエイリアス `avg_salary` を使用可能（実行順序: SELECT → ORDER BY）。

</details>

---

## 演習5: STRING_AGGとARRAY_AGG

各プロジェクトについて、プロジェクト名と、アサインされた従業員の名前をカンマ区切りの文字列で表示せよ（名前のアルファベット順）。アサインのないプロジェクトも含めること。

**あなたの解答:**

```sql

```

<details><summary>解答</summary>

```sql
SELECT p.name AS project,
       COALESCE(STRING_AGG(e.name, ', ' ORDER BY e.name), 'アサインなし') AS members
FROM projects p
LEFT JOIN assignments a ON p.id = a.project_id
LEFT JOIN employees e ON a.employee_id = e.id
GROUP BY p.name
ORDER BY p.name;
```

**解説**: `LEFT JOIN` でアサインのないプロジェクトも含める。`STRING_AGG` は `NULL` のみの場合 `NULL` を返すため、`COALESCE` でフォールバック値を設定する。`STRING_AGG` 内で `ORDER BY` を指定でき、連結順を制御できる。

</details>

---

## 演習6: スカラーサブクエリ

全社の平均給与より高い給与を受け取っている従業員の名前、給与、平均給与との差額を表示せよ。差額の降順でソートすること。

**あなたの解答:**

```sql

```

<details><summary>解答</summary>

```sql
SELECT name,
       salary,
       salary - (SELECT AVG(salary) FROM employees) AS diff
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees)
ORDER BY diff DESC;
```

**解説**: `(SELECT AVG(salary) FROM employees)` はスカラーサブクエリで、1行1列（平均給与）を返す。`WHERE` と `SELECT` の両方で使用している。同じサブクエリの重複が気になる場合は CTE（`WITH` 句、次回以降で扱う）を使う方法もある。

</details>

---

## 演習7: EXISTSと相関サブクエリ

2つのプロジェクト以上にアサインされている従業員の名前と、アサインされているプロジェクト数を取得せよ。`EXISTS` を使う方法と、`GROUP BY` を使う方法の2通りで書け。

**あなたの解答:**

```sql

```

<details><summary>解答</summary>

**方法1: GROUP BY + HAVING**

```sql
SELECT e.name,
       COUNT(*) AS project_count
FROM employees e
INNER JOIN assignments a ON e.id = a.employee_id
GROUP BY e.id, e.name
HAVING COUNT(*) >= 2
ORDER BY project_count DESC;
```

**方法2: 相関サブクエリ（スカラーサブクエリ + WHERE）**

```sql
SELECT e.name,
       (SELECT COUNT(*)
        FROM assignments a
        WHERE a.employee_id = e.id) AS project_count
FROM employees e
WHERE (SELECT COUNT(*)
       FROM assignments a
       WHERE a.employee_id = e.id) >= 2
ORDER BY project_count DESC;
```

**解説**: 方法1が簡潔で効率的。方法2は相関サブクエリを使う例で、外側クエリの `e.id` を内側で参照している。実務では方法1を使うべきだが、相関サブクエリの動作を理解することは重要。

なお、`EXISTS` 単体では「2つ以上」という条件を直接表現しにくい。`EXISTS` は「存在するかどうか」の判定に適しており、個数の条件には `COUNT` + `HAVING` や相関サブクエリの方が自然。

</details>

---

## 演習8: NULLの扱い

以下のクエリの結果を予測し、理由を説明せよ。

```sql
-- (a)
SELECT COUNT(*), COUNT(department_id)
FROM employees;

-- (b)
SELECT *
FROM employees
WHERE department_id = NULL;

-- (c)
SELECT *
FROM employees
WHERE department_id <> 1;

-- (d)
SELECT COALESCE(NULL, NULL, 'default');
```

**あなたの解答:**

```

```

<details><summary>解答</summary>

**(a)** `COUNT(*)` は全行数を返す（`NULL` 含む）。`COUNT(department_id)` は `department_id` が `NULL` でない行のみ数える。結果が異なる場合、`department_id` が `NULL` の行が存在する。

**(b)** 結果は **0行**。`NULL = NULL` は `UNKNOWN` であり、`WHERE` は `TRUE` の行のみ返す。正しくは `WHERE department_id IS NULL`。

**(c)** `department_id` が `NULL` の行は結果に**含まれない**。`NULL <> 1` は `UNKNOWN` であり、`WHERE` の条件を満たさないため。`NULL` の行も含めたい場合:

```sql
WHERE department_id <> 1 OR department_id IS NULL
-- または
WHERE department_id IS DISTINCT FROM 1
```

`IS DISTINCT FROM` は PostgreSQL で `NULL` を通常の値のように比較する演算子。

**(d)** 結果は `'default'`。`COALESCE` は引数を左から順に評価し、最初の非 `NULL` 値を返す。

</details>

---

## 演習9: 実行順序の理解

以下のクエリのうち、エラーになるものはどれか。理由を実行順序に基づいて説明せよ。

```sql
-- (a)
SELECT department_id, COUNT(*) AS cnt
FROM employees
GROUP BY department_id
HAVING cnt >= 2;

-- (b)
SELECT department_id, COUNT(*) AS cnt
FROM employees
GROUP BY department_id
ORDER BY cnt DESC;

-- (c)
SELECT salary * 12 AS annual
FROM employees
WHERE annual > 6000000;
```

**あなたの解答:**

```

```

<details><summary>解答</summary>

**(a) エラー**（標準SQLでは）。`HAVING` は `SELECT` より先に評価されるため、エイリアス `cnt` を参照できない。正しくは:

```sql
HAVING COUNT(*) >= 2
```

ただし PostgreSQL は `HAVING` でのエイリアス参照を許容する場合がある（拡張機能）。移植性を考えると式を直接書くべき。

**(b) OK**。`ORDER BY` は `SELECT` の後に評価されるため、エイリアス `cnt` を参照できる。

**(c) エラー**。`WHERE` は `SELECT` より先に評価されるため、エイリアス `annual` を参照できない。正しくは:

```sql
WHERE salary * 12 > 6000000
```

**実行順序**: FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT

</details>

---

## 演習10: 総合問題

「東京」にある部署に所属する従業員のうち、予算が1,000,000以上のプロジェクトにリーダー (`role = 'Lead'`) としてアサインされている人の名前、部署名、プロジェクト名、予算を取得せよ。予算の降順でソートすること。

**あなたの解答:**

```sql

```

<details><summary>解答</summary>

```sql
SELECT e.name AS employee,
       d.name AS department,
       p.name AS project,
       p.budget
FROM employees e
INNER JOIN departments d ON e.department_id = d.id
INNER JOIN assignments a ON e.id = a.employee_id
INNER JOIN projects p ON a.project_id = p.id
WHERE d.location = '東京'
  AND p.budget >= 1000000
  AND a.role = 'Lead'
ORDER BY p.budget DESC;
```

**解説**: 4テーブルの `INNER JOIN` を使用。条件はすべて `WHERE` で指定する。すべてのテーブルで一致が必要なので `INNER JOIN` が適切。

クエリの評価順序:
1. `FROM` / `JOIN`: 4テーブルを結合
2. `WHERE`: 東京の部署、予算100万以上、Leadロールでフィルタ
3. `SELECT`: 必要な列を選択
4. `ORDER BY`: 予算の降順でソート

</details>
