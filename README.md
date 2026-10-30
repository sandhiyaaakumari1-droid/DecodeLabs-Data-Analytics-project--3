# DecodeLabs Data Analytics Track | Project 3: SQL Data Analysis 🗄️

**Author:** Sandhia Kumari  
**Program:** Industrial Training Program | Batch 2026 | DecodeLabs  
**Project Goal:** Use SQL queries to extract business insight from the cleaned orders dataset  

---

## Executive Summary

**Problem statement:** What can structured SQL queries (filter, group, aggregate) tell us about orders, revenue, order status and customers, and do the SQL answers agree with the earlier Python analysis?

**Methodology (IPO framework):**
- **Input:** `Cleaned_Dataset.xlsx` (Project 1 output) loaded into a SQLite table `orders` with PRIMARY KEY, UNIQUE and CHECK constraints
- **Process:** 21 queries in six sections: overview, WHERE filtering, GROUP BY aggregation, time trends, HAVING and subqueries, business insight
- **Output:** results workbook, a PDF report, and a verification step that recomputes 14 key numbers in pandas (14/14 match)

## Key Findings

| # | Headline | Query |
| :--- | :--- | :--- |
| 1 | **41.1% of order value ($519,674) is cancelled or returned.** Only 19.2% is delivered. | Q09 |
| 2 | **First-half revenue fell 10.3% in 2024 and 9.8% in 2025.** | Q14 |
| 3 | **A typical order is $823.62, not $1,053.97.** 40.9% of orders exceed the average. | Q18, Q19 |
| 4 | **No product, payment method, channel or coupon stands out.** Product cancel-rate gaps are consistent with chance (chi-square p = 0.98). | Q07, Q10 to Q12, Q16 |
| 5 | **Only 11 of 1,189 customers ordered twice.** | Q17 |
| 6 | **7 of the 8 largest orders were placed in 2023**, none in 2025 (a lead to monitor, not a conclusion). | Q04, Q21 |

### A sample query

```sql
-- Q09: What share of order value is delivered, in flight, or lost?
SELECT CASE WHEN OrderStatus IN ('Cancelled', 'Returned') THEN 'At risk (Cancelled or Returned)'
            WHEN OrderStatus = 'Delivered'                THEN 'Delivered'
            ELSE 'In flight (Pending or Shipped)' END AS status_group,
       COUNT(*)                                          AS orders,
       ROUND(SUM(TotalPrice), 2)                         AS order_value,
       ROUND(100.0 * SUM(TotalPrice) / (SELECT SUM(TotalPrice) FROM orders), 1) AS pct_of_value
FROM orders
GROUP BY status_group
ORDER BY order_value DESC;
```

| status_group | orders | order_value | pct_of_value |
| :--- | ---: | ---: | ---: |
| At risk (Cancelled or Returned) | 497 | 519,673.91 | 41.1 |
| In flight (Pending or Shipped) | 472 | 502,487.73 | 39.7 |
| Delivered | 231 | 242,600.32 | 19.2 |

## SQL Concepts Covered

| Requirement | Demonstrated with | Queries |
| :--- | :--- | :--- |
| SELECT | Column lists, aliases, DISTINCT, LIMIT | Q01 to Q21 |
| WHERE | `>`, `<>`, BETWEEN, AND, LIKE, IN, date filters | Q04, Q05, Q06, Q14 |
| ORDER BY | ASC / DESC, by aliases and aggregates | Q01, Q04, Q07, Q15 |
| GROUP BY | One column, several columns, computed expressions | Q06 to Q15, Q20, Q21 |
| COUNT, SUM, AVG | Plus MIN, MAX, COUNT(DISTINCT) | Q02, Q07 to Q13, Q21 |
| HAVING | Filtering grouped data | Q03, Q16, Q17 |
| Beyond the brief | CASE, subqueries, CTE with window function (LAG), median in pure SQL | Q09, Q14, Q16, Q18, Q19 |

**Execution order matters.** A query is typed `SELECT, FROM, WHERE, GROUP BY` but executed `FROM, WHERE, GROUP BY, HAVING, SELECT, ORDER BY`. Because WHERE runs before SELECT, the queries repeat the full expression instead of using an alias. SQLite accepts aliases in WHERE (tested), but MySQL, PostgreSQL and SQL Server do not, so this keeps the SQL portable.

## Verification

`run_sql_analysis.py` recomputes 14 key figures with pandas from the same Excel file and compares them with the SQL results: total orders, unique customers, total and average order value, duplicate IDs, large orders, repeat customers, cancelled/returned value and count, median, orders above average, and first-half revenue for 2023, 2024 and 2025. **All 14 match**, and the totals also agree with the Project 2 report.

## Repository Structure

```text
.
├── Cleaned_Dataset.xlsx                 # Input: output of Project 1
├── queries.sql                          # All 21 queries (SQLite)
├── run_sql_analysis.py                  # Builds orders.db, runs queries, verifies, writes outputs
├── orders.db                            # SQLite database (table: orders, 1,200 rows)
├── SQL_Results.xlsx                     # Every query result + Verification sheet
├── sql_results.json                     # Results in JSON
├── SQL_Analysis_Report_Project3.pdf     # Full report with insights
└── README.md                            # This file
```

## How to Reproduce

Requirements: Python 3 with `pandas` and `openpyxl` (SQLite ships with Python).

```bash
py -m pip install pandas openpyxl
py run_sql_analysis.py
```

Keep `run_sql_analysis.py`, `queries.sql` and `Cleaned_Dataset.xlsx` in the same folder. To explore by hand, open `orders.db` in [DB Browser for SQLite](https://sqlitebrowser.org/) or the VS Code SQLite extension and paste any query from `queries.sql`.

## Limitations

- **One table, so no JOIN.** The dataset is a single flat table.
- **SQLite dialect.** `strftime()` and the median pattern are SQLite-specific; other databases use `EXTRACT()`, `DATE_FORMAT()` or `PERCENTILE_CONT()`.
- **Same caveats as Project 2.** Order status, product and channel are unusually evenly spread, and CustomerID is almost never repeated. Confirm both against the source system.
- **SQL describes; it does not prove.** Differences between groups were tested for significance before being called real.

## Tools

SQL (SQLite) for analysis; Python (sqlite3, pandas, openpyxl, SciPy) for loading, verification and the workbook; ReportLab for the PDF.

**Skills demonstrated:** SQL fundamentals, filtering and grouping, aggregation, HAVING, subqueries and CTEs, data validation, and translating query results into business insight.

---

*DecodeLabs | Professional Standard*
