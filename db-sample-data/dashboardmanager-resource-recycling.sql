--
-- Resource recycling per-capita component seed data
--

BEGIN;

ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS timeline_config json;

DELETE FROM public.query_charts
WHERE "index" = 'resource_recycling_per_capita'
  AND city IN ('taipei', 'metrotaipei');

DELETE FROM public.component_charts
WHERE "index" = 'resource_recycling_per_capita';

DELETE FROM public.components
WHERE "index" = 'resource_recycling_per_capita'
   OR id = 371;

INSERT INTO public.components (id, "index", name)
VALUES (371, 'resource_recycling_per_capita', '雙北資源回收雷達圖');

INSERT INTO public.component_charts ("index", color, types, unit, timeline_config)
VALUES (
    'resource_recycling_per_capita',
    ARRAY['#5CA8D8', '#F8CF58', '#9B7EDE'],
    ARRAY['RadarChart'],
    '指標',
    '{"enabled": true, "granularity": "month", "nameDelimiter": "::"}'::json
);

INSERT INTO public.query_charts (
    "index",
    history_config,
    map_config_ids,
    map_filter,
    time_from,
    time_to,
    update_freq,
    update_freq_unit,
    source,
    short_desc,
    long_desc,
    use_case,
    links,
    contributors,
    created_at,
    updated_at,
    query_type,
    query_chart,
    query_history,
    city
)
VALUES
(
    'resource_recycling_per_capita',
    NULL,
    '{}',
    '{}',
    'static',
    NULL,
    1,
    'month',
    '環境部、主計總處',
    '顯示雙北與其他縣市人均資源回收指標',
    '彙整執行機關資源回收量月資料，保留臺北市與新北市，其他縣市合併後依回收物類別加總，再除以 109 年常住人口。每個月份依各資收分類內最高人均值標準化為 100 分指標，並以時間線切換月份。',
    '可用於聚焦比較臺北市、新北市與其他縣市在紙類、金屬、塑膠、玻璃等回收類別的人均相對表現，並透過時間線追蹤各月份變化。',
    ARRAY['https://data.moenv.gov.tw/dataset/detail/STAT_P_132'],
    ARRAY['doit'],
    '2026-05-02 00:00:00+00',
    '2026-05-02 00:00:00+00',
    'three_d',
    $sql$
WITH aggregated AS (
    SELECT
        c.stat_year,
        c.stat_month,
        c.period,
        CASE WHEN c.county_city = '臺北市' THEN c.county_city ELSE '其他縣市' END AS area,
        c.category,
        SUM(c.amount_ton) AS amount_ton,
        SUM(c.resident_population) AS resident_population
    FROM (
        SELECT
            r.stat_year,
            r.stat_month,
            r.period,
            r.county_city,
            r.category,
            SUM(r.amount_ton) AS amount_ton,
            MAX(p.resident_population) AS resident_population
        FROM public.resource_recycling_amounts r
        JOIN public.county_resident_population_109 p
          ON p.county_city = r.county_city
        WHERE r.stat_month IS NOT NULL
        GROUP BY r.stat_year, r.stat_month, r.period, r.county_city, r.category
    ) c
    GROUP BY
        c.stat_year,
        c.stat_month,
        c.period,
        CASE WHEN c.county_city = '臺北市' THEN c.county_city ELSE '其他縣市' END,
        c.category
),
-- 計算公式
per_capita AS (
    SELECT
        stat_year,
        stat_month,
        period,
        area,
        category,
        amount_ton * 1000000 / NULLIF(resident_population, 0) AS grams_per_person
    FROM aggregated
)
SELECT
    CASE p.category
        WHEN '紙類及紙製品' THEN '紙類'
        WHEN '金屬類' THEN '金屬'
        WHEN '塑膠及橡膠製品' THEN '塑膠橡膠'
        WHEN '玻璃製品' THEN '玻璃'
        WHEN '家電用品' THEN '家電'
        WHEN '資訊及通信物品' THEN '資通訊物品'
        WHEN '農藥容器及特殊環境用藥容器' THEN '農藥容器'
        ELSE p.category
    END AS x_axis,
    CONCAT(REPLACE(p.period, ' ', ''), '::', p.area) AS y_axis,
    ROUND((p.grams_per_person / NULLIF(MAX(p.grams_per_person) OVER (PARTITION BY p.stat_year, p.stat_month, p.category), 0) * 100)::numeric)::int AS data
FROM per_capita p
ORDER BY
    p.stat_year DESC,
    p.stat_month DESC,
    ARRAY_POSITION(ARRAY[
        '紙類及紙製品', '金屬類', '塑膠及橡膠製品', '玻璃製品', '紡織品',
        '家電用品', '電池', '資訊及通信物品', '農藥容器及特殊環境用藥容器',
        '食用油', '其他'
    ]::text[], p.category),
    ARRAY_POSITION(ARRAY['臺北市', '其他縣市']::text[], p.area)
    $sql$,
    NULL,
    'taipei'
),
(
    'resource_recycling_per_capita',
    NULL,
    '{}',
    '{}',
    'static',
    NULL,
    1,
    'month',
    '環境部、主計總處',
    '顯示雙北與其他縣市人均資源回收指標',
    '彙整執行機關資源回收量月資料，保留臺北市與新北市，其他縣市合併後依回收物類別加總，再除以 109 年常住人口。每個月份依各資收分類內最高人均值標準化為 100 分指標，並以時間線切換月份。',
    '可用於聚焦比較臺北市、新北市與其他縣市在紙類、金屬、塑膠、玻璃等回收類別的人均相對表現，並透過時間線追蹤各月份變化。',
    ARRAY['https://data.moenv.gov.tw/dataset/detail/STAT_P_132'],
    ARRAY['doit'],
    '2026-05-02 00:00:00+00',
    '2026-05-02 00:00:00+00',
    'three_d',
    $sql$
WITH aggregated AS (
    SELECT
        c.stat_year,
        c.stat_month,
        c.period,
        CASE WHEN c.county_city IN ('臺北市', '新北市') THEN c.county_city ELSE '其他縣市' END AS area,
        c.category,
        SUM(c.amount_ton) AS amount_ton,
        SUM(c.resident_population) AS resident_population
    FROM (
        SELECT
            r.stat_year,
            r.stat_month,
            r.period,
            r.county_city,
            r.category,
            SUM(r.amount_ton) AS amount_ton,
            MAX(p.resident_population) AS resident_population
        FROM public.resource_recycling_amounts r
        JOIN public.county_resident_population_109 p
          ON p.county_city = r.county_city
        WHERE r.stat_month IS NOT NULL
        GROUP BY r.stat_year, r.stat_month, r.period, r.county_city, r.category
    ) c
    GROUP BY
        c.stat_year,
        c.stat_month,
        c.period,
        CASE WHEN c.county_city IN ('臺北市', '新北市') THEN c.county_city ELSE '其他縣市' END,
        c.category
),
per_capita AS (
    SELECT
        stat_year,
        stat_month,
        period,
        area,
        category,
        amount_ton * 1000000 / NULLIF(resident_population, 0) AS grams_per_person
    FROM aggregated
)
SELECT
    CASE p.category
        WHEN '紙類及紙製品' THEN '紙類'
        WHEN '金屬類' THEN '金屬'
        WHEN '塑膠及橡膠製品' THEN '塑膠橡膠'
        WHEN '玻璃製品' THEN '玻璃'
        WHEN '家電用品' THEN '家電'
        WHEN '資訊及通信物品' THEN '資通訊物品'
        WHEN '農藥容器及特殊環境用藥容器' THEN '農藥容器'
        ELSE p.category
    END AS x_axis,
    CONCAT(REPLACE(p.period, ' ', ''), '::', p.area) AS y_axis,
    ROUND((p.grams_per_person / NULLIF(MAX(p.grams_per_person) OVER (PARTITION BY p.stat_year, p.stat_month, p.category), 0) * 100)::numeric)::int AS data
FROM per_capita p
ORDER BY
    p.stat_year DESC,
    p.stat_month DESC,
    ARRAY_POSITION(ARRAY[
        '紙類及紙製品', '金屬類', '塑膠及橡膠製品', '玻璃製品', '紡織品',
        '家電用品', '電池', '資訊及通信物品', '農藥容器及特殊環境用藥容器',
        '食用油', '其他'
    ]::text[], p.category),
    ARRAY_POSITION(ARRAY['臺北市', '新北市', '其他縣市']::text[], p.area)
    $sql$,
    NULL,
    'metrotaipei'
);

DO $$
DECLARE v_id integer;
BEGIN
    SELECT id INTO v_id FROM public.components WHERE "index" = 'resource_recycling_per_capita';
    IF v_id IS NOT NULL THEN
        UPDATE public.dashboards
        SET components = array_append(components, v_id)
        WHERE "index" IN ('sustainable_env_tpe', 'sustainable_env_newtpe')
          AND NOT (v_id = ANY(components));
    END IF;
END $$;

SELECT pg_catalog.setval(
    'public.components_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM public.components),
    true
);

COMMIT;
