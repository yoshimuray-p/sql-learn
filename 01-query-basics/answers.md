# 第1回 解答: SQLクエリの基礎

---

## 演習1: 基本的なSELECTとフィルタリング

```sql
SELECT name, salary
FROM employees
WHERE hire_date >= '2024-01-01'
  AND salary >= 450000
ORDER BY salary DESC;
```

**解説**: `WHERE` で複数条件を `AND` で結合する。日付の比較は文字列リテラル `'YYYY-MM-DD'` 形式で行える。`ORDER BY ... DESC` で降順ソート。

---

## 演習2: パターンマッチとIN

```sql
SELECT id, name, department_id
FROM employees
WHERE department_id IN (1, 3, 5)
  AND name LIKE '%田%';
```

**解説**: `IN` でリスト照合、`LIKE '%田%'` で部分一致検索。`ILIKE` を使えば英字の大文字小文字を無視できる（この例では日本語なので差はない）。

---

## 演習3: INNER JOINと複数テーブル結合

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

**解説**: 「アサインされていない従業員も含める」ため、`assignments` と `projects` への結合は `LEFT JOIN` を使う。`INNER JOIN` にすると、アサインのない従業員が結果から除外される。`departments` も `LEFT JOIN` にすることで、部署未配属の従業員（西村恵子）も含まれる。

---

## 演習4: 集約関数とGROUP BY

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

---

## 演習5: STRING_AGGとARRAY_AGG

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

---

## 演習6: スカラーサブクエリ

```sql
SELECT name,
       salary,
       salary - (SELECT AVG(salary) FROM employees) AS diff
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees)
ORDER BY diff DESC;
```

**解説**: `(SELECT AVG(salary) FROM employees)` はスカラーサブクエリで、1行1列（平均給与）を返す。`WHERE` と `SELECT` の両方で使用している。同じサブクエリの重複が気になる場合は CTE（`WITH` 句、次回以降で扱う）を使う方法もある。

---

## 演習7: EXISTSと相関サブクエリ

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

---

## 演習8: NULLの扱い

**(a)** `COUNT(*)` は全行数を返す（`NULL` 含む）。`COUNT(department_id)` は `department_id` が `NULL` でない行のみ数える。

- `COUNT(*)` = 14
- `COUNT(department_id)` = 13（西村恵子の department_id が NULL）

**(b)** 結果は **0行**。`NULL = NULL` は `UNKNOWN` であり、`WHERE` は `TRUE` の行のみ返す。正しくは `WHERE department_id IS NULL`。

**(c)** `department_id` が `NULL` の行は結果に**含まれない**。`NULL <> 1` は `UNKNOWN` であり、`WHERE` の条件を満たさないため。`NULL` の行も含めたい場合:

```sql
WHERE department_id <> 1 OR department_id IS NULL
-- または
WHERE department_id IS DISTINCT FROM 1
```

`IS DISTINCT FROM` は PostgreSQL で `NULL` を通常の値のように比較する演算子。

**(d)** 結果は `'default'`。`COALESCE` は引数を左から順に評価し、最初の非 `NULL` 値を返す。

---

## 演習9: 実行順序の理解

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

---

## 演習10: 総合問題

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
