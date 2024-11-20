-- Query 1: Count the number of customers per country
SELECT country, COUNT(DISTINCT customer_id) AS unique_customers
FROM customer
GROUP BY country
ORDER BY unique_customers DESC;

-- Query 2: Count the number of transactions per country
SELECT 
    c.country, 
    COUNT(t.trxid) AS transaction_count
FROM 
    transaction t
JOIN 
    customer c
ON 
    t.customerid = c.customer_id
GROUP BY 
    c.country
ORDER BY 
    transaction_count DESC;

-- Query 3: Find the first transaction date of each customer
SELECT 
    t.customerid,
    MIN(t.trx_time) AS first_transaction_date
FROM 
    transaction t
GROUP BY 
    t.customerid
ORDER BY 
    first_transaction_date;

-- Query 4: Find the number of customers who made their first transaction in each country, each day
WITH first_transactions AS (
    SELECT 
        t.customerid,
        MIN(t.trx_time) AS first_transaction_date
    FROM 
        transaction t
    GROUP BY 
        t.customerid
)
SELECT 
    c.country,
    ft.first_transaction_date,
    COUNT(ft.customerid) AS customer_count
FROM 
    first_transactions ft
JOIN 
    customer c
ON 
    ft.customerid = c.customer_id
GROUP BY 
    c.country, ft.first_transaction_date
ORDER BY 
    c.country, ft.first_transaction_date;

-- Query 5: Find the first order's trx_amount_usd of each customer. If there is a tie, use the transaction with the lower trxid
WITH first_transactions AS (
    SELECT 
        t.customerid,
        MIN(t.trx_time) AS first_transaction_date
    FROM 
        transaction t
    GROUP BY 
        t.customerid
),
tied_transactions AS (
    SELECT 
        t.customerid,
        t.trxid,
        t.trx_amount_usd,
        t.trx_time
    FROM 
        transaction t
    JOIN 
        first_transactions ft
    ON 
        t.customerid = ft.customerid
        AND t.trx_time = ft.first_transaction_date
)
SELECT 
    tt.customerid,
    tt.trx_amount_usd
FROM 
    tied_transactions tt
WHERE 
    tt.trxid = (
        SELECT 
            MIN(t2.trxid)
        FROM 
            tied_transactions t2
        WHERE 
            t2.customerid = tt.customerid
    )
ORDER BY 
    tt.customerid;
