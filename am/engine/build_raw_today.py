#!/usr/bin/env python3
# Merge TODAY's member-level raw rows into raw.json.
# Usage: build_raw_today.py <old_raw.json> <today_rows.json> <out_raw.json>
# Rows: [date_MMDD, agent, mobile, name, bucket, outcome, in_call, util]
# - drops any existing rows for today's MM-DD, appends the fresh ones
# - keeps a rolling window of the last 3 calendar months (bounds file size)
import sys, json
from datetime import datetime, timezone, timedelta

old_path, today_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

def load(p):
    try:
        with open(p) as f:
            d = json.load(f)
        return d if isinstance(d, list) else []
    except Exception:
        return []

old = load(old_path)
new = load(today_path)

# today's MM-DD: prefer the fresh rows; else use IST clock
ist = timezone(timedelta(hours=5, minutes=30))
today_mmdd = new[0][0] if new else datetime.now(ist).strftime('%m-%d')

# drop existing rows for today, then append fresh
kept = [r for r in old if r and r[0] != today_mmdd]
kept.extend(new)

# rolling 3-month window
m = datetime.now(ist).month
allowed = {((m - 1 - k) % 12) + 1 for k in range(3)}
kept = [r for r in kept if int(str(r[0])[:2]) in allowed]

with open(out_path, 'w') as f:
    json.dump(kept, f, separators=(',', ':'))

print(f"raw.json: {len(new)} rows for {today_mmdd}, total {len(kept)}")
