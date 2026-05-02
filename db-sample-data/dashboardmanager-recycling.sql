--
-- 全台資源回收量 (Resource Recycling) — dashboardmanager patch
--
-- Depends on: dashboardmanager-demo.sql
--
-- timeline_config.enabled = true lets the frontend show a time-period slider.
-- Granularity and time fields are inferred automatically from the returned data.
--

BEGIN;

-- ── Migrate: add timeline_config column if not exists ─────────────────────────
ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS timeline_config json;

ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS levels json;

ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS ranking_config json;

-- ── Cleanup (idempotent) ──────────────────────────────────────────────────────
DELETE FROM public.query_charts   WHERE index = 'resource_recycling_tw';
DELETE FROM public.component_charts WHERE index = 'resource_recycling_tw';
DELETE FROM public.components      WHERE index = 'resource_recycling_tw';

-- ── Component ─────────────────────────────────────────────────────────────────
INSERT INTO public.components (id, index, name)
VALUES (370, 'resource_recycling_tw', '全台資源回收量');

-- ── Component chart config ────────────────────────────────────────────────────
INSERT INTO public.component_charts (index, color, types, unit, levels, ranking_config, timeline_config)
VALUES (
    'resource_recycling_tw',
    ARRAY['#56B96D', '#9DC56E', '#F8CF58', '#F5AD4A', '#4CB495'],
    ARRAY['RankingOverviewChart', 'ColumnChart'],
    '公噸',
    '[
        {"label":"低量","fullLabel":"低回收量","min":0,"max":5000},
        {"label":"中量","fullLabel":"中等回收量","min":5001,"max":15000},
        {"label":"高量","fullLabel":"高回收量","min":15001,"max":50000},
        {"label":"大量","fullLabel":"大量回收量","min":50001,"max":80000},
        {"label":"超高","fullLabel":"超高回收量","min":80001,"max":200000}
    ]'::json,
    '{
        "order": "desc",
        "primary_metric": "sum",
        "value_precision": 0,
        "labels": {
            "primary": "全台總回收量",
            "leading": "最高",
            "average": "平均",
            "count": "縣市數",
            "countUnit": "縣市",
            "rank": "排名",
            "diff": "平均差",
            "listTitle": "縣市回收量排名"
        }
    }'::json,
    '{
        "enabled": true,
        "sort": "desc"
    }'::json
);

-- ── Query charts ──────────────────────────────────────────────────────────────
-- Strategy: y_axis = 統計期 (time period) creates one series per month.
-- Annual subtotal rows are intentionally excluded from this monthly component.

