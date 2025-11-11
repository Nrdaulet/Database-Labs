CREATE TABLE employees(
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(50),
    dept_id INT,
    salary DECIMAL(10, 2)
);

CREATE TABLE departments(
    dept_id INT PRIMARY KEY,
    dept_name VARCHAR(50),
    location VARCHAR(50)
);

CREATE TABLE projects(
    project_id SERIAL PRIMARY KEY,
    project_name VARCHAR(50),
    dept_id INT,
    budget DECIMAL(10, 2)
);

CREATE VIEW employee_details AS
    SELECT
        e.emp_name,
        e.salary,
        d.dept_name,
        d.location
FROM employees e
JOIN departments d on e.dept_id = d.dept_id;
SELECT*FROM employee_details;

CREATE VIEW dept_statistics AS
    SELECT
        d.dept_name,
        count(e.emp_id) AS employee_count,
        COALESCE(AVG(e.salary), 0) AS avg_salary,
        COALESCE(MAX(e.salary), 0) AS max_salary,
        COALESCE((MIN(e.salary), 0))AS min_salary
FROM departments d
LEFT JOIN employees e ON d.dept_id=e.dept_id
GROUP BY d.dept_name;

SELECT * FROM dept_statistics
ORDER BY employee_count DESC;


CREATE VIEW project_overview AS
    SELECT
        p.project_name,
        p.budget,
        d.dept_name,
        d.location,
        count(e.emp_id) AS team_size
FROM projects p
LEFT JOIN departments d on p.dept_id=d.dept_id
LEFT JOIN employees e on d.dept_id=e.dept_id
GROUP BY p.project_name, p.budget, d.dept_name, d.location;

CREATE VIEW high_earners AS
    SELECT
        e.emp_name,
        e.salary,
        d.dept_name
FROM employees e
JOIN departments d on e.dept_id=d.dept_id
WHERE e.salary>55000;

SELECT * FROM high_earners;

CREATE OR REPLACE VIEW employee_details AS
    SELECT
        e.emp_name,
        e.salary,
        d.dept_name,
        d.location,
        CASE
            WHEN e.salary>60000 THEN 'high'
            WHEN e.salary>50000 THEN 'medium'
            ELSE 'Standard'
        END AS salary_grade
FROM employees e
JOIN departments d on e.dept_id = d.dept_id;

SELECT * FROM employee_details;

CREATE VIEW temp_view AS
    SELECT
        emp_name,salary,dept_id
FROM employees
WHERE salary<50000;

SELECT *FROM temp_view;
DROP VIEW temp_view;

CREATE VIEW employee_salaries AS
    SELECT
        emp_id,
        emp_name,
        dept_id,
        salary
FROM employees;

UPDATE employee_salaries
SET salary=52000
WHERE emp_name='John Smith';

SELECT * FROM employees WHERE emp_name='John Smith';

INSERT INTO employee_salaries(emp_id, emp_name, dept_id, salary)
VALUES (6,'Math Sels', 102,50000);

SELECT *FROM employees WHERE emp_name='Math Sels';

CREATE VIEW it_employees AS
    SELECT
        emp_id,
        emp_name,
        dept_id,
        salary
FROM employees
WHERE dept_id=101
WITH LOCAL CHECK OPTION;

CREATE MATERIALIZED VIEW dept_summary_mv AS
    SELECT
        d.dept_id,
        d.dept_name,
        count(DISTINCT e.emp_id) AS total_employees,
        COALESCE(SUM(e.salary), 0) AS total_salaries,
        count(DISTINCT p.project_id) AS total_projects,
        COALESCE(SUM(p.budget), 0) AS total_project_budget
FROM departments d
LEFT JOIN employees e on d.dept_id = e.dept_id
LEFT JOIN projects p on d.dept_id = p.dept_id
GROUP BY d.dept_id, d.dept_name
WITH DATA;

SELECT * FROM dept_summary_mv ORDER BY total_employees DESC;

INSERT INTO employees(emp_id, emp_name, dept_id, salary)
VALUES (8,'Nur Daulet', 101,54000);
SELECT * FROM dept_summary_mv;

REFRESH MATERIALIZED VIEW dept_summary_mv;
SELECT * FROM dept_summary_mv;

CREATE UNIQUE INDEX dept_summary_mv_idx ON dept_summary_mv(dept_id);
REFRESH MATERIALIZED VIEW CONCURRENTLY dept_summary_mv;

CREATE MATERIALIZED VIEW project_stats_mv AS
    SELECT
        p.project_name,
        p.budget,
        d.dept_name,
        count(e.emp_id) AS employee_count
FROM projects p
LEFT JOIN departments d on p.dept_id = d.dept_id
LEFT JOIN employees e on d.dept_id = e.dept_id
GROUP BY p.project_name, p.budget, d.dept_name
WITH NO DATA;

SELECT * FROM project_stats_mv;

CREATE ROLE analyst;

CREATE ROLE data_viewer LOGIN PASSWORD 'viewer123';

CREATE ROLE report_user LOGIN PASSWORD 'report456';

