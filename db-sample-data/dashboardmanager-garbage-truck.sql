BEGIN;

-- Apply this patch after the base dashboardmanager demo data is initialized.

INSERT INTO public.components ("index", name)
VALUES ('garbage_truck', '垃圾車收運點位')
ON CONFLICT ("index") DO UPDATE
SET name = EXCLUDED.name;

INSERT INTO public.component_charts ("index", color, types, unit)
VALUES (
  'garbage_truck',
  ARRAY['#E6DF44', '#F4633C', '#D63940', '#9C2A4B'],
  ARRAY['ColumnChart', 'DistrictChart'],
  '處'
)
ON CONFLICT ("index") DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

DELETE FROM public.query_charts
WHERE "index" IN ('garbage_truck')
  AND city IN ('taipei', 'metrotaipei');

DELETE FROM public.component_maps
WHERE "index" IN ('garbage_truck');

INSERT INTO public.component_maps (
  "index",
  title,
  type,
  source,
  size,
  icon,
  paint,
  property
)
VALUES (
  'garbage_truck',
  '垃圾車收運點位',
  'circle',
  'geojson',
  NULL,
  NULL,
  '{
    "circle-color": [
      "case",
      ["<", ["get", "抵達時間"], 1700], "#E6DF44",
      ["<", ["get", "抵達時間"], 1900], "#F4633C",
      ["<", ["get", "抵達時間"], 2100], "#D63940",
      "#9C2A4B"
    ],
    "circle-radius": 3,
    "circle-stroke-color": "#ffffff",
    "circle-stroke-width": 1
  }'::json,
  '[
    {"key":"行政區","name":"行政區"},
    {"key":"里別","name":"里別"},
    {"key":"分隊","name":"清潔隊名稱"},
    {"key":"車號","name":"車牌"},
    {"key":"路線","name":"路線"},
    {"key":"車次","name":"車次"},
    {"key":"抵達時間","name":"抵達時間"},
    {"key":"離開時間","name":"離開時間"},
    {"key":"地點","name":"地址"}
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
  'garbage_truck',
  NULL,
  ARRAY[
    (SELECT id::integer FROM public.component_maps WHERE "index" = 'garbage_truck' ORDER BY id DESC LIMIT 1)
  ],
  NULL,
  'current',
  NULL,
  NULL,
  NULL,
  '環保局',
  '顯示垃圾車相關資訊',
  '顯示垃圾車資料的詳細說明',
  '可用於觀察垃圾車分布或服務情形',
  ARRAY[]::text[],
  ARRAY['doit'],
  NOW(),
  NOW(),
  'three_d',
  $sql$
SELECT * FROM (
SELECT
  行政區 as x_axis,
  CASE
    WHEN 抵達時間 BETWEEN 0 AND 1659 THEN '1700前'
    WHEN 抵達時間 BETWEEN 1700 AND 1859 THEN '1700-1900'
    WHEN 抵達時間 BETWEEN 1900 AND 2059 THEN '1900-2100'
    ELSE '2100後'
  END AS y_axis,
  COUNT(*) AS data
FROM garbage_truck
GROUP BY
  行政區,
  CASE
    WHEN 抵達時間 BETWEEN 0 AND 1659 THEN '1700前'
    WHEN 抵達時間 BETWEEN 1700 AND 1859 THEN '1700-1900'
    WHEN 抵達時間 BETWEEN 1900 AND 2059 THEN '1900-2100'
    ELSE '2100後'
  END
) as t
ORDER BY
  ARRAY_POSITION(ARRAY['士林區', '大安區', '文山區', '松山區', '南港區', '大同區', '中山區', '內湖區', '北投區', '中正區', '萬華區', '信義區']::varchar[], t.x_axis),
  ARRAY_POSITION(ARRAY['1700前', '1700-1900', '1900-2100', '2100後'], t.y_axis)
  $sql$,
  NULL,
  'taipei'
);

INSERT INTO public.dashboards ("index", name, components, icon, updated_at, created_at)
SELECT
  'test-layers',
  '測試儀表板',
  ARRAY[]::integer[],
  'public',
  NOW(),
  NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM public.dashboards WHERE "index" = 'test-layers'
);

UPDATE public.dashboards
SET
  updated_at = NOW(),
  components = CASE
    WHEN components IS NULL THEN ARRAY[(SELECT id::integer FROM public.components WHERE "index" = 'garbage_truck')]
    WHEN array_position(components, (SELECT id::integer FROM public.components WHERE "index" = 'garbage_truck')) IS NULL
      THEN array_append(components, (SELECT id::integer FROM public.components WHERE "index" = 'garbage_truck'))
    ELSE components
  END
WHERE "index" = 'test-layers';

INSERT INTO public.dashboard_groups (dashboard_id, group_id)
SELECT d.id, g.id
FROM public.dashboards d
JOIN public.groups g ON g.name = 'taipei'
WHERE d."index" = 'test-layers'
ON CONFLICT DO NOTHING;

INSERT INTO public.dashboard_groups (dashboard_id, group_id)
SELECT d.id, g.id
FROM public.dashboards d
JOIN public.groups g ON g.name = 'metrotaipei'
WHERE d."index" = 'test-layers'
ON CONFLICT DO NOTHING;

COMMIT;
