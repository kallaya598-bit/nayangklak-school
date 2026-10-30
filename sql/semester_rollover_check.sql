-- Read-only. Run in Supabase SQL Editor and share the result before deployment.
select 'school_year' as item, value as result from public.system_settings where key='school_year'
union all select 'semester',value from public.system_settings where key='semester'
union all select 'students',count(*)::text from public.students
union all select 'active_students',count(*)::text from public.students where status='active'
union all select 'home_visits',count(*)::text from public.home_visits
union all select 'subjects',count(*)::text from public.subjects
union all select 'teaching_assignments_1_2569',count(*)::text
  from public.teaching_assignments where year=2569 and semester=1
union all select 'teaching_assignments_2_2569',count(*)::text
  from public.teaching_assignments where year=2569 and semester=2
union all select 'morning_attendance',count(*)::text from public.morning_attendance
union all select 'afternoon_attendance',count(*)::text from public.afternoon_attendance
union all select 'good_deeds',count(*)::text from public.good_deeds
union all select 'behavior_records',count(*)::text from public.behavior_records
union all select 'score_summary',count(*)::text from public.score_summary
union all select 'grades',count(*)::text from public.grades
union all select 'grade_structures',count(*)::text from public.grade_structures
union all select 'oe_exams',count(*)::text from public.oe_exams
union all select 'exam_subjects',count(*)::text from public.exam_subjects
union all select 'mh_assessments',count(*)::text from public.mh_assessments
union all select 'reward_wallets',count(*)::text from public.reward_wallets
union all select 'reward_ledger',count(*)::text from public.reward_ledger
union all select 'lottery_rounds_v2',count(*)::text from public.lottery_rounds_v2
order by item;
