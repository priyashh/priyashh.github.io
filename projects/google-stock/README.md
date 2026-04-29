# Google Stock Price Trend & Volatility Analysis

This project takes 21+ years of Google / Alphabet data and turns it into a Power BI dashboard.  
I wanted to see how the stock actually behaved over time (returns, crashes, volatility) and how that lines up with revenue growth, segment mix and basic financial health.

The data runs from 2004 to 2025.  
On the main page I highlight things like the latest price (around $359), revenue CAGR (about 25.6%), 2025 revenue (around $385B) and net profit margin (roughly 23.6%).

---

## What I focused on

- Long‑term stock performance and compounding.  
- Volatility and big drawdowns (how bad the crashes were).  
- Revenue and earnings growth over time.  
- How much comes from Search vs YouTube vs Cloud vs other segments.  
- Margins, cash flow and simple ratios like ROE / ROA.

---

## Data and tools

- Daily stock prices (GOOGLE): open, high, low, close, adjusted close, volume.  
- Annual financials: revenue, net income (billions).  
- Quarterly earnings: revenue and YoY growth.  
- Revenue segments: Google Search, YouTube ads, Google Network, Google Cloud, Other.  
- Financial ratios: gross/operating/net margin, ROE, ROA, free cash flow, current ratio.

Tools:

- PostgreSQL for cleaning and all the heavy queries.  
- Power BI for DAX measures and the interactive report.  
- Excel for small checks during cleaning.

---

## Main tables

- `public.stock_prices` – daily prices and volume.  
- `public.annual_financials` – revenue and net income by year (billions).  
- `public.quarterly_earnings` – quarterly revenue and YoY growth.  
- `public.revenue_segments` – revenue per segment in billions.  
- `public.financial_ratios` – pre‑calculated margins, ROE, ROA, FCF, etc.  
- `Date table` – calendar table in Power BI for all time‑based DAX.

---

## SQL – key queries (with short explanation)

Most of the analysis SQL is in:

`projects/google-stock/Data analysi main.sql`.[page:88]  
Below are some of the main patterns.

### 1. Annual stock performance

Find first and last price each year and calculate annual return:

```sql
SELECT
  EXTRACT(YEAR FROM date) AS year,
  MIN(adj_close) AS year_low,
  MAX(adj_close) AS year_high,
  FIRST_VALUE(adj_close) OVER (PARTITION BY EXTRACT(YEAR FROM date)
                               ORDER BY date) AS year_start_price,
  LAST_VALUE(adj_close) OVER (PARTITION BY EXTRACT(YEAR FROM date)
                              ORDER BY date
                              ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS year_end_price,
  (year_end_price - year_start_price) / year_start_price AS annual_return
FROM public.stock_prices;
```

This is used for the “year‑by‑year” return table and to spot which years were huge winners or big drawdowns.[page:88]

---

### 2. Daily returns and volatility

Calculate daily returns and rolling 30‑day volatility:

```sql
-- Daily simple returns
SELECT
  date,
  adj_close,
  LAG(adj_close) OVER (ORDER BY date) AS prev_close,
  (adj_close - LAG(adj_close) OVER (ORDER BY date))
    / LAG(adj_close) OVER (ORDER BY date) AS daily_return
FROM public.stock_prices;

-- 30‑day rolling volatility
SELECT
  date,
  adj_close,
  STDDEV_POP(daily_return) OVER (
    ORDER BY date
    ROWS BETWEEN 30 PRECEDING AND CURRENT ROW
  ) AS vol_30d
FROM daily_returns;
```

This feeds the volatility charts and helps show how noisy the stock was in different periods.[page:88]

---

### 3. Running peaks and drawdowns

Track new highs and how far the price falls from them:

```sql
WITH prices AS (
  SELECT
    date,
    adj_close,
    MAX(adj_close) OVER (ORDER BY date
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_peak
  FROM public.stock_prices
)
SELECT
  date,
  adj_close,
  running_peak,
  (adj_close - running_peak) / running_peak AS drawdown
FROM prices;
```

This is used for the drawdown chart and explains the depth and length of past crashes.[page:88]

---

### 4. Revenue and earnings growth

Pull yearly revenue, net income and growth:

