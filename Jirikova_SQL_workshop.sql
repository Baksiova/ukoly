-- Using the financial5_56 database for the following queries
USE financial5_56;

###############################################
-- History of granted loans
###############################################
-- This query calculates a summary of granted loans based on different dimensions: year, quarter, and month.
-- It also includes totals for each dimension and overall totals.
SELECT
    YEAR(l.date) AS year,
    QUARTER(l.date) AS quarter,
    MONTH(l.date) AS month,
    SUM(l.amount) AS total_amount_of_loans,
    AVG(l.amount) AS average_loan_amount,
    COUNT(*) AS total_number_of_given_loans
FROM
    loan l
GROUP BY
    YEAR(l.date),
    QUARTER(l.date),
    MONTH(l.date)
WITH ROLLUP; -- -- Includes extra rows that represent subtotals and grand totals for each grouping level.

###############################################
-- Loan status
###############################################
-- This query retrieves the count of loans for each unique status value in the Loan table.
-- There are a total of 682 granted loans in the database, of which 606 have been repaid and 76 have not.
-- Paid loans: A (203), C (403)
-- Unpaid loans: B (31), D (45)
SELECT * FROM loan;
SELECT count(*) FROM loan;

SELECT
    status,
    COUNT(*) AS count_of_loans
FROM
    loan
GROUP BY
    status;

###############################################
-- Analysis of accounts
###############################################
-- This query retrieves information about accounts, including the number of given loans, total amount of loans, and average loan amount.
-- It considers only fully paid loans (statuses 'A' and 'C').
SELECT  a.account_id,
        COUNT(l.loan_id) AS number_of_given_loans,
        SUM(l.amount) AS total_amount_of_loans,
        AVG(l.amount) AS average_loan_amount
FROM account a
LEFT JOIN loan l USING (account_id)
WHERE l.status IN ('A', 'C') -- Selects only fully paid loans (statuses 'A' and 'C')
GROUP BY a.account_id
ORDER BY COUNT(l.loan_id) DESC, -- Ranks by the number of given loans (decreasing)
        SUM(l.amount) DESC, -- Ranks by the total amount of given loans (decreasing)
        AVG(l.amount) DESC; -- Ranks by the average loan amount

###############################################
-- Fully paid loans
###############################################
-- This script calculates the number of loans that have been repaid and the total amount repaid, divided by client gender.
-- It first creates a temporary table 'fpl_results' to store the aggregated data.
-- Then, it retrieves and displays the contents of the temporary table.
-- Next, it calculates the differences between the total counts and amounts from 'fpl_results' and the counts and amounts calculated directly from the 'loan' table.
-- The results are displayed as 'loan_difference' and 'amount_difference'.
DROP TABLE IF EXISTS tmp_fpl_result;
CREATE TEMPORARY TABLE tmp_fpl_result AS
SELECT  c.gender,
        COUNT(l.account_id) AS total_loans_repaid,
        SUM(l.amount) AS total_amount_repaid
FROM disp d
INNER JOIN account a USING (account_id)
INNER JOIN loan l USING (account_id)
INNER JOIN client c USING (client_id)
WHERE l.status IN ('A', 'C') AND d.type = 'OWNER'
GROUP BY c.gender;

SELECT * FROM tmp_fpl_result;

WITH cte AS (
    SELECT  COUNT(l.account_id) AS HOW_many,
            SUM(amount) AS HOW_much
    FROM loan AS l
    WHERE l.status IN ('A', 'C')),
fpl_results AS (
    SELECT  c.gender,
            COUNT(l.account_id) AS total_loans_repaid,
            SUM(l.amount) AS total_amount_repaid
    FROM disp d
    INNER JOIN  account a USING (account_id)
    INNER JOIN  loan l USING (account_id)
    INNER JOIN client c USING (client_id)
    WHERE l.status IN ('A', 'C') AND d.type = 'OWNER'
    GROUP BY c.gender
)
SELECT
    ((SELECT SUM(total_loans_repaid) FROM tmp_fpl_result) - (SELECT HOW_many FROM cte)) AS loan_difference,
    ((SELECT SUM(total_amount_repaid) FROM tmp_fpl_result) - (SELECT HOW_much FROM cte)) AS amount_difference;

