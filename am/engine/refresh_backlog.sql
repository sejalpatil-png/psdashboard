SELECT COALESCE(json_agg(json_build_array(ag,bk,created_today_open,overdue_open) ORDER BY ag,bk)::text,'[]') rows FROM (
  SELECT ag, bk, COUNT(*) FILTER (WHERE fd = CURRENT_DATE) created_today_open, COUNT(*) FILTER (WHERE fd < CURRENT_DATE) overdue_open
  FROM (
    SELECT split_part(ihf.care_reachout__assigned_to,'@',1) ag, (ihf.created_at::timestamptz)::date fd,
      CASE WHEN ihf.care_reachout__reason='DAY_FIFTEEN' THEN 'Day 15' WHEN ihf.care_reachout__reason='DAY_SEVENTY_FIVE' THEN 'Day 75'
        WHEN ihf.care_reachout__reason='DAY_ONE_HUNDRED_FIFTY' THEN 'Day 150' WHEN ihf.care_reachout__reason='DAY_TWO_HUNDRED_TEN' THEN 'Day 210'
        WHEN ihf.care_reachout__reason='DAY_TWO_HUNDRED_SEVENTY' THEN 'Day 270' WHEN ihf.care_reachout__reason='OVERDUE_OPD_CLAIM' THEN 'OPD Reimbursement'
        WHEN ihf.care_reachout__reason LIKE 'BAD_CSAT%' THEN 'Bad CSAT' WHEN ihf.care_reachout__reason='ENGMT_INACTIVE_ACCOUNT' THEN 'Engagement (Inactive)' ELSE 'Other' END bk
    FROM public."individuals-health_forms" ihf
    WHERE ihf.type='POSTSALES_REACHOUT' AND ihf.is_draft=true AND ihf.care_reachout__assigned_to IS NOT NULL
  ) z WHERE bk<>'Other' GROUP BY ag,bk
) t;