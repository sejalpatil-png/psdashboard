WITH bc AS (
  SELECT ihf.uid form_uid, dmf.account_uid, split_part(ihf.care_reachout__assigned_to,'@',1) ag, ihf.is_draft,
    to_char((ihf.created_at::timestamptz)::date,'YYYY-MM-DD') d,
    CASE WHEN ihf.care_reachout__reason='DAY_FIFTEEN' THEN 'Day 15' WHEN ihf.care_reachout__reason='DAY_SEVENTY_FIVE' THEN 'Day 75'
      WHEN ihf.care_reachout__reason='DAY_ONE_HUNDRED_FIFTY' THEN 'Day 150' WHEN ihf.care_reachout__reason='DAY_TWO_HUNDRED_TEN' THEN 'Day 210'
      WHEN ihf.care_reachout__reason='DAY_TWO_HUNDRED_SEVENTY' THEN 'Day 270' WHEN ihf.care_reachout__reason='OVERDUE_OPD_CLAIM' THEN 'OPD Reimbursement'
      WHEN ihf.care_reachout__reason LIKE 'BAD_CSAT%' THEN 'Bad CSAT' WHEN ihf.care_reachout__reason='ENGMT_INACTIVE_ACCOUNT' THEN 'Engagement (Inactive)' ELSE 'Other' END bucket
  FROM public."individuals-health_forms" ihf
  LEFT JOIN public.dpipe_member_flat dmf ON dmf.individual_uid=ihf._parent_doc_id
  WHERE ihf.type='POSTSALES_REACHOUT' AND ihf.care_reachout__assigned_to IS NOT NULL
    AND (ihf.created_at::timestamptz)::date = CURRENT_DATE),
aggc AS (SELECT d,ag,bucket bk, COUNT(DISTINCT account_uid) accts, COUNT(DISTINCT form_uid) FILTER (WHERE is_draft) pending, COUNT(DISTINCT form_uid) forms FROM bc WHERE bucket<>'Other' GROUP BY 1,2,3),
bs AS (
  SELECT ihf.uid form_uid, ihf.care_reachout__outcome outcome, to_char((ihf.submitted_at::timestamptz)::date,'YYYY-MM-DD') d, split_part(ihf.care_reachout__assigned_to,'@',1) ag,
    (COALESCE(ihf.care_reachout__day_seventy_five_form_info__booked_during_call,false) OR COALESCE(ihf.care_reachout__day_one_fifty_form_info__booked_during_call,false)
      OR COALESCE((ihf.care_reachout__day_fifteen_form_info->>'booked_during_call')::boolean,false) OR COALESCE((ihf.care_reachout__day_two_hundred_ten_form_info->>'booked_during_call')::boolean,false)
      OR COALESCE((ihf.care_reachout__day_two_hundred_seventy_form_info->>'booked_during_call')::boolean,false)
      OR NULLIF(ihf.care_reachout__day_seventy_five_form_info__booking_id,'') IS NOT NULL OR NULLIF(ihf.care_reachout__day_one_fifty_form_info__booking_id,'') IS NOT NULL
      OR NULLIF(ihf.care_reachout__day_fifteen_form_info->>'booking_id','') IS NOT NULL OR NULLIF(ihf.care_reachout__day_two_hundred_ten_form_info->>'booking_id','') IS NOT NULL
      OR NULLIF(ihf.care_reachout__day_two_hundred_seventy_form_info->>'booking_id','') IS NOT NULL
      OR ihf.care_reachout__day_seventy_five_form_info__hcu_booking='BOOK_ON_CALL' OR ihf.care_reachout__day_one_fifty_form_info__hcu_booking='BOOK_ON_CALL'
      OR ihf.care_reachout__day_fifteen_form_info->>'hcu_booking'='BOOK_ON_CALL' OR ihf.care_reachout__day_two_hundred_ten_form_info->>'hcu_booking'='BOOK_ON_CALL'
      OR ihf.care_reachout__day_two_hundred_seventy_form_info->>'hcu_booking'='BOOK_ON_CALL') in_call,
    CASE WHEN ihf.care_reachout__reason='DAY_FIFTEEN' THEN 'Day 15' WHEN ihf.care_reachout__reason='DAY_SEVENTY_FIVE' THEN 'Day 75'
      WHEN ihf.care_reachout__reason='DAY_ONE_HUNDRED_FIFTY' THEN 'Day 150' WHEN ihf.care_reachout__reason='DAY_TWO_HUNDRED_TEN' THEN 'Day 210'
      WHEN ihf.care_reachout__reason='DAY_TWO_HUNDRED_SEVENTY' THEN 'Day 270' WHEN ihf.care_reachout__reason='OVERDUE_OPD_CLAIM' THEN 'OPD Reimbursement'
      WHEN ihf.care_reachout__reason LIKE 'BAD_CSAT%' THEN 'Bad CSAT' WHEN ihf.care_reachout__reason='ENGMT_INACTIVE_ACCOUNT' THEN 'Engagement (Inactive)' ELSE 'Other' END bucket
  FROM public."individuals-health_forms" ihf
  WHERE ihf.type='POSTSALES_REACHOUT' AND ihf.is_draft=false AND ihf.care_reachout__assigned_to IS NOT NULL
    AND (ihf.submitted_at::timestamptz)::date = CURRENT_DATE),
aggs AS (SELECT d,ag,bucket bk, COUNT(DISTINCT form_uid) calls, COUNT(DISTINCT form_uid) FILTER (WHERE in_call) bookings,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome IN ('INTERESTED','INTERESTED_NSA')) di, COUNT(DISTINCT form_uid) FILTER (WHERE outcome IN ('DNP','DNP_REALLOCATE')) ddnp,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome='RESCHEDULED') dre, COUNT(DISTINCT form_uid) FILTER (WHERE outcome='DND') ddnd,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome='IGNORED') dig, COUNT(DISTINCT form_uid) FILTER (WHERE outcome='WAIT_AND_WATCH') dww,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome='LANGUAGE_BARRIER') dlb, COUNT(DISTINCT form_uid) FILTER (WHERE outcome IN ('OPEN_ND','OPEN_REIMBURSEMENT')) dop,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome IS NULL) dno FROM bs WHERE bucket<>'Other' GROUP BY 1,2,3)
SELECT COALESCE(json_agg(json_build_array(COALESCE(c.d,s.d),COALESCE(c.ag,s.ag),COALESCE(c.bk,s.bk),
  COALESCE(c.accts,0),COALESCE(c.pending,0),COALESCE(c.forms,0),COALESCE(s.calls,0),COALESCE(s.bookings,0),
  COALESCE(s.di,0),COALESCE(s.ddnp,0),COALESCE(s.dre,0),COALESCE(s.ddnd,0),COALESCE(s.dig,0),COALESCE(s.dww,0),COALESCE(s.dlb,0),COALESCE(s.dop,0),COALESCE(s.dno,0)) ORDER BY 1,2,3)::text,'[]') rows
FROM aggc c FULL OUTER JOIN aggs s ON c.d=s.d AND c.ag=s.ag AND c.bk=s.bk;