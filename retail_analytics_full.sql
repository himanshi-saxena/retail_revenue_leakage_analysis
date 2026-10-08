SELECT TOP (1000) [Invoice]
      ,[StockCode]
      ,[Description]
      ,[Quantity]
      ,[InvoiceDate]
      ,[Price]
      ,[Customer_ID]
      ,[Country]
  FROM [Retail_Analytics].[dbo].[RawOnlineRetail]

---whole data--
SELECT*
FROM RawOnlineRetail;

-- Checking Data
SELECT 
    COUNT(*) AS Total_rows,
    COUNT(DISTINCT Invoice) AS Unique_Invoice,
    COUNT(DISTINCT Customer_ID) AS Unique_Customers,
    SUM(CASE WHEN Customer_ID IS NULL THEN 1 ELSE 0 END ) AS Missing_customer_ID,
    SUM(CASE WHEN Quantity <= 0 THEN 1 ELSE 0 END ) AS non_positive_qty,
    SUM(CASE WHEN Price <= 0 THEN 1 ELSE 0 END ) AS non_positive_price,
    SUM(CASE WHEN Description IS NULL THEN 1 ELSE 0 END) AS missing_description
FROM RawOnlineRetail;

--New Cleaned table/column--
SELECT *,
       CASE WHEN LEFT(Invoice,1) = 'C' THEN 1 ELSE 0 END AS IsCancelled,
       Quantity * Price AS Revenue,
       CAST(Customer_ID AS INT) AS CustomerID_Clean
INTO CleanedOnlineRetail
FROM RawOnlineRetail
WHERE Price > 0
  AND Quantity <> 0
  AND Description IS NOT NULL;

-- Building Star Schema Dimesion + Fact table--
 CREATE TABLE Dim_Customer(
    Customer_ID INT PRIMARY KEY,
    Country NVARCHAR(50));

CREATE TABLE Dim_Product(
    StockCode NVARCHAR(50) PRIMARY KEY,
    Description NVARCHAR(200));

CREATE TABLE Dim_Date(
DateKey DATE PRIMARY KEY,
[YEAR] INT, [MONTH] INT, MonthName NVARCHAR(10), [DATE] INT, DayName NVARCHAR(10));


--Creating Table--
SELECT*
FROM CleanedOnlineRetail

--Create fact Orders--

INSERT INTO FactOrders
SELECT Invoice, StockCode, CustomerID_Clean, InvoiceDate,
       CAST(InvoiceDate AS DATE), Quantity, Price, Revenue, IsCancelled
FROM CleanedOnlineRetail;
--
DELETE FROM FactOrders;
DELETE FROM Dim_Customer;
DELETE FROM Dim_Product;
DELETE FROM Dim_Date;

--REfill Dim_customer--
INSERT INTO Dim_Customer
SELECT CustomerID_Clean, MAX(Country)
FROM CleanedOnlineRetail
WHERE CustomerID_Clean IS NOT NULL
GROUP BY CustomerID_Clean;

--Refill Dim_product
INSERT INTO Dim_Product
SELECT StockCode, MAX(Description)
FROM CleanedOnlineRetail
GROUP BY StockCode;

--Refill Dim_Date
INSERT INTO Dim_Date
SELECT DISTINCT CAST(InvoiceDate AS DATE),
       YEAR(InvoiceDate),
       MONTH(InvoiceDate),
       DATENAME(MONTH, InvoiceDate),
       DAY(InvoiceDate),
       DATENAME(WEEKDAY, InvoiceDate)
FROM CleanedOnlineRetail;

--Checking all table--

SELECT 'Dim_Customer' AS TableName, COUNT(*) AS Total FROM Dim_Customer
UNION ALL SELECT 'Dim_Product', COUNT(*) FROM Dim_Product
UNION ALL SELECT 'Dim_Date', COUNT(*) FROM Dim_Date
UNION ALL SELECT 'FactOrders', COUNT(*) FROM FactOrders
UNION ALL SELECT 'CleanedOnlineRetail', COUNT(*) FROM CleanedOnlineRetail;

--Step 2.7 RFM segmentation

