--
-- Green store distribution component seed data
--

BEGIN;

ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS levels json;

ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS ranking_config json;

INSERT INTO public.components ("index", name)
VALUES ('green_store_distribution', '綠色商店分布')
ON CONFLICT ("index") DO UPDATE
SET name = EXCLUDED.name;

DELETE FROM public.component_maps
WHERE "index" IN (
    'green_store_distribution_taipei',
    'green_store_distribution_metrotaipei'
);

INSERT INTO public.component_charts ("index", color, types, unit, levels, ranking_config)
VALUES (
    'green_store_distribution',
    ARRAY['#3A8B72', '#45A980', '#62C879', '#9BE86A', '#E8FF7A'],
    ARRAY['DistrictChart', 'RankingOverviewChart'],
    '家',
    '[
        {"label":"很少","fullLabel":"資源很少","min":0,"max":50},
        {"label":"少","fullLabel":"資源較少","min":51,"max":200},
        {"label":"中","fullLabel":"中等密度","min":201,"max":500},
        {"label":"多","fullLabel":"資源較多","min":501,"max":900},
        {"label":"很多","fullLabel":"資源很多","min":901,"max":1300}
    ]'::json,
    '{
        "order": "desc",
        "primary_metric": "sum",
        "value_precision": 0,
        "labels": {
            "primary": "綠色商店總數",
            "leading": "最多行政區",
            "average": "平均每區",
            "count": "行政區數",
            "countUnit": "區",
            "rank": "排名",
            "diff": "與平均差",
            "listTitle": "綠色商店排名"
        }
    }'::json
)
ON CONFLICT ("index") DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit,
    levels = EXCLUDED.levels,
    ranking_config = EXCLUDED.ranking_config;

INSERT INTO public.component_maps ("index", title, type, source, size, icon, paint, property)
VALUES
(
    'green_store_distribution_taipei',
    '綠色商店行政區',
    'fill',
    'geojson',
    NULL,
    NULL,
    '{
        "fill-color": [
            "interpolate",
            ["linear"],
            ["to-number", ["get", "store_count"], 0],
            0, "#2E6F61",
            50, "#3A8B72",
            200, "#45A980",
            500, "#62C879",
            900, "#9BE86A",
            1300, "#E8FF7A"
        ],
        "fill-opacity": [
            "interpolate",
            ["linear"],
            ["zoom"],
            9, 0.56,
            13, 0.68,
            16, 0.78
        ],
        "fill-outline-color": "rgba(255,255,255,0.45)"
    }'::json,
    '[
        {"key":"city","name":"城市"},
        {"key":"district","name":"行政區"},
        {"key":"store_count","name":"綠色商店"},
        {"key":"level","name":"密度"}
    ]'::json
),
(
    'green_store_distribution_metrotaipei',
    '雙北綠色商店行政區',
    'fill',
    'geojson',
    NULL,
    NULL,
    '{
        "fill-color": [
            "interpolate",
            ["linear"],
            ["to-number", ["get", "store_count"], 0],
            0, "#2E6F61",
            50, "#3A8B72",
            200, "#45A980",
            500, "#62C879",
            900, "#9BE86A",
            1300, "#E8FF7A"
        ],
        "fill-opacity": [
            "interpolate",
            ["linear"],
            ["zoom"],
            9, 0.56,
            13, 0.68,
            16, 0.78
        ],
        "fill-outline-color": "rgba(255,255,255,0.45)"
    }'::json,
    '[
        {"key":"city","name":"城市"},
        {"key":"district","name":"行政區"},
        {"key":"store_count","name":"綠色商店"},
        {"key":"level","name":"密度"}
    ]'::json
);

DELETE FROM public.query_charts
WHERE "index" = 'green_store_distribution'
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
(
    'green_store_distribution',
    NULL,
    ARRAY[(SELECT id::integer FROM public.component_maps WHERE "index" = 'green_store_distribution_taipei' ORDER BY id DESC LIMIT 1)],
    '{"mode":"byParam","byParam":{"xParam":"district"}}'::json,
    'static',
    NULL,
    0,
    '',
    '臺北市環保局資料',
    '臺北市各行政區綠色商店分布',
    '依臺北市綠色商店地址擷取行政區，統計各行政區綠色商店數量。資料無經緯度，故以行政區圖呈現分布。',
    '可用於觀察臺北市綠色消費資源分布，協助使用者選擇綠色商店較密集的生活圈。',
    ARRAY[
        'https://data.moenv.gov.tw/dataset/detail/GP_P_01',
        'https://data.taipei/dataset/detail?id=1756cb64-0066-444a-a323-9f3b5a961045'
    ],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'three_d',
    'SELECT district AS x_axis, ''綠色商店'' AS y_axis, '''' AS icon, store_count::int AS data FROM public.green_store_district_stats WHERE city = ''臺北市'' ORDER BY district',
    NULL,
    'taipei'
),
(
    'green_store_distribution',
    NULL,
    ARRAY[(SELECT id::integer FROM public.component_maps WHERE "index" = 'green_store_distribution_metrotaipei' ORDER BY id DESC LIMIT 1)],
    '{"mode":"byParam","byParam":{"xParam":"district"}}'::json,
    'static',
    NULL,
    0,
    '',
    '臺北市環保局、新北市環保局資料',
    '雙北各行政區綠色商店分布',
    '依臺北市與新北市綠色商店地址擷取行政區，統計各行政區綠色商店數量。資料無經緯度，故以行政區圖呈現分布；新北資料中非雙北地址已排除。',
    '可用於比較雙北各行政區綠色消費資源密度，補足沒有座標資料時的區域便利度分析。',
    ARRAY[
        'https://data.moenv.gov.tw/dataset/detail/GP_P_01',
        'https://data.taipei/dataset/detail?id=1756cb64-0066-444a-a323-9f3b5a961045'
    ],
    ARRAY['doit', 'ntpc'],
    NOW(),
    NOW(),
    'three_d',
    'SELECT district AS x_axis, ''綠色商店'' AS y_axis, '''' AS icon, store_count::int AS data FROM public.green_store_district_stats ORDER BY city, district',
    NULL,
    'metrotaipei'
);

DO $$
DECLARE
    v_id integer;
BEGIN
    SELECT id::integer INTO v_id
    FROM public.components
    WHERE "index" = 'green_store_distribution';

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

SELECT pg_catalog.setval(
    'public.component_maps_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM public.component_maps),
    true
);

COMMIT;
