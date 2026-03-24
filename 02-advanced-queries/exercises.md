# 第2回 演習: 高度なクエリ (Advanced Queries)

## サンプルデータ

第1回と同じデータを使用します（`make setup` または `make seed`）。

スキーマ参照:
```sql
-- departments(id, name, location)
-- employees(id, name, email, department_id, salary, hire_date, manager_id)
-- projects(id, name, budget, start_date, end_date)
-- assignments(employee_id, project_id, role, assigned_date)
```

---

## 問題1: CTE基礎 — 部門別統計

各部門について、所属人数・平均給与・最高給与を計算するCTEを定義し、平均給与が全社平均を超える部門のみを表示せよ。結果には部門名・所属人数・平均給与・最高給与を含めること。

**期待される出力 (3行):**
```
   department    | emp_count | dept_avg_salary | max_salary
-----------------+-----------+-----------------+------------
 経理部           |         1 |       550000.00 |     550000
 開発部           |         4 |       512500.00 |     600000
 マーケティング部  |         3 |       493333.33 |     530000
```
※ 全社平均 = 475,000円。営業部(436,667)・人事部(455,000)は全社平均以下のため除外。部署未配属の西村恵子は INNER JOIN により除外。

**あなたの解答:**

```

```

<details>
<summary>解答</summary>

```sql
WITH dept_stats AS (
    SELECT
        department_id,
        COUNT(*)          AS emp_count,
        AVG(salary)       AS avg_salary,
        MAX(salary)       AS max_salary
    FROM employees
    GROUP BY department_id
),
company_avg AS (
    SELECT AVG(salary) AS avg_salary FROM employees
)
SELECT
    d.name AS department,
    ds.emp_count,
    ROUND(ds.avg_salary, 2)  AS dept_avg_salary,
    ds.max_salary
FROM dept_stats ds
JOIN departments d ON ds.department_id = d.id
CROSS JOIN company_avg ca
WHERE ds.avg_salary > ca.avg_salary
ORDER BY ds.avg_salary DESC;
```

ポイント: 複数CTEをカンマ区切りで定義し、全社平均と部門平均を比較している。

</details>

---

## 問題2: 再帰CTE — 組織階層

`employees.manager_id` を使って、全社員の組織階層を表示せよ。以下のカラムを含むこと:
- `name` — 社員名
- `depth` — 階層の深さ（トップを1とする）
- `path` — ルートからの経路（例: `"山田太郎 → 鈴木花子 → 伊藤美咲"`）

結果は `path` の昇順で並べること。

**期待される出力 (14行):**
```
    name     | depth |                   path
-------------+-------+------------------------------------------
 山田太郎    |     1 | 山田太郎
 佐藤健      |     2 | 山田太郎 → 佐藤健
 小林達也    |     3 | 山田太郎 → 佐藤健 → 小林達也
 松本浩二    |     3 | 山田太郎 → 佐藤健 → 松本浩二
 加藤由美    |     2 | 山田太郎 → 加藤由美
 渡辺一郎    |     2 | 山田太郎 → 渡辺一郎
 上田明      |     3 | 山田太郎 → 渡辺一郎 → 上田明
 吉田真一    |     3 | 山田太郎 → 渡辺一郎 → 吉田真一
 田中誠      |     2 | 山田太郎 → 田中誠
 中村さくら  |     3 | 山田太郎 → 田中誠 → 中村さくら
 西村恵子    |     2 | 山田太郎 → 西村恵子
 鈴木花子    |     2 | 山田太郎 → 鈴木花子
 伊藤美咲    |     3 | 山田太郎 → 鈴木花子 → 伊藤美咲
 田村洋子    |     3 | 山田太郎 → 鈴木花子 → 田村洋子
```
※ 並び順は `path_arr`（配列）の辞書順 = Unicodeコードポイント順。

**あなたの解答:**

```

```

<details>
<summary>解答</summary>

```sql
WITH RECURSIVE org_tree AS (
    -- ベースケース: トップ（manager_id IS NULL）
    SELECT
        id, name, manager_id,
        1 AS depth,
        ARRAY[name] AS path_arr
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- 再帰部
    SELECT
        e.id, e.name, e.manager_id,
        ot.depth + 1,
        ot.path_arr || e.name
    FROM employees e
    JOIN org_tree ot ON e.manager_id = ot.id
)
SELECT
    name,
    depth,
    array_to_string(path_arr, ' → ') AS path
FROM org_tree
ORDER BY path_arr;
```

