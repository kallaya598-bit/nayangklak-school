-- ================================================================
-- Security Hardening: ปิดคำเตือน "Table publicly accessible" (rls_disabled_in_public)
--                      + ปิดช่องโหว่รหัสผ่านครูอ่านได้ตรงๆ
-- รันใน Supabase SQL Editor — รันซ้ำได้ปลอดภัยเสมอ (idempotent)
--
-- ⚠️ ถ้าพอร์ตไปโรงเรียนใหม่: ต้องเปลี่ยนค่า secret ในบรรทัดที่มี 'x-app-key' ด้านล่าง
--    เป็นค่าสุ่มใหม่ (เช่น openssl rand -hex 24) แล้วอัปเดต APP_KEY ใน index.html
--    ให้ตรงกันด้วย — อย่าใช้ secret เดียวกับโรงเรียนอื่น
--    ต้องรันไฟล์นี้ "หลังสุด" หลังจากตาราง teachers ถูกสร้างครบทุกคอลัมน์แล้วเท่านั้น
--    (รวมคอลัมน์ permissions/is_academic/shortcuts) ไม่งั้นการ grant คอลัมน์ในขั้นตอนที่ 2
--    จะไม่ครบ (ระบบข้ามให้อัตโนมัติถ้าตารางไม่มีอยู่ แต่คอลัมน์ต้องมีครบตอนรัน)
--
-- ⚠️⚠️ สำคัญมาก — ลำดับการ deploy (สำหรับโปรเจกต์ที่มีผู้ใช้งานจริงอยู่แล้ว) ⚠️⚠️
--   1) Deploy index.html เวอร์ชันที่ส่ง header 'x-app-key' ขึ้น GitHub Pages ก่อน
--   2) รอสักครู่ให้แน่ใจไม่มีแท็บเว็บเวอร์ชันเก่าค้างอยู่ (เว็บนี้ไม่มี service worker
--      แคชหน้า HTML — sw.js จัดการแค่ push notification — ความเสี่ยงต่ำ)
--   3) ค่อยรันไฟล์นี้ใน Supabase SQL Editor
--
-- ทำไมไม่ใช้ RLS แบบ "ผูกกับผู้ใช้จริง": ระบบนี้ใช้ custom login ผ่าน RPC (ไม่ใช่ Supabase Auth)
-- ทุก request จากเว็บใช้ anon key เดียวกันหมด Supabase จึงแยกไม่ออกว่าใครเรียก
-- แนวทางนี้จึงล็อกด้วย "secret header" แทน — ปิดกั้นบอท/สแกนอัตโนมัติที่ยิง Supabase URL
-- สาธารณะแบบสุ่ม (ภัยคุกคามจริงที่พบบ่อยที่สุด) แต่ไม่ใช่การยืนยันตัวตนแบบสมบูรณ์
-- (คนที่เปิด view-source เว็บแล้วคัดลอก header ไปใช้ตรงๆ ยังบายพาสได้ เหมือน anon key เดิม)
-- ================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------
-- 1) ฟังก์ชันตรวจ header ลับ — ต้อง match กับ APP_KEY ใน index.html ทุกตัวอักษร
-- ---------------------------------------------------------------
create or replace function public.app_authorized()
returns boolean
language sql
stable
as $$
  select coalesce(
    current_setting('request.headers', true)::json->>'x-app-key',
    ''
  ) = '49790950ea1d82dcf4a1cb68e4cdb53a7e6c6ad5f97a0236';
$$;

-- ---------------------------------------------------------------
-- 2) ล็อกคอลัมน์รหัสผ่านครู — เว็บไม่เคย SELECT/UPDATE คอลัมน์นี้ตรงๆ อยู่แล้ว
--    (ใช้ RPC login/admin_create_teacher/admin_set_password/teacher_change_password เท่านั้น)
--    ต้อง revoke สิทธิ์ระดับ "ทั้งตาราง" ก่อน แล้ว grant กลับเฉพาะคอลัมน์ที่ไม่ใช่ password
--    (revoke แค่ระดับคอลัมน์เดียวไม่พอ เพราะสิทธิ์ระดับตารางที่มีอยู่เดิมครอบคลุมทุกคอลัมน์
--    อยู่แล้ว — คำนวณรายชื่อคอลัมน์อัตโนมัติ กันตกหล่นคอลัมน์ที่เพิ่มนอกไฟล์ .sql)
-- ---------------------------------------------------------------
do $$
declare
  cols text;
begin
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position)
  into cols
  from information_schema.columns
  where table_schema = 'public' and table_name = 'teachers' and column_name <> 'password';

  if cols is null then
    raise exception 'ไม่พบตาราง teachers หรือไม่มีคอลัมน์อื่นนอกจาก password — ตรวจสอบด้วยตนเอง';
  end if;

  execute 'revoke select, update on public.teachers from anon, authenticated;';
  execute format('grant select (%s) on public.teachers to anon, authenticated;', cols);
  execute format('grant update (%s) on public.teachers to anon, authenticated;', cols);
end $$;

