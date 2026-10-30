-- Run in Supabase SQL Editor before deploying the matching index.html.
-- Nothing in this file performs a rollover. The RPCs require an admin reward session.

alter table if exists public.oe_exams
  add column if not exists school_year integer not null default 2569,
  add column if not exists semester integer not null default 1;
alter table if exists public.exam_subjects
  add column if not exists school_year integer not null default 2569,
  add column if not exists semester integer not null default 1;

create or replace function public._sr_admin(p_token uuid)
returns integer language plpgsql security definer set search_path=public,extensions as $$
declare v_actor integer;
begin
  if not public.app_authorized() then raise exception 'unauthorized'; end if;
  v_actor := public.reward_staff_actor(p_token);
  if v_actor is null or not exists (
    select 1 from public.teachers where id=v_actor and role='admin' and active=true
  ) then raise exception 'admin session required'; end if;
  return v_actor;
end $$;

create or replace function public._sr_tables()
returns text[] language sql immutable as $$
  select array[
    'reward_ranking_awards','reward_coupons','reward_wheel_spins',
    'lottery_winner_rights','lottery_draw_results','lottery_draws_v2',
    'lottery_purchase_items','lottery_ticket_inventory','lottery_purchases',
    'lottery_carts','lottery_rounds_v2','reward_attendance_awards',
    'reward_weekly_states','reward_notifications','reward_ledger',
    'reward_wallets','reward_subject_sessions','reward_ranking_prizes',
    'reward_grant_batches','reward_activity_templates','reward_wheel_prizes',
    'reward_assignment_settings',
    'lottery_winners','lottery_tickets','lottery_draws','lottery_prizes',
    'lottery_campaigns','coin_transactions','coin_accounts',
    'oe_events','oe_answers','oe_attempts','oe_options','oe_questions','oe_exams',
    'exam_results','exam_subjects','grade_history','grades',
    'subject_attendance','grade_structures','enrollments','assignment_teachers',
    'timetable','teaching_assignments','subjects',
    'morning_attendance','afternoon_attendance','good_deeds',
    'behavior_records','score_summary'
  ]::text[];
$$;

-- All predicates are built from a fixed whitelist and typed arguments.
create or replace function public._sr_where(
  p_table text,p_year integer,p_semester integer,p_start date,p_end date
) returns text language plpgsql stable as $$
declare a text; r text; e text; g text; o text; x text;
begin
  if p_table <> all(public._sr_tables()) then raise exception 'unknown reset table %',p_table; end if;
  a := format('select id from public.teaching_assignments where year=%s and semester=%s',p_year,p_semester);
  r := format('select id from public.lottery_rounds_v2 where assignment_id in (%s)',a);
  e := format('select id from public.exam_subjects where school_year=%s and semester=%s',p_year,p_semester);
  o := format('select id from public.oe_exams where school_year=%s and semester=%s',p_year,p_semester);
  g := format('select id from public.grade_structures where assignment_id in (%s) or subject_id in (select id from public.subjects)',a);
  if p_table in ('subjects','score_summary','coin_accounts','coin_transactions',
    'lottery_winners','lottery_tickets','lottery_draws','lottery_prizes','lottery_campaigns') then
    return 'true';
  elsif p_table='teaching_assignments' then return format('t.year=%s and t.semester=%s',p_year,p_semester);
  elsif p_table='timetable' then return format('t.assignment_id in (%s) or (t.year=%s and t.semester=%s)',a,p_year,p_semester);
  elsif p_table in ('enrollments','assignment_teachers','grade_structures',
    'reward_assignment_settings','reward_wallets','reward_ledger',
    'reward_activity_templates','reward_grant_batches','reward_subject_sessions',
    'reward_weekly_states','reward_notifications','lottery_rounds_v2',
    'lottery_purchases','reward_wheel_prizes','reward_wheel_spins',
    'reward_coupons','reward_ranking_prizes','reward_ranking_awards') then
    if p_table='grade_structures' then return format('t.id in (%s)',g); end if;
    return format('t.assignment_id in (%s)',a);
  elsif p_table='subject_attendance' then
    return format('t.assignment_id in (%s) or t.timetable_id in (select id from public.timetable where assignment_id in (%s) or (year=%s and semester=%s))',a,a,p_year,p_semester);
  elsif p_table='grades' then return format('t.structure_id in (%s)',g);
  elsif p_table='grade_history' then return format('t.grade_id in (select id from public.grades where structure_id in (%s))',g);
  elsif p_table='reward_attendance_awards' then
    return format('t.session_id in (select id from public.reward_subject_sessions where assignment_id in (%s))',a);
  elsif p_table in ('lottery_ticket_inventory','lottery_carts','lottery_draws_v2','lottery_winner_rights') then
    return format('t.round_id in (%s)',r);
  elsif p_table='lottery_purchase_items' then
    return format('t.purchase_id in (select id from public.lottery_purchases where assignment_id in (%s))',a);
  elsif p_table='lottery_draw_results' then
    return format('t.draw_id in (select id from public.lottery_draws_v2 where round_id in (%s))',r);
  elsif p_table='oe_exams' then return format('t.id in (%s)',o);
  elsif p_table in ('oe_questions','oe_attempts') then return format('t.exam_id in (%s)',o);
  elsif p_table='oe_options' then return format('t.question_id in (select id from public.oe_questions where exam_id in (%s))',o);
  elsif p_table in ('oe_answers','oe_events') then return format('t.attempt_id in (select id from public.oe_attempts where exam_id in (%s))',o);
  elsif p_table='exam_subjects' then return format('t.id in (%s)',e);
  elsif p_table='exam_results' then return format('t.subject_id in (%s)',e);
  elsif p_table in ('morning_attendance','afternoon_attendance') then x:='att_date';
  elsif p_table='good_deeds' then x:='deed_date';
  elsif p_table='behavior_records' then x:='record_date';
  else raise exception 'no scope for %',p_table;
  end if;
  return format('t.%I >= %L::date and t.%I <= %L::date',x,p_start,x,p_end);
