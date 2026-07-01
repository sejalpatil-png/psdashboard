# Renewals dashboard — refresh runbook (every 30 min, app-open model)

Goal: re-pull renewal aggregates from Metabase DB13 and republish
https://sejalpatil-png.github.io/psdashboard/renewals/

Steps (do exactly, in order):

1. Clone fresh:
   rm -rf /tmp/rnw && git clone --depth 1 "https://$GH_TOKEN@github.com/sejalpatil-png/psdashboard.git" /tmp/rnw

2. Run the 4 SQL blocks in /tmp/rnw/renewals/engine/queries.sql against database_id 13
   using the Metabase `execute` tool (row_limit 500). For each result, take the
   returned `data` object (the {"0":{...},"1":{...}} map) and write it verbatim to:
     /tmp/rnw/renewals/engine/raw/funnel.json
     /tmp/rnw/renewals/engine/raw/leaderboard.json
     /tmp/rnw/renewals/engine/raw/cycle.json
     /tmp/rnw/renewals/engine/raw/watchlist.json
   (In watchlist rows, convert null reason to "".)

3. Build:  cd /tmp/rnw/renewals/engine && python3 build_data.py

4. Publish:
   cd /tmp/rnw && git add -A && \
   git -c user.email="sejal.patil@even.in" -c user.name="Sejal Patil" commit -q -m "refresh renewals dashboard" && \
   git pull --rebase origin main && git push origin HEAD

5. Report the [build] line and whether the push succeeded. If nothing changed,
   `git commit` will say "nothing to commit" — that's fine, skip the push.

Notes: uses the Metabase tool (works while the Claude/Cowork app is open).
Customer names/mobiles are intentionally excluded from the public page.
