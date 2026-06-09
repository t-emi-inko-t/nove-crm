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

-- Time-decay attribution
CREATE OR ALTER VIEW vw_attribution_comparison AS
WITH customer_revenue AS (
    SELECT customer_id, SUM(amount) AS total_revenue
    FROM revenue_events
    GROUP BY customer_id
),
touch_with_decay AS (
    SELECT
        mt.customer_id,
        mt.channel,
        mt.touchpoint_date,
        c.signup_date,
        DATEDIFF(DAY, mt.touchpoint_date, c.signup_date) AS days_before_conversion,
        -- Time decay: more recent = higher weight
        POWER(0.5, CAST(DATEDIFF(DAY, mt.touchpoint_date, c.signup_date) AS FLOAT) / 7.0) AS decay_weight
    FROM marketing_touchpoints mt
    INNER JOIN customers c ON mt.customer_id = c.customer_id
),
normalized_decay AS (
    SELECT
        customer_id,
        channel,
        decay_weight / SUM(decay_weight) OVER (PARTITION BY customer_id) AS normalized_weight
    FROM touch_with_decay
),
-- First touch
first_touch AS (
    SELECT customer_id, channel,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY touchpoint_date ASC) AS rn
    FROM marketing_touchpoints
),
-- Last touch
last_touch AS (
    SELECT customer_id, channel,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY touchpoint_date DESC) AS rn
    FROM marketing_touchpoints
),
-- Linear
touch_counts AS (
    SELECT customer_id, COUNT(*) AS total_touches
    FROM marketing_touchpoints
    GROUP BY customer_id
)
SELECT 'First Touch' AS attribution_model, ft.channel,
    SUM(cr.total_revenue) AS attributed_revenue,
    COUNT(DISTINCT ft.customer_id) AS attributed_customers
FROM first_touch ft
INNER JOIN customer_revenue cr ON ft.customer_id = cr.customer_id
WHERE ft.rn = 1
GROUP BY ft.channel

UNION ALL

SELECT 'Last Touch', lt.channel,
    SUM(cr.total_revenue),
    COUNT(DISTINCT lt.customer_id)
FROM last_touch lt
INNER JOIN customer_revenue cr ON lt.customer_id = cr.customer_id
WHERE lt.rn = 1
GROUP BY lt.channel

UNION ALL

SELECT 'Linear', mt.channel,
    SUM(cr.total_revenue * (1.0 / tc.total_touches)),
    CAST(SUM(1.0 / tc.total_touches) AS INT)
FROM marketing_touchpoints mt
INNER JOIN customer_revenue cr ON mt.customer_id = cr.customer_id
INNER JOIN touch_counts tc ON mt.customer_id = tc.customer_id
GROUP BY mt.channel

UNION ALL

SELECT 'Time Decay', nd.channel,
    SUM(cr.total_revenue * nd.normalized_weight),
    CAST(SUM(nd.normalized_weight) AS INT)
FROM normalized_decay nd
INNER JOIN customer_revenue cr ON nd.customer_id = cr.customer_id
GROUP BY nd.channel;
GO