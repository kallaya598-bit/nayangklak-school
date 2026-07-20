-- ================================================================
-- ระบบสอบออนไลน์ (oe_ = online exam) — รันใน Supabase SQL Editor ครั้งเดียว
-- รันซ้ำได้ปลอดภัยเสมอ (idempotent)
--
-- ⚠️ สำคัญเรื่องความปลอดภัยของเฉลย — อ่านก่อนใช้งาน ⚠️
-- ระบบนี้ไม่มี Supabase Auth แยกสิทธิ์ผู้ใช้จริง (ครู/นักเรียนใช้ anon key เดียวกันหมด
-- ตามที่ security_hardening.sql อธิบายไว้) ดังนั้น RLS/ header x-app-key ที่ตารางด้านล่าง
-- ใช้ร่วมกันทั้งระบบ "กันบอท/สแกนอัตโนมัติ" เท่านั้น ไม่ใช่การกันนักเรียนที่ตั้งใจเปิด
-- DevTools แล้วยิง REST ไปตาราง oe_options ตรงๆ (จะยังอ่าน is_correct ได้เหมือนตารางอื่น
-- ทุกตารางในระบบนี้)
-- การป้องกันจริงที่ทำได้คือ: หน้าทำข้อสอบของนักเรียนต้องเรียกผ่าน RPC
-- (oe_start_attempt / oe_save_answer / oe_submit_attempt) เท่านั้น ห้ามอ่านตาราง
-- oe_options/oe_questions ตรงๆ — RPC เหล่านี้เป็น SECURITY DEFINER และตัดคอลัมน์
-- is_correct ออกก่อนส่งกลับเสมอ ทำให้ "การใช้งานปกติ" (เปิดลิงก์สอบ → ทำข้อสอบ)
-- ไม่มีทางเห็นเฉลยผ่าน Network tab ได้ — ป้องกันได้เฉพาะช่องทางใช้งานปกติ
-- ไม่ใช่การป้องกันแบบสมบูรณ์ 100% เหมือนระบบที่มี server แยกจริง
-- ================================================================

create extension if not exists pgcrypto;

-- ================================================================
-- 1) ตาราง
-- ================================================================

