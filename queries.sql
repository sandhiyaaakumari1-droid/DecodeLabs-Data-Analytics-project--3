-- =====================================================================
-- DecodeLabs | Data Analytics | Project 3: SQL Data Analysis
-- Database : orders.db (SQLite)    Table: orders (1,200 rows, 14 columns)
-- Source   : Cleaned_Dataset.xlsx  (output of Project 1)
--
-- Logical execution order of every query below (not the order it is typed):
--   1 FROM  ->  2 WHERE  ->  3 GROUP BY  ->  4 HAVING  ->  5 SELECT  ->  6 ORDER BY
-- Because WHERE and HAVING run before SELECT, they repeat the full expression
-- instead of using an alias (portable SQL). SQLite happens to be lenient about
-- aliases, but MySQL / PostgreSQL / SQL Server are not.
--
-- Each query starts with a "-- @Qnn | Section | Title" tag read by run_sql_analysis.py
-- =====================================================================


-- @Q01 | A. Data overview | Preview the first 10 orders
-- Business question: What does an order record look like?
SELECT OrderID, Date, Product, Quantity, UnitPrice, TotalPrice, OrderStatus
FROM orders
ORDER BY Date, OrderID
LIMIT 10;


-- @Q02 | A. Data overview | Headline business numbers
-- Business question: How big is the business in this dataset?
SELECT COUNT(*)                         AS total_orders,
       COUNT(DISTINCT CustomerID)       AS unique_customers,
       ROUND(SUM(TotalPrice), 2)        AS total_order_value,
       ROUND(AVG(TotalPrice), 2)        AS avg_order_value,
       MIN(TotalPrice)                  AS smallest_order,
       MAX(TotalPrice)                  AS largest_order,
       MIN(Date)                        AS first_order_date,
       MAX(Date)                        AS last_order_date
FROM orders;


-- @Q03 | A. Data overview | Integrity audit: duplicate OrderIDs
-- Business question: Is every OrderID truly unique? (Project 1 gate, re-proved in SQL)
-- Expected result: 0 rows.
SELECT OrderID, COUNT(*) AS occurrences
FROM orders
GROUP BY OrderID
HAVING COUNT(*) > 1;


-- @Q04 | B. Filtering with WHERE | Unusually large orders (above the IQR fence)
-- Business question: Which orders are the extreme high-value ones? ($3,330.41 is the Project 2 IQR upper fence)
SELECT OrderID, Date, Product, Quantity, UnitPrice, TotalPrice, OrderStatus
FROM orders
WHERE TotalPrice > 3330.41
ORDER BY TotalPrice DESC;


-- @Q05 | B. Filtering with WHERE | Delivered 2024 orders that used a coupon
-- Business question: What are the biggest successfully delivered coupon orders of 2024?
SELECT OrderID, Date, Product, CouponCode, TotalPrice
FROM orders
WHERE OrderStatus = 'Delivered'
  AND Date BETWEEN '2024-01-01' AND '2024-12-31'
  AND CouponCode <> 'No Coupon'
ORDER BY TotalPrice DESC
LIMIT 10;


-- @Q06 | B. Filtering with WHERE | Pattern matching with LIKE and IN
-- Business question: How do products starting with "P" sell when paid by card?
SELECT Product, PaymentMethod,
       COUNT(*)                  AS orders,
       ROUND(SUM(TotalPrice), 2) AS order_value
FROM orders
WHERE Product LIKE 'P%'
  AND PaymentMethod IN ('Credit Card', 'Debit Card')
GROUP BY Product, PaymentMethod
ORDER BY order_value DESC;


-- @Q07 | C. GROUP BY and aggregations | Orders, value and average by product
-- Business question: Which products bring in the most order value?
SELECT Product,
       COUNT(*)                                                           AS orders,
       ROUND(SUM(TotalPrice), 2)                                          AS order_value,
       ROUND(AVG(TotalPrice), 2)                                          AS avg_order_value,
       ROUND(100.0 * SUM(TotalPrice) / (SELECT SUM(TotalPrice) FROM orders), 1) AS pct_of_value
FROM orders
GROUP BY Product
ORDER BY order_value DESC;


