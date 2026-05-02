--
-- Waste statistics component seed data
-- Timeline enabled: year-level (民國100年 ~ 113年)
-- Series name format: CONCAT(year, '年::', metric) → normalizeTimelineSeries splits on '::'
--

BEGIN;

INSERT INTO public.components ("index", name)
VALUES ('waste_statistics', '一般廢棄物清理情況')
ON CONFLICT ("index") DO UPDATE
SET name = EXCLUDED.name;

-- Ensure timeline_config column exists (added by dashboardmanager-recycling.sql,
-- but guard here in case this file is run independently).
ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS timeline_config json;

INSERT INTO public.component_charts ("index", color, types, unit, timeline_config)
VALUES (
    'waste_statistics',
    ARRAY['#24B0DD', '#56B96D', '#F8CF58'],
    ARRAY['ColumnChart', 'BarPercentChart'],
    '公克/人日',
    '{"enabled": true, "granularity": "year"}'::json
)
ON CONFLICT ("index") DO UPDATE
SET color          = EXCLUDED.color,
    types          = EXCLUDED.types,
    unit           = EXCLUDED.unit,
    timeline_config = EXCLUDED.timeline_config;

DELETE FROM public.query_charts
WHERE "index" = 'waste_statistics'
  AND city IN ('taipei', 'metrotaipei');

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
-- ── 臺北市 ────────────────────────────────────────────────────────────────────
(
    'waste_statistics',
    NULL,
    NULL,
    NULL,
    'static',
    NULL,
    1,
    'year',
    '環境部資料',
    '一般廢棄物處理統計',
    '呈現歷年臺北市一般垃圾清運、資源回收與廚餘回收的人均每日處理量（公克/人日）。透過時間軸可逐年比較各類廢棄物處理量的變化趨勢。',
    '可用於觀察臺北市一般廢棄物處理結構，評估垃圾減量與資源回收成效。滑動時間軸即可切換不同年度。',
    ARRAY['https://data.moenv.gov.tw/dataset/detail/STAT_P_45']::text[],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'three_d',
    $sql$
SELECT x_axis, y_axis, data
FROM (
    SELECT
        '臺北市'                                                AS x_axis,
        CONCAT(year::text, '年::一般垃圾清運')                  AS y_axis,
        ROUND(garbageclearance)::int                            AS data,
        year                                                    AS year_sort,
        1                                                       AS sort_order
    FROM public.waste_statistics WHERE county = 'Taipei'

    UNION ALL

    SELECT
        '臺北市',
        CONCAT(year::text, '年::資源回收'),
        ROUND(garbagerecycled)::int,
        year,
        2
    FROM public.waste_statistics WHERE county = 'Taipei'

    UNION ALL

    SELECT
        '臺北市',
        CONCAT(year::text, '年::廚餘回收'),
        ROUND(foodwastesrecycled)::int,
        year,
        3
    FROM public.waste_statistics WHERE county = 'Taipei'
) t
ORDER BY year_sort DESC, sort_order
    $sql$,
    NULL,
    'taipei'
),
-- ── 雙北 ──────────────────────────────────────────────────────────────────────
(
    'waste_statistics',
    NULL,
    NULL,
    NULL,
    'static',
    NULL,
    1,
    'year',
    '環境部資料',
    '一般廢棄物處理統計',
    '呈現歷年臺北市、新北市與其他縣市一般垃圾清運、資源回收與廚餘回收的人均每日處理量（公克/人日）。透過時間軸可逐年比較各縣市廢棄物處理結構的演變。',
    '可用於比較臺北市、新北市與其他縣市一般廢棄物處理結構，評估垃圾減量與資源回收成效。滑動時間軸即可快速瀏覽歷史趨勢。',
    ARRAY['https://data.moenv.gov.tw/dataset/detail/STAT_P_45']::text[],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'three_d',
    $sql$
SELECT x_axis, y_axis, data
FROM (
    SELECT
        CASE county
            WHEN 'Taipei'    THEN '臺北市'
            WHEN 'NewTaipei' THEN '新北市'
            ELSE '其他縣市'
        END                                                     AS x_axis,
        CASE county
            WHEN 'Taipei'    THEN 1
            WHEN 'NewTaipei' THEN 2
            ELSE 3
        END                                                     AS city_order,
        CONCAT(year::text, '年::一般垃圾清運')                  AS y_axis,
        ROUND(garbageclearance)::int                            AS data,
        year                                                    AS year_sort,
        1                                                       AS sort_order
    FROM public.waste_statistics

    UNION ALL

    SELECT
        CASE county WHEN 'Taipei' THEN '臺北市' WHEN 'NewTaipei' THEN '新北市' ELSE '其他縣市' END,
        CASE county WHEN 'Taipei' THEN 1        WHEN 'NewTaipei' THEN 2        ELSE 3          END,
        CONCAT(year::text, '年::資源回收'),
        ROUND(garbagerecycled)::int,
        year,
        2
    FROM public.waste_statistics

    UNION ALL

    SELECT
        CASE county WHEN 'Taipei' THEN '臺北市' WHEN 'NewTaipei' THEN '新北市' ELSE '其他縣市' END,
        CASE county WHEN 'Taipei' THEN 1        WHEN 'NewTaipei' THEN 2        ELSE 3          END,
        CONCAT(year::text, '年::廚餘回收'),
        ROUND(foodwastesrecycled)::int,
        year,
        3
    FROM public.waste_statistics
) t
ORDER BY year_sort DESC, sort_order, city_order
    $sql$,
    NULL,
    'metrotaipei'
);

DO $$
DECLARE
    v_id integer;
BEGIN
    SELECT id::integer INTO v_id
    FROM public.components
    WHERE "index" = 'waste_statistics';

    IF v_id IS NOT NULL THEN
        UPDATE public.dashboards
        SET components = array_append(components, v_id)
        WHERE "index" = 'sustainable_env_tpe'
          AND NOT (v_id = ANY(components));

        UPDATE public.dashboards
        SET components = array_append(components, v_id)
        WHERE "index" = 'sustainable_env_newtpe'
          AND NOT (v_id = ANY(components));
    END IF;
END $$;

SELECT pg_catalog.setval(
    'public.components_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM public.components),
    true
);

COMMIT;