create table if not exists oe_exams (
  id bigint generated always as identity primary key,
  title text not null,
  description text,
  room_ids text not null default '',      -- "1,2,3" (classroom IDs คั่นด้วย comma)
  created_by integer references teachers(id),
  status text not null default 'draft' check (status in ('draft','published','closed')),
  exam_code text unique,                  -- รหัสสั้นสำหรับลิงก์เข้าสอบ (?exam=CODE)
  access_code text,                       -- รหัสผ่านเข้าสอบเพิ่มเติม (ไม่บังคับ)
  duration_minutes integer not null default 60,
  start_at timestamptz,
  end_at timestamptz,
  attempt_limit integer not null default 1,
  shuffle_questions boolean not null default true,
  shuffle_options boolean not null default true,
  random_count integer,                   -- จำนวนข้อที่สุ่มออกจากคลัง (null = ใช้ทุกข้อ)
  show_score boolean not null default true,
  show_answers_mode text not null default 'after_close' check (show_answers_mode in ('never','after_close','immediate')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
alter table oe_exams
  add column if not exists title text,
  add column if not exists description text,
  add column if not exists room_ids text not null default '',
  add column if not exists created_by integer references teachers(id),
  add column if not exists status text not null default 'draft',
  add column if not exists exam_code text,
  add column if not exists access_code text,
  add column if not exists duration_minutes integer not null default 60,
  add column if not exists start_at timestamptz,
  add column if not exists end_at timestamptz,
  add column if not exists attempt_limit integer not null default 1,
  add column if not exists shuffle_questions boolean not null default true,
  add column if not exists shuffle_options boolean not null default true,
  add column if not exists random_count integer,
  add column if not exists show_score boolean not null default true,
  add column if not exists show_answers_mode text not null default 'after_close',
  add column if not exists updated_at timestamptz default now();
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'oe_exams_exam_code_key') then
    alter table oe_exams add constraint oe_exams_exam_code_key unique (exam_code);
  end if;
exception when duplicate_table then null; end $$;

create table if not exists oe_questions (
  id bigint generated always as identity primary key,
  exam_id bigint not null references oe_exams(id) on delete cascade,
  question_text text not null,
  question_type text not null default 'mcq' check (question_type in ('mcq','tf')),
  score numeric not null default 1,
  explanation text,
  sort_order integer not null default 0,
  created_at timestamptz default now()
);

create table if not exists oe_options (
  id bigint generated always as identity primary key,
  question_id bigint not null references oe_questions(id) on delete cascade,
  option_text text not null,
  is_correct boolean not null default false,
  sort_order integer not null default 0
);

create table if not exists oe_attempts (
  id bigint generated always as identity primary key,
  exam_id bigint not null references oe_exams(id) on delete cascade,
  student_id integer not null references students(id),
  attempt_token uuid not null default gen_random_uuid() unique,
  attempt_number integer not null default 1,
  question_order jsonb not null default '[]'::jsonb,   -- [{question_id, option_order:[opt_id,...]}]
  status text not null default 'in_progress' check (status in ('in_progress','submitted','expired')),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  auto_score numeric,
  adjusted_score numeric,
  adjust_note text,
  final_score numeric,
  duration_seconds integer,
  auto_submitted boolean not null default false,
  warn_count integer not null default 0,
  unique(exam_id, student_id, attempt_number)
);

create table if not exists oe_answers (
  id bigint generated always as identity primary key,
  attempt_id bigint not null references oe_attempts(id) on delete cascade,
  question_id bigint not null references oe_questions(id) on delete cascade,
  selected_option_id bigint references oe_options(id),
  answered_at timestamptz default now(),
  unique(attempt_id, question_id)
);

create table if not exists oe_events (
  id bigint generated always as identity primary key,
  attempt_id bigint not null references oe_attempts(id) on delete cascade,
  event_type text not null,
  event_detail text,
  occurred_at timestamptz default now()
);

-- ================================================================
-- 2) RLS — เหมือนตารางอื่นทั้งระบบ (ดูหมายเหตุด้านบนของไฟล์)
-- ================================================================
do $$
declare t text;
begin
  foreach t in array array['oe_exams','oe_questions','oe_options','oe_attempts','oe_answers','oe_events']
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists app_access on public.%I;', t);
    execute format(
      'create policy app_access on public.%I for all using (public.app_authorized()) with check (public.app_authorized());',
      t
    );
  end loop;
end $$;

-- ================================================================
-- 3) trigger updated_at
-- ================================================================
create or replace function oe_set_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

drop trigger if exists trg_oe_exams_updated on oe_exams;
create trigger trg_oe_exams_updated before update on oe_exams
  for each row execute function oe_set_updated_at();

-- ================================================================
-- 4) RPC ฝั่งนักเรียน (SECURITY DEFINER — ไม่ส่ง is_correct กลับเด็ดขาด)
-- ================================================================

-- เริ่มสอบ / กลับเข้าสอบต่อ / ดูผลถ้าสอบไปแล้ว
create or replace function oe_start_attempt(
  p_exam_code text, p_access_code text, p_student_code text, p_fullname text, p_room text
) returns jsonb as $$
declare
  v_exam oe_exams%rowtype;
  v_student students%rowtype;
  v_room_name text;
  v_attempt oe_attempts%rowtype;
  v_count integer;
  v_qids bigint[];
  v_qid bigint;
  v_opt_ids bigint[];
  v_qorder jsonb;
  v_questions jsonb;
  v_qentry jsonb;
  v_options jsonb;
  v_oid bigint;
  v_selected bigint;
