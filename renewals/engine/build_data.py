#!/usr/bin/env python3
"""Build renewals dashboard data.json from raw Metabase query dumps."""
import json, os, datetime
HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(HERE, "..", "data.json")
CHANNELS = ["ONLINE", "CLINIC", "OFFLINE"]
def load(name):
    with open(os.path.join(RAW, name + ".json")) as f:
        d = json.load(f)
    if isinstance(d, dict) and "data" in d and isinstance(d["data"], dict):
        d = d["data"]
    return [d[k] for k in sorted(d, key=lambda x: int(x))]
def num(x): return 0 if x is None else x
def pct(n, d): return round(100.0 * n / d, 1) if d else 0
# FUNNEL
FK = ["not_in_window","outreach","grace_early","grace_late","overdue","renewed","total","rupees_in_window","rupees_overdue","rupees_renewed"]
funnel = {}
for r in load("funnel"):
    funnel[r["channel"]] = {k: num(r.get(k)) for k in FK}
funnel["ALL"] = {k: sum(funnel[c][k] for c in CHANNELS if c in funnel) for k in FK}
# LEADERBOARD
LK = ["total_accts","renewed","outreach","grace","overdue","rupees_renewed","rupees_overdue","rupees_in_window"]
lb = {c: [] for c in CHANNELS}; allmap = {}
for r in load("leaderboard"):
    ch, owner = r["channel"], r["owner"]
    rec = {"owner": owner}
    for k in LK: rec[k] = num(r.get(k))
    rec["renewal_pct"] = pct(rec["renewed"], rec["total_accts"])
    lb.setdefault(ch, []).append(rec)
    a = allmap.setdefault(owner, {"owner": owner, **{k: 0 for k in LK}})
    for k in LK: a[k] += rec[k]
for a in allmap.values(): a["renewal_pct"] = pct(a["renewed"], a["total_accts"])
lb["ALL"] = sorted(allmap.values(), key=lambda x: -x["total_accts"])
for c in CHANNELS: lb[c] = sorted(lb.get(c, []), key=lambda x: -x["total_accts"])
# CYCLE
cy = {c: [] for c in CHANNELS}; allcy = {}
for r in load("cycle"):
    ch = r["channel"]; cyc = r["cycle"]
    rec = {"cycle": cyc, "total": num(r.get("total")), "renewed": num(r.get("renewed")), "old_premium": num(r.get("old_premium")), "renewed_amt": num(r.get("renewed_amt"))}
    rec["acct_ret_pct"] = pct(rec["renewed"], rec["total"]); rec["rev_ret_pct"] = pct(rec["renewed_amt"], rec["old_premium"])
    cy.setdefault(ch, []).append(rec)
    a = allcy.setdefault(cyc, {"cycle": cyc, "total": 0, "renewed": 0, "old_premium": 0, "renewed_amt": 0})
    for k in ["total","renewed","old_premium","renewed_amt"]: a[k] += rec[k]
for a in allcy.values():
    a["acct_ret_pct"] = pct(a["renewed"], a["total"]); a["rev_ret_pct"] = pct(a["renewed_amt"], a["old_premium"])
cy["ALL"] = sorted(allcy.values(), key=lambda x: x["cycle"])
for c in CHANNELS: cy[c] = sorted(cy.get(c, []), key=lambda x: x["cycle"])
# WATCHLIST
wl = {c: [] for c in CHANNELS}; wl_all = []
for r in load("watchlist"):
    rec = {"owner": r["owner"], "account_uid": r["account_uid"], "channel": r["channel"], "cycle": r["cycle"], "days_overdue": num(r.get("days_overdue")), "old_premium": num(r.get("old_premium")), "reason": r.get("reason") or ""}
    wl.setdefault(rec["channel"], []).append(rec); wl_all.append(rec)
wl["ALL"] = sorted(wl_all, key=lambda x: -x["old_premium"])
for c in CHANNELS: wl[c] = sorted(wl.get(c, []), key=lambda x: -x["old_premium"])
out = {"generated": datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC"), "channels": ["ALL"] + CHANNELS, "funnel": funnel, "leaderboard": lb, "cycle": cy, "watchlist": wl}
with open(OUT, "w") as f: json.dump(out, f, separators=(",", ":"))
print("[build] data.json written. owners:", {c: len(lb[c]) for c in out["channels"]})
