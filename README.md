# Zomato-Data-Analysis
Zomato Data Exploration and Analysis with SQL (SQL SERVER)

Most of us know that Zomato is an Indian multinational restaurant aggregator and food delivery company. The idea of analyzing the Zomato dataset is to get an overview of what is actually happening in their business. The Zomato dataset consists of more than 9,000 rows with columns such as Restaurant ID, Restaurant Name, City, Location, Cuisines, and many more.  

**While exploring the data with SQL, I worked on the following steps:**

Checked all table details, including column names, data types, and constraints.

Checked for duplicate values in the [RestaurantId] column.

Removed unwanted and redundant columns from the table.

Merged 2 different tables and added a new Country_Name column using [CountryCode] as the primary key.

Identified and corrected misspelled city names caused by encoding issues.

Calculated the number of restaurants using rolling/moving counts with window functions.

Analyzed minimum, maximum, and average values for votes, ratings, and currency columns.

Created a new derived Rate_Category column based on restaurant ratings.

**After completing data exploration, I moved on to data analysis to uncover key business insights:**

**Global Market Distribution:** According to the dataset, **90.67%** of the data represents restaurants listed in **India**, followed by the **USA at 4.45%**.

**Online Delivery Adoption:** Out of 15 countries, only 2 countries provide online delivery options. Specifically, **28.01% of restaurants in India and 46.67% in the UAE** offer online delivery.

**Top Dining Hubs in India:** **Connaught Place ** in **New Delhi** has the highest concentration of listed restaurants **(122)**, followed by Rajouri Garden (99) and Shahdara (87).

**Cuisine Trends**: The most popular cuisine offered in high-density areas like **Connaught** Place is North Indian.

**Table Booking Availability**: Out of the **122** restaurants in Connaught Place, only **54** provide table-booking facilities.

**Impact of Amenities on Ratings:** Restaurants in Connaught Place with table-booking options hold a higher average rating of **3.9/5**, compared to **3.7/5** for restaurants without table booking.

**Top-Value Recommendation:** By filtering for moderately priced options (average cost for two under 1000, rating > 4, votes > 1000, and supporting both table booking and online delivery), the top-performing Indian restaurant identified is 'India Restaurant' (Restaurant ID: **20747**) located in **Kolkata**.