begin
  if not public.app_authorized() then raise exception 'unauthorized'; end if;

  select * into v_exam from oe_exams where exam_code = upper(trim(coalesce(p_exam_code,'')));
  if not found then raise exception 'exam_not_found'; end if;
  if v_exam.status <> 'published' then raise exception 'exam_not_open'; end if;
  if v_exam.start_at is not null and now() < v_exam.start_at then raise exception 'exam_not_started'; end if;
  if v_exam.end_at is not null and now() > v_exam.end_at then raise exception 'exam_closed'; end if;
  if coalesce(v_exam.access_code,'') <> '' and coalesce(p_access_code,'') <> v_exam.access_code then
    raise exception 'wrong_access_code';
  end if;

  select * into v_student from students
  where student_code = trim(coalesce(p_student_code,'')) and status = 'active';
  if not found then raise exception 'student_not_found'; end if;

  select room_name into v_room_name from classrooms where id = v_student.classroom_id;
  if v_room_name is null or trim(v_room_name) <> trim(coalesce(p_room,''))
     or trim(v_student.fullname) <> trim(coalesce(p_fullname,'')) then
    raise exception 'student_mismatch';
  end if;

  if coalesce(v_exam.room_ids,'') = ''
     or (','||v_exam.room_ids||',') not like ('%,'||v_student.classroom_id||',%') then
    raise exception 'room_not_allowed';
  end if;

  -- มี attempt ที่ยังไม่ส่งอยู่แล้ว → คืนอันเดิม (กลับเข้าสอบต่อ) เว้นแต่หมดเวลาไปแล้ว
  select * into v_attempt from oe_attempts
  where exam_id = v_exam.id and student_id = v_student.id and status = 'in_progress'
  order by attempt_number desc limit 1;

  if found and extract(epoch from (now() - v_attempt.started_at)) > (v_exam.duration_minutes * 60 + 30) then
    update oe_attempts set status = 'expired' where id = v_attempt.id;
    v_attempt := null;
  end if;

  if v_attempt.id is null then
    select count(*) into v_count from oe_attempts
    where exam_id = v_exam.id and student_id = v_student.id;

    if v_count >= v_exam.attempt_limit then
      -- สอบครบจำนวนครั้งแล้ว เข้าลิงก์ซ้ำ → คืนผลล่าสุดแทนการฟ้อง error
      select * into v_attempt from oe_attempts
      where exam_id = v_exam.id and student_id = v_student.id
      order by attempt_number desc limit 1;
      return jsonb_build_object(
        'already_submitted', true,
        'score', case when v_exam.show_score then v_attempt.final_score else null end,
        'show_score', v_exam.show_score
      );
    end if;

    select array_agg(id order by case when v_exam.shuffle_questions then random() else sort_order::float end)
    into v_qids from oe_questions where exam_id = v_exam.id;

    if v_qids is null then raise exception 'exam_has_no_questions'; end if;

    if v_exam.random_count is not null and v_exam.random_count > 0
       and array_length(v_qids,1) > v_exam.random_count then
      v_qids := v_qids[1:v_exam.random_count];
    end if;

    v_qorder := '[]'::jsonb;
    foreach v_qid in array v_qids loop
      select array_agg(id order by case when v_exam.shuffle_options then random() else sort_order::float end)
      into v_opt_ids from oe_options where question_id = v_qid;
      if v_opt_ids is null then continue; end if; -- ข้อที่ยังไม่มีตัวเลือก ข้ามไปก่อน
      v_qorder := v_qorder || jsonb_build_array(
        jsonb_build_object('question_id', v_qid, 'option_order', to_jsonb(v_opt_ids))
      );
    end loop;

    insert into oe_attempts(exam_id, student_id, attempt_number, question_order, status, started_at)
    values (v_exam.id, v_student.id, coalesce(v_count,0) + 1, v_qorder, 'in_progress', now())
    returning * into v_attempt;
  end if;

  -- ประกอบคำถาม+ตัวเลือกตามลำดับที่บันทึกไว้ตอนเริ่มสอบ (ไม่มี is_correct) + คำตอบเดิมถ้ามี
  v_questions := '[]'::jsonb;
  for v_qentry in select value from jsonb_array_elements(v_attempt.question_order) loop
    v_qid := (v_qentry->>'question_id')::bigint;
    v_options := '[]'::jsonb;
    for v_oid in select jsonb_array_elements_text(v_qentry->'option_order')::bigint loop
      select v_options || jsonb_build_array(jsonb_build_object('id', o.id, 'option_text', o.option_text))
      into v_options from oe_options o where o.id = v_oid;
    end loop;
    select selected_option_id into v_selected from oe_answers
    where attempt_id = v_attempt.id and question_id = v_qid;
    select v_questions || jsonb_build_array(jsonb_build_object(
      'id', q.id, 'question_text', q.question_text, 'question_type', q.question_type,
      'score', q.score, 'options', v_options, 'selected_option_id', v_selected
    )) into v_questions from oe_questions q where q.id = v_qid;
  end loop;

  return jsonb_build_object(
    'attempt_token', v_attempt.attempt_token,
    'exam', jsonb_build_object(
      'id', v_exam.id, 'title', v_exam.title, 'description', v_exam.description,
      'duration_minutes', v_exam.duration_minutes, 'show_score', v_exam.show_score
    ),
    'started_at', v_attempt.started_at,
    'questions', v_questions,
    'student', jsonb_build_object('fullname', v_student.fullname, 'student_code', v_student.student_code)
  );