WITH RFM_Base AS (
    SELECT CustomerID,
           DATEDIFF(DAY, MAX(InvoiceDate), (SELECT MAX(InvoiceDate) FROM FactOrders)) AS Recency,
           COUNT(DISTINCT InvoiceNo) AS Frequency,
           SUM(Revenue) AS Monetary
    FROM FactOrders
    WHERE IsCancelled = 0 AND CustomerID IS NOT NULL
    GROUP BY CustomerID
),
RFM_Scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY Recency DESC)  AS R_Score,
           NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score,
           NTILE(5) OVER (ORDER BY Monetary ASC)  AS M_Score
    FROM RFM_Base
)
SELECT *,
       (R_Score + F_Score + M_Score) AS RFM_Total,
       CASE
           WHEN (R_Score + F_Score + M_Score) >= 13 THEN 'Champion'
           WHEN (R_Score + F_Score + M_Score) >= 10 THEN 'Loyal'
           WHEN (R_Score + F_Score + M_Score) >= 7  THEN 'At Risk'
           ELSE 'Lost'
       END AS Segment
INTO RFM_Segments
FROM RFM_Scored;

--Step 2.8 Coherent retention

DROP TABLE IF EXISTS CohortRetention;

WITH FirstPurchase AS (
    SELECT CustomerID, MIN(DateKey) AS FirstDate
    FROM FactOrders
    WHERE CustomerID IS NOT NULL AND IsCancelled = 0
    GROUP BY CustomerID
),
Activity AS (
    SELECT f.CustomerID,
           DATEFROMPARTS(YEAR(fp.FirstDate), MONTH(fp.FirstDate), 1) AS CohortMonth,
           DATEFROMPARTS(YEAR(f.DateKey), MONTH(f.DateKey), 1) AS ActivityMonth
    FROM FactOrders f
    JOIN FirstPurchase fp ON f.CustomerID = fp.CustomerID
    WHERE f.IsCancelled = 0
),
CohortCounts AS (
    SELECT CohortMonth,
           DATEDIFF(MONTH, CohortMonth, ActivityMonth) AS MonthsSinceFirstPurchase,
           COUNT(DISTINCT CustomerID) AS ActiveCustomers
    FROM Activity
    GROUP BY CohortMonth, DATEDIFF(MONTH, CohortMonth, ActivityMonth)
)
SELECT CohortMonth,
       MonthsSinceFirstPurchase,
       ActiveCustomers,
       FIRST_VALUE(ActiveCustomers) OVER (PARTITION BY CohortMonth ORDER BY MonthsSinceFirstPurchase) AS CohortSize,
       ROUND(100.0 * ActiveCustomers /
             FIRST_VALUE(ActiveCustomers) OVER (PARTITION BY CohortMonth ORDER BY MonthsSinceFirstPurchase), 1) AS RetentionPct
INTO CohortRetention
FROM CohortCounts;

--Step 2.9 Revenue leakage

DROP TABLE IF EXISTS RevenueLeakage;

SELECT DATEFROMPARTS(YEAR(DateKey), MONTH(DateKey), 1) AS [Month],
       SUM(CASE WHEN IsCancelled = 0 THEN Revenue ELSE 0 END)      AS GrossRevenue,
       SUM(CASE WHEN IsCancelled = 1 THEN ABS(Revenue) ELSE 0 END) AS LeakedRevenue
INTO RevenueLeakage
FROM FactOrders
GROUP BY DATEFROMPARTS(YEAR(DateKey), MONTH(DateKey), 1);

ALTER TABLE RevenueLeakage ADD NetRevenue AS (GrossRevenue - LeakedRevenue);
ALTER TABLE RevenueLeakage ADD LeakagePct AS (ROUND(100.0 * LeakedRevenue / NULLIF(GrossRevenue, 0), 1));

--Step 2.10 Running total month over month

USE Retail_Analytics;
GO

SELECT [Month],
       NetRevenue,
       SUM(NetRevenue) OVER (ORDER BY [Month]) AS RunningTotal,
       LAG(NetRevenue) OVER (ORDER BY [Month]) AS PrevMonthRevenue,
       ROUND(100.0 * (NetRevenue - LAG(NetRevenue) OVER (ORDER BY [Month]))
             / NULLIF(LAG(NetRevenue) OVER (ORDER BY [Month]), 0), 1) AS MoM_GrowthPct
FROM dbo.RevenueLeakage
ORDER BY [Month];

--Create teh views--
--View 1--
USE Retail_Analytics;
GO

DROP VIEW IF EXISTS vw_RFM_Segments;
GO
CREATE VIEW vw_RFM_Segments AS SELECT * FROM dbo.RFM_Segments;
GO

DROP VIEW IF EXISTS vw_CohortRetention;
GO
CREATE VIEW vw_CohortRetention AS SELECT * FROM dbo.CohortRetention;
GO

DROP VIEW IF EXISTS vw_RevenueLeakage;
GO
CREATE VIEW vw_RevenueLeakage AS SELECT * FROM dbo.RevenueLeakage;
GO