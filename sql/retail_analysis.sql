-- ============================================================
-- Retail Sales Performance & Customer Analytics
-- SQL Analysis
-- Dataset: UCI Online Retail
-- ============================================================
--
-- Analysis focuses on product sales, revenue trends,
-- product performance, geographic markets, customer behavior,
-- and transaction cancellations.
--
-- Product sales are defined as:
-- TransactionType = 'Sale' AND ItemType = 'Product'
-- ============================================================

-- ============================================================
-- BUSINESS QUESTION 1
-- How have revenue and sales volume changed monthly?
-- ============================================================

WITH MonthlySales AS (
    SELECT
        YearMonth,
        SUM(LineValue) AS Revenue,
        SUM(Quantity) AS UnitsSold,
        COUNT(DISTINCT InvoiceNo) AS Orders
    FROM retail_transactions
    WHERE TransactionType = 'Sale'
      AND ItemType = 'Product'
    GROUP BY YearMonth
),
MonthlyWithPrevious AS (
    SELECT
        YearMonth,
        Revenue,
        UnitsSold,
        Orders,
        LAG(Revenue) OVER (ORDER BY YearMonth) AS PreviousRevenue
    FROM MonthlySales
)

SELECT
    YearMonth,
    Revenue,
    UnitsSold,
    Orders,
    PreviousRevenue,
    ROUND(
        (Revenue - PreviousRevenue) / PreviousRevenue * 100,
        2
    ) AS RevenueGrowthPct
FROM MonthlyWithPrevious
ORDER BY YearMonth;


-- Quarterly sales performance
WITH QuarterlySales AS (
    SELECT
        Quarter,
        SUM(LineValue) AS Revenue,
        SUM(Quantity) AS UnitsSold,
        COUNT(DISTINCT InvoiceNo) AS Orders
    FROM retail_transactions
    WHERE TransactionType = 'Sale'
      AND ItemType = 'Product'
    GROUP BY Quarter
),
QuarterlyWithPrevious AS (
    SELECT
        Quarter,
        Revenue,
        UnitsSold,
        Orders,
        LAG(Revenue) OVER (ORDER BY Quarter) AS PreviousRevenue
    FROM QuarterlySales
)

SELECT
    Quarter,
    Revenue,
    UnitsSold,
    Orders,
    PreviousRevenue,
    ROUND(
        (Revenue - PreviousRevenue) / PreviousRevenue * 100,
        2
    ) AS RevenueGrowthPct
FROM QuarterlyWithPrevious
ORDER BY Quarter;



-- ============================================================
-- BUSINESS QUESTION 2
-- Which products generate the highest and lowest revenue?
-- ============================================================

SELECT
    StockCode,
    Description,
    SUM(LineValue) AS TotalRevenue,
    SUM(Quantity) AS UnitsSold,
    COUNT(DISTINCT InvoiceNo) AS Orders
FROM retail_transactions
WHERE TransactionType = 'Sale'
  AND ItemType = 'Product'
GROUP BY StockCode, Description
ORDER BY TotalRevenue DESC
LIMIT 10;

SELECT
    StockCode,
    Description,
    SUM(LineValue) AS TotalRevenue,
    SUM(Quantity) AS UnitsSold,
    COUNT(DISTINCT InvoiceNo) AS Orders
FROM retail_transactions
WHERE TransactionType = 'Sale'
  AND ItemType = 'Product'
GROUP BY StockCode, Description
ORDER BY TotalRevenue ASC
LIMIT 10;


-- ============================================================
-- BUSINESS QUESTION 3
-- How concentrated is revenue among top products?
-- ============================================================


WITH ProductRevenue AS (
    SELECT
        StockCode,
        Description,
        SUM(LineValue) AS Revenue
    FROM retail_transactions
    WHERE TransactionType = 'Sale'
      AND ItemType = 'Product'
    GROUP BY StockCode, Description
),