ポイント: `ARRAY` 型を使って経路を蓄積し、`array_to_string` で表示用に変換する。`ORDER BY path_arr` で配列の辞書順ソートになる。

</details>

---

## 問題3: ウィンドウ関数 — 部門内ランキング

各社員について、所属部門内での給与ランキングを3種類（`ROW_NUMBER`, `RANK`, `DENSE_RANK`）で算出せよ。結果には社員名・部門名・給与・3種類のランキングを含め、部門名昇順 → 給与降順で並べること。

**期待される出力 (13行 — 部署未配属の西村恵子を除く):**
```
    name    | department        | salary | row_num | rank | dense_rank
------------+-------------------+--------+---------+------+------------
 山田太郎   | 開発部             | 600000 |       1 |    1 |          1
 鈴木花子   | 開発部             | 500000 |       2 |    2 |          2  ← 同額 (*)
 田村洋子   | 開発部             | 500000 |       3 |    2 |          2  ← 同額 (*)
 伊藤美咲   | 開発部             | 450000 |       4 |    4 |          3
 佐藤健     | 営業部             | 480000 |       1 |    1 |          1
 小林達也   | 営業部             | 430000 |       2 |    2 |          2
 松本浩二   | 営業部             | 400000 |       3 |    3 |          3
 田中誠     | 人事部             | 520000 |       1 |    1 |          1
 中村さくら  | 人事部             | 390000 |       2 |    2 |          2
 加藤由美   | 経理部             | 550000 |       1 |    1 |          1
 上田明     | マーケティング部    | 530000 |       1 |    1 |          1
 吉田真一   | マーケティング部    | 490000 |       2 |    2 |          2
 渡辺一郎   | マーケティング部    | 460000 |       3 |    3 |          3
```
(*) 鈴木花子・田村洋子は同額500,000円 → RANK=2 で4位をスキップ、DENSE_RANK=2 でスキップなし、ROW_NUMBER は2か3（不定）。

**あなたの解答:**

```

```

<details>
<summary>解答</summary>

```sql
SELECT
    e.name,
    d.name AS department,
    e.salary,
    ROW_NUMBER() OVER w AS row_num,
    RANK()       OVER w AS rank,
    DENSE_RANK() OVER w AS dense_rank
FROM employees e
JOIN departments d ON e.department_id = d.id
WINDOW w AS (PARTITION BY e.department_id ORDER BY e.salary DESC)
ORDER BY d.name, e.salary DESC;
```

ポイント: `WINDOW` 句で同一のウィンドウ定義を再利用している。同じ給与の社員がいる場合に3つの関数の違いが現れる。

</details>

---

## 問題4: ウィンドウ関数 — 累計と移動平均

社員を `hire_date` の昇順に並べ、以下を計算せよ:
- `running_total` — 給与の累計
- `moving_avg_3` — 直近3人（自分を含む）の給与の移動平均（小数第2位まで）
- `hire_order` — 入社順の連番

**期待される出力 (14行):**
```
    name    | hire_date  | salary | hire_order | running_total | moving_avg_3
------------+------------+--------+------------+---------------+--------------
 加藤由美   | 2019-08-01 | 550000 |          1 |        550000 |    550000.00
 山田太郎   | 2020-04-01 | 600000 |          2 |       1150000 |    575000.00
 佐藤健     | 2021-01-15 | 480000 |          3 |       1630000 |    543333.33
 鈴木花子   | 2022-07-01 | 500000 |          4 |       2130000 |    526666.67
 小林達也   | 2022-11-01 | 430000 |          5 |       2560000 |    470000.00
 田村洋子   | 2023-04-01 | 500000 |          6 |       3060000 |    476666.67
 西村恵子   | 2023-06-01 | 350000 |          7 |       3410000 |    426666.67
 渡辺一郎   | 2023-09-01 | 460000 |          8 |       3870000 |    436666.67
 松本浩二   | 2023-10-01 | 400000 |          9 |       4270000 |    403333.33
 中村さくら  | 2024-01-10 | 390000 |         10 |       4660000 |    416666.67
 田中誠     | 2024-03-01 | 520000 |         11 |       5180000 |    436666.67
 吉田真一   | 2024-05-01 | 490000 |         12 |       5670000 |    466666.67
 伊藤美咲   | 2024-06-01 | 450000 |         13 |       6120000 |    486666.67
 上田明     | 2024-08-01 | 530000 |         14 |       6650000 |    490000.00
```

