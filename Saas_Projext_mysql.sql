-- ============================================================
-- SAAS CUSTOMER & REVENUE ANALYTICS PROJECT
-- SQL DATABASE: SAAS
-- ============================================================


-- ============================================================
-- DATABASE SETUP
-- ============================================================

CREATE DATABASE IF NOT EXISTS saas;

USE saas;

SHOW TABLES;

-- View table structures
DESC customers;
DESC subs;
DESC revenue;

-- View sample data
SELECT * FROM customers;
SELECT * FROM subs;
SELECT * FROM revenue;



-- ============================================================
-- Q1. SHOW THE COMPLETE CUSTOMER DATASET
-- ============================================================
-- Objective:
-- Retrieve all customer records to understand the available
-- customer information and dataset structure.
-- ============================================================

SELECT *
FROM customers;



-- ============================================================
-- Q2. WHAT IS THE TOTAL NUMBER OF CUSTOMERS BY PLAN TYPE?
-- ============================================================
-- Objective:
-- Calculate the total number of customers subscribed to
-- each SaaS plan and identify the most popular plans.
-- ============================================================

SELECT 
    plan_type,
    COUNT(*) AS total_customers
FROM customers
GROUP BY plan_type
ORDER BY total_customers DESC;



-- ============================================================
-- Q3. HOW MANY CUSTOMERS ARE ACTIVE VS CHURNED?
-- ============================================================
-- Objective:
-- Classify customers as Active or Churned based on whether
-- they have a churn date.
-- ============================================================

SELECT 
    CASE 
        WHEN churn_date IS NULL THEN 'Active User'
        ELSE 'Churned User'
    END AS user_status,
    COUNT(*) AS total_users
FROM customers
GROUP BY user_status;



-- ============================================================
-- Q4. HOW MANY NEW CUSTOMERS SIGNED UP EACH MONTH?
-- ============================================================
-- Objective:
-- Analyze monthly customer acquisition and identify customer
-- growth trends over time.
-- ============================================================

SELECT 
    DATE_FORMAT(signup_date, '%Y-%b') AS signup_month,
    COUNT(*) AS total_customers
FROM customers
GROUP BY signup_month;



-- ============================================================
-- Q5. WHAT IS THE CHURN RATE BY PLAN TYPE?
-- ============================================================
-- Objective:
-- Calculate total customers, churned customers, and churn
-- percentage for each subscription plan.
-- ============================================================

