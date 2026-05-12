-- Quick row count check
USE NovaCRM;
SELECT
    (SELECT COUNT(*) FROM customers) AS customer_count,
    (SELECT COUNT(*) FROM subscriptions) AS subscription_count,
    (SELECT COUNT(*) FROM marketing_touchpoints) AS touchpoint_count,
    (SELECT COUNT(*) FROM revenue_events) AS revenue_count;