--------------------------------------------------------------------------------
-- 1. REGIONAL RESTAURANT DISTRIBUTION & PERCENTAGE SHARE ANALYSIS
--------------------------------------------------------------------------------
-- Business Question: What is our global market footprint, and what percentage 
-- share does each country command of the total listed restaurants?
--------------------------------------------------------------------------------

-- Initial breakdown of restaurant density by country, city, and locality using window functions
SELECT Country_Name, City, Locality, COUNT(locality) AS count_locality,
       SUM(COUNT(locality)) OVER (PARTITION BY Country_Name ORDER BY Country_Name, city, locality DESC) AS TOTAL_REST
FROM ZomatoData
WHERE Country_Name = 'India'
GROUP BY Country_Name, City, Locality;

-- Verifying column schemas to ensure compatibility for relational calculations
SELECT column_name, data_type
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'zomatodata';

-- Creating a baseline view to cache total restaurant counts for proportion calculations
CREATE OR ALTER VIEW Total_count
AS
SELECT DISTINCT (country_name), COUNT(RestaurantID) OVER() AS TOTAL_REST
FROM ZomatoData;
GO

SELECT * FROM Total_count;

-- Calculating each country's percentage share of the total global Zomato marketplace
WITH CT1 AS (
    SELECT [COUNTRY_NAME], COUNT([RestaurantID]) AS REST_COUNT
    FROM [dbo].[ZomatoData]
    GROUP BY [COUNTRY_NAME]
)
SELECT 
    A.[COUNTRY_NAME],
    A.[REST_COUNT], 
    (A.[REST_COUNT] * 100.0) / B.[TOTAL_REST] AS Percentage_Share
FROM CT1 A 
JOIN Total_count B
    ON A.[COUNTRY_NAME] = B.[country_name]
ORDER BY 3 DESC;


--------------------------------------------------------------------------------
-- 2. SERVICE ADOPTION: ONLINE DELIVERY METRICS
--------------------------------------------------------------------------------
-- Business Question: How is online delivery adoption distributed across different 
-- countries, and what exact percentage of restaurants support digital delivery?
--------------------------------------------------------------------------------

-- Establishing a secondary view to track regional base volumes for delivery analysis
CREATE OR ALTER VIEW COUNTRY_REST
AS
SELECT [COUNTRY_NAME], COUNT(CAST([RestaurantID] AS NUMERIC)) AS REST_COUNT
FROM [dbo].[ZomatoData]
GROUP BY [COUNTRY_NAME];
GO

SELECT * FROM COUNTRY_REST
ORDER BY 2 DESC;

-- Determining the volume and percentage of restaurants supporting online delivery per country
SELECT A.[COUNTRY_NAME], COUNT(A.[RestaurantID]) AS TOTAL_REST, 
       ROUND(COUNT(CAST(A.[RestaurantID] AS DECIMAL)) / CAST(B.[REST_COUNT] AS DECIMAL) * 100, 2) AS Online_Delivery_Percentage
FROM [dbo].[ZomatoData] A 
JOIN COUNTRY_REST B
    ON A.[COUNTRY_NAME] = B.[COUNTRY_NAME]
WHERE A.[Has_Online_delivery] = 'YES'
GROUP BY A.[COUNTRY_NAME], B.REST_COUNT
ORDER BY 2 DESC;


--------------------------------------------------------------------------------
-- 3. DEEP DIVE: LOCALITY-LEVEL CONCENTRATION (INDIA)
--------------------------------------------------------------------------------
-- Business Question: Which specific micro-markets and localities inside India 
-- hold the highest density of listed restaurants, and what are their cuisines?
--------------------------------------------------------------------------------

-- Identifying the specific city and locality in India boasting the highest restaurant density
WITH CT1 AS (
    SELECT [City], [Locality], COUNT([RestaurantID]) AS REST_COUNT
    FROM [dbo].[ZomatoData]
    WHERE [COUNTRY_NAME] = 'INDIA'
    GROUP BY CITY, LOCALITY
)
SELECT city, [Locality], REST_COUNT 
FROM CT1 
WHERE REST_COUNT = (SELECT MAX(REST_COUNT) FROM CT1);

