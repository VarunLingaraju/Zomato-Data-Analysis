--------------------------------------------------------------------------------
-- 1. INITIAL DATABASE & TABLE INSPECTION
--------------------------------------------------------------------------------

-- Checking all tables and their catalogs across the database to understand structure
SELECT DISTINCT(table_catalog), table_name 
FROM INFORMATION_SCHEMA.COLUMNS;

-- Inspecting data types of columns in the 'ZomatoData' table for schema validation
SELECT column_name, data_type
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ZomatoData';

-- Quick preview of the raw dataset records
SELECT * FROM ZomatoData;


--------------------------------------------------------------------------------
-- 2. DATA INTEGRITY & PRIMARY KEY VALIDATION
--------------------------------------------------------------------------------

-- Checking for duplicate restaurant IDs to see if the column can serve as a primary key
SELECT restaurantId, COUNT(restaurantId) AS ID_Count
FROM ZomatoData
GROUP BY restaurantId
ORDER BY 2 DESC;
-- (Optional filter: HAVING COUNT(restaurantId) >= 2 to isolate duplicates)


--------------------------------------------------------------------------------
-- 3. COUNTRY & REGIONAL ANALYSIS SETUP
--------------------------------------------------------------------------------

-- Analyzing distribution of records per CountryCode to understand geographic spread
SELECT DISTINCT(CountryCode), COUNT(CountryCode) AS Count
FROM ZomatoData
GROUP BY CountryCode;

-- Listing all unique country codes present in the main dataset
SELECT DISTINCT(countrycode)
FROM ZomatoData;

-- Inspecting a specific record to cross-reference details
SELECT * 
FROM ZomatoData
WHERE [RestaurantID] = '18306543';

-- Previewing the lookup table for country codes and names
SELECT * 
FROM CountryCodes;

-- Renaming column in lookup table to maintain consistency and remove spaces
EXEC sp_rename 'CountryCodes.[Country Code]', 'Country_Code', 'COLUMN';

-- Verifying the join between ZomatoData and CountryCodes before updating
SELECT A.CountryCode, B.Country
FROM ZomatoData A 
JOIN CountryCodes B
ON A.CountryCode = B.Country_Code;

-- Adding a new column to store country names directly in the main table for better readability
ALTER TABLE ZomatoData
ADD Country_Name VARCHAR(50);

-- Populating the new Country_Name column using a join with the CountryCodes table
UPDATE ZomatoData 
SET Country_Name = B.Country
FROM ZomatoData AS A
JOIN CountryCodes B 
ON A.CountryCode = B.Country_Code;


--------------------------------------------------------------------------------
-- 4. DATA CLEANING: STRING FORMATTING & ENCODING FIXES
--------------------------------------------------------------------------------

-- Identifying records with encoding/special character issues in the City column
SELECT DISTINCT(City) 
FROM ZomatoData
WHERE CITY LIKE '%?%';

-- Previewing the fix for corrupted city names by replacing '?' with the correct character ('i')
SELECT REPLACE(City, '?', 'i')
FROM ZomatoData 
WHERE CITY LIKE '%?%';

-- Applying the fix permanently to the City column
UPDATE ZomatoData
SET City = REPLACE(City, '?', 'i')
FROM ZomatoData
where City LIKE '%?%';


--------------------------------------------------------------------------------
-- 5. AGGREGATION & HIERARCHICAL ANALYSIS
--------------------------------------------------------------------------------

-- Calculating total restaurants per country and city
SELECT country_Name, city, COUNT(city) AS Total_Restaurants
FROM ZomatoData 
GROUP BY Country_Name, City
ORDER BY 1, 2, 3 ASC;

-- Analyzing locality distribution within India using window functions (running total/rolling count)
SELECT city, Locality, COUNT(locality) AS Count_Locality,
       SUM(COUNT(locality)) OVER (PARTITION BY city ORDER BY city, locality) AS Roll_Count
FROM ZomatoData
WHERE Country_Name = 'India'
GROUP BY [Locality], CITY
ORDER BY 1, 2, 3 DESC;


--------------------------------------------------------------------------------
-- 6. SCHEMA OPTIMIZATION & UNUSED COLUMN REMOVAL
--------------------------------------------------------------------------------

-- Dropping redundant address and verbose locality columns to streamline the dataset
ALTER TABLE ZomatoData 
DROP COLUMN [address];

ALTER TABLE ZomatoData
drop column localityVerbose;

