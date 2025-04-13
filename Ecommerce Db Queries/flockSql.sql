-- 1. Lifetime Value of a User
SELECT u.user_id, u.name, u.email, SUM(o.total_amount) AS lifetime_value FROM Users u JOIN Orders o ON u.user_id = o.user_id GROUP BY u.user_id, u.name, u.email ORDER BY lifetime_value DESC LIMIT 10;


-- 2. Product Popularity Over Time
SELECT p.product_id, p.name AS product_name, DATE_FORMAT(o.order_date, '%Y-%m-01') AS sale_month, SUM(oi.quantity) AS total_quantity_sold FROM OrderItems oi JOIN Orders o ON oi.order_id = o.order_id JOIN Products p ON oi.product_id = p.product_id WHERE o.order_date >= CURDATE() - INTERVAL 1 YEAR GROUP BY p.product_id, p.name, DATE_FORMAT(o.order_date, '%Y-%m-01') ORDER BY p.product_id, sale_month;

-- 3. Customer Retention Rate
WITH user_months AS (
    SELECT 
        DISTINCT user_id,
        DATE_FORMAT(order_date, '%Y-%m') AS order_month
    FROM Orders
    WHERE order_date >= CURDATE() - INTERVAL 1 YEAR
),

retention AS (
    SELECT 
        curr.order_month AS month,
        COUNT(DISTINCT curr.user_id) AS current_month_users,
        COUNT(DISTINCT prev.user_id) AS retained_users
    FROM user_months curr
    LEFT JOIN user_months prev 
        ON curr.user_id = prev.user_id
        AND DATE_FORMAT(DATE_ADD(prev.order_month, INTERVAL 1 MONTH), '%Y-%m') = curr.order_month
    GROUP BY curr.order_month
)

SELECT 
    month,
    ROUND((retained_users / NULLIF(current_month_users, 0)) * 100, 2) AS retention_rate_percentage
FROM retention
ORDER BY month;


-- 4. Average Order Value and Order Frequency by User Segment
WITH user_orders AS (
    SELECT 
        user_id,
        SUM(total_amount) AS lifetime_value,
        COUNT(*) AS total_orders,
        TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) + 1 AS active_months
    FROM Orders
    GROUP BY user_id
),

ranked_users AS (
    SELECT 
        user_id,
        lifetime_value,
        total_orders,
        active_months,
        NTILE(10) OVER (ORDER BY lifetime_value) AS decile
    FROM user_orders
),

segmented_users AS (
    SELECT 
        user_id,
        lifetime_value,
        total_orders,
        active_months,
        CASE
            WHEN decile <= 3 THEN 'Low Spenders'
            WHEN decile <= 7 THEN 'Medium Spenders'
            ELSE 'High Spenders'
        END AS segment
    FROM ranked_users
)

SELECT 
    segment,
    ROUND(AVG(lifetime_value / total_orders), 2) AS avg_order_value,
    ROUND(AVG(total_orders / active_months), 2) AS avg_orders_per_month
FROM segmented_users
GROUP BY segment;


-- 5. Conversion Rate of Marketing Campaigns
SELECT
    mc.campaign_id,
    mc.campaign_name,
    ROUND(
        COUNT(DISTINCT o.user_id) / COUNT(DISTINCT mc.user_id) * 100,
        2
    ) AS conversion_rate
FROM MarketingCampaigns mc
LEFT JOIN Orders o 
    ON mc.user_id = o.user_id
    AND o.order_date BETWEEN mc.campaign_start_date AND mc.campaign_end_date
GROUP BY mc.campaign_id, mc.campaign_name;
