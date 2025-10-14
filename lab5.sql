CREATE TABLE employees(
    employee_id INT,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    age INT CHECK ( age BETWEEN 18 AND 65),
    salary NUMERIC CHECK ( salary > 0 )
);
INSERT INTO employees VALUES (1,'Nur','Dau',19,42500);
INSERT INTO employees VALUES (2,'John','Johnny',32,12000);

-- Invalid insers
-- INSERT INTO employees VALUES(3,'Tom','Kim',17,1800);
-- INSERT INTO employees VALUES(4,'Lina','Anna',22,-400);

CREATE TABLE products_catalog(
    product_id INT,
    product_name VARCHAR(50),
    regular_price NUMERIC,
    discount_price NUMERIC,
    CONSTRAINT valid_discount CHECK (
        regular_price>0 AND
        discount_price>0 AND
        discount_price<regular_price
        )
);

INSERT INTO products_catalog VALUES (101,'watch',500,259);
INSERT INTO products_catalog VALUES (102,'TV',1000,800);

-- INSERT INTO products_catalog VALUES(103,'Keyboard',0,50);
-- INSERT INTO products_catalog VALUES(104,'Mouse',100,120);
CREATE TABLE bookings(
    booking_id INT,
    check_in_date DATE,
    check_out_date DATE,
    num_guests INT,
    CHECk ( num_guests BETWEEN 1 AND 10),
    CHECK ( check_out_date>check_in_date )
);

INSERT INTO bookings VALUES (1,'2025-10-6','2025-10-13',2);
INSERT INTO bookings VALUES (2,'2025-9-29','2025-10-5',5);

-- INSERT INTO bookings VALUES(3,'2025-10-6','2025-10-13,11');
-- INSERT INTO bookings VALUES(4,'2025-10-5','2025-9-29',7);


CREATE TABLE customers(
    customer_id INT NOT NULL,
    email VARCHAR(50) NOT NULL,
    phone VARCHAR(50),
    registration_date DATE NOT NULL
);

INSERT INTO customers VALUES (1,'nur@email.com','87718133256',CURRENT_DATE);
INSERT INTO customers VALUES (2,'daulet@email.com',NULL,'2025-10-10');

-- INSERT INTO customers VALUES(3,'zhan@email.com','87074587425',NULL) registration_id can't be NULL
-- INSERT INTO customers VALUES(4,NULL,'87778523648','2025-09-01') email can't be NULL

CREATE TABLE inventory(
    item_id INT NOT NULL,
    item_name VARCHAR(50) NOT NULL,
    quantity INT NOT NULL CHECK ( quantity >=0 ),
    unit_price NUMERIC NOT NULL CHECK ( unit_price>0 ),
    last_updated TIMESTAMP NOT NULL
);

INSERT INTO inventory VALUES (101,'Laptop',10,1200,NOW());
INSERT INTO inventory VALUES (102,'Mouse',50,25,NOW());

-- INSERT INTO inventory VALUES(103,'Keyboard',5,NULL,NOW()); unit_price can't be NULL
-- INSERT INTO inventory VALUES(104,'Monitor',NULL,500,NOW()); quantity can't be NULL

