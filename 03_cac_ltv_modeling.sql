USE NovaCRM;
GO

-- CAC by channel
WITH channel_spend AS (
    SELECT
        mt.channel,
        DATEFROMPARTS(YEAR(c.signup_date), MONTH(c.signup_date), 1) AS acquisition_month,
        SUM(mt.cost) AS total_spend,
        COUNT(DISTINCT c.customer_id) AS customers_acquired
    FROM marketing_touchpoints mt
    INNER JOIN customers c ON mt.customer_id = c.customer_id
    GROUP BY mt.channel, DATEFROMPARTS(YEAR(c.signup_date), MONTH(c.signup_date), 1)
)
SELECT
    channel,
    acquisition_month,
    total_spend,
    customers_acquired,
    CASE
        WHEN customers_acquired > 0 THEN total_spend / customers_acquired
        ELSE 0
    END AS cac
FROM channel_spend
ORDER BY channel, acquisition_month;
GO

-- Customer LTV with cumulative revenue
WITH customer_ltv AS (
    SELECT
        c.customer_id,
        c.plan_tier,
        c.signup_date,
        DATEFROMPARTS(YEAR(c.signup_date), MONTH(c.signup_date), 1) AS cohort_month,
        SUM(re.amount) AS total_revenue,
        COUNT(re.event_id) AS payment_count,
        DATEDIFF(MONTH, c.signup_date, ISNULL(c.churn_date, '2024-06-30')) AS months_active
    FROM customers c
    LEFT JOIN revenue_events re ON c.customer_id = re.customer_id
    GROUP BY c.customer_id, c.plan_tier, c.signup_date, c.churn_date
)
SELECT
    plan_tier,
    COUNT(*) AS customer_count,
    AVG(total_revenue) AS avg_ltv,
    AVG(months_active) AS avg_lifetime_months,
    AVG(CASE WHEN months_active > 0 THEN total_revenue / months_active ELSE 0 END) AS avg_monthly_value
FROM customer_ltv
GROUP BY plan_tier
ORDER BY avg_ltv DESC;
GO

-- LTV by acquisition channel
-- CAC:LTV Ratio by channel with health flag
CREATE OR ALTER VIEW vw_unit_economics AS
WITH cac_by_channel AS (
    SELECT
        mt.channel,
        SUM(mt.cost) AS total_spend,
        COUNT(DISTINCT mt.customer_id) AS customers_acquired,
        CASE
            WHEN COUNT(DISTINCT mt.customer_id) > 0
            THEN SUM(mt.cost) / COUNT(DISTINCT mt.customer_id)
            ELSE 0
        END AS cac
    FROM marketing_touchpoints mt
    GROUP BY mt.channel
),
ltv_by_channel AS (
    SELECT
        mt.channel,
        AVG(cltv.total_revenue) AS avg_ltv
    FROM (
        SELECT
            c.customer_id,
            SUM(re.amount) AS total_revenue
        FROM customers c
        INNER JOIN revenue_events re ON c.customer_id = re.customer_id
        GROUP BY c.customer_id
    ) cltv
    INNER JOIN marketing_touchpoints mt ON cltv.customer_id = mt.customer_id
    GROUP BY mt.channel
)
SELECT
    cac.channel,
    cac.total_spend,
    cac.customers_acquired,
    cac.cac,
    ltv.avg_ltv,
    CASE WHEN cac.cac > 0 THEN ltv.avg_ltv / cac.cac ELSE 0 END AS ltv_cac_ratio,
    CASE
        WHEN cac.cac > 0 AND ltv.avg_ltv / cac.cac >= 3 THEN 'Healthy'
        WHEN cac.cac > 0 AND ltv.avg_ltv / cac.cac >= 1 THEN 'Warning'
        ELSE 'Unhealthy'
    END AS health_status
FROM cac_by_channel cac
LEFT JOIN ltv_by_channel ltv ON cac.channel = ltv.channel;
GO