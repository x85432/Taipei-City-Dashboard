#!/usr/bin/env python3
"""Filter all_clinic.csv down to only New Taipei rows."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


NEW_TAIPEI_CODE = "65000"
INPUT_ENCODINGS = ("utf-8-sig", "utf-8", "cp950", "big5")


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(
        description="Filter all_clinic.csv to only New Taipei clinic rows."
    )
    parser.add_argument(
        "--input",
        default=repo_root / "all_clinic.csv",
        type=Path,
        help="Path to the all_clinic CSV file.",
    )
    parser.add_argument(
        "--output",
        default=repo_root / "newtaipei_clinic.csv",
        type=Path,
        help="Path to the filtered UTF-8 CSV output file.",
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


def filter_rows(path: Path) -> tuple[list[dict[str, str]], list[str]]:
    reader = open_dict_reader(path)
    rows: list[dict[str, str]] = []
    try:
        fieldnames = reader.fieldnames or []
        for row in reader:
            if normalize_text(row.get("縣市別代碼")) != NEW_TAIPEI_CODE:
                continue
            rows.append({key: normalize_text(value) for key, value in row.items()})
    finally:
        reader.source_file.close()  # type: ignore[attr-defined]
    return rows, fieldnames


def write_output(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file_obj:
        writer = csv.DictWriter(file_obj, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    rows, fieldnames = filter_rows(args.input)
    write_output(args.output, rows, fieldnames)
    print(
        "Filtered New Taipei clinic CSV:",
        f"total={len(rows)}",
        f"output={args.output}",
    )


if __name__ == "__main__":
    main()
