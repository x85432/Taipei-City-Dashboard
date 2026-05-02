# 建立 Dashboard 組件流程

本專案的資料分成兩個 PostgreSQL database：

- `dashboard`：放原始資料表，例如從 CSV 匯入後的資料。
- `dashboardmanager`：放 component 設定，例如 `components`、`component_charts`、`query_charts`、`component_maps`、`dashboards`。

## 1. 取得 CSV

以銀髮族服務機構為例：

```text
臺北市銀髮族服務相關機構.csv
```

先確認欄位，例如：

```text
序號
機構類型
機構名稱
地址
行政區代碼
電話
立案日期
```

如果 CSV 內有地址但沒有座標，後續若要做地圖點位，需要額外 geocoding 或使用既有點位資料。

## 2. 規劃 component

先決定 component 要呈現什麼。

範例：`銀髮族服務機構分布`

- component index：`senior_service_distribution`
- component name：`銀髮族服務機構分布`
- query type：`three_d`
- chart types：`DistrictChart`, `ColumnChart`
- unit：`家`
- city versions：`taipei`, `metrotaipei`

如果要可以切換臺北市/雙北，做法不是建兩個 component，而是：

- `components` 一筆
- `component_charts` 一筆
- `query_charts` 兩筆
  - `city = 'taipei'`
  - `city = 'metrotaipei'`

## 3. 建 dashboard 原始資料 SQL

在 `db-sample-data` 新增一個 dashboard database 的 patch SQL。

範例：

```text
db-sample-data/dashboard-senior-service.sql
```

內容通常包含：

```sql
DROP TABLE IF EXISTS public.taipei_senior_service_orgs;

CREATE TABLE public.taipei_senior_service_orgs (
    serial_no integer,
    service_type text,
    org_name text,
    address text,
    district_code text,
    phone text,
    approved_date text,
    district text
);
```

接著用 `COPY ... FROM stdin` 放入整理後資料：

```sql
COPY public.taipei_senior_service_orgs (
    serial_no,
    service_type,
    org_name,
    address,
    district_code,
    phone,
    approved_date,
    district
) FROM stdin;
1	居家服務	機構名稱	臺北市萬華區...	63000070	02-xxxx-xxxx	1070709	萬華區
\.
```

注意：如果要用 `DistrictChart`，`district` 必須能對上行政區名稱，例如 `萬華區`、`中山區`。

## 4. 寫 chart query

`three_d` 圖表需要查詢回傳三欄：

```sql
x_axis
y_axis
data
```

範例：

```sql
SELECT
    district AS x_axis,
    service_type AS y_axis,
    COUNT(*)::int AS data
FROM public.taipei_senior_service_orgs
WHERE district IS NOT NULL
  AND (address LIKE '臺北市%' OR address LIKE '台北市%')
GROUP BY district, service_type
ORDER BY district, service_type;
```

```sql
WITH districts AS (
    SELECT DISTINCT district
    FROM public.taipei_senior_service_orgs
    WHERE district IS NOT NULL
),
service_types AS (
    SELECT DISTINCT service_type
    FROM public.taipei_senior_service_orgs
),
counts AS (
    SELECT district, service_type, COUNT(*)::int AS data
    FROM public.taipei_senior_service_orgs
    WHERE district IS NOT NULL
    GROUP BY district, service_type
)
SELECT
    d.district AS x_axis,
    s.service_type AS y_axis,
    COALESCE(c.data, 0) AS data
FROM districts d
CROSS JOIN service_types s
LEFT JOIN counts c
    ON c.district = d.district
   AND c.service_type = s.service_type
ORDER BY d.district, s.service_type;
```

## 5. 建 dashboardmanager metadata SQL

在 `db-sample-data` 新增一個 dashboardmanager database 的 patch SQL。

範例：

```text
db-sample-data/dashboardmanager-senior-service.sql
```

基本內容包含：

