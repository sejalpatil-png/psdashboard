WITH bc AS (
  SELECT ihf.uid form_uid, dmf.account_uid, split_part(ihf.care_reachout__assigned_to,'@',1) ag, ihf.is_draft,
    to_char((ihf.created_at::timestamptz)::date,'YYYY-MM-DD') d,
    CASE WHEN ihf.care_reachout__reason='DAY_FIFTEEN' THEN 'Day 15'
      WHEN ihf.care_reachout__reason='DAY_SEVENTY_FIVE' THEN 'Day 75'
      WHEN ihf.care_reachout__reason='DAY_ONE_HUNDRED_FIFTY' THEN 'Day 150'
      WHEN ihf.care_reachout__reason='DAY_TWO_HUNDRED_TEN' THEN 'Day 210'
      WHEN ihf.care_reachout__reason='DAY_TWO_HUNDRED_SEVENTY' THEN 'Day 270'
      WHEN ihf.care_reachout__reason='OVERDUE_OPD_CLAIM' THEN 'OPD Reimbursement'
      WHEN ihf.care_reachout__reason LIKE 'BAD_CSAT%' THEN 'Bad CSAT'
      WHEN ihf.care_reachout__reason='ENGMT_INACTIVE_ACCOUNT' THEN 'Engagement (Inactive)'
      ELSE 'Other' END bucket
  FROM public."individuals-health_forms" ihf
  LEFT JOIN public.dpipe_member_flat dmf ON dmf.individual_uid=ihf._parent_doc_id
  WHERE ihf.type='POSTSALES_REACHOUT' AND ihf.care_reachout__assigned_to IS NOT NULL
    AND (ihf.created_at::timestamptz)::date >= date_trunc('month',CURRENT_DATE))
SELECT json_agg(json_build_array(d,ag,bk,accts,pending,forms) ORDER BY d,ag,bk)::text rows FROM (
  SELECT d, ag, bucket bk, COUNT(DISTINCT account_uid) accts,
    COUNT(DISTINCT form_uid) FILTER (WHERE is_draft) pending, COUNT(DISTINCT form_uid) forms
  FROM bc WHERE bucket<>'Other' GROUP BY 1,2,3) t;