**あなたの解答:**

```

```

<details>
<summary>解答</summary>

```sql
SELECT
    name,
    hire_date,
    salary,
    ROW_NUMBER() OVER (ORDER BY hire_date) AS hire_order,
    SUM(salary)  OVER (ORDER BY hire_date) AS running_total,
    ROUND(
        AVG(salary) OVER (
            ORDER BY hire_date
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2
    ) AS moving_avg_3
FROM employees
ORDER BY hire_date;
```

ポイント: `SUM() OVER (ORDER BY ...)` のデフォルトフレームは `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` なので累計になる。移動平均には `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` を明示している。

</details>

---

## 問題5: LAG/LEAD — 前回との比較

社員を入社日順に並べ、前の社員との給与差と、給与が前の社員より高いかどうかを示すフラグ（`'↑'`, `'↓'`, `'→'`）を表示せよ。最初の社員の差分は `NULL` でよい。

**期待される出力 (14行、抜粋):**
```
    name    | hire_date  | salary | prev_salary |  diff  | trend
------------+------------+--------+-------------+--------+-------
 加藤由美   | 2019-08-01 | 550000 |        NULL |   NULL | NULL
 山田太郎   | 2020-04-01 | 600000 |      550000 |  50000 | ↑
 佐藤健     | 2021-01-15 | 480000 |      600000 | -120000| ↓
 鈴木花子   | 2022-07-01 | 500000 |      480000 |  20000 | ↑
 小林達也   | 2022-11-01 | 430000 |      500000 | -70000 | ↓
 田村洋子   | 2023-04-01 | 500000 |      430000 |  70000 | ↑
 ...
```

**あなたの解答:**

```

```

<details>
<summary>解答</summary>

```sql
SELECT
    name,
    hire_date,
    salary,
    LAG(salary) OVER (ORDER BY hire_date) AS prev_salary,
    salary - LAG(salary) OVER (ORDER BY hire_date) AS diff,
    CASE
        WHEN salary > LAG(salary) OVER (ORDER BY hire_date) THEN '↑'
        WHEN salary < LAG(salary) OVER (ORDER BY hire_date) THEN '↓'
        WHEN salary = LAG(salary) OVER (ORDER BY hire_date) THEN '→'
        ELSE NULL
    END AS trend
FROM employees
ORDER BY hire_date;
```

ポイント: `LAG()` のデフォルト offset は1。最初の行では `LAG()` が `NULL` を返すため、`CASE` の `ELSE NULL` で処理される。

</details>

---

## 問題6: CASE式 — 給与帯別クロス集計

部門ごとに、給与帯（500,000未満: '低', 500,000以上700,000未満: '中', 700,000以上: '高'）別の人数を1行にまとめるクロス集計を行え。結果は以下の形式:

| department | low | mid | high | total |
|------------|-----|-----|------|-------|

**期待される出力 (5行 — 従業員がいる部署のみ):**
```
   department    | low | mid | high | total
-----------------+-----+-----+------+-------
 マーケティング部  |   1 |   2 |    0 |     3
 営業部           |   3 |   0 |    0 |     3
 開発部           |   1 |   3 |    0 |     4
 人事部           |   2 |   0 |    0 |     2
 経理部           |   0 |   1 |    0 |     1
```
※ 部署未配属の西村恵子(350,000)はINNER JOINで除外。給与帯: 低(<500k), 中(500k〜699k), 高(≥700k)。

**あなたの解答:**

```

```

<details>
<summary>解答</summary>

```sql
SELECT
    d.name AS department,
    COUNT(*) FILTER (WHERE e.salary < 500000)                       AS low,
    COUNT(*) FILTER (WHERE e.salary >= 500000 AND e.salary < 700000) AS mid,
    COUNT(*) FILTER (WHERE e.salary >= 700000)                       AS high,
    COUNT(*) AS total
FROM employees e
JOIN departments d ON e.department_id = d.id
GROUP BY d.name
ORDER BY d.name;

-- CASE版（他DBMS互換）:
-- SELECT
--     d.name AS department,
--     SUM(CASE WHEN e.salary < 500000 THEN 1 ELSE 0 END) AS low,
--     SUM(CASE WHEN e.salary >= 500000 AND e.salary < 700000 THEN 1 ELSE 0 END) AS mid,
--     SUM(CASE WHEN e.salary >= 700000 THEN 1 ELSE 0 END) AS high,
--     COUNT(*) AS total
-- FROM employees e
-- JOIN departments d ON e.department_id = d.id
-- GROUP BY d.name
-- ORDER BY d.name;
```

