"""
PostgreSQLとpandasを使用したデータ分析サンプル

このスクリプトは以下を実行します：
1. PostgreSQLへの接続
2. データの読み込み
3. 基本的な分析
4. 可視化
5. データの書き出し
"""

import psycopg2
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sqlalchemy import create_engine
import sys

# 日本語フォントの設定（環境に応じて調整）
plt.rcParams['font.sans-serif'] = ['DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False

# ========================================
# 1. データベース接続設定
# ========================================

DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'study_sql',
    'user': 'study_user',
    'password': 'password123'
}

def create_connection():
    """PostgreSQLへの接続を作成"""
    try:
        # SQLAlchemyエンジンの作成
        connection_string = f"postgresql://{DB_CONFIG['user']}:{DB_CONFIG['password']}@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
        engine = create_engine(connection_string)
        print("✓ データベース接続成功")
        return engine
    except Exception as e:
        print(f"✗ データベース接続エラー: {e}")
        sys.exit(1)

# ========================================
# 2. データの読み込み
# ========================================

def load_data(engine):
    """データベースからデータを読み込み"""
    
    # 従業員データの読み込み
    employees_query = """
        SELECT 
            id, name, email, department, position, 
            salary, hire_date, created_at
        FROM employees
        ORDER BY id
    """
    df_employees = pd.read_sql(employees_query, engine)
    print(f"✓ 従業員データ: {len(df_employees)}件")
    
    # 部署別統計の読み込み
    dept_stats_query = "SELECT * FROM v_department_stats ORDER BY employee_count DESC"
    df_dept_stats = pd.read_sql(dept_stats_query, engine)
    print(f"✓ 部署別統計: {len(df_dept_stats)}件")
    
    # プロジェクト概要の読み込み
    project_query = "SELECT * FROM v_project_overview ORDER BY id"
    df_projects = pd.read_sql(project_query, engine)
    print(f"✓ プロジェクトデータ: {len(df_projects)}件")
    
    return df_employees, df_dept_stats, df_projects

# ========================================
# 3. データ分析
# ========================================

def analyze_salary(df_employees):
    """給与データの分析"""
    print("\n" + "="*50)
    print("給与分析")
    print("="*50)
    
    # 基本統計量
    print("\n【基本統計量】")
    print(df_employees['salary'].describe())
    
    # 部署別給与統計
    print("\n【部署別給与統計】")
    dept_salary = df_employees.groupby('department')['salary'].agg([
        ('平均給与', 'mean'),
        ('中央値', 'median'),
        ('最小給与', 'min'),
        ('最大給与', 'max'),
        ('従業員数', 'count')
    ]).round(2)
    print(dept_salary)
    
    # 役職別給与統計
    print("\n【役職別給与統計】")
    position_salary = df_employees.groupby('position')['salary'].agg([
        ('平均給与', 'mean'),
        ('従業員数', 'count')
    ]).sort_values('平均給与', ascending=False).round(2)
    print(position_salary)
    
    return dept_salary, position_salary

def analyze_tenure(df_employees):
    """勤続年数の分析"""
    print("\n" + "="*50)
    print("勤続年数分析")
    print("="*50)
    
    # 勤続年数の計算
    df_employees['hire_date'] = pd.to_datetime(df_employees['hire_date'])
    df_employees['tenure_years'] = (
        (pd.Timestamp.now() - df_employees['hire_date']).dt.days / 365.25
    ).round(1)
    
    print("\n【勤続年数統計】")
    print(df_employees[['name', 'department', 'tenure_years']].sort_values('tenure_years', ascending=False))
    
    # 勤続年数と給与の相関
    correlation = df_employees['tenure_years'].corr(df_employees['salary'])
    print(f"\n勤続年数と給与の相関係数: {correlation:.3f}")
    
    return df_employees

def analyze_projects(df_projects):
    """プロジェクト分析"""
    print("\n" + "="*50)
    print("プロジェクト分析")
    print("="*50)
    
    # ステータス別集計
    print("\n【ステータス別プロジェクト数】")
    status_counts = df_projects['status'].value_counts()
    print(status_counts)
    
    # 部署別プロジェクト数
    print("\n【部署別プロジェクト数】")
    dept_projects = df_projects.groupby('department_name').size()
    print(dept_projects)
    
    return df_projects

# ========================================
# 4. データ可視化
# ========================================

