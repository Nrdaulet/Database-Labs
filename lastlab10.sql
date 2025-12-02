-- 3.1
BEGIN;
UPDATE accounts SET balance = balance -100.00 WHERE name = 'Alice';
UPDATE accounts SET balance = balance +100.00 WHERE name = 'Bob';
COMMIT;

-- 3.2
BEGIN;
UPDATE accounts SET balance = balance -500.00 WHERE name = 'Alice';
SELECT * FROM accounts WHERE name = 'Alice';

ROLLBACK;
SELECT * FROM accounts WHERE name = 'Alice';

-- 3.3
BEGIN;
UPDATE accounts SET balance = balance -100.00 WHERE name='Alice';
SAVEPOINT my_savepoint;

UPDATE accounts SET balance = balance +100.00 WHERE name ='Bob';
ROLLBACK TO my_savepoint;

UPDATE accounts SET balance =balance +100.00 WHERE name ='Wally';
COMMIT;

-- 3.4
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT * FROM products WHERE shop= 'Joe''s Shop';
SELECT * FROM products WHERE shop='Joe''s Shop';
COMMIT;

BEGIN;
DELETE FROM products WHERE shop='Joe''s Shop';
INSERT INTO products VALUES ('Joe''s Shop', 'Fanta', 3.50);
COMMIT;

-- Task 4
-- 1
BEGIN;
DO $$
DECLARE current_balance DECIMAL(10,2);
BEGIN
    SELECT balance INTO current_balance FROM accounts WHERE name='Bob';
    IF current_balance >=200 THEN
       UPDATE accounts SET balance =balance -200 WHERE name='Bob';
        UPDATE accounts SET balance = balance +200 WHERE name ='Wally';
    ELSE
        RAISE NOTICE 'Not enough funds';
        ROLLBACK;
        RETURN;
    END IF;
END $$;
COMMIT;

-- 2
BEGIN;
INSERT INTO products VALUES ('Joe''s Shop', 'Tea',1.50);
SAVEPOINT sp1;

UPDATE products SET price =2.00 WHERE product='Tea';
SAVEPOINT sp2;

DELETE FROM products WHERE product ='Tea';
ROLLBACK TO sp1;
COMMIT;

-- 3
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
      SELECT balance FROM accounts WHERE name='Alice';
UPDATE accounts SET balance=balance -300 WHERE name ='Alice';

COMMIT;

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
      SELECT balance FROM accounts WHERE name='Alice';
UPDATE accounts SET balance =balance-300 WHERE name ='alice';
COMMIT;

-- 4
-- Without transaction
-- SELECT max(price) FROM sells WHERE shop='Joe';
-- Joe updates price
-- SELECT min(price) FROM sells WHERE shop='Joe';

BEGIN;
SELECT MAX(price) FROM Sells WHERE shop='Joe';
SELECT MIN(price) FROM Sells WHERE shop='Joe';
COMMIT;