ポイント: PostgreSQL の `FILTER (WHERE ...)` を使えば `CASE` より簡潔に書ける。

</details>

---

## 問題7: 集合演算 — プロジェクト参加状況

以下の3つのクエリを集合演算で求めよ:

1. プロジェクト1にもプロジェクト2にも参加している社員のIDと名前
2. プロジェクト1には参加しているがプロジェクト2には参加していない社員のIDと名前
3. プロジェクト1またはプロジェクト2のいずれかに参加している社員のIDと名前（重複なし）

**期待される出力:**

1. INTERSECT (2行):
```
 id |   name
----+--------
  1 | 山田太郎
  2 | 鈴木花子
```

2. EXCEPT (1行):
```
 id |   name
----+--------
 11 | 田村洋子
```

3. UNION (4行):
```
 id |   name
----+--------
  1 | 山田太郎
  2 | 鈴木花子
  5 | 伊藤美咲
 11 | 田村洋子
```
※ プロジェクト1: 山田太郎, 鈴木花子, 田村洋子 / プロジェクト2: 山田太郎, 鈴木花子, 佐藤健, 伊藤美咲

**あなたの解答:**

```

```

<details>
<summary>解答</summary>

```sql
-- 1. 両方に参加（積集合）
SELECT e.id, e.name
FROM employees e JOIN assignments a ON e.id = a.employee_id
WHERE a.project_id = 1
INTERSECT
SELECT e.id, e.name
FROM employees e JOIN assignments a ON e.id = a.employee_id
WHERE a.project_id = 2;

-- 2. 1のみ参加（差集合）
SELECT e.id, e.name
FROM employees e JOIN assignments a ON e.id = a.employee_id
WHERE a.project_id = 1
EXCEPT
SELECT e.id, e.name
FROM employees e JOIN assignments a ON e.id = a.employee_id
WHERE a.project_id = 2;

-- 3. いずれかに参加（和集合）
SELECT e.id, e.name
FROM employees e JOIN assignments a ON e.id = a.employee_id
WHERE a.project_id = 1
UNION
SELECT e.id, e.name
FROM employees e JOIN assignments a ON e.id = a.employee_id
WHERE a.project_id = 2;
```

ポイント: `UNION` は重複除去、`INTERSECT` は共通部分、`EXCEPT` は差分を返す。

</details>

---

## 問題8: LATERAL JOIN — 各部門の高給者トップ3

各部門について、給与上位3名の社員名・給与を表示せよ。社員がいない部門も結果に含めること（社員情報は `NULL` で表示）。

**期待される出力 (16行):**
```
   department    |  employee  | salary
-----------------+------------+--------
 マーケティング部  | 上田明      | 530000
 マーケティング部  | 吉田真一    | 490000
 マーケティング部  | 渡辺一郎    | 460000
 営業部           | 佐藤健      | 480000
 営業部           | 小林達也    | 430000
 営業部           | 松本浩二    | 400000
 開発部           | 山田太郎    | 600000
 開発部           | 鈴木花子    | 500000
 開発部           | 田村洋子    | 500000
 人事部           | 田中誠      | 520000
 人事部           | 中村さくら  | 390000
 経理部           | 加藤由美    | 550000
 法務部           | NULL        |   NULL
```
※ 法務部は従業員0人 → LEFT JOIN LATERAL により NULL で表示。

**あなたの解答:**

```

```

<details>
<summary>解答</summary>

```sql
SELECT
    d.name AS department,
    top.name AS employee,
    top.salary
FROM departments d
LEFT JOIN LATERAL (
    SELECT e.name, e.salary
    FROM employees e
    WHERE e.department_id = d.id
    ORDER BY e.salary DESC
    LIMIT 3
) AS top ON true
ORDER BY d.name, top.salary DESC NULLS LAST;
```

ポイント: `LEFT JOIN LATERAL ... ON true` を使うことで、サブクエリの結果が0行の部門も結果に残る。`LIMIT 3` をサブクエリ内で適用するため、ウィンドウ関数版より効率的な場合がある。