```sql
SELECT
  year,
  revenue_billions,
  net_income_billions,
  revenue_billions
    - LAG(revenue_billions) OVER (ORDER BY year) AS revenue_change_b,
  (revenue_billions
    / NULLIF(LAG(revenue_billions) OVER (ORDER BY year), 0) - 1) AS revenue_yoy_pct
FROM public.annual_financials;
```

This gives the revenue levels and YoY growth used on the fundamentals pages.[page:88]

---

### 5. Revenue mix by segment

Calculate how much each segment contributes to total revenue:

```sql
SELECT
  year,
  total_revenue_billions,
  google_search_billions / total_revenue_billions AS search_share,
  youtube_ads_billions / total_revenue_billions AS youtube_share,
  google_network_billions / total_revenue_billions AS network_share,
  google_cloud_billions / total_revenue_billions AS cloud_share,
  other_revenues_billions / total_revenue_billions AS other_share
FROM public.revenue_segments;
```

This explains the stacked segment chart where Search dominates but Cloud and YouTube grow over time.[page:88]

---

### 6. Financial ratios

Summarise margins and cash‑flow‑related ratios:

```sql
SELECT
  year,
  gross_margin,
  operating_margin,
  net_margin,
  free_cash_flow_billions,
  free_cash_flow_billions / revenue_billions AS fcf_margin,
  roe,
  roa,
  current_ratio
FROM public.financial_ratios
JOIN public.annual_financials USING (year);
```

This powers the “financial health” visuals: margins, FCF margin, ROE, ROA and current ratio.[page:88]

---

## DAX measures – with formulas and simple notes

On top of this SQL, I used a set of DAX measures in Power BI.  
Here are the main ones that show up in the report.[page:88][page:89]

### Returns, price and risk

```DAX
Daily Return =
VAR PrevPrice =
    CALCULATE (
        MAX ( 'public stock_prices'[close] ),
        DATEADD ( 'public stock_prices'[date], -1, DAY )
    )
RETURN
IF (
    NOT ISBLANK ( PrevPrice ) && PrevPrice <> 0,
    ( MAX ( 'public stock_prices'[close] ) - PrevPrice ) / PrevPrice
)
```

Day‑to‑day % change in price. Used for volatility and to build up annual returns.

```DAX
Annual Volatility % =
STDEV.P ( 'public stock_prices'[Daily Log Return] ) * SQRT ( 252 ) * 100
```

Approximate annual volatility based on daily log returns.

```DAX
Annual Return % =
( EXP ( SUM ( 'public stock_prices'[Daily Log Return] ) ) - 1 ) * 100
```

Compounded annual return from daily log returns (shown as a %).

```DAX
Running Peak =
CALCULATE (
    MAX ( 'public stock_prices'[close] ),
    FILTER (
        ALL ( 'public stock_prices'[date] ),
        'public stock_prices'[date] <= MAX ( 'public stock_prices'[date] )
    )
)
```

Highest price reached so far at each point in time.

```DAX
Drawdown % =
DIVIDE (
    MAX ( 'public stock_prices'[close] ) - [Running Peak],
    [Running Peak]
)
```

How far the stock is below its running peak (used in the drawdown chart).

```DAX
30D Volatility =
STDEVX.P (
    DATESINPERIOD (
        'public stock_prices'[Date],
        MAX ( 'public stock_prices'[Date] ),
        -30,
        DAY
    ),
    [Daily Return]
)
```

Short‑term (30‑day) volatility based on daily returns.

```DAX
latest close price =
CALCULATE (
    MAX ( 'public stock_prices'[adj_close] ),
    LASTDATE ( 'public stock_prices'[date] )
)
```

Latest adjusted close, used for the main “current price” card.

---

### Revenue, growth and segments

```DAX
Total Revenue =
SUM ( 'public revenue_segments'[total_revenue_billions] )
```

Total revenue in billions.

```DAX
YoY Revenue Growth % =
VAR CurrentYear =
    SELECTEDVALUE ( 'Date table'[Year] )
VAR CurrentRevenue =
    SUM ( 'public annual_financials'[revenue_billions] )
VAR PriorRevenue =
    CALCULATE (
        SUM ( 'public annual_financials'[revenue_billions] ),
        'Date table'[Year] = CurrentYear - 1
    )
RETURN
IF (
    NOT ISBLANK ( PriorRevenue ) && PriorRevenue <> 0,
    DIVIDE ( CurrentRevenue - PriorRevenue, PriorRevenue ),
    BLANK ()
)
```

