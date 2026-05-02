#!/usr/bin/env python3
"""Build normalized environment pressure data assets.

This script turns the cleaned MOENV air-quality CSVs into:
- UTF-8 normalized CSVs with stable English filenames.
- Station point GeoJSON.
- District pressure choropleth GeoJSON.
- PostgreSQL seed SQL for dashboard data tables.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = PROJECT_ROOT / "dataset-analysis" / "eco-friendly"
MAPDATA_DIR = PROJECT_ROOT / "Taipei-City-Dashboard-FE" / "public" / "mapData"
DB_SAMPLE_DIR = PROJECT_ROOT / "db-sample-data"

SOURCE_STATIONS = SOURCE_DIR / "雙北空氣品質測站即時資料.csv"
SOURCE_PRESSURE = SOURCE_DIR / "雙北空氣品質行政區壓力.csv"
DISTRICT_GEOJSON = MAPDATA_DIR / "metrotaipei_town.geojson"

NORMALIZED_STATIONS = SOURCE_DIR / "environment_air_quality_stations.csv"
NORMALIZED_PRESSURE = SOURCE_DIR / "environment_pressure_index.csv"
STATION_GEOJSON = MAPDATA_DIR / "environment_air_quality_stations.geojson"
DISTRICT_PRESSURE_GEOJSON = MAPDATA_DIR / "environment_air_pressure_district.geojson"
SQL_OUTPUT = DB_SAMPLE_DIR / "dashboard-air-quality.sql"

STATION_COLUMNS = [
    "city",
    "district",
    "site_id",
    "site_name",
    "status",
    "aqi",
    "pollutant",
    "so2_ppb",
    "co_ppm",
    "o3_ppb",
    "o3_8hr_ppb",
    "pm10_ug_m3",
    "pm2_5_ug_m3",
    "no2_ppb",
    "nox_ppb",
    "no_ppb",
    "wind_speed_m_sec",
    "wind_direction_degree",
    "co_8hr_ppm",
    "pm2_5_avg_ug_m3",
    "pm10_avg_ug_m3",
    "so2_avg_ppb",
    "longitude",
    "latitude",
    "publish_time",
    "import_date",
    "source_dataset",
    "updated_at",
]

PRESSURE_COLUMNS = [
    "city",
    "district",
    "period",
    "pressure_type",
    "metric_name",
    "station_count",
    "avg_aqi",
    "max_aqi",
    "avg_pm2_5",
    "avg_pm10",
    "avg_o3_8hr",
    "worst_status",
    "dominant_pollutant",
    "score",
    "unit",
    "source_dataset",
    "updated_at",
]

NUMERIC_COLUMNS = {
    "site_id",
    "aqi",
    "so2_ppb",
    "co_ppm",
    "o3_ppb",
    "o3_8hr_ppb",
    "pm10_ug_m3",
    "pm2_5_ug_m3",
    "no2_ppb",
    "nox_ppb",
    "no_ppb",
    "wind_speed_m_sec",
    "wind_direction_degree",
    "co_8hr_ppm",
    "pm2_5_avg_ug_m3",
    "pm10_avg_ug_m3",
    "so2_avg_ppb",
    "longitude",
    "latitude",
    "station_count",
    "avg_aqi",
    "max_aqi",
    "avg_pm2_5",
    "avg_pm10",
    "avg_o3_8hr",
    "score",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-stations", type=Path, default=SOURCE_STATIONS)
    parser.add_argument("--source-pressure", type=Path, default=SOURCE_PRESSURE)
    parser.add_argument("--district-geojson", type=Path, default=DISTRICT_GEOJSON)
    parser.add_argument("--normalized-stations", type=Path, default=NORMALIZED_STATIONS)
    parser.add_argument("--normalized-pressure", type=Path, default=NORMALIZED_PRESSURE)
    parser.add_argument("--station-geojson", type=Path, default=STATION_GEOJSON)
    parser.add_argument(
        "--district-pressure-geojson",
        type=Path,
        default=DISTRICT_PRESSURE_GEOJSON,
    )
    parser.add_argument("--sql-output", type=Path, default=SQL_OUTPUT)
    return parser.parse_args()


def read_csv(path: Path) -> list[dict]:
    with path.open("r", encoding="utf-8-sig", newline="") as file:
        return list(csv.DictReader(file))


def write_csv(path: Path, rows: list[dict], columns: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def clean_row(row: dict, columns: list[str]) -> dict:
    cleaned = {}
    for column in columns:
        value = row.get(column, "")
        if value is None:
            value = ""
        value = str(value).strip()
        if column in NUMERIC_COLUMNS:
            value = normalize_number(value)
        cleaned[column] = value
    return cleaned


def normalize_number(value: str) -> str:
    if value in {"", "nan", "NaN", "None", "null", "-"}:
        return ""
    try:
        number = float(value)
    except ValueError:
        return ""
    if number.is_integer():
        return str(int(number))
    return f"{number:.4f}".rstrip("0").rstrip(".")


def to_float(value: str):
    if value == "":
        return None
    try:
        return float(value)
    except ValueError:
        return None


def build_station_geojson(rows: list[dict]) -> dict:
    features = []
    for row in rows:
        lng = to_float(row.get("longitude", ""))
        lat = to_float(row.get("latitude", ""))
        if lng is None or lat is None:
            continue
        properties = {
            key: value
            for key, value in row.items()
            if key not in {"longitude", "latitude"}
        }
        properties["pressure_type"] = "空氣"
        properties["score"] = row.get("aqi", "")
        features.append(
            {
                "type": "Feature",
                "geometry": {"type": "Point", "coordinates": [lng, lat]},
                "properties": properties,
            }
        )
    return {"type": "FeatureCollection", "features": features}


def build_district_pressure_geojson(pressure_rows: list[dict], district_path: Path) -> dict:
    district_data = json.loads(district_path.read_text(encoding="utf-8"))
    pressure_by_key = {
        (row.get("city", ""), row.get("district", "")): row
        for row in pressure_rows
    }

    output_features = []
    for feature in district_data.get("features", []):
        properties = feature.get("properties", {})
        city = properties.get("PNAME", "")
        district = properties.get("TNAME", "")
        pressure = pressure_by_key.get((city, district), {})
        next_properties = {
            **properties,
            "city": city,
            "district": district,
            "has_data": bool(pressure),
            "pressure_type": pressure.get("pressure_type", "空氣"),
            "period": pressure.get("period", ""),
            "metric_name": pressure.get("metric_name", "AQI"),
            "station_count": pressure.get("station_count", ""),
            "avg_aqi": pressure.get("avg_aqi", ""),
            "max_aqi": pressure.get("max_aqi", ""),
            "avg_pm2_5": pressure.get("avg_pm2_5", ""),
            "avg_pm10": pressure.get("avg_pm10", ""),
            "avg_o3_8hr": pressure.get("avg_o3_8hr", ""),
            "worst_status": pressure.get("worst_status", ""),
            "dominant_pollutant": pressure.get("dominant_pollutant", ""),
            "score": pressure.get("score", ""),
            "unit": pressure.get("unit", "score_0_100"),
            "source_dataset": pressure.get("source_dataset", "MOENV AQX_P_432"),
            "updated_at": pressure.get("updated_at", ""),
        }
        output_features.append(
            {
                "type": "Feature",
                "geometry": feature.get("geometry"),
                "properties": next_properties,
            }
        )

    return {"type": "FeatureCollection", "features": output_features}


def write_geojson(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


def sql_value(value: str) -> str:
    if value == "":
        return r"\N"
    return value.replace("\\", "\\\\").replace("\t", " ").replace("\n", " ")


def copy_block(table: str, columns: list[str], rows: list[dict]) -> str:
    lines = [
        f"COPY public.{table} ({', '.join(columns)}) FROM stdin;",
    ]
    for row in rows:
        lines.append("\t".join(sql_value(row.get(column, "")) for column in columns))
    lines.append(r"\.")
    return "\n".join(lines)


def build_sql(station_rows: list[dict], pressure_rows: list[dict]) -> str:
    return f"""-- Air quality data seed
