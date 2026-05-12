USE NovaCRM;
GO

-- Monthly cohort retention analysis
WITH cohorts AS (
    SELECT
        customer_id,
        DATEFROMPARTS(YEAR(signup_date), MONTH(signup_date), 1) AS cohort_month,
        plan_tier,
        signup_date,
        churn_date,
        is_churned
    FROM customers
),
retention AS (
    SELECT
        c.cohort_month,
        c.plan_tier,
        COUNT(*) AS cohort_size,
        COUNT(CASE WHEN DATEDIFF(MONTH, c.signup_date, ISNULL(c.churn_date, '2024-06-30')) >= 1 THEN 1 END) AS retained_m1,
        COUNT(CASE WHEN DATEDIFF(MONTH, c.signup_date, ISNULL(c.churn_date, '2024-06-30')) >= 3 THEN 1 END) AS retained_m3,
        COUNT(CASE WHEN DATEDIFF(MONTH, c.signup_date, ISNULL(c.churn_date, '2024-06-30')) >= 6 THEN 1 END) AS retained_m6,
        COUNT(CASE WHEN DATEDIFF(MONTH, c.signup_date, ISNULL(c.churn_date, '2024-06-30')) >= 12 THEN 1 END) AS retained_m12
    FROM cohorts c
    GROUP BY c.cohort_month, c.plan_tier
)
SELECT
    cohort_month,
    plan_tier,
    cohort_size,
    CAST(retained_m1 AS FLOAT) / cohort_size * 100 AS retention_pct_m1,
    CAST(retained_m3 AS FLOAT) / cohort_size * 100 AS retention_pct_m3,
    CAST(retained_m6 AS FLOAT) / cohort_size * 100 AS retention_pct_m6,
    CAST(retained_m12 AS FLOAT) / cohort_size * 100 AS retention_pct_m12
FROM retention
ORDER BY cohort_month, plan_tier;
GO

-- Churn acceleration using LAG
WITH monthly_churn AS (
    SELECT
        DATEFROMPARTS(YEAR(churn_date), MONTH(churn_date), 1) AS churn_month,
        plan_tier,
        COUNT(*) AS churned_count
    FROM customers
    WHERE is_churned = 1 AND churn_date IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(churn_date), MONTH(churn_date), 1), plan_tier
)
SELECT
    churn_month,
    plan_tier,
    churned_count,
    LAG(churned_count) OVER (PARTITION BY plan_tier ORDER BY churn_month) AS prev_month_churn,
    churned_count - LAG(churned_count) OVER (PARTITION BY plan_tier ORDER BY churn_month) AS churn_acceleration
FROM monthly_churn
ORDER BY plan_tier, churn_month;
GO

-- Create view for Power BI
CREATE OR ALTER VIEW vw_cohort_retention AS
WITH cohorts AS (
    SELECT
        customer_id,
        DATEFROMPARTS(YEAR(signup_date), MONTH(signup_date), 1) AS cohort_month,
        plan_tier,
        signup_date,
        churn_date,
        is_churned
    FROM customers
),
months AS (
    SELECT DISTINCT DATEFROMPARTS(YEAR(signup_date), MONTH(signup_date), 1) AS cohort_month
    FROM customers
),
periods AS (
    SELECT value AS months_since_signup
    FROM GENERATE_SERIES(0, 18)
)
SELECT
    c.cohort_month,
    p.months_since_signup,
    c.plan_tier,
    COUNT(*) AS cohort_size,
    COUNT(CASE
        WHEN DATEDIFF(MONTH, c.signup_date, ISNULL(c.churn_date, '2024-06-30')) >= p.months_since_signup
        THEN 1
    END) AS retained_count,
    CAST(COUNT(CASE
        WHEN DATEDIFF(MONTH, c.signup_date, ISNULL(c.churn_date, '2024-06-30')) >= p.months_since_signup
        THEN 1
    END) AS FLOAT) / COUNT(*) * 100 AS retention_pct
FROM cohorts c
CROSS JOIN periods p
GROUP BY c.cohort_month, p.months_since_signup, c.plan_tier;
GO