-- @Q08 | C. GROUP BY and aggregations | Order status mix (percentage contribution)
-- Business question: How much order value sits in each status?
SELECT OrderStatus,
       COUNT(*)                                                           AS orders,
       ROUND(SUM(TotalPrice), 2)                                          AS order_value,
       ROUND(100.0 * SUM(TotalPrice) / (SELECT SUM(TotalPrice) FROM orders), 1) AS pct_of_value
FROM orders
GROUP BY OrderStatus
ORDER BY order_value DESC;


-- @Q09 | C. GROUP BY and aggregations | Revenue at risk (CASE grouping)
-- Business question: What share of order value is delivered, still in flight, or lost to cancellations and returns?
SELECT CASE WHEN OrderStatus IN ('Cancelled', 'Returned') THEN 'At risk (Cancelled or Returned)'
            WHEN OrderStatus = 'Delivered'                THEN 'Delivered'
            ELSE 'In flight (Pending or Shipped)' END                      AS status_group,
       COUNT(*)                                                           AS orders,
       ROUND(SUM(TotalPrice), 2)                                          AS order_value,
       ROUND(100.0 * SUM(TotalPrice) / (SELECT SUM(TotalPrice) FROM orders), 1) AS pct_of_value
FROM orders
GROUP BY status_group
ORDER BY order_value DESC;


-- @Q10 | C. GROUP BY and aggregations | Payment method performance
-- Business question: Does the way customers pay relate to order value?
SELECT PaymentMethod,
       COUNT(*)                  AS orders,
       ROUND(SUM(TotalPrice), 2) AS order_value,
       ROUND(AVG(TotalPrice), 2) AS avg_order_value
FROM orders
GROUP BY PaymentMethod
ORDER BY order_value DESC;


-- @Q11 | C. GROUP BY and aggregations | Referral source performance
-- Business question: Which marketing channels bring orders and value?
SELECT ReferralSource,
       COUNT(*)                  AS orders,
       ROUND(SUM(TotalPrice), 2) AS order_value,
       ROUND(AVG(TotalPrice), 2) AS avg_order_value
FROM orders
GROUP BY ReferralSource
ORDER BY order_value DESC;


-- @Q12 | C. GROUP BY and aggregations | Coupon use versus no coupon
-- Business question: Do orders with a coupon have a different average value?
SELECT CASE WHEN CouponCode = 'No Coupon' THEN 'No coupon' ELSE 'Coupon used' END AS coupon_use,
       COUNT(*)                  AS orders,
       ROUND(SUM(TotalPrice), 2) AS order_value,
       ROUND(AVG(TotalPrice), 2) AS avg_order_value
FROM orders
GROUP BY coupon_use
ORDER BY orders DESC;


-- @Q13 | D. Time trends | Yearly orders and value
-- Business question: How does each calendar year compare? (2025 covers January to June only)
SELECT strftime('%Y', Date)      AS year,
       COUNT(*)                  AS orders,
       ROUND(SUM(TotalPrice), 2) AS order_value,
       ROUND(AVG(TotalPrice), 2) AS avg_order_value
FROM orders
GROUP BY year
ORDER BY year;


-- @Q14 | D. Time trends | First-half revenue, year over year (CTE + window function)
-- Business question: Is like-for-like (Jan to Jun) revenue growing or shrinking?
WITH h1 AS (
    SELECT strftime('%Y', Date) AS year,
           COUNT(*)             AS orders,
           SUM(TotalPrice)      AS revenue
    FROM orders
    WHERE CAST(strftime('%m', Date) AS INTEGER) <= 6
    GROUP BY strftime('%Y', Date)
)
SELECT year,
       orders,
       ROUND(revenue, 2) AS revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY year)) / LAG(revenue) OVER (ORDER BY year), 1) AS yoy_pct
FROM h1
ORDER BY year;


-- @Q15 | D. Time trends | Monthly orders and value
-- Business question: What does the month-by-month pattern look like?
SELECT strftime('%Y-%m', Date)   AS month,
       COUNT(*)                  AS orders,
       ROUND(SUM(TotalPrice), 2) AS order_value
