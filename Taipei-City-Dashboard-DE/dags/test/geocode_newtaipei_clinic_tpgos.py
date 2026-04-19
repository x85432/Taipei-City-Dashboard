#!/usr/bin/env python3
"""Batch geocode normalized New Taipei clinic CSV with TGOS/TPGOS."""

from __future__ import annotations

import argparse
import csv
import json
import os
import time
import unicodedata
from pathlib import Path
from typing import Any

import requests
import urllib3
from requests.adapters import HTTPAdapter


TGOS_URL = "https://map.tpgos.gov.taipei/embed/webapi.cfm"
OUTPUT_COLUMNS = [
    "city",
    "facility_type",
    "category",
    "name",
    "district_code",
    "district",
    "address",
    "lng",
    "lat",
    "source_dataset",
]


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(
        description="Geocode New Taipei clinic addresses with TGOS/TPGOS and fill lng/lat."
    )
    parser.add_argument(
        "--input",
        default=repo_root / "newtaipei_clinic_normalized.csv",
        type=Path,
        help="Path to the normalized clinic CSV.",
    )
    parser.add_argument(
        "--output",
        default=repo_root / "newtaipei_clinic_geocoded.csv",
        type=Path,
        help="Path to the geocoded output CSV.",
    )
    parser.add_argument(
        "--cache",
        default=repo_root / "newtaipei_clinic_geocode_cache.json",
        type=Path,
        help="Path to the JSON cache file.",
    )
    parser.add_argument(
        "--api-key",
        default=os.getenv("TPGOS_API_KEY", ""),
        help="TGOS/TPGOS API key. Defaults to env TPGOS_API_KEY.",
    )
    parser.add_argument(
        "--sleep-seconds",
        default=0.2,
        type=float,
        help="Delay between uncached requests.",
    )
    parser.add_argument(
        "--timeout",
        default=20,
        type=float,
        help="Request timeout in seconds.",
    )
    parser.add_argument(
        "--insecure",
        action="store_true",
        help="Disable SSL certificate verification for TGOS if your local env fails cert validation.",
    )
    parser.add_argument(
        "--accept-fuzzy",
        action="store_true",
        help="Accept the first returned result even if QUERYTYPE is not 完全比對.",
    )
    return parser.parse_args()


def normalize_text(value: str | None) -> str:
    if value is None:
        return ""
    return value.strip().replace("\t", "")


def normalize_address(address: str) -> str:
    normalized = unicodedata.normalize("NFKC", address)
    normalized = normalized.replace("台", "臺")
    normalized = normalized.replace("（", "(").replace("）", ")")
    if "(" in normalized:
        normalized = normalized.split("(", 1)[0]
    normalized = normalized.replace(" ", "")
    return normalized.strip()


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as file_obj:
        return list(csv.DictReader(file_obj))


def write_rows(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(file_obj, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)


def load_cache(path: Path) -> dict[str, dict[str, Any]]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def save_cache(path: Path, cache: dict[str, dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True),
        encoding="utf-8",
    )


def build_session(insecure: bool) -> requests.Session:
    session = requests.Session()
    session.mount("https://", HTTPAdapter(max_retries=5))
    session.mount("http://", HTTPAdapter(max_retries=5))
    if insecure:
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    return session


def geocode_address(
    session: requests.Session,
    api_key: str,
    address: str,
    timeout: float,
    insecure: bool,
    accept_fuzzy: bool,
) -> dict[str, Any]:
    params = {
        "SERVICE": "KEYWORDSEARCH",
        "KEYWORD": address,
        "APIKEY": api_key,
        "ITEM_LIST": "TPGOS_CA_ADDR:30,TGOS_V2_ADDR,GMAPI_ADDR",
        "SRS_T": "WGS84",
    }
    response = session.get(TGOS_URL, params=params, timeout=timeout, verify=not insecure)
    response.raise_for_status()

    try:
        payload = response.json()
    except json.JSONDecodeError:
        text = response.text.strip()
        raise RuntimeError(f"TGOS returned non-JSON response: {text[:200]}")

    if not payload:
        return {"lng": "", "lat": "", "query_type": "NO_RESULT", "raw": payload}

    first = payload[0]
    query_type = normalize_text(str(first.get("QUERYTYPE", "")))
    if query_type == "完全比對" or accept_fuzzy:
        return {
            "lng": normalize_text(str(first.get("X", ""))),
            "lat": normalize_text(str(first.get("Y", ""))),
            "query_type": query_type or "UNKNOWN",
            "raw": first,
        }

    return {
        "lng": "",
        "lat": "",
        "query_type": query_type or "UNMATCHED",
        "raw": first,
    }


def main() -> None:
    args = parse_args()
    if not args.api_key:
        raise SystemExit("Missing TGOS API key. Pass --api-key or set TPGOS_API_KEY.")

    rows = load_rows(args.input)
    cache = load_cache(args.cache)
    session = build_session(args.insecure)

    updated = 0
    skipped = 0
    failed = 0

    for index, row in enumerate(rows, start=1):
        if normalize_text(row.get("lng")) and normalize_text(row.get("lat")):
            skipped += 1
            continue

        address = normalize_address(normalize_text(row.get("address")))
        if not address:
            failed += 1
            continue

        cached = cache.get(address)
        if cached is None:
            try:
                cached = geocode_address(
                    session=session,
                    api_key=args.api_key,
                    address=address,
                    timeout=args.timeout,
                    insecure=args.insecure,
                    accept_fuzzy=args.accept_fuzzy,
                )
            except Exception as exc:  # pragma: no cover - network defensive
                cached = {
                    "lng": "",
                    "lat": "",
                    "query_type": f"ERROR: {exc}",
                    "raw": {},
                }
            cache[address] = cached
            time.sleep(args.sleep_seconds)

        row["lng"] = normalize_text(str(cached.get("lng", "")))
        row["lat"] = normalize_text(str(cached.get("lat", "")))

        if row["lng"] and row["lat"]:
            updated += 1
        else:
            failed += 1

        if index % 50 == 0:
            save_cache(args.cache, cache)
            write_rows(args.output, rows)

    save_cache(args.cache, cache)
    write_rows(args.output, rows)

    print(
        "Geocoded New Taipei clinic CSV:",
        f"updated={updated}",
        f"skipped={skipped}",
        f"failed={failed}",
        f"output={args.output}",
        f"cache={args.cache}",
    )


if __name__ == "__main__":
    main()