def visualize_data(df_employees, df_dept_stats, df_projects):
    """データの可視化"""
    print("\n" + "="*50)
    print("データ可視化")
    print("="*50)
    
    # スタイル設定
    sns.set_style("whitegrid")
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    
    # 1. 部署別従業員数
    ax1 = axes[0, 0]
    df_dept_stats.plot(x='department', y='employee_count', kind='bar', ax=ax1, color='steelblue')
    ax1.set_title('Employee Count by Department', fontsize=12, fontweight='bold')
    ax1.set_xlabel('Department')
    ax1.set_ylabel('Number of Employees')
    ax1.tick_params(axis='x', rotation=45)
    
    # 2. 部署別平均給与
    ax2 = axes[0, 1]
    df_dept_stats.plot(x='department', y='avg_salary', kind='bar', ax=ax2, color='coral')
    ax2.set_title('Average Salary by Department', fontsize=12, fontweight='bold')
    ax2.set_xlabel('Department')
    ax2.set_ylabel('Average Salary (JPY)')
    ax2.tick_params(axis='x', rotation=45)
    
    # 3. 給与分布（ヒストグラム）
    ax3 = axes[1, 0]
    ax3.hist(df_employees['salary'], bins=15, color='lightgreen', edgecolor='black')
    ax3.set_title('Salary Distribution', fontsize=12, fontweight='bold')
    ax3.set_xlabel('Salary (JPY)')
    ax3.set_ylabel('Frequency')
    ax3.axvline(df_employees['salary'].mean(), color='red', linestyle='--', label='Mean')
    ax3.axvline(df_employees['salary'].median(), color='blue', linestyle='--', label='Median')
    ax3.legend()
    
    # 4. プロジェクトステータス
    ax4 = axes[1, 1]
    status_counts = df_projects['status'].value_counts()
    ax4.pie(status_counts.values, labels=status_counts.index, autopct='%1.1f%%', startangle=90)
    ax4.set_title('Project Status Distribution', fontsize=12, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('00-setup/analysis_results.png', dpi=300, bbox_inches='tight')
    print("✓ グラフを保存しました: analysis_results.png")
    
    # 詳細な散布図（勤続年数 vs 給与）
    if 'tenure_years' in df_employees.columns:
        plt.figure(figsize=(10, 6))
        scatter = plt.scatter(
            df_employees['tenure_years'], 
            df_employees['salary'],
            c=df_employees['department'].astype('category').cat.codes,
            s=100,
            alpha=0.6,
            cmap='viridis'
        )
        plt.colorbar(scatter, label='Department')
        plt.xlabel('Tenure (years)')
        plt.ylabel('Salary (JPY)')
        plt.title('Salary vs Tenure by Department', fontsize=14, fontweight='bold')
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.savefig('00-setup/salary_vs_tenure.png', dpi=300, bbox_inches='tight')
        print("✓ グラフを保存しました: salary_vs_tenure.png")

# ========================================
# 5. レポート生成
# ========================================

def generate_report(df_employees, df_dept_stats, df_projects):
    """分析レポートをCSVで出力"""
    print("\n" + "="*50)
    print("レポート生成")
    print("="*50)
    
    # 従業員詳細レポート
    df_employees_report = df_employees.copy()
    if 'tenure_years' in df_employees_report.columns:
        df_employees_report = df_employees_report[[
            'name', 'department', 'position', 'salary', 'tenure_years'
        ]].sort_values('salary', ascending=False)
    df_employees_report.to_csv('00-setup/employee_report.csv', index=False, encoding='utf-8-sig')
    print("✓ 従業員レポート: employee_report.csv")
    
    # 部署別統計レポート
    df_dept_stats.to_csv('00-setup/department_stats.csv', index=False, encoding='utf-8-sig')
    print("✓ 部署別統計: department_stats.csv")
    
    # プロジェクトレポート
    df_projects.to_csv('00-setup/project_report.csv', index=False, encoding='utf-8-sig')
    print("✓ プロジェクトレポート: project_report.csv")

# ========================================
# 6. データベースへの書き込み例
# ========================================

def write_to_database(engine, df_employees):
    """分析結果をデータベースに書き込む例"""
    print("\n" + "="*50)
    print("データベースへの書き込み")
    print("="*50)
    
    # 分析結果テーブルの作成
    if 'tenure_years' in df_employees.columns:
        analysis_df = df_employees[['id', 'name', 'salary', 'tenure_years']].copy()
        analysis_df['salary_per_year'] = (analysis_df['salary'] / analysis_df['tenure_years']).round(2)
        
        # データベースに書き込み
        analysis_df.to_sql(
            'employee_analysis',
            engine,
            if_exists='replace',
            index=False
        )
        print("✓ 分析結果をテーブル 'employee_analysis' に保存しました")

# ========================================
# メイン処理
# ========================================

def main():
    """メイン処理"""
    print("\n" + "="*50)
    print("PostgreSQL + pandas データ分析")
    print("="*50)
    
    # 1. データベース接続
    engine = create_connection()
    
    # 2. データ読み込み
    print("\n【データ読み込み】")
    df_employees, df_dept_stats, df_projects = load_data(engine)
    
    # 3. データ分析
    analyze_salary(df_employees)
    df_employees = analyze_tenure(df_employees)
    analyze_projects(df_projects)
    
    # 4. 可視化
    visualize_data(df_employees, df_dept_stats, df_projects)
    
    # 5. レポート生成
    generate_report(df_employees, df_dept_stats, df_projects)
    
    # 6. データベースへの書き込み
    write_to_database(engine, df_employees)
    
    print("\n" + "="*50)
    print("✓ すべての処理が完了しました！")
    print("="*50)

if __name__ == "__main__":
    main()
