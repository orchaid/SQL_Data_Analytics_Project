
--========================================
-- Change over Time
--========================================

SELECT
    DATE(DATE_TRUNC('month', order_date)) order_month,
    SUM (sales_amount) AS total_revenue,
    SUM(quantity) total_quantity,
    ROUND(AVG(price)),
    COUNT(customer_key) AS Nr_of_customers
FROM
    gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date)
-- Sales were the highest during 2013

--========================================
-- Cumulative Analysis
--========================================

SELECT 
    order_month,
    total_sales,
    SUM(total_sales) OVER(PARTITION BY DATE_TRUNC('year', order_month) ORDER BY order_month) AS rolling_total,
    average_price,
    ROUND(AVG(average_price) OVER (PARTITION BY DATE_TRUNC('year', order_month) ORDER BY order_month)) AS moving_average
FROM (
SELECT
    DATE_TRUNC('month', order_date) order_month,
    SUM(sales_amount) total_sales,
    SUM(quantity) total_quantity,
    ROUND(AVG(price)) average_price
FROM 
    gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date)
)
-- the total sales for each month and the running total of sales over time


--========================================
-- Performance Analysis
--========================================

-- Analyze the yearly production of products by comparing each product's sales 
-- to both its average sales performance and the previous year's sales


WITH yearly_product_sales AS (
SELECT 
    EXTRACT(year FROM order_date) order_year,
    p.product_name,
    SUM(sales_amount) current_sales
FROM 
    gold.fact_sales s
LEFT JOIN gold.dim_products p
    ON p.product_key= s.product_key
WHERE order_date IS NOT NULL
GROUP BY EXTRACT(year FROM order_date), p.product_name
ORDER BY order_year
)
SELECT
    order_year,
    product_name,
    current_sales,
    ROUND(AVG(current_sales) OVER(PARTITION BY product_name)) average_sales,
    current_sales - ROUND(AVG(current_sales) OVER(PARTITION BY product_name)) diff_from_avg,
    CASE WHEN current_sales - ROUND(AVG(current_sales) OVER(PARTITION BY product_name)) < 0 THEN 'below avg'
        WHEN current_sales - ROUND(AVG(current_sales) OVER(PARTITION BY product_name)) > 0 THEN 'above avg'
        else 'no change'
    END change_from_the_avg,
    LAG(current_sales) OVER (PARTITION BY product_name) previous_year_sales,
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name) diff_from_previous_year,
    CASE WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'decrease'
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'increase'
        ELSE 'no change'
    END year_by_year_diff
FROM 
    yearly_product_sales


--========================================
-- Part-to-Whole
--========================================

-- Which category contribute the most to overall sales
WITH sales_by_category AS(
SELECT
    category,
    SUM(sales_amount) total_sales
FROM
    gold.fact_sales s
LEFT JOIN gold.dim_products p
    ON p.product_key = s.product_key
GROUP BY category
)
SELECT 
    category,
    total_sales,
    SUM(total_sales) OVER(),
    CONCAT (ROUND((total_sales / SUM(total_sales) OVER()) * 100, 2), ' %') percentage_of_total 
FROM   
    sales_by_category


--========================================
-- Data Sgmentation
--========================================

-- Segments products into cost ranges and count how many products fall into each segment.
WITH cost_segmentation AS (
SELECT
    product_key, -- will use for the count for performance
    product_name,
    product_cost,
    CASE 
        WHEN product_cost < 100 THEN 'below 100'
        WHEN product_cost < 1000 THEN '100-1000'
        WHEN product_cost > 1000 THEN 'above 1000'
    END segments
FROM
    gold.dim_products
)
SELECT
    segments,
    COUNT(product_key) Nr_of_products
FROM cost_segmentation
GROUP BY segments
ORDER BY Nr_of_products DESC


/* Group customersinto 3 segments based on their spending behavior:
    VIP: customers with at least 10 months of history spending more than 5000
    Regular: customers with at least 10 months of history spending 5000 or less
    New:customers with a lifespan less than 10 months
*/
WITH customer_spending AS (
SELECT 
    SUM(sales_amount) total_spending,
    c.customer_key,
    MIN(order_date) first_order,
    MAX(order_date) last_order,
    (DATE_PART('year', AGE(MAX(order_date), MIN(order_date))) * 12) 
    + DATE_PART('month', AGE(MAX(order_date), MIN(order_date))) AS life_span_months
FROM
    gold.fact_sales s
LEFT JOIN gold.dim_customers c
    ON c.customer_key = s.customer_key
GROUP BY c.customer_key
)

SELECT 
    customer_segments,
    COUNT (customer_key) total_customers
FROM 
(
SELECT
    customer_key,
    total_spending,
    CASE
        WHEN life_span_months >= 10 AND total_spending > 5000 THEN 'VIP'
        WHEN life_span_months >= 10 AND total_spending < 5000 THEN 'Regular'
        WHEN life_span_months < 10 THEN 'New'
    END customer_segments
FROM
    customer_spending
)
GROUP BY customer_segments
