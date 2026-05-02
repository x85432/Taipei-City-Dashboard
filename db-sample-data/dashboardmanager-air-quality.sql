-- Air quality dashboard component manager

BEGIN;

ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS levels json;

ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS ranking_config json;

DO $$
DECLARE v_component_id integer;
BEGIN
    FOR v_component_id IN
        SELECT id::integer
        FROM public.components
        WHERE "index" IN ('air_quality_overview', 'environment_pressure')
    LOOP
        UPDATE public.dashboards
        SET components = array_remove(components, v_component_id)
        WHERE v_component_id = ANY(components);
    END LOOP;
END $$;

DELETE FROM public.query_charts
WHERE "index" IN ('air_quality_overview', 'environment_pressure');

DELETE FROM public.component_charts
WHERE "index" IN ('air_quality_overview', 'environment_pressure');

DELETE FROM public.component_maps
WHERE "index" IN (
    'environment_air_quality_aqi_zones',
    'environment_air_quality_isoline',
    'environment_air_quality_surface',
    'environment_air_pressure_district',
    'environment_air_quality_stations'
);

DELETE FROM public.components
WHERE "index" = 'environment_pressure';

INSERT INTO public.components ("index", name)
VALUES ('air_quality_overview', '空氣品質總覽')
ON CONFLICT ("index") DO UPDATE
SET name = EXCLUDED.name;

INSERT INTO public.component_charts ("index", color, types, unit, levels, ranking_config)
VALUES (
    'air_quality_overview',
    ARRAY['#56B96D', '#F8CF58', '#F5AD4A', '#F05D5E', '#8E63CE', '#8B6A43'],
    ARRAY['RankingOverviewChart'],
    'AQI',
    '[
        {"label":"良好","fullLabel":"良好","min":0,"max":50},
        {"label":"普通","fullLabel":"普通","min":51,"max":100},
        {"label":"敏感族群","fullLabel":"對敏感族群不健康","min":101,"max":150},
        {"label":"所有族群","fullLabel":"對所有族群不健康","min":151,"max":200},
        {"label":"非常不健康","fullLabel":"非常不健康","min":201,"max":300},
        {"label":"危害","fullLabel":"危害","min":301,"max":500}
    ]'::json,
    '{
        "order": "desc",
        "primary_metric": "average",
        "value_precision": 0,
        "labels": {
            "primary": "平均 AQI",
            "leading": "最高",
            "average": "平均",
            "count": "筆數",
            "countUnit": "項",
            "rank": "排名",
            "diff": "平均差",
            "listTitle": "AQI 排名"
        }
    }'::json
);

