# PostgreSQL 操作ガイド

## psql 接続

```bash
make psql
# または直接:
psql postgresql://study_user:study_password@localhost:5432/study_db
```

## psql 基本コマンド

| コマンド | 内容 |
|---|---|
| `\l` | データベース一覧 |
| `\dt` | テーブル一覧 |
| `\d テーブル名` | テーブル定義を表示 |
| `\i ファイル.sql` | SQL ファイルを実行 |
| `\e` | エディタで SQL を編集 |
| `\timing` | 実行時間の表示切り替え |
| `\q` | 終了 |

## SQL ファイルの実行

```bash
psql postgresql://study_user:study_password@localhost:5432/study_db -f ファイル.sql
```

## 実行計画の確認

```sql
EXPLAIN SELECT * FROM employees WHERE department_id = 1;
EXPLAIN ANALYZE SELECT * FROM employees WHERE department_id = 1;
```

## トランザクション

```sql
BEGIN;
UPDATE employees SET salary = salary * 1.1 WHERE department_id = 1;
ROLLBACK;  -- または COMMIT;
```
