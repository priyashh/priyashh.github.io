# Olist E‑commerce Operations Analysis

This project looks at 100k+ orders from the Brazilian e‑commerce platform Olist.  
I wanted to see where the money comes from, how bad delivery delays really are, and what the data says about customers, sellers and reviews.

The raw money values are in BRL.  
In my charts I convert them to USD with a rough rate of 1 BRL ≈ 0.20 USD.  
This is just to make the numbers easier to read, not an official rate from Olist.

---

## What I looked at

- Which categories, states and customers bring in most of the revenue.  
- How often orders arrive late and by how many days.  
- How review scores change when delivery is early/on‑time/late.  
- How many customers buy only once vs come back again.  
- How many sellers are active and who the top sellers are.

---

## Data and tools

- Olist public e‑commerce dataset (Kaggle, 2016–2018).  
- PostgreSQL for cleaning and the main analysis queries.  
- Power BI for the model, DAX measures and dashboards.  
- Excel for small checks while cleaning.

---

## Main tables / views

- `orders`, plus a cleaned `vw_order_master` view with delivery days and delay.  
- `order_items`, `order_payments`.  
- `customers`, `sellers`.  
- `products`, `category_translation` for category‑level analysis.

---

## SQL – core queries with explanations

Most of the analysis lives in `projects/olist/project file/main_analysis.sql`.  
Below are the main queries I used and what they do.

### 1. Monthly revenue and orders

```sql
SELECT
  to_char(o.order_purchase_timestamp, 'YYYY-MM') AS year_month,
  COUNT(DISTINCT o.order_id) AS total_orders,
  ROUND(SUM(p.payment_value), 2) AS total_revenue_brl,
  ROUND(AVG(p.payment_value), 2) AS avg_order_value_brl
FROM orders o
JOIN order_payments p
  ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY to_char(o.order_purchase_timestamp, 'YYYY-MM')
ORDER BY year_month;
```

This groups delivered orders by month, so I can see how order volume, revenue and average order value move over time.

---

### 2. Top product categories

```sql
SELECT
  ct.product_category_name_english AS category,
  COUNT(DISTINCT oi.order_id) AS total_orders,
  ROUND(SUM(oi.price), 2) AS total_revenue_brl,
  ROUND(AVG(oi.price), 2) AS avg_item_price_brl,
  ROUND(AVG(oi.freight_value), 2) AS avg_freight_brl
FROM order_items oi
JOIN products pr
  ON oi.product_id = pr.product_id
JOIN category_translation ct
  ON pr.product_category_name = ct.product_category_name
JOIN orders o
  ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY ct.product_category_name_english
ORDER BY total_revenue_brl DESC
LIMIT 20;
```

This is used for the “top categories” view: which categories bring most revenue, how expensive items are, and how high the freight is.

---

### 3. Customer state analysis

```sql
SELECT
  c.customer_state,
  COUNT(DISTINCT o.order_id) AS total_orders,
  COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
  ROUND(SUM(p.payment_value), 2) AS total_revenue_brl,
  ROUND(AVG(p.payment_value), 2) AS avg_order_value_brl,
  ROUND(
    AVG(
      (o.order_delivered_customer_date::date
       - o.order_estimated_delivery_date::date)
    ),
    2
  ) AS avg_delivery_delay_days
FROM orders o
JOIN customers c
  ON o.customer_id = c.customer_id
JOIN order_payments p
  ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue_brl DESC;
```

This gives me, per state: orders, unique customers, revenue and average delay.  
It feeds the state‑level map and tables.

---

### 4. Delivery performance vs review scores

```sql
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
    WHEN delay_days BETWEEN -10 AND 0 THEN 'On time / slightly early'
    WHEN delay_days BETWEEN 0 AND 10 THEN 'Late (0-10 days)'
    WHEN delay_days BETWEEN 10 AND 30 THEN 'Late (10-30 days)'
    ELSE 'Very Late (>30 days)'
  END AS delivery_bucket,
  COUNT(*) AS order_count,
  ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM delays
JOIN order_reviews r
  ON delays.order_id = r.order_id
GROUP BY delivery_bucket
ORDER BY avg_review_score DESC;
```



