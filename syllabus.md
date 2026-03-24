# SQL実務マスターコース — シラバス

**対象**: 情報系修士課程レベル（プログラミング経験あり）
**目標**: SQLを実務レベルで十分に扱えるようになること
**前提DBMS**: PostgreSQL
**全5回構成**

---

## 第1回: クエリ基礎 (Query Basics)

SELECT / WHERE / ORDER BY / LIMIT の基本構文。JOIN（INNER, LEFT, RIGHT, FULL, CROSS, 自己結合）。GROUP BY / HAVING / 集約関数。サブクエリ（スカラ, IN, EXISTS）。NULL の扱い。

## 第2回: 高度なクエリ (Advanced Queries)

CTE（WITH句）と再帰CTE。ウィンドウ関数（ROW_NUMBER, RANK, DENSE_RANK, LAG, LEAD, SUM OVER, NTILE）。CASE式。集合演算（UNION, INTERSECT, EXCEPT）。LATERAL JOIN。

## 第3回: テーブル設計 (Table Design)

DDL（CREATE TABLE, ALTER TABLE）。データ型の選択。制約（PK, FK, UNIQUE, CHECK, NOT NULL）。正規化（1NF〜BCNF）と反正規化。インデックス（B-tree, Hash, GIN, GiST）の仕組みと設計。

## 第4回: トランザクションと性能 (Transactions & Performance)

ACID特性。トランザクション制御（BEGIN, COMMIT, ROLLBACK, SAVEPOINT）。分離レベルと競合現象。MVCC の仕組み。EXPLAIN / EXPLAIN ANALYZE による実行計画の読み方。クエリチューニングの実践。

## 第5回: 実務応用 (Practical Patterns)

VIEW / MATERIALIZED VIEW。JSON/JSONB 型の操作。ストアドファンクション（PL/pgSQL基礎）。SQLインジェクション対策。実務で頻出するクエリパターン集。
