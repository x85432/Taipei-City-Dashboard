-- Camera component patch for dashboardmanager
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

WITH stale_components AS (
  SELECT ARRAY_AGG(id::integer) AS ids
  FROM public.components
  WHERE "index" IN (
    'fixed_camera',
    'fixed_camera_violation_analysis',
    'fixed_camera_violation_ratio',
    'fixed_camera_violation_legend'
  )
)
UPDATE public.dashboards
SET components = ARRAY(
  SELECT component_id
  FROM unnest(COALESCE(components, '{}')) AS component_id
  WHERE NOT component_id = ANY(COALESCE((SELECT ids FROM stale_components), '{}'::integer[]))
)
WHERE components && COALESCE((SELECT ids FROM stale_components), '{}'::integer[]);

DELETE FROM public.query_charts
WHERE "index" IN (
  'fixed_camera',
  'fixed_camera_violation_analysis',
  'fixed_camera_violation_ratio',
  'fixed_camera_violation_legend'
);

DELETE FROM public.component_charts
WHERE "index" IN (
  'fixed_camera',
  'fixed_camera_violation_analysis',
  'fixed_camera_violation_ratio',
  'fixed_camera_violation_legend'
);

DELETE FROM public.components
WHERE "index" IN (
  'fixed_camera',
  'fixed_camera_violation_analysis',
  'fixed_camera_violation_ratio',
  'fixed_camera_violation_legend'
);

DELETE FROM public.component_maps
WHERE "index" IN ('taipei_camera', 'newtaipei_camera');

DO $body$
DECLARE
  taipei_map_id integer;
  newtaipei_map_id integer;
  analysis_id integer;