end $$;

create or replace function public._sr_validate(
  p_token uuid,p_year integer,p_semester integer,p_start date,p_end date,p_cleanup boolean
) returns void language plpgsql security definer set search_path=public,extensions as $$
declare v_year text; v_sem text;
begin
  perform public._sr_admin(p_token);
  if p_semester not in (1,2) or p_start is null or p_end is null
    or p_start > p_end or p_end > (now() at time zone 'Asia/Bangkok')::date then
    raise exception 'invalid closing term dates';
  end if;
  select value into v_year from public.system_settings where key='school_year';
  select value into v_sem from public.system_settings where key='semester';
  if p_cleanup then
    if (v_year::integer <> case when p_semester=1 then p_year else p_year+1 end)
      or (v_sem::integer <> case when p_semester=1 then 2 else 1 end) then
      raise exception 'previous term does not match the current term';
    end if;
    if exists (select 1 from public.teaching_assignments
      where year=v_year::integer and semester=v_sem::integer) then
      raise exception 'current-term teaching exists; cleanup needs a separate subject plan';
    end if;
    if to_regclass('public.oe_exams') is not null then
      if exists (select 1 from public.oe_exams where school_year=v_year::integer and semester=v_sem::integer) then
        raise exception 'current-term online exams exist; cleanup needs a separate exam plan';
      end if;
    end if;
    if to_regclass('public.exam_subjects') is not null then
      if exists (select 1 from public.exam_subjects where school_year=v_year::integer and semester=v_sem::integer) then
        raise exception 'current-term graded exams exist; cleanup needs a separate exam plan';
      end if;
    end if;
  elsif v_year is distinct from p_year::text or v_sem is distinct from p_semester::text then
    raise exception 'current term changed; refresh the page';
  end if;
end $$;