-- Mapping all raw cuisine entries associated with India's highest-density locality
WITH CT1 AS (
    SELECT city, Locality, COUNT(RestaurantID) AS Rest_count
    FROM ZomatoData
    Where Country_Name = 'India'
    GROUP BY City, Locality
),
CT2 AS (
    SELECT city, Locality, Rest_count
    FROM CT1
    WHERE Rest_count = (SELECT MAX(Rest_count) FROM CT1)
),
CT3 AS (
    SELECT Locality, Cuisines 
    FROM ZomatoData
)
SELECT a.locality, b.cuisines 
FROM CT2 a 
JOIN CT3 b 
    ON a.Locality = b.Locality;

-- Cross-tabulating popular cuisine categories for high-density localities using conditional aggregation (Pivot-style)
WITH RankedLocalities AS (
    SELECT 
        City,
        Locality,
        COUNT(RestaurantID) AS Rest_count,
        RANK() OVER (ORDER BY COUNT(RestaurantID) DESC) AS rnk
    FROM ZomatoData
    WHERE Country_Name = 'India'
    GROUP BY City, Locality
),
MaxLocalityCuisines AS (
    SELECT 
        a.Locality,
        b.Cuisines
    FROM RankedLocalities a
    JOIN ZomatoData b 
        ON a.Locality = b.Locality
    WHERE a.rnk = 1
)
SELECT 
    Locality,
    SUM(CASE WHEN Cuisines LIKE '%North Indian%' THEN 1 ELSE 0 END) AS [North Indian],
    SUM(CASE WHEN Cuisines LIKE '%Chinese%' THEN 1 ELSE 0 END) AS [Chinese],
    SUM(CASE WHEN Cuisines LIKE '%Fast Food%' THEN 1 ELSE 0 END) AS [Fast Food],
    SUM(CASE WHEN Cuisines LIKE '%Mughlai%' THEN 1 ELSE 0 END) AS [Mughlai],
    SUM(CASE WHEN Cuisines LIKE '%South Indian%' THEN 1 ELSE 0 END) AS [South Indian],
    SUM(CASE WHEN Cuisines LIKE '%Italian%' THEN 1 ELSE 0 END) AS [Italian]
FROM MaxLocalityCuisines
GROUP BY Locality;


--------------------------------------------------------------------------------
-- 4. CULINARY TRENDS & OUTLIER LOCALITIES
--------------------------------------------------------------------------------
-- Business Question: What are the most frequently offered food styles in high-density 
-- regions, and which low-engagement localities act as bottom-tier outliers?
--------------------------------------------------------------------------------

-- Normalizing piped-delimited multi-cuisine strings to extract top popular foods in high-density Indian hubs
CREATE VIEW VF 
AS
(
SELECT [COUNTRY_NAME], [City], [Locality], N.[Cuisines] 
FROM [dbo].[ZomatoData]
CROSS APPLY (SELECT VALUE AS [Cuisines] FROM string_split([Cuisines], '|')) N
);

WITH CT1 AS (
    SELECT [City], [Locality], COUNT([RestaurantID]) AS REST_COUNT
    FROM [dbo].[ZomatoData]
    WHERE [COUNTRY_NAME] = 'INDIA'
    GROUP BY CITY, LOCALITY
),
CT2 AS (
    SELECT [Locality], REST_COUNT 
    FROM CT1 
    WHERE REST_COUNT = (SELECT MAX(REST_COUNT) FROM CT1)
)
SELECT A.[Cuisines], COUNT(A.[Cuisines]) AS Cuisine_Frequency
FROM VF A 
JOIN CT2 B
    ON A.Locality = B.[Locality]
GROUP BY B.[Locality], A.[Cuisines]
ORDER BY 2 DESC;

