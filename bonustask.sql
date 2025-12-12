
CREATE TYPE request_type AS ENUM('transfer', 'deposit', 'withdrawal');
CREATE TYPE transaction_status AS ENUM('pending', 'completed', 'failed', 'reversed');
CREATE TYPE customer_status AS ENUM('active', 'blocked', 'frozen');

CREATE TABLE customers(
    customer_id SERIAL PRIMARY KEY,
    iin CHAR(12) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(50),
    status customer_status DEFAULT 'active',
    created_at TIMESTAMP DEFAULT now(),
    daily_limit_kzt NUMERIC(18, 2) DEFAULT 10000000.00
);

CREATE TABLE accounts(
    account_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    account_number VARCHAR(35) UNIQUE NOT NULL,
    currency VARCHAR(3) NOT NULL CHECK ( currency IN('KZT', 'USD','EUR','RUB')),
    balance NUMERIC(18, 2) DEFAULT 0.00 CHECK ( balance>=0),
    is_active BOOLEAN DEFAULT TRUE,
    opened_at TIMESTAMP DEFAULT now(),
    closed_at TIMESTAMP,
    FOREIGN KEY(customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE transactions(
    transaction_id SERIAL PRIMARY KEY,
    from_account_id INT,
    to_account_id INT,
    amount NUMERIC(18, 2) NOT NULL CHECK ( amount>0 ),
    currency VARCHAR(3) NOT NULL,
    exchange_rate NUMERIC(18, 2) DEFAULT 1.0,
    amount_kzt NUMERIC(18, 2),
    type request_type NOT NULL,
    status transaction_status DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT now(),
    completed_at TIMESTAMP,
    description VARCHAR(200),
    FOREIGN KEY(from_account_id) REFERENCES accounts(account_id),
    FOREIGN KEY(to_account_id) REFERENCES accounts(account_id)
);

CREATE TABLE exchange_rates(
    rate_id SERIAL PRIMARY KEY,
    from_currency VARCHAR(3) NOT NULL,
    tto_currency VARCHAR(3) NOT NULL,
    rate NUMERIC(18, 6) NOT NULL CHECK ( rate>0 ),
    valid_from TIMESTAMP DEFAULT now(),
    valid_to TIMESTAMP,
    UNIQUE(from_currency, tto_currency,valid_from)
);

CREATE TABLE audit_log(
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id INT,
    action VARCHAR(10) NOT NULL CHECK ( action IN('INSERT', 'UPDATE', 'DELETE')),
    old_values jsonb,
    new_values jsonb,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT now(),
    ip_address inet
);

CREATE OR REPLACE FUNCTION process_transfer(
    p_from_account_number VARCHAR(34),
    p_to_account_number VARCHAR(34),
    p_amount NUMERIC(18, 2),
    p_currency VARCHAR(3),
    p_description VARCHAR(200)
)

RETURNS TABLE(
    success BOOLEAN,
    error_mode VARCHAR(20),
    error_message TEXT,
    transaction_id INT
) AS $$
DECLARE
    v_from_account_id INT;
    v_to_account_id INT;
    v_from_customer_id INT;
    v_to_customer_id INT;
    v_from_balance NUMERIC(18, 2);
    v_to_balance NUMERIC(18, 2);
    v_from_currency VARCHAR(3);
    v_tto_currency VARCHAR(3);
    v_customer_status customer_status;
    v_daily_limit NUMERIC(18, 2);
    v_today_total NUMERIC(18, 2);
    v_exchange_rate NUMERIC(18, 6);
    v_amount_kzt NUMERIC(18, 2);
    v_converted_amount NUMERIC(18, 2);
    v_transaction_id INT;
    v_from_active BOOLEAN;
    v_to_active BOOLEAN;
BEGIN
    SAVEPOINT transfer_start;

    IF p_from_account_number=p_to_account_number THEN
        RETURN QUERY SELECT false, 'ERR_SAME_ACCOUNT'::VARCHAR(20),
                            'Cannot transfer to the same account' :: TEXT, NULL::INT;
        RETURN;
    end if;

    IF p_amount<=0 THEN
        RETURN QUERY SELECT false, 'ERR_INVALID_AMOUNT'::VARCHAR(20),
                            'Transfer amount must be positive' ::TEXT, NULL::INT;
        RETURN;
    end if;

    BEGIN
        SELECT a.account_id, a.customer_id, a.balance, a.currency, a.is_active
        INTO STRICT v_from_account_id, v_from_customer_id, v_from_balance,v_from_currency,v_from_active
        FROM accounts a
        WHERE a.account_number=p_from_account_number
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
        RETURN QUERY SELECT false, 'ERR_FROM_NOT_FOUND'::VARCHAR(20),
                            'Source account does not exist'::TEXT, NULL::INT;
        RETURN ;
    end;

    IF NOT v_from_active THEN
        RETURN QUERY SELECT false, 'ERR_FROM_INACTIVE'::VARCHAR(20),
                            'Source account is not active'::TEXT, NULL::INT;
        RETURN;
    end if;

    BEGIN
        SELECT a.account_id, a.customer_id, a.balance, a.currency, a.is_active
        INTO STRICT v_to_account_id,v_to_customer_id, v_to_balance, v_tto_currency, v_to_active
        FROM accounts a
        WHERE a.account_number=p_to_account_number
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
        RETURN QUERY SELECT false, 'ERR_TO_NOT_FOUND'::VARCHAR(20),
                            'Destination account does not exist'::TEXT, NULL::INT;
        RETURN;
    end;

    IF NOT v_to_active THEN
        RETURN QUERY SELECT false, 'ERR_TO_INACTIVE'::VARCHAR(20),
                            'Destination account is not active'::TEXT, NULL::INT;
        RETURN;
    end if;

    SELECT c.status, c.daily_limit_kzt
    INTO v_customer_status,v_daily_limit
    FROM customers c
    WHERE c.customer_id=v_from_customer_id;

    IF v_customer_status !='active' THEN
        INSERT INTO audit_log(table_name, record_id, action, new_values,changed_by)
        VALUES ('transactions', NULL,'INSERT',
                json_build_object('error', 'Customer blocked or frozen', 'customer_id',v_from_customer_id, 'status', v_customer_status), current_user);
        RETURN QUERY SELECT false, 'ERR_CUSTOMER_BLOCKED'::VARCHAR(20),
                            format('Customer status is %s (not active)', v_customer_status)::TEXT,NULL::INT;
        RETURN;
    end if;

    IF p_currency!= v_from_currency THEN
        SELECT rate INTO v_exchange_rate
        FROM exchange_rates
        WHERE from_currency=p_currency
        AND tto_currency=v_from_currency
        AND valid_from <=now()
        AND (valid_to IS NULL OR valid_to>now())
        ORDER BY valid_from DESC
        LIMIT 1;

        IF v_exchange_rate IS NULL THEN
            RETURN QUERY SELECT false, 'ERR_NO_EXCHANGE_RATE'::VARCHAR(20),
                                format('No change rate found for %s to %s', p_currency, v_from_currency)::TEXT, NULL::INT;
            RETURN;
        end if;

    ELSE
        v_exchange_rate :=1.0;
        v_converted_amount :=p_amount;
    end if;

    IF v_from_balance < v_converted_amount THEN
        INSERT INTO audit_log(table_name, record_id, action, new_values, changed_by)
        VALUES ('transactions', NULL, 'INSERT',
                json_build_object('error', 'Insufficient balance','account_id', v_from_account_id, 'balance', v_from_balance, 'required', v_converted_amount),current_user);
        RETURN QUERY SELECT false, 'ERR_INSUFFICIENT_FUNDS'::VARCHAR(20),
                            format('Insufficient balance: have %s, need %s', v_from_balance,v_converted_amount)::TEXT,NULL::INT;
        RETURN;
    end if;

    IF p_currency = 'KZT' THEN
        v_amount_kzt :=p_amount;
    ELSE
        SELECT rate INTO v_exchange_rate
        FROM exchange_rates
        WHERE from_currency = p_currency
        AND tto_currency = 'KZT'
        AND valid_from <= now()
        AND (valid_to IS NULL OR valid_to >now())
        ORDER BY valid_from DESC
        LIMIT 1;

        IF v_exchange_rate IS NULL THEN
            v_amount_kzt := p_amount;
        ELSE
            v_amount_kzt := p_amount*v_exchange_rate;
        end if;
    end if;

    SELECT coalesce(sum(amount_kzt), 0)
    INTO v_today_total
    FROM transactions
    WHERE from_account_id= v_from_account_id
    AND DATE(created_at) = CURRENT_DATE
    AND status IN('completed', 'pending');

    IF(v_today_total+v_amount_kzt)>v_daily_limit THEN
        INSERT INTO audit_log(table_name, record_id, action, new_values, changed_by)
        VALUES ('transactions', NULL, 'INSERT',
                json_build_object('error','Daily limit exceeded', 'customer_id', v_from_customer_id, 'today_total', v_today_total, 'Limit', v_daily_limit, 'attempted', v_amount_kzt),
                current_user);
        RETURN QUERY SELECT false, 'ERR_DAILY_LIMIT' ::VARCHAR(20),
                            format('Daily limit exceeded: used %s KZT of %s KZT limit',
                            v_today_total, v_daily_limit)::TEXT, NULL::INT;
        RETURN;
    end if;

    INSERT INTO transactions(
        from_account_id, to_account_id, amount, currency,
                             exchange_rate,amount_kzt, type, status, description, created_at
    )
    VALUES (v_from_account_id, v_to_account_id, p_amount, p_currency,
            v_exchange_rate, v_amount_kzt, 'transfer', 'pending', p_description, now())
    RETURNING transactions.transaction_id INTO v_transaction_id;

    INSERT INTO audit_log(table_name, record_id, action, new_values, changed_by)
    VALUES ('transactions', v_transaction_id, 'INSERT',
            json_build_object('from_account', v_from_account_id,
            'to_account', v_to_account_id, 'amount', p_amount, 'currency', p_currency),
            current_user);
    UPDATE accounts
    SET balance =balance - v_converted_amount
    WHERE account_id=v_from_account_id;

    IF p_currency != v_tto_currency THEN
        SELECT rate INTO v_exchange_rate
        FROM exchange_rates
        WHERE from_currency=p_currency
        AND tto_currency = v_tto_currency
        AND valid_from <= now()
        AND (valid_to IS NULL OR valid_to > now())
        ORDER BY valid_from DESC
        LIMIT 1;

        IF v_exchange_rate IS NULL THEN
            ROLLBACK TO SAVEPOINT transfer_start;
            RETURN QUERY SELECT false, 'ERR_NO_EXCHANGE_RATE'::VARCHAR(20),
                                format('No exchange rate found for %s to %s', p_currency, v_from_currency)::TEXT,
                                NULL::INT;
            RETURN;
        end if;

        v_converted_amount :=p_amount*v_exchange_rate;
    ELSE
        v_converted_amount := p_amount;
    end if;
    UPDATE accounts
    SET balance= balance+v_converted_amount
    WHERE account_id=v_to_account_id;

    UPDATE transactions
    SET status = 'completed',
        completed_at = now()
    WHERE transaction_id= v_transaction_id;

    INSERT INTO audit_log(table_name, record_id, action, new_values, changed_by)
    VALUES ('transactions', v_transaction_id, 'UPDATE',
            json_build_object('status', 'completed', 'completed_at', now()), current_user);
    RETURN QUERY SELECT true, 'SUCCESS'::VARCHAR(20),
                        'Transfer completed successfully'::TEXT, v_transaction_id;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO SAVEPOINT transfer_start;

        INSERT INTO audit_log(table_name, record_id, action, new_values ,changed_by)
        VALUES ('transactions', NULL, 'INSERT',
                json_build_object('error', SQLERRM, 'sqlstate', SQLSTATE), current_user);
        RETURN QUERY SELECT false, 'ERR_INTERNAL' ::VARCHAR(20),
                            format('Internal error: %s', SQLERRM)::TEXT, NULL::INT;
end;
    $$ LANGUAGE plpgsql;

-- 1. Курсы валют
INSERT INTO exchange_rates(from_currency,tto_currency, rate, valid_from) VALUES
('USD', 'KZT', 480.50, now()),
('EUR', 'KZT', 520.30, now()),
('RUB', 'KZT', 5.20, now()),
('KZT', 'USD', 0.00208, now()),
('KZT', 'EUR', 0.00192, now()),
('KZT', 'RUB', 0.192, now()),
('USD', 'EUR', 0.92, now()),
('EUR', 'USD', 1.09, now());

-- 2. Клиенты (минимум 10)
INSERT INTO customers(iin, full_name, phone, email, status, daily_limit_kzt) VALUES
('123456789012', 'Нурсултан Айтжанов', '+77011234567', 'nursultan@mail.kz', 'active', 10000000.00),
('234567890123', 'Айгерим Смагулова', '+77012345678', 'aigerim@gmail.com', 'active', 5000000.00),
('345678901234', 'Даурен Оспанов', '+77023456789', 'dauren@yandex.kz', 'active', 15000000.00),
('456789012345', 'Асель Кенжебекова', '+77034567890', 'asel@mail.ru', 'blocked', 3000000.00),
('567890123456', 'Ержан Темиров', '+77045678901', 'yerzhan@gmail.com', 'active', 8000000.00),
('678901234567', 'Гульнара Абдуллина', '+77056789012', 'gulnara@mail.kz', 'active', 12000000.00),
('789012345678', 'Бауыржан Сарсенов', '+77067890123', 'baur@yandex.kz', 'frozen', 6000000.00),
('890123456789', 'Меруерт Касымова', '+77078901234', 'meruert@gmail.com', 'active', 20000000.00),
('901234567890', 'Арман Жумабаев', '+77089012345', 'arman@mail.kz', 'active', 7000000.00),
('012345678901', 'Жанар Нурланова', '+77090123456', 'zhanar@gmail.com', 'active', 9000000.00);

-- 3. Счета (минимум 10)
INSERT INTO accounts(customer_id, account_number, currency, balance, is_active, opened_at) VALUES
(1, 'KZ86125KZT5004100100', 'KZT', 5000000.00, true, now()),
(1, 'KZ86125USD5004100101', 'USD', 10000.00, true, now()),
(2, 'KZ86125KZT5004100102', 'KZT', 3000000.00, true, now()),
(2, 'KZ86125EUR5004100103', 'EUR', 5000.00, true, now()),
(3, 'KZ86125KZT5004100104', 'KZT', 8000000.00, true, now()),
(3, 'KZ86125USD5004100105', 'USD', 20000.00, true, now()),
(5, 'KZ86125KZT5004100106', 'KZT', 2500000.00, true, now()),
(6, 'KZ86125RUB5004100107', 'RUB', 500000.00, true, now()),
(8, 'KZ86125KZT5004100108', 'KZT', 15000000.00, true, now()),
(9, 'KZ86125USD5004100109', 'USD', 8000.00, true, now()),
(10, 'KZ86125EUR5004100110', 'EUR', 3000.00, true, now());

SELECT proname,proargtypes
FROM pg_proc
WHERE proname= 'process_transfer';

SELECT * FROM process_transfer(
     p_from_account_number:='KZ86125KZT5004100100',
    p_to_account_number:='KZ86125KZT5004100102',
              p_amount:=50000.00,
              p_currency:='KZT',
              p_description:='Perevod drugu'
    );

SELECT * FROM process_transfer(
    'KZ86125USD5004100101',
    'KZ86125KZT5004100102',
              100.00,
              'USD',
              'Payment for service'
              );

SELECT * FROM process_transfer(
    'KZ86125KZT5004100106',
    'KZ86125KZT5004100108',
              10000000.00,
              'KZT',
              'Big summa'
);

SELECT * FROM process_transfer(
    'KZ86125KZT5004100100',
    'KZ86125KZT5004100100',
              1000.0,
              'KZT',
              'sam sebe'
    );

SELECT *FROM process_transfer(
    'KZ99999999999999999',
    'KZ86125KZT5004100102',
             1000.00,
             'KZT',
             'Test'
    );

SELECT
    c.full_name,
    a.account_number,
    a.currency,
    a.balance
FROM accounts a
JOIN customers c ON a.customer_id= c.customer_id
ORDER BY c.customer_id, a.account_id;

SELECT
    transaction_id,
    from_account_id,
    to_account_id,
    amount,
    currency,
    status,
    description,
    created_at
FROM transactions
ORDER BY created_at DESC;

SELECT
    log_id,
    table_name,
    action,
    new_values,
    changed_at
FROM audit_log
ORDER BY changed_at DESC
LIMIT 10;

CREATE OR REPLACE VIEW customer_balance_summary AS
WITH account_balances AS (
    SELECT
        c.customer_id,
        c.iin,
        c.full_name,
        c.email,
        c.status,
        c.daily_limit_kzt,

        a.account_id,
        a.account_number,
        a.currency,
        a.balance,
        a.is_active,

        CASE
            WHEN a.currency = 'KZT' THEN a.balance
            ELSE a.balance * COALESCE(
                (SELECT rate
                FROM exchange_rates
                WHERE from_currency = a.currency
                AND tto_currency = 'KZT'
                AND valid_from <= NOW()
                AND (valid_to IS NULL OR valid_to >= NOW())
                ORDER BY valid_from DESC
                LIMIT 1),
                0
            )
        END AS balance_kzt
    FROM customers c
    LEFT JOIN accounts a ON c.customer_id = a.customer_id
),
daily_usage AS (
    SELECT
        a.customer_id,
        COALESCE(SUM(t.amount_kzt), 0) AS today_used_kzt
    FROM accounts a
    LEFT JOIN transactions t ON a.account_id = t.from_account_id
        AND DATE(t.created_at) = CURRENT_DATE
        AND t.status IN ('completed', 'pending')
    GROUP BY a.customer_id
)
SELECT
    ab.customer_id,
    ab.iin,
    ab.full_name,
    ab.email,
    ab.status,
    ab.account_number,
    ab.currency,
    ab.balance,
    ab.balance_kzt,
    ab.is_active,
    SUM(ab.balance_kzt) OVER (PARTITION BY ab.customer_id) AS total_balance_kzt,
    ab.daily_limit_kzt,
    COALESCE(du.today_used_kzt, 0) AS today_used_kzt,

    CASE
        WHEN ab.daily_limit_kzt > 0 THEN
            ROUND((COALESCE(du.today_used_kzt, 0) / ab.daily_limit_kzt * 100), 2)
        ELSE 0
    END AS daily_limit_utilization_pct,  -- Исправил опечатку utilizaation -> utilization
    DENSE_RANK() OVER (ORDER BY SUM(ab.balance_kzt) OVER (PARTITION BY ab.customer_id) DESC) AS balance_rank
FROM account_balances ab
LEFT JOIN daily_usage du ON ab.customer_id = du.customer_id
ORDER BY balance_rank, ab.customer_id, ab.account_id;

CREATE OR REPLACE VIEW daily_transaction_report AS
WITH daily_stats AS (
    SELECT
        DATE(created_at) AS transaction_date,
        type,
        status,
        count(*) AS transaction_count,
        sum(amount_kzt) AS total_volume_kzt,
        avg(amount_kzt) AS avg_amount_kzt,
        min(amount_kzt) AS min_amount_kzt,
        max(amount_kzt) AS max_amount_kzt
    FROM transactions
    WHERE status = 'completed'
    GROUP BY DATE(created_at), type,status
),
    running_totals AS(
        SELECT
            transaction_date,
            type,
            status,
            transaction_count,
            total_volume_kzt,
            avg_amount_kzt,
            min_amount_kzt,
            max_amount_kzt,

            SUM(total_volume_kzt) OVER (
                PARTITION BY type
                ORDER BY transaction_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ) AS cumulative_volume_kzt,
            LAG(total_volume_kzt) OVER(
                PARTITION BY type
                ORDER BY transaction_date
                ) AS prev_day_volume_kzt
        FROM daily_stats
    )
SELECT
    transaction_date,
    type,
    status,
    transaction_count,
    round(total_volume_kzt, 2) AS total_volume_kzt,
    round(avg_amount_kzt, 2) AS avg_amount_kzt,
    round(min_amount_kzt, 2) AS min_amount_kzt,
    round(max_amount_kzt, 2) AS max_amount_kzt,
    round(cumulative_volume_kzt, 2) AS cumulative_volume_kzt,
    CASE
        WHEN prev_day_volume_kzt IS NULL OR prev_day_volume_kzt = 0 THEN NULL
        ELSE round(((total_volume_kzt - prev_day_volume_kzt) / prev_day_volume_kzt * 100), 2)
    END AS day_over_day_growth_pct
FROM running_totals
ORDER BY transaction_date DESC, type;

CREATE OR REPLACE VIEW suspicious_activity_view
WITH (security_barrier=true) AS
    WITH large_transactions AS(
        SELECT
            t.transaction_id,
            t.from_account_id,
            t.to_account_id,
            c.customer_id,
            c.iin,
            c.full_name,
            t.amount,
            t.currency,
            t.amount_kzt,
            t.created_at,
            t.description,
            'LARGE_AMOUNT' AS flag_type,
            'Transaction exceeds 5M KZT equivalent' AS flag_reason
        FROM transactions t
        JOIN accounts a on t.from_account_id = a.account_id
        JOIN customers c ON a.customer_id=c.customer_id
        WHERE t.amount_kzt>5000000
        AND t.status='completed'
    ),
high_frequency AS (
    SELECT
        a.customer_id,
        c.iin,
        c.full_name,
        date_trunc('hour',t.created_at) AS hour_window,
        count(*) AS transaction_count,
        min(t.transaction_id) AS first_transaction_id,
        min(t.created_at) AS first_transaction_time,
        'HIGH_FREQUENCY' AS flag_type,
        'More than 10 transactions in one hour' AS flag_reason
    FROM transactions t
    JOIN accounts a ON t.from_account_id = a.account_id
    JOIN customers c on a.customer_id = c.customer_id
    WHERE t.status='completed'
    GROUP BY a.customer_id, c.iin, c.full_name, date_trunc('hour', t.created_at)
    HAVING count(*)>10
),
rapid_sequential AS (
    -- Быстрые последовательные переводы (менее 1 минуты)
    SELECT
        t1.transaction_id,
        t1.from_account_id,
        t1.to_account_id,
        c.customer_id,
        c.iin,
        c.full_name,
        t1.amount,
        t1.currency,
        t1.amount_kzt,
        t1.created_at,
        t1.description,
        'RAPID_SEQUENTIAL' AS flag_type,
        'Sequential transfers less than 1 minute apart' AS flag_reason,
        EXTRACT(EPOCH FROM (t1.created_at - t2.created_at)) AS seconds_between
    FROM transactions t1
    JOIN transactions t2 ON t1.from_account_id = t2.from_account_id
        AND t1.transaction_id > t2.transaction_id
        AND t1.status = 'completed'
        AND t2.status = 'completed'
        AND EXTRACT(EPOCH FROM (t1.created_at - t2.created_at)) < 60
    JOIN accounts a ON t1.from_account_id = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
)

SELECT
    transaction_id,
    from_account_id,
    to_account_id,
    customer_id,
    iin,
    full_name,
    amount,
    currency,
    amount_kzt,
    created_at,
    description,
    flag_type,
    flag_reason,
    NULL::NUMERIC AS seconds_between
FROM large_transactions

UNION ALL

SELECT
    first_transaction_id AS transaction_id,
    NULL::INT AS from_account_id,
    NULL::INT AS to_account_id,
    customer_id,
    iin,
    full_name,
    NULL::NUMERIC AS amount,
    NULL::VARCHAR AS currency,
    NULL::NUMERIC AS amount_kzt,
    first_transaction_time AS created_at,
    NULL::VARCHAR AS description,
    flag_type,
    flag_reason || ' (count: ' || transaction_count || ')' AS flag_reason,
    NULL::NUMERIC AS seconds_between
FROM high_frequency

UNION ALL

SELECT
    transaction_id,
    from_account_id,
    to_account_id,
    customer_id,
    iin,
    full_name,
    amount,
    currency,
    amount_kzt,
    created_at,
    description,
    flag_type,
    flag_reason,
    seconds_between
FROM rapid_sequential

ORDER BY created_at DESC;

SELECT * FROM daily_transaction_report LIMIT 10;

SELECT
    transaction_date,
    type,
    total_volume_kzt,
    day_over_day_growth_pct,
    cumulative_volume_kzt
FROM daily_transaction_report
WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY transaction_date DESC, type;

SELECT * FROM suspicious_activity_view LIMIT 10;

SELECT
    flag_type,
    COUNT(*) AS incident_count,
    SUM(amount_kzt) AS total_amount_kzt
FROM suspicious_activity_view
WHERE amount_kzt IS NOT NULL
GROUP BY flag_type
ORDER BY incident_count DESC;

SELECT * FROM process_transfer(
    'KZ86125KZT5004100104',
    'KZ86125KZT5004100108',
    6000000.00,
    'KZT',
    'Large transfer for testing'
);

-- Создаём несколько быстрых последовательных транзакций
SELECT * FROM process_transfer('KZ86125KZT5004100100', 'KZ86125KZT5004100102', 10000, 'KZT', 'Rapid 1');
SELECT * FROM process_transfer('KZ86125KZT5004100100', 'KZ86125KZT5004100102', 15000, 'KZT', 'Rapid 2');
SELECT * FROM process_transfer('KZ86125KZT5004100100', 'KZ86125KZT5004100102', 20000, 'KZT', 'Rapid 3');

-- Проверяем подозрительные активности
SELECT * FROM suspicious_activity_view;

CREATE INDEX idx_transactions_account_date_status
ON transactions(from_account_id, created_at DESC, status)
WHERE status IN ('completed', 'pending');

CREATE INDEX idx_accounts_number_hash
ON accounts USING HASH (account_number);

CREATE INDEX idx_accounts_active_currency
ON accounts(customer_id, currency, balance)
WHERE is_active = true;

CREATE INDEX idx_customers_email_lower
ON customers(LOWER(email));

CREATE INDEX idx_audit_log_new_values_gin
ON audit_log USING GIN (new_values);

CREATE INDEX idx_audit_log_old_values_gin
ON audit_log USING GIN (old_values);

CREATE INDEX idx_accounts_covering
ON accounts(customer_id, currency)
INCLUDE (balance, is_active, account_number);

CREATE INDEX idx_exchange_rates_lookup
ON exchange_rates(from_currency, tto_currency, valid_from DESC)
WHERE valid_to IS NULL OR valid_to > NOW();

CREATE INDEX idx_transactions_suspicious
ON transactions(from_account_id, created_at, amount_kzt)
WHERE status = 'completed' AND amount_kzt > 1000000;

EXPLAIN ANALYZE
SELECT * FROM transactions
WHERE from_account_id = 1
  AND created_at >= CURRENT_DATE - INTERVAL '30 days'
  AND status = 'completed';

EXPLAIN ANALYZE
SELECT * FROM customers
WHERE LOWER(email) = LOWER('nursultan@mail.kz');

EXPLAIN ANALYZE
SELECT customer_id, currency, balance FROM accounts
WHERE is_active = true AND currency = 'KZT';

EXPLAIN ANALYZE
SELECT * FROM audit_log
WHERE new_values @> '{"status": "completed"}';

EXPLAIN ANALYZE
SELECT * FROM accounts
WHERE account_number = 'KZ86125KZT5004100100';

EXPLAIN ANALYZE
SELECT customer_id, currency, balance, is_active, account_number
FROM accounts
WHERE customer_id = 1 AND currency = 'KZT';

SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexname::regclass) DESC;

SELECT
    schemaname,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

CREATE OR REPLACE FUNCTION process_salary_batch(
    p_company_account_number VARCHAR(34),
    p_payments JSONB
)
RETURNS TABLE(
    success BOOLEAN,
    successful_count INT,
    failed_count INT,
    total_amount_processed NUMERIC(18, 2),
    failed_details JSONB,
    message TEXT
) AS $$
DECLARE
    v_company_account_id INT;
    v_company_balance NUMERIC(18, 2);
    v_company_currency VARCHAR(3);
    v_total_batch_amount NUMERIC(18, 2) := 0;
    v_payment JSONB;
    v_employee_iin VARCHAR(12);
    v_employee_account_id INT;
    v_employee_account_number VARCHAR(34);
    v_payment_amount NUMERIC(18, 2);
    v_payment_description TEXT;
    v_successful_count INT := 0;
    v_failed_count INT := 0;
    v_failed_array JSONB := '[]'::JSONB;
    v_exchange_rate NUMERIC(18, 6);
    v_converted_amount NUMERIC(18, 2);
    v_transaction_id INT;
    v_lock_acquired BOOLEAN;
BEGIN
    v_lock_acquired := pg_try_advisory_lock(hashtext(p_company_account_number));

    IF NOT v_lock_acquired THEN
        RETURN QUERY SELECT
            false,
            0,
            0,
            0::NUMERIC(18, 2),
            '[]'::JSONB,
            'Another batch is being processed for this company account'::TEXT;
        RETURN;
    END IF;

    BEGIN
        SELECT account_id, balance, currency
        INTO STRICT v_company_account_id, v_company_balance, v_company_currency
        FROM accounts
        WHERE account_number = p_company_account_number
          AND is_active = true
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            PERFORM pg_advisory_unlock(hashtext(p_company_account_number));
            RETURN QUERY SELECT
                false,
                0,
                0,
                0::NUMERIC(18, 2),
                '[]'::JSONB,
                'Company account not found or inactive'::TEXT;
            RETURN;
    END;

    FOR v_payment IN SELECT * FROM jsonb_array_elements(p_payments)
    LOOP
        v_payment_amount := (v_payment->>'amount')::NUMERIC(18, 2);

        IF v_company_currency = 'KZT' THEN
            v_total_batch_amount := v_total_batch_amount + v_payment_amount;
        ELSE
            SELECT rate INTO v_exchange_rate
            FROM exchange_rates
            WHERE from_currency = v_company_currency
              AND tto_currency = 'KZT'
              AND valid_from <= NOW()
              AND (valid_to IS NULL OR valid_to > NOW())
            ORDER BY valid_from DESC
            LIMIT 1;

            IF v_exchange_rate IS NOT NULL THEN
                v_total_batch_amount := v_total_batch_amount + (v_payment_amount * v_exchange_rate);
            ELSE
                v_total_batch_amount := v_total_batch_amount + v_payment_amount;
            END IF;
        END IF;
    END LOOP;

    IF v_company_balance < v_total_batch_amount THEN
        PERFORM pg_advisory_unlock(hashtext(p_company_account_number));
        RETURN QUERY SELECT
            false,
            0,
            0,
            0::NUMERIC(18, 2),
            '[]'::JSONB,
            format('Insufficient balance: have %s, need %s', v_company_balance, v_total_batch_amount)::TEXT;
        RETURN;
    END IF;

    FOR v_payment IN SELECT * FROM jsonb_array_elements(p_payments)
    LOOP
        SAVEPOINT individual_payment;

        BEGIN
            v_employee_iin := v_payment->>'iin';
            v_payment_amount := (v_payment->>'amount')::NUMERIC(18, 2);
            v_payment_description := COALESCE(v_payment->>'description', 'Salary payment');

            SELECT a.account_id, a.account_number
            INTO v_employee_account_id, v_employee_account_number
            FROM customers c
            JOIN accounts a ON c.customer_id = a.customer_id
            WHERE c.iin = v_employee_iin
              AND a.currency = v_company_currency
              AND a.is_active = true
            LIMIT 1;

            IF v_employee_account_id IS NULL THEN
                RAISE EXCEPTION 'Employee account not found for IIN: %', v_employee_iin;
            END IF;

            IF v_company_currency = 'KZT' THEN
                v_converted_amount := v_payment_amount;
                v_exchange_rate := 1.0;
            ELSE
                SELECT rate INTO v_exchange_rate
                FROM exchange_rates
                WHERE from_currency = v_company_currency
                  AND tto_currency = 'KZT'
                  AND valid_from <= NOW()
                  AND (valid_to IS NULL OR valid_to > NOW())
                ORDER BY valid_from DESC
                LIMIT 1;

                v_converted_amount := v_payment_amount * COALESCE(v_exchange_rate, 1.0);
            END IF;

            INSERT INTO transactions(
                from_account_id,
                to_account_id,
                amount,
                currency,
                exchange_rate,
                amount_kzt,
                type,
                status,
                description,
                created_at
            ) VALUES (
                v_company_account_id,
                v_employee_account_id,
                v_payment_amount,
                v_company_currency,
                v_exchange_rate,
                v_converted_amount,
                'transfer',
                'completed',
                v_payment_description,
                NOW()
            ) RETURNING transaction_id INTO v_transaction_id;

            UPDATE accounts
            SET balance = balance - v_payment_amount
            WHERE account_id = v_company_account_id;

            UPDATE accounts
            SET balance = balance + v_payment_amount
            WHERE account_id = v_employee_account_id;

            INSERT INTO audit_log(table_name, record_id, action, new_values, changed_by)
            VALUES (
                'transactions',
                v_transaction_id,
                'INSERT',
                jsonb_build_object(
                    'type', 'salary_batch',
                    'from_account', v_company_account_id,
                    'to_account', v_employee_account_id,
                    'amount', v_payment_amount,
                    'iin', v_employee_iin
                ),
                current_user
            );

            v_successful_count := v_successful_count + 1;

            RELEASE SAVEPOINT individual_payment;

        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK TO SAVEPOINT individual_payment;

                v_failed_count := v_failed_count + 1;
                v_failed_array := v_failed_array || jsonb_build_object(
                    'iin', v_employee_iin,
                    'amount', v_payment_amount,
                    'error', SQLERRM,
                    'description', v_payment_description
                );

                INSERT INTO audit_log(table_name, record_id, action, new_values, changed_by)
                VALUES (
                    'transactions',
                    NULL,
                    'INSERT',
                    jsonb_build_object(
                        'type', 'salary_batch_failed',
                        'iin', v_employee_iin,
                        'amount', v_payment_amount,
                        'error', SQLERRM
                    ),
                    current_user
                );
        END;
    END LOOP;

    PERFORM pg_advisory_unlock(hashtext(p_company_account_number));

    RETURN QUERY SELECT
        true,
        v_successful_count,
        v_failed_count,
        v_total_batch_amount,
        v_failed_array,
        format('Batch completed: %s successful, %s failed', v_successful_count, v_failed_count)::TEXT;

EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_advisory_unlock(hashtext(p_company_account_number));

        RETURN QUERY SELECT
            false,
            v_successful_count,
            v_failed_count,
            0::NUMERIC(18, 2),
            v_failed_array,
            format('Batch processing error: %s', SQLERRM)::TEXT;
END;
$$ LANGUAGE plpgsql;


CREATE MATERIALIZED VIEW salary_batch_summary AS
SELECT
    DATE(t.created_at) AS payment_date,
    DATE_TRUNC('month', t.created_at) AS payment_month,
    a_from.account_number AS company_account,
    c_from.full_name AS company_name,
    COUNT(*) AS total_payments,
    SUM(t.amount) AS total_amount,
    t.currency,
    SUM(t.amount_kzt) AS total_amount_kzt,
    AVG(t.amount) AS avg_payment,
    MIN(t.amount) AS min_payment,
    MAX(t.amount) AS max_payment,
    COUNT(DISTINCT t.to_account_id) AS unique_employees
FROM transactions t
JOIN accounts a_from ON t.from_account_id = a_from.account_id
JOIN customers c_from ON a_from.customer_id = c_from.customer_id
WHERE t.type = 'transfer'
  AND t.status = 'completed'
  AND t.description ILIKE '%salary%'
GROUP BY
    DATE(t.created_at),
    DATE_TRUNC('month', t.created_at),
    a_from.account_number,
    c_from.full_name,
    t.currency
ORDER BY payment_date DESC;

CREATE UNIQUE INDEX ON salary_batch_summary(payment_date, company_account, currency);


INSERT INTO customers(iin, full_name, phone, email, status, daily_limit_kzt)
VALUES ('999888777666', 'Company Tech LLP', '+77017778899', 'company@tech.kz', 'active', 100000000.00)
RETURNING customer_id;

INSERT INTO accounts(customer_id, account_number, currency, balance, is_active)
VALUES (11, 'KZ86125KZT9999999999', 'KZT', 50000000.00, true);


SELECT * FROM process_salary_batch(
    'KZ86125KZT9999999999',
    '[
        {"iin": "123456789012", "amount": 500000, "description": "December salary"},
        {"iin": "234567890123", "amount": 450000, "description": "December salary"},
        {"iin": "345678901234", "amount": 600000, "description": "December salary"},
        {"iin": "567890123456", "amount": 400000, "description": "December salary"},
        {"iin": "678901234567", "amount": 550000, "description": "December salary"}
    ]'::JSONB
);


SELECT * FROM process_salary_batch(
    'KZ86125KZT9999999999',
    '[
        {"iin": "123456789012", "amount": 300000, "description": "Bonus"},
        {"iin": "999999999999", "amount": 200000, "description": "Non-existent employee"},
        {"iin": "890123456789", "amount": 250000, "description": "Bonus"}
    ]'::JSONB
);


SELECT
    c.full_name,
    a.account_number,
    a.balance
FROM accounts a
JOIN customers c ON a.customer_id = c.customer_id
WHERE a.account_number = 'KZ86125KZT9999999999';

SELECT
    t.transaction_id,
    t.amount,
    t.description,
    t.created_at,
    c.full_name AS recipient
FROM transactions t
JOIN accounts a ON t.to_account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.from_account_id = (
    SELECT account_id FROM accounts WHERE account_number = 'KZ86125KZT9999999999'
)
ORDER BY t.created_at DESC;

REFRESH MATERIALIZED VIEW salary_batch_summary;

SELECT * FROM salary_batch_summary ORDER BY payment_date DESC;