# 第1回 自己解答: SQLクエリの基礎

スキーマ参照:
```sql
-- departments(id, name, location)
-- employees(id, name, email, department_id, salary, hire_date, manager_id)
-- projects(id, name, budget, start_date, end_date)
-- assignments(employee_id, project_id, role, assigned_date)
```

---

## 演習1: 基本的なSELECTとフィルタリング

2024年以降に入社し、給与が450,000以上の従業員の名前と給与を、給与の降順で取得せよ。

```sql

```

---

## 演習2: パターンマッチとIN

部署IDが 1, 3, 5 のいずれかに所属し、名前に「田」を含む従業員を取得せよ。

```sql

```

---

## 演習3: INNER JOINと複数テーブル結合

全従業員について、名前、部署名、担当プロジェクト名、役割を取得せよ。プロジェクトにアサインされていない従業員も含めること。

```sql

```

---

## 演習4: 集約関数とGROUP BY

部署ごとに、従業員数、平均給与（小数点以下2桁）、最高給与を求めよ。従業員数が2人以上の部署のみ表示し、平均給与の降順でソートせよ。

```sql

```

---

## 演習5: STRING_AGGとARRAY_AGG

各プロジェクトについて、プロジェクト名と、アサインされた従業員の名前をカンマ区切りの文字列で表示せよ（名前のアルファベット順）。アサインのないプロジェクトも含めること。

```sql

```

---

## 演習6: スカラーサブクエリ

全社の平均給与より高い給与を受け取っている従業員の名前、給与、平均給与との差額を表示せよ。差額の降順でソートすること。

```sql

```

---

## 演習7: EXISTSと相関サブクエリ

2つのプロジェクト以上にアサインされている従業員の名前と、アサインされているプロジェクト数を取得せよ。`EXISTS` を使う方法と、`GROUP BY` を使う方法の2通りで書け。

**方法1: GROUP BY + HAVING**

```sql

```

**方法2: 相関サブクエリ**

```sql

```

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
(a):

(b):

(c):

(d):
```

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
(a):

(b):

(c):
```

---

## 演習10: 総合問題

「東京」にある部署に所属する従業員のうち、予算が1,000,000以上のプロジェクトにリーダー（`role = 'Lead'`）としてアサインされている人の名前、部署名、プロジェクト名、予算を取得せよ。予算の降順でソートすること。

```sql

```
