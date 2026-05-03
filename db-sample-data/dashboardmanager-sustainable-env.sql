--
-- Sustainable Environment dashboard seed data
--
-- Depends on:
--   dashboardmanager-resource-recycling.sql (resource_recycling_per_capita)
--   dashboardmanager-recycling.sql          (resource_recycling_tw)
--   dashboardmanager-eco-restaurant.sql     (eco_restaurant_taipei)
--   dashboardmanager-garbage-truck.sql      (garbage_truck)
--   dashboardmanager-clothing-recycle-bins.sql
--   dashboardmanager-air-quality.sql        (air_quality_overview)
--   dashboardmanager-waste.sql              (waste_statistics)
--   dashboardmanager-food-carbon.sql        (food_carbon_ranking)
--   dashboardmanager-green-store.sql        (green_store_distribution)
--

BEGIN;

INSERT INTO public.dashboards ("index", name, components, icon, updated_at, created_at)
SELECT 'sustainable_env_tpe', '永續環境', ARRAY[]::integer[], 'eco', NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.dashboards WHERE "index" = 'sustainable_env_tpe');

INSERT INTO public.dashboards ("index", name, components, icon, updated_at, created_at)
SELECT 'sustainable_env_newtpe', '永續環境', ARRAY[]::integer[], 'eco', NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.dashboards WHERE "index" = 'sustainable_env_newtpe');

-- Keep this dashboard seed canonical. Upstream removed the old eco_zone
-- components, so stale ids must be cleared from existing dashboard rows.
UPDATE public.dashboards
SET components = ARRAY[]::integer[]
WHERE "index" IN ('sustainable_env_tpe', 'sustainable_env_newtpe');

DO $$
DECLARE
    v_legacy_component_id integer;
BEGIN
    -- Clear legacy component ids even if their component rows were already
    -- deleted in a previous seed run.
    FOREACH v_legacy_component_id IN ARRAY ARRAY[320, 330, 340, 350]
    LOOP
        UPDATE public.dashboards
        SET components = array_remove(components, v_legacy_component_id)
        WHERE v_legacy_component_id = ANY(components);
    END LOOP;

    FOR v_legacy_component_id IN
        SELECT id::integer
        FROM public.components
        WHERE "index" IN ('eco_zone1', 'eco_zone2', 'eco_zone3', 'eco_zone4')
    LOOP
        UPDATE public.dashboards
        SET components = array_remove(components, v_legacy_component_id)
        WHERE v_legacy_component_id = ANY(components);
    END LOOP;
END $$;

-- The map layer drawer fetches map-layers dashboards without a city query.
-- Components without query_charts/map_config make the backend fail while
-- parsing map_config, so keep unsupported legacy custom components out.
DO $$
DECLARE
    v_component_id integer;
BEGIN
    FOR v_component_id IN
        SELECT id::integer
        FROM public.components
        WHERE "index" IN ('fixed_camera_violation_analysis')
    LOOP
        UPDATE public.dashboards
        SET components = array_remove(components, v_component_id)
        WHERE "index" IN ('map-layers-taipei', 'map-layers-metrotaipei')
          AND v_component_id = ANY(components);
    END LOOP;
END $$;

DELETE FROM public.query_charts
WHERE "index" IN ('eco_zone1', 'eco_zone2', 'eco_zone3', 'eco_zone4');

DELETE FROM public.component_charts
WHERE "index" IN ('eco_zone1', 'eco_zone2', 'eco_zone3', 'eco_zone4');

DELETE FROM public.component_maps
WHERE "index" IN (
    'eco_zone2_taipei',
    'eco_zone2_metro',
    'eco_zone3_taipei',
    'eco_zone3_metro',
    'eco_zone4_taipei',
    'eco_zone4_metro'
);

DELETE FROM public.components
WHERE "index" IN ('eco_zone1', 'eco_zone2', 'eco_zone3', 'eco_zone4');

DO $$
DECLARE
    v_dashboard_index text;
    v_component_index text;
    v_component_id integer;
BEGIN
    FOREACH v_dashboard_index IN ARRAY ARRAY['sustainable_env_tpe', 'sustainable_env_newtpe']
    LOOP
        FOREACH v_component_index IN ARRAY ARRAY[
            'resource_recycling_per_capita',
            'air_quality_overview',
            'eco_restaurant_taipei',
            'garbage_truck',
            'clothing_recycle_bins',
            'waste_statistics',
            'food_carbon_ranking',
            'green_store_distribution',
            'resource_recycling_tw',
			'taipei_ev_charging'
        ]
        LOOP
            SELECT id::integer INTO v_component_id
            FROM public.components
            WHERE "index" = v_component_index;

            IF v_component_id IS NOT NULL THEN
                UPDATE public.dashboards
                SET components = array_append(components, v_component_id)
                WHERE "index" = v_dashboard_index
                  AND NOT (v_component_id = ANY(components));
            END IF;
        END LOOP;
    END LOOP;
END $$;

INSERT INTO public.dashboard_groups (dashboard_id, group_id)
SELECT d.id, g.id
FROM public.dashboards d
JOIN public.groups g ON g.name = 'taipei'
WHERE d."index" = 'sustainable_env_tpe'
ON CONFLICT DO NOTHING;

INSERT INTO public.dashboard_groups (dashboard_id, group_id)
SELECT d.id, g.id
FROM public.dashboards d
JOIN public.groups g ON g.name = 'metrotaipei'
WHERE d."index" = 'sustainable_env_newtpe'
ON CONFLICT DO NOTHING;

COMMIT;
