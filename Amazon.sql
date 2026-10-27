CREATE DATABASE IF NOT EXISTS amazon_sales;
USE amazon_sales;

SHOW DATABASES LIKE 'amazon_sales';
SHOW TABLES FROM amazon_sales;

CREATE TABLE amazon_sales.stg_customer (
    C_ID           VARCHAR(30),
    C_Name         VARCHAR(200),
    Gender         VARCHAR(30),
    Age            VARCHAR(20),
    City           VARCHAR(100),
    State          VARCHAR(100),
    Street_Address VARCHAR(300),
    Mobile         VARCHAR(30)
);

SELECT COUNT(*) AS staged_rows
FROM amazon_sales.stg_customer;

SELECT COUNT(*) AS duplicate_rows
FROM (
    SELECT C_ID, C_Name, Gender, Age, City, State, Street_Address, Mobile
    FROM amazon_sales.stg_customer
    GROUP BY C_ID, C_Name, Gender, Age, City, State, Street_Address, Mobile
    HAVING COUNT(*) > 1
) AS duplicates;

CREATE TABLE amazon_sales.dim_customer (
    C_ID           VARCHAR(30) NOT NULL,
    C_Name         VARCHAR(200),
    Gender         VARCHAR(30),
    Age            TINYINT UNSIGNED,
    City           VARCHAR(100),
    State          VARCHAR(100),
    Street_Address VARCHAR(300),
    Mobile         VARCHAR(30),
    PRIMARY KEY (C_ID)
);

INSERT INTO amazon_sales.dim_customer
    (C_ID, C_Name, Gender, Age, City, State, Street_Address, Mobile)
SELECT DISTINCT
    C_ID, C_Name, Gender, CAST(Age AS UNSIGNED),
    City, State, Street_Address, Mobile
FROM amazon_sales.stg_customer;

SELECT
    COUNT(*) AS customer_rows,
    COUNT(DISTINCT C_ID) AS unique_customer_ids
FROM amazon_sales.dim_customer;