</details>

---

## 問題9: 総合 — プロジェクト別レポート

各プロジェクトについて以下の情報を1つのクエリで出力せよ:
- プロジェクト名
- 予算
- 参加者数
- 参加者の平均給与
- 予算規模（`budget >= 1000000`: '大規模', `budget >= 500000`: '中規模', それ以外: '小規模'）
- 予算の全プロジェクト内順位（降順）

参加者がいないプロジェクトも含めること。

**期待される出力 (5行):**
```
        project        |  budget  | member_count | avg_salary  | budget_scale | budget_rank
-----------------------+----------+--------------+-------------+--------------+-------------
 基幹システム刷新        | 5000000  |            3 |   536666.67 | 大規模        |           1
 ECサイト構築           | 2000000  |            4 |   507500.00 | 大規模        |           2
 ブランドリニューアル     | 1500000  |            3 |   493333.33 | 大規模        |           3
 採用管理システム        |  800000  |            2 |   510000.00 | 中規模        |           4
 内部統制整備           |  600000  |            0 |        0.00 | 中規模        |           5
```
※ 内部統制整備は参加者なし → member_count=0, avg_salary=0.00（COALESCE で NULL→0変換）。

**あなたの解答:**

```

```

<details>
<summary>解答</summary>

```sql
WITH project_members AS (
    SELECT
        a.project_id,
        COUNT(*)        AS member_count,
        AVG(e.salary)   AS avg_salary
    FROM assignments a
    JOIN employees e ON a.employee_id = e.id
    GROUP BY a.project_id
)
SELECT
    p.name AS project,
    p.budget,
    COALESCE(pm.member_count, 0) AS member_count,
    ROUND(COALESCE(pm.avg_salary, 0), 2) AS avg_salary,
    CASE
        WHEN p.budget >= 1000000 THEN '大規模'
        WHEN p.budget >= 500000  THEN '中規模'
        ELSE '小規模'
    END AS budget_scale,
    RANK() OVER (ORDER BY p.budget DESC) AS budget_rank
FROM projects p
LEFT JOIN project_members pm ON p.id = pm.project_id
ORDER BY p.budget DESC;
```

ポイント: CTE・CASE式・ウィンドウ関数・LEFT JOINを組み合わせた総合問題。`COALESCE` で参加者0のプロジェクトの `NULL` を処理している。

</details>

---

## 問題10: 総合 — 部門間の給与分布比較

各部門について、給与の四分位数（`NTILE(4)` ベース）ごとの人数と平均給与を表示せよ。結果は以下の形式:

| department | quartile | count | avg_salary |
|------------|----------|-------|------------|

**期待される出力（抜粋 — 人数が多い部署のみ）:**
```
   department    | quartile | count | avg_salary
-----------------+----------+-------+------------
 マーケティング部  |        1 |     1 |  460000.00  ← 渡辺一郎
 マーケティング部  |        2 |     1 |  490000.00  ← 吉田真一
 マーケティング部  |        3 |     1 |  530000.00  ← 上田明
 開発部           |        1 |     1 |  450000.00  ← 伊藤美咲
 開発部           |        2 |     1 |  500000.00  ← 鈴木花子or田村洋子
 開発部           |        3 |     1 |  500000.00  ← 田村洋子or鈴木花子
 開発部           |        4 |     1 |  600000.00  ← 山田太郎
 ...
```
※ NTILE(4) で各部門内を4分割するが、人数が4未満の部署では一部の四分位に複数の行が入る場合がある。

**あなたの解答:**

```

```

<details>
<summary>解答</summary>

```sql
WITH quartiled AS (
    SELECT
        e.department_id,
        e.salary,
        NTILE(4) OVER (
            PARTITION BY e.department_id
            ORDER BY e.salary
        ) AS quartile
    FROM employees e
)
SELECT
    d.name AS department,
    q.quartile,
    COUNT(*)             AS count,
    ROUND(AVG(q.salary), 2) AS avg_salary
FROM quartiled q
JOIN departments d ON q.department_id = d.id
GROUP BY d.name, q.quartile
ORDER BY d.name, q.quartile;
```

ポイント: `NTILE(4)` で各部門内の社員を給与順に4分割し、その結果をさらに `GROUP BY` で集計する。CTEでウィンドウ関数の結果を一度作り、外側のクエリで集約する2段階パターンはよく使う。

</details>