-- Generated by dataset-analysis/scripts/build_air_quality_assets.py

DROP TABLE IF EXISTS public.environment_air_quality_stations;
CREATE TABLE public.environment_air_quality_stations (
    id SERIAL PRIMARY KEY,
    city text,
    district text,
    site_id integer,
    site_name text,
    status text,
    aqi double precision,
    pollutant text,
    so2_ppb double precision,
    co_ppm double precision,
    o3_ppb double precision,
    o3_8hr_ppb double precision,
    pm10_ug_m3 double precision,
    pm2_5_ug_m3 double precision,
    no2_ppb double precision,
    nox_ppb double precision,
    no_ppb double precision,
    wind_speed_m_sec double precision,
    wind_direction_degree double precision,
    co_8hr_ppm double precision,
    pm2_5_avg_ug_m3 double precision,
    pm10_avg_ug_m3 double precision,
    so2_avg_ppb double precision,
    longitude double precision,
    latitude double precision,
    publish_time text,
    import_date text,
    source_dataset text,
    updated_at text
);

DROP TABLE IF EXISTS public.environment_pressure_index;
CREATE TABLE public.environment_pressure_index (
    id SERIAL PRIMARY KEY,
    city text,
    district text,
    period text,
    pressure_type text,
    metric_name text,
    station_count integer,
    avg_aqi double precision,
    max_aqi double precision,
    avg_pm2_5 double precision,
    avg_pm10 double precision,
    avg_o3_8hr double precision,
    worst_status text,
    dominant_pollutant text,
    score double precision,
    unit text,
    source_dataset text,
    updated_at text
);

