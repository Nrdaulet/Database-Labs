
CREATE TABLE employees (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(50),
    dept_id INT,
    salary DECIMAL(10, 2)
 );

CREATE TABLE departments (
    dept_id INT PRIMARY KEY,
    dept_name VARCHAR(50),
    location VARCHAR(50)
 );

CREATE TABLE projects(
    project_id SERIAL PRIMARY KEY,
    project_name VARCHAR(50),
    dept_id INT,
    budget DECIMAL(10,2)
);

INSERT INTO employees (emp_id, emp_name, dept_id, salary)
VALUES
 (1, 'John Smith', 101, 50000),
 (2, 'Jane Doe', 102, 60000),
 (3, 'Mike Johnson', 101, 55000),
 (4, 'Sarah Williams', 103, 65000),
 (5, 'Tom Brown', NULL, 45000);

 INSERT INTO departments (dept_id, dept_name, location) VALUES
 (101, 'IT', 'Building A'),
 (102, 'HR', 'Building B'),
 (103, 'Finance', 'Building C'),
 (104, 'Marketing', 'Building D');

 INSERT INTO projects (project_id, project_name, dept_id,
budget) VALUES
 (1, 'Website Redesign', 101, 100000),
 (2, 'Employee Training', 102, 50000),
 (3, 'Budget Analysis', 103, 75000),
 (4, 'Cloud Migration', 101, 150000),
 (5, 'AI Research', NULL, 200000);

-- Part 2
SELECT e.emp_name, d.dept_name
FROM employees e CROSS JOIN departments d;

SELECT e.emp_name, p.project_name
FROM employees e
CROSS JOIN projects p;

-- Part 3
SELECT emp_name, dept_name, location
FROM employees
INNER JOIN departments USING (dept_id);

SELECT emp_name, dept_name, location
FROM employees
NATURAL INNER JOIN departments;

SELECT e.emp_name, d.dept_name, p.project_name
FROM employees e
INNER JOIN departments d ON e.dept_id=d.dept_id
INNER JOIN projects p ON d.dept_id=p.dept_id;

-- Part 4
SELECT e.emp_name, e.dept_id AS emp_dept, d.dept_id AS
dept_dept,d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id=d.dept_id;

SELECT emp_name, dept_id, dept_name
FROM employees e
LEFT JOIN departments USING (dept_id);

SELECT e.emp_name, e.dept_id
FROM employees e
LEFT JOIN departments d ON e.dept_id=d.dept_id
WHERE d.dept_id IS NULL;

SELECT d.dept_name, count(e.emp_id) AS employee_count
FROM departments d
LEFT JOIN employees e ON d.dept_id=e.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY employee_count DESC;

-- Part 5
SELECT e.emp_name, d.dept_name
FROM employees e
RIGHT JOIN departments d ON e.dept_id=d.dept_id;

SELECT e.emp_name,d.dept_name
FROM departments d
LEFT JOIN employees e ON e.dept_id=d.dept_id;

SELECT  d.dept_name, d.location
FROM employees e
RIGHT JOIN departments d ON e.dept_id=d.dept_id
WHERE e.emp_id IS NULL;

-- Part 6
SELECT e.emp_name, e.dept_id AS emp_dept, d.dept_id AS dept_dept, d.dept_name
FROM employees e
FULL JOIN departments d ON e.dept_id=d.dept_id;

SELECT d.dept_name, p.project_name, p.budget
FROM departments d
FULL JOIN projects p ON d.dept_id=p.dept_id;

SELECT
    CASE
        WHEN e.emp_id IS NULL THEN 'Department without employees'
        WHEN d.dept_id IS NULL THEN 'Employees without department'
        ELSE 'Matched'
    END AS record_status,
    e.emp_name,
    d.dept_name
FROM employees e
FULL JOIN departments d ON e.dept_id=d.dept_id
WHERE e.emp_id IS NULL OR d.dept_id IS NULL;

-- Part 7
SELECT e.emp_name,d.dept_name, e.salary
FROM employees e
LEFT JOIN departments d ON e.dept_id=d.dept_id AND d.location='Building A';

SELECT e.emp_name, d.dept_name, e.salary
FROM employees e
LEFT JOIN departments d ON e.dept_id=d.dept_id WHERE  d.location='Building A';

SELECT emp_name, dept_name, salary
FROM employees
INNER JOIN departments ON employees.dept_id=departments.dept_id WHERE location='Building A';

-- Part 8
SELECT
    d.dept_name,
    e.emp_name,
    e.salary,
    p.project_name,
    p.budget
FROM departments d
LEFT JOIN employees e ON e.dept_id=d.dept_id
LEFT JOIN projects p ON d.dept_id=p.dept_id
ORDER BY d.dept_name,e.emp_name;

ALTER TABLE employees ADD COLUMN manager_id INT;

UPDATE employees SET manager_id = 3 WHERE  emp_id=1;
UPDATE employees SET manager_id = 3 WHERE emp_id=2;
UPDATE employees SET manager_id= NULL WHERE emp_id=3;
UPDATE employees SET manager_id=3 WHERE emp_id=4;
UPDATE employees SET manager_id=3 WHERE emp_id=5;

SELECT
    e.emp_name AS employee,
    m.emp_name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id=m.emp_id;

SELECT d.dept_name, AVG(e.salary) AS avg_salary
FROM departments d
INNER JOIN employees e ON d.dept_id=e.dept_id
GROUP BY d.dept_id,d.dept_name
HAVING AVG(salary)>50000;