```sql
DELETE FROM public.query_charts
WHERE index = 'senior_service_distribution';

DELETE FROM public.component_charts
WHERE index = 'senior_service_distribution';

DELETE FROM public.components
WHERE index = 'senior_service_distribution';

INSERT INTO public.components (id, index, name)
VALUES (219, 'senior_service_distribution', '銀髮族服務機構分布');

INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'senior_service_distribution',
    ARRAY['#24B0DD', '#56B96D', '#F8CF58', '#F5AD4A', '#E170A6'],
    ARRAY['DistrictChart', 'ColumnChart'],
    '家'
);
```


接著新增 `query_charts`。如果要支援臺北市和雙北，要新增兩筆：

```sql
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
    'senior_service_distribution',
    NULL,
    '{}',
    '{}',
    'static',
    NULL,
    0,
    '',
    '臺北市政府資料',
    '顯示臺北市銀髮族服務機構分布',
    '統計臺北市銀髮族服務相關機構，依行政區與服務類型呈現分布情形。',
    '可用於盤點臺北市各行政區銀髮照護與服務資源配置。',
    ARRAY['臺北市銀髮族服務相關機構.csv'],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'three_d',
    'SELECT district AS x_axis, service_type AS y_axis, COUNT(*)::int AS data FROM public.taipei_senior_service_orgs WHERE district IS NOT NULL GROUP BY district, service_type ORDER BY district, service_type',
    NULL,
    'taipei'
);
```

## 6. 掛到 dashboard

component 建好後，還要把 component id 掛到 dashboard 的 `components` 陣列。

範例：把 `219` 掛到長照關懷 dashboard。

```sql
UPDATE public.dashboards
SET components = '{214,215,216,218,219}'
WHERE index = 'ltc_care_tpe';

UPDATE public.dashboards
SET components = '{214,215,216,218,219}'
WHERE index = 'ltc_care_newtpe';
```

最後更新 sequence：

```sql
SELECT pg_catalog.setval(
    'public.components_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM public.components),
    true
);
```

## 7. 如果需要地圖點位

如果 component 要在 `/mapview` 顯示點位，需要兩件事：

1. 在前端放 GeoJSON：

```text
Taipei-City-Dashboard-FE/public/mapData/senior_service_distribution_taipei.geojson
Taipei-City-Dashboard-FE/public/mapData/senior_service_distribution_metrotaipei.geojson
```

GeoJSON 格式：

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "name": "機構名稱",
        "service_type": "居家服務",
        "district": "萬華區",
        "address": "臺北市萬華區...",
        "phone": "02-xxxx-xxxx"
      },
      "geometry": {
        "type": "Point",
        "coordinates": [121.5, 25.03]
      }
    }
  ]
}
```

2. 在 `dashboardmanager` 新增 `component_maps`，再把 id 放進 `query_charts.map_config_ids`。

範例：

```sql
INSERT INTO public.component_maps (
    id,
    index,
    title,
    type,
    source,
    size,
    icon,
    paint,
    property
) VALUES (
    102,
    'senior_service_distribution_taipei',
    '銀髮族服務機構',
    'circle',
    'geojson',
    'big',
    NULL,
    '{"circle-color": "#24B0DD", "circle-stroke-color": "#ffffff", "circle-stroke-width": 1}',
    '[
        {"key": "name", "name": "機構名稱"},
        {"key": "service_type", "name": "機構類型"},
        {"key": "district", "name": "行政區"},
        {"key": "address", "name": "地址"},
        {"key": "phone", "name": "電話"}
    ]'
);
```

`component_maps.index` 必須對應到前端檔名：

```text
component_maps.index = senior_service_distribution_taipei
GeoJSON path = /mapData/senior_service_distribution_taipei.geojson
```

然後 `query_charts.map_config_ids` 要設定：

```sql
-- taipei
map_config_ids = '{102}'