end;
$$ language plpgsql security definer;

-- บันทึกคำตอบ (autosave ทีละข้อ)
create or replace function oe_save_answer(p_attempt_token uuid, p_question_id bigint, p_option_id bigint)
returns jsonb as $$
declare
  v_attempt oe_attempts%rowtype;
  v_exam oe_exams%rowtype;
  v_valid boolean;
begin
  if not public.app_authorized() then raise exception 'unauthorized'; end if;

  select * into v_attempt from oe_attempts where attempt_token = p_attempt_token;
  if not found then raise exception 'attempt_not_found'; end if;
  if v_attempt.status <> 'in_progress' then raise exception 'attempt_closed'; end if;

  select * into v_exam from oe_exams where id = v_attempt.exam_id;
  if extract(epoch from (now() - v_attempt.started_at)) > (v_exam.duration_minutes * 60 + 30) then
    update oe_attempts set status = 'expired' where id = v_attempt.id;
    raise exception 'time_up';
  end if;

  -- คำถามต้องอยู่ในชุดคำถามของ attempt นี้จริง (กันการยัดข้อของข้อสอบชุดอื่น)
  select exists(
    select 1 from jsonb_array_elements(v_attempt.question_order) qo
    where (qo->>'question_id')::bigint = p_question_id
  ) into v_valid;
  if not v_valid then raise exception 'question_not_in_attempt'; end if;

  if p_option_id is not null
     and not exists(select 1 from oe_options where id = p_option_id and question_id = p_question_id) then
    raise exception 'invalid_option';
  end if;

  insert into oe_answers(attempt_id, question_id, selected_option_id, answered_at)
  values (v_attempt.id, p_question_id, p_option_id, now())
  on conflict (attempt_id, question_id)
  do update set selected_option_id = excluded.selected_option_id, answered_at = now();

  return jsonb_build_object('ok', true);
end;
$$ language plpgsql security definer;

-- บันทึกเหตุการณ์ระหว่างสอบ (สลับแท็บ / ออกจากโหมดเต็มหน้าจอ ฯลฯ) — คืนจำนวนครั้งสะสม
create or replace function oe_log_event(p_attempt_token uuid, p_event_type text, p_event_detail text default null)
returns jsonb as $$
declare
  v_attempt oe_attempts%rowtype;
  v_warn integer;
begin
  if not public.app_authorized() then raise exception 'unauthorized'; end if;
  select * into v_attempt from oe_attempts where attempt_token = p_attempt_token;
  if not found then raise exception 'attempt_not_found'; end if;

  insert into oe_events(attempt_id, event_type, event_detail) values (v_attempt.id, p_event_type, p_event_detail);

  if p_event_type in ('tab_hidden','fullscreen_exit') then
    update oe_attempts set warn_count = warn_count + 1 where id = v_attempt.id returning warn_count into v_warn;
  else
    v_warn := v_attempt.warn_count;
  end if;

  return jsonb_build_object('warn_count', v_warn);
end;
$$ language plpgsql security definer;

-- ส่งข้อสอบ + ตรวจคะแนนอัตโนมัติ (ฝั่งเซิร์ฟเวอร์เท่านั้น)
create or replace function oe_submit_attempt(p_attempt_token uuid, p_auto boolean default false)
returns jsonb as $$
declare
  v_attempt oe_attempts%rowtype;
  v_exam oe_exams%rowtype;
  v_score numeric := 0;
  v_rec record;
