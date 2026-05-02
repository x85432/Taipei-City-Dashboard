--
-- Metro Taipei used clothes recycling resources component seed data
--
-- Fix: DistrictChart requires a complete district × org_type cross product.
--      The original simple GROUP BY left gaps for missing combinations, causing
--      rendering issues. Now uses CROSS JOIN + COALESCE(0) pattern.
--
-- Fix: Added taipei-specific map + query_chart (filtered by source_city='臺北市')
--      so the component renders correctly inside the 永續環境 taipei dashboard.
--

BEGIN;

INSERT INTO public.components ("index", name)
VALUES ('clothing_recycle_bins', '舊衣回收資源分布')
ON CONFLICT ("index") DO UPDATE
SET name = EXCLUDED.name;

INSERT INTO public.component_charts ("index", color, types, unit)
VALUES (
    'clothing_recycle_bins',
    ARRAY['#46B3E6', '#68C174', '#F8CF58', '#E170A6', '#9B7EDE'],
    ARRAY['DistrictChart', 'ColumnChart'],
    '處'
)
ON CONFLICT ("index") DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit  = EXCLUDED.unit;

-- Remove stale query_charts and maps before re-inserting
DELETE FROM public.query_charts
WHERE "index" = 'clothing_recycle_bins'
  AND city IN ('taipei', 'metrotaipei');

DELETE FROM public.component_maps
WHERE "index" IN (
    'clothing_recycle_bins_taipei',
    'clothing_recycle_bins_metrotaipei',
    'clothing_recycle_points_newtaipei'
);

-- ─── Maps ─────────────────────────────────────────────────────────────────────

-- 臺北市 map (source_city = '臺北市')
INSERT INTO public.component_maps ("index", title, type, source, size, icon, paint, property)
VALUES (
    'clothing_recycle_bins_taipei',
    '舊衣回收箱(臺北)',
    'circle',
    'geojson',
    NULL,
    NULL,
    '{"circle-radius":["interpolate",["linear"],["zoom"],10,3,13,5,16,8],"circle-color":["match",["get","org_type"],"視障服務團體","#46B3E6","身障復健團體","#68C174","社福基金會","#F8CF58","社福服務機構","#E170A6","公益協會團體","#9B7EDE","#46B3E6"],"circle-stroke-color":"#ffffff","circle-stroke-width":1.2,"circle-opacity":0.88}'::json,
    '[{"key":"source_city","name":"城市"},{"key":"resource_type","name":"資源類型"},{"key":"approval_id","name":"核准編號"},{"key":"org_name","name":"設置單位"},{"key":"org_type","name":"團體類型"},{"key":"district","name":"行政區"},{"key":"village","name":"設置里別"},{"key":"approved_location","name":"設置地點"},{"key":"full_address","name":"完整地址"},{"key":"phone","name":"電話"},{"key":"approval_years","name":"核准年限"},{"key":"note","name":"備註"}]'::json
);

-- 新北市 map (district aggregation; source CSV has no coordinates)
INSERT INTO public.component_maps ("index", title, type, source, size, icon, paint, property)
VALUES (
    'clothing_recycle_points_newtaipei',
    '舊衣回收點(新北)',
    'fill',
    'geojson',
    NULL,
    NULL,
    '{"fill-color":["interpolate",["linear"],["to-number",["get","recycle_point_count"],0],0,"#1F3B36",1,"#2F7E68",3,"#46B3E6",6,"#F8CF58",8,"#E170A6"],"fill-opacity":["interpolate",["linear"],["zoom"],9,0.38,13,0.52,16,0.64],"fill-outline-color":"rgba(255,255,255,0.42)"}'::json,
    '[{"key":"source_city","name":"城市"},{"key":"resource_type","name":"資源類型"},{"key":"district","name":"行政區"},{"key":"recycle_point_count","name":"舊衣回收點"},{"key":"total_point_count","name":"全部二手服務點"},{"key":"service_types","name":"服務類型"},{"key":"level","name":"密度"}]'::json
);

-- ─── Query Charts ─────────────────────────────────────────────────────────────
--
-- Key fix: Use CROSS JOIN between districts and org_types so that every
-- district always has a row for every org_type (defaulting to 0 via COALESCE).
-- The DistrictChart component requires a complete matrix; missing rows caused
-- the chart to misalign colors and labels (the original NaN / blank display bug).
--

