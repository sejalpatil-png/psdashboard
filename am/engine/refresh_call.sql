WITH bs AS (
  SELECT ihf.uid form_uid, ihf.care_reachout__outcome outcome,
    (ihf.submitted_at::timestamptz)::date d, split_part(ihf.care_reachout__assigned_to,'@',1) ag,
    (COALESCE(ihf.care_reachout__day_seventy_five_form_info__booked_during_call,false)
      OR COALESCE(ihf.care_reachout__day_one_fifty_form_info__booked_during_call,false)
      OR COALESCE((ihf.care_reachout__day_fifteen_form_info->>'booked_during_call')::boolean,false)
      OR COALESCE((ihf.care_reachout__day_two_hundred_ten_form_info->>'booked_during_call')::boolean,false)
      OR COALESCE((ihf.care_reachout__day_two_hundred_seventy_form_info->>'booked_during_call')::boolean,false)
      OR NULLIF(ihf.care_reachout__day_seventy_five_form_info__booking_id,'') IS NOT NULL
      OR NULLIF(ihf.care_reachout__day_one_fifty_form_info__booking_id,'') IS NOT NULL
      OR NULLIF(ihf.care_reachout__day_fifteen_form_info->>'booking_id','') IS NOT NULL
      OR NULLIF(ihf.care_reachout__day_two_hundred_ten_form_info->>'booking_id','') IS NOT NULL
      OR NULLIF(ihf.care_reachout__day_two_hundred_seventy_form_info->>'booking_id','') IS NOT NULL
      OR ihf.care_reachout__day_seventy_five_form_info__hcu_booking='BOOK_ON_CALL'
      OR ihf.care_reachout__day_one_fifty_form_info__hcu_booking='BOOK_ON_CALL'
      OR ihf.care_reachout__day_fifteen_form_info->>'hcu_booking'='BOOK_ON_CALL'
      OR ihf.care_reachout__day_two_hundred_ten_form_info->>'hcu_booking'='BOOK_ON_CALL'
      OR ihf.care_reachout__day_two_hundred_seventy_form_info->>'hcu_booking'='BOOK_ON_CALL') in_call,
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
  WHERE ihf.type='POSTSALES_REACHOUT' AND ihf.is_draft=false AND ihf.care_reachout__assigned_to IS NOT NULL
    AND (ihf.submitted_at::timestamptz)::date >= date_trunc('month',CURRENT_DATE))
SELECT json_agg(json_build_array(d,ag,bk,calls,bookings,di,ddnp,dre,ddnd,dig,dww,dlb,dop,dno) ORDER BY d,ag,bk)::text rows FROM (
  SELECT to_char(d,'YYYY-MM-DD') d, ag, bucket bk, COUNT(DISTINCT form_uid) calls,
    COUNT(DISTINCT form_uid) FILTER (WHERE in_call) bookings,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome IN ('INTERESTED','INTERESTED_NSA')) di,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome IN ('DNP','DNP_REALLOCATE')) ddnp,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome='RESCHEDULED') dre,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome='DND') ddnd,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome='IGNORED') dig,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome='WAIT_AND_WATCH') dww,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome='LANGUAGE_BARRIER') dlb,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome IN ('OPEN_ND','OPEN_REIMBURSEMENT')) dop,
    COUNT(DISTINCT form_uid) FILTER (WHERE outcome IS NULL) dno
  FROM bs WHERE bucket<>'Other' GROUP BY 1,2,3) t;