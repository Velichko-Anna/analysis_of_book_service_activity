
-- Расчет MAU авторов 
WITH get_mau_author_id AS (
    SELECT 
        main_content_id, 
        puid
    FROM bookmate.audition
    WHERE EXTRACT(MONTH FROM msk_business_dt_str::date) = 11
)
SELECT 
    a.main_author_name, 
    count(distinct gma.puid) AS mau
FROM get_mau_author_id AS gma 
JOIN bookmate.content AS c ON gma.main_content_id = c.main_content_id
JOIN bookmate.author AS a ON c.main_author_id = a.main_author_id
group by a.main_author_name
ORDER BY mau DESC
LIMIT 3;

-- Расчет MAU произведений
WITH get_content_november AS (
    SELECT 
        main_content_id, 
        puid
    FROM bookmate.audition
    WHERE EXTRACT(MONTH FROM msk_business_dt_str::date) = 11
)
SELECT 
    c.main_content_name, 
    c.published_topic_title_list, 
    a.main_author_name, 
    COUNT(DISTINCT gcn.puid) AS mau
FROM get_content_november AS gcn
JOIN bookmate.content AS c ON gcn.main_content_id = c.main_content_id
JOIN bookmate.author AS a ON a.main_author_id = c.main_author_id
GROUP BY c.main_content_name, c.published_topic_title_list, a.main_author_name
ORDER BY COUNT(DISTINCT gcn.puid) DESC
LIMIT 3;

-- Расчёт Retention Rate
WITH get_december_info AS (
   SELECT DISTINCT puid
FROM bookmate.audition
WHERE msk_business_dt_str::date = '2024-12-02'
),
user_activity AS (
SELECT
    a.puid,
    DATE(a.msk_business_dt_str) - DATE('2024-12-02') AS day_since_install,
    (SELECT COUNT(DISTINCT puid) FROM get_december_info) AS total_users,
    COUNT(d.puid) OVER() AS useless_hernya
FROM bookmate.audition a
JOIN get_december_info d ON a.puid = d.puid
WHERE DATE(a.msk_business_dt_str) >= '2024-12-02'
)
SELECT 
    day_since_install,
    COUNT(DISTINCT puid) AS retained_users,
    ROUND(COUNT(DISTINCT puid)::numeric / MAX(total_users)::numeric, 2) AS retention_rate
FROM user_activity
GROUP BY day_since_install
ORDER BY day_since_install ASC;

-- Расчет LTV
WITH user_activity AS(
    SELECT
        usage_geo_id_name AS city,
        puid,
        COUNT(DISTINCT DATE_TRUNC('month', msk_business_dt_str::date)) AS active_months
    FROM bookmate.audition a
    JOIN bookmate.geo g ON a.usage_geo_id = g.usage_geo_id
    WHERE usage_geo_id_name IN ('Москва', 'Санкт-Петербург')
    GROUP BY usage_geo_id_name, puid
)
SELECT 
    city,
    COUNT(puid) AS total_users,
    ROUND(SUM(active_months)::numeric * 399 / COUNT(puid)::numeric, 2) AS ltv
FROM user_activity
GROUP BY city;

-- Расчёт средней выручки прослушанного часа — аналог среднего чека
WITH mau AS (
    SELECT 
        TO_CHAR(DATE_TRUNC('month', msk_business_dt_str::date), 'YYYY-MM-DD') AS month,
    ROUND(SUM(hours), 2) AS hours,
    COUNT (DISTINCT ba.puid) AS mau
    FROM bookmate.audition AS ba
    WHERE msk_business_dt_str::date BETWEEN '2024-09-01' AND '2024-11-30'
    GROUP BY month
)
SELECT 
    month::date,
    mau, 
    hours, 
    ROUND(mau*399/hours, 2) AS avg_hour_rev -- 399 - стоимость месячного доступа
FROM mau