CREATE TABLE IF NOT EXISTS amazon_sales.stg_delivery (
    DP_ID VARCHAR(30), DP_Name VARCHAR(200), DP_Ratings VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS amazon_sales.stg_orders (
    Or_ID VARCHAR(30), C_ID VARCHAR(30), P_ID VARCHAR(30),
    Order_Date VARCHAR(30), Order_Time VARCHAR(30),
    Qty VARCHAR(20), Coupon VARCHAR(200), DP_ID VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS amazon_sales.stg_products (
    P_ID VARCHAR(30), PName VARCHAR(250), Category VARCHAR(100),
    Specs1 VARCHAR(300), Price VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS amazon_sales.stg_ratings (
    R_ID VARCHAR(30), Or_ID VARCHAR(30),
    Prod_Rating VARCHAR(20), Delivery_Service_Rating VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS amazon_sales.stg_returns (
    RT_ID VARCHAR(30), Or_ID VARCHAR(30), Reason VARCHAR(200),
    Return_Refund VARCHAR(30), Date VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS amazon_sales.stg_subscription_details (
    SD_ID VARCHAR(30), C_ID VARCHAR(30), Plan_ID VARCHAR(30),
    From_Date VARCHAR(30), To_Date VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS amazon_sales.stg_subscription_plan (
    Plan_ID VARCHAR(30), Plan_Name VARCHAR(100), Features VARCHAR(500)
);

CREATE TABLE IF NOT EXISTS amazon_sales.stg_transactions (
    Tr_ID VARCHAR(30), Or_ID VARCHAR(30),
    Transaction_Mode VARCHAR(100), Tran_Status VARCHAR(50)
);

SELECT 'stg_customer' AS table_name, COUNT(*) AS actual_rows, 10184 AS expected_rows
FROM amazon_sales.stg_customer
UNION ALL
SELECT 'stg_delivery', COUNT(*), 325 FROM amazon_sales.stg_delivery
UNION ALL
SELECT 'stg_orders', COUNT(*), 10000 FROM amazon_sales.stg_orders
UNION ALL
SELECT 'stg_products', COUNT(*), 10000 FROM amazon_sales.stg_products
UNION ALL
SELECT 'stg_ratings', COUNT(*), 10000 FROM amazon_sales.stg_ratings
UNION ALL
SELECT 'stg_returns', COUNT(*), 2000 FROM amazon_sales.stg_returns
UNION ALL
SELECT 'stg_subscription_details', COUNT(*), 10036 FROM amazon_sales.stg_subscription_details
UNION ALL
SELECT 'stg_subscription_plan', COUNT(*), 3 FROM amazon_sales.stg_subscription_plan
UNION ALL
SELECT 'stg_transactions', COUNT(*), 10000 FROM amazon_sales.stg_transactions;

CREATE TABLE amazon_sales.dim_product (
    P_ID     VARCHAR(30) NOT NULL,
    PName    VARCHAR(250) NOT NULL,
    Category VARCHAR(100) NOT NULL,
    Specs1   VARCHAR(300),
    Price    DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (P_ID)
);

INSERT INTO amazon_sales.dim_product
    (P_ID, PName, Category, Specs1, Price)
SELECT
    P_ID,
    COALESCE(NULLIF(TRIM(PName), ''), 'Unknown Product'),
    Category,
    Specs1,
    CAST(NULLIF(TRIM(Price), '') AS DECIMAL(10,2))
FROM amazon_sales.stg_products;

SELECT
    COUNT(*) AS product_rows,
    COUNT(DISTINCT P_ID) AS unique_product_ids,
    SUM(PName = 'Unknown Product') AS unknown_names
FROM amazon_sales.dim_product;

CREATE TABLE amazon_sales.dim_delivery (
    DP_ID      VARCHAR(30) NOT NULL,
    DP_Name    VARCHAR(200),
    DP_Ratings DECIMAL(2,1) NULL,
    PRIMARY KEY (DP_ID)
);

INSERT INTO amazon_sales.dim_delivery
    (DP_ID, DP_Name, DP_Ratings)
SELECT DISTINCT
    DP_ID,
    DP_Name,
    CAST(NULLIF(TRIM(DP_Ratings), '') AS DECIMAL(2,1))
FROM amazon_sales.stg_delivery;

SELECT
    COUNT(*) AS delivery_rows,
    COUNT(DISTINCT DP_ID) AS unique_delivery_ids,
    SUM(DP_Ratings IS NULL) AS missing_ratings
FROM amazon_sales.dim_delivery;

CREATE TABLE amazon_sales.fact_orders (
    Or_ID               VARCHAR(30) NOT NULL,
    C_ID                VARCHAR(30) NOT NULL,
    P_ID                VARCHAR(30) NOT NULL,
    DP_ID               VARCHAR(30) NOT NULL,
    Order_Date          DATE NOT NULL,
    Order_Time          TIME,
    Qty                 SMALLINT UNSIGNED NOT NULL,
    Coupon              VARCHAR(200),
    Unit_Price          DECIMAL(10,2) NOT NULL,
    Gross_Sales_Proxy   DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (Or_ID),
    INDEX idx_fact_orders_date (Order_Date),
    FOREIGN KEY (C_ID) REFERENCES amazon_sales.dim_customer(C_ID),
    FOREIGN KEY (P_ID) REFERENCES amazon_sales.dim_product(P_ID),
    FOREIGN KEY (DP_ID) REFERENCES amazon_sales.dim_delivery(DP_ID)
);

SELECT Or_ID, Order_Date, Order_Time, Qty, Coupon, DP_ID
FROM amazon_sales.stg_orders
LIMIT 10;

SELECT
    Order_Time,
    CAST(NULLIF(TRIM(Order_Time), '') AS TIME) AS parsed_time,
    Qty,
    CAST(NULLIF(TRIM(Qty), '') AS UNSIGNED) AS parsed_qty
FROM amazon_sales.stg_orders
LIMIT 10;

SHOW CREATE TABLE amazon_sales.fact_orders;

SELECT
    Order_Time,
    STR_TO_DATE(NULLIF(TRIM(Order_Time), ''), '%H:%i:%s') AS parsed_time
FROM amazon_sales.stg_orders
LIMIT 10;

INSERT INTO amazon_sales.fact_orders
    (Or_ID, C_ID, P_ID, DP_ID, Order_Date, Order_Time,
     Qty, Coupon, Unit_Price, Gross_Sales_Proxy)
SELECT
    o.Or_ID,
    o.C_ID,
    o.P_ID,
    o.DP_ID,
    STR_TO_DATE(NULLIF(TRIM(o.Order_Date), ''), '%Y-%m-%d'),
    STR_TO_DATE(NULLIF(TRIM(o.Order_Time), ''), '%H:%i:%s'),
    CAST(NULLIF(TRIM(o.Qty), '') AS UNSIGNED),
    COALESCE(NULLIF(TRIM(o.Coupon), ''), 'No Coupon'),
    p.Price,
    CAST(NULLIF(TRIM(o.Qty), '') AS UNSIGNED) * p.Price
FROM amazon_sales.stg_orders AS o
JOIN amazon_sales.dim_product AS p
    ON p.P_ID = o.P_ID;
    
SELECT
    COUNT(*) AS order_rows,
    COUNT(DISTINCT Or_ID) AS unique_orders,
    SUM(Qty) AS total_units,
    ROUND(SUM(Gross_Sales_Proxy), 2) AS gross_sales_proxy
FROM amazon_sales.fact_orders;

CREATE TABLE amazon_sales.fact_transactions (
    Tr_ID           VARCHAR(30) NOT NULL,
    Or_ID           VARCHAR(30) NOT NULL,
    Transaction_Mode VARCHAR(100) NOT NULL,
    Tran_Status     VARCHAR(50) NOT NULL,
    PRIMARY KEY (Tr_ID),
    INDEX idx_transactions_order (Or_ID),
    FOREIGN KEY (Or_ID) REFERENCES amazon_sales.fact_orders(Or_ID)
);

INSERT INTO amazon_sales.fact_transactions
    (Tr_ID, Or_ID, Transaction_Mode, Tran_Status)
SELECT
    Tr_ID,
    Or_ID,
    COALESCE(NULLIF(TRIM(Transaction_Mode), ''), 'Unknown'),
    TRIM(Tran_Status)
FROM amazon_sales.stg_transactions;

SELECT
    COUNT(*) AS transaction_attempts,
    COUNT(DISTINCT Tr_ID) AS unique_transaction_ids,
    SUM(Transaction_Mode = 'Unknown') AS unknown_modes
FROM amazon_sales.fact_transactions;

SELECT Tran_Status, COUNT(*) AS attempts
FROM amazon_sales.fact_transactions
GROUP BY Tran_Status;

CREATE TABLE amazon_sales.fact_ratings (
    R_ID                     VARCHAR(30) NOT NULL,
    Or_ID                    VARCHAR(30) NOT NULL,
    Prod_Rating              DECIMAL(2,1) NULL,
    Delivery_Service_Rating  DECIMAL(2,1) NULL,
    PRIMARY KEY (R_ID),
    INDEX idx_ratings_order (Or_ID),
    FOREIGN KEY (Or_ID) REFERENCES amazon_sales.fact_orders(Or_ID)
);

INSERT INTO amazon_sales.fact_ratings
    (R_ID, Or_ID, Prod_Rating, Delivery_Service_Rating)
SELECT
    R_ID,
    Or_ID,
    CAST(NULLIF(TRIM(Prod_Rating), '') AS DECIMAL(2,1)),
    CAST(NULLIF(TRIM(Delivery_Service_Rating), '') AS DECIMAL(2,1))
FROM amazon_sales.stg_ratings;

SELECT
    COUNT(*) AS rating_rows,
    COUNT(DISTINCT R_ID) AS unique_rating_ids,
    SUM(Prod_Rating IS NULL) AS missing_product_ratings,
    SUM(Delivery_Service_Rating IS NULL) AS missing_service_ratings
FROM amazon_sales.fact_ratings;

CREATE TABLE amazon_sales.fact_returns (
    RT_ID          VARCHAR(30) NOT NULL,
    Or_ID          VARCHAR(30) NOT NULL,
    Reason         VARCHAR(200) NOT NULL,
    Return_Refund  VARCHAR(30) NOT NULL,
    Return_Date    DATE NOT NULL,
    PRIMARY KEY (RT_ID),
    INDEX idx_returns_order (Or_ID),
    FOREIGN KEY (Or_ID) REFERENCES amazon_sales.fact_orders(Or_ID)
);

INSERT INTO amazon_sales.fact_returns
    (RT_ID, Or_ID, Reason, Return_Refund, Return_Date)
SELECT
    RT_ID,
    Or_ID,
    TRIM(Reason),
    TRIM(Return_Refund),
    STR_TO_DATE(NULLIF(TRIM(Date), ''), '%Y-%m-%d')
FROM amazon_sales.stg_returns;

SELECT
    COUNT(*) AS return_records,
    COUNT(DISTINCT RT_ID) AS unique_return_ids,
    COUNT(DISTINCT Or_ID) AS affected_orders,
    MIN(Return_Date) AS first_return_date,
    MAX(Return_Date) AS last_return_date
FROM amazon_sales.fact_returns;

CREATE TABLE amazon_sales.dim_subscription_plan (
    Plan_ID   VARCHAR(30) NOT NULL,
    Plan_Name VARCHAR(100) NOT NULL,
    Features  VARCHAR(500),
    PRIMARY KEY (Plan_ID)
);

INSERT INTO amazon_sales.dim_subscription_plan
    (Plan_ID, Plan_Name, Features)
SELECT DISTINCT
    Plan_ID,
    TRIM(Plan_Name),
    TRIM(Features)
FROM amazon_sales.stg_subscription_plan;

SELECT COUNT(*) AS plan_rows, COUNT(DISTINCT Plan_ID) AS unique_plan_ids
FROM amazon_sales.dim_subscription_plan;

CREATE TABLE amazon_sales.fact_subscriptions (
    SD_ID                VARCHAR(30) NOT NULL,
    C_ID                 VARCHAR(30) NOT NULL,
    Plan_ID              VARCHAR(30) NOT NULL,
    Start_Date           DATE NOT NULL,
    End_Date             DATE NOT NULL,
    Invalid_Date_Range   BOOLEAN NOT NULL,
    PRIMARY KEY (SD_ID),
    INDEX idx_subscriptions_customer (C_ID),
    INDEX idx_subscriptions_plan (Plan_ID),
    FOREIGN KEY (C_ID) REFERENCES amazon_sales.dim_customer(C_ID),
    FOREIGN KEY (Plan_ID) REFERENCES amazon_sales.dim_subscription_plan(Plan_ID)
);

INSERT INTO amazon_sales.fact_subscriptions
    (SD_ID, C_ID, Plan_ID, Start_Date, End_Date, Invalid_Date_Range)
SELECT
    SD_ID,
    C_ID,
    Plan_ID,
    STR_TO_DATE(NULLIF(TRIM(From_Date), ''), '%Y-%m-%d'),
    STR_TO_DATE(NULLIF(TRIM(To_Date), ''), '%Y-%m-%d'),
    STR_TO_DATE(NULLIF(TRIM(To_Date), ''), '%Y-%m-%d')
        < STR_TO_DATE(NULLIF(TRIM(From_Date), ''), '%Y-%m-%d')
FROM amazon_sales.stg_subscription_details;

SELECT
    COUNT(*) AS subscription_rows,
    SUM(Invalid_Date_Range) AS invalid_date_ranges,
    COUNT(*) - SUM(Invalid_Date_Range) AS valid_date_ranges
FROM amazon_sales.fact_subscriptions;

SELECT 'dim_customer' AS table_name, COUNT(*) AS actual_rows, 10000 AS expected_rows
FROM amazon_sales.dim_customer
UNION ALL
SELECT 'dim_product', COUNT(*), 10000 FROM amazon_sales.dim_product
UNION ALL
SELECT 'dim_delivery', COUNT(*), 300 FROM amazon_sales.dim_delivery
UNION ALL
SELECT 'dim_subscription_plan', COUNT(*), 3 FROM amazon_sales.dim_subscription_plan
UNION ALL
SELECT 'fact_orders', COUNT(*), 10000 FROM amazon_sales.fact_orders
UNION ALL
SELECT 'fact_transactions', COUNT(*), 10000 FROM amazon_sales.fact_transactions
UNION ALL
SELECT 'fact_ratings', COUNT(*), 10000 FROM amazon_sales.fact_ratings
UNION ALL
SELECT 'fact_returns', COUNT(*), 2000 FROM amazon_sales.fact_returns
UNION ALL
SELECT 'fact_subscriptions', COUNT(*), 10036 FROM amazon_sales.fact_subscriptions;

SELECT
    DATE_FORMAT(Order_Date, '%Y-%m-01') AS Month,
    COUNT(*) AS Orders,
    SUM(Qty) AS Units,
    ROUND(SUM(Gross_Sales_Proxy), 2) AS Gross_Sales_Proxy
FROM amazon_sales.fact_orders
GROUP BY DATE_FORMAT(Order_Date, '%Y-%m-01')
ORDER BY Month;

SELECT
    p.Category,
    COUNT(*) AS Orders,
    SUM(o.Qty) AS Units,
    ROUND(SUM(o.Gross_Sales_Proxy), 2) AS Gross_Sales_Proxy,
    COUNT(DISTINCT o.P_ID) AS Products,
    ROUND(
        100 * SUM(o.Gross_Sales_Proxy) /
        (SELECT SUM(Gross_Sales_Proxy) FROM amazon_sales.fact_orders),
        1
    ) AS Sales_Share_Pct
FROM amazon_sales.fact_orders AS o
JOIN amazon_sales.dim_product AS p
    ON p.P_ID = o.P_ID
GROUP BY p.Category
ORDER BY Gross_Sales_Proxy DESC;

SELECT
    c.State,
    COUNT(*) AS Orders,
    COUNT(DISTINCT o.C_ID) AS Customers,
    SUM(o.Qty) AS Units,
    ROUND(SUM(o.Gross_Sales_Proxy), 2) AS Gross_Sales_Proxy,
    ROUND(AVG(o.Gross_Sales_Proxy), 2) AS Avg_Order_Value_Proxy,
    ROUND(
        100 * SUM(o.Gross_Sales_Proxy) /
        (SELECT SUM(Gross_Sales_Proxy) FROM amazon_sales.fact_orders),
        1
    ) AS Sales_Share_Pct
FROM amazon_sales.fact_orders AS o
JOIN amazon_sales.dim_customer AS c
    ON c.C_ID = o.C_ID
GROUP BY c.State
ORDER BY Gross_Sales_Proxy DESC;

SELECT
    Transaction_Mode,
    Tran_Status,
    COUNT(*) AS Transaction_Attempts,
    COUNT(DISTINCT Or_ID) AS Distinct_Orders
FROM amazon_sales.fact_transactions
GROUP BY Transaction_Mode, Tran_Status
ORDER BY Transaction_Mode, Tran_Status;

SELECT
    Return_Refund,
    Reason,
    COUNT(*) AS Return_Records,
    COUNT(DISTINCT Or_ID) AS Affected_Orders
FROM amazon_sales.fact_returns
GROUP BY Return_Refund, Reason
ORDER BY Return_Refund, Return_Records DESC;

SELECT
    COUNT(DISTINCT r.Or_ID) AS affected_orders,
    COUNT(DISTINCT o.Or_ID) AS total_orders,
    ROUND(
        100 * COUNT(DISTINCT r.Or_ID) /
        COUNT(DISTINCT o.Or_ID),
        1
    ) AS order_incidence_pct
FROM amazon_sales.fact_orders AS o
LEFT JOIN amazon_sales.fact_returns AS r
    ON r.Or_ID = o.Or_ID;
    
SELECT
    COUNT(*) AS rating_records,
    COUNT(Prod_Rating) AS product_responses,
    ROUND(AVG(Prod_Rating), 2) AS avg_product_rating,
    SUM(Prod_Rating IS NULL) AS missing_product_ratings,
    COUNT(Delivery_Service_Rating) AS service_responses,
    ROUND(AVG(Delivery_Service_Rating), 2) AS avg_service_rating,
    SUM(Delivery_Service_Rating IS NULL) AS missing_service_ratings
FROM amazon_sales.fact_ratings;
    
 WITH valid_subscriptions AS (
    SELECT
        s.SD_ID,
        s.C_ID,
        s.Plan_ID,
        p.Plan_Name,
        s.Start_Date,
        s.End_Date,
        DATEDIFF(s.End_Date, s.Start_Date) AS Duration_Days
    FROM amazon_sales.fact_subscriptions AS s
    JOIN amazon_sales.dim_subscription_plan AS p
        ON p.Plan_ID = s.Plan_ID
    WHERE s.Invalid_Date_Range = 0
),
ranked_subscriptions AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY Plan_ID
            ORDER BY Duration_Days
        ) AS duration_rank,
        COUNT(*) OVER (
            PARTITION BY Plan_ID
        ) AS plan_count
    FROM valid_subscriptions
)
SELECT
    Plan_ID,
    Plan_Name,
    COUNT(*) AS Subscriptions,
    COUNT(DISTINCT C_ID) AS Customers,
    AVG(
        CASE
            WHEN duration_rank IN (
                FLOOR((plan_count + 1) / 2),
                FLOOR((plan_count + 2) / 2)
            )
            THEN Duration_Days
        END
    ) AS Median_Duration_Days,
    SUM(
        Start_Date <= '2024-12-31'
        AND End_Date >= '2024-12-31'
    ) AS Active_Subscriptions_As_Of_Snapshot
FROM ranked_subscriptions
GROUP BY Plan_ID, Plan_Name
ORDER BY Plan_ID;   