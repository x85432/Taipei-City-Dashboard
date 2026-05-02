import argparse
import html
import json
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import quote_plus
from urllib.request import HTTPCookieProcessor, Request, build_opener


ROOT = Path(__file__).resolve().parents[1]
TAIPEI_TZ = timezone(timedelta(hours=8))
PAGE_URL = "https://ecolife2.moenv.gov.tw/BeachCleanup/Home/JoinCleanUp"
API_URL = "https://ecolife2.moenv.gov.tw/BeachCleanup/Data/GetSeaCleanEventNotExpired"
EVENT_URL = "https://ecolife2.moenv.gov.tw/Coastal/SeaCleanEvent/SeaCleanEventApply.aspx?EventID={event_id}"
OUTPUT_SQL = ROOT / "db-sample-data" / "dashboard-beach-cleanup-events.sql"

TARGET_CITIES = {"臺北市", "台北市", "新北市"}

DISTRICT_KEYWORDS = {
    "淡水": "淡水區",
    "沙崙": "淡水區",
    "翡翠灣": "萬里區",
    "萬里": "萬里區",
    "野柳": "萬里區",
    "金山": "金山區",
    "石門": "石門區",
    "三芝": "三芝區",
    "八里": "八里區",
    "林口": "林口區",
    "貢寮": "貢寮區",
    "福隆": "貢寮區",
    "龍洞": "貢寮區",
    "瑞芳": "瑞芳區",
    "深澳": "瑞芳區",
    "鼻頭": "瑞芳區",
}


def normalize_city(value):
    value = clean_text(value)
    return "臺北市" if value == "台北市" else value


def clean_text(value):
    if value is None:
        return ""
    value = html.unescape(str(value))
    return re.sub(r"\s+", " ", value).strip()


def sql_copy(value):
    value = clean_text(value)
    if value == "":
        return r"\N"
    return value.replace("\\", "\\\\").replace("\t", " ").replace("\n", " ")


def parse_iso_datetime(value):
    value = clean_text(value)
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def format_timestamp(value):
    parsed = parse_iso_datetime(value)
    if parsed is None:
        return r"\N"
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=TAIPEI_TZ)
    return parsed.strftime("%Y-%m-%d %H:%M:%S%z")


def infer_district(*values):
    text = " ".join(clean_text(v) for v in values)
    for keyword, district in DISTRICT_KEYWORDS.items():
        if keyword in text:
            return district
    match = re.search(r"(臺北市|台北市|新北市)([^市縣]{1,4}區)", text)
    if match:
        return match.group(2)
    return ""


def normalize_photo_url(value):
    value = clean_text(value)
    if not value:
        return ""
    if value.startswith("~"):
        return "https://ecolife2.moenv.gov.tw/Coastal" + value[1:]
    if value.startswith("/"):
        return "https://ecolife2.moenv.gov.tw" + value
    return value


def fetch_events():
    opener = build_opener(HTTPCookieProcessor())
    page = opener.open(Request(PAGE_URL, headers={"User-Agent": "Mozilla/5.0"}), timeout=30).read().decode("utf-8")
    token_match = re.search(r'name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"', page)
    if not token_match:
        raise RuntimeError("Cannot find __RequestVerificationToken from beach cleanup page.")

    body = f"__RequestVerificationToken={quote_plus(token_match.group(1))}".encode("utf-8")
    request = Request(
        API_URL,
        data=body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "User-Agent": "Mozilla/5.0",
            "X-Requested-With": "XMLHttpRequest",
            "Referer": PAGE_URL,
        },
        method="POST",
    )
    raw = opener.open(request, timeout=30).read().decode("utf-8-sig")
    return json.loads(raw)


def normalize_event(raw):
    city = normalize_city(raw.get("slcityname"))
    location = clean_text(raw.get("location"))
    rendezvous = clean_text(raw.get("rendezvous"))
    event_id = clean_text(raw.get("eventid"))
    return {
        "event_id": event_id,
        "city": city,
        "district": infer_district(location, rendezvous),
        "event_name": clean_text(raw.get("eventname")),
        "organizer": clean_text(raw.get("organizer")),
        "start_time": format_timestamp(raw.get("starttime")),
        "location": location,
        "rendezvous": rendezvous,
        "event_url": EVENT_URL.format(event_id=event_id) if event_id else "",
        "photo_url": normalize_photo_url(raw.get("photourl")),
    }


def generate_sql(events):
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S%z")
    rows = []
    for raw in events:
        city = normalize_city(raw.get("slcityname"))
        if city not in TARGET_CITIES:
            continue
        event = normalize_event(raw)
        if not event["event_id"] or not event["event_name"]:
            continue
        rows.append(event)

    rows.sort(key=lambda item: (item["start_time"], item["city"], item["event_name"]))

    lines = [
        "--",
        "-- Beach cleanup upcoming event data",
        "-- Source: https://ecolife2.moenv.gov.tw/BeachCleanup/Home/JoinCleanUp",
        f"-- Generated at: {generated_at}",
        "--",
        "",
        "CREATE TABLE IF NOT EXISTS public.beach_cleanup_events (",
        "    event_id text PRIMARY KEY,",
        "    city text,",
        "    district text,",
        "    event_name text,",
        "    organizer text,",
        "    start_time timestamp with time zone,",
        "    location text,",
        "    rendezvous text,",
        "    event_url text,",
        "    photo_url text,",
        "    scraped_at timestamp with time zone DEFAULT NOW()",
        ");",
        "",
        "TRUNCATE TABLE public.beach_cleanup_events;",
        "",
        "COPY public.beach_cleanup_events (event_id, city, district, event_name, organizer, start_time, location, rendezvous, event_url, photo_url, scraped_at) FROM stdin;",
    ]

    for row in rows:
        values = [
            row["event_id"],
            row["city"],
            row["district"],
            row["event_name"],
            row["organizer"],
            row["start_time"],
            row["location"],
            row["rendezvous"],
            row["event_url"],
            row["photo_url"],
            generated_at,
        ]
        lines.append("\t".join(sql_copy(value) for value in values))

    lines.extend(
        [
            r"\.",
            "",
            "CREATE INDEX IF NOT EXISTS beach_cleanup_events_city_start_time_idx",
            "ON public.beach_cleanup_events (city, start_time);",
            "",
        ]
    )
    return "\n".join(lines), len(rows)


def main():
    parser = argparse.ArgumentParser(description="Fetch MOENV beach cleanup events and generate dashboard SQL.")
    parser.add_argument("--offline-json", type=Path, help="Use an existing API JSON file instead of fetching from the website.")
    args = parser.parse_args()

    if args.offline_json:
        events = json.loads(args.offline_json.read_text(encoding="utf-8-sig"))
    else:
        events = fetch_events()

    sql, count = generate_sql(events)
    OUTPUT_SQL.write_text(sql, encoding="utf-8")
    print(f"Generated {OUTPUT_SQL} with {count} Taipei/New Taipei events.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Failed to generate beach cleanup events: {exc}", file=sys.stderr)
        raise