---

### 5. Payment methods

```sql
SELECT
  payment_type,
  COUNT(DISTINCT order_id) AS total_orders,
  ROUND(SUM(payment_value), 2) AS total_revenue_brl,
  ROUND(AVG(payment_value), 2) AS avg_payment_brl,
  ROUND(AVG(payment_installments), 1) AS avg_installments
FROM order_payments
GROUP BY payment_type
ORDER BY total_revenue_brl DESC;
```

This shows how much volume goes through each payment method and how many installments people usually use.

---

### 6. Top sellers

```sql
SELECT
  oi.seller_id,
  s.seller_state,
  COUNT(DISTINCT oi.order_id) AS total_orders,
  ROUND(SUM(oi.price), 2) AS total_revenue_brl,
  ROUND(AVG(oi.freight_value), 2) AS avg_freight_brl,
  ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM order_items oi
JOIN sellers s
  ON oi.seller_id = s.seller_id
JOIN orders o
  ON oi.order_id = o.order_id
LEFT JOIN order_reviews r
  ON oi.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.seller_id, s.seller_state
ORDER BY total_revenue_brl DESC
LIMIT 30;
```

This is used to rank sellers by revenue and see their average reviews and freight costs.

---

### 7. Basic RFM‑style customer summary

```sql
SELECT
  c.customer_unique_id,
  COUNT(DISTINCT o.order_id) AS frequency,
  ROUND(SUM(p.payment_value), 2) AS monetary_brl,
  ROUND(
    DATE '2018-10-01'
    - MAX(o.order_purchase_timestamp::date),
    0
  ) AS recency_days
FROM orders o
JOIN customers c
  ON o.customer_id = c.customer_id
JOIN order_payments p
  ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id;
```

This gives me recency, frequency and monetary value per customer, which I use to talk about one‑time vs repeat customers.

---

## DAX measures with explanations

On top of this SQL, I created a small set of DAX measures in Power BI.  
Here are the important ones and what they do.

### Revenue and volume

- `Total Payment BRL`  
  Sum of `order_payments[payment_value]` for delivered orders.

- `Total Revenue USD`  
  `Total Payment BRL * 0.20` to convert BRL to USD.

- `Total Orders`  
  Distinct count of `orders[order_id]`.

- `Total Unique Customers`  
  Distinct count of `customers[customer_unique_id]`.

- `Total Active Sellers`  
  Distinct count of `sellers[seller_id]`.

- `Avg Order Value (USD)`  
  `Total Revenue USD / Total Orders`.

### Delivery / operations

- `Avg Delivery Days`  
  Average of `vw_order_master[total_delivery_days]`.

- `On‑Time Rate %`  
  Percentage of orders where delivery delay is 0 or less (delivered on or before estimate).

- `Late Orders`  
  Count of orders where delivery delay is greater than 0.

### Reviews

- `Avg Review Score`  
  Average of `order_reviews[review_score]`.

- `5‑Star Share %`  
  Percentage of orders with `review_score = 5`.

- `Seller Avg Review Score`  
  Average review score per seller, using a relationship between items and reviews.

### Categories and states

- `Category Revenue USD`  
  Sum of category revenue in BRL, converted to USD.

- `Category Orders`  
  Distinct count of orders per category.

- `Category Revenue Share %`  
  Category revenue divided by total category revenue.

- `Revenue by State (USD)`  
  Revenue in USD grouped by `customer_state`.

### Customer behaviour

- `Customer Order Count`  
  Number of orders per `customer_unique_id`.

- `One‑time Customers`  
  Count of customers where `Customer Order Count = 1`.

- `Repeat Customers`  
  Count of customers where `Customer Order Count > 1`.

---

## Report flow

The Power BI report (and the portfolio page) follow this rough flow:

- Summary: revenue (USD), orders, customers, sellers, average order value, top categories and states.  
- Delivery: average delivery days, on‑time rate, late orders, breakdown by state.  
- Reviews: score distribution, 5‑star share, seller review comparison, effect of delay.  
- Customers: one‑time vs repeat customers, plus a simple RFM‑style view.

