-- Renewals dashboard source queries (Metabase DB13). T = current_policy_end.
-- Run each via the Metabase tool, save the result 'data' object to raw/<name>.json, then: python3 build_data.py

-- ===== raw/funnel.json =====
WITH b AS (SELECT r.channel,r.is_renewed,r.year,(r.current_policy_end::date-CURRENT_DATE) d,COALESCE(r.current_policy_amount,0)::numeric oldp,COALESCE(r.renewed_amount,0)::numeric renp FROM public.dpipe_retention r WHERE r.year BETWEEN 1 AND 4 AND r.channel IN ('ONLINE','CLINIC','OFFLINE'))
SELECT channel,
 COUNT(*) FILTER (WHERE NOT is_renewed AND d>15) not_in_window,
 COUNT(*) FILTER (WHERE NOT is_renewed AND d BETWEEN 1 AND 15) outreach,
 COUNT(*) FILTER (WHERE NOT is_renewed AND d BETWEEN -15 AND 0) grace_early,
 COUNT(*) FILTER (WHERE NOT is_renewed AND d BETWEEN -30 AND -16) grace_late,
 COUNT(*) FILTER (WHERE NOT is_renewed AND d < -30) overdue,
 COUNT(*) FILTER (WHERE is_renewed) renewed, COUNT(*) total,
 ROUND(SUM(oldp) FILTER (WHERE NOT is_renewed AND d BETWEEN -30 AND 15)) rupees_in_window,
 ROUND(SUM(oldp) FILTER (WHERE NOT is_renewed AND d < -30)) rupees_overdue,
 ROUND(SUM(renp) FILTER (WHERE is_renewed)) rupees_renewed
FROM b GROUP BY channel ORDER BY channel;

-- ===== raw/leaderboard.json =====
WITH b AS (SELECT r.channel,CASE WHEN COALESCE(r.renewal_deal_owner,'')='' THEN 'Unassigned' ELSE r.renewal_deal_owner END owner,r.is_renewed,(r.current_policy_end::date-CURRENT_DATE) d,COALESCE(r.current_policy_amount,0)::numeric oldp,COALESCE(r.renewed_amount,0)::numeric renp FROM public.dpipe_retention r WHERE r.year BETWEEN 1 AND 4 AND r.channel IN ('ONLINE','CLINIC','OFFLINE'))
SELECT channel,owner,COUNT(*) total_accts,COUNT(*) FILTER (WHERE is_renewed) renewed,
 COUNT(*) FILTER (WHERE NOT is_renewed AND d BETWEEN 1 AND 15) outreach,
 COUNT(*) FILTER (WHERE NOT is_renewed AND d BETWEEN -30 AND 0) grace,
 COUNT(*) FILTER (WHERE NOT is_renewed AND d < -30) overdue,
 ROUND(SUM(renp) FILTER (WHERE is_renewed)) rupees_renewed,
 ROUND(SUM(oldp) FILTER (WHERE NOT is_renewed AND d < -30)) rupees_overdue,
 ROUND(SUM(oldp) FILTER (WHERE NOT is_renewed AND d BETWEEN -30 AND 15)) rupees_in_window
FROM b GROUP BY channel,owner
HAVING COUNT(*) FILTER (WHERE NOT is_renewed AND d BETWEEN -30 AND 15)>0 OR COUNT(*) FILTER (WHERE is_renewed)>0
ORDER BY channel,total_accts DESC;

-- ===== raw/cycle.json =====
WITH b AS (SELECT r.channel,r.year,r.is_renewed,COALESCE(r.current_policy_amount,0)::numeric oldp,COALESCE(r.renewed_amount,0)::numeric renp FROM public.dpipe_retention r WHERE r.year BETWEEN 1 AND 4 AND r.channel IN ('ONLINE','CLINIC','OFFLINE'))
SELECT channel,year cycle,COUNT(*) total,COUNT(*) FILTER (WHERE is_renewed) renewed,ROUND(SUM(oldp)) old_premium,ROUND(SUM(renp)) renewed_amt FROM b GROUP BY channel,year ORDER BY channel,year;

-- ===== raw/watchlist.json =====
SELECT r.channel,CASE WHEN COALESCE(r.renewal_deal_owner,'')='' THEN 'Unassigned' ELSE r.renewal_deal_owner END owner,r.account_uid,r.year cycle,(CURRENT_DATE-r.current_policy_end::date) days_overdue,ROUND(COALESCE(r.current_policy_amount,0)::numeric) old_premium,NULLIF(r.reason_for_not_renewing,'') reason
FROM public.dpipe_retention r WHERE r.year BETWEEN 1 AND 4 AND r.channel IN ('ONLINE','CLINIC','OFFLINE') AND NOT r.is_renewed AND (r.current_policy_end::date-CURRENT_DATE)<-30
ORDER BY old_premium DESC LIMIT 250;
