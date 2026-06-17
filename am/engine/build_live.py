#!/usr/bin/env python3
# Usage: build_live.py <old_data.json> <created_rows.json> <call_rows.json> <out_data.json>
# created row: [d,ag,bk, accts,pending,forms]
# call row:    [d,ag,bk, calls,bookings, di,ddnp,dre,ddnd,dig,dww,dlb,dop,dno]
# output row (25): [d,ag,bk, accts,pending,forms,calls,bookings,
#   u_tele,u_scan,u_tests,u_visit,u_opd,u_ipd,u_other,u_any,  (carried from old data.json)
#   di,ddnp,dre,ddnd,dig,dww,dlb,dop,dno]
import json, sys, datetime

old_path, created_path, call_path, out_path = sys.argv[1:5]

def load_rows(p):
    try:
        x = json.load(open(p))
        return x if isinstance(x, list) else []
    except Exception:
        return []

# old data.json -> carry-forward services-availed (u_* = idx 8..15)
old = {}
try:
    od = json.load(open(old_path))
    for r in od.get("rows", []):
        old[(r[0], r[1], r[2])] = r[8:16]
except Exception:
    pass

M = {}
def row(k):
    if k not in M:
        M[k] = [k[0], k[1], k[2]] + [0]*22
    return M[k]

for r in load_rows(created_path):
    o = row((r[0], r[1], r[2]))
    o[3], o[4], o[5] = r[3], r[4], r[5]      # accts, pending, forms

for r in load_rows(call_path):
    o = row((r[0], r[1], r[2]))
    o[6], o[7] = r[3], r[4]                   # calls, bookings
    o[16:25] = r[5:14]                        # 9 dispositions

# carry services-availed
for k, o in M.items():
    if k in old:
        o[8:16] = list(old[k])

rows = sorted(M.values(), key=lambda x: (x[0], x[1], x[2]))
ist = datetime.timezone(datetime.timedelta(hours=5, minutes=30))
meta = {"refreshed_at": datetime.datetime.now(ist).strftime("%d %b %Y, %I:%M %p IST"),
        "min_date": min(r[0] for r in rows), "max_date": max(r[0] for r in rows), "n_rows": len(rows)}
json.dump({"meta": meta, "rows": rows}, open(out_path, "w"), separators=(",", ":"))
print("live rows", len(rows), "max", meta["max_date"], "|", meta["refreshed_at"])