-- metrotaipei
map_config_ids = '{103}'
```

## 8. 接進 init 流程

在 `db-sample-data/dashboard-demo.sql` 最後加：

```sql
\i /opt/db-sample-data/dashboard-senior-service.sql
```

在 `db-sample-data/dashboardmanager-demo.sql` 最後加：

```sql
\i /opt/db-sample-data/dashboardmanager-senior-service.sql
```

路徑必須用 container 內的路徑：

```text
/opt/db-sample-data/...
```

不要寫 Windows 本機路徑。


### 9. RankingOverviewChart 公版排名圖表

`RankingOverviewChart` 是公版的排名總覽元件，可以給不同資料集使用。元件本身不寫死 AQI、飲食碳排、行政區或任何特定領域文案；呈現方式由 `three_d` 查詢結果、`component_charts.levels` 與 `component_charts.ranking_config` 控制。

適合使用情境：

- 行政區、站點、類別、服務、產品等項目排名。
- 需要摘要卡顯示平均、總和或第一名。
- 需要點選某一列後，在元件內顯示該項目的排名與平均との差。
- 可搭配地圖篩選，也可以完全不搭配地圖。

不適合使用情境：

- 一個 `x_axis` 需要同時比較多個系列。
- 需要時間軸趨勢、堆疊比例或複雜交叉表。
- 數值不是單一量尺，且不能透過 `unit` 或描述清楚說明。

#### 9.1 資料格式

`query_type` 使用 `three_d`。查詢至少回傳：

```sql
SELECT
    item_name AS x_axis,      -- 排名項目，例如行政區、站點、食物分類
    '指標名稱' AS y_axis,     -- 系列名稱，通常只放一個系列
    '' AS icon,               -- 保留欄位；RankingOverviewChart 目前不使用 icon
    ROUND(score)::int AS data -- 排名數值，後端 three_d 目前會掃成 int
FROM public.some_table
ORDER BY score DESC, item_name;
```

欄位規則：

- `x_axis`：排名項目名稱，會出現在排名列與點選後的主卡。
- `y_axis`：指標名稱，會成為資料系列名稱；公版建議只回傳一個 `y_axis`。
- `icon`：保留欄位，目前給空字串即可。
- `data`：整數數值。元件會依 `ranking_config.order` 排序。

如果來源是小數，例如 `2.44`，因為後端 `three_d` 的 `data` 目前是 `int`，建議在 SQL 先放大，再用 `ranking_config.value_divisor` 還原顯示：

```sql
SELECT
    category AS x_axis,
    '每公克碳排' AS y_axis,
    '' AS icon,
    ROUND(carbon_gco2e_per_gram * 100)::int AS data
FROM public.food_carbon_categories;
```

搭配：

```json
{
    "value_precision": 2,
    "value_divisor": 100
}
```

前端會先把 `data / value_divisor`，再依 `value_precision` 顯示，所以 `244` 會顯示成 `2.44`。

#### 9.2 有地圖與無地圖接法

如果排名列要同步篩選地圖，設定 `map_config_ids` 與 `map_filter`：

```sql
map_config_ids = '{360,361}'
map_filter = '{"mode":"byParam","byParam":{"xParam":"district"}}'::json
```

如果元件不需要地圖，例如飲食碳排分類排名，設定：

```sql
map_config_ids = NULL
map_filter = NULL
```

無地圖時，點擊排名列只會更新元件自己的摘要卡，不會影響地圖。

#### 9.3 component_charts 設定

若需要分級顏色與標籤，在 `component_charts` 加上 `levels` JSON；沒有 `levels` 時，元件會退回一般單色排名。若需要調整排序、主卡計算方式與文字，使用 `ranking_config`。

```sql
ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS levels json;

ALTER TABLE public.component_charts
    ADD COLUMN IF NOT EXISTS ranking_config json;

