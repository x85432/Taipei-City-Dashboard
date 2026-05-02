--
-- Taipei eco restaurant component seed data
--

DELETE FROM public.query_charts
WHERE index = 'eco_restaurant_taipei';

DELETE FROM public.component_charts
WHERE index = 'eco_restaurant_taipei';

DELETE FROM public.component_maps
WHERE index IN ('eco_restaurant_taipei', 'eco_restaurant_metrotaipei');

DELETE FROM public.components
WHERE index = 'eco_restaurant_taipei';

INSERT INTO public.components (id, index, name)
VALUES (223, 'eco_restaurant_taipei', '環保餐廳分布');

INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'eco_restaurant_taipei',
    ARRAY['#36C2A0'],
    ARRAY['DistrictChart', 'ColumnChart'],
    '家'
);

INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES
(
    120,
    'eco_restaurant_taipei',
    '環保餐廳',
    'symbol',
    'geojson',
    NULL,
    'restaurant',
    '{}',
    '[
        {"key":"name","name":"餐廳名稱"},
        {"key":"district","name":"行政區"},
        {"key":"address","name":"地址"},
        {"key":"phone","name":"電話"}
    ]'
),
(
    121,
    'eco_restaurant_metrotaipei',
    '雙北環保餐廳',
    'symbol',
    'geojson',
    NULL,
    'restaurant',
    '{}',
    '[
        {"key":"city","name":"城市"},
        {"key":"name","name":"餐廳名稱"},
        {"key":"district","name":"行政區"},
        {"key":"address","name":"地址"},
        {"key":"phone","name":"電話"}
    ]'
);

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
    'eco_restaurant_taipei',
    NULL,
    ARRAY[120],
    '{}',
    'static',
    NULL,
    0,
    '',
    '臺北市環保局資料',
    '顯示臺北市環保餐廳分布',
    '彙整臺北市環保餐廳資料，依行政區呈現餐廳數量，並以地圖點位顯示餐廳位置。',
    '可用於觀察各行政區綠色飲食資源分布，支援永續消費、環境教育與商圈推廣分析。',
    ARRAY['https://data.moenv.gov.tw/dataset/detail/GIS_P_11'],
    ARRAY['doit'],
    '2026-04-25 00:00:00+00',
    '2026-04-25 00:00:00+00',
    'three_d',
    'SELECT district AS x_axis, ''環保餐廳'' AS y_axis, COUNT(*)::int AS data FROM public.taipei_eco_restaurants WHERE district IS NOT NULL AND btrim(district) <> '''' AND lower(btrim(district)) <> ''nan'' GROUP BY district ORDER BY district',
    NULL,
    'taipei'
),
(
    'eco_restaurant_taipei',
    NULL,
    ARRAY[121],
    '{}',
    'static',
    NULL,
    0,
    '',
    '臺北市環保局、新北市環保局資料',
    '顯示雙北環保餐廳分布',
    '彙整臺北市與新北市環保餐廳資料，依行政區呈現餐廳數量，並以地圖點位顯示餐廳位置。',
    '可用於觀察雙北各行政區綠色飲食資源分布，支援永續消費、環境教育與商圈推廣分析。',
    ARRAY['https://data.moenv.gov.tw/dataset/detail/GIS_P_11'],
    ARRAY['doit', 'ntpc'],
    '2026-04-25 00:00:00+00',
    '2026-04-25 00:00:00+00',
    'three_d',
    'SELECT district AS x_axis, ''環保餐廳'' AS y_axis, COUNT(*)::int AS data FROM (SELECT district FROM public.taipei_eco_restaurants UNION ALL SELECT district FROM public.newtaipei_eco_restaurants) restaurants WHERE district IS NOT NULL AND btrim(district) <> '''' AND lower(btrim(district)) <> ''nan'' GROUP BY district ORDER BY district',
    NULL,
    'metrotaipei'
);

UPDATE public.dashboards
SET components = array_append(components, 223)
WHERE index = 'map-layers-taipei'
  AND NOT (223 = ANY(components));

UPDATE public.dashboards
SET components = array_append(components, 223)
WHERE index = 'map-layers-metrotaipei'
  AND NOT (223 = ANY(components));

SELECT pg_catalog.setval(
    'public.component_maps_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM public.component_maps),
    true
);

SELECT pg_catalog.setval(
    'public.components_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM public.components),
    true
);
