USE Chinook;

-- 1. Rank the customers by total sales
select CustomerId, sum(Total),
RANK() OVER (ORDER BY  sum(Total) desc) AS Rank_
from invoice
group by CustomerId;

-- 2. Select only the top 10 ranked customer from the previous question
select CustomerId, sum(Total),
RANK() OVER (ORDER BY  sum(Total) desc) AS Rank_
from invoice
group by CustomerId
limit 10;

-- 3. Rank albums based on the total number of tracks sold.


      WITH AlbumSales AS (
    SELECT A.AlbumId, A.Title AS AlbumTitle, 
           COUNT(IL.TrackId) OVER (PARTITION BY A.AlbumId) AS TotalTracksSold
    FROM InvoiceLine IL
    JOIN Track T ON IL.TrackId = T.TrackId
    JOIN Album A ON T.AlbumId = A.AlbumId
)
SELECT DISTINCT AlbumId, AlbumTitle, TotalTracksSold,
       RANK() OVER (ORDER BY TotalTracksSold DESC) AS Rank_
FROM AlbumSales
ORDER BY Rank_;
-- 4. Do music preferences vary by country? What are the top 3 genres for each country?
CREATE TEMPORARY TABLE genresales
(
SELECT DISTINCT C.Country, G.Name AS Genre, 
       COUNT(IL.TrackId) AS TotalTracksSold,
       DENSE_RANK() OVER (PARTITION BY C.Country ORDER BY COUNT(IL.TrackId) DESC) AS Rank_
FROM Customer C
JOIN Invoice I ON C.CustomerId = I.CustomerId
JOIN InvoiceLine IL ON I.InvoiceId = IL.InvoiceId 
JOIN Track T ON T.TrackId = IL.TrackId
JOIN Genre G ON T.GenreId = G.GenreId
GROUP BY C.Country, G.Name
ORDER BY Country, Rank_

);
select GS.Country, GS.Genre, GS.Rank_, GS.TotalTracksSold 
from genresales GS
where GS.Rank_ <=3
ORDER BY GS.Country, GS.Rank_;

-- 5. In which countries is Blues the least popular genre?
CREATE TEMPORARY TABLE MaxRanks AS
SELECT Country, MAX(Rank_) AS MaxRank
FROM GenreSales
GROUP BY Country;

SELECT GS.Country, GS.Genre, GS.TotalTracksSold, GS.Rank_
FROM GenreSales GS
JOIN MaxRanks MR ON GS.Country = MR.Country AND GS.Rank_ = MR.MaxRank
ORDER BY GS.Country;
-- 6. Has there been year on year growth? By how much have sales increased per year?
WITH YearlySales AS (
    SELECT YEAR(I.InvoiceDate) AS Year, 
           SUM(I.Total) AS TotalSales
    FROM Invoice I
    GROUP BY YEAR(I.InvoiceDate)
)
    SELECT Year, 
       TotalSales, 
       LAG(TotalSales) OVER (ORDER BY Year) AS PreviousYearSales,
       (TotalSales - LAG(TotalSales) OVER (ORDER BY Year)) AS SalesIncrease
FROM YearlySales;
      
-- 7. How do the sales vary month-to-month as a percentage? 
WITH MonthlySales AS (
    SELECT DATE_FORMAT(I.InvoiceDate, '%Y-%m') AS month, 
           SUM(I.Total) AS TotalSales
    FROM Invoice I
    GROUP BY DATE_FORMAT(I.InvoiceDate, '%Y-%m')
)
    SELECT month, 
       TotalSales, 
       LAG(TotalSales) OVER (ORDER BY month) AS PreviousYearSales,
       (TotalSales - LAG(TotalSales) OVER (ORDER BY month)) AS SalesIncrease,
       ROUND((TotalSales - LAG(TotalSales) OVER (ORDER BY month)) / 
             LAG(TotalSales) OVER (ORDER BY month) * 100, 2) AS GrowthPercentage
FROM MonthlySales;