INSERT INTO public.component_maps ("index", title, type, source, size, icon, paint, property)
VALUES
(
    'environment_air_quality_aqi_zones',
    '官方 AQI 等級面',
    'fill',
    'geojson',
    NULL,
    NULL,
    '{
        "filter-disabled": true,
        "fill-color": ["get", "color"],
        "fill-opacity": [
            "interpolate",
            ["linear"],
            ["zoom"],
            9, 0.36,
            13, 0.46,
            16, 0.56
        ],
        "fill-outline-color": "rgba(255,255,255,0)"
    }'::json,
    '[
        {"key":"label","name":"AQI等級"},
        {"key":"min","name":"下限"},
        {"key":"max","name":"上限"}
    ]'::json
),
(
    'environment_air_quality_stations',
    '空氣品質測站',
    'circle',
    'geojson',
    NULL,
    NULL,
    '{
        "circle-radius": ["interpolate", ["linear"], ["zoom"], 10, 4, 13, 6, 16, 9],
        "circle-color": [
            "step",
            ["to-number", ["get", "aqi"], 0],
            "#56B96D",
            51, "#F8CF58",
            101, "#F5AD4A",
            151, "#F05D5E",
            201, "#8E63CE",
            301, "#8B6A43"
        ],
        "circle-stroke-color": "#ffffff",
        "circle-stroke-width": 1.2,
        "circle-opacity": 0.9
    }'::json,
    '[
        {"key":"city","name":"城市"},
        {"key":"district","name":"行政區"},
        {"key":"site_name","name":"測站"},
        {"key":"status","name":"狀態"},
        {"key":"aqi","name":"AQI"},
        {"key":"pollutant","name":"主要污染物"},
        {"key":"pm2_5_avg_ug_m3","name":"PM2.5平均"},
        {"key":"pm10_avg_ug_m3","name":"PM10平均"},
        {"key":"o3_8hr_ppb","name":"O3 8小時"},
        {"key":"publish_time","name":"資料時間"}
    ]'::json
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
    'air_quality_overview',
    NULL,
    ARRAY[
        (SELECT id::integer FROM public.component_maps WHERE "index" = 'environment_air_quality_aqi_zones' ORDER BY id DESC LIMIT 1),
        (SELECT id::integer FROM public.component_maps WHERE "index" = 'environment_air_quality_stations' ORDER BY id DESC LIMIT 1)
    ],
    '{"mode":"byParam","byParam":{"xParam":"district"}}'::json,
    'current',
    NULL,
    1,
    'hour',
    '環境部',
    '顯示臺北市空氣品質 AQI 與測站分布',
    '以環境部 AQX_P_432 空氣品質資料建立臺北市行政區 AQI 排名、平均 AQI 與測站點位。',
    '可用於快速掌握臺北市空氣品質熱點、良好行政區數量與測站分布，協助判斷需要優先關注的行政區。',
    ARRAY['https://data.moenv.gov.tw/dataset/detail/aqx_p_432'],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'three_d',
    'SELECT district AS x_axis, ''AQI'' AS y_axis, '''' AS icon, ROUND(score)::int AS data FROM public.environment_pressure_index WHERE city = ''臺北市'' AND pressure_type = ''空氣'' AND score IS NOT NULL ORDER BY district',
    NULL,
    'taipei'
),
(
    'air_quality_overview',
    NULL,
    ARRAY[
        (SELECT id::integer FROM public.component_maps WHERE "index" = 'environment_air_quality_aqi_zones' ORDER BY id DESC LIMIT 1),
        (SELECT id::integer FROM public.component_maps WHERE "index" = 'environment_air_quality_stations' ORDER BY id DESC LIMIT 1)
    ],
    '{"mode":"byParam","byParam":{"xParam":"district"}}'::json,
    'current',
    NULL,
    1,
    'hour',
    '環境部',
    '顯示雙北空氣品質 AQI 與測站分布',
    '以環境部 AQX_P_432 空氣品質資料建立雙北行政區 AQI 排名、平均 AQI 與測站點位。',
    '可用於快速掌握雙北空氣品質熱點、良好行政區數量與測站分布，協助判斷需要優先關注的行政區。',
    ARRAY['https://data.moenv.gov.tw/dataset/detail/aqx_p_432'],
    ARRAY['doit', 'ntpc'],
    NOW(),
    NOW(),
    'three_d',
    'SELECT district AS x_axis, ''AQI'' AS y_axis, '''' AS icon, ROUND(score)::int AS data FROM public.environment_pressure_index WHERE pressure_type = ''空氣'' AND score IS NOT NULL ORDER BY city, district',
    NULL,
    'metrotaipei'
);

DO $$
DECLARE v_component_id integer;
BEGIN
    SELECT id::integer INTO v_component_id
    FROM public.components
    WHERE "index" = 'air_quality_overview';

    IF v_component_id IS NOT NULL THEN
        UPDATE public.dashboards
        SET components = array_append(components, v_component_id)
        WHERE "index" IN (
            'map-layers-taipei',
            'map-layers-metrotaipei',
            'sustainable_env_tpe',
            'sustainable_env_newtpe'
        )
          AND NOT (v_component_id = ANY(components));
    END IF;
END $$;

SELECT pg_catalog.setval('public.components_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.components), true);
SELECT pg_catalog.setval('public.component_maps_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.component_maps), true);

COMMIT;
