WITH bs AS (
  SELECT ihf.uid form_uid, dmf.account_uid, dmf.mobile, dmf.full_name nm, split_part(ihf.care_reachout__assigned_to,'@',1) ag,
    to_char((ihf.submitted_at::timestamptz)::date,'MM-DD') d, ihf.care_reachout__outcome outcome,
    (COALESCE(ihf.care_reachout__day_seventy_five_form_info__booked_during_call,false) OR COALESCE(ihf.care_reachout__day_one_fifty_form_info__booked_during_call,false)
      OR COALESCE((ihf.care_reachout__day_fifteen_form_info->>'booked_during_call')::boolean,false) OR COALESCE((ihf.care_reachout__day_two_hundred_ten_form_info->>'booked_during_call')::boolean,false)
      OR COALESCE((ihf.care_reachout__day_two_hundred_seventy_form_info->>'booked_during_call')::boolean,false)
      OR NULLIF(ihf.care_reachout__day_seventy_five_form_info__booking_id,'') IS NOT NULL OR NULLIF(ihf.care_reachout__day_one_fifty_form_info__booking_id,'') IS NOT NULL
      OR NULLIF(ihf.care_reachout__day_fifteen_form_info->>'booking_id','') IS NOT NULL OR NULLIF(ihf.care_reachout__day_two_hundred_ten_form_info->>'booking_id','') IS NOT NULL
      OR NULLIF(ihf.care_reachout__day_two_hundred_seventy_form_info->>'booking_id','') IS NOT NULL
      OR ihf.care_reachout__day_seventy_five_form_info__hcu_booking='BOOK_ON_CALL' OR ihf.care_reachout__day_one_fifty_form_info__hcu_booking='BOOK_ON_CALL'
      OR ihf.care_reachout__day_fifteen_form_info->>'hcu_booking'='BOOK_ON_CALL' OR ihf.care_reachout__day_two_hundred_ten_form_info->>'hcu_booking'='BOOK_ON_CALL'
      OR ihf.care_reachout__day_two_hundred_seventy_form_info->>'hcu_booking'='BOOK_ON_CALL') in_call,
    CASE ihf.care_reachout__reason WHEN 'DAY_FIFTEEN' THEN 0 WHEN 'DAY_SEVENTY_FIVE' THEN 1 WHEN 'DAY_ONE_HUNDRED_FIFTY' THEN 2
      WHEN 'DAY_TWO_HUNDRED_TEN' THEN 3 WHEN 'DAY_TWO_HUNDRED_SEVENTY' THEN 4 WHEN 'OVERDUE_OPD_CLAIM' THEN 5
      WHEN 'ENGMT_INACTIVE_ACCOUNT' THEN 7 ELSE (CASE WHEN ihf.care_reachout__reason LIKE 'BAD_CSAT%' THEN 6 ELSE 9 END) END bk
  FROM public."individuals-health_forms" ihf LEFT JOIN public.dpipe_member_flat dmf ON dmf.individual_uid=ihf._parent_doc_id
  WHERE ihf.type='POSTSALES_REACHOUT' AND ihf.is_draft=false AND ihf.care_reachout__assigned_to IS NOT NULL
    AND (ihf.submitted_at::timestamptz)::date BETWEEN '{D1}' AND '{D2}'),
fs AS (SELECT bs.form_uid, x.claim_type FROM bs JOIN LATERAL (
    SELECT ds.claim_type FROM public.dpipe_services ds WHERE ds.account_uid=bs.account_uid AND ds.claim_creation_time IS NOT NULL AND ds.visit_type='OPD' AND ds.claim_type<>'MEDICINE_HOME_DELIVERY'
      AND ds.status IN ('ACTIVE','APPROVED','DOCUMENTS_TO_BE_SUBMITTED','REPORTS_UPLOADED','RESCHEDULED','SAMPLE_COLLECTED','USER_ACTION_REQUIRED','VERIFICATION_IN_PROGRESS','INSURER_UNDER_REVIEW','ON_HOLD','UNDER_REVIEW')
      AND ds.claim_creation_time::date >= ('2026-'||bs.d)::date ORDER BY ds.claim_creation_time LIMIT 1) x ON TRUE)
SELECT COALESCE(json_agg(json_build_array(bs.d,bs.ag,bs.mobile,bs.nm,bs.bk,
    CASE bs.outcome WHEN 'INTERESTED' THEN 0 WHEN 'INTERESTED_NSA' THEN 0 WHEN 'DNP' THEN 1 WHEN 'DNP_REALLOCATE' THEN 1 WHEN 'RESCHEDULED' THEN 2
      WHEN 'DND' THEN 3 WHEN 'IGNORED' THEN 4 WHEN 'WAIT_AND_WATCH' THEN 5 WHEN 'LANGUAGE_BARRIER' THEN 6 WHEN 'OPEN_ND' THEN 7 WHEN 'OPEN_REIMBURSEMENT' THEN 7 ELSE 8 END,
    (bs.in_call)::int,
    CASE WHEN f.claim_type IS NULL THEN 0 WHEN f.claim_type='IN_HOUSE_CONSULT' THEN 1 WHEN f.claim_type='SCANNER' THEN 2 WHEN f.claim_type='HOME_COLLECTION' THEN 3
      WHEN f.claim_type IN ('NETWORK_VISIT','OPD_VISIT') THEN 4 WHEN f.claim_type='REIMBURSEMENT' THEN 5 ELSE 6 END))::text,'[]') rows
FROM bs LEFT JOIN fs f ON f.form_uid=bs.form_uid WHERE bs.bk<>9;
