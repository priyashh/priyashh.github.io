select 
extract(year from date) :: INT as year,
round(min(adj_close),2) as yearly_low,
round(max(adj_close),2) as yearly_high,
round(avg(adj_close),2) as avgprice,
round(max(adj_close) - min(adj_close),2) as price_range,
round((max(adj_close) - min(adj_close))
		/ min(adj_close) * 100, 1) as range_pct,
round(sum(volume)/1000000.0, 1) as total_vol_millions
from stock_prices
group by extract(year from date)
order by year;


--First and Last Price of Each Year (for YoY Return)
with yearly_bounds as (select
extract(year from date) :: int as year,
min(date) as first_date,
max(date) as last_date
from stock_prices
group by extract(year from date)),
year_prices as (select yb.year, s1.adj_close as year_open_price, s2.adj_close as year_close_price
from yearly_bounds yb
join stock_prices s1 on s1.date = yb.first_date
join stock_prices s2 on s2.date = yb.last_date)
select year, year_open_price, year_close_price,
round(year_close_price - year_open_price, 2) as price_change,
round((year_close_price - year_open_price)
/ year_open_price * 100, 1) as annual_return_pct
from year_prices
order by year;




--daily returns & 30 day rolling volatility
with daily_returns as (select
date,adj_close,round(
ln(adj_close / lag(adj_close) over (order by date)),6) as log_return
from stock_prices
where adj_close > 0)
select date,adj_close,round(log_return * 100, 4) as daily_return_pct,
round(stddev(log_return) over 
(order by date rows between 29 preceding and current row) * 100,4) as rolling_30d_volatility
from daily_returns
where log_return is not null
order by date;


--Worst and Best Single-Day Returns
with daily_returns as (select date,adj_close,
round((adj_close - lag(adj_close) over (order by date))
/ lag(adj_close) over (order by date) * 100, 2) as daily_return_pct
from stock_prices)
select date, adj_close, daily_return_pct
from daily_returns
where daily_return_pct is not null
order by daily_return_pct desc
limit 10;

--Volume price correlation by year
select
extract(year from date):: int as year,
round(avg(adj_close), 2) as avg_price,
round(avg(volume) / 1000000.0, 1) as avg_daily_volume_millions,
round(corr(volume, adj_close) :: numeric, 3) as vol_price_correlation
from stock_prices
group by extract(year from date)
order by year;

--Revenue & Profit Growth — Year-Over-Year
select year, revenue_billions, net_income_billions,
round((revenue_billions - lag(revenue_billions) over (order by year))
/ lag(revenue_billions) over (order by year) * 100, 1) as revenue_yoy_growth_pct,
round((net_income_billions - lag(net_income_billions) over (order by year))
/ lag(net_income_billions) over (order by year) * 100, 1) as net_income_yoy_growth_pct,
round(net_income_billions / revenue_billions * 100, 1) as net_margin_pct
from annual_financials
order by year;


-- Financial Ratios Trend — Efficiency & Profitability
select f.year,
round(f.roe * 100, 1) as roe_pct,
round(f.roa * 100, 1) as roa_pct,
f.current_ratio,
round(f.gross_margin * 100, 1) as gross_margin_pct,
round(f.operating_margin * 100, 1) as operating_margin_pct,
round(f.net_margin * 100, 1) as net_margin_pct,
f.free_cash_flow_billions,
round(f.free_cash_flow_billions / a.revenue_billions * 100, 1) as fcf_margin_pct
from financial_ratios f
join annual_financials a on f.year = a.year
order by f.year;

--Quarterly Earnings Trend — Revenue & EPS (2020-2025)
select
year, quarter, revenue_billions, eps,
round(yoy_revenue_growth * 100, 1) as yoy_growth_pct,
round(operating_margin * 100, 1) as op_margin_pct,
round((revenue_billions - lag(revenue_billions) over (order by date_reported))
/ lag(revenue_billions) over (order by date_reported) * 100, 1) as qoq_revenue_growth_pct
from quarterly_earnings
order by date_reported;

