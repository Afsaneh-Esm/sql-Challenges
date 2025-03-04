USE chinook;

-- 1. What is the difference in minutes between the total length of 'Rock' tracks and 'Jazz' tracks?
select ABS((select SUM(T.Milliseconds) / 60000
from track T
join genre G on G.GenreId =T.GenreId
where G.Name = 'Jazz')
-
(select SUM(T.Milliseconds) / 60000 
from track T
join genre G on G.GenreId =T.GenreId
where G.Name = 'Rock'))
 AS TimeDifferenceInMinutes;
-- 2. How many tracks have a length greater than the average track length?
select COUNT(*) AS TrackCount 
from track T
where T.Milliseconds > (select avg(T.Milliseconds) from track T);

-- 3. What is the percentage of tracks sold per genre?
SELECT G.Name AS Genre, 
       (COUNT(IL.TrackId) * 100.0) / 
       (SELECT COUNT(*) FROM InvoiceLine) AS PercentageSold
FROM invoiceLine IL
JOIN track T ON IL.TrackId = T.TrackId
JOIN genre G ON T.GenreId = G.GenreId
GROUP BY G.GenreId, G.Name
ORDER BY PercentageSold DESC;


-- 4. Can you check that the column of percentages adds up to 100%?

WITH Genrepercentage AS 
(SELECT G.Name AS Genre, 
       (COUNT(IL.TrackId) * 100.0) / 
       (SELECT COUNT(*) FROM InvoiceLine) AS PercentageSold
FROM invoiceLine IL
JOIN track T ON IL.TrackId = T.TrackId
JOIN genre G ON T.GenreId = G.GenreId
GROUP BY G.GenreId, G.Name
ORDER BY PercentageSold DESC)
select sum(PercentageSold)  AS TotalGenrepercentages from Genrepercentage ;


-- 5. What is the difference between the highest number of tracks in a genre and the lowest?
WITH counttrackgenre AS 
(
select count(T.TrackId) As Counttracks, G.Name 
from track T
join genre G on G.GenreId=T.GenreId
group by G.Name 
order by count(T.TrackId))
select max(Counttracks)- min(Counttracks)As trackdifference from Counttrackgenre ;


SELECT 
    (SELECT MAX(TrackCount) FROM 
        (SELECT COUNT(T.TrackId) AS TrackCount 
         FROM track T 
         JOIN genre G ON T.GenreId = G.GenreId 
         GROUP BY G.GenreId) AS MaxTracks) 
    - 
    (SELECT MIN(TrackCount) FROM 
        (SELECT COUNT(T.TrackId) AS TrackCount 
         FROM track T 
         JOIN genre G ON T.GenreId = G.GenreId 
         GROUP BY G.GenreId) AS MinTracks) 
    AS TrackDifference;


-- 6. What is the average value of Chinook customers (total spending)?
SELECT AVG(CustomerTotal) AS AverageCustomerValue
FROM (
    SELECT C.CustomerId, SUM(I.Total) AS CustomerTotal
    FROM customer C
    JOIN invoice I ON C.CustomerId = I.CustomerId
    GROUP BY C.CustomerId
) AS CustomerSpending;
-- 7. How many complete albums were sold? Not just tracks from an album, but the whole album bought on one invoice.
SELECT COUNT(*) AS CompleteAlbumsSold
FROM (
    SELECT I.InvoiceId, A.AlbumId
    FROM InvoiceLine IL
    JOIN Track T ON IL.TrackId = T.TrackId
    JOIN Album A ON T.AlbumId = A.AlbumId
    JOIN Invoice I ON IL.InvoiceId = I.InvoiceId
    GROUP BY I.InvoiceId, A.AlbumId
    HAVING COUNT(DISTINCT T.TrackId) = 
           (SELECT COUNT(*) FROM Track T2 WHERE T2.AlbumId = A.AlbumId)
) AS CompleteAlbumInvoices;

-- 8. What is the maximum spent by a customer in each genre?

SELECT G.Name AS Genre, C.CustomerId, C.FirstName, C.LastName,  
       MAX(CustomerSpending.TotalSpent) AS MaxSpending
FROM (
    SELECT I.CustomerId, T.GenreId, SUM(IL.UnitPrice * IL.Quantity) AS TotalSpent
    FROM invoiceLine IL
    JOIN invoice I ON IL.InvoiceId = I.InvoiceId
    JOIN track T ON IL.TrackId = T.TrackId
    GROUP BY I.CustomerId, T.GenreId
) AS CustomerSpending 
JOIN genre G ON CustomerSpending.GenreId = G.GenreId
JOIN customer C ON CustomerSpending.CustomerId = C.CustomerId
GROUP BY G.GenreId, C.CustomerId
ORDER BY MaxSpending DESC;
select BillingState, InvoiceDate from invoice;

