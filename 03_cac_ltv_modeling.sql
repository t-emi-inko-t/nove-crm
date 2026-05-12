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