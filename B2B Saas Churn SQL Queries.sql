CREATE DATABASE SaaSChurnDB;
GO

USE SaaSChurnDB;
GO

SELECT * FROM DBO.b2b_saas_churn

-- Table ka naam aur rows check karo

SELECT s.name AS schema_name, t.name AS table_name, SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.schemas s    ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
GROUP BY s.name, t.name
ORDER BY t.name

-- Columns ke data types dekho

SELECT ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'b2b_saas_churn'
ORDER BY ORDINAL_POSITION;

-- Types theek hain, to sirf validate karo

SELECT
    COUNT(*)                                            AS total_rows,        
    COUNT(DISTINCT customer_id)                         AS unique_ids,        
    SUM(CAST(churn_flag AS INT))                        AS churned,           
    SUM(CASE WHEN nps_score IS NULL THEN 1 ELSE 0 END)  AS null_nps,          
    SUM(CASE WHEN csat_score IS NULL THEN 1 ELSE 0 END) AS null_csat,         
    SUM(CASE WHEN churn_date IS NULL THEN 1 ELSE 0 END) AS null_churn_date    
FROM dbo.b2b_saas_churn

-- Convert date columns
-- After successful import, convert the date strings from DD-MM-YYYY to SQL Server DATE.

ALTER TABLE dbo.B2B_SaaS_Churn
ADD signup_date_new DATE NULL,
    contract_start_date_new DATE NULL,
    last_login_date_new DATE NULL,
    next_renewal_date_new DATE NULL,
    churn_date_new DATE NULL;
GO

UPDATE dbo.b2b_saas_churn
SET
    signup_date_new =
        TRY_CONVERT(DATE, signup_date, 105),

    contract_start_date_new =
        TRY_CONVERT(DATE, contract_start_date, 105),

    last_login_date_new =
        TRY_CONVERT(DATE, last_login_date, 105),

    next_renewal_date_new =
        TRY_CONVERT(DATE, next_renewal_date, 105),

    churn_date_new =
        TRY_CONVERT(DATE, churn_date, 105);
GO


SELECT
    COUNT(*) AS Total_Records,
    COUNT(signup_date_new) AS Valid_Signup_Dates,
    COUNT(churn_date_new) AS Valid_Churn_Dates
FROM dbo.B2B_SaaS_Churn;

-- Correct company size categories

UPDATE dbo.B2B_SaaS_Churn
SET company_size_band =
    CASE
        WHEN company_size_band = '01-Oct' THEN '1-10'
        WHEN company_size_band = 'Nov-50' THEN '11-50'
        ELSE company_size_band
    END;

-- Total customers and churn rate

SELECT
    COUNT(*) AS Total_Customers,

    SUM(CAST(churn_flag AS INT)) AS Churned_Customers,

    COUNT(*) - SUM(CAST(churn_flag AS INT)) AS Active_Customers,

    CAST(
        SUM(CAST(churn_flag AS INT)) * 100.0 / COUNT(*)
        AS DECIMAL(10,2)
    ) AS Churn_Rate_Percentage

FROM dbo.B2B_SaaS_Churn;


-- Churn analysis by subscription plan

