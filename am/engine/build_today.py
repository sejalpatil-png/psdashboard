#!/usr/bin/env python3
# Usage: build_today.py <old_data.json> <today_rows.json> <out_data.json> [backlog_rows.json]
# today_rows: full 25-col rows (replaces today's slice, keeps prior days)
# backlog_rows (optional): [[ag,bk,created_today_open,overdue_open],...] -> stored in meta.open (live snapshot)
import json, sys, datetime

old_path, today_path, out_path = sys.argv[1:4]
backlog_path = sys.argv[4] if len(sys.argv) > 4 else None

old = json.load(open(old_path))
old_rows = old.get("rows", [])
today = json.load(open(today_path))
if not isinstance(today, list): today = []

today_str = today[0][0] if today else None
rows = [r for r in old_rows if r[0] != today_str] + today
rows = sorted(rows, key=lambda x: (x[0], x[1], x[2]))

open_snap = old.get("meta", {}).get("open", [])
if backlog_path:
    try:
        b = json.load(open(backlog_path))
        if isinstance(b, list): open_snap = b
    except Exception:
        pass

ist = datetime.timezone(datetime.timedelta(hours=5, minutes=30))
meta = {"refreshed_at": datetime.datetime.now(ist).strftime("%d %b %Y, %I:%M %p IST"),
        "min_date": min(r[0] for r in rows), "max_date": max(r[0] for r in rows),
        "n_rows": len(rows), "open": open_snap}
json.dump({"meta": meta, "rows": rows}, open(out_path, "w"), separators=(",", ":"))
print("refreshed", today_str, "| rows", len(rows), "| open buckets", len(open_snap), "|", meta["refreshed_at"])
