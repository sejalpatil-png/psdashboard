WITH bc AS (
  SELECT ihf.uid form_uid, dmf.account_uid, split_part(ihf.care_reachout__assigned_to,'@',1) ag, ihf.is_draft,
    to_char((ihf.created_at::timestamptz)::date,'YYYY-MM-DD') d,
    CASE WHEN ihf.care_reachout__reason='DAY_FIFTEEN' THEN 'Day 15' WHEN ihf.care_reachout__reason='DAY_SEVENTY_FIVE' THEN 'Day 75'
      WHEN ihf.care_reachout__reason='DAY_ONE_HUNDRED_FIFTY' THEN 'Day 150' WHEN ihf.care_reachout__reason='DAY_TWO_HUNDRED_TEN' THEN 'Day 210'
      WHEN ihf.care_reachout__reason='DAY_TWO_HUNDRED_SEVENTY' THEN 'Day 270' WHEN ihf.care_reachout__reason='OVERDUE_OPD_CLAIM' THEN 'OPD Reimbursement'
      WHEN ihf.care_reachout__reason LIKE 'BAD_CSAT%' THEN 'Bad CSAT' WHEN ihf.care_reachout__reason='ENGMT_INACTIVE_ACCOUNT' THEN 'Engagement (Inactive)' ELSE 'Other' END bucket
  FROM public."individuals-health_forms" ihf LEFT JOIN public.dpipe_member_flat dmf ON dmf.individual_uid=ihf._parent_doc_id
  WHERE ihf.type='POSTSALES_REACHOUT' AND ihf.care_reachout__assigned_to IS NOT NULL AND (ihf.created_at::timestamptz)::date = CURRENT_DATE),
aggc AS (SELECT bc.d, bc.ag, bc.bucket bk, COUNT(DISTINCT bc.account_uid) accts, COUNT(DISTINCT bc.form_uid) FILTER (WHERE bc.is_draft) pending, COUNT(DISTINCT bc.form_uid) forms
  FROM bc WHERE bc.bucket<>'Other' GROUP BY 1,2,3),
bs AS (
  SELECT ihf.uid form_uid, dmf.account_uid, split_part(ihf.care_reachout__assigned_to,'@',1) ag, (ihf.submitted_at::timestamptz)::date sd, ihf.care_reachout__outcome outcome,
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
  FROM public."individuals-health_forms" ihf LEFT JOIN public.dpipe_member_flat dmf ON dmf.individual_uid=ihf._parent_doc_id
  WHERE ihf.type='POSTSALES_REACHOUT' AND ihf.is_draft=false AND ihf.care_reachout__assigned_to IS NOT NULL AND (ihf.submitted_at::timestamptz)::date = CURRENT_DATE),
fs AS (SELECT bs.form_uid, x.claim_type FROM bs JOIN LATERAL (
    SELECT ds.claim_type FROM public.dpipe_services ds WHERE ds.account_uid=bs.account_uid AND ds.claim_creation_time IS NOT NULL AND ds.visit_type='OPD' AND ds.claim_type<>'MEDICINE_HOME_DELIVERY'
      AND ds.status IN ('ACTIVE','APPROVED','DOCUMENTS_TO_BE_SUBMITTED','REPORTS_UPLOADED','RESCHEDULED','SAMPLE_COLLECTED','USER_ACTION_REQUIRED','VERIFICATION_IN_PROGRESS','INSURER_UNDER_REVIEW','ON_HOLD','UNDER_REVIEW')
      AND ds.claim_creation_time::date >= bs.sd ORDER BY ds.claim_creation_time LIMIT 1) x ON TRUE),
aggs AS (SELECT bs.ag, bs.bucket bk, COUNT(DISTINCT bs.form_uid) calls, COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.in_call) in_call,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE f.claim_type='IN_HOUSE_CONSULT') ut, COUNT(DISTINCT bs.form_uid) FILTER (WHERE f.claim_type='SCANNER') us,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE f.claim_type='HOME_COLLECTION') ute, COUNT(DISTINCT bs.form_uid) FILTER (WHERE f.claim_type IN ('NETWORK_VISIT','OPD_VISIT')) uv,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE f.claim_type='REIMBURSEMENT') uo,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE f.claim_type NOT IN ('IN_HOUSE_CONSULT','SCANNER','HOME_COLLECTION','NETWORK_VISIT','OPD_VISIT','REIMBURSEMENT')) uoth,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE f.form_uid IS NOT NULL) uany,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome IN ('INTERESTED','INTERESTED_NSA')) di, COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome IN ('DNP','DNP_REALLOCATE')) ddnp,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome='RESCHEDULED') dre, COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome='DND') ddnd,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome='IGNORED') dig, COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome='WAIT_AND_WATCH') dww,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome='LANGUAGE_BARRIER') dlb, COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome IN ('OPEN_ND','OPEN_REIMBURSEMENT')) dop,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome IS NULL) dno
  FROM bs LEFT JOIN fs f ON f.form_uid=bs.form_uid WHERE bs.bucket<>'Other' GROUP BY 1,2)
SELECT COALESCE(json_agg(json_build_array(to_char(CURRENT_DATE,'YYYY-MM-DD'),COALESCE(c.ag,s.ag),COALESCE(c.bk,s.bk),
  COALESCE(c.accts,0),COALESCE(c.pending,0),COALESCE(c.forms,0),COALESCE(s.calls,0),COALESCE(s.in_call,0),
  COALESCE(s.ut,0),COALESCE(s.us,0),COALESCE(s.ute,0),COALESCE(s.uv,0),COALESCE(s.uo,0),0,COALESCE(s.uoth,0),COALESCE(s.uany,0),
  COALESCE(s.di,0),COALESCE(s.ddnp,0),COALESCE(s.dre,0),COALESCE(s.ddnd,0),COALESCE(s.dig,0),COALESCE(s.dww,0),COALESCE(s.dlb,0),COALESCE(s.dop,0),COALESCE(s.dno,0)))::text,'[]') rows
FROM aggc c FULL OUTER JOIN aggs s ON c.ag=s.ag AND c.bk=s.bk;