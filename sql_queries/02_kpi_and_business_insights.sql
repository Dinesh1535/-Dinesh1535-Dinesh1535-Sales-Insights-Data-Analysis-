-- =============================================================================
-- Project: AtliQ Hardware Sales Insights Data Analysis
-- File: 02_kpi_and_business_insights.sql
-- Description: Core business analysis queries covering Revenue, Profitability,
--              Market Dynamics, Customer Concentration, and Product Performance.
-- =============================================================================

USE `sales`;

-- -----------------------------------------------------------------------------
-- 1. OVERALL BUSINESS KPIS
-- -----------------------------------------------------------------------------
-- Total Revenue, Total Volume, Total Profit Margin, and Overall Profit Margin %
SELECT 
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) / 1000000.0, 2) AS total_revenue_inr_mln,
    ROUND(SUM(t.sales_qty) / 1000.0, 1) AS total_sales_volume_k_units,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 1000000.0, 2) AS total_profit_margin_inr_mln,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 
          SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) * 100, 2) AS overall_profit_margin_pct
FROM transactions t
WHERE t.sales_amount > 0 AND t.market_code NOT IN ('Mark097', 'Mark999');


-- -----------------------------------------------------------------------------
-- 2. YEAR-OVER-YEAR (YoY) FINANCIAL TRENDS
-- -----------------------------------------------------------------------------
SELECT 
    d.year,
    COUNT(t.sales_amount) AS total_transactions,
    SUM(t.sales_qty) AS units_sold,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) / 1000000.0, 2) AS revenue_mln,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 1000000.0, 2) AS profit_mln,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 
          SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) * 100, 2) AS profit_margin_pct
FROM transactions t
JOIN date d ON t.order_date = d.date
WHERE t.sales_amount > 0 AND t.market_code NOT IN ('Mark097', 'Mark999')
GROUP BY d.year
ORDER BY d.year;


-- -----------------------------------------------------------------------------
-- 3. MARKET PERFORMANCE & REGIONAL PROFITABILITY
-- Highlights top revenue-generating markets and pinpoints loss-making territories.
-- -----------------------------------------------------------------------------
SELECT 
    m.markets_name,
    m.zone,
    COUNT(t.sales_amount) AS total_orders,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) / 1000000.0, 2) AS revenue_mln,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 1000000.0, 2) AS profit_mln,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 
          SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) * 100, 2) AS profit_margin_pct,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) * 100.0 / 
          (SELECT SUM(CASE WHEN currency LIKE '%USD%' THEN sales_amount * 75 ELSE sales_amount END) 
           FROM transactions WHERE market_code NOT IN ('Mark097', 'Mark999') AND sales_amount > 0), 2) AS revenue_contribution_pct
FROM transactions t
JOIN markets m ON t.market_code = m.markets_code
WHERE t.sales_amount > 0 AND m.markets_code NOT IN ('Mark097', 'Mark999')
GROUP BY m.markets_code, m.markets_name, m.zone
ORDER BY revenue_mln DESC;


-- -----------------------------------------------------------------------------
-- 4. LOSS-MAKING MARKETS (CRITICAL ALERT)
-- Identifies markets operating with negative net profit margins.
-- -----------------------------------------------------------------------------
SELECT 
    m.markets_name,
    m.zone,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) / 1000.0, 2) AS revenue_k,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 1000.0, 2) AS profit_k,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 
          SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) * 100, 2) AS profit_margin_pct
FROM transactions t
JOIN markets m ON t.market_code = m.markets_code
WHERE t.sales_amount > 0 AND m.markets_code NOT IN ('Mark097', 'Mark999')
GROUP BY m.markets_code, m.markets_name, m.zone
HAVING profit_k < 0
ORDER BY profit_margin_pct ASC;


-- -----------------------------------------------------------------------------
-- 5. CUSTOMER CONCENTRATION ANALYSIS (PARETO 80/20 PRINCIPLE)
-- Reveals reliance on key customer accounts.
-- -----------------------------------------------------------------------------
SELECT 
    c.customer_code,
    c.custmer_name AS customer_name,
    c.customer_type,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) / 1000000.0, 2) AS revenue_mln,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 1000000.0, 2) AS profit_mln,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 
          SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) * 100, 2) AS margin_pct,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) * 100.0 / 
          (SELECT SUM(CASE WHEN currency LIKE '%USD%' THEN sales_amount * 75 ELSE sales_amount END) 
           FROM transactions WHERE market_code NOT IN ('Mark097', 'Mark999') AND sales_amount > 0), 2) AS revenue_share_pct
FROM transactions t
JOIN customers c ON t.customer_code = c.customer_code
WHERE t.sales_amount > 0 AND t.market_code NOT IN ('Mark097', 'Mark999')
GROUP BY c.customer_code, c.custmer_name, c.customer_type
ORDER BY revenue_mln DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- 6. CHANNEL PERFORMANCE: BRICK & MORTAR VS. E-COMMERCE
-- -----------------------------------------------------------------------------
SELECT 
    c.customer_type AS sales_channel,
    COUNT(t.sales_amount) AS total_orders,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) / 1000000.0, 2) AS revenue_mln,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 1000000.0, 2) AS profit_mln,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 
          SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) * 100, 2) AS profit_margin_pct
FROM transactions t
JOIN customers c ON t.customer_code = c.customer_code
WHERE t.sales_amount > 0 AND t.market_code NOT IN ('Mark097', 'Mark999')
GROUP BY c.customer_type;


-- -----------------------------------------------------------------------------
-- 7. TOP 5 MOST PROFITABLE PRODUCTS & TOP 5 LOSS-MAKING PRODUCTS
-- (Filtered for active products with significant transaction volume > ₹500K)
-- -----------------------------------------------------------------------------
-- Top 5 Highest Margin Products
SELECT 
    p.product_code,
    TRIM(REPLACE(p.product_type, '\r', '')) AS product_type,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) / 1000.0, 2) AS revenue_k,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 1000.0, 2) AS profit_k,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 
          SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) * 100, 2) AS margin_pct
FROM transactions t
JOIN products p ON t.product_code = p.product_code
WHERE t.sales_amount > 0 AND t.market_code NOT IN ('Mark097', 'Mark999')
GROUP BY p.product_code, p.product_type
HAVING revenue_k > 500
ORDER BY margin_pct DESC
LIMIT 5;

-- Top 5 Bleeding / Loss-Making Products
SELECT 
    p.product_code,
    TRIM(REPLACE(p.product_type, '\r', '')) AS product_type,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) / 1000.0, 2) AS revenue_k,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 1000.0, 2) AS profit_k,
    ROUND(SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.profit_margin * 75 ELSE t.profit_margin END) / 
          SUM(CASE WHEN t.currency LIKE '%USD%' THEN t.sales_amount * 75 ELSE t.sales_amount END) * 100, 2) AS margin_pct
FROM transactions t
JOIN products p ON t.product_code = p.product_code
WHERE t.sales_amount > 0 AND t.market_code NOT IN ('Mark097', 'Mark999')
GROUP BY p.product_code, p.product_type
HAVING revenue_k > 500
ORDER BY margin_pct ASC
LIMIT 5;