-- 9. What percentage of customers who made a purchase in 2022 returned to make additional purchases in subsequent years?
CREATE TEMPORARY TABLE Datetable(
select distinct I.CustomerId, I.InvoiceDate
from invoice I
where year(InvoiceDate)=2022 and EXISTS (
    SELECT 1 FROM invoice I2 
    WHERE I2.CustomerId = I.CustomerId 
    AND YEAR(I2.InvoiceDate) > 2022)
);
SELECT 
    (COUNT(DISTINCT D.CustomerId) * 100.0) / 
    (SELECT COUNT(DISTINCT I.CustomerId) FROM Invoice I WHERE YEAR(I.InvoiceDate) = 2022) 
    AS ReturningCustomerPercentage
FROM Datetable D;

-- 10. Which genre is each employee most successful at selling? Most successful is greatest amount of tracks sold.

WITH Mostsellingtrack AS (
    SELECT SUM(il.quantity) AS QuantitySoldInGenre, CONCAT(e.firstname, " ", e.lastname) AS EmployeeName,
           E.EmployeeId, 
           G.Name AS GenreName
    FROM Employee E 
    JOIN Customer C ON E.EmployeeId = C.SupportRepId
    JOIN Invoice I ON C.CustomerId = I.CustomerId
    JOIN InvoiceLine IL ON I.InvoiceId = IL.InvoiceId
    JOIN Track T ON IL.TrackId = T.TrackId
    JOIN Genre G ON T.GenreId = G.GenreId
    GROUP BY E.EmployeeId, G.Name
)
SELECT EmployeeId, GenreName, QuantitySoldInGenre, EmployeeName
FROM Mostsellingtrack
WHERE QuantitySoldInGenre= (
    SELECT MAX(QuantitySoldInGenre) 
    FROM Mostsellingtrack AS Sub
    WHERE Sub.EmployeeId = Mostsellingtrack.EmployeeId
);

--------------------------------------------------------------------------------------------------------------------------

CREATE TEMPORARY TABLE AmountSoldPerEmployeePerGenre (
SELECT 
	e.employeeid,
    CONCAT(e.firstname, " ", e.lastname) AS EmployeeName,
    g.Name AS GenreName,
    SUM(il.quantity) AS QuantitySoldInGenre
FROM
	employee e
    JOIN customer c
		ON e.employeeid = c.supportrepid
	JOIN invoice i
		USING (customerid)
	JOIN invoiceline il
		USING (invoiceid)
	JOIN track t
		USING (trackid)
	JOIN genre g
		USING (genreid)
GROUP BY e.employeeid, g.genreid, g.Name
);

CREATE TEMPORARY TABLE MaxSoldPerEmployeePerGenre (
SELECT
	employeeid,
    EmployeeName,
    MAX(QuantitySoldInGenre) AS MaxSold
FROM
	AmountSoldPerEmployeePerGenre
GROUP BY employeeid, EmployeeName
);

SELECT 
	a.EmployeeName,
    a.GenreName, MaxSold
FROM
	MaxSoldPerEmployeePerGenre m
	JOIN
		AmountSoldPerEmployeePerGenre a USING (employeeid)
WHERE m.MaxSold = a.QuantitySoldInGenre;



-- 11. How many customers made a second purchase the month after their first purchase?

WITH FirstPurchase AS (
    SELECT
        CustomerId,
        MIN(InvoiceDate) AS FirstPurchaseDate
    FROM Invoice
    GROUP BY CustomerId
),
SecondPurchase AS (
    SELECT
        i.CustomerId,
        i.InvoiceDate AS SecondPurchaseDate
    FROM Invoice i
    JOIN FirstPurchase fp
        ON i.CustomerId = fp.CustomerId
    WHERE i.InvoiceDate > fp.FirstPurchaseDate
),
ValidSecondPurchase AS (
    SELECT
        sp.CustomerId
    FROM SecondPurchase sp
    JOIN FirstPurchase fp
        ON sp.CustomerId = fp.CustomerId
    WHERE DATE_FORMAT(sp.SecondPurchaseDate, '%Y-%m') = DATE_FORMAT(DATE_ADD(fp.FirstPurchaseDate, INTERVAL 1 MONTH), '%Y-%m')
)
SELECT COUNT(DISTINCT CustomerId) AS CustomersMadeSecondPurchaseNextMonth
FROM ValidSecondPurchase;





