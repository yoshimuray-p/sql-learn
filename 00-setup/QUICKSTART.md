# クイックスタートガイド

このガイドでは、最短でPostgreSQL環境を構築し、pandasを使ったデータ分析を開始できます。

## 🚀 5分でスタート

### ステップ1: Dockerでデータベース起動

```bash
# 00-setupディレクトリに移動
cd 00-setup

# PostgreSQLコンテナを起動（初回は自動でセットアップ実行）
docker-compose up -d

# 起動確認
docker-compose ps
```

### ステップ2: Pythonパッケージのインストール

```bash
# 仮想環境の作成（推奨）
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 必要なパッケージをインストール
pip install -r requirements.txt
```

### ステップ3: データ分析を実行

```bash
# サンプル分析スクリプトを実行
python pandas_analysis.py
```

実行すると以下が生成されます：
- `employee_report.csv` - 従業員詳細レポート
- `department_stats.csv` - 部署別統計
- `project_report.csv` - プロジェクトレポート
- `analysis_results.png` - 可視化グラフ
- `salary_vs_tenure.png` - 給与と勤続年数の相関図

---

## 📊 すぐに試せるコマンド

### psqlでデータベースに接続

```bash
# Docker経由で接続
docker exec -it sql-study-postgres psql -U study_user -d study_sql

# ローカルにpsqlがある場合
psql -h localhost -U study_user -d study_sql
```

### よく使うクエリ

```sql
-- 従業員一覧
SELECT * FROM employees;

-- 部署別統計（ビュー）
SELECT * FROM v_department_stats;

-- 高給与トップ5
SELECT name, department, salary 
FROM employees 
ORDER BY salary DESC 
LIMIT 5;

-- 部署ごとの平均給与
SELECT 
    department,
    ROUND(AVG(salary), 2) as avg_salary,
    COUNT(*) as count
FROM employees 
GROUP BY department 
ORDER BY avg_salary DESC;
```

---

## 🐍 Pythonで直接アクセス

### 基本的な使い方

```python
from sqlalchemy import create_engine
import pandas as pd

# 接続
engine = create_engine('postgresql://study_user:password123@localhost:5432/study_sql')

# データ読み込み
df = pd.read_sql("SELECT * FROM employees", engine)
print(df.head())

# 部署別平均給与
dept_avg = df.groupby('department')['salary'].mean()
print(dept_avg)
```

### Jupyter Notebookで試す

```bash
# Jupyter Lab起動
jupyter lab

# ブラウザで開いたら、新しいノートブックを作成して上記コードを実行
```

---

## 🎯 次のステップ

### データベース管理（GUIツール）

pgAdminを使ってGUIでデータベースを管理：

1. ブラウザで http://localhost:5050 を開く
2. ログイン情報：
   - Email: `admin@example.com`
   - Password: `admin`
3. サーバーを追加：
   - Host: `postgres`（Dockerネットワーク内）または `host.docker.internal`（Mac/Windows）
   - Port: `5432`
   - Database: `study_sql`
   - Username: `study_user`
   - Password: `password123`

### カスタムデータで試す

```python
import pandas as pd
from sqlalchemy import create_engine

engine = create_engine('postgresql://study_user:password123@localhost:5432/study_sql')

# CSVからデータを読み込んでデータベースに保存
df = pd.read_csv('your_data.csv')
df.to_sql('your_table', engine, if_exists='replace', index=False)

# 確認
result = pd.read_sql("SELECT * FROM your_table LIMIT 5", engine)
print(result)
```

---

## 🛠 トラブルシューティング

### データベースに接続できない

```bash
# コンテナが起動しているか確認
docker-compose ps

# ログを確認
docker-compose logs postgres

# 再起動
docker-compose restart postgres
```

### パスワードエラー

接続文字列を確認：
```python
# 正しい形式
postgresql://study_user:password123@localhost:5432/study_sql
```

### ポート競合

既にPostgreSQLが起動している場合は、`docker-compose.yml`のポートを変更：
```yaml
ports:
  - "5433:5432"  # ホスト側を5433に変更
```

接続時もポート番号を変更：
```python
engine = create_engine('postgresql://study_user:password123@localhost:5433/study_sql')
```

---

## 🧹 クリーンアップ

```bash
# コンテナを停止
docker-compose down

# データも削除する場合
docker-compose down -v
```

---

## 📚 詳細ドキュメント

より詳しい説明は [README.md](README.md) を参照してください。

- PostgreSQL環境構築の詳細
- pandasの高度な使い方
- データ可視化のテクニック
- 大量データの処理方法
