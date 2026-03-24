# SQL実務マスターコース

PostgreSQL を使った SQL 学習環境です。Docker でDBを起動し、psql や Python (pandas) から操作します。

## 構成

```
.
├── syllabus.md          # シラバス
├── docker-compose.yml   # PostgreSQL コンテナ定義
├── Makefile             # 操作コマンド集
├── pyproject.toml       # Python 依存関係
├── setup/
│   ├── schema.sql       # テーブル定義
│   ├── seed.sql         # サンプルデータ
│   └── reset.sql        # リセット用
├── 01-query-basics/
├── 02-advanced-queries/
├── 03-table-design/
├── 04-transactions-performance/
└── 05-practical-patterns/
```

各回のディレクトリに `lecture.md`（講義）と `exercises.md`（演習）があります。

## セットアップ

**前提**: Docker、psql、uv（または pip）が必要です。

```bash
# 初回: コンテナ起動 + スキーマ作成 + サンプルデータ投入
make setup

# Python 依存関係のインストール
uv sync   # または: pip install -e .
```

## 主なコマンド

| コマンド | 内容 |
|---|---|
| `make up` | コンテナ起動 |
| `make down` | コンテナ停止 |
| `make psql` | psql に接続 |
| `make seed` | サンプルデータ再投入 |
| `make reset` | スキーマ・データを完全リセット |
| `make check` | 各テーブルの行数確認 |

## 接続情報

```
Host:     localhost:5432
Database: study_db
User:     study_user
Password: study_password
```

## 参考ドキュメント

- [PostgreSQL 操作ガイド](docs/postgres.md)
- [pandas 連携ガイド](docs/pandas.md)