--Revenue Mix — Each Segment's Share of Total Revenue
select
year,
round(google_search_billions / total_revenue_billions * 100, 1) as search_share_pct,
round(youtube_ads_billions / total_revenue_billions * 100, 1) as youtube_share_pct,
round(google_network_billions / total_revenue_billions * 100, 1) as network_share_pct,
round(google_cloud_billions / total_revenue_billions * 100, 1) as cloud_share_pct,
round(other_revenues_billions / total_revenue_billions * 100, 1) as other_share_pct,
round(google_cloud_billions - lag(google_cloud_billions) over (order by year), 2) as cloud_yoy_growth_b
from revenue_segments
order by year;

--Fastest-Growing Revenue Segment
with segment_growth as (select year, 
round((google_search_billions - lag(google_search_billions) over (order by year))
/ lag(google_search_billions) over (order by year) * 100, 1) as search_growth,
round((youtube_ads_billions - lag(youtube_ads_billions) over (order by year))
/ lag(youtube_ads_billions) over (order by year) * 100, 1) as youtube_growth,
round((google_cloud_billions - lag(google_cloud_billions) over (order by year))
/ lag(google_cloud_billions) over (order by year) * 100, 1) as cloud_growth
from revenue_segments)
select year, search_growth, youtube_growth, cloud_growth,
case 
when cloud_growth >= youtube_growth and cloud_growth >= search_growth then 'Cloud'
when youtube_growth >= cloud_growth and youtube_growth >= search_growth then 'YouTube'
else 'Search'
end as fastest_growing_segment
from segment_growth
where year > 2017
order by year;

--Moving Averages — 50-Day & 200-Day (Golden/Death Cross)
select date, adj_close,
round(avg(adj_close) over (order by date
rows between 49 preceding and current row),2) as sma_50,
round(avg(adj_close) over (order by date
rows between 199 preceding and current row),2) as sma_200,
case
when avg(adj_close) over (order by date
rows between 49 preceding and current row) > avg(adj_close) over 
(order by date rows between 199 preceding and current row)
then 'Bullish (50 > 200)'
else 'Bearish (50 < 200)'
end as trend_signal
from stock_prices
order by date;



-- Compound Annual Growth Rate (CAGR) Calculation
select
min(extract(year from date) :: int) as start_year,
max(extract(year from date) :: int) as end_year,
min(adj_close) as start_price,
max(case when date = (select max(date) from stock_prices)
then adj_close end) as end_price,
count(distinct extract(year from date)) - 1 as years,
round((power(max(case when date = (select max(date) from stock_prices) then adj_close end)
/ (select adj_close from stock_prices order by date limit 1),1.0
/ (count(distinct extract(year from date)) - 1)) - 1) * 100,2) as cagr_pct
from stock_prices;


--Stock Performance vs. Financial Health Score
select
a.year,a.revenue_billions,a.net_income_billions,a.market_cap_billions,a.pe_ratio,a.employees,f.roe 
* 100 as roe_pct,
f.operating_margin * 100 as op_margin_pct,
f.free_cash_flow_billions,
round(a.revenue_billions * 1000.0 / a.employees, 0) as revenue_per_employee_k,
round(a.market_cap_billions / a.revenue_billions, 2) as price_to_sales, a.key_event
from annual_financials a
join financial_ratios f on a.year = f.year
order by a.year;


--Monthly Seasonality — Average Return by Month
with monthly_returns as (select
extract(month from date):: int as month_num,
to_char(date, 'Month') as month_name, first_value(adj_close) over 
(partition by extract(year from date), extract(month from date) order by date
rows between unbounded preceding and unbounded following) as month_open,
last_value(adj_close) over (partition by extract(year from date),
extract(month from date) order by date
rows between unbounded preceding and unbounded following) as month_close
from stock_prices)
select month_num,trim(month_name) as month,
round(avg((month_close - month_open) / month_open * 100), 2) as avg_monthly_return_pct,
count(*) / 21 as years_of_data
from monthly_returns
group by month_num, month_name
order by month_num;
