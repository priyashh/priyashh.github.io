# Olist E‑commerce Operations Analysis

This project looks at 100k+ orders from the Brazilian e‑commerce platform Olist.  
I wanted to see where the money really comes from, how bad delivery delays are, and what the data says about customers, sellers and reviews.

The raw money values are in BRL.  
In the report I convert them to USD with a rough rate of 1 BRL ≈ 0.20 USD just to make the numbers easier to read. This is a project assumption, not an official Olist rate.

---

## What I focused on

- Which categories, states and customers drive most of the revenue.  
- How often orders are late and by how many days.  
- How review scores change when delivery is early / on time / late.  
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

- `orders` + a cleaned view `vw_order_master` with delivery days and delay.  
- `order_items`, `order_payments`.  
- `customers`, `sellers`.  
- `products`, `category_translation` for category analysis.

---

## SQL – core queries with explanations

Most of the analysis SQL is in:

`projects/olist/project file/main_analysis.sql`.[page:86]

Here are the main queries I use and what they do (simplified):

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

Groups delivered orders by month so I can see how volume, revenue and average order value move over time.[page:86]

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

Used for the “top categories” view: which categories bring the most revenue, and what their average item and freight costs look like.[page:86]

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

Per state: orders, unique customers, revenue and average delay. This feeds the state‑level map and tables.[page:86]

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

Buckets orders by how early/late they were and compares average review scores for each bucket (logistics vs satisfaction).[page:86]

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

Shows how much volume each payment method handles and the typical number of installments.[page:86]

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

Ranks sellers by revenue and shows their average freight cost and review score.[page:86]

---

### 7. RFM‑style customer summary

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

Basic RFM metrics (recency, frequency, monetary) per customer, used to support the one‑time vs repeat customer story.[page:86]

---

## DAX measures – with formulas and short notes

On top of this SQL, I created a small set of DAX measures in Power BI.  
These are the ones that actually show up in the final report.

### Revenue and volume

```DAX
Total Payment BRL =
SUM ( 'public order_payments'[payment_value] )
```

Sum of payment value for delivered orders (in BRL).

```DAX
Total Revenue USD =
[Total Payment BRL] * 0.20
```

Total payment converted from BRL to USD using the 0.20 rate.

```DAX
Total Orders =
DISTINCTCOUNT ( 'public orders'[order_id] )
```

Distinct orders.

```DAX
Total Unique Customers =
DISTINCTCOUNT ( 'public customers'[customer_unique_id] )
```

Distinct customers.

```DAX
Total Active Sellers =
DISTINCTCOUNT ( 'public sellers'[seller_id] )
```

Distinct sellers.

```DAX
Avg Order Value (USD) =
DIVIDE ( [Total Revenue USD], [Total Orders] )
```

Average revenue per order in USD.

```DAX
Revenue by State USD =
SUM ( 'public vw_order_master'[total_payment] ) * 0.20
```

Revenue per state in USD.

---

### Delivery and operations

```DAX
Avg Delivery Days =
AVERAGE ( 'public vw_order_master'[total_delivery_days] )
```

Average days from purchase to delivery.

```DAX
On-Time Rate % =
DIVIDE (
    COUNTROWS (
        FILTER (
            'public vw_order_master',
            'public vw_order_master'[delivery_delay_days] <= 0
        )
    ),
    COUNTROWS ( 'public vw_order_master' )
)
```

Percentage of orders delivered on or before the estimated date.

```DAX
Late Orders =
COUNTROWS (
    FILTER (
        'public vw_order_master',
        'public vw_order_master'[delivery_delay_days] > 0
    )
)
```

Number of late orders.

---

### Reviews and satisfaction

```DAX
Avg Review Score =
AVERAGE ( 'public order_reviews'[review_score] )
```

Average review score (1–5).

```DAX
5-Star Share % =
DIVIDE (
    COUNTROWS (
        FILTER (
            'public order_reviews',
            'public order_reviews'[review_score] = 5
        )
    ),
    COUNTROWS ( 'public order_reviews' )
)
```

Share of orders with a 5‑star review.

```DAX
Seller Avg Review Score =
CALCULATE (
    AVERAGE ( 'public order_reviews'[review_score] ),
    TREATAS (
        VALUES ( 'public order_items'[order_id] ),
        'public order_reviews'[order_id]
    )
)
```

Average review score per seller.

---

### Categories and states

```DAX
Category Revenue USD =
SUM ( 'public vw_category_revenue'[price] ) * 0.20
```

Revenue per product category in USD.

```DAX
Category Orders =
DISTINCTCOUNT ( 'public vw_category_revenue'[order_id] )
```

Orders per category.

```DAX
Total Revenue All Categories =
CALCULATE (
    [Category Revenue USD],
    ALL ( 'public vw_category_revenue'[category] )
)
```

Total revenue across all categories.

```DAX
Category Revenue Share % =
DIVIDE ( [Category Revenue USD], [Total Revenue All Categories] )
```

Share of total revenue for each category.

---

### Customer behaviour

```DAX
Customer Order Count =
CALCULATE (
    DISTINCTCOUNT ( 'public orders'[order_id] ),
    ALLEXCEPT ( 'public customers', 'public customers'[customer_unique_id] )
)
```

Orders per unique customer.

```DAX
One-time Customers =
CALCULATE (
    DISTINCTCOUNT ( 'public customers'[customer_unique_id] ),
    FILTER (
        VALUES ( 'public customers'[customer_unique_id] ),
        CALCULATE ( DISTINCTCOUNT ( 'public orders'[order_id] ) ) = 1
    )
)
```

Customers with exactly one order.

```DAX
Repeat Customers =
CALCULATE (
    DISTINCTCOUNT ( 'public customers'[customer_unique_id] ),
    FILTER (
        VALUES ( 'public customers'[customer_unique_id] ),
        CALCULATE ( DISTINCTCOUNT ( 'public orders'[order_id] ) ) > 1
    )
)
```

Customers with more than one order.

---

## Report flow

The Power BI report (and the portfolio page) roughly follow this flow:

- Summary: revenue (USD), orders, customers, sellers, average order value, top categories and states.[page:69]  
- Delivery: average delivery days, on‑time rate, late orders, breakdown by state.[page:69]  
- Reviews: score distribution, 5‑star share, seller review comparison, impact of delay.[page:69]  
- Customers: one‑time vs repeat customers plus a simple RFM‑style view.[page:69]