###############################################
-- Client analysis - part 1
###############################################
-- The analysis shows that women (F) have a higher total number of repaid loans (307) compared to men (M) with 299 repaid loans.
-- However, men have a slightly higher average borrower age (66.8729 years) compared to women (64.8502 years).
DROP TABLE IF EXISTS tmp_fpl_result;
CREATE TEMPORARY TABLE tmp_fpl_result AS
SELECT  c.gender,
        COUNT(l.account_id) AS total_loans_repaid,
        SUM(l.amount) AS total_amount_repaid,
        AVG(YEAR(CURRENT_DATE()) - YEAR(c.birth_date)) AS average_borrower_age
FROM disp d
INNER JOIN account a USING (account_id)
INNER JOIN loan l USING (account_id)
INNER JOIN client c USING (client_id)
WHERE l.status IN ('A', 'C') AND d.type = 'OWNER'
GROUP BY c.gender;

SELECT * FROM tmp_fpl_result;

###############################################
-- Client analysis - part 2
###############################################
-- Analysis 1: Area with the most clients who are account owners
-- (all clients - does not matter if their loans are paid or not)
-- Hl.m. Praha (79) - 73 (paid), 6 (unpaid)
SELECT  d.A2 AS area_name,
        COUNT(DISTINCT c.client_id) AS num_clients,
        COUNT(l.loan_id) AS num_loans,
        SUM(l.amount) AS loans_amount
FROM district AS d
INNER JOIN client AS c USING (district_id)
INNER JOIN disp AS disp USING (client_id)
INNER JOIN account AS a USING (account_id)
INNER JOIN loan AS l USING (account_id)
WHERE disp.type = 'OWNER'
GROUP BY d.A2
ORDER BY num_clients DESC;

-- Analysis 2: Area with the highest number of loans paid among account owners
-- Analysis 3: Area with the highest amount of loans paid among account owners
DROP TABLE IF EXISTS tmp_district_analytics;
CREATE TEMPORARY TABLE tmp_district_analytics AS
SELECT  d.A2 AS area_name,
        COUNT(l.loan_id) AS num_loans_paid,
        SUM(l.amount) AS loans_amount_paid
FROM district AS d
INNER JOIN client AS c USING (district_id)
INNER JOIN disp AS disp USING (client_id)
INNER JOIN account AS a USING (account_id)
INNER JOIN loan AS l USING (account_id)
WHERE disp.type = 'OWNER' AND l.status IN ('A', 'C')
GROUP BY d.A2
ORDER BY num_loans_paid DESC;

-- Analysis 2: Area with the highest number of loans paid among account owners
-- Hl.m. Praha (73)
SELECT *
FROM tmp_district_analytics
ORDER BY num_loans_paid DESC
LIMIT 1;

-- Analysis 3: Area with the highest amount of loans paid among account owners
-- Hl.m. Praha (10502628)
SELECT *
FROM tmp_district_analytics
ORDER BY loans_amount_paid DESC
LIMIT 1;

###############################################
-- Client analysis - part 3
###############################################
-- Query to determine the percentage of each district in the total amount of loans granted.
-- It considers both paid and unpaid loans.
    -- "Granted loans"  are loans that have been provided  to the borrower by the lender.
    -- Therefore, when determining the percentage of granted loans by region,
    -- it usually includes both paid and unpaid loans.
SELECT d.A2 AS area_name,
        COUNT(DISTINCT c.client_id) AS customer_count,
        SUM(l.amount) AS loans_given_amount,
        COUNT(l.loan_id) AS loans_given_count,
        CAST((SUM(l.amount) / SUM(SUM(l.amount)) OVER ()) * 100 AS DECIMAL(10, 2)) AS amount_share_percentage -- Calculating the percentage of loans given amount for each district