-- Expanding the Cuisines column size to prevent data truncation issues
ALTER TABLE ZomatoData
ALTER COLUMN Cuisines VARCHAR(MAX);


--------------------------------------------------------------------------------
-- 7. NULL VALUE CHECKS & CATEGORICAL FIELD AUDITS
--------------------------------------------------------------------------------

-- Checking for missing or blank values in the Cuisines column
SELECT Cuisines, COUNT([Cuisines]) AS Null_Or_Blank_Count 
FROM ZomatoData
WHERE Cuisines IS NULL OR Cuisines = ' '
GROUP BY [Cuisines];

-- Frequency distribution of different cuisines offered
SELECT Cuisines, COUNT(cuisines) AS Cuisine_Count 
FROM ZomatoData
group by Cuisines
ORDER BY 2 DESC;

-- Analyzing currency distribution across restaurants
SELECT Currency, COUNT(currency) AS Currency_Count 
FROM ZomatoData
GROUP BY Currency
ORDER BY 2 DESC;

-- Inspecting binary/categorical service flags
SELECT DISTINCT([Has_Table_booking]) FROM [dbo].[ZomatoData];
SELECT DISTINCT([Has_Online_delivery]) FROM [dbo].[ZomatoData];
SELECT DISTINCT([Is_delivering_now]) FROM [dbo].[ZomatoData];
SELECT DISTINCT([Switch_to_order_menu]) FROM [dbo].[ZomatoData];

-- Dropping an obsolete/unused service flag column
ALTER TABLE ZomatoData DROP COLUMN [Switch_to_order_menu];

-- Checking price range categories available in the dataset
SELECT DISTINCT([Price_range]) FROM [dbo].[ZomatoData];


--------------------------------------------------------------------------------
-- 8. METRIC CONVERSIONS & STATISTICAL ANALYSIS
--------------------------------------------------------------------------------

-- Converting Votes column to integer for numerical aggregation
ALTER TABLE [dbo].[ZomatoData] ALTER COLUMN [Votes] INT;

-- Calculating statistical metrics for customer votes
SELECT MIN(votes) AS min_vt, MAX(votes) AS max_vt, AVG(votes) AS avg_vt
FROM ZomatoData;

-- Converting Average Cost for Two to float for precise mathematical operations
ALTER TABLE [dbo].[ZomatoData] ALTER COLUMN [Average_Cost_for_two] FLOAT;

-- Analyzing average, minimum, and maximum dining costs grouped by currency
SELECT Currency, 
       MIN(Average_Cost_for_two) AS min_cost, 
       ROUND(AVG(Average_Cost_for_two), 2) AS avg_cost, 
       MAX(Average_Cost_for_two) AS max_cost
from ZomatoData
GROUP BY Currency;

-- Evaluating overall rating distribution (Min, Avg, Max)
SELECT MIN(rating) AS min_rating, 
       ROUND(AVG(rating), 2) AS avg_rating, 
       MAX(rating) AS max_rating
FROM ZomatoData;

-- Counting the number of high-performing restaurants with a rating of 4.0 or above
SELECT COUNT(RATING) AS Above_4_rating 
FROM [ZomatoData] 
WHERE [Rating] >= 4;


--------------------------------------------------------------------------------
-- 9. FEATURE ENGINEERING: RATING CATEGORIZATION
--------------------------------------------------------------------------------

-- Previewing conditional categorization of restaurant ratings
SELECT rating, 
CASE 
    WHEN rating >= 1 AND rating <= 2.5 THEN 'Poor'
    WHEN rating > 2.5 AND rating <= 3.5 THEN 'Good'
    WHEN rating > 3.5 AND rating <= 4.5 THEN 'Great'
    WHEN rating > 4.5 THEN 'Excellent'
END AS Rate_Category
FROM ZomatoData;

-- Adding a new derived column for performance tiering
ALTER TABLE zomatodata
ADD Rate_Category VARCHAR(20);

-- Populating the newly created Rate_Category column based on rating thresholds
UPDATE [ZomatoData] 
SET [Rate_Category] = (
    CASE								     
        WHEN [Rating] >= 1 AND [Rating] < 2.5 THEN 'POOR'
        WHEN [Rating] >= 2.5 AND [Rating] < 3.5 THEN 'GOOD'
        WHEN [Rating] >= 3.5 AND [Rating] < 4.5 THEN 'GREAT'
        WHEN [Rating] >= 4.5 THEN 'EXCELLENT'
    END
);

-- Final verification check of the fully cleaned and engineered dataset
SELECT * FROM ZomatoData;