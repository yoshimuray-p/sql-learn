-- ============================================================
-- SQL学習コース — 共通スキーマ (全5回対応)
-- ============================================================
-- 使用方法: psql $DB_URL -f setup/schema.sql
-- ============================================================

-- ----- 第1〜4回 共通テーブル -----

CREATE TABLE IF NOT EXISTS departments (
    id       SERIAL PRIMARY KEY,
    name     TEXT NOT NULL,
    location TEXT
);

-- manager_id は第2回「再帰CTE」で使用
CREATE TABLE IF NOT EXISTS employees (
    id            SERIAL PRIMARY KEY,
    name          TEXT    NOT NULL,
    email         TEXT    UNIQUE NOT NULL,
    department_id INT     REFERENCES departments(id),
    salary        INT     NOT NULL CHECK (salary >= 0),
    hire_date     DATE    NOT NULL,
    manager_id    INT     REFERENCES employees(id)
);

CREATE TABLE IF NOT EXISTS projects (
    id         SERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    budget     INT  NOT NULL CHECK (budget >= 0),
    start_date DATE NOT NULL,
    end_date   DATE
);

CREATE TABLE IF NOT EXISTS assignments (
    employee_id   INT  NOT NULL REFERENCES employees(id),
    project_id    INT  NOT NULL REFERENCES projects(id),
    role          TEXT NOT NULL,
    assigned_date DATE NOT NULL,
    PRIMARY KEY (employee_id, project_id)
);

-- ----- 第5回 追加テーブル -----

CREATE TABLE IF NOT EXISTS products (
    id       SERIAL PRIMARY KEY,
    name     TEXT NOT NULL,
    category TEXT NOT NULL,
    price    INT  NOT NULL CHECK (price >= 0)
);

-- user_id は employees.id を想定（デモ用に外部キー制約なし）
CREATE TABLE IF NOT EXISTS orders (
    id         SERIAL PRIMARY KEY,
    user_id    INT  NOT NULL,
    product_id INT  REFERENCES products(id),
    quantity   INT  NOT NULL DEFAULT 1 CHECK (quantity > 0),
    amount     INT  NOT NULL CHECK (amount >= 0),
    order_date DATE NOT NULL DEFAULT CURRENT_DATE
);

-- 第5回 問題3: JSONB クエリ用
CREATE TABLE IF NOT EXISTS api_logs (
    id         SERIAL PRIMARY KEY,
    endpoint   TEXT        NOT NULL,
    payload    JSONB       NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 第5回 問題9: ギャップ・アンド・アイランド用
CREATE TABLE IF NOT EXISTS logins (
    user_id    INT  NOT NULL,
    login_date DATE NOT NULL,
    PRIMARY KEY (user_id, login_date)
);

-- 第5回 問題6: Upsert 用
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id    INT  NOT NULL,
    key        TEXT NOT NULL,
    value      TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, key)
);

-- 第5回 問題10: トリガー用
CREATE TABLE IF NOT EXISTS inventory (
    product_id INT PRIMARY KEY REFERENCES products(id),
    stock      INT NOT NULL DEFAULT 0 CHECK (stock >= 0)
);
