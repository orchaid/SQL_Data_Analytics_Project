
/*
--============================================================================
-- Customer Report
--============================================================================

Purpose:
    - This report consolidates key customer metrics and behaviors

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
    2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
        - total orders
        - total sales
        - total quantity purchased
        - total products
        - lifespan (in months)
    4. Calculates valuable KPIs:
        - recency (months since last order)
        - average order value
        - average monthly spend

==========================================================================
*/

CREATE VIEW gold.report_customers AS 
WITH details AS (
-- 1) retrieve core columns from the table
SELECT 
    CONCAT(c.first_name, ' ' ,c.last_name) full_name,
    EXTRACT(year FROM AGE(current_DATE, c.birth_date)) AS age,
    order_date,
    f.sales_amount,
    f.quantity,
    f.order_number,
    f.product_key,
    c.customer_number
FROM 
    gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
LEFT JOIN gold.dim_products p
    ON f.product_key = p.product_key
WHERE order_date IS NOT NULL
)
-- 2) customer aggregations: summerizing key metrics
, customer_aggregations AS (
SELECT 
    full_name,
    customer_number,
    product_key,
    age,
    SUM(sales_amount) total_sales,
    COUNT(DISTINCT order_number) total_orders,
    SUM(quantity) total_quantity,
    MAX(order_date) last_order,
    EXTRACT (month FROM AGE(MAX(order_date), MIN(order_date))) AS life_span
FROM 
    details
GROUP BY  full_name, customer_number,product_key, age
)
SELECT
    full_name, 
    customer_number, 
    product_key,
    age,
    CASE WHEN age < 21 then 'teen'
        WHEN age between 21 and 45 THEN'young'
        WHEN age > 45 THEN 'old'
    END age_segments,
    CASE WHEN total_sales > 5000 AND life_span >= 10  THEN 'VIP'
        WHEN total_sales <= 5000 AND life_span >= 10 THEN 'Regular'
        WHEN life_span < 10 AND total_sales < 1000 THEN 'new'
    END customer_segments,
    total_sales,
    total_orders,
    total_quantity,
    (DATE_PART('year', AGE(current_DATE, last_order)) * 12) 
    + DATE_PART('month', AGE(current_DATE, last_order)) AS recency,
    CASE WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders 
    END AS average_order_value, -- (AVO)
    CASE WHEN life_span = 0 THEN 0
        ELSE ROUND(total_sales / life_span) 
    END AS average_monthly_spending
FROM 
    customer_aggregations




/*
--============================================================================
Product Report
--============================================================================

Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
1. Gathers essential fields such as product name, category, subcategory, and cost.
2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
3. Aggregates product-level metrics:
    - total orders
    - total sales
    - total quantity sold
    - total customers (unique)
    - lifespan (in months)
4. Calculates valuable KPIs:
    - recency (months since last sale)
    - average order revenue (AOR)
    - average monthly revenue
============================================================
*/
CREATE VIEW gold.report_products AS
WITH product_details AS (
SELECT
    f.customer_key,
    f.order_number,
    f.product_key,
    p.category,
    p.subcategory,
    p.product_name,
    f.sales_amount,
    p.product_cost,
    f.quantity,
    f.order_date
FROM
    gold.fact_sales f
LEFT JOIN
    gold.dim_products p
    ON p.product_key = f.product_key
)

, aggregation_product AS (
SELECT
    category,
    subcategory,
    product_name,
    COUNT(DISTINCT order_number) total_orders,
    COUNT(DISTINCT customer_key) total_customers,
    SUM(sales_amount) total_sales,
    ROUND(AVG(product_cost)) average_cost,
    ROUND(AVG(sales_amount/ NULLIF(quantity,0))) average_price,
    MAX(order_date) last_order,
    (DATE_PART('year', AGE(MAX(order_date), MIN(order_date))) * 12) 
    + DATE_PART('month', AGE(MAX(order_date), MIN(order_date))) AS life_span

FROM
    product_details
GROUP BY
    category,
    subcategory,
    product_name
)

SELECT
    category,
    subcategory,
    product_name,
    CASE 
        WHEN total_sales > 30000 THEN 'High-Performance'
        WHEN total_sales BETWEEN 20000 AND 30000 THEN 'Mid Range'
        WHEN total_sales < 2000 THEN 'Low-performance'
    END AS product_segment,
    (DATE_PART('year', AGE(current_DATE, last_order)) * 12) 
    + DATE_PART('month', AGE(current_DATE, last_order)) AS recency,
    CASE WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders 
    END AS average_order_revenue, -- (AOR)
    CASE WHEN life_span = 0 THEN 0
        ELSE ROUND(total_sales / life_span) 
    END AS average_monthly_revenue,
    total_orders,
    total_customers,
    total_sales,
    average_cost,
    average_price
FROM 
    aggregation_product;



DROP VIEW IF EXISTS gold.report_customers;
DROP VIEW IF EXISTS gold.report_products;



