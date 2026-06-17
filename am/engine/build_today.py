#!/usr/bin/env python3
# Usage: build_today.py <old_data.json> <today_rows.json> <out_data.json>
# today row (17): [d,ag,bk, accts,pending,forms,calls,bookings, di,ddnp,dre,ddnd,dig,dww,dlb,dop,dno]
# output row (25): [d,ag,bk, accts,pending,forms,calls,bookings,
#   u_tele,u_scan,u_tests,u_visit,u_opd,u_ipd,u_other,u_any, di..dno]
import json, sys, datetime

old_path, today_path, out_path = sys.argv[1:4]
old = json.load(open(old_path))
old_rows = old.get("rows", [])
today = json.load(open(today_path))
if not isinstance(today, list):
    today = []

# carry-forward services-availed (u_* idx 8..15) keyed by (d,ag,bk)
u_old = {(r[0], r[1], r[2]): r[8:16] for r in old_rows}

today_str = today[0][0] if today else None
# keep all historical rows except today's (today gets replaced)
rows = [r for r in old_rows if r[0] != today_str]
for t in today:
    k = (t[0], t[1], t[2])
    u = list(u_old.get(k, [0]*8))
    rows.append(t[0:8] + u + t[8:17])

rows = sorted(rows, key=lambda x: (x[0], x[1], x[2]))
ist = datetime.timezone(datetime.timedelta(hours=5, minutes=30))
meta = {"refreshed_at": datetime.datetime.now(ist).strftime("%d %b %Y, %I:%M %p IST"),
        "min_date": min(r[0] for r in rows), "max_date": max(r[0] for r in rows), "n_rows": len(rows)}
json.dump({"meta": meta, "rows": rows}, open(out_path, "w"), separators=(",", ":"))
print("refreshed", today_str, "| rows", len(rows), "|", meta["refreshed_at"])
