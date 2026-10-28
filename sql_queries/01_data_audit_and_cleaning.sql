-- =============================================================================
-- Project: AtliQ Hardware Sales Insights Data Analysis
-- File: 01_data_audit_and_cleaning.sql
-- Description: Diagnostic SQL scripts to detect anomalies, data quality issues,
--              referential integrity breaks, and apply cleaning transformations.
-- =============================================================================

USE `sales`;

-- -----------------------------------------------------------------------------
-- 1. INSPECT TABLE ROW COUNTS
-- -----------------------------------------------------------------------------
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'date', COUNT(*) FROM date
UNION ALL
SELECT 'markets', COUNT(*) FROM markets
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions;


-- -----------------------------------------------------------------------------
-- 2. CURRENCY DISCREPANCIES & UNCLEAN DATA
-- Issue: Transactions contain mixed currencies ('INR', 'USD') and trailing carriage returns ('INR\r', 'USD\r').
-- -----------------------------------------------------------------------------
-- Check distinct currency values and their counts
SELECT 
    currency, 
    COUNT(*) AS transaction_count,
    SUM(sales_amount) AS total_gross_amount
FROM transactions
GROUP BY currency;

-- Normalization logic: Convert USD to INR (Conversion rate: 1 USD = 75 INR)
-- Handled in Power Query M or SQL:
SELECT 
    product_code,
    customer_code,
    market_code,
    order_date,
    sales_qty,
    sales_amount,
    currency,
    CASE 
        WHEN currency IN ('USD', 'USD\r') THEN sales_amount * 75
        ELSE sales_amount
    END AS normalized_sales_amount
FROM transactions;


-- -----------------------------------------------------------------------------
-- 3. INVALID & ZERO/NEGATIVE SALES TRANSACTIONS
-- Issue: Raw database dumps contain transactions with sales_amount <= 0 or sales_qty <= 0.
-- -----------------------------------------------------------------------------
-- Detect invalid sales transactions
SELECT COUNT(*) AS invalid_records_count, MIN(sales_amount) AS min_amt, MAX(sales_amount) AS max_amt
FROM transactions
WHERE sales_amount <= 0;

-- Filter out non-positive sales (to be applied in views or ETL)
SELECT * 
FROM transactions
WHERE sales_amount > 0 AND sales_qty > 0;


-- -----------------------------------------------------------------------------
-- 4. GHOST / ZERO-TRANSACTION MARKETS & DUPLICATES
-- Issue: 'New York' (Mark097) and 'Paris' (Mark999) have blank zones and 0 sales.
-- Issue: 'Bhopal' exists twice as Mark007 and Mark013.
-- -----------------------------------------------------------------------------
-- Find markets with missing zones
SELECT * 
FROM markets 
WHERE zone IS NULL OR zone = '';

-- Find duplicate market entries
SELECT markets_name, COUNT(*) AS occurrences
FROM markets
GROUP BY markets_name
HAVING COUNT(*) > 1;

-- Market transaction volumes
SELECT 
    m.markets_code,
    m.markets_name,
    m.zone,
    COUNT(t.order_date) AS total_transactions
FROM markets m
LEFT JOIN transactions t ON m.markets_code = t.market_code
GROUP BY m.markets_code, m.markets_name, m.zone
ORDER BY total_transactions ASC;


-- -----------------------------------------------------------------------------
-- 5. REFERENTIAL INTEGRITY BREAKS: THE "(BLANK)" PRODUCT MYSTERY
-- Issue: In Power BI, June 2020 shows "(Blank)" product accounting for ~₹7M revenue!
-- Cause: Products table only defines Prod001 to Prod279, while transactions table
-- contains transactions for Prod280 to Prod339 (54,599 orphaned transactions).
-- -----------------------------------------------------------------------------
-- Detect orphaned transactions missing from product dimension
SELECT 
    COUNT(*) AS orphaned_transaction_count,
    COUNT(DISTINCT t.product_code) AS missing_distinct_products,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END), 2) AS orphaned_revenue
FROM transactions t
LEFT JOIN products p ON t.product_code = p.product_code
WHERE p.product_code IS NULL;

-- List all orphaned product codes
SELECT DISTINCT t.product_code
FROM transactions t
LEFT JOIN products p ON t.product_code = p.product_code
WHERE p.product_code IS NULL
ORDER BY t.product_code;

-- Recommended Fix: Backfill products dimension table with unknown/inferred records
-- INSERT INTO products (product_code, product_type)
-- SELECT DISTINCT t.product_code, 'Own Brand'
-- FROM transactions t
-- LEFT JOIN products p ON t.product_code = p.product_code
-- WHERE p.product_code IS NULL;


-- -----------------------------------------------------------------------------
-- 6. DIRTY CARRIAGE RETURNS IN STRINGS
-- Issue: Fields like product_type and currency have trailing '\r' (char 13).
-- -----------------------------------------------------------------------------
SELECT DISTINCT product_type, HEX(product_type) FROM products;

-- SQL Cleanse:
-- UPDATE products SET product_type = TRIM(REPLACE(product_type, '\r', ''));
-- UPDATE transactions SET currency = TRIM(REPLACE(currency, '\r', ''));
