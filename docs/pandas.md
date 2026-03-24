# pandas 連携ガイド

SQLAlchemy 経由で PostgreSQL に接続し、pandas DataFrame として操作します。

## 接続

```python
from sqlalchemy import create_engine
import pandas as pd

engine = create_engine("postgresql://study_user:study_password@localhost:5432/study_db")
```

## クエリ結果を DataFrame に読み込む

```python
df = pd.read_sql("SELECT * FROM employees", engine)
```

## DataFrame を SQL で絞り込む

```python
df = pd.read_sql("""
    SELECT e.name, e.salary, d.name AS department
    FROM employees e
    JOIN departments d ON e.department_id = d.id
    WHERE e.salary > 500000
""", engine)
```

## DataFrame をテーブルに書き込む

```python
df.to_sql("テーブル名", engine, if_exists="replace", index=False)
# if_exists: "replace"（上書き）/ "append"（追加）/ "fail"（エラー）
```

## 基本的な集計

```python
# 部署ごとの平均給与
df.groupby("department")["salary"].mean()

# 上位 5 件
df.nlargest(5, "salary")
```
