# 環境構築とツール

このディレクトリでは、SQLコースで使用するPostgreSQLの環境構築方法と、データ分析に役立つPython pandasの利用方法を説明します。

## 目次

1. [PostgreSQL環境構築](#postgresql環境構築)
2. [Python pandasによるデータ分析](#python-pandasによるデータ分析)

---

## PostgreSQL環境構築

### 1. インストール方法

#### Ubuntu/Debian系
```bash
# PostgreSQLのインストール
sudo apt update
sudo apt install postgresql postgresql-contrib

# サービスの起動確認
sudo systemctl status postgresql
```

#### macOS (Homebrew)
```bash
# PostgreSQLのインストール
brew install postgresql@15

# サービスの起動
brew services start postgresql@15
```

#### Docker（推奨）
```bash
# PostgreSQLコンテナの起動
docker run --name postgres-study \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=studyuser \
  -e POSTGRES_DB=studydb \
  -p 5432:5432 \
  -d postgres:15

# 接続確認
docker exec -it postgres-study psql -U studyuser -d studydb
```

### 2. データベースの作成

```bash
# PostgreSQLユーザーとしてログイン
sudo -u postgres psql

# または直接psqlコマンドで
psql -U studyuser -d studydb
```

```sql
-- データベースの作成
CREATE DATABASE study_sql;

-- データベースに接続
\c study_sql

-- ユーザーの作成
CREATE USER study_user WITH PASSWORD 'password123';

-- 権限の付与
GRANT ALL PRIVILEGES ON DATABASE study_sql TO study_user;
```

### 3. 基本的なpsqlコマンド

```bash
# データベースに接続
psql -U study_user -d study_sql

# または環境変数を使用
export PGUSER=study_user
export PGDATABASE=study_sql
psql
```

#### 便利なメタコマンド

```sql
\l              -- データベース一覧
\c dbname       -- データベースの切り替え
\dt             -- テーブル一覧
\d tablename    -- テーブル構造の表示
\du             -- ユーザー一覧
\q              -- psqlの終了
\i filename.sql -- SQLファイルの実行
\o output.txt   -- 出力先の指定
\timing on      -- クエリ実行時間の表示
```

### 4. サンプルデータのセットアップ

```sql
-- サンプルテーブルの作成
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    department VARCHAR(50),
    salary NUMERIC(10, 2),
    hire_date DATE
);

-- サンプルデータの挿入
INSERT INTO employees (name, department, salary, hire_date) VALUES
    ('山田太郎', '営業', 450000, '2020-04-01'),
    ('佐藤花子', '開発', 520000, '2019-07-15'),
    ('鈴木一郎', '人事', 380000, '2021-01-10'),
    ('田中美咲', '開発', 580000, '2018-03-20'),
    ('高橋健太', '営業', 420000, '2020-09-01');
```

### 5. 設定ファイル

PostgreSQLの主要な設定ファイル：

- `postgresql.conf`: 主要な設定ファイル
- `pg_hba.conf`: クライアント認証設定

```bash
# 設定ファイルの場所を確認
SHOW config_file;
SHOW hba_file;
```

---

## Python pandasによるデータ分析

### 1. 環境構築

```bash
# 仮想環境の作成（推奨）
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 必要なパッケージのインストール
pip install pandas psycopg2-binary sqlalchemy jupyterlab
```

### 2. PostgreSQLとの接続

#### psycopg2を使用した接続

```python
import psycopg2
import pandas as pd

# データベース接続
conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="study_sql",
    user="study_user",
    password="password123"
)

# クエリの実行
query = "SELECT * FROM employees"
df = pd.read_sql(query, conn)

print(df)

# 接続を閉じる
conn.close()
```

#### SQLAlchemyを使用した接続（推奨）

```python
from sqlalchemy import create_engine
import pandas as pd

# 接続エンジンの作成
engine = create_engine('postgresql://study_user:password123@localhost:5432/study_sql')

# データの読み込み
df = pd.read_sql("SELECT * FROM employees", engine)

# DataFrameをSQLテーブルに保存
df.to_sql('employees_backup', engine, if_exists='replace', index=False)
```

### 3. 基本的なデータ操作

```python
import pandas as pd
from sqlalchemy import create_engine

# 接続
engine = create_engine('postgresql://study_user:password123@localhost:5432/study_sql')

# データの読み込み
df = pd.read_sql("SELECT * FROM employees", engine)

# データの確認
print(df.head())
print(df.info())
print(df.describe())

# 部署ごとの平均給与
salary_by_dept = df.groupby('department')['salary'].mean()
print(salary_by_dept)

# 条件でフィルタリング
high_salary = df[df['salary'] > 500000]

# 新しいカラムの追加
df['salary_in_million'] = df['salary'] / 1000000

# ソート
df_sorted = df.sort_values('salary', ascending=False)
```

### 4. SQLとpandasの組み合わせ

```python
# 複雑なクエリはSQLで、分析はpandasで
query = """
    SELECT 
        department,
        COUNT(*) as employee_count,
        AVG(salary) as avg_salary,
        MAX(salary) as max_salary
    FROM employees
    GROUP BY department
"""

dept_stats = pd.read_sql(query, engine)

# pandasでさらに加工
dept_stats['salary_range'] = dept_stats['max_salary'] - dept_stats['avg_salary']

# CSVに出力
dept_stats.to_csv('department_statistics.csv', index=False)
```

### 5. 大量データの処理

```python
# チャンク単位での読み込み（大量データ対応）
chunk_size = 10000
for chunk in pd.read_sql("SELECT * FROM large_table", engine, chunksize=chunk_size):
    # 各チャンクを処理
    processed = chunk[chunk['some_column'] > 100]
    print(f"Processed {len(processed)} rows")

# データのバッチ挿入
import numpy as np

# サンプルデータの生成
new_data = pd.DataFrame({
    'name': [f'Employee{i}' for i in range(1000)],
    'department': np.random.choice(['営業', '開発', '人事'], 1000),
    'salary': np.random.randint(300000, 800000, 1000)
})

# データベースに挿入
new_data.to_sql('employees', engine, if_exists='append', index=False)
```

### 6. データの可視化

```python
import matplotlib.pyplot as plt

# 部署ごとの従業員数
dept_counts = df['department'].value_counts()

plt.figure(figsize=(10, 6))
dept_counts.plot(kind='bar')
plt.title('従業員数（部署別）')
plt.xlabel('部署')
plt.ylabel('人数')
plt.tight_layout()
plt.savefig('employee_count_by_dept.png')
```

### 7. Jupyter Notebookでの利用

```bash
# Jupyter Labの起動
jupyter lab
```

Notebookでの使用例：

```python
# %%
# セットアップ
from sqlalchemy import create_engine
import pandas as pd
import matplotlib.pyplot as plt

engine = create_engine('postgresql://study_user:password123@localhost:5432/study_sql')

# %%
# データの読み込みと確認
df = pd.read_sql("SELECT * FROM employees", engine)
df.head()

# %%
# 分析
df.groupby('department').agg({
    'salary': ['mean', 'median', 'min', 'max'],
    'id': 'count'
})

# %%
# 可視化
df.boxplot(column='salary', by='department', figsize=(10, 6))
plt.suptitle('')
plt.title('給与分布（部署別）')
plt.show()
```

---

## 参考リンク

- [PostgreSQL公式ドキュメント](https://www.postgresql.org/docs/)
- [pandas公式ドキュメント](https://pandas.pydata.org/docs/)
- [SQLAlchemyドキュメント](https://docs.sqlalchemy.org/)
- [psycopg2ドキュメント](https://www.psycopg.org/docs/)
