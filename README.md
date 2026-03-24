# SQL実務マスターコース

情報系修士課程レベルを対象とした、SQLを実務レベルで扱えるようになるための学習コース。

## 📋 コース概要

- **対象**: プログラミング経験のある学習者
- **目標**: SQLを実務レベルで十分に扱えるようになること
- **DBMS**: PostgreSQL
- **構成**: 全5回 + 環境構築ガイド

## 🚀 はじめに

### クイックスタート

```bash
# 1. リポジトリをクローン
git clone <repository-url>
cd sql

# 2. PostgreSQL環境を構築（Docker使用）
cd 00-setup
docker-compose up -d

# 3. Python環境をセットアップ
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 4. サンプル分析を実行
python pandas_analysis.py
```

詳細は **[00-setup/QUICKSTART.md](00-setup/QUICKSTART.md)** を参照してください。

## 📚 カリキュラム

### [第0回: 環境構築とツール](00-setup/)
- PostgreSQLのインストールと設定
- Docker環境での構築
- Python pandasを使ったデータ分析
- Jupyter Notebookでの対話的分析

### [第1回: クエリ基礎](01-query-basics/)
- SELECT / WHERE / ORDER BY / LIMIT
- JOIN（INNER, LEFT, RIGHT, FULL, CROSS, 自己結合）
- GROUP BY / HAVING / 集約関数
- サブクエリ（スカラ, IN, EXISTS）
- NULL の扱い

### [第2回: 高度なクエリ](02-advanced-queries/)
- CTE（WITH句）と再帰CTE
- ウィンドウ関数（ROW_NUMBER, RANK, DENSE_RANK, LAG, LEAD, SUM OVER, NTILE）
- CASE式
- 集合演算（UNION, INTERSECT, EXCEPT）
- LATERAL JOIN

### [第3回: テーブル設計](03-table-design/)
- DDL（CREATE TABLE, ALTER TABLE）
- データ型の選択
- 制約（PK, FK, UNIQUE, CHECK, NOT NULL）
- 正規化（1NF〜BCNF）と反正規化
- インデックス（B-tree, Hash, GIN, GiST）の仕組みと設計

### [第4回: トランザクションと性能](04-transactions-performance/)
- ACID特性
- トランザクション制御（BEGIN, COMMIT, ROLLBACK, SAVEPOINT）
- 分離レベルと競合現象
- MVCC の仕組み
- EXPLAIN / EXPLAIN ANALYZE による実行計画の読み方
- クエリチューニングの実践

### [第5回: 実務応用](05-practical-patterns/)
- VIEW / MATERIALIZED VIEW
- JSON/JSONB 型の操作
- ストアドファンクション（PL/pgSQL基礎）
- SQLインジェクション対策
- 実務で頻出するクエリパターン集

## 🛠 推奨ツール

### データベース管理
- **psql**: PostgreSQL標準CLIツール
- **pgAdmin**: GUIデータベース管理ツール（Docker Composeに含まれる）
- **DBeaver**: マルチプラットフォーム対応のデータベースツール

### データ分析
- **Python + pandas**: データ分析とSQL連携
- **Jupyter Notebook/Lab**: 対話的な分析環境
- **matplotlib/seaborn**: データ可視化

## 📖 学習の進め方

1. **環境構築**: まず [00-setup](00-setup/) で環境をセットアップ
2. **順次学習**: 01から05まで順番に進める
3. **実践**: 各回の練習問題を解く
4. **応用**: pandasと組み合わせて実データで分析

## 🔗 参考リソース

- [PostgreSQL公式ドキュメント](https://www.postgresql.org/docs/)
- [pandas公式ドキュメント](https://pandas.pydata.org/docs/)
- [SQL Style Guide](https://www.sqlstyle.guide/)

## 📝 ライセンス

このコースは学習目的で作成されています。

## 🤝 コントリビューション

改善提案やバグ報告は Issue または Pull Request でお願いします。
