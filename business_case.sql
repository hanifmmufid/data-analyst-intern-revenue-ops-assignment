-- Business Case 1: Retention, Revenue, and Cumulative Revenue
WITH cohort AS (
    SELECT
        c.customer_id,
        MIN(DATE_TRUNC('month', t.trx_time)) AS cohort_month
    FROM 
        customer c
    JOIN
        transaction t ON c.customer_id = t.customerid
    GROUP BY 
        c.customer_id
),
monthly_activity AS (
    SELECT
        c.customer_id,
        DATE_TRUNC('month', t.trx_time) AS transaction_month, 
        SUM(t.trx_amount_usd) AS revenue 
    FROM
        customer c
    JOIN
        transaction t ON c.customer_id = t.customerid
    WHERE
        t.trx_time BETWEEN '2023-12-01' AND '2024-05-31' 
    GROUP BY 
        c.customer_id, DATE_TRUNC('month', t.trx_time)
),
cohort_activity AS (
    SELECT 
        cohort.cohort_month,
        EXTRACT(YEAR FROM monthly_activity.transaction_month) * 12 + EXTRACT(MONTH FROM monthly_activity.transaction_month) 
        - (EXTRACT(YEAR FROM cohort.cohort_month) * 12 + EXTRACT(MONTH FROM cohort.cohort_month)) AS month_after_cohort,
        COUNT(DISTINCT monthly_activity.customer_id) AS active_customers,
        SUM(monthly_activity.revenue) AS monthly_revenue
    FROM 
        cohort
    LEFT JOIN
        monthly_activity ON cohort.customer_id = monthly_activity.customer_id
    GROUP BY 
        cohort.cohort_month, month_after_cohort
),
cohort_size AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) AS total_customers
    FROM 
        cohort
    GROUP BY 
        cohort_month
)
SELECT 
    TO_CHAR(cohort_activity.cohort_month, 'FMMonth YYYY') AS cohort_month,
    cohort_activity.month_after_cohort,
    cohort_activity.active_customers,
    TO_CHAR((cohort_activity.active_customers * 100.0 / cohort_size.total_customers), 'FM990.00') || '%' AS retention_percentage, 
    TO_CHAR(cohort_activity.monthly_revenue, 'FM$999,999,990.00') AS monthly_revenue, 
    TO_CHAR(SUM(cohort_activity.monthly_revenue) OVER (PARTITION BY cohort_activity.cohort_month ORDER BY cohort_activity.month_after_cohort), 'FM$999,999,990.00') AS cumulative_revenue 
FROM 
    cohort_activity
JOIN
    cohort_size ON cohort_activity.cohort_month = cohort_size.cohort_month
ORDER BY 
    cohort_activity.cohort_month, cohort_activity.month_after_cohort;


-- Business Case 2: Customer Status by Last Transaction
-- Table 2.1
WITH last_transaction AS (
    SELECT
        c.customer_id,
        c.country,
        MAX(t.trx_time) AS last_trx_time
    FROM
        customer c
    LEFT JOIN
        transaction t
    ON
        c.customer_id = t.customerid
    GROUP BY
        c.customer_id, c.country
),
customer_status AS (
    SELECT 
        c.customer_id,
        c.country,
        CASE 
            WHEN last_trx_time < DATE '2024-06-01' - INTERVAL '3 months' THEN 'Churned'
            WHEN last_trx_time >= DATE '2024-06-01' - INTERVAL '1 month' THEN 'Active'
            ELSE 'At-Risk'
        END AS status
    FROM
        last_transaction l
    JOIN
        customer c ON c.customer_id = l.customer_id
)
SELECT
    country,
    COUNT(CASE WHEN status = 'Active' THEN 1 END) AS active_count,
    COUNT(CASE WHEN status = 'At-Risk' THEN 1 END) AS at_risk_count,
    COUNT(CASE WHEN status = 'Churned' THEN 1 END) AS churned_count
FROM
    customer_status
GROUP BY
    country
ORDER BY
    country;

-- Table 2.2
WITH last_transaction AS (
    SELECT
        c.customer_id,
        c.country,
        MAX(t.trx_time) AS last_trx_time
    FROM
        customer c
    LEFT JOIN
        transaction t
    ON
        c.customer_id = t.customerid
    GROUP BY
        c.customer_id, c.country
),
customer_status AS (
    SELECT 
        c.customer_id,
        c.country,
        CASE 
            WHEN last_trx_time < DATE '2024-06-01' - INTERVAL '3 months' THEN 'Churned'
            WHEN last_trx_time >= DATE '2024-06-01' - INTERVAL '1 month' THEN 'Active'
            ELSE 'At-Risk'
        END AS status
    FROM
        last_transaction l
    JOIN
        customer c ON c.customer_id = l.customer_id
),
teams AS (
    SELECT
        1 AS team_member, 'ID,MY,PH' AS countries_assigned
    UNION ALL
    SELECT
        2, 'SG,TH,TW'
    UNION ALL
    SELECT
        3, 'VN,MY,SG'
    UNION ALL
    SELECT
        4, 'ID,PH,TH'
    UNION ALL
    SELECT
        5, 'VN,TW,SG'
),
team_member_summary AS (
    SELECT
        t.team_member,
        t.countries_assigned,
        COUNT(CASE WHEN cs.status = 'At-Risk' THEN 1 END) AS total_at_risk_customers,
        COUNT(CASE WHEN cs.status = 'Active' THEN 1 END) AS total_active_customers
    FROM
        customer_status cs
    JOIN
        teams t ON cs.country = ANY(string_to_array(t.countries_assigned, ','))
    GROUP BY
        t.team_member, t.countries_assigned
)
SELECT
    team_member,
    countries_assigned,
    total_at_risk_customers,
    total_active_customers
FROM
    team_member_summary
ORDER BY
    team_member;				

-- Chart: Chart: Customer Status Distribution by Country
WITH last_transaction AS (
    SELECT
        c.customer_id,
        c.country,
        MAX(t.trx_time) AS last_trx_time
    FROM
        customer c
    LEFT JOIN
        transaction t
    ON
        c.customer_id = t.customerid
    GROUP BY
        c.customer_id, c.country
)
SELECT 
    c.country,
    CASE 
        WHEN last_trx_time < DATE '2024-06-01' - INTERVAL '3 months' THEN 'Churned'
        WHEN last_trx_time >= DATE '2024-06-01' - INTERVAL '1 month' THEN 'Active'
        ELSE 'At-Risk'
    END AS status,
    COUNT(c.customer_id) AS customer_count
FROM 
    last_transaction l
JOIN
    customer c ON c.customer_id = l.customer_id
GROUP BY
    c.country, status
ORDER BY 
    c.country, status;