Year‑over‑year revenue growth, used on the revenue trend.

```DAX
Revenue CAGR % =
VAR MinYearVisible =
    MIN ( 'public annual_financials'[year] )
VAR MaxYearVisible =
    MAX ( 'public annual_financials'[year] )
VAR StartRevenue =
    CALCULATE (
        SUM ( 'public annual_financials'[revenue_billions] ),
        'public annual_financials'[year] = MinYearVisible
    )
VAR EndRevenue =
    CALCULATE (
        SUM ( 'public annual_financials'[revenue_billions] ),
        'public annual_financials'[year] = MaxYearVisible
    )
VAR NumYears = MaxYearVisible - MinYearVisible
RETURN
IF (
    NOT ISBLANK ( StartRevenue )
        && NOT ISBLANK ( EndRevenue )
        && NumYears > 0
        && StartRevenue <> 0,
    POWER ( EndRevenue / StartRevenue, 1.0 / NumYears ) - 1,
    BLANK ()
)
```

Compound annual growth rate for revenue across the visible period.

```DAX
Google Search Share =
DIVIDE (
    SUM ( 'public revenue_segments'[google_search_billions] ),
    SUM ( 'public revenue_segments'[total_revenue_billions] )
)
```

Share of revenue from Search.

Similar pattern is used for:

```DAX
Youtube Ads =
DIVIDE (
    SUM ( 'public revenue_segments'[youtube_ads_billions] ),
    SUM ( 'public revenue_segments'[total_revenue_billions] )
)

cloud share % =
DIVIDE (
    SUM ( 'public revenue_segments'[google_cloud_billions] ),
    SUM ( 'public revenue_segments'[total_revenue_billions] )
)
```

Used for the segment breakdown visuals.

---

### Margins, cash and health

```DAX
Gross Margin % =
AVERAGE ( 'public financial_ratios'[gross_margin] )

Operating Margin % =
AVERAGE ( 'public financial_ratios'[operating_margin] )

Net Margin % =
AVERAGE ( 'public financial_ratios'[net_margin] )
```

Average margins across the visible years.

```DAX
Net Profit Margin % =
DIVIDE (
    SUM ( 'public annual_financials'[net_income_billions] ),
    SUM ( 'public annual_financials'[revenue_billions] )
)
```

Net income / revenue, used for the 2025 net margin card (with a year filter applied).

```DAX
Free Cash Flow ($B) =
SUM ( 'public financial_ratios'[free_cash_flow_billions] )

FCF Margin % =
DIVIDE (
    SUM ( 'public financial_ratios'[free_cash_flow_billions] ),
    SUM ( 'public annual_financials'[revenue_billions] )
)
```

Free cash flow and free cash flow margin.

```DAX
ROE % =
AVERAGE ( 'public financial_ratios'[roe] )

ROA % =
AVERAGE ( 'public financial_ratios'[roa] )
```

Return on equity and return on assets.

```DAX
Current Ratio (Latest) =
VAR LatestYear =
    MAX ( 'public financial_ratios'[year] )
RETURN
CALCULATE (
    AVERAGE ( 'public financial_ratios'[current_ratio] ),
    'public financial_ratios'[year] = LatestYear
)
```

Current ratio for the latest year.

```DAX
Risk Adjusted Return =
DIVIDE (
    [Annual Return %],
    [Annual Volatility %]
)
```

Return per unit of risk, used to show how “efficient” the stock’s returns have been.

---

## Report pages (high level)

The Power BI report matches the structure of the Google Stock project page:

- overview: long‑term price, latest price, revenue and net income highlights, revenue CAGR.  
- price & volatility: annual returns, annual volatility, 30‑day volatility, drawdown chart.  
- revenue mix: total revenue, YoY growth and segment breakdown (Search, YouTube, Network, Cloud, Other).  
- financial health: margins, free cash flow, ROE/ROA and current ratio.

---
