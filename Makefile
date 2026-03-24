DB_URL = postgresql://study_user:study_password@localhost:5432/study_db
PSQL   = psql $(DB_URL)

.PHONY: up down setup seed reset psql check

## Docker コンテナを起動する
up:
	docker compose up -d
	@echo "⏳ PostgreSQL の起動を待機中..."
	@until docker exec sql-study-postgres pg_isready -U study_user -d study_db > /dev/null 2>&1; do \
		sleep 1; \
	done
	@echo "✅ PostgreSQL 起動完了"

## Docker コンテナを停止する（データは保持）
down:
	docker compose down

## 初回セットアップ: コンテナ起動 → スキーマ作成 → サンプルデータ投入
setup: up
	$(PSQL) -f setup/schema.sql
	$(PSQL) -f setup/seed.sql
	@echo "✅ セットアップ完了"

## サンプルデータだけを再投入する（スキーマは変更しない）
## 注意: 既存データはすべて削除されます
seed:
	$(PSQL) -f setup/seed.sql
	@echo "✅ サンプルデータ投入完了"

## スキーマとデータを完全にリセットする
## 注意: すべてのテーブルが削除・再作成されます
reset: up
	$(PSQL) -f setup/reset.sql
	$(PSQL) -f setup/schema.sql
	$(PSQL) -f setup/seed.sql
	@echo "✅ リセット完了"

## psql に接続する
psql:
	$(PSQL)

## 各テーブルの行数を確認する
check:
	@$(PSQL) -c "\
	SELECT 'departments' AS table_name, COUNT(*) AS rows FROM departments \
	UNION ALL SELECT 'employees',   COUNT(*) FROM employees \
	UNION ALL SELECT 'projects',    COUNT(*) FROM projects \
	UNION ALL SELECT 'assignments', COUNT(*) FROM assignments \
	UNION ALL SELECT 'products',    COUNT(*) FROM products \
	UNION ALL SELECT 'orders',      COUNT(*) FROM orders \
	UNION ALL SELECT 'api_logs',    COUNT(*) FROM api_logs \
	UNION ALL SELECT 'logins',      COUNT(*) FROM logins \
	UNION ALL SELECT 'inventory',   COUNT(*) FROM inventory \
	ORDER BY table_name;"