-- 8. What is the monthly sales growth, categorised by whether it was an increase or decrease compared to the previous month?
WITH MonthlySales AS (
    SELECT DATE_FORMAT(I.InvoiceDate, '%Y-%m') AS month, 
           SUM(I.Total) AS TotalSales
    FROM Invoice I
    GROUP BY DATE_FORMAT(I.InvoiceDate, '%Y-%m')
)
    SELECT month, 
       TotalSales, 
       LAG(TotalSales) OVER (ORDER BY month) AS PreviousYearSales,
       (TotalSales - LAG(TotalSales) OVER (ORDER BY month)) AS SalesIncrease,
       ROUND((TotalSales - LAG(TotalSales) OVER (ORDER BY month)) / 
             LAG(TotalSales) OVER (ORDER BY month) * 100, 2) AS GrowthPercentage,
	 CASE 
           WHEN (TotalSales - LAG(TotalSales) OVER (ORDER BY Month)) > 0 THEN 'Increase'
           WHEN (TotalSales - LAG(TotalSales) OVER (ORDER BY Month)) < 0 THEN 'Decrease'
           ELSE 'No Change'
       END AS GrowthCategory
FROM MonthlySales;
 
-- 9. How many months in the data showed an increase in sales compared to the previous month?

WITH MonthlySales AS (
    SELECT DATE_FORMAT(I.InvoiceDate, '%Y-%m') AS Month, 
           SUM(I.Total) AS TotalSales
    FROM Invoice I
    GROUP BY DATE_FORMAT(I.InvoiceDate, '%Y-%m')
)
SELECT COUNT(*) AS MonthsWithIncrease
FROM (
    SELECT Month, 
           TotalSales, 
           LAG(TotalSales) OVER (ORDER BY Month) AS PreviousMonthSales,
           (TotalSales - LAG(TotalSales) OVER (ORDER BY Month)) AS SalesIncrease
    FROM MonthlySales
) AS SalesComparison
WHERE SalesIncrease > 0;


-- 10. As a percentage of all months in the dataset, how many months in the data showed an increase in sales compared to the previous month?
WITH MonthlySales AS (
    SELECT DATE_FORMAT(I.InvoiceDate, '%Y-%m') AS Month, 
           SUM(I.Total) AS TotalSales
    FROM Invoice I
    GROUP BY DATE_FORMAT(I.InvoiceDate, '%Y-%m')
),
MonthOverMonth AS (
    SELECT Month, 
           TotalSales, 
           LAG(TotalSales) OVER (ORDER BY Month) AS PreviousMonthSales,
           (TotalSales - LAG(TotalSales) OVER (ORDER BY Month)) AS SalesIncrease
    FROM MonthlySales
)
SELECT 
    COUNT(CASE WHEN SalesIncrease > 0 THEN 1 END) * 100.0 / COUNT(*) AS PercentageIncreaseMonths
FROM MonthOverMonth;
;
-- 11. How have purchases of rock music changed quarterly? Show the quarterly change in the amount of tracks sold


WITH QuarterlySales AS (
    SELECT 
    YEAR(I.InvoiceDate) as year, QUARTER(I.InvoiceDate) as quarternum,
    CONCAT(YEAR(I.InvoiceDate), '-Q', QUARTER(I.InvoiceDate)) AS Quarter, 
           COUNT(IL.TrackId) AS RockTracksSold
    FROM Invoice I
    JOIN InvoiceLine IL ON I.InvoiceId = IL.InvoiceId
    JOIN Track T ON IL.TrackId = T.TrackId
    JOIN Genre G ON T.GenreId = G.GenreId
    WHERE G.Name = 'Rock'
    GROUP BY YEAR(I.InvoiceDate), QUARTER(I.InvoiceDate)
)
SELECT Quarter, 
       RockTracksSold,
       LAG(RockTracksSold) OVER (ORDER BY year, quarternum) AS PreviousQuarterSales,
       (RockTracksSold - LAG(RockTracksSold) OVER (ORDER BY year, quarternum)) AS SalesChange
FROM QuarterlySales
ORDER BY Quarter;

-- 12. Determine the average time between purchases for each customer.
with Custmerpurchasestime AS
( select 	I.CustomerId, I.InvoiceDate,
LAG(I.InvoiceDate) over (partition by I.CustomerId order by I.InvoiceDate)AS PreviousPurchase,
DATEDIFF(I.InvoiceDate, LAG(I.InvoiceDate) OVER (PARTITION BY I.CustomerId ORDER BY I.InvoiceDate)) AS DaysBetweenPurchases
    FROM Invoice I
)
SELECT CustomerId,
       ROUND(AVG(DaysBetweenPurchases), 2) AS AvgDaysBetweenPurchases
FROM Custmerpurchasestime
GROUP BY CustomerId
;



