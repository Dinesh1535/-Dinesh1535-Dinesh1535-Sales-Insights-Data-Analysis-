"""
AtliQ Hardware Sales Insights & Performance Analysis
Author: Arencheruvu Dinesh
Repository: https://github.com/Dinesh1535/-Dinesh1535-Dinesh1535-Sales-Insights-Data-Analysis-
Description:
    End-to-end Python engine that ingests the SQL dump, validates data integrity,
    cleans anomalies, calculates core business metrics & DAX equivalents,
    and exports summary analytical datasets.
"""

import os
import sys
import re
import csv
import sqlite3
from typing import Dict, List, Tuple

# Ensure UTF-8 printing in Windows terminals
if sys.stdout.encoding.lower() != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL_DUMP_PATH = os.path.join(BASE_DIR, "db_dump_version_2.sql")
EXPORTS_DIR = os.path.join(BASE_DIR, "data_exports")


def init_database() -> sqlite3.Connection:
    """Load SQL dump into SQLite in-memory database."""
    conn = sqlite3.connect(":memory:")
    cursor = conn.cursor()

    print("[*] Reading SQL dump file...")
    with open(SQL_DUMP_PATH, "r", encoding="utf-8", errors="ignore") as f:
        sql = f.read()

    statements = sql.split(";\n")
    print(f"[*] Processing {len(statements)} SQL statements into memory...")

    executed = 0
    for stmt in statements:
        stmt = stmt.strip()
        if (
            not stmt
            or stmt.startswith("/*")
            or stmt.startswith("--")
            or stmt.startswith("LOCK")
            or stmt.startswith("UNLOCK")
        ):
            continue

        clean_stmt = re.sub(r"ENGINE=InnoDB.*", "", stmt, flags=re.IGNORECASE)
        clean_stmt = re.sub(r"/\*!.*?\*/", "", clean_stmt)

        if (
            clean_stmt.startswith("DROP")
            or clean_stmt.startswith("CREATE TABLE")
            or clean_stmt.startswith("INSERT INTO")
        ):
            try:
                cursor.execute(clean_stmt)
                executed += 1
            except Exception as e:
                pass

    conn.commit()
    print(f"[+] Loaded successfully ({executed} statements executed).")
    return conn


def export_query_to_csv(cursor: sqlite3.Cursor, query: str, filename: str):
    """Execute SQL query and write results to CSV file."""
    os.makedirs(EXPORTS_DIR, exist_ok=True)
    out_path = os.path.join(EXPORTS_DIR, filename)

    cursor.execute(query)
    headers = [col[0] for col in cursor.description]
    rows = cursor.fetchall()

    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)

    print(f"[+] Exported {len(rows)} rows to {filename}")


