#!/usr/bin/env python3
# Usage: build_today.py <old_data.json> <today_rows.json> <out_data.json>
# today_rows are full 25-col rows (same schema as data.json rows). Replaces today's slice, keeps all prior days.
import json, sys, datetime

old_path, today_path, out_path = sys.argv[1:4]
old = json.load(open(old_path)).get("rows", [])
today = json.load(open(today_path))
if not isinstance(today, list):
    today = []

today_str = today[0][0] if today else None
rows = [r for r in old if r[0] != today_str] + today
rows = sorted(rows, key=lambda x: (x[0], x[1], x[2]))
ist = datetime.timezone(datetime.timedelta(hours=5, minutes=30))
meta = {"refreshed_at": datetime.datetime.now(ist).strftime("%d %b %Y, %I:%M %p IST"),
        "min_date": min(r[0] for r in rows), "max_date": max(r[0] for r in rows), "n_rows": len(rows)}
json.dump({"meta": meta, "rows": rows}, open(out_path, "w"), separators=(",", ":"))
print("refreshed", today_str, "| rows", len(rows), "|", meta["refreshed_at"])
