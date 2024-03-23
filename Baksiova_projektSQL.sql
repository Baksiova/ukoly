-- PK kazdej tabulky
SELECT 'account' AS table_name, 'account_id' AS primary_key UNION ALL
SELECT 'card', 'card_id' UNION ALL
SELECT 'client', 'client_id' UNION ALL
SELECT 'disp', 'disp_id' UNION ALL
SELECT 'district', 'district_id' UNION ALL
SELECT 'loan', 'loan_id' UNION ALL
SELECT 'order', 'order_id' UNION ALL
SELECT 'trans', 'trans_id';

-- History of granted loans
-- Prvý dotaz analyzuje vzťah medzi účtami a transakciami a zobrazuje, koľko transakcií pripadá na každý účet.
-- Druhý dotaz poskytuje analýzu poskytnutých úverov v čase,  údaje podľa roka, štvrťroka a mesiaca.
SELECT a.account_id, COUNT(t.trans_id) as transaction_count
FROM account a
         LEFT JOIN trans t ON a.account_id = t.account_id
GROUP BY a.account_id;

SELECT
    EXTRACT(YEAR FROM date) AS loan_year,
    EXTRACT(QUARTER FROM date) AS loan_quarter,
    EXTRACT(MONTH FROM date) AS loan_month,
    SUM(amount) AS loans_total,
    AVG(amount) AS loans_avg,
    COUNT(*) AS loans_count
FROM financial11_56.loan
GROUP BY loan_year, loan_quarter, loan_month WITH ROLLUP
ORDER BY loan_year, loan_quarter, loan_month;

-- Loan status
-- Tento dotaz analyzuje počet úverov podľa ich stavu, čím poskytuje prehľad o tom, koľko úverov sa nachádza v každom špecifickom stave.
SELECT
    status,
    COUNT(*) AS status_count
FROM loan
GROUP BY status;

-- Analysis of accounts

-- SQL dotaz vytvára rebríček úverov na základe sumy, počtu a priemernej výšky úverov pre každý účet, pričom používa výrazy pre bežné tabuľky (CTE)
-- na predspracovanie údajov. Potom používa funkciu ROW_NUMBER() na pridelenie poradia účtom podľa týchto kritérií, umožňujúc detailnú analýzu  úverov.
WITH ranked_loans AS (
    SELECT
        l.account_id,
        SUM(l.amount) AS loans_amount,
        COUNT(l.amount) AS loans_count,
        AVG(l.amount) AS loans_avg
    FROM financial11_56.loan AS l
    WHERE l.status IN ('A', 'C')
    GROUP BY l.account_id
)
SELECT
    r.account_id,
    r.loans_amount,
    r.loans_count,
    r.loans_avg,
    ROW_NUMBER() OVER (ORDER BY r.loan_count DESC, r.loans_amount DESC) AS rank_by_count_and_amount,
    ROW_NUMBER() OVER (ORDER BY r.loans_amount ) AS rank_by_amount,
    ROW_NUMBER() OVER (ORDER BY r.loan_count DESC) AS rank_by_count
FROM ranked_loans AS r;


-- Sumarizujem celkovú sumu úverov rozdelených podľa pohlavia klienta,
-- pričom zohľadňuje len úvery, ktoré boli úplne splatené (označené stavmi 'A' a 'C') a vztahuje sa na vlastníkov účtov. Výsledkom je zistenie, aká je celková suma úverov poskytnutých mužom a ženám.


SELECT
    c.gender,
    sum(l.amount) AS total
FROM
    financial11_56.loan l
        JOIN
    financial11_56.account a ON l.account_id = a.account_id
        JOIN
    financial11_56.disp d ON a.account_id = d.account_id
        JOIN
    financial11_56.client c ON d.client_id = c.client_id
WHERE
    l.status IN ('A', 'C') AND d.type = 'OWNER'
GROUP BY c.gender;

-- Client analysis - part 1

DROP TABLE IF EXISTS tmp_analysis;

CREATE TEMPORARY TABLE tmp_analysis AS

SELECT c.gender,AVG(YEAR(CURRENT_DATE) - YEAR(c.birth_date)) AS average_age

FROM financial11_56.loan l
   JOIN financial11_56.account a ON l.account_id = a.account_id
 JOIN financial11_56.disp d ON a.account_id = d.account_id
 JOIN
    financial11_56.client c ON d.client_id = c.client_id
WHERE
    l.status IN ('A', 'C') AND d.type = 'OWNER'

GROUP BY c.gender;
 -- Tento dotaz vytvára dočasnú tabuľku tmp_analysis, ktorá zahŕňa priemerný vek klientov podľa pohlavia.
 -- Výpočet priemerného veku využíva aktuálny dátum pre získanie aktuálneho roku a odráta rok narodenia klienta, berie do úvahy len úvery so stavom 'A' alebo 'C' a disponentov typu 'OWNER'.


-- Client analysis part 2
 -- Praha ID 1
 -- Najviac klientov :
 SELECT
    d.A2 AS area_name,
    COUNT(DISTINCT c.client_id) AS num_clients
FROM
    client AS c
INNER JOIN
    district AS d ON c.district_id = d.district_id
INNER JOIN
    disp AS disp ON c.client_id = disp.client_id
INNER JOIN
    account AS a ON disp.account_id = a.account_id
WHERE
    disp.type = 'OWNER'
