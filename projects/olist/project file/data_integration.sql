Create table orders (order_id TEXT PRIMARY KEY,
customer_id TEXT,order_status TEXT, order_purchase_timestamp      TIMESTAMPTZ,
order_approved_at TIMESTAMPTZ, order_delivered_carrier_date  TIMESTAMPTZ,
order_delivered_customer_date TIMESTAMPTZ, order_estimated_delivery_date TIMESTAMPTZ);

Create table order_items (order_id TEXT,order_item_id INTEGER,
product_id TEXT, seller_id TEXT, shipping_limit_date TIMESTAMPTZ,
price NUMERIC(10,2),freight_value NUMERIC(10,2));

Create table order_payments (order_id TEXT,payment_sequential INTEGER,payment_type TEXT, 
payment_installments INTEGER, payment_value NUMERIC(10,2));

Create table customers (customer_id TEXT PRIMARY KEY, customer_unique_id TEXT,
customer_zip_code_prefix INTEGER, customer_city TEXT, customer_state TEXT);

Create table sellers (seller_id TEXT PRIMARY KEY,
seller_zip_code_prefix INTEGER,seller_city TEXT, seller_state TEXT);

Create table products (product_id TEXT PRIMARY KEY, product_category_name TEXT,
product_name_lenght REAL, product_description_lenght REAL,product_photos_qty REAL,product_weight_g REAL,
product_length_cm REAL, product_height_cm REAL,product_width_cm REAL);

Create table order_reviews (review_id TEXT, order_id TEXT, review_score INTEGER, review_comment_title TEXT,
review_comment_message TEXT, review_creation_date TIMESTAMPTZ, review_answer_timestamp TIMESTAMPTZ);

Create table category_translation (product_category_name TEXT PRIMARY KEY,
product_category_name_english TEXT);


CREATE TABLE geolocation (geolocation_zip_code_prefix INTEGER, geolocation_lat DECIMAL(10,8),
geolocation_lng DECIMAL(11,8), geolocation_city TEXT, geolocation_state VARCHAR(2));

-- Index

Create index idx_orders_customer 
ON orders(customer_id);

Create index idx_orders_status 
ON orders(order_status);

Create index idx_items_order 
ON order_items(order_id);

Create index idx_items_product 
ON order_items(product_id);

Create index idx_items_seller 
ON order_items(seller_id);

Create index idx_payments_order 
ON order_payments(order_id);

Create index idx_reviews_order 
ON order_reviews(order_id);

Create index idx_products_cat 
ON products(product_category_name);

Create index idx_geo_zip 
ON geolocation(geolocation_zip_code_prefix);

--
CREATE OR REPLACE VIEW vw_order_master AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_state,
    c.customer_city,
    o.order_status,
    to_char(o.order_purchase_timestamp, 'YYYY-MM') AS year_month,
    EXTRACT(YEAR  FROM o.order_purchase_timestamp) AS year,
    EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    ROUND(
        (
            o.order_delivered_customer_date::date
          - o.order_estimated_delivery_date::date
        )::numeric,
        1
    ) AS delivery_delay_days,
    ROUND(
        (
            o.order_delivered_customer_date::date
          - o.order_purchase_timestamp::date
        )::numeric,
        1
    ) AS total_delivery_days,
    p.total_payment,
    p.payment_type,
    p.payment_installments
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN (
    SELECT
        order_id,
        SUM(payment_value)          AS total_payment,
        MAX(payment_installments)   AS payment_installments,
        MAX(payment_type)           AS payment_type
    FROM order_payments
    GROUP BY order_id
) p
    ON o.order_id = p.order_id;




--


CREATE OR REPLACE VIEW vw_order_master AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_state,
    c.customer_city,
    o.order_status,
    to_char(o.order_purchase_timestamp, 'YYYY-MM') AS year_month,
    EXTRACT(YEAR  FROM o.order_purchase_timestamp) AS year,
    EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    ROUND(
        (
            o.order_delivered_customer_date::date
          - o.order_estimated_delivery_date::date
        )::numeric,
        1
    ) AS delivery_delay_days,
    ROUND(
        (
            o.order_delivered_customer_date::date
          - o.order_purchase_timestamp::date
        )::numeric,
        1
    ) AS total_delivery_days,
    p.total_payment,
    p.payment_type,
    p.payment_installments
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN (
    SELECT
        order_id,
        SUM(payment_value)          AS total_payment,
        MAX(payment_installments)   AS payment_installments,
        MAX(payment_type)           AS payment_type
    FROM order_payments
    GROUP BY order_id
) p
    ON o.order_id = p.order_id;
---
CREATE OR REPLACE VIEW vw_category_revenue AS
SELECT
    ct.product_category_name_english AS category,
    oi.order_id,
    oi.price,
    oi.freight_value,
    o.order_status,
    o.order_purchase_timestamp,
    c.customer_state,
    s.seller_state
FROM order_items oi
JOIN products pr
    ON oi.product_id = pr.product_id
JOIN category_translation ct
    ON pr.product_category_name = ct.product_category_name
JOIN orders o
    ON oi.order_id = o.order_id
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN sellers s
    ON oi.seller_id = s.seller_id;



