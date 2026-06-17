WITH bc AS (
  SELECT ihf.uid form_uid, dmf.account_uid, split_part(ihf.care_reachout__assigned_to,'@',1) ag, ihf.is_draft,
    to_char((ihf.created_at::timestamptz)::date,'YYYY-MM-DD') d, (ihf.created_at::timestamptz)::date fd,
    CASE WHEN ihf.care_reachout__reason='DAY_FIFTEEN' THEN 'Day 15' WHEN ihf.care_reachout__reason='DAY_SEVENTY_FIVE' THEN 'Day 75'
      WHEN ihf.care_reachout__reason='DAY_ONE_HUNDRED_FIFTY' THEN 'Day 150' WHEN ihf.care_reachout__reason='DAY_TWO_HUNDRED_TEN' THEN 'Day 210'
      WHEN ihf.care_reachout__reason='DAY_TWO_HUNDRED_SEVENTY' THEN 'Day 270' WHEN ihf.care_reachout__reason='OVERDUE_OPD_CLAIM' THEN 'OPD Reimbursement'
      WHEN ihf.care_reachout__reason LIKE 'BAD_CSAT%' THEN 'Bad CSAT' WHEN ihf.care_reachout__reason='ENGMT_INACTIVE_ACCOUNT' THEN 'Engagement (Inactive)' ELSE 'Other' END bucket
  FROM public."individuals-health_forms" ihf
  LEFT JOIN public.dpipe_member_flat dmf ON dmf.individual_uid=ihf._parent_doc_id
  WHERE ihf.type='POSTSALES_REACHOUT' AND ihf.care_reachout__assigned_to IS NOT NULL AND (ihf.created_at::timestamptz)::date = CURRENT_DATE),
svc AS (SELECT bc.form_uid fid,
    bool_or(ds.claim_type='IN_HOUSE_CONSULT') tele, bool_or(ds.claim_type='SCANNER') scan, bool_or(ds.claim_type='HOME_COLLECTION') tests,
    bool_or(ds.claim_type IN ('NETWORK_VISIT','OPD_VISIT')) vis, bool_or(ds.visit_type='OPD' AND ds.claim_type='REIMBURSEMENT') opd,
    bool_or(ds.visit_type='IPD') ipd, bool_or(ds.visit_type NOT IN ('OPD','IPD') AND ds.claim_type='REIMBURSEMENT') oth
  FROM bc JOIN public.dpipe_services ds ON ds.account_uid=bc.account_uid AND ds.claim_creation_time IS NOT NULL AND ds.claim_type<>'MEDICINE_HOME_DELIVERY'
    AND ds.status IN ('ACTIVE','APPROVED','DOCUMENTS_TO_BE_SUBMITTED','REPORTS_UPLOADED','RESCHEDULED','SAMPLE_COLLECTED','USER_ACTION_REQUIRED','VERIFICATION_IN_PROGRESS','INSURER_UNDER_REVIEW','ON_HOLD','UNDER_REVIEW')
    AND ds.claim_creation_time::date >= bc.fd GROUP BY bc.form_uid),
aggc AS (SELECT bc.d, bc.ag, bc.bucket bk, COUNT(DISTINCT bc.account_uid) accts, COUNT(DISTINCT bc.form_uid) FILTER (WHERE bc.is_draft) pending, COUNT(DISTINCT bc.form_uid) forms,
    COUNT(DISTINCT bc.account_uid) FILTER (WHERE s.tele) ut, COUNT(DISTINCT bc.account_uid) FILTER (WHERE s.scan) us, COUNT(DISTINCT bc.account_uid) FILTER (WHERE s.tests) ute,
    COUNT(DISTINCT bc.account_uid) FILTER (WHERE s.vis) uv, COUNT(DISTINCT bc.account_uid) FILTER (WHERE s.opd) uo, COUNT(DISTINCT bc.account_uid) FILTER (WHERE s.ipd) ui,
    COUNT(DISTINCT bc.account_uid) FILTER (WHERE s.oth) uoth, COUNT(DISTINCT bc.account_uid) FILTER (WHERE s.fid IS NOT NULL) uany
  FROM bc LEFT JOIN svc s ON s.fid=bc.form_uid WHERE bc.bucket<>'Other' GROUP BY 1,2,3),
bs AS (SELECT ihf.uid form_uid, ihf.care_reachout__outcome outcome, to_char((ihf.submitted_at::timestamptz)::date,'YYYY-MM-DD') d, split_part(ihf.care_reachout__assigned_to,'@',1) ag,
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
  FROM public."individuals-health_forms" ihf WHERE ihf.type='POSTSALES_REACHOUT' AND ihf.is_draft=false AND ihf.care_reachout__assigned_to IS NOT NULL AND (ihf.submitted_at::timestamptz)::date = CURRENT_DATE),
aggs AS (SELECT bs.d, bs.ag, bs.bucket bk, COUNT(DISTINCT bs.form_uid) calls, COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.in_call) bookings,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome IN ('INTERESTED','INTERESTED_NSA')) di, COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome IN ('DNP','DNP_REALLOCATE')) ddnp,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome='RESCHEDULED') dre, COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome='DND') ddnd, COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome='IGNORED') dig,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome='WAIT_AND_WATCH') dww, COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome='LANGUAGE_BARRIER') dlb,
    COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome IN ('OPEN_ND','OPEN_REIMBURSEMENT')) dop, COUNT(DISTINCT bs.form_uid) FILTER (WHERE bs.outcome IS NULL) dno
  FROM bs WHERE bs.bucket<>'Other' GROUP BY 1,2,3)
SELECT COALESCE(json_agg(json_build_array(COALESCE(c.d,s.d),COALESCE(c.ag,s.ag),COALESCE(c.bk,s.bk),
  COALESCE(c.accts,0),COALESCE(c.pending,0),COALESCE(c.forms,0),COALESCE(s.calls,0),COALESCE(s.bookings,0),
  COALESCE(c.ut,0),COALESCE(c.us,0),COALESCE(c.ute,0),COALESCE(c.uv,0),COALESCE(c.uo,0),COALESCE(c.ui,0),COALESCE(c.uoth,0),COALESCE(c.uany,0),
  COALESCE(s.di,0),COALESCE(s.ddnp,0),COALESCE(s.dre,0),COALESCE(s.ddnd,0),COALESCE(s.dig,0),COALESCE(s.dww,0),COALESCE(s.dlb,0),COALESCE(s.dop,0),COALESCE(s.dno,0)) ORDER BY 1,2,3)::text,'[]') rows
FROM aggc c FULL OUTER JOIN aggs s ON c.d=s.d AND c.ag=s.ag AND c.bk=s.bk;