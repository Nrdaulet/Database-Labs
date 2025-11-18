CREATE TABLE department(
    dept_id INT PRIMARY KEY,
    dept_name VARCHAR(50),
    location VARCHAR(50)
);

CREATE TABLE employees(
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(120),
    dept_id INT,
    salary DECIMAL(10, 2),
    FOREIGN KEY (dept_id) REFERENCES department(dept_id)
);

CREATE TABLE projects(
    proj_id INT PRIMARY KEY,
    proj_name VARCHAR(100),
    budget DEC(12, 2),
    dept_id INT,
    FOREIGN KEY (dept_id) REFERENCES department(dept_id)
);

INSERT INTO department VALUES
(101,'IT','Building A'),
(102,'HR','Building B'),
(103,'Operations','Building C');

INSERT INTO employees VALUES
(1,'John Smith',101,50000),
(2,'Jane Doe',101,55000),
(3,'Mike Johnson',102.48000),
(4,'Sarah Williams',102,52000),
(5,'Tom Brown',103,60000);

INSERT INTO projects VALUES
(201,'Website',75000,101),
(202,'Database',120000,101),
(203,'HR system',50000,102);

CREATE INDEX emp_salary_idx ON employees(salary);
CREATE INDEX emp_dept_idx ON employees(dept_id);
CREATE INDEX emp_dept_salary_idx ON employees(dept_id,salary);
CREATE INDEX emp_salary_dept_idx ON employees(salary,dept_id);

ALTER TABLE employees ADD COLUMN email VARCHAR(100);
UPDATE employees SET email ='john.smith@company.com' WHERE emp_id=1;
UPDATE employees SET email ='jane.doe@company.com' WHERE emp_id=2;
UPDATE employees SET email ='mike.johnson@company.com' WHERE emp_id=3;
UPDATE employees SET email ='sarah.williams@company.com' WHERE emp_id=4;
UPDATE employees SET email ='tom.brown@company.com' WHERE emp_id=5;
CREATE UNIQUE INDEX emp_email_unique_idx ON employees(email);

ALTER TABLE employees ADD COLUMN phone VARCHAR(50) UNIQUE;
CREATE INDEX emp_salary_desc_idx ON employees(salary DESC );
CREATE INDEX proj_budget_nulls_first_idx ON projects(budget NULL FIRST);
CREATE INDEX emp_name_lower_idx ON employees(LOWER(emp_name));

ALTER TABLE employees ADD COLUMN hire_date DATE;
UPDATE employees SET hire_date ='2020-01-15' WHERE emp_id=1;
UPDATE employees SET hire_date ='2021-01-15' WHERE emp_id=2;
UPDATE employees SET hire_date ='2022-10-23' WHERE emp_id=3;
UPDATE employees SET hire_date ='2022-12-05' WHERE emp_id=4;
UPDATE employees SET hire_date ='2018-12-25' WHERE emp_id=5;

CREATE INDEX emp_hire_year_idx ON employees( (EXTRACT(YEAR FROM hire_date)));

CREATE INDEX emp_salary_filter_idx ON employees(salary) WHERE salary>50000;

CREATE INDEX proj_high_budget_idx ON projects(budget) WHERE budget>80000;

CREATE INDEX dept_name_hash_idx ON department USING HASH(dept_name);

CREATE INDEX proj_name _btree_idx ON projects(proj_name);
CREATE INDEX proj_name_hash_idx ON projects(proj_name);

CREATE VIEW index_documentation AS
    tablename,
    indexname,
    indexdef,
    'Improves salart based queries' as purpose
FROM pg_indexes
WHERE schemaname='public'
    AND indexname LIKE '%salary%';