USE NovaCRM;
GO

-- First-touch and last-touch attribution
WITH ordered_touches AS (
    SELECT
        mt.customer_id,
        mt.channel,
        mt.touchpoint_date,
        mt.cost,
        c.signup_date,
        ROW_NUMBER() OVER (PARTITION BY mt.customer_id ORDER BY mt.touchpoint_date ASC) AS touch_rank_asc,
        ROW_NUMBER() OVER (PARTITION BY mt.customer_id ORDER BY mt.touchpoint_date DESC) AS touch_rank_desc
    FROM marketing_touchpoints mt
    INNER JOIN customers c ON mt.customer_id = c.customer_id
),
customer_revenue AS (
    SELECT
        customer_id,
        SUM(amount) AS total_revenue
    FROM revenue_events
    GROUP BY customer_id
)
SELECT
    'First Touch' AS model,
    ot.channel,
    COUNT(DISTINCT ot.customer_id) AS attributed_customers,
    SUM(cr.total_revenue) AS attributed_revenue
FROM ordered_touches ot
INNER JOIN customer_revenue cr ON ot.customer_id = cr.customer_id
WHERE ot.touch_rank_asc = 1
GROUP BY ot.channel

UNION ALL

SELECT
    'Last Touch' AS model,
    ot.channel,
    COUNT(DISTINCT ot.customer_id) AS attributed_customers,
    SUM(cr.total_revenue) AS attributed_revenue
FROM ordered_touches ot
INNER JOIN customer_revenue cr ON ot.customer_id = cr.customer_id
WHERE ot.touch_rank_desc = 1
GROUP BY ot.channel
ORDER BY model, attributed_revenue DESC;
GO

-- Linear attribution (equal weight)
WITH touch_counts AS (
    SELECT
        customer_id,
        COUNT(*) AS total_touches
    FROM marketing_touchpoints
    GROUP BY customer_id
),
linear_attribution AS (
    SELECT
        mt.customer_id,
        mt.channel,
        1.0 / tc.total_touches AS attribution_weight
    FROM marketing_touchpoints mt
    INNER JOIN touch_counts tc ON mt.customer_id = tc.customer_id
),
customer_revenue AS (
    SELECT
        customer_id,
        SUM(amount) AS total_revenue
    FROM revenue_events
    GROUP BY customer_id
)
SELECT
    la.channel,
    SUM(la.attribution_weight) AS weighted_conversions,
    SUM(la.attribution_weight * cr.total_revenue) AS attributed_revenue
FROM linear_attribution la
INNER JOIN customer_revenue cr ON la.customer_id = cr.customer_id
GROUP BY la.channel
ORDER BY attributed_revenue DESC;
GO