FROM disp AS disp
INNER JOIN account AS a USING (account_id)
INNER JOIN loan AS l USING (account_id)
INNER JOIN client AS c USING (client_id)
INNER JOIN district AS d ON c.district_id = d.district_id
WHERE disp.type = 'OWNER' -- Select only account owners
GROUP BY d.A2
ORDER BY amount_share_percentage DESC;

###############################################
-- Client selection - part 1
###############################################
-- This query retrieves clients who meet the specified criteria:
-- 1. Their account balance is above 1000.
-- 2. They have more than 5 loans.
-- 3. They were born after 1990.

-- SELECT statement returned 0 rows.
SELECT c.client_id,
        c.gender,
        c.birth_date,
        COUNT(DISTINCT l.loan_id) AS num_loans,
        SUM(l.amount - l.payments) AS account_balance
FROM loan AS l
INNER JOIN account AS a USING (account_id)
INNER JOIN disp AS disp USING (account_id)
INNER JOIN client AS c USING (client_id)
WHERE disp.type = 'OWNER'
GROUP BY c.client_id, c.gender, c.birth_date
HAVING  account_balance > 1000
        AND num_loans > 5
        AND YEAR(birth_date) > 1990;

###############################################
-- Client selection - part 2
###############################################
-- This query analyzes the dataset to identify which condition(s) caused the empty results in the previous exercise.
SELECT  c.client_id,
        c.gender,
        c.birth_date,
        COUNT(DISTINCT l.loan_id) AS num_loans,
        SUM(l.amount - l.payments) AS account_balance
FROM loan AS l
INNER JOIN account AS a USING (account_id)
INNER JOIN disp AS disp USING (account_id)
INNER JOIN client AS c USING (client_id)
WHERE disp.type = 'OWNER'
GROUP BY c.client_id, c.gender, c.birth_date
HAVING  account_balance > 1000
    --  AND num_loans > 5            -- maximum number of loans per client is 1
    --  AND YEAR(birth_date) > 1990  -- latest birth year of client is 1980
ORDER BY account_balance DESC;

###############################################
-- Expiring cards
###############################################
DELIMITER $$
DROP PROCEDURE IF EXISTS Refresh_Cards_At_Expiration$$
CREATE PROCEDURE Refresh_Cards_At_Expiration(IN p_date DATETIME)
BEGIN
    -- Drop the existing table if it exists
    DROP TABLE IF EXISTS cards_at_expiration;

    -- Create the new table
    CREATE TABLE cards_at_expiration (
        client_id INT,
        card_id INT,
        expiration_date DATE,
        client_address VARCHAR(255)
    ); -- Add semicolon here

    -- Insert into the new table using a subquery to calculate expiration_date
    INSERT INTO cards_at_expiration (client_id, card_id, expiration_date, client_address)
    SELECT  c.client_id,
            ca.card_id,
            DATE_ADD(ca.issued, INTERVAL 3 YEAR) AS expiration_date,
            d.A3 AS client_address
    FROM card AS ca
    INNER JOIN disp AS disp USING (disp_id)
    INNER JOIN client AS c USING (client_id)
    INNER JOIN district AS d ON c.district_id = d.district_id
    WHERE
        -- records with expiration dates 7 days or less from the p_date
        DATE_ADD(ca.issued, INTERVAL 3 YEAR) BETWEEN p_date AND DATE_ADD(p_date, INTERVAL 7 DAY);
END $$
DELIMITER ;

CALL Refresh_Cards_At_Expiration('2001-12-24');
-- The card table has cards that were issued until the end of 1998.
    -- Calling the Refresh_Cards_At_Expiration procedure
    -- with a date 7 days before the end of the year 2001 to simulate card expiration.

SELECT * FROM cards_at_expiration;
-- Displaying the records of cards_at_expiration table,
-- which contains the last expired cards from the end of the year 1998.
########################################################################
########################################################################
########################################################################