FROM orders
GROUP BY month
ORDER BY month;


-- @Q16 | E. HAVING and subqueries | Products with an above-average cancel/return rate
-- Business question: Which products lose more orders than the business overall?
SELECT Product,
       COUNT(*) AS orders,
       SUM(CASE WHEN OrderStatus IN ('Cancelled', 'Returned') THEN 1 ELSE 0 END) AS at_risk_orders,
       ROUND(100.0 * SUM(CASE WHEN OrderStatus IN ('Cancelled', 'Returned') THEN 1 ELSE 0 END) / COUNT(*), 1) AS at_risk_pct
FROM orders
GROUP BY Product
HAVING 100.0 * SUM(CASE WHEN OrderStatus IN ('Cancelled', 'Returned') THEN 1 ELSE 0 END) / COUNT(*)
       > (SELECT 100.0 * SUM(CASE WHEN OrderStatus IN ('Cancelled', 'Returned') THEN 1 ELSE 0 END) / COUNT(*) FROM orders)
ORDER BY at_risk_pct DESC;


-- @Q17 | E. HAVING and subqueries | Repeat customers
-- Business question: Which customers ordered more than once?
SELECT CustomerID,
       COUNT(*)                  AS orders,
       ROUND(SUM(TotalPrice), 2) AS total_value,
       MIN(Date)                 AS first_order,
       MAX(Date)                 AS last_order
FROM orders
GROUP BY CustomerID
HAVING COUNT(*) > 1
ORDER BY total_value DESC;


-- @Q18 | E. HAVING and subqueries | Orders above the average order value
-- Business question: How many orders are larger than the "average" order?
SELECT COUNT(*)                                                         AS orders_above_average,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders), 1)       AS pct_of_all_orders,
       ROUND((SELECT AVG(TotalPrice) FROM orders), 2)                   AS average_order_value
FROM orders
WHERE TotalPrice > (SELECT AVG(TotalPrice) FROM orders);


-- @Q19 | E. HAVING and subqueries | Median order value in pure SQL
-- Business question: What is the typical (median) order value? SQLite has no MEDIAN(), so the middle row(s) are picked.
SELECT ROUND(AVG(TotalPrice), 2) AS median_order_value
FROM (
    SELECT TotalPrice
    FROM orders
    ORDER BY TotalPrice
    LIMIT 2 - (SELECT COUNT(*) FROM orders) % 2
    OFFSET (SELECT (COUNT(*) - 1) / 2 FROM orders)
);


-- @Q20 | F. Business insight | Cancelled or returned orders by year
-- Business question: Is the cancel/return problem getting better or worse?
SELECT strftime('%Y', Date) AS year,
       COUNT(*)             AS orders,
       SUM(CASE WHEN OrderStatus IN ('Cancelled', 'Returned') THEN 1 ELSE 0 END)                    AS at_risk_orders,
       ROUND(100.0 * SUM(CASE WHEN OrderStatus IN ('Cancelled', 'Returned') THEN 1 ELSE 0 END) / COUNT(*), 1) AS at_risk_pct,
       ROUND(SUM(CASE WHEN OrderStatus IN ('Cancelled', 'Returned') THEN TotalPrice ELSE 0 END), 2) AS at_risk_value
FROM orders
GROUP BY year
ORDER BY year;


-- @Q21 | F. Business insight | What changed in the average order: quantity, price or big orders?
-- Business question: Did customers buy fewer units, pay lower prices, or place fewer large ($2,500+) orders over time?
SELECT strftime('%Y', Date) AS year,
       COUNT(*)             AS orders,
       ROUND(AVG(Quantity), 2)   AS avg_quantity,
       ROUND(AVG(UnitPrice), 2)  AS avg_unit_price,
       ROUND(AVG(TotalPrice), 2) AS avg_order_value,
       SUM(CASE WHEN TotalPrice >= 2500 THEN 1 ELSE 0 END) AS large_orders,
       ROUND(100.0 * SUM(CASE WHEN TotalPrice >= 2500 THEN 1 ELSE 0 END) / COUNT(*), 1) AS large_order_pct
FROM orders
GROUP BY year
ORDER BY year;