begin
  if not public.app_authorized() then raise exception 'unauthorized'; end if;
  select * into v_attempt from oe_attempts where attempt_token = p_attempt_token;
  if not found then raise exception 'attempt_not_found'; end if;
  if v_attempt.status <> 'in_progress' then raise exception 'attempt_closed'; end if;

  select * into v_exam from oe_exams where id = v_attempt.exam_id;

  for v_rec in
    select q.score as qscore, coalesce(o.is_correct,false) as correct
    from oe_answers a
    join oe_questions q on q.id = a.question_id
    left join oe_options o on o.id = a.selected_option_id
    where a.attempt_id = v_attempt.id
  loop
    if v_rec.correct then v_score := v_score + v_rec.qscore; end if;
  end loop;

  update oe_attempts set
    status = 'submitted',
    submitted_at = now(),
    auto_score = v_score,
    final_score = v_score,
    duration_seconds = extract(epoch from (now() - v_attempt.started_at))::integer,
    auto_submitted = p_auto
  where id = v_attempt.id;

  return jsonb_build_object(
    'submitted', true,
    'score', case when v_exam.show_score then v_score else null end,
    'show_score', v_exam.show_score
  );
end;
$$ language plpgsql security definer;

-- ดูเฉลยหลังส่งข้อสอบ (ตามการตั้งค่า show_answers_mode ของครู) — ตัดสินที่ฝั่งเซิร์ฟเวอร์เท่านั้น
create or replace function oe_get_review(p_attempt_token uuid)
returns jsonb as $$
declare
  v_attempt oe_attempts%rowtype;
  v_exam oe_exams%rowtype;
  v_allowed boolean := false;
  v_questions jsonb := '[]'::jsonb;
  v_qentry jsonb;
  v_qid bigint;
  v_options jsonb;
  v_oid bigint;
  v_selected bigint;
begin
  if not public.app_authorized() then raise exception 'unauthorized'; end if;
  select * into v_attempt from oe_attempts where attempt_token = p_attempt_token;
  if not found then raise exception 'attempt_not_found'; end if;
  if v_attempt.status = 'in_progress' then raise exception 'not_submitted'; end if;

  select * into v_exam from oe_exams where id = v_attempt.exam_id;

  if v_exam.show_answers_mode = 'immediate' then
    v_allowed := true;
  elsif v_exam.show_answers_mode = 'after_close' then
    v_allowed := (v_exam.status = 'closed') or (v_exam.end_at is not null and now() > v_exam.end_at);
  end if;

  if not v_allowed then
    return jsonb_build_object('allowed', false, 'final_score', case when v_exam.show_score then v_attempt.final_score else null end);
  end if;

  for v_qentry in select value from jsonb_array_elements(v_attempt.question_order) loop
    v_qid := (v_qentry->>'question_id')::bigint;
    v_options := '[]'::jsonb;
    for v_oid in select jsonb_array_elements_text(v_qentry->'option_order')::bigint loop
      select v_options || jsonb_build_array(jsonb_build_object(
        'id', o.id, 'option_text', o.option_text, 'is_correct', o.is_correct
      )) into v_options from oe_options o where o.id = v_oid;
    end loop;
    select selected_option_id into v_selected from oe_answers
    where attempt_id = v_attempt.id and question_id = v_qid;
    select v_questions || jsonb_build_array(jsonb_build_object(
      'id', q.id, 'question_text', q.question_text, 'score', q.score,
      'explanation', q.explanation, 'options', v_options, 'selected_option_id', v_selected
    )) into v_questions from oe_questions q where q.id = v_qid;
  end loop;

  return jsonb_build_object(
    'allowed', true,
    'final_score', case when v_exam.show_score then v_attempt.final_score else null end,
    'questions', v_questions
  );
end;
$$ language plpgsql security definer;

notify pgrst, 'reload schema';

-- ================================================================
-- ตรวจผลหลังรัน:
--   select * from pg_tables where tablename like 'oe_%';
--   select tablename, policyname from pg_policies where tablename like 'oe_%';
-- ================================================================