RankedProducts AS (
    SELECT
        StockCode,
        Description,
        Revenue,
        ROW_NUMBER() OVER (ORDER BY Revenue DESC) AS RevenueRank,
        SUM(Revenue) OVER () AS TotalRevenue,
        COUNT(*) OVER () AS TotalProducts
    FROM ProductRevenue
)

SELECT
    StockCode,
    Description,
    Revenue,
    RevenueRank,
    ROUND(Revenue / TotalRevenue * 100, 2) AS RevenueSharePct,
    ROUND(
        SUM(Revenue) OVER (
            ORDER BY Revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / TotalRevenue * 100,
        2
    ) AS CumulativeRevenueSharePct
FROM RankedProducts
ORDER BY RevenueRank;


-- ============================================================
-- BUSINESS QUESTION 4
-- Which products are experiencing declining sales/revenue?
-- ============================================================

WITH ProductMonthly AS (
    SELECT
        StockCode,
        Description,
        YearMonth,
        Month,
        SUM(LineValue) AS MonthlyRevenue,
        SUM(Quantity) AS MonthlyUnits
    FROM retail_transactions
    WHERE TransactionType = 'Sale'
      AND ItemType = 'Product'
      AND Year = 2011
      AND Month BETWEEN 1 AND 11
    GROUP BY StockCode, Description, YearMonth, Month
),

ProductPeriods AS (
    SELECT
        StockCode,
        Description,
        YearMonth,
        MonthlyRevenue,
        MonthlyUnits,
        CASE
            WHEN Month BETWEEN 1 AND 6 THEN 'Earlier'
            WHEN Month BETWEEN 7 AND 11 THEN 'Recent'
        END AS Period
    FROM ProductMonthly
),

ProductComparison AS (
    SELECT
        StockCode,
        Description,

        SUM(
            CASE
                WHEN Period = 'Earlier' THEN MonthlyRevenue
                ELSE 0
            END
        ) / 6.0 AS EarlierAvgRevenue,

        SUM(
            CASE
                WHEN Period = 'Recent' THEN MonthlyRevenue
                ELSE 0
            END
        ) / 5.0 AS RecentAvgRevenue,

        SUM(
            CASE
                WHEN Period = 'Earlier' THEN MonthlyUnits
                ELSE 0
            END
        ) / 6.0 AS EarlierAvgUnits,

        SUM(
            CASE
                WHEN Period = 'Recent' THEN MonthlyUnits
                ELSE 0
            END
        ) / 5.0 AS RecentAvgUnits

    FROM ProductPeriods
    GROUP BY StockCode, Description
)

SELECT
    StockCode,
    Description,
    EarlierAvgRevenue,
    RecentAvgRevenue,
    RecentAvgRevenue - EarlierAvgRevenue AS RevenueChange,
    (RecentAvgRevenue - EarlierAvgRevenue)
        / EarlierAvgRevenue * 100 AS RevenueChangePct,
    EarlierAvgUnits,
    RecentAvgUnits,
    RecentAvgUnits - EarlierAvgUnits AS UnitsChange,
    (RecentAvgUnits - EarlierAvgUnits)
        / EarlierAvgUnits * 100 AS UnitsChangePct
FROM ProductComparison
WHERE RecentAvgRevenue < EarlierAvgRevenue
ORDER BY RevenueChange ASC
LIMIT 20;

-- ============================================================
-- BUSINESS QUESTION 5
-- Which countries generate the most revenue and sales volume?
-- ============================================================

SELECT
    Country,
    SUM(LineValue) AS Revenue,
    SUM(Quantity) AS UnitsSold,
    COUNT(DISTINCT InvoiceNo) AS Orders
FROM retail_transactions
WHERE TransactionType = 'Sale'
  AND ItemType = 'Product'
GROUP BY Country
ORDER BY Revenue DESC;

-- ============================================================
-- BUSINESS QUESTION 6
-- Which countries underperform based on revenue,
-- order volume, and customer activity?
-- ============================================================

WITH CountryMetrics AS (
    SELECT
        Country,
        SUM(LineValue) AS Revenue,
        SUM(Quantity) AS UnitsSold,
        COUNT(DISTINCT InvoiceNo) AS Orders,
        COUNT(DISTINCT CustomerID) AS Customers
    FROM retail_transactions
    WHERE TransactionType = 'Sale'
      AND ItemType = 'Product'
    GROUP BY Country
)

SELECT
    Country,
    Revenue,
    UnitsSold,
    Orders,
    Customers,
    Revenue / Orders AS RevenuePerOrder,
    Orders * 1.0 / NULLIF(Customers, 0) AS OrdersPerCustomer
FROM CountryMetrics
ORDER BY Revenue DESC;

-- Underperformance scoring was completed in Pandas because SQLite
-- does not provide a built-in MEDIAN() aggregate.
--
-- Median benchmarks:
-- Revenue: £9,432.29
-- Orders: 15.5
-- Customers: 5
-- Revenue per Order: £674.55
--
-- Countries received one point for falling below each benchmark.
-- Markets scoring 4 were classified as underperforming.


-- ============================================================
-- BUSINESS QUESTION 7
-- How does customer purchasing behavior differ
-- across geographic markets?
-- ============================================================

WITH CountryMetrics AS (
    SELECT
        Country,
        SUM(LineValue) AS Revenue,
        COUNT(DISTINCT InvoiceNo) AS Orders,
        COUNT(DISTINCT CustomerID) AS Customers
    FROM retail_transactions
    WHERE TransactionType = 'Sale'
      AND ItemType = 'Product'
    GROUP BY Country
)

SELECT
    Country,
    Customers,
    Orders,
    Revenue,
    Revenue / Orders AS RevenuePerOrder,
    Orders * 1.0 / NULLIF(Customers, 0) AS OrdersPerCustomer,
    Revenue / NULLIF(Customers, 0) AS RevenuePerCustomer
FROM CountryMetrics
WHERE Customers >= 5
  AND Country != 'Unspecified'
ORDER BY RevenuePerOrder DESC;


 ============================================================
-- Q8: Who are the highest-value customers, and how concentrated is revenue among them?
-- ============================================================

WITH CustomerRevenue AS (
    SELECT
        CustomerID,
        SUM(LineValue) AS Revenue,
        COUNT(DISTINCT InvoiceNo) AS Orders,
        SUM(Quantity) AS UnitsPurchased
    FROM retail_transactions
    WHERE TransactionType = 'Sale'
      AND ItemType = 'Product'
      AND CustomerID IS NOT NULL
    GROUP BY CustomerID
)

SELECT
    CustomerID,
    Revenue,
    Orders,
    UnitsPurchased
FROM CustomerRevenue
ORDER BY Revenue DESC
LIMIT 10;

WITH CustomerRevenue AS (
    SELECT
        CustomerID,
        SUM(LineValue) AS Revenue
    FROM retail_transactions
    WHERE TransactionType = 'Sale'
      AND ItemType = 'Product'
      AND CustomerID IS NOT NULL
    GROUP BY CustomerID
),

RankedCustomers AS (
    SELECT
        CustomerID,
        Revenue,
        ROW_NUMBER() OVER (ORDER BY Revenue DESC) AS RevenueRank,
        COUNT(*) OVER () AS TotalCustomers,
        SUM(Revenue) OVER () AS TotalRevenue
    FROM CustomerRevenue
)

SELECT
    ROUND(
        100.0 * SUM(CASE WHEN RevenueRank <= 10 THEN Revenue ELSE 0 END)
        / MAX(TotalRevenue), 2
    ) AS Top10CustomerSharePct,

    ROUND(
        100.0 * SUM(
            CASE WHEN RevenueRank <= CEIL(TotalCustomers * 0.01)
                 THEN Revenue ELSE 0 END
        ) / MAX(TotalRevenue), 2
    ) AS Top1PctCustomerSharePct,

    ROUND(
        100.0 * SUM(
            CASE WHEN RevenueRank <= CEIL(TotalCustomers * 0.10)
                 THEN Revenue ELSE 0 END
        ) / MAX(TotalRevenue), 2
    ) AS Top10PctCustomerSharePct

FROM RankedCustomers;

-- Q9: What is the monthly cancellation rate, and which products/customers
-- disproportionately contribute to cancellations?

WITH MonthlyOrders AS (
    SELECT
        YearMonth,

        COUNT(DISTINCT CASE
            WHEN TransactionType = 'Sale'
            THEN InvoiceNo
        END) AS SaleOrders,

        COUNT(DISTINCT CASE
            WHEN TransactionType = 'Cancellation'
            THEN InvoiceNo
        END) AS CancellationOrders

    FROM retail_transactions
    WHERE ItemType = 'Product'
    GROUP BY YearMonth
)

SELECT
    YearMonth,
    SaleOrders,
    CancellationOrders,
    ROUND(
        100.0 * CancellationOrders
        / (SaleOrders + CancellationOrders),
        2
    ) AS CancellationRatePct
FROM MonthlyOrders
ORDER BY YearMonth;

SELECT
    StockCode,
    Description,
    ABS(SUM(Quantity)) AS CancelledUnits,
    COUNT(DISTINCT InvoiceNo) AS CancellationOrders
FROM retail_transactions
WHERE TransactionType = 'Cancellation'
  AND ItemType = 'Product'
GROUP BY StockCode, Description
ORDER BY CancelledUnits DESC
LIMIT 10;

SELECT
    CustomerID,
    ABS(SUM(Quantity)) AS CancelledUnits,
    COUNT(DISTINCT InvoiceNo) AS CancellationOrders
FROM retail_transactions
WHERE TransactionType = 'Cancellation'
  AND ItemType = 'Product'
  AND CustomerID IS NOT NULL
GROUP BY CustomerID
ORDER BY CancelledUnits DESC
LIMIT 10;

-- Investigate unusually large PAPER CRAFT cancellation

SELECT
    InvoiceNo,
    CustomerID,
    StockCode,
    Description,
    Quantity,
    UnitPrice,
    LineValue,
    TransactionType,
    InvoiceDate
FROM retail_transactions
WHERE CustomerID = 16446
  AND StockCode = '23843'
ORDER BY InvoiceDate;


-- ============================================================
-- BUSINESS QUESTION 10
-- What seasonal patterns exist, and what do historical trends
-- suggest about future demand?
-- ============================================================

WITH MonthlySales AS (
    SELECT
        YearMonth,
        Year,
        Month,
        SUM(LineValue) AS Revenue,
        SUM(Quantity) AS UnitsSold,
        COUNT(DISTINCT InvoiceNo) AS Orders
    FROM retail_transactions
    WHERE TransactionType = 'Sale'
      AND ItemType = 'Product'
      AND Year = 2011
      AND Month BETWEEN 1 AND 11
    GROUP BY YearMonth, Year, Month
)

SELECT
    YearMonth,
    Revenue,
    UnitsSold,
    Orders
FROM MonthlySales
ORDER BY YearMonth;

WITH MonthlySales AS (
    SELECT
        YearMonth,
        Month,
        SUM(LineValue) AS Revenue,
        SUM(Quantity) AS UnitsSold,
        COUNT(DISTINCT InvoiceNo) AS Orders
    FROM retail_transactions
    WHERE TransactionType = 'Sale'
      AND ItemType = 'Product'
      AND Year = 2011
      AND Month BETWEEN 1 AND 11
    GROUP BY YearMonth, Month
),

PeriodAverages AS (
    SELECT
        CASE
            WHEN Month BETWEEN 1 AND 8 THEN 'Jan-Aug'
            WHEN Month BETWEEN 9 AND 11 THEN 'Sep-Nov'
        END AS Period,
        AVG(Revenue) AS AvgMonthlyRevenue,
        AVG(UnitsSold) AS AvgMonthlyUnits,
        AVG(Orders) AS AvgMonthlyOrders
    FROM MonthlySales
    GROUP BY Period
)

SELECT *
FROM PeriodAverages
ORDER BY Period;

