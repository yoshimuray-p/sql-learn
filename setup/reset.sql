-- ============================================================
-- SQL学習コース — テーブル全削除
-- ============================================================
-- 使用方法: Makefile の `make reset` 経由で実行
-- (psql $DB_URL -f setup/reset.sql の後、schema.sql → seed.sql を実行)
-- ============================================================

DROP TABLE IF EXISTS
    assignments,
    orders,
    api_logs,
    logins,
    user_preferences,
    inventory,
    employees,
    projects,
    products,
    departments
CASCADE;