-- Flagging lower-bound outlier localities in India with the minimal restaurant counts recorded
WITH CT1 AS (
    SELECT [City], [Locality], COUNT([RestaurantID]) AS REST_COUNT
    FROM [dbo].[ZomatoData]
    WHERE [COUNTRY_NAME] = 'INDIA'
    GROUP BY [City], [Locality]
)
SELECT * FROM CT1 
WHERE REST_COUNT = (SELECT MIN(REST_COUNT) FROM CT1) 
ORDER BY CITY;


--------------------------------------------------------------------------------
-- 5. AMENITIES & CUSTOMER EXPERIENCE CORRELATIONS
--------------------------------------------------------------------------------
-- Business Question: How do table-booking availability and standard amenities 
-- impact customer review scores and volume across high-traffic local markets?
--------------------------------------------------------------------------------

-- Quantifying table-booking availability specifically within India's maximum density cluster
WITH CT1 AS (
    SELECT [City], [Locality], COUNT([RestaurantID]) AS REST_COUNT
    FROM [dbo].[ZomatoData]
    WHERE [COUNTRY_NAME] = 'INDIA'
    GROUP BY CITY, LOCALITY
),
CT2 AS (
    SELECT [Locality], REST_COUNT 
    FROM CT1 
    WHERE REST_COUNT = (SELECT MAX(REST_COUNT) FROM CT1)
),
CT3 AS (
    SELECT [Locality], [Has_Table_booking] AS TABLE_BOOKING
    FROM [dbo].[ZomatoData]
)
SELECT A.[Locality], COUNT(A.TABLE_BOOKING) AS TABLE_BOOKING_OPTION
FROM CT3 A 
JOIN CT2 B
    ON A.[Locality] = B.[Locality]
WHERE A.TABLE_BOOKING = 'YES'
GROUP BY A.[Locality];

-- Evaluating the relationship between table-booking capability and average ratings in Connaught Place
SELECT 'WITH_TABLE' AS TABLE_BOOKING_OPT, COUNT([Has_Table_booking]) AS TOTAL_REST, ROUND(AVG([Rating]), 2) AS AVG_RATING
FROM [dbo].[ZomatoData]
WHERE [Has_Table_booking] = 'YES'
  AND [Locality] = 'Connaught Place'
UNION
SELECT 'WITHOUT_TABLE' AS TABLE_BOOKING_OPT, COUNT([Has_Table_booking]) AS TOTAL_REST, ROUND(AVG([Rating]), 2) AS AVG_RATING
FROM [dbo].[ZomatoData]
WHERE [Has_Table_booking] = 'NO'
  AND [Locality] = 'Connaught Place';

-- Benchmarking overall average performance metrics grouped by global geographical hierarchy
SELECT [COUNTRY_NAME], [City], [Locality], 
       COUNT([RestaurantID]) AS TOTAL_REST, 
       ROUND(AVG(CAST([Rating] AS DECIMAL)), 2) AS AVG_RATING
FROM [dbo].[ZomatoData]
GROUP BY [COUNTRY_NAME], [City], [Locality]
ORDER BY 4 DESC;


--------------------------------------------------------------------------------
-- 6. BUSINESS RECOMMENDATION ENGINE: FILTERING PREMIUM DINING
--------------------------------------------------------------------------------
-- Business Question: Can we programmatically isolate top-performing, high-vote, 
-- moderately priced Indian restaurants that support both booking and delivery features?
--------------------------------------------------------------------------------

-- Identifying high-performing, moderately priced Indian restaurants optimized for bookings and delivery
SELECT *
FROM [dbo].[ZomatoData]
WHERE [COUNTRY_NAME] = 'INDIA'
  AND [Has_Table_booking] = 'YES'
  AND [Has_Online_delivery] = 'YES'
  AND [Price_range] <= 3
  AND [Votes] > 1000
  AND [Average_Cost_for_two] < 1000
  AND [Rating] > 4
  AND [Cuisines] LIKE '%INDIA%';

-- Correlating price tier placement with reservation features among elite venues (Rating >= 4.5)
SELECT [Price_range], COUNT([Has_Table_booking]) AS NO_OF_REST
FROM [dbo].[ZomatoData]
WHERE [Rating] >= 4.5
  AND [Has_Table_booking] = 'YES'
GROUP BY [Price_range];