INSERT INTO public.component_charts (index, color, types, unit, levels, ranking_config)
VALUES (
    'your_ranking_component',
    ARRAY['#56B96D', '#F8CF58', '#F5AD4A', '#F05D5E'],
    ARRAY['RankingOverviewChart'],
    '分',
    '[
        {"label":"低","fullLabel":"低","min":0,"max":25},
        {"label":"中","fullLabel":"中","min":26,"max":50},
        {"label":"高","fullLabel":"高","min":51,"max":75},
        {"label":"極高","fullLabel":"極高","min":76,"max":100}
    ]'::json,
    '{
        "order": "desc",
        "primary_metric": "average",
        "value_precision": 0,
        "labels": {
            "primary": "平均分數",
            "leading": "最高",
            "average": "平均",
            "count": "筆數",
            "countUnit": "項",
            "rank": "排名",
            "diff": "平均との差",
            "listTitle": "分數排名"
        }
    }'::json
);
```

`levels` 欄位：

- `label`：短標籤，顯示在列尾與圖例。
- `fullLabel`：完整標籤，顯示在 tooltip。
- `min` / `max`：分級範圍，會用來決定顏色。
- 顏色依序取用 `component_charts.color`；也可以在單一 level 裡加 `color` 覆蓋。

`ranking_config` 可用欄位：

- `order`：`desc` 或 `asc`，預設 `desc`。
- `primary_metric`：主卡未選取項目時顯示 `average`、`sum` 或 `leading`，預設 `average`。
- `value_precision`：小數位數，預設 `0`。
- `value_divisor`：顯示前的除數，預設 `1`。用來支援小數資料，例如 SQL 輸出 `244`、設定 `100` 後顯示 `2.44`。
- `labels.primary`：主卡標題，例如 `平均 AQI`、`總服務量`、`最高分類`。
- `labels.leading`：第一名摘要標籤，例如 `最高`、`最低`、`最便利`。
- `labels.average`、`labels.count`、`labels.countUnit`、`labels.rank`、`labels.diff`、`labels.listTitle`：控制元件內固定文案。

#### 9.4 完整範例：空氣品質 AQI

```sql
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

-- query_charts.query_chart
SELECT
    district AS x_axis,
    'AQI' AS y_axis,
    '' AS icon,
    ROUND(score)::int AS data
FROM public.environment_pressure_index
WHERE pressure_type = '空氣'
  AND score IS NOT NULL
ORDER BY city, district;
```

#### 9.5 完整範例：飲食每公克碳排

```sql
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
);

-- query_charts.query_chart
SELECT
    category AS x_axis,
    '每公克碳排' AS y_axis,
    '' AS icon,
    ROUND(carbon_gco2e_per_gram * 100)::int AS data
FROM public.food_carbon_categories
ORDER BY carbon_gco2e_per_gram DESC, category;
```

這個範例的來源資料原本同時有 `每公克`、`每毫升`、`每顆`：

- `每公克`：直接沿用來源值。
- `每毫升`：以 `1 毫升約 1 公克` 換算，適合飲品與水等近似密度資料。
- `每顆`：以 `1 顆蛋約 60 公克` 換算。

換算假設應保存在資料表欄位或 `long_desc`，避免使用者誤以為所有來源原本就是每公克。

### 10. 本機更新空氣品質資料

`query_charts.update_freq` 只控制前端顯示「每多久更新」，不會自己排程抓資料。本機開發時可先用下列腳本更新 MOENV 空氣品質資料：

```bash
MOENV_API_KEY=你的環境部APIKEY \
  python3 dataset-analysis/scripts/update_air_quality_local.py
```

若本機 Python 憑證驗證失敗，可在開發環境加上 `--no-verify-ssl`：

```bash
MOENV_API_KEY=你的環境部APIKEY \
  python3 dataset-analysis/scripts/update_air_quality_local.py --no-verify-ssl
```

這支腳本會依序：

- 呼叫 `build_moenv_air_quality_csv.py` 抓取 `AQX_P_432` 並篩出雙北。
- 呼叫 `build_air_quality_assets.py` 產生正規化 CSV、地圖 GeoJSON 與 `dashboard-air-quality.sql`。
- 呼叫 `build_air_quality_aqi_zones.mjs` 以測站 AQI 做 IDW 插值，依官方 AQI 級距輸出 `environment_air_quality_aqi_zones.geojson` MultiPolygon 面圖。
- 將 `dashboard-air-quality.sql` 匯入 Docker 的 `postgres-data` container，預設 DB 為 `dashboard`。

若要用已下載的原始 JSON 測試，不打 API：

```bash
python3 dataset-analysis/scripts/update_air_quality_local.py \
  --input-json dataset-analysis/eco-friendly/雙北空氣品質原始API資料.json
```

正式部署時，不建議由後端 API 直接呼叫 MOENV。應將同一套資料流程搬到 `Taipei-City-Dashboard-DE`，建立每小時執行的 Airflow DAG，讓 DAG 更新資料庫與地圖資料來源。