SELECT
    plan_tier,

    COUNT(*) AS Total_Customers,

    SUM(CAST(churn_flag AS INT)) AS Churned_Customers,

    CAST(
        SUM(CAST(churn_flag AS INT)) * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Churn_Rate

FROM dbo.B2B_SaaS_Churn

GROUP BY plan_tier

ORDER BY Churn_Rate DESC;

-- Revenue analysis by industry

SELECT
    industry,

    COUNT(*) AS Total_Customers,

    SUM(arr_usd) AS Total_ARR_USD,

    SUM(mrr_usd) AS Total_MRR_USD,

    SUM(lost_arr_usd) AS Lost_ARR_USD

FROM dbo.B2B_SaaS_Churn

GROUP BY industry

ORDER BY Total_ARR_USD DESC;

-- Regional churn analysis

SELECT
    region,

    COUNT(*) AS Total_Customers,

    SUM(CAST(churn_flag AS INT)) AS Churned_Customers,

    CAST(
        SUM(CAST(churn_flag AS INT)) * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Churn_Rate

FROM dbo.B2B_SaaS_Churn

GROUP BY region

ORDER BY Churn_Rate DESC;

-- Top 10 customers by ARR

SELECT TOP 10
    customer_id,
    company_name,
    industry,
    country,
    plan_tier,
    mrr_usd,
    arr_usd,
    churn_status

FROM dbo.B2B_SaaS_Churn

ORDER BY arr_usd DESC;

-- Customer churn reasons

SELECT
    churn_reason,

    COUNT(*) AS Lost_Customers,

    SUM(lost_arr_usd) AS Lost_Revenue_USD

FROM dbo.B2B_SaaS_Churn

WHERE churn_flag = 1

GROUP BY churn_reason

ORDER BY Lost_Customers DESC;


-- Customer health score analysis

SELECT
    CASE
        WHEN customer_health_score >= 80 THEN 'Healthy'
        WHEN customer_health_score >= 60 THEN 'Moderate Risk'
        ELSE 'High Risk'
    END AS Customer_Health_Category,

    COUNT(*) AS Total_Customers,

    SUM(CAST(churn_flag AS INT)) AS Churned_Customers,

    CAST(
        SUM(CAST(churn_flag AS INT)) * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Churn_Rate

FROM dbo.B2B_SaaS_Churn

GROUP BY
    CASE
        WHEN customer_health_score >= 80 THEN 'Healthy'
        WHEN customer_health_score >= 60 THEN 'Moderate Risk'
        ELSE 'High Risk'
    END

ORDER BY Churn_Rate DESC;

-- Monthly churn trend

SELECT
    YEAR(churn_date_new) AS Churn_Year,

    MONTH(churn_date_new) AS Churn_Month,

    DATENAME(MONTH, churn_date_new) AS Month_Name,

    COUNT(*) AS Churned_Customers,

    SUM(lost_arr_usd) AS Lost_ARR_USD

FROM dbo.B2B_SaaS_Churn

WHERE churn_flag = 1
AND churn_date_new IS NOT NULL

GROUP BY
    YEAR(churn_date_new),
    MONTH(churn_date_new),
    DATENAME(MONTH, churn_date_new)

ORDER BY
    Churn_Year,
    Churn_Month;


-- Customer engagement analysis

SELECT
    CASE
        WHEN logins_last_30d < 10 THEN 'Low Engagement'
        WHEN logins_last_30d < 50 THEN 'Medium Engagement'
        ELSE 'High Engagement'
    END AS Engagement_Level,

    COUNT(*) AS Total_Customers,

    SUM(CAST(churn_flag AS INT)) AS Churned_Customers,

    CAST(
        SUM(CAST(churn_flag AS INT)) * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Churn_Rate

FROM dbo.B2B_SaaS_Churn

GROUP BY
    CASE
        WHEN logins_last_30d < 10 THEN 'Low Engagement'
        WHEN logins_last_30d < 50 THEN 'Medium Engagement'
        ELSE 'High Engagement'
    END

ORDER BY Churn_Rate DESC;

-- Upselling opportunities

SELECT
    customer_id,
    company_name,
    industry,
    plan_tier,
    arr_usd,
    seats_purchased,
    seats_active,
    seat_utilization_pct,
    customer_health_score

FROM dbo.B2B_SaaS_Churn

WHERE upsell_flag = 1
AND churn_flag = 0

ORDER BY arr_usd DESC;

-- Payment failure analysis

SELECT
    payment_failures_last_12m,

    COUNT(*) AS Total_Customers,

    SUM(CAST(churn_flag AS INT)) AS Churned_Customers,

    CAST(
        SUM(CAST(churn_flag AS INT)) * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Churn_Rate

FROM dbo.B2B_SaaS_Churn

GROUP BY payment_failures_last_12m

ORDER BY payment_failures_last_12m;

-- Top 10 customers at risk

SELECT TOP 10
    customer_id,
    company_name,
    industry,
    plan_tier,
    customer_health_score,
    days_since_last_login,
    support_tickets_last_90d,
    payment_failures_last_12m,
    competitor_mentioned_flag,
    arr_usd

FROM dbo.B2B_SaaS_Churn

WHERE churn_flag = 0

AND (
    customer_health_score < 60
    OR days_since_last_login > 30
    OR payment_failures_last_12m > 0
)

ORDER BY
    customer_health_score ASC,
    days_since_last_login DESC;

-- Verify your database

SELECT
    COUNT(*) AS Total_Records,

    SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END)
        AS Churned_Customers,

    SUM(CASE WHEN churn_flag = 0 THEN 1 ELSE 0 END)
        AS Active_Customers,

    SUM(CASE WHEN churn_flag IS NULL THEN 1 ELSE 0 END)
        AS Null_Churn_Flags

FROM dbo.B2B_SaaS_Churn;



USE SaaSChurnDB;
SELECT COUNT(*) AS total_rows,
       SUM(CAST(churn_flag AS INT)) AS churned,
       CAST(100.0*SUM(CAST(churn_flag AS INT))/COUNT(*) AS DECIMAL(5,2)) AS churn_pct
FROM dbo.b2b_saas_churn