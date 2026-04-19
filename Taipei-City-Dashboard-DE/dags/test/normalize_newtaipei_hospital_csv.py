#!/usr/bin/env python3
"""Normalize New Taipei hospital CSV into the shared medical CSV schema."""

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

INPUT_ENCODINGS = ("utf-8-sig", "utf-8", "cp950", "big5")


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(
        description="Normalize New Taipei hospital CSV into the shared medical schema."
    )
    parser.add_argument(
        "--input",
        default=repo_root / "newtaipei_hospital.csv",
        type=Path,
        help="Path to the New Taipei hospital CSV file.",
    )
    parser.add_argument(
        "--output",
        default=repo_root / "newtaipei_medical_merged.csv",
        type=Path,
        help="Path to the normalized UTF-8 CSV output file.",
    )
    return parser.parse_args()


def open_dict_reader(path: Path) -> csv.DictReader:
    last_error: Exception | None = None
    for encoding in INPUT_ENCODINGS:
        try:
            file_obj = path.open("r", encoding=encoding, newline="")
            reader = csv.DictReader(file_obj)
            _ = reader.fieldnames
            if reader.fieldnames is None:
                file_obj.close()
                raise ValueError(f"No header row found in {path}")
            reader.source_file = file_obj  # type: ignore[attr-defined]
            return reader
        except Exception as exc:  # pragma: no cover - defensive
            last_error = exc
    raise RuntimeError(f"Failed to read {path} with supported encodings") from last_error


def normalize_text(value: str | None) -> str:
    if value is None:
        return ""
    return value.strip().replace("\t", "")


def write_output(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(file_obj, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)


def build_rows(path: Path) -> list[dict[str, str]]:
    reader = open_dict_reader(path)
    rows: list[dict[str, str]] = []
    try:
        for row in reader:
            rows.append(
                {
                    "city": "newtaipei",
                    "facility_type": "hospital",
                    "category": "醫院",
                    "name": normalize_text(row.get("hosp_name")),
                    "district_code": "",
                    "district": normalize_text(row.get("area")),
                    "address": normalize_text(row.get("hosp_addr")),
                    "lng": normalize_text(row.get("wgs84ax_longitude")),
                    "lat": normalize_text(row.get("wgs84ay_latitude")),
                    "source_dataset": "newtaipei_hospital",
                }
            )
    finally:
        reader.source_file.close()  # type: ignore[attr-defined]
    return rows


def main() -> None:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)

    rows = build_rows(input_path)
    write_output(output_path, rows)

    print(
        "Normalized New Taipei hospital CSV:",
        f"total={len(rows)}",
        f"output={output_path}",
    )


if __name__ == "__main__":
    main()