INSERT INTO public.query_charts (
    index,
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
) VALUES
(
    'resource_recycling_tw',
    NULL,
    '{}',
    '{}',
    'static',
    NULL,
    1,
    'month',
    '環境部統計處',
    '顯示全台各縣市每月資源回收總量。',
    '本圖表彙整環境部統計處提供之地方環保機關資源回收成果，依統計期（月份）與統計區呈現回收總量（公噸）。透過時間軸滑桿可切換月份，觀察不同時間點各縣市的回收表現。',
    '可用於追蹤各縣市資源回收量的月度變化，評估回收政策成效，或比較不同縣市的回收能量。滑動時間軸即可快速瀏覽歷史趨勢。',
    ARRAY['https://data.gov.tw/dataset/32999'],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'three_d',
    $$WITH monthly AS (
    SELECT
        item1,
        item2,
        value1,
        CAST(split_part(item1, '年', 1) AS INTEGER) AS roc_year,
        CAST(TRIM(split_part(split_part(item1, '年', 2), '月', 1)) AS INTEGER) AS month_num
    FROM public.resource_recycling
    WHERE item1 ~ '^[0-9]{2,3}年[[:space:]]*[0-9]{1,2}月$'
)
SELECT
    item2 AS x_axis,
    REPLACE(item1, ' ', '') AS y_axis,
    value1::int AS data
FROM monthly
ORDER BY
    roc_year DESC,
    month_num DESC,
    CASE item2
        WHEN '臺北市' THEN 1
        WHEN '新北市' THEN 2
        WHEN '桃園市' THEN 3
        WHEN '臺中市' THEN 4
        WHEN '臺南市' THEN 5
        WHEN '高雄市' THEN 6
        WHEN '基隆市' THEN 7
        WHEN '新竹市' THEN 8
        WHEN '嘉義市' THEN 9
        WHEN '新竹縣' THEN 10
        WHEN '苗栗縣' THEN 11
        WHEN '彰化縣' THEN 12
        WHEN '南投縣' THEN 13
        WHEN '雲林縣' THEN 14
        WHEN '嘉義縣' THEN 15
        WHEN '屏東縣' THEN 16
        WHEN '宜蘭縣' THEN 17
        WHEN '花蓮縣' THEN 18
        WHEN '臺東縣' THEN 19
        WHEN '澎湖縣' THEN 20
        WHEN '金門縣' THEN 21
        WHEN '連江縣' THEN 22
        ELSE 99
    END$$,
    NULL,
    'taipei'
),
(
    'resource_recycling_tw',
    NULL,
    '{}',
    '{}',
    'static',
    NULL,
    1,
    'month',
    '環境部統計處',
    '顯示全台各縣市每月資源回收總量。',
    '本圖表彙整環境部統計處提供之地方環保機關資源回收成果，依統計期（月份）與統計區呈現回收總量（公噸）。透過時間軸滑桿可切換月份，觀察不同時間點各縣市的回收表現。',
    '可用於追蹤各縣市資源回收量的月度變化，評估回收政策成效，或比較不同縣市的回收能量。滑動時間軸即可快速瀏覽歷史趨勢。',
    ARRAY['https://data.gov.tw/dataset/32999'],
    ARRAY['doit', 'ntpc'],
    NOW(),
    NOW(),
    'three_d',
    $$WITH monthly AS (
    SELECT
        item1,
        item2,
        value1,
        CAST(split_part(item1, '年', 1) AS INTEGER) AS roc_year,
        CAST(TRIM(split_part(split_part(item1, '年', 2), '月', 1)) AS INTEGER) AS month_num
    FROM public.resource_recycling
    WHERE item1 ~ '^[0-9]{2,3}年[[:space:]]*[0-9]{1,2}月$'
)
SELECT
    item2 AS x_axis,
    REPLACE(item1, ' ', '') AS y_axis,
    value1::int AS data
FROM monthly
ORDER BY
    roc_year DESC,
    month_num DESC,
    CASE item2
        WHEN '臺北市' THEN 1
        WHEN '新北市' THEN 2
        WHEN '桃園市' THEN 3
        WHEN '臺中市' THEN 4
        WHEN '臺南市' THEN 5
        WHEN '高雄市' THEN 6
        WHEN '基隆市' THEN 7
        WHEN '新竹市' THEN 8
        WHEN '嘉義市' THEN 9
        WHEN '新竹縣' THEN 10
        WHEN '苗栗縣' THEN 11
        WHEN '彰化縣' THEN 12
        WHEN '南投縣' THEN 13
        WHEN '雲林縣' THEN 14
        WHEN '嘉義縣' THEN 15
        WHEN '屏東縣' THEN 16
        WHEN '宜蘭縣' THEN 17
        WHEN '花蓮縣' THEN 18
        WHEN '臺東縣' THEN 19
        WHEN '澎湖縣' THEN 20
        WHEN '金門縣' THEN 21
        WHEN '連江縣' THEN 22
        ELSE 99
    END$$,
    NULL,
    'metrotaipei'
);

-- ── Hook into sustainable-env dashboard ──────────────────────────────────────
DO $$
DECLARE v_id integer;
BEGIN
    SELECT id INTO v_id FROM public.components WHERE "index" = 'resource_recycling_tw';
    IF v_id IS NOT NULL THEN
        UPDATE public.dashboards
        SET components = array_append(components, v_id)
        WHERE "index" IN ('sustainable_env_tpe', 'sustainable_env_newtpe')
          AND NOT (v_id = ANY(components));
    END IF;
END $$;

-- Update sequence
SELECT pg_catalog.setval(
    'public.components_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM public.components),
    true
);

COMMIT;
