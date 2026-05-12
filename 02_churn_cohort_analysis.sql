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