SELECT rolname FROM pg_roles WHERE rolname NOT LIKE 'pg_%';

CREATE ROLE db_creator LOGIN PASSWORD 'creator789' CREATEDB;
CREATE ROLE user_manager LOGIN PASSWORD 'manager101' CREATEROLE;
CREATE ROLE admin_user LOGIN PASSWORD 'admin999' SUPERUSER;

GRANT SELECT ON employees,departments,projects TO analyst;
GRANT ALL PRIVILEGES ON employee_details TO data_viewer;
GRANT SELECT, INSERT ON employees TO report_user;

CREATE ROLE hr_team;
CREATE ROLE finance_team;
CREATE ROLE it_team;

CREATE ROLE hr_user LOGIN PASSWORD 'hr001';
CREATE ROLE hr_user2 LOGIN PASSWORD 'hr002';
CREATE ROLE finance_user1 LOGIN PASSWORD 'fin001';

GRANT hr_team TO hr_user;
GRANT hr_team TO hr_user2;
GRANT finance_team TO finance_user1;

GRANT SELECT,UPDATE ON employees TO hr_team;
GRANT SELECT ON dept_statistics TO finance_team;

REVOKE UPDATE ON employees FROM hr_team;
REVOKE hr_team FROM hr_user2;
REVOKE ALL PRIVILEGES ON employee_details FROM data_viewer;

ALTER ROLE analyst LOGIN PASSWORD 'analyst123';
ALTER ROLE user_manager SUPERUSER;
ALTER ROLE analyst PASSWORD NULL;
ALTER ROLE data_viewer CONNECTION LIMIT 5;

CREATE ROLE read_only;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO read_only;

CREATE ROLE junior_analyst LOGIN PASSWORD 'junior123';
CREATE ROLE senior_analyst LOGIN PASSWORD 'senior123';

GRANT read_only TO junior_analyst;
GRANT read_only TO senior_analyst;

GRANT INSERT, UPDATE ON employees TO senior_analyst;

CREATE ROLE project_manager LOGIN PASSWORD 'pm123';

ALTER VIEW dept_statistics OWNER TO project_manager;
ALTER TABLE projects OWNER TO project_manager;

SELECT tablename,tableowner
FROM pg_tables
WHERE schemaname='public';

CREATE ROLE temp_owner LOGIN;
CREATE TABLE temp_table(id INT);

ALTER TABLE temp_table OWNER TO temp_owner;

REASSIGN OWNED BY temp_owner TO postgres;

DROP OWNED BY temp_owner;

DROP ROLE temp_owner;

CREATE VIEW hr_employee_view AS
    SELECT *
FROM employees
WHERE dept_id=102;

GRANT SELECT ON hr_employee_view TO hr_team;

CREATE VIEW finance_employee_view AS
    SELECT emp_id,emp_name,salary
FROM employees;

GRANT SELECT ON finance_employee_view TO finance_team;

CREATE VIEW dept_dashboard AS
    SELECT
        d.dept_name,
        d.location,
        count(DISTINCT e.emp_id) AS employee_count,
        round(COALESCE(AVG(e.salary), 0), 2) AS avg_salary,
        count(DISTINCT p.project_id) AS active_projects,
        COALESCE(SUM(p.budget), 0) AS total_project_budget,
        ROUND(
        coalesce(SUM(p.budget)/NULLIF(count(DISTINCT e.emp_id), 0), 0),
        2) AS budget_per_employee
FROM departments d
LEFT JOIN employees e on d.dept_id = e.dept_id
LEFT JOIN projects p on d.dept_id = p.dept_id
GROUP BY d.dept_name, d.location;

SELECT *FROM dept_dashboard;

ALTER TABLE projects
ADD COLUMN created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

CREATE VIEW high_budget_projects AS
    SELECT
        p.project_name,
        p.budget,
        d.dept_name,
        p.created_date,
        CASE
            WHEN p.budget>150000 THEN 'Critical Review Required'
            WHEN p.budget>100000 THEN 'Management Approval Needed'
            ELSE 'Standard Process'
        END AS approval_status
FROm projects p
JOIN departments d ON p.dept_id=d.dept_id
WHERE p.budget>75000;

SELECT * FROM high_budget_projects ORDER BY budget DESC;

CREATE ROLE viewer_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO viewer_role;

CREATE ROLE entry_role;
GRANT viewer_role TO entry_role;
GRANT INSERT ON employees,projects TO entry_role;

CREATE ROLE analyst_role;
GRANT entry_role TO analyst_role;
GRANT UPDATE ON employees,projects TO analyst_role;

CREATE ROLE manager_role;
GRANT analyst_role TO manager_role;
GRANT DELETE ON employees, projects TO manager_role;

CREATE ROLE alice LOGIN PASSWORD 'alice123';
CREATE ROLE bob LOGIN PASSWORD 'bob123';
CREATE ROLE charlie LOGIN PASSWORD 'charlie123';

GRANT viewer_role TO alice;
GRANT analyst_role TO bob;
GRANT manager_role TO charlie;
