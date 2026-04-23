--Monthly Revenue & Order Count

select to_char(o.order_purchase_timestamp, 'YYYY-MM') as year_month,
Count(Distinct o.order_id) as total_orders,
	Round(Sum(p.payment_value),2) as total_revenue,
	Round (avg(p.payment_value),2) as avg_order_value
From Orders o
Join Order_payments p
on o.order_id = p.order_id
Where o.order_status = 'delivered' 
group by to_char(o.order_purchase_timestamp, 'YYYY-MM')
order by year_month;


-- Top 20 Product Categories by Revenue (PostgreSQL)

SELECT ct.product_category_name_english AS category,
    COUNT(DISTINCT oi.order_id)      AS total_orders,
    ROUND(SUM(oi.price), 2)          AS total_revenue,
    ROUND(AVG(oi.price), 2)          AS avg_item_price,
    ROUND(AVG(oi.freight_value), 2)  AS avg_freight
FROM order_items oi
JOIN products pr
    ON oi.product_id = pr.product_id
JOIN category_translation ct
    ON pr.product_category_name = ct.product_category_name
JOIN orders o
    ON oi.order_id = o.order_id
WHERE
    o.order_status = 'delivered'
GROUP BY
    ct.product_category_name_english
ORDER BY
    total_revenue DESC
LIMIT 20;

-- Customer State Analysis (PostgreSQL)

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id)                    AS total_orders,
    COUNT(DISTINCT c.customer_unique_id)          AS unique_customers,
    ROUND(SUM(p.payment_value), 2)                AS total_revenue,
    ROUND(AVG(p.payment_value), 2)                AS avg_order_value,
    ROUND(AVG(
        (o.order_delivered_customer_date::date
         - o.order_estimated_delivery_date::date)
    ), 2)                                         AS avg_delivery_delay_days
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN order_payments p
    ON o.order_id = p.order_id
WHERE
    o.order_status = 'delivered'
GROUP BY
    c.customer_state
ORDER BY
    total_revenue DESC;


-- Delivery Performance vs Review Score (PostgreSQL)

WITH delays AS (
    SELECT
        o.order_id,
        (o.order_delivered_customer_date::date
         - o.order_estimated_delivery_date::date) AS delay_days
    FROM orders o
    WHERE
        o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
    CASE
        WHEN delay_days < -30 THEN 'Very Early (>30d ahead)'
        WHEN delay_days BETWEEN -30 AND -10 THEN 'Early (10-30d ahead)'
        WHEN delay_days BETWEEN -10 AND 0 THEN 'On Time (~0)'
        WHEN delay_days BETWEEN 0 AND 10 THEN 'Late (0-10 days)'
        WHEN delay_days BETWEEN 10 AND 30 THEN 'Late (10-30 days)'
        ELSE 'Very Late (>30 days)'
    END                                           AS delivery_bucket,
    COUNT(*)                                      AS order_count,
    ROUND(AVG(r.review_score), 2)                AS avg_review_score
FROM delays
JOIN order_reviews r
    ON delays.order_id = r.order_id
GROUP BY
    delivery_bucket
ORDER BY
    avg_review_score DESC;


-- Payment Method Analysis (PostgreSQL)

SELECT
    payment_type,
    COUNT(DISTINCT order_id)                             AS total_orders,
    ROUND(SUM(payment_value), 2)                         AS total_revenue,
    ROUND(AVG(payment_value), 2)                         AS avg_payment,
    ROUND(AVG(payment_installments), 1)                  AS avg_installments,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS payment_share_pct
FROM order_payments
GROUP BY
    payment_type
ORDER BY
    total_revenue DESC;


--Top 30 Sellers by Revenue with Review Score (PostgreSQL)

SELECT
    oi.seller_id,
    s.seller_state,
    COUNT(DISTINCT oi.order_id)           AS total_orders,
    ROUND(SUM(oi.price), 2)               AS total_revenue,
    ROUND(AVG(oi.freight_value), 2)       AS avg_freight,
    ROUND(AVG(r.review_score), 2)         AS avg_review_score
FROM order_items oi
JOIN sellers s
    ON oi.seller_id = s.seller_id
JOIN orders o
    ON oi.order_id = o.order_id
LEFT JOIN order_reviews r
    ON oi.order_id = r.order_id
WHERE
    o.order_status = 'delivered'
GROUP BY
    oi.seller_id,
    s.seller_state
ORDER BY
    total_revenue DESC
LIMIT 30;


--Order Status Breakdown (PostgreSQL)

SELECT
    order_status,
    COUNT(*)                                                   AS count,
    ROUND(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders),
        2
    )                                                          AS pct
FROM orders
GROUP BY
    order_status
ORDER BY
    count DESC;


--Average Delivery Time by Seller State (PostgreSQL)

SELECT
    s.seller_state,
    COUNT(DISTINCT o.order_id)                                AS orders,
    ROUND(
        AVG(
            o.order_delivered_customer_date::date
          - o.order_purchase_timestamp::date
        ),
        1
    )                                                         AS avg_total_delivery_days,
    ROUND(
        AVG(
            o.order_delivered_customer_date::date
          - o.order_estimated_delivery_date::date
        ),
        1
    )                                                         AS avg_delay_vs_estimate
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE
    o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY
    s.seller_state
ORDER BY
    avg_delay_vs_estimate ASC;


-- RFM Segmentation (PostgreSQL)
-- Reference date chosen as 2018-10-01 to match guide

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id)                                 AS frequency,
    ROUND(SUM(p.payment_value), 2)                             AS monetary,
    ROUND(
        DATE '2018-10-01'
      - MAX(o.order_purchase_timestamp::date),
        0
    )                                                          AS recency_days
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN order_payments p
    ON o.order_id = p.order_id
WHERE
    o.order_status = 'delivered'
GROUP BY
    c.customer_unique_id
ORDER BY
    monetary DESC
LIMIT 100;