{copy_block("environment_air_quality_stations", STATION_COLUMNS, station_rows)}

{copy_block("environment_pressure_index", PRESSURE_COLUMNS, pressure_rows)}

CREATE INDEX IF NOT EXISTS environment_air_quality_stations_city_district_idx
ON public.environment_air_quality_stations (city, district);

CREATE INDEX IF NOT EXISTS environment_pressure_index_city_district_type_idx
ON public.environment_pressure_index (city, district, pressure_type);

SELECT pg_catalog.setval(
    'public.environment_air_quality_stations_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM public.environment_air_quality_stations),
    true
);

SELECT pg_catalog.setval(
    'public.environment_pressure_index_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM public.environment_pressure_index),
    true
);
"""


def main() -> int:
    args = parse_args()
    station_rows = [
        clean_row(row, STATION_COLUMNS)
        for row in read_csv(args.source_stations)
    ]
    pressure_rows = [
        clean_row(row, PRESSURE_COLUMNS)
        for row in read_csv(args.source_pressure)
    ]

    station_rows.sort(
        key=lambda row: (
            row["city"],
            row["district"],
            row["site_name"],
            row["site_id"],
        )
    )
    pressure_rows.sort(
        key=lambda row: (
            row["city"],
            row["district"],
            row["pressure_type"],
        )
    )

    write_csv(args.normalized_stations, station_rows, STATION_COLUMNS)
    write_csv(args.normalized_pressure, pressure_rows, PRESSURE_COLUMNS)
    write_geojson(args.station_geojson, build_station_geojson(station_rows))
    write_geojson(
        args.district_pressure_geojson,
        build_district_pressure_geojson(pressure_rows, args.district_geojson),
    )
    args.sql_output.parent.mkdir(parents=True, exist_ok=True)
    args.sql_output.write_text(
        build_sql(station_rows, pressure_rows),
        encoding="utf-8",
    )

    print(f"station_csv={args.normalized_stations} rows={len(station_rows)}")
    print(f"pressure_csv={args.normalized_pressure} rows={len(pressure_rows)}")
    print(f"station_geojson={args.station_geojson}")
    print(f"district_geojson={args.district_pressure_geojson}")
    print(f"sql={args.sql_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
