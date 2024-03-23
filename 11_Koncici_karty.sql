CREATE TABLE cards_at_expiration #vytvoření tabulky
(
    client_id       int                      not null,
    card_id         int default 0            not null,
    expiration_date date                     null,
    A3              varchar(15) charset utf8 not null,
    generated_for_date date                     null
);

-- Nastavíme vlastní oddělovač, aby bylo možné v proceduře používat středníky
DELIMITER $$

-- Odstraníme proceduru, pokud již existuje, aby bylo možné ji znovu vytvořit
DROP PROCEDURE IF EXISTS generate_cards_at_expiration_report;

-- Vytvoříme novou proceduru s názvem 'generate_cards_at_expiration_report'
CREATE PROCEDURE generate_cards_at_expiration_report(p_date DATE)
BEGIN
    -- Vyprázdníme tabulku 'cards_at_expiration' před vložením nových dat
    TRUNCATE TABLE cards_at_expiration;

    -- Vložíme data do tabulky 'cards_at_expiration'
    INSERT INTO cards_at_expiration
    WITH CTE AS
        (
        -- Vytvoříme Common Table Expression (CTE) pro lepší čitelnost a strukturu dotazu
        SELECT
            d.client_id,  -- Vybereme ID klienta
            a.card_id,  -- Vybereme ID karty
            DATE_ADD(a.issued, INTERVAL 3 YEAR) AS expiration_date,  -- Vypočítáme datum expirace karty přidáním 3 let k datu vydání
            c2.A3 AS client_adress  -- Vybereme adresu klienta z tabulky 'district'
        FROM
            card AS a  -- Hlavní tabulka pro karty
        JOIN
            disp AS c USING (disp_id)  -- Připojíme tabulku 'disp' pomocí 'disp_id'
        JOIN
            client AS d USING (client_id)  -- Připojíme tabulku 'client' pomocí 'client_id'
        JOIN
            district AS c2 ON d.district_id = c2.district_id  -- Připojíme tabulku 'district' pomocí 'district_id'
        )
    -- Vybereme všechny sloupce z CTE a přidáme parametr 'p_date' jako 'generated_for_date'
    SELECT *, p_date AS generated_for_date
    FROM CTE
    -- Filtrujeme záznamy, kde 'p_date' spadá do 7 dnů před datem expirace karty až do samotného data expirace
    WHERE p_date BETWEEN DATE_ADD(expiration_date, INTERVAL -7 DAY) AND expiration_date;
END;

-- Vrátíme se k výchozímu oddělovači
DELIMITER ;


#Kontrola
CALL generate_cards_at_expiration_report('2001-01-01');
SELECT * FROM cards_at_expiration;
