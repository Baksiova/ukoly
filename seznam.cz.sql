--ukol 1:

SELECT
    impression_logs.ad_id,
    COUNT(impression_logs.impression_id) AS impressions,
    COUNT(click_logs.impression_id) AS clicks,
    SUM(click_logs.cpc) AS total_CPC,
    COUNT(conversion_logs.impression_id) AS conversions,
    SUM(conversion_logs.value) AS total_conversion_value
FROM
    impression_logs
LEFT JOIN
    click_logs ON impression_logs.impression_id = click_logs.impression_id
LEFT JOIN
    conversion_logs ON impression_logs.impression_id = conversion_logs.impression_id
WHERE
    impression_logs.advertiser_id = 123
GROUP BY
    impression_logs.ad_id;
	
-- ukol 2

SELECT
    impression_logs.zone_id,
    AVG(click_logs.cpc) AS average_CPC
FROM
    impression_logs
JOIN
    click_logs ON impression_logs.impression_id = click_logs.impression_id
GROUP BY
    impression_logs.zone_id
ORDER BY
    average_CPC DESC
LIMIT 10;

--ukol 3, tady sa mi zda, ze neni nutne dle zadani specifikovat inzerenta pres WHERE clause, pretoze staci najst top 3 regiony a ty doporucit

SELECT
    impression_logs.region,
    COUNT(click_logs.impression_id) / COUNT(impression_logs.impression_id) AS CTR
FROM
    impression_logs
LEFT JOIN
    click_logs ON impression_logs.impression_id = click_logs.impression_id
GROUP BY
    impression_logs.region
ORDER BY
    CTR DESC
LIMIT 3;
