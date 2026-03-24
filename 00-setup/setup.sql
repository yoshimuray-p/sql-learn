-- ========================================
-- PostgreSQL セットアップ用SQLスクリプト
-- ========================================

-- データベースの作成（psqlで postgres データベースに接続して実行）
-- CREATE DATABASE study_sql;

-- このスクリプトは study_sql データベースに接続した状態で実行してください
-- psql -U postgres -d study_sql -f setup.sql

-- ========================================
-- 1. テーブルの作成
-- ========================================

-- 従業員テーブル
CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    department VARCHAR(50),
    position VARCHAR(50),
    salary NUMERIC(10, 2) CHECK (salary > 0),
    hire_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 部署テーブル
CREATE TABLE IF NOT EXISTS departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    location VARCHAR(100),
    budget NUMERIC(12, 2)
);

-- プロジェクトテーブル
CREATE TABLE IF NOT EXISTS projects (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    department_id INTEGER REFERENCES departments(id),
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) CHECK (status IN ('planning', 'active', 'completed', 'cancelled'))
);

-- プロジェクトメンバーテーブル
CREATE TABLE IF NOT EXISTS project_members (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    employee_id INTEGER REFERENCES employees(id) ON DELETE CASCADE,
    role VARCHAR(50),
    hours_allocated INTEGER,
    UNIQUE(project_id, employee_id)
);

-- ========================================
-- 2. サンプルデータの投入
-- ========================================

-- 部署データ
INSERT INTO departments (name, location, budget) VALUES
    ('営業部', '東京本社', 50000000),
    ('開発部', '大阪支社', 80000000),
    ('人事部', '東京本社', 30000000),
    ('マーケティング部', '東京本社', 40000000)
ON CONFLICT (name) DO NOTHING;

-- 従業員データ
INSERT INTO employees (name, email, department, position, salary, hire_date) VALUES
    ('山田太郎', 'yamada@example.com', '営業部', '部長', 650000, '2015-04-01'),
    ('佐藤花子', 'sato@example.com', '開発部', 'シニアエンジニア', 720000, '2017-07-15'),
    ('鈴木一郎', 'suzuki@example.com', '人事部', '課長', 580000, '2018-01-10'),
    ('田中美咲', 'tanaka@example.com', '開発部', 'リードエンジニア', 850000, '2016-03-20'),
    ('高橋健太', 'takahashi@example.com', '営業部', '主任', 520000, '2019-09-01'),
    ('伊藤由美', 'ito@example.com', 'マーケティング部', 'マネージャー', 680000, '2018-06-15'),
    ('渡辺翔太', 'watanabe@example.com', '開発部', 'エンジニア', 550000, '2020-04-01'),
    ('中村さくら', 'nakamura@example.com', '人事部', 'スタッフ', 420000, '2021-02-01'),
    ('小林大輔', 'kobayashi@example.com', '営業部', 'スタッフ', 450000, '2020-10-15'),
    ('加藤真理子', 'kato@example.com', 'マーケティング部', 'スタッフ', 480000, '2021-05-20')
ON CONFLICT (email) DO NOTHING;

-- プロジェクトデータ
INSERT INTO projects (name, department_id, start_date, end_date, status) VALUES
    ('新製品開発', 2, '2023-01-15', '2023-12-31', 'active'),
    ('Webサイトリニューアル', 4, '2023-03-01', '2023-09-30', 'completed'),
    ('営業システム刷新', 1, '2023-06-01', '2024-03-31', 'active'),
    ('人材育成プログラム', 3, '2023-04-01', '2023-10-31', 'completed');

-- プロジェクトメンバーデータ
INSERT INTO project_members (project_id, employee_id, role, hours_allocated) VALUES
    (1, 2, 'リーダー', 160),
    (1, 4, 'メンバー', 120),
    (1, 7, 'メンバー', 160),
    (2, 6, 'リーダー', 140),
    (2, 2, 'アドバイザー', 20),
    (3, 1, 'リーダー', 100),
    (3, 5, 'メンバー', 120),
    (3, 7, 'メンバー', 80),
    (4, 3, 'リーダー', 80),
    (4, 8, 'メンバー', 100);

-- ========================================
-- 3. インデックスの作成
-- ========================================

CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department);
CREATE INDEX IF NOT EXISTS idx_employees_hire_date ON employees(hire_date);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_project_members_project_id ON project_members(project_id);
CREATE INDEX IF NOT EXISTS idx_project_members_employee_id ON project_members(employee_id);

-- ========================================
-- 4. ビューの作成
-- ========================================

-- 従業員の詳細情報ビュー
CREATE OR REPLACE VIEW v_employee_details AS
SELECT 
    e.id,
    e.name,
    e.email,
    e.department,
    e.position,
    e.salary,
    e.hire_date,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.hire_date)) as years_of_service,
    COUNT(pm.id) as project_count
FROM employees e
LEFT JOIN project_members pm ON e.id = pm.employee_id
GROUP BY e.id, e.name, e.email, e.department, e.position, e.salary, e.hire_date;

-- 部署別統計ビュー
CREATE OR REPLACE VIEW v_department_stats AS
SELECT 
    e.department,
    COUNT(*) as employee_count,
    ROUND(AVG(e.salary), 2) as avg_salary,
    ROUND(MIN(e.salary), 2) as min_salary,
    ROUND(MAX(e.salary), 2) as max_salary,
    ROUND(SUM(e.salary), 2) as total_salary
FROM employees e
GROUP BY e.department;

-- プロジェクト概要ビュー
CREATE OR REPLACE VIEW v_project_overview AS
SELECT 
    p.id,
    p.name as project_name,
    d.name as department_name,
    p.start_date,
    p.end_date,
    p.status,
    COUNT(pm.id) as member_count,
    SUM(pm.hours_allocated) as total_hours
FROM projects p
LEFT JOIN departments d ON p.department_id = d.id
LEFT JOIN project_members pm ON p.id = pm.project_id
GROUP BY p.id, p.name, d.name, p.start_date, p.end_date, p.status;

-- ========================================
-- 5. 確認クエリ
-- ========================================

-- テーブル一覧
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE schemaname = 'public';

-- データ件数確認
SELECT 
    'employees' as table_name, COUNT(*) as count FROM employees
UNION ALL
SELECT 'departments', COUNT(*) FROM departments
UNION ALL
SELECT 'projects', COUNT(*) FROM projects
UNION ALL
SELECT 'project_members', COUNT(*) FROM project_members;

-- ========================================
-- 完了メッセージ
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'セットアップが完了しました！';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'テーブル: employees, departments, projects, project_members';
    RAISE NOTICE 'ビュー: v_employee_details, v_department_stats, v_project_overview';
    RAISE NOTICE '';
    RAISE NOTICE '確認コマンド:';
    RAISE NOTICE '  \dt              -- テーブル一覧';
    RAISE NOTICE '  \dv              -- ビュー一覧';
    RAISE NOTICE '  SELECT * FROM v_employee_details;';
    RAISE NOTICE '========================================';
END $$;
