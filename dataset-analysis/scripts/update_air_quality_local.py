#!/usr/bin/env python3
"""Update local MOENV air-quality data for dashboard development.

This is a local developer runner. Production should move the same steps into
Taipei-City-Dashboard-DE as an Airflow DAG.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
FETCH_SCRIPT = PROJECT_ROOT / "dataset-analysis" / "scripts" / "build_moenv_air_quality_csv.py"
ASSET_SCRIPT = PROJECT_ROOT / "dataset-analysis" / "scripts" / "build_air_quality_assets.py"
AQI_ZONE_SCRIPT = PROJECT_ROOT / "dataset-analysis" / "scripts" / "build_air_quality_aqi_zones.mjs"
DATA_SQL = PROJECT_ROOT / "db-sample-data" / "dashboard-air-quality.sql"


def parse_args() -> tuple[argparse.Namespace, list[str]]:
    parser = argparse.ArgumentParser(
        description="Fetch MOENV air quality data and load it into the local dashboard DB.",
    )
    parser.add_argument("--data-container", default=os.getenv("DATA_CONTAINER", "postgres-data"))
    parser.add_argument("--data-db", default=os.getenv("DATA_DB", "dashboard"))
    parser.add_argument("--data-user", default=os.getenv("DATA_USER", "postgres"))
    return parser.parse_known_args()


def has_api_key(fetch_args: list[str]) -> bool:
    return (
        bool(os.getenv("MOENV_API_KEY"))
        or "--input-json" in fetch_args
        or "--api-key" in fetch_args
        or any(arg.startswith("--api-key=") for arg in fetch_args)
    )


def run(command: list[str]) -> None:
    subprocess.run(command, cwd=PROJECT_ROOT, check=True)


def main() -> int:
    args, fetch_args = parse_args()
    if not has_api_key(fetch_args):
        print(
            "Missing MOENV_API_KEY. Export it first, pass --api-key, "
            "or pass --input-json to use a local raw JSON file.",
            file=sys.stderr,
        )
        return 1

    run([sys.executable, str(FETCH_SCRIPT), *fetch_args])
    run([sys.executable, str(ASSET_SCRIPT)])
    run(["node", str(AQI_ZONE_SCRIPT)])
    run(["docker", "cp", str(DATA_SQL), f"{args.data_container}:/tmp/dashboard-air-quality.sql"])
    run([
        "docker",
        "exec",
        args.data_container,
        "psql",
        "-U",
        args.data_user,
        "-d",
        args.data_db,
        "-f",
        "/tmp/dashboard-air-quality.sql",
    ])
    print(f"Air quality data updated in {args.data_container}/{args.data_db}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