GROUP BY
    d.A2
ORDER BY
    num_clients DESC
LIMIT 1;

-- najviac splatenych loans :
SELECT
    dt.district_id,
    COUNT(l.loan_id) AS total_loans_paid
FROM
    loan l
JOIN
    account a ON l.account_id = a.account_id
JOIN
    disp d ON a.account_id = d.account_id
JOIN
    client c ON d.client_id = c.client_id
JOIN
    district dt ON c.district_id = dt.district_id
WHERE
    l.status IN ('A', 'C') AND d.type = 'OWNER'
GROUP BY
    dt.district_id
ORDER BY
    total_loans_paid DESC
LIMIT 1;


-- najvacsia suma loans, kt. bola zaplatena:
SELECT
    dt.district_id,
    SUM(l.amount) AS total_amount_paid
FROM
    loan l
JOIN
    account a ON l.account_id = a.account_id
JOIN
    disp d ON a.account_id = d.account_id
JOIN
    client c ON d.client_id = c.client_id
JOIN
    district dt ON c.district_id = dt.district_id
WHERE
    l.status IN ('A', 'C') AND d.type = 'OWNER'
GROUP BY
    dt.district_id
ORDER BY
    total_amount_paid DESC
LIMIT 1;

-- Client analysis part 3
--  dotaz určuje množstvo a podiel úverov udelených v jednotlivých oblastiach. Počet zákazníkov, celková suma poskytnutých úverov a ich počet sú zoskupené podľa identifikátora oblasti a výsledok obsahuje aj podiel sumy úverov z každej oblasti vzhľadom na celkovú sumu úverov.
 SELECT
    d.district_id,
    COUNT(DISTINCT c.client_id) AS customer_amount,
    SUM(l.amount) AS loans_given_amount,
    COUNT(l.loan_id) AS loans_given_count,
    SUM(l.amount) / (SELECT SUM(amount) FROM loan WHERE status IN ('A', 'C')) AS amount_share
FROM
    client AS c
        INNER JOIN
    district AS d ON c.district_id = d.district_id
        INNER JOIN
    disp AS disp ON c.client_id = disp.client_id
        INNER JOIN
    account AS a ON disp.account_id = a.account_id
        INNER JOIN
    loan AS l ON a.account_id = l.account_id
WHERE
    l.status IN ('A', 'C') AND disp.type = 'OWNER'
GROUP BY
    d.district_id;


-- Selection 1
--  dotaz identifikuje klientov, ktorí majú viac ako päť úverov a ich zostatok na účte presahuje 1000. Zároveň berie do úvahy iba tie úvery, ktoré sú plne splatené a klienti, ktorí sa narodili po roku 1990. Výsledky sú zoskupené podľa identifikátora klienta
-- prazdny vysledok :/
SELECT
    c.client_id,
    COUNT(DISTINCT l.loan_id) AS num_loans,
    SUM(l.amount - l.payments) AS account_balance
FROM
    client AS c
        INNER JOIN disp AS d ON c.client_id = d.client_id
        INNER JOIN account AS a ON d.account_id = a.account_id
        INNER JOIN loan AS l ON a.account_id = l.account_id
WHERE
    d.type = 'OWNER'
  AND c.birth_date > '1990-01-01'
  AND l.status IN ('A', 'C')
GROUP BY
    c.client_id
HAVING
    COUNT(DISTINCT l.loan_id) > 5
   AND SUM(l.amount - l.payments) > 1000;

-- Selection 2                             \
-- chyba v pocte pujcek a datume narodenia


-- Expiring cards
DELIMITER $$

DROP PROCEDURE IF EXISTS Refresh_Cards_At_Expiration$$

CREATE PROCEDURE Refresh_Cards_At_Expiration(IN p_date DATE)
BEGIN
    -- Odstránenie existujúcej tabuľky, ak existuje
    DROP TABLE IF EXISTS cards_at_expiration;

    -- Vytvorenie novej tabuľky s pridaným stĺpcom pre dátum generovania
    CREATE TABLE cards_at_expiration (
        client_id INT,
        card_id INT,
        expiration_date DATE,
        client_address VARCHAR(255),
        generated_for_date DATE);-- Vloženie údajov do novej tabuľky s použitím poddopytu na výpočet expiration_date
    -- a nastavením stĺpca generated_for_date na dátum zadania procedúry
    INSERT INTO cards_at_expiration (client_id, card_id, expiration_date, client_address, generated_for_date)
    SELECT
        cl.client_id,
        ca.card_id,
        DATE_ADD(ca.issued, INTERVAL 3 YEAR) AS expiration_date, -- Vypočítame dátum expirácie
        di.A3 AS client_address, -- Adresa klienta z tabuľky district
        p_date AS generated_for_date -- Dátum generovania záznamu
    FROM
        card AS ca
        INNER JOIN disp AS d ON ca.disp_id = d.disp_id
        INNER JOIN client AS cl ON d.client_id = cl.client_id
        INNER JOIN district AS di ON cl.district_id = di.district_id
    WHERE
        ca.issued <= '1998-12-31' AND -- Iba karty vydané do konca roku 1998
        DATE_ADD(ca.issued, INTERVAL 3 YEAR) <= p_date;
END$$

DELIMITER ;

-- Spustenie procedúry pre obnovenie tabuľky cards_at_expiration
CALL Refresh_Cards_At_Expiration('2001-12-31')