SELECT 
    plan_type,
    COUNT(*) AS total_users,

    SUM(
        CASE 
            WHEN churn_date IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS churn_users,

    ROUND(
        SUM(
            CASE 
                WHEN churn_date IS NOT NULL THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS churn_percentage

FROM customers
GROUP BY plan_type
ORDER BY churn_percentage DESC;



-- ============================================================
-- Q6. WHAT IS THE AVERAGE AND TOTAL ACQUISITION COST BY PLAN?
-- ============================================================
-- Objective:
-- Calculate the total and average Customer Acquisition Cost
-- (CAC) for each plan type.
-- ============================================================

SELECT 
    plan_type,
    SUM(acquisition_cost) AS total_acquisition_cost,
    ROUND(AVG(acquisition_cost), 2) AS average_acquisition_cost
FROM customers
GROUP BY plan_type
ORDER BY total_acquisition_cost DESC;



-- ============================================================
-- Q7. WHAT ARE THE MONTHLY SUBSCRIPTION FEES BILLED?
-- ============================================================
-- Objective:
-- Create a stored procedure that accepts a year as input
-- and calculates monthly subscription fees billed.
-- ============================================================

DELIMITER //

CREATE PROCEDURE year_monthlybills(IN y INT)
BEGIN

    SELECT 
        DATE_FORMAT(signup_date, '%b-%Y') AS month_year,
        COUNT(DISTINCT customer_id) AS total_customers,
        SUM(monthly_fee) AS total_monthly_fees
    FROM customers
    WHERE YEAR(signup_date) = y
    GROUP BY 
        YEAR(signup_date),
        MONTH(signup_date)
    ORDER BY 
        YEAR(signup_date),
        MONTH(signup_date);

END //

DELIMITER ;


-- Execute stored procedure
CALL year_monthlybills(2024);



-- ============================================================
-- Q8. WHAT ARE THE SUBSCRIPTION DETAILS OF EACH CUSTOMER?
-- ============================================================
-- Objective:
-- Join the customers and subscriptions tables to display
-- customer and subscription-level information.
-- ============================================================

SELECT 
    c.customer_id,
    c.plan_type,
    c.signup_date,
    s.subscription_id,
    s.month_year AS active_month,
    s.monthly_fee
FROM customers c
JOIN subs s
    ON c.customer_id = s.customer_id
ORDER BY c.customer_id ASC;



-- ============================================================
-- Q9. WHAT IS THE TOTAL REVENUE COLLECTED BY EACH PLAN TYPE?
-- ============================================================
-- Objective:
-- Calculate the total number of customers and total revenue
-- generated by each subscription plan.
-- ============================================================

SELECT 
    c.plan_type,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    SUM(r.amount) AS total_revenue
FROM customers c
JOIN revenue r
    ON c.customer_id = r.customer_id
GROUP BY c.plan_type
ORDER BY total_revenue DESC;



-- ============================================================
-- Q10. WHAT IS THE MONTHLY RECURRING REVENUE (MRR) TREND?
-- ============================================================
-- Objective:
-- Calculate total revenue generated in each month and analyze
-- the Monthly Recurring Revenue trend.
-- ============================================================

SELECT 
    `month` AS month_year,
    SUM(amount) AS MRR
FROM revenue
GROUP BY `month`
ORDER BY `month`;



-- ============================================================
-- Q11. WHAT IS THE CUSTOMER LIFETIME VALUE (LTV) VS CAC?
-- ============================================================
-- Objective:
-- Calculate Customer Acquisition Cost (CAC), Lifetime Value
-- (LTV), and Net Value for each customer.
--
-- Formula:
-- Net Value = LTV - CAC
-- ============================================================

SELECT 
    c.customer_id,
    c.plan_type,
    c.acquisition_cost AS customer_acquisition_cost,
    SUM(r.amount) AS lifetime_value,
    SUM(r.amount) - c.acquisition_cost AS net_value
FROM customers c
JOIN revenue r
    ON c.customer_id = r.customer_id
GROUP BY 
    c.customer_id,
    c.plan_type,
    c.acquisition_cost;



-- ============================================================
-- Q12. ARE SUBSCRIPTION FEES AND REVENUE AMOUNTS MATCHING?
-- ============================================================
-- Objective:
-- Compare subscription fees with actual revenue amounts
-- and identify billing discrepancies.
-- ============================================================

SELECT 
    s.subscription_id,
    s.customer_id,
    s.month_year,
    s.monthly_fee AS subscription_fee,
    r.amount AS revenue_amount,
    s.monthly_fee - r.amount AS discrepancy
FROM subs s
JOIN revenue r
    ON s.subscription_id = r.subscription_id
WHERE s.monthly_fee <> r.amount
ORDER BY discrepancy DESC;



-- ============================================================
-- Q13. WHAT IS THE FULL CUSTOMER BUSINESS PROFILE?
-- ============================================================
-- Objective:
-- Create a complete customer-level summary containing:
-- Customer details, plan, signup/churn dates, active months,
-- CAC, and total revenue.
-- ============================================================

SELECT 
    c.customer_id,
    c.plan_type,
    c.signup_date,
    c.churn_date,
    COALESCE(s.active_month, 0) AS active_month,
    c.acquisition_cost,
    COALESCE(r.total_revenue, 0) AS total_revenue

FROM customers c

LEFT JOIN (
    SELECT 
        customer_id,
        COUNT(DISTINCT subscription_id) AS active_month
    FROM subs
    GROUP BY customer_id
) s
    ON c.customer_id = s.customer_id

LEFT JOIN (
    SELECT 
        customer_id,
        SUM(amount) AS total_revenue
    FROM revenue
    GROUP BY customer_id
) r
    ON c.customer_id = r.customer_id;



-- ============================================================
-- Q14. WHAT IS THE ARPU BY PLAN TYPE PER MONTH?
-- ============================================================
-- Objective:
-- Calculate Active Users, Total MRR, and Average Revenue
-- Per User (ARPU) by plan and month.
--
-- Formula:
-- ARPU = Total Revenue / Active Users
-- ============================================================

SELECT 
    c.plan_type,
    r.year_Mnth,
    COUNT(DISTINCT c.customer_id) AS active_users,
    SUM(r.amount) AS total_MRR,

    ROUND(
        SUM(r.amount) / COUNT(DISTINCT c.customer_id),
        2
    ) AS average_revenue_per_user

FROM customers c
JOIN revenue r
    ON c.customer_id = r.customer_id

GROUP BY 
    c.plan_type,
    r.year_Mnth

ORDER BY 
    r.year_Mnth,
    c.plan_type;



-- ============================================================
-- Q15. HOW MANY MONTHS DOES IT TAKE TO RECOVER CAC?
-- ============================================================
-- Objective:
-- Calculate the CAC Payback Period for each customer.
--
-- Formula:
-- Payback Months = CAC / Monthly Fee
-- ============================================================

SELECT 
    customer_id,
    plan_type,
    monthly_fee,
    acquisition_cost AS CAC,

    ROUND(
        acquisition_cost / NULLIF(monthly_fee, 0),
        2
    ) AS payback_months

FROM customers;



-- ============================================================
-- Q16. WHAT IS THE REVENUE PERFORMANCE OF SIGNUP COHORTS?
-- ============================================================
-- Objective:
-- Group customers based on their signup month and plan type
-- and analyze their cohort size and total revenue.
-- ============================================================

SELECT 
    DATE_FORMAT(c.signup_date, '%Y-%b') AS signup_cohort,
    c.plan_type,
    COUNT(DISTINCT c.customer_id) AS cohort_size,
    SUM(r.amount) AS total_revenue

FROM customers c
JOIN revenue r
    ON c.customer_id = r.customer_id

GROUP BY 
    YEAR(c.signup_date),
    MONTH(c.signup_date),
    c.plan_type

ORDER BY 
    YEAR(c.signup_date),
    MONTH(c.signup_date),
    c.plan_type;



-- ============================================================
-- Q17. WHAT IS THE LTV AND NET PROFIT OF CHURNED CUSTOMERS?
-- ============================================================
-- Objective:
-- Analyze churned customers by calculating their customer
-- lifetime, LTV, CAC, and Net Profit.
--
-- Formula:
-- Net Profit = LTV - CAC
-- ============================================================

SELECT 
    c.customer_id,
    c.plan_type,
    c.signup_date,
    c.churn_date,

    DATEDIFF(
        c.churn_date,
        c.signup_date
    ) AS days_as_customer,

    SUM(r.amount) AS LTV,

    c.acquisition_cost AS CAC,

    SUM(r.amount) - c.acquisition_cost AS net_profit

FROM customers c
JOIN revenue r
    ON c.customer_id = r.customer_id

WHERE c.churn_date IS NOT NULL

GROUP BY 
    c.customer_id,
    c.plan_type,
    c.signup_date,
    c.churn_date,
    c.acquisition_cost;



-- ============================================================
-- Q18. RANK CUSTOMERS BY TOTAL REVENUE
-- ============================================================
-- Objective:
-- Rank all customers based on their total lifetime revenue
-- from highest to lowest using the DENSE_RANK() window function.
-- ============================================================

WITH customer_rank AS (

    SELECT 
        c.customer_id,
        c.plan_type,
        SUM(r.amount) AS total_revenue

    FROM customers c

    JOIN revenue r
        ON c.customer_id = r.customer_id

    GROUP BY 
        c.customer_id,
        c.plan_type
)

SELECT 
    *,
    DENSE_RANK() OVER (
        ORDER BY total_revenue DESC
    ) AS revenue_rank

FROM customer_rank

ORDER BY revenue_rank;



-- ============================================================
-- Q19. RANK CUSTOMERS WITHIN EACH PLAN
-- ============================================================
-- Objective:
-- Rank customers based on their total revenue within each
-- subscription plan using PARTITION BY.
-- ============================================================

WITH customer_rank AS (

    SELECT 
        c.customer_id,
        c.plan_type,
        SUM(r.amount) AS total_revenue

    FROM customers c

    JOIN revenue r
        ON c.customer_id = r.customer_id

    GROUP BY 
        c.customer_id,
        c.plan_type
)

SELECT 
    *,
    DENSE_RANK() OVER (
        PARTITION BY plan_type
        ORDER BY total_revenue DESC
    ) AS plan_revenue_rank

FROM customer_rank

ORDER BY 
    plan_type,
    plan_revenue_rank;



-- ============================================================
-- Q20. WHAT IS THE MONTHLY AND RUNNING REVENUE?
-- ============================================================
-- Objective:
-- Calculate monthly revenue and cumulative running revenue
-- using a CTE and Window Function.
-- ============================================================

WITH monthly_rev AS (

    SELECT 
        year_Mnth,
        SUM(amount) AS monthly_revenue

    FROM revenue

    GROUP BY year_Mnth
)

SELECT 
    year_Mnth,
    monthly_revenue,

    SUM(monthly_revenue) OVER (
        ORDER BY year_Mnth
    ) AS running_revenue

FROM monthly_rev

ORDER BY year_Mnth;