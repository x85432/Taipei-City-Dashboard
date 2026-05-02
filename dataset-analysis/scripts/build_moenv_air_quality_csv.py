#!/usr/bin/env python3
"""Build Taipei/New Taipei air quality CSVs from MOENV AQX_P_432.

Outputs:
1. Station-level current air quality rows.
2. District-level air pressure rows for dashboard pressure ranking.

Usage:
    MOENV_API_KEY=... python3 dataset-analysis/scripts/build_moenv_air_quality_csv.py
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import ssl
import statistics
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DISTRICT_GEOJSON = (
    PROJECT_ROOT
    / "Taipei-City-Dashboard-FE"
    / "public"
    / "mapData"
    / "metrotaipei_town.geojson"
)
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "dataset-analysis" / "eco-friendly"
COUNTIES = {"臺北市", "台北市", "新北市"}

FIELD_MAP = {
    "siteid": "site_id",
    "sitename": "site_name",
    "county": "city",
    "aqi": "aqi",
    "pollutant": "pollutant",
    "status": "status",
    "so2": "so2_ppb",
    "co": "co_ppm",
    "o3": "o3_ppb",
    "o3_8hr": "o3_8hr_ppb",
    "pm10": "pm10_ug_m3",
    "pm2.5": "pm2_5_ug_m3",
    "no2": "no2_ppb",
    "nox": "nox_ppb",
    "no": "no_ppb",
    "wind_speed": "wind_speed_m_sec",
    "wind_direc": "wind_direction_degree",
    "publishtime": "publish_time",
    "co_8hr": "co_8hr_ppm",
    "pm2.5_avg": "pm2_5_avg_ug_m3",
    "pm10_avg": "pm10_avg_ug_m3",
    "so2_avg": "so2_avg_ppb",
    "longitude": "longitude",
    "latitude": "latitude",
    "importdate": "import_date",
}

NUMERIC_FIELDS = {
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
}

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

DISTRICT_COLUMNS = [
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--api-key", default=os.getenv("MOENV_API_KEY"))
    parser.add_argument(
        "--verify-ssl",
        action=argparse.BooleanOptionalAction,
        default=os.getenv("MOENV_VERIFY_SSL", "true").strip().lower()
        not in {"0", "false", "no"},
    )
    parser.add_argument("--dataset-code", default="AQX_P_432")
    parser.add_argument("--limit", type=int, default=1000)
    parser.add_argument("--input-json", type=Path)
    parser.add_argument("--district-geojson", type=Path, default=DEFAULT_DISTRICT_GEOJSON)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument(
        "--station-output",
        default="雙北空氣品質測站即時資料.csv",
    )
    parser.add_argument(
        "--district-output",
        default="雙北空氣品質行政區壓力.csv",
    )
    parser.add_argument(
        "--raw-output",
        default="雙北空氣品質原始API資料.json",
    )
    return parser.parse_args()


def fetch_moenv_records(
    dataset_code: str,
    api_key: str,
    limit: int,
    verify_ssl: bool,
) -> list[dict]:
    if not api_key:
        raise ValueError("Missing API key. Pass --api-key or set MOENV_API_KEY.")

    base_url = f"https://data.moenv.gov.tw/api/v2/{dataset_code}"
    records: list[dict] = []
    offset = 0
    total = None

    while total is None or offset < total:
        params = {
            "api_key": api_key,
            "format": "json",
            "limit": limit,
            "offset": offset,
            "sort": "ImportDate desc",
        }
        url = f"{base_url}?{urllib.parse.urlencode(params)}"
        context = None if verify_ssl else ssl._create_unverified_context()
        try:
            with urllib.request.urlopen(url, timeout=45, context=context) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"MOENV request failed: {exc.code} {body}") from exc

        page_records = extract_records(payload)
        records.extend(page_records)
        total = int(payload.get("total", len(page_records))) if isinstance(payload, dict) else len(page_records)
        if not page_records:
            break
        offset += limit

    return records


def extract_records(payload) -> list[dict]:
    if isinstance(payload, list):
        return payload
    if not isinstance(payload, dict):
        return []
    if isinstance(payload.get("records"), list):
        return payload["records"]
    result = payload.get("result")
    if isinstance(result, dict) and isinstance(result.get("records"), list):
        return result["records"]
    return []


def to_float(value):
    if value in (None, "", "-", "ND", "NA", "nan"):
        return None
    try:
        return float(str(value).strip())
    except ValueError:
        return None


def normalize_city(value: str) -> str:
    return "臺北市" if value == "台北市" else value


def normalize_record(record: dict, districts: list[dict], updated_at: str) -> dict:
    normalized = {}
    lowered = {str(key).lower(): value for key, value in record.items()}

    for source, target in FIELD_MAP.items():
        value = lowered.get(source)
        if target in NUMERIC_FIELDS:
            value = to_float(value)
        normalized[target] = value

    normalized["city"] = normalize_city(normalized.get("city"))
    normalized["district"] = find_district(
        normalized.get("longitude"),
        normalized.get("latitude"),
        normalized.get("city"),
        districts,
    )
    normalized["source_dataset"] = "MOENV AQX_P_432"
    normalized["updated_at"] = updated_at
    return normalized


def load_districts(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    districts = []
    for feature in data.get("features", []):
        properties = feature.get("properties", {})
        geometry = feature.get("geometry", {})
        polygons = extract_polygons(geometry)
        bbox = geometry_bbox(polygons)
        districts.append(
            {
                "city": normalize_city(properties.get("PNAME")),
                "district": properties.get("TNAME"),
                "polygons": polygons,
                "bbox": bbox,
            }
        )
    return districts


def extract_polygons(geometry: dict) -> list[list[list[list[float]]]]:
    geometry_type = geometry.get("type")
    coordinates = geometry.get("coordinates", [])
    if geometry_type == "Polygon":
        return [coordinates]
    if geometry_type == "MultiPolygon":
        return coordinates
    return []


def geometry_bbox(polygons: list) -> tuple[float, float, float, float]:
    points = [
        point
        for polygon in polygons
        for ring in polygon
        for point in ring
    ]
    lngs = [point[0] for point in points]
    lats = [point[1] for point in points]
    return min(lngs), min(lats), max(lngs), max(lats)


def find_district(lng, lat, city, districts: list[dict]) -> str:
    if lng is None or lat is None:
        return ""
    for item in districts:
        if city and item["city"] != city:
            continue
        min_lng, min_lat, max_lng, max_lat = item["bbox"]
        if not (min_lng <= lng <= max_lng and min_lat <= lat <= max_lat):
            continue
        if any(point_in_polygon(lng, lat, polygon) for polygon in item["polygons"]):
            return item["district"] or ""
    return ""


def point_in_polygon(lng: float, lat: float, polygon: list) -> bool:
    if not polygon or not point_in_ring(lng, lat, polygon[0]):
        return False
    return not any(point_in_ring(lng, lat, hole) for hole in polygon[1:])


def point_in_ring(lng: float, lat: float, ring: list) -> bool:
    inside = False
    j = len(ring) - 1
    for i in range(len(ring)):
        xi, yi = ring[i][0], ring[i][1]
        xj, yj = ring[j][0], ring[j][1]
        if (yi > lat) != (yj > lat):
            x_intersect = (xj - xi) * (lat - yi) / ((yj - yi) or 1e-12) + xi
            if lng < x_intersect:
                inside = not inside
        j = i
    return inside


def average(values: list[float]) -> float | None:
    clean = [value for value in values if value is not None]
    return round(statistics.fmean(clean), 2) if clean else None


def status_rank(status: str) -> int:
    order = {
        "良好": 0,
        "普通": 1,
        "對敏感族群不健康": 2,
        "對所有族群不健康": 3,
        "非常不健康": 4,
        "危害": 5,
    }
    return order.get(status or "", -1)


def build_district_rows(rows: list[dict], updated_at: str) -> list[dict]:
    groups = defaultdict(list)
    for row in rows:
        if row.get("district"):
            groups[(row["city"], row["district"])].append(row)

    output = []
    for (city, district), group_rows in sorted(groups.items()):
        aqi_values = [row.get("aqi") for row in group_rows if row.get("aqi") is not None]
        max_aqi = max(aqi_values) if aqi_values else None
        score = min(100, round(max_aqi, 2)) if max_aqi is not None else None
        statuses = [row.get("status") for row in group_rows if row.get("status")]
        pollutants = [
            row.get("pollutant")
            for row in group_rows
            if row.get("pollutant") not in (None, "", "無")
        ]
        publish_times = [row.get("publish_time") for row in group_rows if row.get("publish_time")]
        output.append(
            {
                "city": city,
                "district": district,
                "period": max(publish_times) if publish_times else "",
                "pressure_type": "空氣",
                "metric_name": "AQI",
                "station_count": len(group_rows),
                "avg_aqi": average([row.get("aqi") for row in group_rows]),
                "max_aqi": round(max_aqi, 2) if max_aqi is not None else "",
                "avg_pm2_5": average([row.get("pm2_5_avg_ug_m3") for row in group_rows]),
                "avg_pm10": average([row.get("pm10_avg_ug_m3") for row in group_rows]),
                "avg_o3_8hr": average([row.get("o3_8hr_ppb") for row in group_rows]),
                "worst_status": max(statuses, key=status_rank) if statuses else "",
                "dominant_pollutant": Counter(pollutants).most_common(1)[0][0]
                if pollutants
                else "",
                "score": score if score is not None else "",
                "unit": "score_0_100",
                "source_dataset": "MOENV AQX_P_432",
                "updated_at": updated_at,
            }
        )
    return output


def write_csv(path: Path, rows: list[dict], columns: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    args = parse_args()
    updated_at = datetime.now().astimezone().isoformat(timespec="seconds")
    districts = load_districts(args.district_geojson)

    if args.input_json:
        payload = json.loads(args.input_json.read_text(encoding="utf-8"))
        records = extract_records(payload)
    else:
        records = fetch_moenv_records(
            args.dataset_code,
            args.api_key,
            args.limit,
            args.verify_ssl,
        )
        args.output_dir.mkdir(parents=True, exist_ok=True)
        (args.output_dir / args.raw_output).write_text(
            json.dumps(records, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    rows = [
        normalize_record(record, districts, updated_at)
        for record in records
        if normalize_city(record.get("county") or record.get("County")) in COUNTIES
    ]
    rows.sort(key=lambda row: (row.get("city") or "", row.get("district") or "", row.get("site_name") or ""))
    district_rows = build_district_rows(rows, updated_at)

    station_path = args.output_dir / args.station_output
    district_path = args.output_dir / args.district_output
    write_csv(station_path, rows, STATION_COLUMNS)
    write_csv(district_path, district_rows, DISTRICT_COLUMNS)

    print(f"station_rows={len(rows)} output={station_path}")
    print(f"district_rows={len(district_rows)} output={district_path}")
    missing_districts = [row["site_name"] for row in rows if not row.get("district")]
    if missing_districts:
        print(f"missing_district_sites={','.join(missing_districts)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