CREATE TABLE users(
    user_id INTEGER  PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    email VARCHAR(50) UNIQUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE course_enrollment(
    enrollment_id INTEGER,
    student_id INTEGER,
    course_code VARCHAR(50),
    semester VARCHAR(50),
    UNIQUE(student_id,course_code,semester)
);

ALTER TABLE users
ADD CONSTRAINT unique_username UNIQUE(username);

ALTER TABLE users
ADD CONSTRAINT unique_email UNIQUE(email);

INSERT INTO users VALUES(3,'Nurken','Nurken@email.com',NOW());

CREATE TABLE departments(
    dept_id INTEGER PRIMARY KEY,
    dept_name VARCHAR(50) NOT NULL,
    location VARCHAR(50)
);
INSERT INTO departments VALUES(1,'IT','Almaty');
INSERT INTO departments VALUES (2,'HR','London');
INSERT INTO departments VALUES (3,'Sales','Paris');

CREATE TABLE students_courses(
    student_id INT,
    course_id INT,
    enrollment_date DATE,
    grade VARCHAR(50),
    PRIMARY KEY (student_id,course_id)
);

INSERT INTO student_courses VALUES (1, 101, '2025-09-01', 'A');
INSERT INTO student_courses VALUES (1, 102, '2025-09-02', 'B');

-- The differences are that a primary key uniquely identifies a row and can't be NULL, while a unique key only enforces uniqueness allowing one NULL value.

-- Use a single-column key if one column uniquely identifies each record
-- Use a composite key when only a combination of two or more columns is unique

-- Because PRIMARY KEY represents the main unique identifier for the table
-- However, multiple UNIQUE constraints can exist for enforcing other uniqueness rules.

CREATE TABLE employees_dept(
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(50) NOT NULL,
    dept_id INT REFERENCES departments(dept_id),
    hire_date DATE
);

INSERT INTO employees_dept VALUES(1,'Beka',1,'2025-10-14');
-- INSERT INTO employees_dept VALUES(101,'Era',99,'2025-10-14');

CREATE TABLE authors(
    author_id INT PRIMARY KEY,
    author_name VARCHAR(50) NOT NULL,
    country VARCHAR(50)
);

CREATE TABLE publishers(
    publisher_id INT PRIMARY KEY,
    publisher_name VARCHAR(50) NOT NULL,
    city VARCHAR(50)
);

CREATE TABLE books(
    book_id INT PRIMARY KEY,
    title VARCHAR(50) NOT NULL,
    author_id INT REFERENCES authors(author_id),
    publisher_id INT REFERENCES publishers(publisher_id),
    publication_year INT,
    isbn VARCHAR(50) UNIQUE
);

INSERT INTO authors VALUES (1,'Haruki Murakami','japan');
INSERT INTO authors VALUES (2,'George Orwell','UK');

INSERT INTO publishers VALUES (1,'Kodansha','Tokyo');
INSERT INTO publishers VALUES (2,'1989','London');

INSERT INTO books VALUES (1,'1984',1,1,1949,'87547521');
INSERT INTO books VALUES (2,'Plaxa',2,2,1983,'45782');

CREATE TABLE categories(
    category_id INT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL
);

CREATE TABLE products_fk(
    product_id INT PRIMARY KEY,
    product_name VARCHAR(50) NOT NULL,
    category_id INT REFERENCES categories(category_id) ON DELETE RESTRICT
);

CREATE TABLE orders(
    order_id INT PRIMARY KEY,
    order_date DATE NOT NULL
);

CREATE TABLE order_items(
    item_id INT PRIMARY KEY,
    order_id INT REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INT REFERENCES products_fk(product_id),
    quantity INT CHECK ( quantity>0 )
);

INSERT INTO categories VALUES (1,'Electronics');
INSERT INTO products_fk VALUES (1,'Smartphone',1);

INSERT INTO orders VALUES (1,'2025-10-10');
INSERT INTO order_items VALUES (1,1,1,2);

DELETE FROM orders WHERE order_id=1;

CREATE TABLE customers(
    customer_id INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL ,
    email VARCHAR(50) UNIQUE NOT NULL,
    phone VARCHAR(50),
    registration_date DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE products(
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    description VARCHAR(100),
    price NUMERIC(10,2) NOT NULL CHECK ( price>=0 ),
    stock_quantity INT NOT NULL CHECK ( stock_quantity>=0 )
);

CREATE TABLE orders(
    order_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id) ON DELETE CASCADE,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_amount NUMERIC(10,2) CHECK ( total_amount>=0 ),
    status VARCHAR(20) NOT NULL CHECK ( status IN 'pending')
);

CREATE TABLE order_details(
    order_detail_id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INT REFERENCES products(product_id),
    quantity INT NOT NULL CHECK ( quantity>0 ),
    unit_price NUMERIC(10,2) NOT NULL CHECK ( unit_price>0 )
);

INSERT INTO customers (name,email,phone)VALUES
('Alice Brown', 'alice@example.com', '87071112233'),
('John Smith', 'john@example.com', '87075556677'),
('Sara Lee', 'sara@example.com', '87079998855'),
('Tom Wilson', 'tom@example.com', NULL),
('Emma Davis', 'emma@example.com', '87076668844');

INSERT INTO products (name,description,price,stock_quantity) VALUES
('Laptop', '15-inch display, 8GB RAM', 1200.00, 10),
('Headphones', 'Noise cancelling', 150.00, 50),
('Mouse', 'Wireless optical mouse', 25.00, 100),
('Keyboard', 'Mechanical RGB keyboard', 80.00, 30),
('Monitor', '27-inch 144Hz', 350.00, 20);

INSERT INTO orders(customer_id,total_amount,status) VALUES
(1, 1350.00, 'pending'),
(2, 175.00, 'processing'),
(3, 25.00, 'shipped'),
(4, 80.00, 'delivered'),
(5, 700.00, 'cancelled');

INSERT INTO order_details( order_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 1200.00),
(1, 2, 1, 150.00),
(2, 2, 1, 150.00),
(3, 3, 1, 25.00),
(4, 4, 1, 80.00),
(5, 5, 2, 350.00);

-- 1. Negative price
-- INSERT INTO products (name, description, price, stock_quantity)
-- VALUES ('Broken Item', 'Test', -50, 10);  -- Violates CHECK (price >= 0)

-- 2. Negative stock quantity
-- INSERT INTO products (name, description, price, stock_quantity)
-- VALUES ('Faulty Item', 'Test', 100, -5);  -- Violates CHECK (stock_quantity >= 0)

-- 3. Invalid order status
-- INSERT INTO orders (customer_id, total_amount, status)
-- VALUES (1, 100, 'lost');  -- Violates CHECK (status IN ...)

-- 4. Zero quantity in order_details
-- INSERT INTO order_details (order_id, product_id, quantity, unit_price)
-- VALUES (1, 3, 0, 20);  -- Violates CHECK (quantity > 0)

-- 5. Duplicate customer email
-- INSERT INTO customers (name, email, phone)
-- VALUES ('Duplicate User', 'alice@example.com', '87070001122');  -- Violates UNIQUE(email)

-- 6. Delete customer → check cascade on orders and order_details
-- DELETE FROM customers WHERE customer_id = 1;
-- -- This will delete orders for customer 1 and related order_details (CASCADE)

-- =====================================================
-- Step 7: Verification queries
-- =====================================================

-- Check data after cascade delete:
-- SELECT * FROM customers;
-- SELECT * FROM orders;
-- SELECT * FROM order_details;

-- Check existing constraints
-- \d customers
-- \d products
-- \d orders
-- \d order_details





