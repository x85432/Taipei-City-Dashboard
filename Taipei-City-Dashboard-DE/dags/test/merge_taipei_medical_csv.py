#!/usr/bin/env python3
"""Merge Taipei clinic and hospital CSV files into one normalized CSV.

Usage:
    python merge_taipei_medical_csv.py
    python merge_taipei_medical_csv.py \
        --clinic /path/to/taipei_clinic.csv \
        --hospital /path/to/taipei_hospital.csv \
        --output /path/to/taipei_medical_merged.csv
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


TAIPEI_DISTRICT_CODE_MAP = {
    "63000010": "松山區",
    "63000020": "信義區",
    "63000030": "大安區",
    "63000040": "中山區",
    "63000050": "中正區",
    "63000060": "大同區",
    "63000070": "萬華區",
    "63000080": "文山區",
    "63000090": "南港區",
    "63000100": "內湖區",
    "63000110": "士林區",
    "63000120": "北投區",
}

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

INPUT_ENCODINGS = ("cp950", "big5", "utf-8-sig", "utf-8")


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(
        description="Merge Taipei clinic and hospital CSVs into a normalized CSV."
    )
    parser.add_argument(
        "--clinic",
        default=repo_root / "taipei_clinic.csv",
        type=Path,
        help="Path to the Taipei clinic CSV file.",
    )
    parser.add_argument(
        "--hospital",
        default=repo_root / "taipei_hospital.csv",
        type=Path,
        help="Path to the Taipei hospital CSV file.",
    )
    parser.add_argument(
        "--output",
        default=repo_root / "taipei_medical_merged.csv",
        type=Path,
        help="Path to the merged UTF-8 CSV output file.",
    )
    return parser.parse_args()


def open_dict_reader(path: Path) -> csv.DictReader:
    last_error: Exception | None = None
    for encoding in INPUT_ENCODINGS:
        try:
            file_obj = path.open("r", encoding=encoding, newline="")
            reader = csv.DictReader(file_obj)
            # Force one fieldnames read to validate encoding.
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


def normalize_number(value: str | None) -> str:
    return normalize_text(value)


def district_name_from_code(code: str) -> str:
    return TAIPEI_DISTRICT_CODE_MAP.get(code, "")


def build_clinic_rows(path: Path) -> list[dict[str, str]]:
    reader = open_dict_reader(path)
    rows: list[dict[str, str]] = []
    try:
        for row in reader:
            district_code = normalize_text(row.get("行政區"))
            rows.append(
                {
                    "city": "taipei",
                    "facility_type": "clinic",
                    "category": normalize_text(row.get("分類")) or "診所",
                    "name": normalize_text(row.get("機構名稱")),
                    "district_code": district_code,
                    "district": district_name_from_code(district_code),
                    "address": normalize_text(row.get("地址")),
                    "lng": normalize_number(row.get("經度")),
                    "lat": normalize_number(row.get("緯度")),
                    "source_dataset": "taipei_clinic",
                }
            )
    finally:
        reader.source_file.close()  # type: ignore[attr-defined]
    return rows


def build_hospital_rows(path: Path) -> list[dict[str, str]]:
    reader = open_dict_reader(path)
    rows: list[dict[str, str]] = []
    try:
        for row in reader:
            district_code = normalize_text(row.get("行政區域代碼"))
            rows.append(
                {
                    "city": "taipei",
                    "facility_type": "hospital",
                    "category": "醫院",
                    "name": normalize_text(row.get("機構名稱")),
                    "district_code": district_code,
                    "district": district_name_from_code(district_code),
                    "address": normalize_text(row.get("地址")),
                    "lng": normalize_number(row.get("經度")),
                    "lat": normalize_number(row.get("緯度")),
                    "source_dataset": "taipei_hospital",
                }
            )
    finally:
        reader.source_file.close()  # type: ignore[attr-defined]
    return rows


def write_output(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(file_obj, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    clinic_path = Path(args.clinic)
    hospital_path = Path(args.hospital)
    output_path = Path(args.output)

    clinic_rows = build_clinic_rows(clinic_path)
    hospital_rows = build_hospital_rows(hospital_path)
    merged_rows = clinic_rows + hospital_rows

    write_output(output_path, merged_rows)

    print(
        "Merged Taipei medical CSVs:",
        f"clinic={len(clinic_rows)}",
        f"hospital={len(hospital_rows)}",
        f"total={len(merged_rows)}",
        f"output={output_path}",
    )


if __name__ == "__main__":
    main()