-- ---------------------------------------------------------------
-- 3) เปิด RLS ทุกตาราง + policy เดียวที่ต้องมี header ลับถึงจะเข้าถึงได้
--    (คง behavior เดิม 100% สำหรับเว็บที่ส่ง header — บล็อกเฉพาะ bot/สแกนที่ไม่รู้ header)
--    ลบ policy เก่าทุกตัวก่อนเสมอ (ไม่ว่าชื่ออะไร) — กันกรณีมี policy เดิมที่อนุญาตกว้างๆ
--    ค้างอยู่จากยุคก่อน (PERMISSIVE policies รวมกันด้วย OR ถ้าเหลือ policy เก่าไว้
--    policy ใหม่จะถูกมองข้ามไปเลย)
-- ---------------------------------------------------------------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array[
    'students','classrooms','teaching_assignments','morning_attendance','home_visits',
    'activity_enrollments','behavior_records','activities','score_summary','room_teachers',
    'mh_assessments','teachers','subject_attendance','timetable','good_deeds',
    'grade_structures','system_settings','enrollments','grades','exam_subjects',
    'activity_teachers','afternoon_attendance','behavior_categories','assignment_teachers',
    'subjects','good_deed_categories','activity_attendance','parents','exam_results',
    'push_subscriptions','login_events','audit_log','user_permissions',
    'grade_history','sdq_records',
    'oe_exams','oe_questions','oe_options','oe_attempts','oe_answers','oe_events'
  ]
  loop
    if to_regclass('public.'||t) is null then
      continue; -- ตารางนี้ยังไม่ถูกสร้าง (ปกติสำหรับโปรเจกต์ที่ยังไม่ได้รันทุกโมดูล) — ข้าม
    end if;

    for p in
      select policyname from pg_policies
      where schemaname = 'public' and tablename = t
    loop
      execute format('drop policy if exists %I on public.%I;', p.policyname, t);
    end loop;

    execute format('alter table public.%I enable row level security;', t);
    execute format(
      'create policy app_access on public.%I for all using (public.app_authorized()) with check (public.app_authorized());',
      t
    );
  end loop;
end $$;

-- ---------------------------------------------------------------
-- 4) เพิ่มการตรวจ header ลับใน RPC สำคัญที่แตะรหัสผ่าน/ล็อกอิน
--    เพราะฟังก์ชันเหล่านี้เป็น SECURITY DEFINER (ข้าม RLS ของตารางได้อยู่แล้วโดยดีไซน์)
--    ถ้าไม่เช็คในนี้ด้วย บอทจะยังยิง /rpc/login ตรงๆ ได้แม้ตารางจะล็อกแล้ว
-- ---------------------------------------------------------------
create or replace function login(p_username TEXT, p_password TEXT)
returns table(id INT, username TEXT, fullname TEXT, role TEXT) as $$
begin
  if not public.app_authorized() then
    raise exception 'unauthorized';
  end if;
  return query
  select t.id, t.username, t.fullname, t.role
  from teachers t
  where t.username = p_username
    and t.password = crypt(p_password, t.password)
    and t.active = true;
end;
$$ language plpgsql security definer;

create or replace function admin_create_teacher(
  p_username TEXT, p_password TEXT, p_fullname TEXT, p_role TEXT default 'teacher'
) returns INT as $$
declare
  v_id int;
begin
  if not public.app_authorized() then
    raise exception 'unauthorized';
  end if;
  insert into teachers(username, password, fullname, role, active)
  values (lower(trim(p_username)), crypt(p_password, gen_salt('bf')), trim(p_fullname),
          coalesce(nullif(trim(p_role),''),'teacher'), true)
  returning id into v_id;
  return v_id;
end;
$$ language plpgsql security definer;

create or replace function admin_set_password(
  p_teacher_id INT, p_new_password TEXT
) returns void as $$
begin
  if not public.app_authorized() then
    raise exception 'unauthorized';
  end if;
  update teachers set password = crypt(p_new_password, gen_salt('bf'))
  where id = p_teacher_id;
end;
$$ language plpgsql security definer;

create or replace function teacher_change_password(
  p_teacher_id INT, p_new_password TEXT
) returns void as $$
begin
  if not public.app_authorized() then
    raise exception 'unauthorized';
  end if;
  update teachers set password = crypt(p_new_password, gen_salt('bf'))
  where id = p_teacher_id;
end;
$$ language plpgsql security definer;

create or replace function calc_score_summary(p_student_id INTEGER)
returns void as $$
declare
  v_good INTEGER;
  v_bad INTEGER;
begin
  if not public.app_authorized() then
    raise exception 'unauthorized';
  end if;
  select coalesce(sum(score),0) into v_good from good_deeds where student_id = p_student_id;
  select coalesce(sum(score),0) into v_bad from behavior_records where student_id = p_student_id;
  insert into score_summary (student_id, good_score, bad_score, net_score, updated_at)
  values (p_student_id, v_good, v_bad, v_good + v_bad, now())
  on conflict (student_id)
  do update set good_score=v_good, bad_score=v_bad, net_score=v_good+v_bad, updated_at=now();
end;
$$ language plpgsql security definer;

notify pgrst, 'reload schema';

-- ================================================================
-- ตรวจผลหลังรันเสร็จ — รันทีละคำสั่ง:
--
-- 1) เหลือ policy เดียวชื่อ app_access ต่อตาราง:
--      select tablename, policyname from pg_policies where tablename='teachers';
--
-- 2) password ต้องไม่มี anon/authenticated ใน SELECT/UPDATE:
--      select grantee, privilege_type from information_schema.column_privileges
--      where table_name='teachers' and column_name='password';
--
-- 3) ทดสอบจริงจาก terminal (ไม่ใส่ header x-app-key) ต้องได้ [] :
--      curl "<SUPABASE_URL>/rest/v1/teachers?select=id,username" \
--        -H "apikey: <ANON_KEY>" -H "Authorization: Bearer <ANON_KEY>"
--
-- 4) เปิดเว็บจริง (index.html) ทดสอบใช้งานทุกโมดูลให้ครบ ต้องเหมือนเดิมทุกอย่าง
--    (โดยเฉพาะ: บันทึกทางลัด/แก้ไขข้อมูลครู/ตั้งสิทธิ์ครู เพราะจุดนี้แตะ UPDATE ตรงบน teachers)
-- ================================================================