def run_full_analysis():
    conn = init_database()
    cursor = conn.cursor()

    print("\n" + "=" * 60)
    print(" 1. DATA AUDIT & REFERENTIAL INTEGRITY FINDINGS")
    print("=" * 60)

    # 1. Total records
    for tbl in ["customers", "date", "markets", "products", "transactions"]:
        cnt = cursor.execute(f"SELECT count(*) FROM {tbl}").fetchone()[0]
        print(f" - Table '{tbl}': {cnt:,} records")

    # 2. Referential integrity: Orphaned products
    orphaned_prod_query = """
    SELECT count(*), 
           round(sum(case when currency='USD' then sales_amount*75 else sales_amount end)/1000000.0, 2)
    FROM transactions t
    LEFT JOIN products p ON t.product_code = p.product_code
    WHERE p.product_code IS NULL;
    """
    orph_cnt, orph_rev = cursor.execute(orphaned_prod_query).fetchone()
    print(f" - Orphaned Transactions (Product not in dim table): {orph_cnt:,} rows | Revenue: ₹{orph_rev:,.2f}M")

    # 3. Currency Normalization
    curr_rows = cursor.execute("SELECT currency, count(*), sum(sales_amount) FROM transactions GROUP BY currency").fetchall()
    print(" - Currency Distribution:")
    for curr, count, amt in curr_rows:
        print(f"    * {curr}: {count:,} records (Gross: ₹{amt:,.2f})")

    # 4. Out-of-Scope Markets (New York, Paris)
    ghost_mkts = cursor.execute("SELECT markets_code, markets_name, zone FROM markets WHERE zone = '' OR zone IS NULL").fetchall()
    print(f" - Ghost / Zero-Transaction Markets: {ghost_mkts}")

    print("\n" + "=" * 60)
    print(" 2. CORE BUSINESS KPIS (OVERALL)")
    print("=" * 60)

    kpi_query = """
    SELECT 
        round(sum(case when t.currency='USD' then t.sales_amount*75 else t.sales_amount end)/1000000.0, 2) as total_revenue_mln,
        round(sum(t.sales_qty)/1000.0, 1) as total_qty_k,
        round(sum(case when t.currency='USD' then t.profit_margin*75 else t.profit_margin end)/1000000.0, 2) as total_profit_mln,
        round(sum(case when t.currency='USD' then t.profit_margin*75 else t.profit_margin end) / 
              sum(case when t.currency='USD' then t.sales_amount*75 else t.sales_amount end) * 100, 2) as profit_margin_pct
    FROM transactions t
    WHERE t.market_code NOT IN ('Mark097', 'Mark999');
    """
    tot_rev, tot_qty, tot_profit, margin_pct = cursor.execute(kpi_query).fetchone()
    print(f" - Total Net Revenue: ₹{tot_rev}M")
    print(f" - Total Sales Quantity: {tot_qty}K units")
    print(f" - Total Profit Margin: ₹{tot_profit}M")
    print(f" - Net Profit Margin %: {margin_pct}%")

    print("\n" + "=" * 60)
    print(" 3. YEAR-OVER-YEAR PERFORMANCE SUMMARY")
    print("=" * 60)

    yearly_query = """
    SELECT 
        d.year,
        count(t.sales_amount) as transactions_count,
        sum(t.sales_qty) as total_units_sold,
        round(sum(case when t.currency='USD' then t.sales_amount*75 else t.sales_amount end)/1000000.0, 2) as revenue_mln,
        round(sum(case when t.currency='USD' then t.profit_margin*75 else t.profit_margin end)/1000000.0, 2) as profit_mln,
        round(sum(case when t.currency='USD' then t.profit_margin*75 else t.profit_margin end) / 
              sum(case when t.currency='USD' then t.sales_amount*75 else t.sales_amount end) * 100, 2) as profit_margin_pct
    FROM transactions t
    JOIN date d ON t.order_date = d.date
    WHERE t.market_code NOT IN ('Mark097', 'Mark999')
    GROUP BY d.year
    ORDER BY d.year;
    """
    cursor.execute(yearly_query)
    print(f"{'Year':<6} | {'Txns':<8} | {'Units Sold':<11} | {'Revenue (₹M)':<14} | {'Profit (₹M)':<13} | {'Margin %':<8}")
    print("-" * 72)
    for row in cursor.fetchall():
        print(f"{row[0]:<6} | {row[1]:<8} | {row[2]:<11,d} | ₹{row[3]:<12.2f} | ₹{row[4]:<11.2f} | {row[5]:<6.2f}%")

    # Exports
    export_query_to_csv(cursor, yearly_query, "yearly_performance.csv")

    market_query = """
    SELECT 
        m.markets_code,
        m.markets_name,
        m.zone,
        count(t.sales_amount) as total_transactions,
        round(sum(case when t.currency='USD' then t.sales_amount*75 else t.sales_amount end)/1000000.0, 2) as revenue_mln,
        round(sum(case when t.currency='USD' then t.profit_margin*75 else t.profit_margin end)/1000000.0, 2) as profit_mln,
        round(sum(case when t.currency='USD' then t.profit_margin*75 else t.profit_margin end) / 
              sum(case when t.currency='USD' then t.sales_amount*75 else t.sales_amount end) * 100, 2) as profit_margin_pct
    FROM markets m
    LEFT JOIN transactions t ON m.markets_code = t.market_code
    WHERE m.markets_code NOT IN ('Mark097', 'Mark999')
    GROUP BY m.markets_code
    ORDER BY revenue_mln DESC;
    """
    export_query_to_csv(cursor, market_query, "market_performance.csv")

    customer_query = """
    SELECT 
        c.customer_code,
        c.custmer_name as customer_name,
        c.customer_type,
        count(t.sales_amount) as total_orders,
        round(sum(case when t.currency='USD' then t.sales_amount*75 else t.sales_amount end)/1000000.0, 2) as revenue_mln,
        round(sum(case when t.currency='USD' then t.profit_margin*75 else t.profit_margin end)/1000000.0, 2) as profit_mln,
        round(sum(case when t.currency='USD' then t.profit_margin*75 else t.profit_margin end) / 
              sum(case when t.currency='USD' then t.sales_amount*75 else t.sales_amount end) * 100, 2) as margin_pct
    FROM customers c
    JOIN transactions t ON c.customer_code = t.customer_code
    GROUP BY c.customer_code
    ORDER BY revenue_mln DESC;
    """
    export_query_to_csv(cursor, customer_query, "customer_performance.csv")

    monthly_query = """
    SELECT 
        d.year,
        d.month_name,
        d.date_yy_mmm,
        count(t.sales_amount) as transactions_count,
        round(sum(case when t.currency='USD' then t.sales_amount*75 else t.sales_amount end)/1000000.0, 2) as revenue_mln,
        round(sum(case when t.currency='USD' then t.profit_margin*75 else t.profit_margin end)/1000000.0, 2) as profit_mln
    FROM transactions t
    JOIN date d ON t.order_date = d.date
    WHERE t.market_code NOT IN ('Mark097', 'Mark999')
    GROUP BY d.date_yy_mmm
    ORDER BY d.year, min(d.date);
    """
    export_query_to_csv(cursor, monthly_query, "monthly_performance.csv")

    print("\n[+] All analytical exports created successfully in 'data_exports/'")
    conn.close()


if __name__ == "__main__":
    run_full_analysis()
