#!/usr/bin/env python3
"""Merge normalized New Taipei clinic and hospital CSV files."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


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
        description="Merge normalized New Taipei clinic and hospital CSVs."
    )
    parser.add_argument(
        "--clinic",
        default=repo_root / "newtaipei_clinic_normalized.csv",
        type=Path,
        help="Path to the normalized New Taipei clinic CSV.",
    )
    parser.add_argument(
        "--hospital",
        default=repo_root / "newtaipei_medical.csv",
        type=Path,
        help="Path to the normalized New Taipei hospital CSV.",
    )
    parser.add_argument(
        "--output",
        default=repo_root / "newtaipei_medical_complete.csv",
        type=Path,
        help="Path to the merged UTF-8 CSV output file.",
    )
    return parser.parse_args()


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as file_obj:
        reader = csv.DictReader(file_obj)
        if reader.fieldnames != OUTPUT_COLUMNS:
            raise ValueError(f"Unexpected columns in {path}: {reader.fieldnames}")
        return list(reader)


def dedupe_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    seen: set[tuple[str, str, str]] = set()
    output: list[dict[str, str]] = []
    for row in rows:
        key = (row["category"], row["name"], row["address"])
        if key in seen:
            continue
        seen.add(key)
        output.append(row)
    return output


def write_rows(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(file_obj, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    clinic_rows = load_rows(args.clinic)
    hospital_rows = load_rows(args.hospital)
    merged_rows = dedupe_rows(clinic_rows + hospital_rows)
    write_rows(args.output, merged_rows)
    print(
        "Merged New Taipei medical CSVs:",
        f"clinic={len(clinic_rows)}",
        f"hospital={len(hospital_rows)}",
        f"total={len(merged_rows)}",
        f"output={args.output}",
    )


if __name__ == "__main__":
    main()
