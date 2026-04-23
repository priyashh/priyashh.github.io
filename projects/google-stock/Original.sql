--CREATED tables according to dataset(6 table in total)
Create Table stock_prices(
data Date,
Open Numeric,
High Numeric,
Low Numeric,
Close Numeric,
Adj_close Numeric,
Volume Bigint,
Split_adjusted Boolean

);

CREATE TABLE company_info (
    category TEXT,
    item TEXT,
    value TEXT,
    date DATE,
    description TEXT
);

CREATE TABLE annual_financials (
    year INT,
    revenue_billions NUMERIC,
    net_income_billions NUMERIC,
    eps NUMERIC,
    market_cap_billions NUMERIC,
    pe_ratio NUMERIC,
    dividend_per_share NUMERIC,
    employees INT,
    key_event TEXT
);

CREATE TABLE quarterly_earnings (
    quarter TEXT,
    year INT,
    revenue_billions NUMERIC,
    net_income_billions NUMERIC,
    eps NUMERIC,
    yoy_revenue_growth NUMERIC,
    operating_margin NUMERIC,
    date_reported DATE
);

CREATE TABLE revenue_segments (
    year INT,
    google_search_billions NUMERIC,
    youtube_ads_billions NUMERIC,
    google_network_billions NUMERIC,
    google_cloud_billions NUMERIC,
    other_revenues_billions NUMERIC,
    total_revenue_billions NUMERIC,
    cloud_growth_rate NUMERIC
);

CREATE TABLE financial_ratios (
    year INT,
    roe NUMERIC,
    roa NUMERIC,
    current_ratio NUMERIC,
    debt_to_equity NUMERIC,
    free_cash_flow_billions NUMERIC,
    operating_cash_flow_billions NUMERIC,
    gross_margin NUMERIC,
    operating_margin NUMERIC,
    net_margin NUMERIC
);
-----------------------------------

--checking tables imported
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public';

--Checking column names & data types for each tables

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'annual_financials';

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'stock_prices';

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'quarterly_earnings';

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'financial_ratios';


SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'revenue_segments';


SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'company_info';

--Duplicate checks
	--duplicates in annual data
	Select year, count(*)
	from annual_financials
	group by year
	having count(*)>1;
		
	--duplicates in daily 

	select date, count (*)
	from stock_prices
	group by date
	having count(*)>1

--Checking values
	--negative values check
	SELECT *
	FROM annual_financials
	WHERE revenue_billions < 0
	   OR net_income_billions < 0;	
		--stock price validation
	SELECT *
	FROM stock_prices
	WHERE open < 0
	   OR high < 0
	   OR low < 0
	   OR close < 0;



