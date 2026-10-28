-- =============================================================================
-- Project: AtliQ Hardware Sales Insights Data Analysis
-- File: 03_powerbi_dax_and_mquery.sql
-- Description: Power BI Power Query (M Language) ETL transformations and
--              DAX (Data Analysis Expressions) Measures reference guide.
-- =============================================================================

/*
===============================================================================
SECTION 1: POWER QUERY (M CODE) ETL FORMULAS
===============================================================================
*/

-- 1.1 Currency Normalization (in Transactions Table)
-- Normalizes USD records to INR using 75 multiplier, handling trailing '\r' characters
/*
Table.AddColumn(#"Filtered Rows", "norm_sales_amount", each 
    if [currency] = "USD" or [currency] = "USD#(cr)" or [currency] = "USD\r" then 
        [sales_amount] * 75 
    else 
        [sales_amount], 
    type number
)
*/

-- 1.2 Profit Margin Normalization (for USD transactions)
/*
Table.AddColumn(#"Added Norm Sales", "norm_profit_margin", each 
    if [currency] = "USD" or [currency] = "USD#(cr)" or [currency] = "USD\r" then 
        [profit_margin] * 75 
    else 
        [profit_margin], 
    type number
)
*/

-- 1.3 Clean Trailing Carriage Returns in Markets and Products
/*
Table.TransformColumns(#"Source", {
    {"product_type", each Text.Clean(Text.Trim(_)), type text}
})
*/

-- 1.4 Filter Out International Ghost Markets
/*
Table.SelectRows(#"Filtered Rows", each ([zone] <> "" and [zone] <> null))
*/


/*
===============================================================================
SECTION 2: DAX MEASURES (DATA ANALYSIS EXPRESSIONS)
===============================================================================
*/

-- 2.1 Base Sales Measures
-- Revenue Measure
Revenue = 
SUM('sales transactions'[norm_sales_amount])

-- Sales Quantity Measure
Sales Quantity = 
SUM('sales transactions'[sales_qty])

-- Total Cost Measure
Total Cost = 
SUMX(
    'sales transactions',
    'sales transactions'[norm_sales_amount] - 'sales transactions'[norm_profit_margin]
)


-- 2.2 Profitability Measures
-- Total Profit Margin
Total Profit Margin = 
SUM('sales transactions'[norm_profit_margin])

-- Profit Margin %
Profit Margin % = 
DIVIDE([Total Profit Margin], [Revenue], 0)


-- 2.3 Contribution & Ratio Measures
-- Revenue Contribution % (Against All Markets/Customers)
Profit Margin Contribution % = 
DIVIDE(
    [Total Profit Margin],
    CALCULATE([Total Profit Margin], ALL('sales products'), ALL('sales markets'), ALL('sales customers')),
    0
)

-- Revenue Share %
Revenue Contribution % = 
DIVIDE(
    [Revenue],
    CALCULATE([Revenue], ALL('sales products'), ALL('sales markets'), ALL('sales customers')),
    0
)


-- 2.4 Diagnostic KPI: Target Margin Status
-- Flags performance against corporate target (e.g., target 3% margin)
Target Profit Margin % = 0.03

Margin Variance = 
[Profit Margin %] - [Target Profit Margin %]

Profit Status = 
SWITCH(
    TRUE(),
    [Profit Margin %] < 0, "🔴 Loss Making",
    [Profit Margin %] < 0.02, "🟡 Low Margin",
    "🟢 Healthy Margin"
)