create or replace function public.semester_rollover_manifest(
  p_token uuid,p_year integer,p_semester integer,p_start date,p_end date,p_cleanup boolean
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare t text; w text; n bigint; h text; rows jsonb:='[]'::jsonb; signature text:='';
begin
  perform public._sr_validate(p_token,p_year,p_semester,p_start,p_end,p_cleanup);
  foreach t in array public._sr_tables() loop
    if to_regclass('public.'||t) is null then
      n:=0;h:=md5('');
    else
      w:=public._sr_where(t,p_year,p_semester,p_start,p_end);
      execute format('select count(*),md5(coalesce(string_agg(to_jsonb(t)::text,chr(10) order by to_jsonb(t)::text),'''')) from public.%I t where %s',t,w) into n,h;
    end if;
    rows:=rows||jsonb_build_array(jsonb_build_object('table',t,'count',n,'hash',h));
    signature:=signature||t||':'||n||':'||h||';';
  end loop;
  return jsonb_build_object('year',p_year,'semester',p_semester,'cleanup',p_cleanup,
    'start',p_start,'end',p_end,'tables',rows,'digest',md5(signature));
end $$;

create or replace function public.semester_rollover_page(
  p_token uuid,p_year integer,p_semester integer,p_start date,p_end date,p_cleanup boolean,
  p_table text,p_offset integer,p_limit integer
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare result jsonb; w text;
begin
  perform public._sr_validate(p_token,p_year,p_semester,p_start,p_end,p_cleanup);
  if p_offset<0 or p_limit<1 or p_limit>500 then raise exception 'invalid page'; end if;
  w:=public._sr_where(p_table,p_year,p_semester,p_start,p_end);
  if to_regclass('public.'||p_table) is null then return '[]'::jsonb; end if;
  execute format('select coalesce(jsonb_agg(x),''[]''::jsonb) from (select to_jsonb(t) x from public.%I t where %s order by to_jsonb(t)::text offset %s limit %s) q',p_table,w,p_offset,p_limit) into result;
  return result;
end $$;

create or replace function public.semester_rollover_commit(
  p_token uuid,p_year integer,p_semester integer,p_start date,p_end date,p_cleanup boolean,p_digest text
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare current_manifest jsonb; t text; w text; next_year integer; next_sem integer; level_no integer;
begin
  perform pg_advisory_xact_lock(2569,2);
  -- Hold the selected tables steady while checking the backup digest and deleting.
  foreach t in array public._sr_tables() loop
    if to_regclass('public.'||t) is not null then
      execute format('lock table public.%I in share row exclusive mode',t);
    end if;
  end loop;
  lock table public.system_settings in share row exclusive mode;
  current_manifest:=public.semester_rollover_manifest(p_token,p_year,p_semester,p_start,p_end,p_cleanup);
  if p_digest is null or current_manifest->>'digest'<>p_digest then
    raise exception 'data changed since backup; download a new ZIP';
  end if;
  -- Break nullable cross references before deleting the selected reward graph.
  if to_regclass('public.lottery_ticket_inventory') is not null then
    update public.lottery_ticket_inventory set purchase_id=null
      where round_id in (select id from public.lottery_rounds_v2 where assignment_id in
        (select id from public.teaching_assignments where year=p_year and semester=p_semester));
  end if;
  if to_regclass('public.reward_ledger') is not null then
    update public.reward_ledger set reversal_of=null where assignment_id in
      (select id from public.teaching_assignments where year=p_year and semester=p_semester);
  end if;
  foreach t in array public._sr_tables() loop
    if to_regclass('public.'||t) is not null then
      w:=public._sr_where(t,p_year,p_semester,p_start,p_end);
      execute format('delete from public.%I t where %s',t,w);
    end if;
  end loop;
  if p_semester=2 and not p_cleanup then
    -- Keep student and home-visit rows; only update current placement.
    if exists (
      select 1 from public.students s join public.classrooms src on src.id=s.classroom_id
      left join public.classrooms dst on dst.level=src.level+1 and dst.room_number=src.room_number
      where s.status='active' and src.level between 1 and 5 and dst.id is null
    ) then raise exception 'a destination classroom is missing; no data was changed'; end if;
    update public.students s set status='transfer'
      from public.classrooms c where s.classroom_id=c.id and c.level=6 and s.status='active';
    for level_no in reverse 5..1 loop
      update public.students s set classroom_id=dst.id
        from public.classrooms src
        join public.classrooms dst on dst.level=src.level+1 and dst.room_number=src.room_number
        where s.classroom_id=src.id and src.level=level_no and s.status='active';
    end loop;
  end if;
  if p_cleanup then
    return jsonb_build_object('year',p_year,'semester',p_semester,'cleanup',true);
  else
    next_sem:=case when p_semester=1 then 2 else 1 end;
    next_year:=case when p_semester=1 then p_year else p_year+1 end;
    insert into public.system_settings(key,value) values
      ('school_year',next_year::text),('semester',next_sem::text)
      on conflict(key) do update set value=excluded.value;
    return jsonb_build_object('year',next_year,'semester',next_sem,'cleanup',false);
  end if;
end $$;

revoke all on function public._sr_admin(uuid) from public,anon,authenticated;
revoke all on function public._sr_tables() from public,anon,authenticated;
revoke all on function public._sr_where(text,integer,integer,date,date) from public,anon,authenticated;
revoke all on function public._sr_validate(uuid,integer,integer,date,date,boolean) from public,anon,authenticated;
grant execute on function public.semester_rollover_manifest(uuid,integer,integer,date,date,boolean) to anon,authenticated;
grant execute on function public.semester_rollover_page(uuid,integer,integer,date,date,boolean,text,integer,integer) to anon,authenticated;
grant execute on function public.semester_rollover_commit(uuid,integer,integer,date,date,boolean,text) to anon,authenticated;
