use magist;
-- 1) Find the average review score by state of the customer.
select avg(ORE.review_score) , SC.name
from order_reviews ORE
join orders O using (order_id)
join customers C using(customer_id)
join geo G on C.customer_zip_code_prefix= G.zip_code_prefix
join state_codes SC on G.state=SC.subdivision
group by SC.name
order by avg(ORE.review_score) desc
limit 5;

-- 2)Do reviews containing positive words have a better score? Some Portuguese positive words are: 
-- “bom”, “otimo”, “gostei”, “recomendo” and “excelente”.
select
AVG(ORE.review_score)
FROM
    order_reviews ORE
        JOIN
    orders O USING (order_id)
        JOIN
    customers C USING (customer_id)
        JOIN
    geo g ON C.customer_zip_code_prefix = G.zip_code_prefix;

select
AVG(ORE.review_score)
FROM
    order_reviews ORE
        JOIN
    orders O USING (order_id)
        JOIN
    customers C USING (customer_id)
        JOIN
    geo g ON C.customer_zip_code_prefix = G.zip_code_prefix
where ORE.review_comment_message like  '%bom%'
        OR ORE.review_comment_message LIKE '%otimo%'
        OR ORE.review_comment_message LIKE '%gostei%'
        OR ORE.review_comment_message LIKE '%recomendo%'
        OR ORE.review_comment_message LIKE '%excelente%';
        
-- 3)Considering only states having at least 30 reviews containing these words, what is the state with the highest score?

CREATE TEMPORARY TABLE Temp_Review_Count AS
SELECT 
    SC.name AS state_name, 
    COUNT(DISTINCT ORE.review_id) AS review_count
FROM order_reviews ORE
JOIN orders O USING (order_id)
JOIN customers C USING (customer_id)
JOIN geo G ON C.customer_zip_code_prefix = G.zip_code_prefix
JOIN state_codes SC ON G.state = SC.subdivision
WHERE ORE.review_comment_message LIKE '%bom%'
   OR ORE.review_comment_message LIKE '%otimo%'
   OR ORE.review_comment_message LIKE '%gostei%'
   OR ORE.review_comment_message LIKE '%recomendo%'
   OR ORE.review_comment_message LIKE '%excelente%'
GROUP BY SC.name
HAVING review_count > 30;

SELECT 
    TRC.state_name, TRC.review_count,
    AVG(ORE.review_score) AS avg_review_score
FROM Temp_Review_Count TRC
JOIN order_reviews ORE
JOIN orders O USING (order_id)
JOIN customers C USING (customer_id)
JOIN geo G ON C.customer_zip_code_prefix = G.zip_code_prefix
JOIN state_codes SC ON G.state = SC.subdivision
ON TRC.state_name = SC.name
GROUP BY TRC.state_name , TRC.review_count
ORDER BY avg_review_score DESC
;
        
-- 4)What is the state where there is a greater score change between all reviews and reviews containing positive words?
CREATE TEMPORARY TABLE Reviews_containing_pos_words AS
SELECT 
    SC.name AS name,  -- Use "name" instead of "state_name" for consistency
    AVG(ORE.review_score) AS positive_review_average
FROM order_reviews ORE
JOIN orders O USING (order_id)
JOIN customers C USING (customer_id)
JOIN geo G ON C.customer_zip_code_prefix = G.zip_code_prefix
JOIN state_codes SC ON G.state = SC.subdivision
WHERE ORE.review_comment_message LIKE '%bom%'
   OR ORE.review_comment_message LIKE '%otimo%'
   OR ORE.review_comment_message LIKE '%gostei%'
   OR ORE.review_comment_message LIKE '%recomendo%'
   OR ORE.review_comment_message LIKE '%excelente%'
GROUP BY SC.name;

SELECT 
    SC.name AS state_name, 
    AVG(ORE.review_score) AS overall_review_average, 
    RCP.positive_review_average,
    (AVG(ORE.review_score) - RCP.positive_review_average) AS difference
FROM order_reviews ORE
JOIN orders O USING (order_id)
JOIN customers C USING (customer_id)
JOIN geo G ON C.customer_zip_code_prefix = G.zip_code_prefix
JOIN state_codes SC ON G.state = SC.subdivision
JOIN Reviews_containing_pos_words RCP ON SC.name = RCP.name
GROUP BY SC.name, RCP.positive_review_average
ORDER BY difference DESC
LIMIT 1;
-- 5) Create a stored procedure that gets as input:
-- The name of a state (the full name from the table you imported).
-- The name of a product category (in English).
-- A year
-- And outputs the average score for reviews left by customers from the given
-- state for orders with the status “delivered, containing at least a product in 
-- the given category, and placed on the given year.

DELIMITER $$

CREATE PROCEDURE Averagescore (
    IN statenama VARCHAR(255), 
    IN productcategory VARCHAR(255), 
    IN year INT
)
BEGIN
    SELECT 
        AVG(ORE.review_score) AS average_score, 
        PCNE.product_category_name_english, 
        SC.name AS state_name
    FROM order_reviews ORE
    JOIN orders O USING (order_id)
    JOIN customers C USING (customer_id)
    JOIN geo G ON G.zip_code_prefix = C.customer_zip_code_prefix
    JOIN state_codes SC ON G.state = SC.subdivision
    JOIN order_items OI USING (order_id)
    JOIN products P USING (product_id)
    JOIN product_category_name_translation PCNE ON P.product_category_name = PCNE.product_category_name
    WHERE SC.name = statenama 
      AND PCNE.product_category_name_english = productcategory
      AND YEAR(O.order_purchase_timestamp) = year
      AND O.order_status = 'delivered'
    GROUP BY SC.name, PCNE.product_category_name_english;
END $$

DELIMITER ;
CALL Averagescore('Rio de Janeiro', 'health_beauty', 2017)