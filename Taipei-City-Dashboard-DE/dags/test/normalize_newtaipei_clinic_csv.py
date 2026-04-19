#!/usr/bin/env python3
"""Normalize filtered New Taipei clinic CSV into the shared medical schema."""

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
EXCLUDED_FACILITY_TYPES = {"醫院", "精神科醫院", "病理中心"}
NEW_TAIPEI_DISTRICTS = [
    "板橋區",
    "三重區",
    "中和區",
    "永和區",
    "新莊區",
    "新店區",
    "樹林區",
    "鶯歌區",
    "三峽區",
    "淡水區",
    "汐止區",
    "瑞芳區",
    "土城區",
    "蘆洲區",
    "五股區",
    "泰山區",
    "林口區",
    "深坑區",
    "石碇區",
    "坪林區",
    "三芝區",
    "石門區",
    "八里區",
    "平溪區",
    "雙溪區",
    "貢寮區",
    "金山區",
    "萬里區",
    "烏來區",
]


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(
        description="Normalize New Taipei clinic CSV into the shared medical schema."
    )
    parser.add_argument(
        "--input",
        default=repo_root / "newtaipei_clinic.csv",
        type=Path,
        help="Path to the filtered New Taipei clinic CSV file.",
    )
    parser.add_argument(
        "--output",
        default=repo_root / "newtaipei_clinic_normalized.csv",
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


def extract_district(address: str) -> str:
    for district in NEW_TAIPEI_DISTRICTS:
        if district in address:
            return district
    return ""


def build_rows(path: Path) -> list[dict[str, str]]:
    reader = open_dict_reader(path)
    rows: list[dict[str, str]] = []
    try:
        for row in reader:
            facility_kind = normalize_text(row.get("醫事機構種類"))
            if facility_kind in EXCLUDED_FACILITY_TYPES:
                continue
            address = normalize_text(row.get("地址"))
            rows.append(
                {
                    "city": "newtaipei",
                    "facility_type": "clinic",
                    "category": "診所",
                    "name": normalize_text(row.get("醫事機構名稱")),
                    "district_code": "",
                    "district": extract_district(address),
                    "address": address,
                    "lng": "",
                    "lat": "",
                    "source_dataset": "newtaipei_clinic",
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
    rows = build_rows(args.input)
    write_output(args.output, rows)
    print(
        "Normalized New Taipei clinic CSV:",
        f"total={len(rows)}",
        f"output={args.output}",
    )


if __name__ == "__main__":
    main()