BEGIN
  INSERT INTO public.component_maps ("index", title, type, source, size, icon, paint, property)
  VALUES (
    'taipei_camera',
    '台北固定式照相',
    'circle',
    'geojson',
    NULL,
    NULL,
    '{
      "circle-color": [
        "match",
        ["get", "violation_group"],
        "超速", "#22D3EE",
        "闖紅燈", "#F43F5E",
        "複合取締", "#F59E0B",
        "其他違規", "#A855F7",
        "未標示", "#94A3B8",
        "#94A3B8"
      ],
      "circle-radius": [
        "match",
        ["get", "violation_group"],
        "複合取締", 6,
        "其他違規", 5,
        4
      ],
      "circle-stroke-color": "#ffffff",
      "circle-stroke-width": 1,
      "circle-opacity": 0.9
    }'::json,
    '[
      {"key":"city","name":"城市"},
      {"key":"district","name":"行政區"},
      {"key":"violation_group","name":"分類"},
      {"key":"violation_type","name":"違規類型"},
      {"key":"address","name":"位置"},
      {"key":"direction","name":"拍攝方向"},
      {"key":"speed_limit","name":"速限"},
      {"key":"branch","name":"單位"},
      {"key":"device_id","name":"設備編號"}
    ]'::json
  ) RETURNING id::integer INTO taipei_map_id;

  INSERT INTO public.component_maps ("index", title, type, source, size, icon, paint, property)
  VALUES (
    'newtaipei_camera',
    '新北固定式照相',
    'circle',
    'geojson',
    NULL,
    NULL,
    '{
      "circle-color": [
        "match",
        ["get", "violation_group"],
        "超速", "#22D3EE",
        "闖紅燈", "#F43F5E",
        "複合取締", "#F59E0B",
        "其他違規", "#A855F7",
        "未標示", "#94A3B8",
        "#94A3B8"
      ],
      "circle-radius": [
        "match",
        ["get", "violation_group"],
        "複合取締", 6,
        "其他違規", 5,
        4
      ],
      "circle-stroke-color": "#ffffff",
      "circle-stroke-width": 1,
      "circle-opacity": 0.9
    }'::json,
    '[
      {"key":"city","name":"城市"},
      {"key":"district","name":"行政區"},
      {"key":"violation_group","name":"分類"},
      {"key":"violation_type","name":"違規類型"},
      {"key":"address","name":"位置"},
      {"key":"direction","name":"拍攝方向"},
      {"key":"speed_limit","name":"速限"},
      {"key":"branch","name":"單位"},
      {"key":"device_id","name":"設備編號"}
    ]'::json
  ) RETURNING id::integer INTO newtaipei_map_id;

  INSERT INTO public.components ("index", name)
  VALUES ('fixed_camera_violation_analysis', '固定式照相監視器總覽')
  RETURNING id::integer INTO analysis_id;

  INSERT INTO public.component_charts ("index", color, types, unit)
  VALUES (
    'fixed_camera_violation_analysis',
    ARRAY['#22D3EE','#F43F5E','#F59E0B','#A855F7','#94A3B8'],
    ARRAY['CameraMonitorChart'],
    '處'
  );

  INSERT INTO public.query_charts (
    "index", history_config, map_config_ids, map_filter, time_from, time_to,
    update_freq, update_freq_unit, source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at, query_type, query_chart,
    query_history, city
  ) VALUES (
    'fixed_camera_violation_analysis', NULL, ARRAY[taipei_map_id], '{"mode":"byParam","byParam":{"xParam":"district","yParam":"violation_group"}}'::json,
    'current', NULL, NULL, NULL,
    '臺北市政府警察局、新北市政府警察局',
    '整合台北固定式照相設備總量、違規類型比例與行政區熱點',
    '以客製化監視器總覽呈現台北固定式照相設備的總量、主要取締類型、熱點行政區與違規類型矩陣。',
    '可在同一張組件中掌握設備分布與取締型態，並透過類型、行政區或組合格直接篩選地圖。',
    ARRAY['https://data.taipei/dataset/detail?id=5012e8ba-5ace-4821-8482-ee07c147fd0a']::text[], ARRAY['doit'], NOW(), NOW(), 'three_d',
    $sql$WITH base AS (
      SELECT district AS x_axis,
        CASE
          WHEN violation_type = '' THEN '未標示'
          WHEN violation_type LIKE '%闖紅燈%' AND (violation_type LIKE '%超速%' OR violation_type LIKE '%測速%') THEN '複合取締'
          WHEN violation_type LIKE '%闖紅燈%' THEN '闖紅燈'
          WHEN violation_type LIKE '%超速%' OR violation_type LIKE '%測速%' THEN '超速'
          ELSE '其他違規'
        END AS y_axis
      FROM public.taipei_camera
      WHERE district <> '' AND district NOT LIKE '%、%'
    ), districts AS (
      SELECT unnest(ARRAY['北投區','士林區','內湖區','南港區','松山區','信義區','中山區','大同區','中正區','萬華區','大安區','文山區']) AS x_axis
    ), groups AS (
      SELECT unnest(ARRAY['超速','闖紅燈','複合取締','其他違規','未標示']) AS y_axis
    ), counts AS (
      SELECT x_axis, y_axis, COUNT(*)::int AS data
      FROM base GROUP BY x_axis, y_axis
    )
    SELECT d.x_axis, g.y_axis, COALESCE(c.data, 0) AS data
    FROM districts d
    CROSS JOIN groups g
    LEFT JOIN counts c ON c.x_axis = d.x_axis AND c.y_axis = g.y_axis
    ORDER BY ARRAY_POSITION(ARRAY['北投區','士林區','內湖區','南港區','松山區','信義區','中山區','大同區','中正區','萬華區','大安區','文山區']::varchar[], d.x_axis),
             ARRAY_POSITION(ARRAY['超速','闖紅燈','複合取締','其他違規','未標示']::varchar[], g.y_axis)$sql$,
    NULL, 'taipei'
  );

  INSERT INTO public.query_charts (
    "index", history_config, map_config_ids, map_filter, time_from, time_to,
    update_freq, update_freq_unit, source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at, query_type, query_chart,
    query_history, city
  ) VALUES (
    'fixed_camera_violation_analysis', NULL, ARRAY[taipei_map_id, newtaipei_map_id], '{"mode":"byParam","byParam":{"xParam":"district","yParam":"violation_group"}}'::json,
    'current', NULL, NULL, NULL,
    '臺北市政府警察局、新北市政府警察局',
    '整合雙北固定式照相設備總量、違規類型比例與行政區熱點',
    '以客製化監視器總覽呈現雙北固定式照相設備的總量、主要取締類型、熱點行政區與違規類型矩陣。',
    '可在同一張組件中掌握設備分布與取締型態，並透過類型、行政區或組合格直接篩選地圖。',
    ARRAY['https://data.taipei/dataset/detail?id=5012e8ba-5ace-4821-8482-ee07c147fd0a','https://data.ntpc.gov.tw/api/datasets/99f3ff6e-0352-4399-a726-775ab765a1dc/csv?page=0&size=1000']::text[], ARRAY['doit','ntpc'], NOW(), NOW(), 'three_d',
    $sql$WITH base AS (
      SELECT district AS x_axis,
        CASE
          WHEN violation_type = '' THEN '未標示'
          WHEN violation_type LIKE '%闖紅燈%' AND (violation_type LIKE '%超速%' OR violation_type LIKE '%測速%') THEN '複合取締'
          WHEN violation_type LIKE '%闖紅燈%' THEN '闖紅燈'
          WHEN violation_type LIKE '%超速%' OR violation_type LIKE '%測速%' THEN '超速'
          ELSE '其他違規'
        END AS y_axis
      FROM public.taipei_camera
      WHERE district <> '' AND district NOT LIKE '%、%'
      UNION ALL
      SELECT district AS x_axis,
        CASE
          WHEN violation_type = '' THEN '未標示'
          WHEN violation_type LIKE '%闖紅燈%' AND (violation_type LIKE '%超速%' OR violation_type LIKE '%測速%') THEN '複合取締'
          WHEN violation_type LIKE '%闖紅燈%' THEN '闖紅燈'
          WHEN violation_type LIKE '%超速%' OR violation_type LIKE '%測速%' THEN '超速'
          ELSE '其他違規'
        END AS y_axis
      FROM public.newtaipei_camera
      WHERE district <> ''
    ), districts AS (
      SELECT unnest(ARRAY[
        '北投區','士林區','內湖區','南港區','松山區','信義區','中山區','大同區','中正區','萬華區','大安區','文山區',
        '板橋區','三重區','中和區','永和區','新莊區','新店區','土城區','蘆洲區','樹林區','鶯歌區','三峽區','淡水區','汐止區','瑞芳區','五股區','泰山區','林口區','深坑區','石碇區','坪林區','三芝區','石門區','八里區','平溪區','雙溪區','貢寮區','金山區','萬里區','烏來區'
      ]) AS x_axis
    ), groups AS (
      SELECT unnest(ARRAY['超速','闖紅燈','複合取締','其他違規','未標示']) AS y_axis
    ), counts AS (
      SELECT x_axis, y_axis, COUNT(*)::int AS data
      FROM base GROUP BY x_axis, y_axis
    )
    SELECT d.x_axis, g.y_axis, COALESCE(c.data, 0) AS data
    FROM districts d
    CROSS JOIN groups g
    LEFT JOIN counts c ON c.x_axis = d.x_axis AND c.y_axis = g.y_axis
    WHERE EXISTS (SELECT 1 FROM counts x WHERE x.x_axis = d.x_axis)
    ORDER BY ARRAY_POSITION(ARRAY[
      '北投區','士林區','內湖區','南港區','松山區','信義區','中山區','大同區','中正區','萬華區','大安區','文山區',
      '板橋區','三重區','中和區','永和區','新莊區','新店區','土城區','蘆洲區','樹林區','鶯歌區','三峽區','淡水區','汐止區','瑞芳區','五股區','泰山區','林口區','深坑區','石碇區','坪林區','三芝區','石門區','八里區','平溪區','雙溪區','貢寮區','金山區','萬里區','烏來區'
    ]::varchar[], d.x_axis),
    ARRAY_POSITION(ARRAY['超速','闖紅燈','複合取締','其他違規','未標示']::varchar[], g.y_axis)$sql$,
    NULL, 'metrotaipei'
  );

  UPDATE public.dashboards
  SET components = CASE
    WHEN components @> ARRAY[analysis_id] THEN components
    ELSE array_append(COALESCE(components, '{}'), analysis_id)
  END
  WHERE "index" IN (
    'test-layers',
    'map-layers-taipei',
    'map-layers-metrotaipei',
    'practical_transportation_newtpe',
    'ltc_care_tpe'
  );

END
$body$;
