--
-- Food carbon ranking component seed data
--

BEGIN;

ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS levels json;

ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS ranking_config json;

INSERT INTO public.components ("index", name)
VALUES ('food_carbon_ranking', '飲食每克碳排')
ON CONFLICT ("index") DO UPDATE
SET name = EXCLUDED.name;

INSERT INTO public.component_charts ("index", color, types, unit, levels, ranking_config)
VALUES (
    'food_carbon_ranking',
    ARRAY['#56B96D', '#BBD55A', '#F8CF58', '#F5AD4A', '#F05D5E'],
    ARRAY['RankingOverviewChart'],
    'gCO2e/g',
    '[
        {"label":"低","fullLabel":"低碳排","min":0,"max":1},
        {"label":"中低","fullLabel":"中低碳排","min":1.01,"max":3},
        {"label":"中","fullLabel":"中碳排","min":3.01,"max":7},
        {"label":"高","fullLabel":"高碳排","min":7.01,"max":12},
        {"label":"極高","fullLabel":"極高碳排","min":12.01,"max":25}
    ]'::json,
    '{
        "order": "desc",
        "primary_metric": "leading",
        "value_precision": 2,
        "value_divisor": 100,
        "labels": {
            "primary": "最高分類",
            "leading": "最高分類",
            "average": "每克平均",
            "count": "分類數",
            "countUnit": "類",
            "rank": "排名",
            "diff": "與平均差",
            "listTitle": "每公克碳排排名"
        }
    }'::json
)
ON CONFLICT ("index") DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit,
    levels = EXCLUDED.levels,
    ranking_config = EXCLUDED.ranking_config;

DELETE FROM public.query_charts
WHERE "index" = 'food_carbon_ranking'
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
    'food_carbon_ranking',
    NULL,
    NULL,
    NULL,
    'static',
    NULL,
    0,
    '',
    '環境部碳足跡標籤資料',
    '飲食類產品每公克碳排排名',
    '依飲食類產品碳標籤資料換算每公克碳排後排序，呈現不同食品分類的相對排放差異。每公克資料沿用來源值；每毫升以1毫升約1公克換算；蛋以每顆約60公克換算。',
    '可用於協助使用者在用餐或採買前，理解不同食物分類在同一重量基準下的碳排差異，做出較低碳的飲食選擇。',
    ARRAY[
        'https://cfp.moenv.gov.tw/WebPage/WebSites/CoefficientDB.aspx',
        'https://data.moenv.gov.tw/dataset/detail/CFP_P_02'
    ],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'three_d',
    'SELECT category AS x_axis, ''每公克碳排'' AS y_axis, '''' AS icon, ROUND(carbon_gco2e_per_gram * 100)::int AS data FROM public.food_carbon_categories ORDER BY carbon_gco2e_per_gram DESC, category',
    NULL,
    'taipei'
),
(
    'food_carbon_ranking',
    NULL,
    NULL,
    NULL,
    'static',
    NULL,
    0,
    '',
    '環境部碳足跡標籤資料',
    '飲食類產品每公克碳排排名',
    '依飲食類產品碳標籤資料換算每公克碳排後排序，呈現不同食品分類的相對排放差異。每公克資料沿用來源值；每毫升以1毫升約1公克換算；蛋以每顆約60公克換算。',
    '可用於協助使用者在用餐或採買前，理解不同食物分類在同一重量基準下的碳排差異，做出較低碳的飲食選擇。',
    ARRAY[
        'https://cfp.moenv.gov.tw/WebPage/WebSites/CoefficientDB.aspx',
        'https://data.moenv.gov.tw/dataset/detail/CFP_P_02'
    ],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'three_d',
    'SELECT category AS x_axis, ''每公克碳排'' AS y_axis, '''' AS icon, ROUND(carbon_gco2e_per_gram * 100)::int AS data FROM public.food_carbon_categories ORDER BY carbon_gco2e_per_gram DESC, category',
    NULL,
    'metrotaipei'
);

DO $$
DECLARE
    v_id integer;
BEGIN
    SELECT id::integer INTO v_id
    FROM public.components
    WHERE "index" = 'food_carbon_ranking';

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