-- 臺北市 query (filters source_city = '臺北市')
INSERT INTO public.query_charts (
    "index", history_config, map_config_ids, map_filter, time_from, time_to,
    update_freq, update_freq_unit, source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at, query_type, query_chart,
    query_history, city
)
VALUES (
    'clothing_recycle_bins',
    NULL,
    ARRAY[(SELECT id::integer FROM public.component_maps WHERE "index" = 'clothing_recycle_bins_taipei' ORDER BY id DESC LIMIT 1)],
    '{"mode":"byParam","byParam":{"xParam":"district","yParam":"org_type"}}'::json,
    'static', NULL, 0, '',
    '臺北市政府資料',
    '顯示臺北市舊衣回收箱分布',
    '彙整臺北市舊衣回收箱資料，依行政區與設置團體類型呈現回收箱數量，並以地圖點位標示實際設置位置。',
    '可用於民眾查找附近舊衣回收箱，也可協助觀察舊衣回收服務在臺北市各區的分布是否均衡。',
    ARRAY['https://data.taipei/dataset/detail?id=33de0950-24df-463d-b199-da3fbf612ef1'],
    ARRAY['doit'],
    '2026-04-28 00:00:00+00',
    '2026-04-28 00:00:00+00',
    'three_d',
    'WITH cleaned AS (SELECT district, org_type FROM public.taipei_clothing_recycle_bins WHERE source_city = ''臺北市'' AND district IS NOT NULL AND org_type IS NOT NULL AND btrim(district) <> '''' AND btrim(org_type) <> '''' AND lower(btrim(district)) <> ''nan'' AND lower(btrim(org_type)) <> ''nan'' AND longitude IS NOT NULL AND latitude IS NOT NULL), districts AS (SELECT DISTINCT district FROM cleaned), org_types AS (SELECT unnest(ARRAY[''視障服務團體'',''身障復健團體'',''社福基金會'',''社福服務機構'',''公益協會團體'']) AS org_type) SELECT d.district AS x_axis, o.org_type AS y_axis, COALESCE(COUNT(c.district), 0)::int AS data FROM districts d CROSS JOIN org_types o LEFT JOIN cleaned c ON c.district = d.district AND c.org_type = o.org_type GROUP BY d.district, o.org_type ORDER BY d.district, o.org_type',
    NULL,
    'taipei'
)
ON CONFLICT DO NOTHING;

-- 雙北 query: 臺北為點位回收箱，新北為行政區回收點統計
INSERT INTO public.query_charts (
    "index", history_config, map_config_ids, map_filter, time_from, time_to,
    update_freq, update_freq_unit, source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at, query_type, query_chart,
    query_history, city
)
VALUES (
    'clothing_recycle_bins',
    NULL,
    ARRAY[
        (SELECT id::integer FROM public.component_maps WHERE "index" = 'clothing_recycle_bins_taipei' ORDER BY id DESC LIMIT 1),
        (SELECT id::integer FROM public.component_maps WHERE "index" = 'clothing_recycle_points_newtaipei' ORDER BY id DESC LIMIT 1)
    ],
    '{"mode":"byParam","byParam":{"xParam":"district","yParam":"resource_type"}}'::json,
    'static', NULL, 0, '',
    '臺北市政府資料、新北市政府資料',
    '顯示雙北舊衣回收資源分布',
    '彙整臺北市舊衣回收箱與新北市舊衣回收點資料；臺北以點位呈現，新北因原始資料無座標，改以行政區統計面圖呈現。',
    '可用於比較雙北舊衣循環資源分布，協助觀察哪些行政區回收資源較集中或相對不足。',
    ARRAY[
        'https://data.taipei/dataset/detail?id=33de0950-24df-463d-b199-da3fbf612ef1',
        'https://data.moenv.gov.tw/dataset/detail/WR_P_250'
    ],
    ARRAY['doit', 'ntpc'],
    '2026-04-28 00:00:00+00',
    '2026-04-28 00:00:00+00',
    'three_d',
    'WITH resources AS (SELECT district, ''臺北舊衣回收箱'' AS resource_type, COUNT(*)::int AS data FROM public.taipei_clothing_recycle_bins WHERE source_city = ''臺北市'' AND district IS NOT NULL AND btrim(district) <> '''' AND lower(btrim(district)) <> ''nan'' AND longitude IS NOT NULL AND latitude IS NOT NULL GROUP BY district UNION ALL SELECT district, ''新北舊衣回收點'' AS resource_type, COUNT(*)::int AS data FROM public.newtaipei_clothing_recycle_points WHERE supports_clothing IS TRUE AND district IS NOT NULL AND btrim(district) <> '''' GROUP BY district), districts AS (SELECT DISTINCT district FROM resources), resource_types AS (SELECT unnest(ARRAY[''臺北舊衣回收箱'',''新北舊衣回收點'']) AS resource_type) SELECT d.district AS x_axis, r.resource_type AS y_axis, COALESCE(SUM(resources.data), 0)::int AS data FROM districts d CROSS JOIN resource_types r LEFT JOIN resources ON resources.district = d.district AND resources.resource_type = r.resource_type GROUP BY d.district, r.resource_type ORDER BY d.district, r.resource_type',
    NULL,
    'metrotaipei'
)
ON CONFLICT DO NOTHING;

-- ─── Dashboard Assignments ────────────────────────────────────────────────────

-- Remove from taipei map-layers (this component only has 台北 data in taipei mode,
-- keep it in metrotaipei map-layers for the dual-city view)
UPDATE public.dashboards
SET components = array_remove(components, (SELECT id FROM public.components WHERE "index" = 'clothing_recycle_bins'))
WHERE "index" = 'map-layers-taipei';

UPDATE public.dashboards
SET components = array_append(components, (SELECT id FROM public.components WHERE "index" = 'clothing_recycle_bins'))
WHERE "index" = 'map-layers-metrotaipei'
  AND NOT ((SELECT id FROM public.components WHERE "index" = 'clothing_recycle_bins') = ANY(components));

-- ─── Sequence Reset ───────────────────────────────────────────────────────────

SELECT pg_catalog.setval('public.component_maps_id_seq',  (SELECT COALESCE(MAX(id), 0) FROM public.component_maps),  true);
SELECT pg_catalog.setval('public.components_id_seq',      (SELECT COALESCE(MAX(id), 0) FROM public.components),      true);

COMMIT;
