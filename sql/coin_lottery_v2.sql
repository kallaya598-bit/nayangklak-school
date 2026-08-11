-- ============================================================================
-- Subject Coin + Number Lottery V2
-- โรงเรียนนายางกลักพิทยาคม
--
-- Additive migration only:
--   * ไม่ลบ/เปลี่ยนความหมายตาราง coin/lottery รุ่นเดิม
--   * กระเป๋าและข้อมูลทุกชนิดแยกด้วย teaching_assignment + ภาคเรียน
--   * ตารางส่วนตัวไม่เปิด REST ตรง การอ่าน/เขียนต้องผ่าน SECURITY DEFINER RPC
--   * รันซ้ำได้ (idempotent DDL)
-- ============================================================================

create extension if not exists pgcrypto;

-- คะแนนบางงานเท่านั้นที่รับคูปองคะแนนโบนัสได้ ครูต้องเปิดเอง
alter table public.grade_structures
  add column if not exists coupon_eligible boolean not null default false;

create table if not exists public.reward_assignment_settings (
  assignment_id integer primary key references public.teaching_assignments(id) on delete restrict,
  school_year integer not null,
  semester integer not null check (semester in (1,2)),
  enabled boolean not null default false,
  enabled_at timestamptz,
  disabled_at timestamptz,
  opening_balance integer not null default 0 check (opening_balance >= 0),
  attendance_coin integer not null default 1 check (attendance_coin >= 0),
  weekly_bonus integer not null default 2 check (weekly_bonus >= 0),
  duplicate_warning_minutes integer not null default 10 check (duplicate_warning_minutes >= 0),
  duplicate_warning_count integer not null default 2 check (duplicate_warning_count >= 1),
  created_by integer references public.teachers(id),
  updated_by integer references public.teachers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reward_wallets (
  id bigserial primary key,
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  student_id integer not null references public.students(id) on delete restrict,
  school_year integer not null,
  semester integer not null check (semester in (1,2)),
  balance integer not null default 0 check (balance >= 0),
  version bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assignment_id, student_id)
);

create table if not exists public.reward_ledger (
  id bigserial primary key,
  wallet_id bigint not null references public.reward_wallets(id) on delete restrict,
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  student_id integer not null references public.students(id) on delete restrict,
  amount integer not null check (amount <> 0),
  balance_after integer not null check (balance_after >= 0),
  entry_type text not null check (entry_type in (
    'opening','attendance','weekly_bonus','teacher_grant','ranking_reward',
    'lottery_purchase','wheel_reward','refund','reversal','admin_correction'
  )),
  source_type text not null,
  source_id text,
  reason text not null,
  student_note text,
  private_note text,
  rank_eligible boolean not null default false,
  actor_teacher_id integer references public.teachers(id),
  idempotency_key text not null unique,
  reversal_of bigint references public.reward_ledger(id) on delete restrict,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists reward_ledger_one_reversal_uq
  on public.reward_ledger(reversal_of) where reversal_of is not null;
create index if not exists reward_ledger_assignment_student_idx
  on public.reward_ledger(assignment_id,student_id,created_at desc);
create index if not exists reward_ledger_rank_idx
  on public.reward_ledger(assignment_id,created_at,student_id)
  where rank_eligible=true;

create table if not exists public.reward_activity_templates (
  id bigserial primary key,
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  title text not null,
  coin_amount integer not null check (coin_amount > 0),
  icon text not null default '⭐',
  active boolean not null default true,
  created_by integer not null references public.teachers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(assignment_id,title)
);

create table if not exists public.reward_grant_batches (
  id uuid primary key default gen_random_uuid(),
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  template_id bigint references public.reward_activity_templates(id) on delete set null,
  amount integer not null check (amount > 0),
  reason text not null,
  student_note text,
  private_note text,
  created_by integer not null references public.teachers(id),
  created_at timestamptz not null default now()
);

create table if not exists public.reward_subject_sessions (
  id bigserial primary key,
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  timetable_id integer references public.timetable(id) on delete set null,
  session_date date not null,
  period integer not null check (period between 1 and 8),
  status text not null default 'scheduled' check (status in ('scheduled','completed','cancelled')),
  cancellation_reason text,
  recorded_by integer references public.teachers(id),
  recorded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(assignment_id,session_date,period)
);

create index if not exists reward_subject_sessions_week_idx
  on public.reward_subject_sessions(assignment_id,session_date,status);

create table if not exists public.reward_attendance_awards (
  session_id bigint not null references public.reward_subject_sessions(id) on delete restrict,
  student_id integer not null references public.students(id) on delete restrict,
  current_ledger_id bigint references public.reward_ledger(id) on delete restrict,
  version integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key(session_id,student_id)
);

create table if not exists public.reward_weekly_states (
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  student_id integer not null references public.students(id) on delete restrict,
  week_start date not null,
  qualified boolean not null default false,
  current_ledger_id bigint references public.reward_ledger(id) on delete restrict,
  version integer not null default 0,
  evaluated_at timestamptz not null default now(),
  primary key(assignment_id,student_id,week_start)
);

create table if not exists public.reward_notifications (
  id bigserial primary key,
  assignment_id integer references public.teaching_assignments(id) on delete restrict,
  recipient_type text not null check (recipient_type in ('student','teacher')),
  student_id integer references public.students(id) on delete cascade,
  teacher_id integer references public.teachers(id) on delete cascade,
  event_type text not null,
  title text not null,
  body text not null,
  entity_type text,
  entity_id text,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  check (
    (recipient_type='student' and student_id is not null and teacher_id is null)
    or (recipient_type='teacher' and teacher_id is not null and student_id is null)
  )
);

create index if not exists reward_notifications_student_idx
  on public.reward_notifications(student_id,created_at desc) where student_id is not null;
create index if not exists reward_notifications_teacher_idx
  on public.reward_notifications(teacher_id,created_at desc) where teacher_id is not null;

-- ===== Number lottery =====
create table if not exists public.lottery_rounds_v2 (
  id bigserial primary key,
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  school_year integer not null,
  semester integer not null check (semester in (1,2)),
  title text not null,
  description text,
  price_two integer not null default 5 check (price_two > 0),
  price_three integer not null default 7 check (price_three > 0),
  total_tickets integer,
  two_ticket_count integer,
  three_ticket_count integer,
  sale_opens_at timestamptz not null,
  sale_closes_at timestamptz not null,
  draw_at timestamptz not null,
  draw_period integer check (draw_period between 1 and 8),
  status text not null default 'draft' check (status in (
    'draft','board_ready','open','sold_out','closed','drawing',
    'pending_confirmation','confirmed','completed','archived','cancelled'
  )),
  board_seed uuid,
  board_version integer not null default 0,
  board_confirmed_at timestamptz,
  board_confirmed_by integer references public.teachers(id),
  created_by integer not null references public.teachers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (sale_closes_at > sale_opens_at),
  check (draw_at >= sale_closes_at),
  check (total_tickets is null or total_tickets % 4 = 0),
  check (two_ticket_count is null or two_ticket_count % 2 = 0),
  check (three_ticket_count is null or three_ticket_count % 2 = 0)
);

-- ชื่อตารางอาจมีอยู่จากการทดลองรุ่นก่อน จึงปรับ constraint ให้รองรับสถานะปิดงวดด้วย
alter table public.lottery_rounds_v2 drop constraint if exists lottery_rounds_v2_status_check;
alter table public.lottery_rounds_v2 add constraint lottery_rounds_v2_status_check check (status in (
  'draft','board_ready','open','sold_out','closed','drawing',
  'pending_confirmation','confirmed','completed','archived','cancelled'
));

create index if not exists lottery_rounds_v2_assignment_idx
  on public.lottery_rounds_v2(assignment_id,created_at desc);

create table if not exists public.lottery_ticket_inventory (
  id bigserial primary key,
  round_id bigint not null references public.lottery_rounds_v2(id) on delete restrict,
  ticket_type text not null check (ticket_type in ('two','three')),
  number_text text not null,
  copy_code text not null check (copy_code in ('A','B')),
  sold_to integer references public.students(id) on delete restrict,
  sold_at timestamptz,
  purchase_id bigint,
  reserved_cart_id uuid,
  reserved_until timestamptz,
  voided_at timestamptz,
  created_at timestamptz not null default now(),
  unique(round_id,ticket_type,number_text,copy_code),
  check (
    (ticket_type='two' and number_text ~ '^[0-9]{2}$')
    or (ticket_type='three' and number_text ~ '^[0-9]{3}$')
  ),
  check ((sold_to is null and sold_at is null) or (sold_to is not null and sold_at is not null))
);

create index if not exists lottery_ticket_inventory_board_idx
  on public.lottery_ticket_inventory(round_id,ticket_type,number_text,copy_code);
create index if not exists lottery_ticket_inventory_student_idx
  on public.lottery_ticket_inventory(sold_to,round_id) where sold_to is not null;

create table if not exists public.lottery_carts (
  id uuid primary key default gen_random_uuid(),
  round_id bigint not null references public.lottery_rounds_v2(id) on delete restrict,
  student_id integer not null references public.students(id) on delete restrict,
  state text not null default 'active' check (state in ('active','purchased','expired','released')),
  request_key text not null unique,
  expires_at timestamptz not null,
  purchased_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists lottery_carts_one_active_per_student_uq
  on public.lottery_carts(student_id) where state='active';

create table if not exists public.lottery_purchases (
  id bigserial primary key,
  cart_id uuid not null unique references public.lottery_carts(id) on delete restrict,
  round_id bigint not null references public.lottery_rounds_v2(id) on delete restrict,
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  student_id integer not null references public.students(id) on delete restrict,
  total_coins integer not null check (total_coins > 0),
  ledger_id bigint not null unique references public.reward_ledger(id) on delete restrict,
  idempotency_key text not null unique,
  purchased_at timestamptz not null default now()
);

alter table public.lottery_ticket_inventory
  drop constraint if exists lottery_ticket_inventory_purchase_id_fkey;
alter table public.lottery_ticket_inventory
  add constraint lottery_ticket_inventory_purchase_id_fkey
  foreign key(purchase_id) references public.lottery_purchases(id) on delete restrict;

create table if not exists public.lottery_purchase_items (
  purchase_id bigint not null references public.lottery_purchases(id) on delete restrict,
  ticket_id bigint not null unique references public.lottery_ticket_inventory(id) on delete restrict,
  ticket_type text not null check (ticket_type in ('two','three')),
  number_text text not null,
  copy_code text not null check (copy_code in ('A','B')),
  price_paid integer not null check (price_paid > 0),
  primary key(purchase_id,ticket_id)
);

create table if not exists public.lottery_draws_v2 (
  id bigserial primary key,
  round_id bigint not null unique references public.lottery_rounds_v2(id) on delete restrict,
  seed uuid not null,
  status text not null default 'pending' check (status in ('pending','confirmed')),
  drawn_by integer not null references public.teachers(id),
  drawn_at timestamptz not null default now(),
  confirmed_by integer references public.teachers(id),
  confirmed_at timestamptz
);

create table if not exists public.lottery_draw_results (
  id bigserial primary key,
  draw_id bigint not null references public.lottery_draws_v2(id) on delete restrict,
  result_slot text not null check (result_slot in ('two_first','two_second','three')),
  ticket_type text not null check (ticket_type in ('two','three')),
  number_text text not null,
  created_at timestamptz not null default now(),
  unique(draw_id,result_slot)
);

create table if not exists public.lottery_winner_rights (
  id bigserial primary key,
  round_id bigint not null references public.lottery_rounds_v2(id) on delete restrict,
  result_id bigint not null references public.lottery_draw_results(id) on delete restrict,
  ticket_id bigint not null references public.lottery_ticket_inventory(id) on delete restrict,
  student_id integer not null references public.students(id) on delete restrict,
  ticket_type text not null check (ticket_type in ('two','three')),
  spin_status text not null default 'ready' check (spin_status in ('ready','spun')),
  created_at timestamptz not null default now(),
  unique(result_id,ticket_id)
);

create table if not exists public.reward_wheel_prizes (
  id bigserial primary key,
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  wheel_type text not null check (wheel_type in ('two','three')),
  title text not null,
  prize_kind text not null check (prize_kind in ('coin','item','privilege','score')),
  amount integer,
  weight numeric(10,4) not null default 1 check (weight > 0),
  active boolean not null default true,
  created_by integer references public.teachers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reward_wheel_spins (
  id bigserial primary key,
  winner_right_id bigint not null unique references public.lottery_winner_rights(id) on delete restrict,
  prize_id bigint not null references public.reward_wheel_prizes(id) on delete restrict,
  student_id integer not null references public.students(id) on delete restrict,
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  seed uuid not null,
  ledger_id bigint references public.reward_ledger(id) on delete restrict,
  spun_by integer not null references public.teachers(id),
  spun_at timestamptz not null default now()
);

create table if not exists public.reward_coupons (
  id bigserial primary key,
  coupon_code text not null unique,
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  round_id bigint references public.lottery_rounds_v2(id) on delete restrict,
  student_id integer not null references public.students(id) on delete restrict,
  spin_id bigint unique references public.reward_wheel_spins(id) on delete restrict,
  coupon_kind text not null check (coupon_kind in ('item','privilege','score')),
  title text not null,
  amount integer,
  status text not null default 'issued' check (status in ('issued','redeemed','expired','voided')),
  expires_on date not null,
  allowed_grade_structure_id integer references public.grade_structures(id) on delete restrict,
  redeemed_grade_structure_id integer references public.grade_structures(id) on delete restrict,
  redeemed_by integer references public.teachers(id),
  redeemed_at timestamptz,
  delivery_note text,
  created_at timestamptz not null default now()
);

create index if not exists reward_coupons_student_idx
  on public.reward_coupons(student_id,status,expires_on);

create table if not exists public.reward_ranking_prizes (
  id bigserial primary key,
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  period_type text not null check (period_type in ('weekly','monthly')),
  title text not null,
  prize_kind text not null check (prize_kind in ('coin','item','privilege','score')),
  amount integer,
  active boolean not null default true,
  created_by integer references public.teachers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (prize_kind not in ('coin','score') or amount>0),
  unique(assignment_id,period_type,title)
);

create table if not exists public.reward_ranking_awards (
  id bigserial primary key,
  prize_id bigint not null references public.reward_ranking_prizes(id) on delete restrict,
  assignment_id integer not null references public.teaching_assignments(id) on delete restrict,
  student_id integer not null references public.students(id) on delete restrict,
  period_type text not null check (period_type in ('weekly','monthly')),
  period_start date not null,
  earned_coins integer not null,
  ledger_id bigint references public.reward_ledger(id) on delete restrict,
  coupon_id bigint references public.reward_coupons(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique(prize_id,period_start,student_id)
);

create table if not exists public.reward_job_runs (
  id bigserial primary key,
  job_name text not null,
  run_key text not null unique,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running' check (status in ('running','success','failed')),
  result jsonb,
  error_text text
);

-- ===== RLS: ไม่มี app_access สำหรับข้อมูลส่วนตัว V2 =====
do $$
declare t text;
begin
  foreach t in array array[
    'reward_assignment_settings','reward_wallets','reward_ledger',
    'reward_activity_templates','reward_grant_batches','reward_subject_sessions',
    'reward_attendance_awards','reward_weekly_states','reward_notifications',
    'lottery_rounds_v2','lottery_ticket_inventory','lottery_carts',
    'lottery_purchases','lottery_purchase_items','lottery_draws_v2',
    'lottery_draw_results','lottery_winner_rights','reward_wheel_prizes',
    'reward_wheel_spins','reward_coupons','reward_ranking_prizes',
    'reward_ranking_awards','reward_job_runs'
  ] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from anon, authenticated',t);
  end loop;
end $$;

-- ===== Internal authorization/helpers =====
create or replace function public._reward_v2_teacher(p_token uuid)
returns integer language plpgsql stable security definer
set search_path=public,extensions as $$
declare v_teacher integer;
begin
  if not public.app_authorized() then raise exception 'unauthorized'; end if;
  v_teacher := public.reward_staff_actor(p_token);
  if v_teacher is null then raise exception 'session ครูหมดอายุ'; end if;
  return v_teacher;
end $$;

create or replace function public._reward_v2_student(p_token uuid)
returns integer language plpgsql stable security definer
set search_path=public,extensions as $$
declare v_student integer;
begin
  if not public.app_authorized() then raise exception 'unauthorized'; end if;
  v_student := public.reward_student_actor(p_token);
  if v_student is null then raise exception 'session นักเรียนหมดอายุ'; end if;
  return v_student;
end $$;

create or replace function public._reward_v2_can_manage(p_teacher integer,p_assignment integer)
returns boolean language sql stable security definer
set search_path=public,extensions as $$
  select exists(
    select 1 from public.teachers t
    join public.teaching_assignments ta on ta.id=p_assignment
    where t.id=p_teacher and t.active=true and (
      t.role='admin' or ta.teacher_id=p_teacher or exists(
        select 1 from public.assignment_teachers at
        where at.assignment_id=ta.id and at.teacher_id=p_teacher
          and at.invite_status='accepted'
      )
    )
  )
$$;

create or replace function public._reward_v2_is_enrolled(p_student integer,p_assignment integer)
returns boolean language sql stable security definer
set search_path=public,extensions as $$
  select exists(
    select 1 from public.enrollments e
    where e.assignment_id=p_assignment and e.student_id=p_student and e.status='active'
  )
$$;

create or replace function public._reward_v2_audit(
  p_actor_id integer,p_actor_role text,p_action text,p_entity text,p_entity_id text,
  p_summary text,p_payload jsonb default '{}'::jsonb
) returns void language plpgsql security definer
set search_path=public,extensions as $$
declare v_name text;v_username text;
begin
  if p_actor_role='student' then
    select fullname,student_code into v_name,v_username from public.students where id=p_actor_id;
  else
    select fullname,username into v_name,v_username from public.teachers where id=p_actor_id;
  end if;
  insert into public.audit_log(
    source,actor_id,actor_name,actor_username,actor_role,action,entity,entity_id,summary,path,payload
  ) values(
    'reward-v2',p_actor_id,v_name,v_username,p_actor_role,p_action,p_entity,p_entity_id,
    p_summary,'rpc/reward-v2',coalesce(p_payload,'{}'::jsonb)
  );
exception when undefined_column then
  insert into public.audit_log(user_id,action,table_name,record_id,new_data)
  values(p_actor_id,p_action,p_entity,null,p_payload);
end $$;

create or replace function public._reward_v2_post(
  p_assignment integer,p_student integer,p_amount integer,p_entry_type text,
  p_source_type text,p_source_id text,p_reason text,p_student_note text,
  p_private_note text,p_rank_eligible boolean,p_actor_teacher integer,
  p_idempotency_key text,p_reversal_of bigint default null,p_metadata jsonb default '{}'::jsonb
) returns bigint language plpgsql security definer
set search_path=public,extensions as $$
declare v_wallet public.reward_wallets%rowtype;v_id bigint;v_year integer;v_sem integer;
begin
  if p_amount=0 then raise exception 'จำนวนเหรียญต้องไม่เป็น 0'; end if;
  select id into v_id from public.reward_ledger where idempotency_key=p_idempotency_key;
  if v_id is not null then return v_id; end if;

  if not public._reward_v2_is_enrolled(p_student,p_assignment) then
    raise exception 'นักเรียนไม่ได้ลงทะเบียนในกลุ่มเรียนนี้';
  end if;
  select year,semester into v_year,v_sem from public.teaching_assignments where id=p_assignment;
  if v_year is null then raise exception 'ไม่พบกลุ่มเรียน'; end if;

  insert into public.reward_wallets(assignment_id,student_id,school_year,semester)
  values(p_assignment,p_student,v_year,v_sem)
  on conflict(assignment_id,student_id) do nothing;

  select * into v_wallet from public.reward_wallets
  where assignment_id=p_assignment and student_id=p_student for update;
  if v_wallet.balance+p_amount<0 then raise exception 'เหรียญไม่เพียงพอ'; end if;

  insert into public.reward_ledger(
    wallet_id,assignment_id,student_id,amount,balance_after,entry_type,
    source_type,source_id,reason,student_note,private_note,rank_eligible,
    actor_teacher_id,idempotency_key,reversal_of,metadata
  ) values(
    v_wallet.id,p_assignment,p_student,p_amount,v_wallet.balance+p_amount,p_entry_type,
    p_source_type,p_source_id,p_reason,p_student_note,p_private_note,coalesce(p_rank_eligible,false),
    p_actor_teacher,p_idempotency_key,p_reversal_of,coalesce(p_metadata,'{}'::jsonb)
  ) returning id into v_id;

  update public.reward_wallets
  set balance=balance+p_amount,version=version+1,updated_at=now()
  where id=v_wallet.id;
  return v_id;
end $$;

create or replace function public._reward_v2_add_school_days(p_start date,p_days integer)
returns date language plpgsql immutable as $$
declare v_date date:=p_start;v_count integer:=0;
begin
  while v_count<p_days loop
    v_date:=v_date+1;
    if extract(isodow from v_date) between 1 and 5 then v_count:=v_count+1; end if;
  end loop;
  return v_date;
end $$;

-- ===== Teacher configuration/grants =====
create or replace function public.reward_v2_set_assignment(
  p_token uuid,p_assignment_id integer,p_enabled boolean,p_opening_balance integer default 0,
  p_duplicate_warning_minutes integer default 10,p_duplicate_warning_count integer default 2
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_ta public.teaching_assignments%rowtype;v_student record;v_ledger bigint;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  if not public._reward_v2_can_manage(v_teacher,p_assignment_id) then raise exception 'ไม่มีสิทธิ์จัดการรายวิชานี้'; end if;
  if p_opening_balance<0 then raise exception 'เหรียญตั้งต้นต้องไม่ติดลบ'; end if;
  select * into v_ta from public.teaching_assignments where id=p_assignment_id;
  if v_ta.id is null then raise exception 'ไม่พบกลุ่มเรียน'; end if;
  if not p_enabled and exists(
    select 1 from public.lottery_rounds_v2 r where r.assignment_id=p_assignment_id
      and r.status not in ('completed','cancelled')
  ) then
    raise exception 'ปิดโมดูลไม่ได้ขณะมีงวดที่ยังไม่จบ';
  end if;

  insert into public.reward_assignment_settings(
    assignment_id,school_year,semester,enabled,enabled_at,disabled_at,opening_balance,
    duplicate_warning_minutes,duplicate_warning_count,created_by,updated_by
  ) values(
    p_assignment_id,v_ta.year,v_ta.semester,p_enabled,
    case when p_enabled then now() else null end,case when p_enabled then null else now() end,
    p_opening_balance,p_duplicate_warning_minutes,p_duplicate_warning_count,v_teacher,v_teacher
  ) on conflict(assignment_id) do update set
    enabled=excluded.enabled,
    enabled_at=case when excluded.enabled and not reward_assignment_settings.enabled then now() else reward_assignment_settings.enabled_at end,
    disabled_at=case when not excluded.enabled then now() else null end,
    opening_balance=excluded.opening_balance,
    duplicate_warning_minutes=excluded.duplicate_warning_minutes,
    duplicate_warning_count=excluded.duplicate_warning_count,
    updated_by=v_teacher,updated_at=now();

  if p_enabled and p_opening_balance>0 then
    for v_student in select student_id from public.enrollments where assignment_id=p_assignment_id and status='active' loop
      v_ledger:=public._reward_v2_post(
        p_assignment_id,v_student.student_id,p_opening_balance,'opening','assignment',p_assignment_id::text,
        'เหรียญตั้งต้นรายวิชา',null,null,false,v_teacher,
        'opening:'||p_assignment_id||':'||v_student.student_id,null,'{}'::jsonb
      );
    end loop;
  end if;

  if p_enabled and not exists(select 1 from public.reward_wheel_prizes where assignment_id=p_assignment_id) then
    insert into public.reward_wheel_prizes(assignment_id,wheel_type,title,prize_kind,amount,weight,created_by) values
      (p_assignment_id,'two','ขนมชิ้นเล็ก','item',null,1,v_teacher),
      (p_assignment_id,'two','ปากกาหรือดินสอ','item',null,1,v_teacher),
      (p_assignment_id,'two','สมุดหรือสติกเกอร์','item',null,1,v_teacher),
      (p_assignment_id,'two','เหรียญ 5','coin',5,1,v_teacher),
      (p_assignment_id,'two','เหรียญ 10','coin',10,1,v_teacher),
      (p_assignment_id,'two','เลือกที่นั่ง 1 คาบ','privilege',null,1,v_teacher),
      (p_assignment_id,'two','ส่งงานช้าได้ 1 วัน','privilege',null,1,v_teacher),
      (p_assignment_id,'two','คะแนนโบนัส 1 คะแนน','score',1,1,v_teacher),
      (p_assignment_id,'three','ขนมชุดใหญ่','item',null,1,v_teacher),
      (p_assignment_id,'three','ชุดเครื่องเขียน','item',null,1,v_teacher),
      (p_assignment_id,'three','เหรียญ 15','coin',15,1,v_teacher),
      (p_assignment_id,'three','เหรียญ 20','coin',20,1,v_teacher),
      (p_assignment_id,'three','เลือกที่นั่ง 1 สัปดาห์','privilege',null,1,v_teacher),
      (p_assignment_id,'three','ยกเว้นงานย่อย 1 ชิ้น','privilege',null,1,v_teacher),
      (p_assignment_id,'three','คะแนนโบนัส 2 คะแนน','score',2,1,v_teacher),
      (p_assignment_id,'three','รางวัลพิเศษประจำงวด','item',null,1,v_teacher);
  end if;

  perform public._reward_v2_audit(v_teacher,'teacher','configure','reward_assignment_settings',p_assignment_id::text,
    case when p_enabled then 'เปิดโมดูลเหรียญรายวิชา' else 'ปิดโมดูลเหรียญรายวิชา' end,
    jsonb_build_object('enabled',p_enabled,'opening_balance',p_opening_balance));
  return jsonb_build_object('ok',true,'enabled',p_enabled,'assignment_id',p_assignment_id);
end $$;

create or replace function public.reward_v2_grant(
  p_token uuid,p_assignment_id integer,p_student_ids integer[],p_amount integer,p_reason text,
  p_student_note text default null,p_private_note text default null,p_template_id bigint default null
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_batch uuid;v_student integer;v_count integer:=0;v_warning_count integer:=0;
  v_warn_minutes integer:=10;v_warn_threshold integer:=2;v_recent integer;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  if not public._reward_v2_can_manage(v_teacher,p_assignment_id) then raise exception 'ไม่มีสิทธิ์จัดการรายวิชานี้'; end if;
  if p_amount<=0 then raise exception 'ครูเพิ่มเหรียญได้เท่านั้น'; end if;
  if nullif(trim(p_reason),'') is null then raise exception 'กรุณาระบุเหตุผลหรือกิจกรรม'; end if;
  if coalesce(array_length(p_student_ids,1),0)=0 then raise exception 'กรุณาเลือกนักเรียน'; end if;
  if not exists(select 1 from public.reward_assignment_settings where assignment_id=p_assignment_id and enabled=true) then
    raise exception 'รายวิชานี้ยังไม่ได้เปิดโมดูลเหรียญ';
  end if;
  select duplicate_warning_minutes,duplicate_warning_count into v_warn_minutes,v_warn_threshold
  from public.reward_assignment_settings where assignment_id=p_assignment_id;

  insert into public.reward_grant_batches(assignment_id,template_id,amount,reason,student_note,private_note,created_by)
  values(p_assignment_id,p_template_id,p_amount,trim(p_reason),nullif(trim(p_student_note),''),nullif(trim(p_private_note),''),v_teacher)
  returning id into v_batch;

  foreach v_student in array p_student_ids loop
    if not public._reward_v2_is_enrolled(v_student,p_assignment_id) then
      raise exception 'นักเรียน % ไม่ได้อยู่ในกลุ่มเรียน',v_student;
    end if;
    select count(*) into v_recent from public.reward_ledger
    where assignment_id=p_assignment_id and student_id=v_student and entry_type='teacher_grant'
      and amount=p_amount and reason=trim(p_reason)
      and created_at>=now()-make_interval(mins=>v_warn_minutes);
    if v_recent>=v_warn_threshold-1 then v_warning_count:=v_warning_count+1; end if;
    perform public._reward_v2_post(
      p_assignment_id,v_student,p_amount,'teacher_grant','grant_batch',v_batch::text,
      trim(p_reason),nullif(trim(p_student_note),''),nullif(trim(p_private_note),''),true,v_teacher,
      'grant:'||v_batch||':'||v_student,null,jsonb_build_object('template_id',p_template_id)
    );
    insert into public.reward_notifications(assignment_id,recipient_type,student_id,event_type,title,body,entity_type,entity_id)
    values(p_assignment_id,'student',v_student,'coin_received','ได้รับเหรียญ',trim(p_reason)||' +'||p_amount||' เหรียญ','grant_batch',v_batch::text);
    v_count:=v_count+1;
  end loop;
  perform public._reward_v2_audit(v_teacher,'teacher','grant','reward_grant_batches',v_batch::text,
    'เพิ่มเหรียญให้นักเรียน '||v_count||' คน',jsonb_build_object('amount',p_amount,'count',v_count,'reason',trim(p_reason)));
  return jsonb_build_object('ok',true,'batch_id',v_batch,'count',v_count,'duplicate_warnings',v_warning_count);
end $$;

create or replace function public.reward_v2_reverse_ledger(
  p_token uuid,p_ledger_id bigint,p_reason text
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_old public.reward_ledger%rowtype;v_new bigint;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  select * into v_old from public.reward_ledger where id=p_ledger_id for update;
  if v_old.id is null then raise exception 'ไม่พบรายการเหรียญ'; end if;
  if not public._reward_v2_can_manage(v_teacher,v_old.assignment_id) then raise exception 'ไม่มีสิทธิ์กลับรายการนี้'; end if;
  if v_old.entry_type in ('lottery_purchase') then raise exception 'สลากที่ซื้อแล้วไม่สามารถคืนเหรียญได้'; end if;
  if exists(select 1 from public.reward_ledger where reversal_of=v_old.id) then raise exception 'รายการนี้ถูกกลับรายการแล้ว'; end if;
  if nullif(trim(p_reason),'') is null then raise exception 'กรุณาระบุเหตุผลการแก้ไข'; end if;
  v_new:=public._reward_v2_post(
    v_old.assignment_id,v_old.student_id,-v_old.amount,'reversal','ledger',v_old.id::text,
    'แก้ไขรายการ: '||trim(p_reason),null,null,v_old.rank_eligible,v_teacher,
    'manual-reversal:'||v_old.id,v_old.id,jsonb_build_object('original_type',v_old.entry_type)
  );
  perform public._reward_v2_audit(v_teacher,'teacher','reverse','reward_ledger',v_old.id::text,
    'กลับรายการเหรียญ',jsonb_build_object('reversal_id',v_new,'reason',trim(p_reason)));
  return jsonb_build_object('ok',true,'reversal_id',v_new);
end $$;

create or replace function public.reward_v2_save_template(
  p_token uuid,p_assignment_id integer,p_template_id bigint,p_title text,
  p_coin_amount integer,p_icon text default '⭐',p_active boolean default true
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_id bigint;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  if not public._reward_v2_can_manage(v_teacher,p_assignment_id) then raise exception 'ไม่มีสิทธิ์จัดการรายวิชานี้'; end if;
  if nullif(trim(p_title),'') is null or p_coin_amount<=0 then raise exception 'ชื่อกิจกรรมและจำนวนเหรียญไม่ถูกต้อง'; end if;
  if p_template_id is null then
    insert into public.reward_activity_templates(assignment_id,title,coin_amount,icon,active,created_by)
    values(p_assignment_id,trim(p_title),p_coin_amount,coalesce(nullif(trim(p_icon),''),'⭐'),p_active,v_teacher)
    returning id into v_id;
  else
    update public.reward_activity_templates set title=trim(p_title),coin_amount=p_coin_amount,
      icon=coalesce(nullif(trim(p_icon),''),'⭐'),active=p_active,updated_at=now()
    where id=p_template_id and assignment_id=p_assignment_id returning id into v_id;
    if v_id is null then raise exception 'ไม่พบแม่แบบ'; end if;
  end if;
  perform public._reward_v2_audit(v_teacher,'teacher','save','reward_activity_templates',v_id::text,'บันทึกแม่แบบกิจกรรม',jsonb_build_object('amount',p_coin_amount,'active',p_active));
  return jsonb_build_object('ok',true,'template_id',v_id);
end $$;

create or replace function public.reward_v2_save_wheel_prize(
  p_token uuid,p_assignment_id integer,p_prize_id bigint,p_wheel_type text,p_title text,
  p_prize_kind text,p_amount integer,p_weight numeric,p_active boolean default true
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_id bigint;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  if not public._reward_v2_can_manage(v_teacher,p_assignment_id) then raise exception 'ไม่มีสิทธิ์จัดการวงล้อ'; end if;
  if p_wheel_type not in ('two','three') or p_prize_kind not in ('coin','item','privilege','score') then raise exception 'ประเภทรางวัลไม่ถูกต้อง'; end if;
  if nullif(trim(p_title),'') is null or p_weight<=0 then raise exception 'ชื่อและน้ำหนักรางวัลไม่ถูกต้อง'; end if;
  if p_prize_kind in ('coin','score') and coalesce(p_amount,0)<=0 then raise exception 'กรุณาระบุจำนวนรางวัล'; end if;
  if p_prize_kind='score' and p_amount>3 then raise exception 'คะแนนโบนัสต่อรางวัลต้องไม่เกิน 3'; end if;
  if p_prize_id is null then
    insert into public.reward_wheel_prizes(assignment_id,wheel_type,title,prize_kind,amount,weight,active,created_by)
    values(p_assignment_id,p_wheel_type,trim(p_title),p_prize_kind,p_amount,p_weight,p_active,v_teacher)
    returning id into v_id;
  else
    update public.reward_wheel_prizes set wheel_type=p_wheel_type,title=trim(p_title),prize_kind=p_prize_kind,
      amount=p_amount,weight=p_weight,active=p_active,updated_at=now()
    where id=p_prize_id and assignment_id=p_assignment_id returning id into v_id;
    if v_id is null then raise exception 'ไม่พบรางวัลวงล้อ'; end if;
  end if;
  perform public._reward_v2_audit(v_teacher,'teacher','save','reward_wheel_prizes',v_id::text,'บันทึกรางวัลวงล้อ',jsonb_build_object('wheel_type',p_wheel_type,'kind',p_prize_kind,'weight',p_weight));
  return jsonb_build_object('ok',true,'prize_id',v_id);
end $$;

create or replace function public.reward_v2_save_ranking_prize(
  p_token uuid,p_assignment_id integer,p_prize_id bigint,p_period_type text,
  p_title text,p_prize_kind text,p_amount integer,p_active boolean default true
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_id bigint;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  if not public._reward_v2_can_manage(v_teacher,p_assignment_id) then raise exception 'ไม่มีสิทธิ์ตั้งรางวัลอันดับ'; end if;
  if p_period_type not in ('weekly','monthly') then raise exception 'รอบอันดับไม่ถูกต้อง'; end if;
  if p_prize_kind not in ('coin','item','privilege','score') then raise exception 'ประเภทรางวัลไม่ถูกต้อง'; end if;
  if nullif(trim(p_title),'') is null then raise exception 'กรุณาระบุชื่อรางวัล'; end if;
  if p_prize_kind in ('coin','score') and coalesce(p_amount,0)<=0 then raise exception 'กรุณาระบุจำนวนรางวัล'; end if;
  if p_prize_kind='score' and p_amount>3 then raise exception 'คะแนนโบนัสต่อรางวัลต้องไม่เกิน 3'; end if;
  if p_prize_id is null then
    insert into public.reward_ranking_prizes(assignment_id,period_type,title,prize_kind,amount,active,created_by)
    values(p_assignment_id,p_period_type,trim(p_title),p_prize_kind,p_amount,p_active,v_teacher) returning id into v_id;
  else
    update public.reward_ranking_prizes set period_type=p_period_type,title=trim(p_title),prize_kind=p_prize_kind,
      amount=p_amount,active=p_active,updated_at=now() where id=p_prize_id and assignment_id=p_assignment_id returning id into v_id;
    if v_id is null then raise exception 'ไม่พบรางวัลอันดับ'; end if;
  end if;
  perform public._reward_v2_audit(v_teacher,'teacher','save','reward_ranking_prizes',v_id::text,
    'บันทึกรางวัลอันดับ',jsonb_build_object('period_type',p_period_type,'kind',p_prize_kind,'amount',p_amount,'active',p_active));
  return jsonb_build_object('ok',true,'prize_id',v_id);
end $$;

create or replace function public.reward_v2_delete_wheel_prize(
  p_token uuid,p_assignment_id integer,p_prize_id bigint
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_used boolean;v_title text;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  if not public._reward_v2_can_manage(v_teacher,p_assignment_id) then raise exception 'ไม่มีสิทธิ์จัดการวงล้อ'; end if;
  select title into v_title from public.reward_wheel_prizes where id=p_prize_id and assignment_id=p_assignment_id for update;
  if v_title is null then raise exception 'ไม่พบรางวัลวงล้อ'; end if;
  select exists(select 1 from public.reward_wheel_spins where prize_id=p_prize_id) into v_used;
  if v_used then
    update public.reward_wheel_prizes set active=false,updated_at=now() where id=p_prize_id;
  else
    delete from public.reward_wheel_prizes where id=p_prize_id;
  end if;
  perform public._reward_v2_audit(v_teacher,'teacher','delete','reward_wheel_prizes',p_prize_id::text,
    case when v_used then 'ถอดรางวัลออกจากวงล้อ (เก็บประวัติเดิม)' else 'ลบรางวัลวงล้อ' end,
    jsonb_build_object('title',v_title,'kept_history',v_used));
  return jsonb_build_object('ok',true,'deleted',not v_used,'retired',v_used);
end $$;

-- ===== Attendance sessions and automatic rewards =====
create or replace function public._reward_v2_materialize_week(p_assignment integer,p_week_start date)
returns integer language plpgsql security definer
set search_path=public,extensions as $$
declare v_count integer;
begin
  insert into public.reward_subject_sessions(assignment_id,timetable_id,session_date,period,status)
  select tt.assignment_id,tt.id,
    p_week_start + case tt.day_of_week
      when 'จันทร์' then 0 when 'อังคาร' then 1 when 'พุธ' then 2
      when 'พฤหัสบดี' then 3 when 'ศุกร์' then 4 end,
    tt.period,'scheduled'
  from public.timetable tt
  join public.reward_assignment_settings s on s.assignment_id=tt.assignment_id and s.enabled=true
  where tt.assignment_id=p_assignment
    and tt.day_of_week in ('จันทร์','อังคาร','พุธ','พฤหัสบดี','ศุกร์')
    and (s.enabled_at is null or (p_week_start + case tt.day_of_week
      when 'จันทร์' then 0 when 'อังคาร' then 1 when 'พุธ' then 2
      when 'พฤหัสบดี' then 3 when 'ศุกร์' then 4 end)>=s.enabled_at::date)
  on conflict(assignment_id,session_date,period) do nothing;
  get diagnostics v_count=row_count;
  return v_count;
end $$;

create or replace function public._reward_v2_reconcile_week(p_assignment integer,p_week_start date)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_student record;v_qualified boolean;v_state public.reward_weekly_states%rowtype;
  v_sessions integer;v_bonus integer;v_ledger bigint;v_changed integer:=0;
begin
  perform public._reward_v2_materialize_week(p_assignment,p_week_start);
  select weekly_bonus into v_bonus from public.reward_assignment_settings where assignment_id=p_assignment and enabled=true;
  if v_bonus is null then return jsonb_build_object('changed',0); end if;
  if (now() at time zone 'Asia/Bangkok')::date < p_week_start+7 then
    return jsonb_build_object('changed',0,'pending',true);
  end if;
  select count(*) into v_sessions from public.reward_subject_sessions
  where assignment_id=p_assignment and session_date between p_week_start and p_week_start+6 and status<>'cancelled';

  for v_student in select student_id from public.enrollments where assignment_id=p_assignment and status='active' loop
    select coalesce(v_sessions>0 and bool_and(
      rs.status='completed' and exists(
        select 1 from public.subject_attendance sa
        where sa.assignment_id=p_assignment and sa.student_id=v_student.student_id
          and sa.att_date=rs.session_date and sa.period=rs.period and sa.status='present'
      )
    ),false) into v_qualified
    from public.reward_subject_sessions rs
    where rs.assignment_id=p_assignment and rs.session_date between p_week_start and p_week_start+6
      and rs.status<>'cancelled';

    insert into public.reward_weekly_states(assignment_id,student_id,week_start,qualified)
    values(p_assignment,v_student.student_id,p_week_start,v_qualified)
    on conflict(assignment_id,student_id,week_start) do nothing;
    select * into v_state from public.reward_weekly_states
    where assignment_id=p_assignment and student_id=v_student.student_id and week_start=p_week_start for update;

    if v_qualified and v_state.current_ledger_id is null and v_bonus>0 then
      v_ledger:=public._reward_v2_post(
        p_assignment,v_student.student_id,v_bonus,'weekly_bonus','week',p_week_start::text,
        'โบนัสมาเรียนตรงเวลาครบทุกคาบประจำสัปดาห์',null,null,true,null,
        'weekly:'||p_assignment||':'||v_student.student_id||':'||p_week_start||':'||(v_state.version+1),null,'{}'::jsonb
      );
      update public.reward_weekly_states set qualified=true,current_ledger_id=v_ledger,version=version+1,evaluated_at=now()
      where assignment_id=p_assignment and student_id=v_student.student_id and week_start=p_week_start;
      v_changed:=v_changed+1;
    elsif not v_qualified and v_state.current_ledger_id is not null then
      v_ledger:=public._reward_v2_post(
        p_assignment,v_student.student_id,-v_bonus,'reversal','week',p_week_start::text,
        'ปรับโบนัสรายสัปดาห์หลังแก้ไขเวลาเรียน',null,null,true,null,
        'weekly-reversal:'||v_state.current_ledger_id,v_state.current_ledger_id,'{}'::jsonb
      );
      update public.reward_weekly_states set qualified=false,current_ledger_id=null,version=version+1,evaluated_at=now()
      where assignment_id=p_assignment and student_id=v_student.student_id and week_start=p_week_start;
      v_changed:=v_changed+1;
    else
      update public.reward_weekly_states set qualified=v_qualified,evaluated_at=now()
      where assignment_id=p_assignment and student_id=v_student.student_id and week_start=p_week_start;
    end if;
  end loop;
  return jsonb_build_object('changed',v_changed,'sessions',v_sessions);
end $$;

create or replace function public.reward_v2_save_attendance(
  p_token uuid,p_assignment_id integer,p_att_date date,p_period integer,p_records jsonb,
  p_cancelled boolean default false,p_cancellation_reason text default null,p_timetable_id integer default null
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_session public.reward_subject_sessions%rowtype;v_rec jsonb;v_student integer;v_status text;
  v_award public.reward_attendance_awards%rowtype;v_ledger bigint;v_coin integer:=1;v_count integer:=0;
  v_old_amount integer;v_new_amount integer;v_balance integer;v_week date;v_enabled_at timestamptz;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  if not public._reward_v2_can_manage(v_teacher,p_assignment_id) then raise exception 'ไม่มีสิทธิ์เช็กชื่อกลุ่มเรียนนี้'; end if;
  if p_period not between 1 and 8 then raise exception 'คาบไม่ถูกต้อง'; end if;
  if not exists(select 1 from public.reward_assignment_settings where assignment_id=p_assignment_id and enabled=true) then
    raise exception 'รายวิชานี้ยังไม่ได้เปิดโมดูลเหรียญ';
  end if;
  select attendance_coin,enabled_at into v_coin,v_enabled_at
  from public.reward_assignment_settings where assignment_id=p_assignment_id;

  insert into public.reward_subject_sessions(
    assignment_id,timetable_id,session_date,period,status,cancellation_reason,recorded_by,recorded_at,updated_at
  ) values(
    p_assignment_id,p_timetable_id,p_att_date,p_period,case when p_cancelled then 'cancelled' else 'completed' end,
    case when p_cancelled then nullif(trim(p_cancellation_reason),'') else null end,v_teacher,now(),now()
  ) on conflict(assignment_id,session_date,period) do update set
    timetable_id=coalesce(excluded.timetable_id,reward_subject_sessions.timetable_id),
    status=excluded.status,cancellation_reason=excluded.cancellation_reason,
    recorded_by=v_teacher,recorded_at=now(),updated_at=now()
  returning * into v_session;

  if p_cancelled then
    for v_award in select * from public.reward_attendance_awards where session_id=v_session.id and current_ledger_id is not null for update loop
      select amount into v_old_amount from public.reward_ledger where id=v_award.current_ledger_id;
      v_ledger:=public._reward_v2_post(
        p_assignment_id,v_award.student_id,-v_old_amount,'reversal','attendance_session',v_session.id::text,
        'ปรับเหรียญเนื่องจากงดเรียน',null,null,true,v_teacher,
        'attendance-cancel:'||v_award.current_ledger_id,v_award.current_ledger_id,'{}'::jsonb
      );
      update public.reward_attendance_awards set current_ledger_id=null,version=version+1,updated_at=now()
      where session_id=v_session.id and student_id=v_award.student_id;
    end loop;
  else
    if jsonb_typeof(p_records)<>'array' then raise exception 'รูปแบบรายการเช็กชื่อไม่ถูกต้อง'; end if;
    for v_rec in select value from jsonb_array_elements(p_records) loop
      v_student:=(v_rec->>'student_id')::integer;v_status:=v_rec->>'status';
      if v_status not in ('present','late','absent','leave','gone_home','special_leave','skip') then
        raise exception 'สถานะเช็กชื่อไม่ถูกต้อง';
      end if;
      if not public._reward_v2_is_enrolled(v_student,p_assignment_id) then raise exception 'นักเรียนไม่ได้อยู่ในกลุ่มเรียน'; end if;
      insert into public.subject_attendance(assignment_id,timetable_id,student_id,teacher_id,att_date,period,status,reason)
      values(p_assignment_id,p_timetable_id,v_student,v_teacher,p_att_date,p_period,v_status,nullif(v_rec->>'remark',''))
      on conflict(assignment_id,student_id,att_date,period) do update set
        timetable_id=coalesce(excluded.timetable_id,subject_attendance.timetable_id),teacher_id=v_teacher,
        status=excluded.status,reason=excluded.reason,recorded_at=now();

      -- ไม่แจกย้อนหลังสำหรับคาบก่อนวันที่เปิดโมดูล
      if v_enabled_at is null or p_att_date>=v_enabled_at::date then
        insert into public.reward_attendance_awards(session_id,student_id)
        values(v_session.id,v_student) on conflict(session_id,student_id) do nothing;
        select * into v_award from public.reward_attendance_awards
        where session_id=v_session.id and student_id=v_student for update;

        -- มาเรียนได้เหรียญตามค่ารายวิชา · ขาดเรียนหัก 1 เหรียญ · สถานะอื่นไม่เปลี่ยนเหรียญ
        v_new_amount:=case when v_status='present' then v_coin when v_status='absent' then -1 else 0 end;
        v_old_amount:=0;
        if v_award.current_ledger_id is not null then
          select amount into v_old_amount from public.reward_ledger where id=v_award.current_ledger_id;
        end if;

        -- เมื่อครูแก้สถานะ ให้กลับรายการเดิมตามจำนวนจริงก่อน จึงไม่หัก/แจกซ้ำ
        if v_award.current_ledger_id is not null and v_old_amount<>v_new_amount then
          v_ledger:=public._reward_v2_post(
            p_assignment_id,v_student,-v_old_amount,'reversal','attendance_session',v_session.id::text,
            'ปรับเหรียญหลังแก้ไขเวลาเรียน',null,null,false,v_teacher,
            'attendance-reversal:'||v_award.current_ledger_id,v_award.current_ledger_id,
            jsonb_build_object('new_status',v_status)
          );
          update public.reward_attendance_awards set current_ledger_id=null,version=version+1,updated_at=now()
          where session_id=v_session.id and student_id=v_student;
          v_award.current_ledger_id:=null;v_award.version:=v_award.version+1;
        end if;

        if v_award.current_ledger_id is null and v_new_amount<>0 then
          -- กระเป๋าไม่ติดลบ: ถ้ายังไม่มีเหรียญ การเช็คขาดจะคงยอดไว้ที่ 0
          if v_new_amount<0 then
            select coalesce(max(balance),0) into v_balance from public.reward_wallets
            where assignment_id=p_assignment_id and student_id=v_student;
            if v_balance<abs(v_new_amount) then v_new_amount:=0; end if;
          end if;
        end if;

        if v_award.current_ledger_id is null and v_new_amount<>0 then
          v_ledger:=public._reward_v2_post(
            p_assignment_id,v_student,v_new_amount,'attendance','attendance_session',v_session.id::text,
            case when v_new_amount<0 then 'ขาดเรียน หัก 1 เหรียญ คาบ '||p_period else 'มาเรียนตรงเวลา คาบ '||p_period end,
            null,null,v_new_amount>0,v_teacher,
            'attendance:'||v_session.id||':'||v_student||':'||(v_award.version+1),null,
            jsonb_build_object('date',p_att_date,'period',p_period,'status',v_status)
          );
          update public.reward_attendance_awards set current_ledger_id=v_ledger,version=version+1,updated_at=now()
          where session_id=v_session.id and student_id=v_student;
        end if;
      end if;
      v_count:=v_count+1;
    end loop;
  end if;

  v_week:=p_att_date-(extract(isodow from p_att_date)::integer-1);
  perform public._reward_v2_reconcile_week(p_assignment_id,v_week);
  perform public._reward_v2_audit(v_teacher,'teacher','attendance','reward_subject_sessions',v_session.id::text,
    case when p_cancelled then 'ตั้งคาบเป็นงดเรียน' else 'บันทึกเวลาเรียนและประมวลผลเหรียญ' end,
    jsonb_build_object('date',p_att_date,'period',p_period,'records',v_count,'cancelled',p_cancelled));
  return jsonb_build_object('ok',true,'session_id',v_session.id,'records',v_count,'cancelled',p_cancelled);
end $$;

create or replace function public.reward_v2_clear_attendance(
  p_token uuid,p_assignment_id integer,p_student_id integer,p_att_date date,p_period integer,p_reason text
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_session bigint;v_award public.reward_attendance_awards%rowtype;
  v_old_amount integer;v_reversal bigint;v_week date;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  if not public._reward_v2_can_manage(v_teacher,p_assignment_id) then raise exception 'ไม่มีสิทธิ์แก้เวลาเรียนกลุ่มนี้'; end if;
  if not exists(select 1 from public.reward_assignment_settings where assignment_id=p_assignment_id and enabled=true) then
    raise exception 'รายวิชานี้ยังไม่ได้เปิดโมดูลเหรียญ';
  end if;
  if nullif(trim(p_reason),'') is null then raise exception 'กรุณาระบุเหตุผลการแก้ไข'; end if;
  select id into v_session from public.reward_subject_sessions
  where assignment_id=p_assignment_id and session_date=p_att_date and period=p_period for update;
  if v_session is not null then
    select * into v_award from public.reward_attendance_awards
    where session_id=v_session and student_id=p_student_id for update;
    if v_award.current_ledger_id is not null then
      select amount into v_old_amount from public.reward_ledger where id=v_award.current_ledger_id;
      v_reversal:=public._reward_v2_post(
        p_assignment_id,p_student_id,-v_old_amount,'reversal','attendance_session',v_session::text,
        'ปรับเหรียญหลังล้างสถานะเวลาเรียน',null,null,true,v_teacher,
        'attendance-clear:'||v_award.current_ledger_id,v_award.current_ledger_id,
        jsonb_build_object('reason',trim(p_reason),'date',p_att_date,'period',p_period)
      );
      update public.reward_attendance_awards set current_ledger_id=null,version=version+1,updated_at=now()
      where session_id=v_session and student_id=p_student_id;
    end if;
  end if;
  delete from public.subject_attendance
  where assignment_id=p_assignment_id and student_id=p_student_id and att_date=p_att_date and period=p_period;
  v_week:=p_att_date-(extract(isodow from p_att_date)::integer-1);
  perform public._reward_v2_reconcile_week(p_assignment_id,v_week);
  perform public._reward_v2_audit(v_teacher,'teacher','clear_attendance','subject_attendance',
    p_assignment_id||':'||p_student_id||':'||p_att_date||':'||p_period,
    'ล้างสถานะเวลาเรียน',jsonb_build_object('reason',trim(p_reason),'reversal_id',v_reversal));
  return jsonb_build_object('ok',true,'reversal_id',v_reversal);
end $$;

-- ===== Lottery lifecycle =====
create or replace function public._lottery_v2_sync_round(p_round bigint)
returns text language plpgsql security definer
set search_path=public,extensions as $$
declare v public.lottery_rounds_v2%rowtype;v_now timestamptz:=now();
begin
  select * into v from public.lottery_rounds_v2 where id=p_round for update;
  if v.id is null then raise exception 'ไม่พบงวด'; end if;
  if v.status='board_ready' and v.board_confirmed_at is not null and v_now>=v.sale_opens_at and v_now<v.sale_closes_at then
    update public.lottery_rounds_v2 set status='open',updated_at=now() where id=p_round;
    v.status:='open';
  end if;
  if v.status in ('open','sold_out') and v_now>=v.sale_closes_at then
    update public.lottery_rounds_v2 set status='closed',updated_at=now() where id=p_round;
    v.status:='closed';
  end if;
  return v.status;
end $$;

create or replace function public.lottery_v2_create_round(
  p_token uuid,p_assignment_id integer,p_title text,p_description text,
  p_sale_opens_at timestamptz,p_sale_closes_at timestamptz,p_draw_at timestamptz,
  p_draw_period integer default null,p_price_two integer default 5,p_price_three integer default 7
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_ta public.teaching_assignments%rowtype;v_id bigint;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  if not public._reward_v2_can_manage(v_teacher,p_assignment_id) then raise exception 'ไม่มีสิทธิ์สร้างงวดในรายวิชานี้'; end if;
  if not exists(select 1 from public.reward_assignment_settings where assignment_id=p_assignment_id and enabled=true) then
    raise exception 'กรุณาเปิดโมดูลเหรียญของรายวิชาก่อน';
  end if;
  if nullif(trim(p_title),'') is null then raise exception 'กรุณากรอกชื่องวด'; end if;
  if p_price_two<=0 or p_price_three<=0 then raise exception 'ราคาสลากต้องมากกว่า 0'; end if;
  if p_sale_closes_at<=p_sale_opens_at or p_draw_at<p_sale_closes_at then raise exception 'วันเวลาเปิดขาย ปิดขาย และออกรางวัลไม่ถูกต้อง'; end if;
  select * into v_ta from public.teaching_assignments where id=p_assignment_id;
  insert into public.lottery_rounds_v2(
    assignment_id,school_year,semester,title,description,price_two,price_three,
    sale_opens_at,sale_closes_at,draw_at,draw_period,created_by
  ) values(
    p_assignment_id,v_ta.year,v_ta.semester,trim(p_title),nullif(trim(p_description),''),
    p_price_two,p_price_three,p_sale_opens_at,p_sale_closes_at,p_draw_at,p_draw_period,v_teacher
  ) returning id into v_id;
  perform public._reward_v2_audit(v_teacher,'teacher','create','lottery_rounds_v2',v_id::text,'สร้างงวดเลข 2 ตัว/3 ตัว',
    jsonb_build_object('assignment_id',p_assignment_id,'price_two',p_price_two,'price_three',p_price_three));
  return jsonb_build_object('ok',true,'round_id',v_id);
end $$;

create or replace function public.lottery_v2_generate_board(
  p_token uuid,p_round_id bigint,p_total_tickets integer default null
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_round public.lottery_rounds_v2%rowtype;v_students integer;
  v_total integer;v_each integer;v_unique integer;v_seed uuid:=gen_random_uuid();v_version integer;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  select * into v_round from public.lottery_rounds_v2 where id=p_round_id for update;
  if v_round.id is null then raise exception 'ไม่พบงวด'; end if;
  if not public._reward_v2_can_manage(v_teacher,v_round.assignment_id) then raise exception 'ไม่มีสิทธิ์จัดการงวดนี้'; end if;
  if v_round.status not in ('draft','board_ready') then raise exception 'เปิดขายแล้ว ไม่สามารถเปลี่ยนแผงได้'; end if;
  if exists(select 1 from public.lottery_ticket_inventory where round_id=p_round_id and sold_to is not null) then
    raise exception 'มีสลากขายแล้ว ไม่สามารถสร้างแผงใหม่ได้';
  end if;
  select count(*) into v_students from public.enrollments where assignment_id=v_round.assignment_id and status='active';
  if p_total_tickets is null then
    v_total:=greatest(100,v_students*3);
  else v_total:=p_total_tickets; end if;
  v_total:=ceil(v_total/4.0)::integer*4;
  if v_total<4 or v_total>400 then raise exception 'จำนวนสลากรวมต้องอยู่ระหว่าง 4–400 ใบ'; end if;
  v_each:=v_total/2;v_unique:=v_each/2;
  if v_unique>100 then raise exception 'สลาก 2 ตัวรองรับได้สูงสุด 200 ใบ'; end if;
  delete from public.lottery_ticket_inventory where round_id=p_round_id;

  with picked as (
    select lpad(n::text,2,'0') number_text from generate_series(0,99) n
    order by md5(v_seed::text||':two:'||n::text) limit v_unique
  )
  insert into public.lottery_ticket_inventory(round_id,ticket_type,number_text,copy_code)
  select p_round_id,'two',p.number_text,c.copy_code from picked p cross join (values('A'),('B')) c(copy_code);

  with picked as (
    select lpad(n::text,3,'0') number_text from generate_series(0,999) n
    order by md5(v_seed::text||':three:'||n::text) limit v_unique
  )
  insert into public.lottery_ticket_inventory(round_id,ticket_type,number_text,copy_code)
  select p_round_id,'three',p.number_text,c.copy_code from picked p cross join (values('A'),('B')) c(copy_code);

  update public.lottery_rounds_v2 set total_tickets=v_total,two_ticket_count=v_each,three_ticket_count=v_each,
    board_seed=v_seed,board_version=board_version+1,board_confirmed_at=null,board_confirmed_by=null,
    status='board_ready',updated_at=now() where id=p_round_id returning board_version into v_version;
  perform public._reward_v2_audit(v_teacher,'teacher','generate_board','lottery_rounds_v2',p_round_id::text,
    'สร้างหรือสุ่มแผงสลากใหม่',jsonb_build_object('total',v_total,'two',v_each,'three',v_each,'version',v_version));
  return jsonb_build_object('ok',true,'total',v_total,'two',v_each,'three',v_each,'board_version',v_version);
end $$;

create or replace function public.lottery_v2_confirm_board(p_token uuid,p_round_id bigint)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_assignment integer;v_status text;v_count integer;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  select assignment_id,status into v_assignment,v_status from public.lottery_rounds_v2 where id=p_round_id for update;
  if not public._reward_v2_can_manage(v_teacher,v_assignment) then raise exception 'ไม่มีสิทธิ์จัดการงวดนี้'; end if;
  if v_status<>'board_ready' then raise exception 'ยังไม่มีแผงที่พร้อมยืนยัน'; end if;
  select count(*) into v_count from public.lottery_ticket_inventory where round_id=p_round_id;
  if v_count=0 then raise exception 'ยังไม่มีสลากในแผง'; end if;
  update public.lottery_rounds_v2 set board_confirmed_at=now(),board_confirmed_by=v_teacher,updated_at=now() where id=p_round_id;
  perform public._reward_v2_audit(v_teacher,'teacher','confirm_board','lottery_rounds_v2',p_round_id::text,'ยืนยันแผงสลาก',jsonb_build_object('tickets',v_count));
  return jsonb_build_object('ok',true,'tickets',v_count);
end $$;

create or replace function public.lottery_v2_hold_numbers(
  p_token uuid,p_round_id bigint,p_ticket_ids bigint[],p_request_key text
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_student integer;v_round public.lottery_rounds_v2%rowtype;v_cart uuid;v_count integer;v_total integer;v_status text;
begin
  v_student:=public._reward_v2_student(p_token);
  if not public._reward_v2_is_enrolled(v_student,(select assignment_id from public.lottery_rounds_v2 where id=p_round_id)) then
    raise exception 'นักเรียนไม่ได้ลงทะเบียนในรายวิชาของงวดนี้';
  end if;
  v_count:=coalesce(array_length(p_ticket_ids,1),0);
  if v_count<1 or v_count>10 then raise exception 'ตะกร้าต้องมี 1–10 ใบ'; end if;
  if v_count<>(select count(distinct x) from unnest(p_ticket_ids) x) then raise exception 'มีสลากซ้ำในตะกร้า'; end if;
  v_status:=public._lottery_v2_sync_round(p_round_id);
  select * into v_round from public.lottery_rounds_v2 where id=p_round_id for update;
  if v_status<>'open' or now()<v_round.sale_opens_at or now()>=v_round.sale_closes_at then raise exception 'งวดนี้ยังไม่เปิดขายหรือปิดขายแล้ว'; end if;

  update public.lottery_carts set state='expired' where state='active' and expires_at<=now();
  update public.lottery_ticket_inventory set reserved_cart_id=null,reserved_until=null
  where round_id=p_round_id and reserved_until<=now() and sold_to is null;

  select id into v_cart from public.lottery_carts
  where request_key=p_request_key and round_id=p_round_id and student_id=v_student;
  if v_cart is not null then
    select count(*),sum(case when ticket_type='two' then v_round.price_two else v_round.price_three end)
    into v_count,v_total from public.lottery_ticket_inventory
    where reserved_cart_id=v_cart and reserved_until>now() and sold_to is null;
    if v_count>0 then
      return jsonb_build_object('ok',true,'cart_id',v_cart,
        'expires_at',(select expires_at from public.lottery_carts where id=v_cart),
        'count',v_count,'total_coins',v_total,'idempotent',true);
    end if;
    raise exception 'คำขอจองนี้หมดอายุแล้ว กรุณาเลือกหมายเลขใหม่';
  end if;
  if exists(select 1 from public.lottery_carts where student_id=v_student and state='active') then
    raise exception 'มีตะกร้าที่กำลังใช้งานอยู่ กรุณายืนยันหรือยกเลิกตะกร้าเดิมก่อน';
  end if;

  perform 1 from public.lottery_ticket_inventory where id=any(p_ticket_ids) and round_id=p_round_id for update;
  if (select count(*) from public.lottery_ticket_inventory
      where id=any(p_ticket_ids) and round_id=p_round_id and sold_to is null and voided_at is null
        and (reserved_cart_id is null or reserved_until<=now()))<>v_count then
    raise exception 'มีหมายเลขบางใบถูกซื้อหรือถูกจองแล้ว กรุณาเลือกใหม่';
  end if;

  insert into public.lottery_carts(round_id,student_id,request_key,expires_at)
  values(p_round_id,v_student,p_request_key,now()+interval '2 minutes') returning id into v_cart;
  update public.lottery_ticket_inventory set reserved_cart_id=v_cart,reserved_until=now()+interval '2 minutes'
  where id=any(p_ticket_ids);
  select sum(case when ticket_type='two' then v_round.price_two else v_round.price_three end) into v_total
  from public.lottery_ticket_inventory where id=any(p_ticket_ids);
  perform public._reward_v2_audit(v_student,'student','hold','lottery_carts',v_cart::text,
    'จองสลากในตะกร้า',jsonb_build_object('round_id',p_round_id,'count',v_count,'expires_in_seconds',120));
  return jsonb_build_object('ok',true,'cart_id',v_cart,'expires_at',now()+interval '2 minutes','count',v_count,'total_coins',v_total);
end $$;

create or replace function public.lottery_v2_release_cart(p_token uuid,p_cart_id uuid)
returns boolean language plpgsql security definer
set search_path=public,extensions as $$
declare v_student integer;v_cart public.lottery_carts%rowtype;
begin
  v_student:=public._reward_v2_student(p_token);
  select * into v_cart from public.lottery_carts where id=p_cart_id for update;
  if v_cart.student_id is distinct from v_student then raise exception 'ไม่พบตะกร้า'; end if;
  if v_cart.state='active' then
    update public.lottery_ticket_inventory set reserved_cart_id=null,reserved_until=null
    where reserved_cart_id=p_cart_id and sold_to is null;
    update public.lottery_carts set state='released' where id=p_cart_id;
    perform public._reward_v2_audit(v_student,'student','release','lottery_carts',p_cart_id::text,
      'ยกเลิกตะกร้าสลาก',jsonb_build_object('round_id',v_cart.round_id));
  end if;
  return true;
end $$;

create or replace function public.lottery_v2_purchase_cart(
  p_token uuid,p_cart_id uuid,p_idempotency_key text
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_student integer;v_cart public.lottery_carts%rowtype;v_round public.lottery_rounds_v2%rowtype;
  v_count integer;v_total integer;v_ledger bigint;v_purchase bigint;v_status text;
begin
  v_student:=public._reward_v2_student(p_token);
  select p.id,p.total_coins,count(i.ticket_id) into v_purchase,v_total,v_count
  from public.lottery_purchases p join public.lottery_purchase_items i on i.purchase_id=p.id
  where p.idempotency_key=p_idempotency_key group by p.id,p.total_coins;
  if v_purchase is not null then return jsonb_build_object('ok',true,'purchase_id',v_purchase,'count',v_count,'total_coins',v_total,'idempotent',true); end if;

  select * into v_cart from public.lottery_carts where id=p_cart_id for update;
  if v_cart.id is null or v_cart.student_id<>v_student then raise exception 'ไม่พบตะกร้า'; end if;
  if v_cart.state='purchased' then
    select p.id,p.total_coins,count(i.ticket_id) into v_purchase,v_total,v_count
    from public.lottery_purchases p join public.lottery_purchase_items i on i.purchase_id=p.id
    where p.cart_id=p_cart_id and p.student_id=v_student group by p.id,p.total_coins;
    if v_purchase is not null then
      return jsonb_build_object('ok',true,'purchase_id',v_purchase,'count',v_count,'total_coins',v_total,'idempotent',true);
    end if;
  end if;
  if v_cart.state<>'active' or v_cart.expires_at<=now() then raise exception 'ตะกร้าหมดอายุ กรุณาเลือกหมายเลขใหม่'; end if;
  v_status:=public._lottery_v2_sync_round(v_cart.round_id);
  select * into v_round from public.lottery_rounds_v2 where id=v_cart.round_id for update;
  if v_status<>'open' or now()>=v_round.sale_closes_at then raise exception 'ปิดขายแล้ว'; end if;
  perform 1 from public.lottery_ticket_inventory where reserved_cart_id=p_cart_id for update;
  select count(*),sum(case when ticket_type='two' then v_round.price_two else v_round.price_three end)
  into v_count,v_total from public.lottery_ticket_inventory
  where reserved_cart_id=p_cart_id and reserved_until>now() and sold_to is null and voided_at is null;
  if v_count<1 or v_count>10 then raise exception 'ตะกร้าไม่ถูกต้องหรือหมดอายุ'; end if;

  v_ledger:=public._reward_v2_post(
    v_round.assignment_id,v_student,-v_total,'lottery_purchase','lottery_cart',p_cart_id::text,
    'ซื้อสลากเลข 2 ตัว/3 ตัว งวด '||v_round.title,null,null,false,null,
    'lottery-purchase:'||p_idempotency_key,null,jsonb_build_object('round_id',v_round.id,'count',v_count)
  );
  insert into public.lottery_purchases(cart_id,round_id,assignment_id,student_id,total_coins,ledger_id,idempotency_key)
  values(p_cart_id,v_round.id,v_round.assignment_id,v_student,v_total,v_ledger,p_idempotency_key)
  returning id into v_purchase;
  insert into public.lottery_purchase_items(purchase_id,ticket_id,ticket_type,number_text,copy_code,price_paid)
  select v_purchase,id,ticket_type,number_text,copy_code,
    case when ticket_type='two' then v_round.price_two else v_round.price_three end
  from public.lottery_ticket_inventory where reserved_cart_id=p_cart_id;
  update public.lottery_ticket_inventory set sold_to=v_student,sold_at=now(),purchase_id=v_purchase,
    reserved_cart_id=null,reserved_until=null where reserved_cart_id=p_cart_id;
  update public.lottery_carts set state='purchased',purchased_at=now() where id=p_cart_id;
  if not exists(select 1 from public.lottery_ticket_inventory where round_id=v_round.id and sold_to is null and voided_at is null) then
    update public.lottery_rounds_v2 set status='sold_out',updated_at=now() where id=v_round.id;
  end if;
  insert into public.reward_notifications(assignment_id,recipient_type,student_id,event_type,title,body,entity_type,entity_id)
  values(v_round.assignment_id,'student',v_student,'lottery_purchase','ซื้อสลากสำเร็จ',
    'ซื้อ '||v_count||' ใบ ใช้ '||v_total||' เหรียญ','lottery_purchase',v_purchase::text);
  perform public._reward_v2_audit(v_student,'student','purchase','lottery_purchases',v_purchase::text,
    'ซื้อสลากเลข 2 ตัว/3 ตัว',jsonb_build_object('round_id',v_round.id,'count',v_count,'coins',v_total));
  return jsonb_build_object('ok',true,'purchase_id',v_purchase,'count',v_count,'total_coins',v_total,'balance',(select balance from public.reward_wallets where assignment_id=v_round.assignment_id and student_id=v_student));
end $$;

-- บันทึกผลทีละขั้น เพื่อให้หน้าเว็บปิดหรือเครือข่ายหลุดแล้วกลับมาทำต่อได้
create or replace function public.lottery_v2_draw_step(p_token uuid,p_round_id bigint)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_round public.lottery_rounds_v2%rowtype;v_draw public.lottery_draws_v2%rowtype;
  v_status text;v_slot text;v_type text;v_number text;v_done boolean;v_existing integer;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  select * into v_round from public.lottery_rounds_v2 where id=p_round_id for update;
  if v_round.id is null then raise exception 'ไม่พบงวด'; end if;
  if not public._reward_v2_can_manage(v_teacher,v_round.assignment_id) then raise exception 'ไม่มีสิทธิ์ออกรางวัล'; end if;

  v_status:=public._lottery_v2_sync_round(p_round_id);
  select * into v_round from public.lottery_rounds_v2 where id=p_round_id for update;
  if v_status not in ('closed','sold_out','drawing','pending_confirmation') or now()<v_round.draw_at then
    raise exception 'ยังไม่ถึงเวลาออกรางวัลหรือยังไม่ปิดขาย';
  end if;
  if not exists(select 1 from public.lottery_ticket_inventory where round_id=p_round_id and ticket_type='two' and voided_at is null)
     or not exists(select 1 from public.lottery_ticket_inventory where round_id=p_round_id and ticket_type='three' and voided_at is null) then
    raise exception 'แผงต้องมีสลากเลข 2 ตัวและ 3 ตัวก่อนออกรางวัล';
  end if;

  select * into v_draw from public.lottery_draws_v2 where round_id=p_round_id for update;
  if v_draw.id is null then
    insert into public.lottery_draws_v2(round_id,seed,drawn_by)
    values(p_round_id,gen_random_uuid(),v_teacher) returning * into v_draw;
    update public.lottery_rounds_v2 set status='drawing',updated_at=now() where id=p_round_id;
  end if;

  select count(*) into v_existing from public.lottery_draw_results where draw_id=v_draw.id;
  if v_existing=0 then v_slot:='two_first';v_type:='two';
  elsif v_existing=1 then v_slot:='two_second';v_type:='two';
  elsif v_existing=2 then v_slot:='three';v_type:='three';
  else
    return jsonb_build_object('ok',true,'draw_id',v_draw.id,'done',true,'resumed',true,
      'results',(select coalesce(jsonb_agg(jsonb_build_object('slot',result_slot,'type',ticket_type,'number',number_text) order by id),'[]'::jsonb)
        from public.lottery_draw_results where draw_id=v_draw.id));
  end if;

  select number_text into v_number from (
    select distinct number_text from public.lottery_ticket_inventory
    where round_id=p_round_id and ticket_type=v_type and voided_at is null
  ) x order by md5(v_draw.seed::text||':'||v_slot||':'||number_text) limit 1;
  insert into public.lottery_draw_results(draw_id,result_slot,ticket_type,number_text)
  values(v_draw.id,v_slot,v_type,v_number) on conflict(draw_id,result_slot) do nothing;
  select count(*)=3 into v_done from public.lottery_draw_results where draw_id=v_draw.id;
  update public.lottery_rounds_v2 set status=case when v_done then 'pending_confirmation' else 'drawing' end,updated_at=now()
  where id=p_round_id;
  perform public._reward_v2_audit(v_teacher,'teacher','draw_step','lottery_rounds_v2',p_round_id::text,
    'บันทึกผลรางวัล '||v_slot,jsonb_build_object('draw_id',v_draw.id,'slot',v_slot,'number',v_number,'done',v_done));
  return jsonb_build_object('ok',true,'draw_id',v_draw.id,'slot',v_slot,'type',v_type,'number',v_number,'done',v_done,
    'results',(select coalesce(jsonb_agg(jsonb_build_object('slot',result_slot,'type',ticket_type,'number',number_text) order by id),'[]'::jsonb)
      from public.lottery_draw_results where draw_id=v_draw.id));
end $$;

-- โหมดทดลอง: ใช้ seed ชั่วคราวและไม่เขียนตารางใด ๆ
create or replace function public.lottery_v2_trial_draw(p_token uuid,p_round_id bigint)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_assignment integer;v_seed uuid:=gen_random_uuid();v_two1 text;v_two2 text;v_three text;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  select assignment_id into v_assignment from public.lottery_rounds_v2 where id=p_round_id;
  if not public._reward_v2_can_manage(v_teacher,v_assignment) then raise exception 'ไม่มีสิทธิ์ทดลองออกรางวัล'; end if;
  select number_text into v_two1 from (select distinct number_text from public.lottery_ticket_inventory where round_id=p_round_id and ticket_type='two' and voided_at is null) x order by md5(v_seed::text||':trial-one:'||number_text) limit 1;
  select number_text into v_two2 from (select distinct number_text from public.lottery_ticket_inventory where round_id=p_round_id and ticket_type='two' and voided_at is null) x order by md5(v_seed::text||':trial-two:'||number_text) limit 1;
  select number_text into v_three from (select distinct number_text from public.lottery_ticket_inventory where round_id=p_round_id and ticket_type='three' and voided_at is null) x order by md5(v_seed::text||':trial-three:'||number_text) limit 1;
  if v_two1 is null or v_three is null then raise exception 'โหมดทดลองต้องมีสลากเลข 2 ตัวและ 3 ตัวในแผง'; end if;
  return jsonb_build_object('ok',true,'trial',true,'two_first',v_two1,'two_second',v_two2,'three',v_three);
end $$;

-- ชื่อเดิมยังคงไว้เพื่อ compatibility แต่ทำงานแบบ resumable ทีละขั้นภายใน transaction เดียว
create or replace function public.lottery_v2_draw_preview(p_token uuid,p_round_id bigint)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_result jsonb;v_i integer;
begin
  for v_i in 1..3 loop
    v_result:=public.lottery_v2_draw_step(p_token,p_round_id);
    exit when coalesce((v_result->>'done')::boolean,false);
  end loop;
  return v_result;
end $$;

create or replace function public.lottery_v2_trial_wheel(p_token uuid,p_assignment_id integer,p_wheel_type text)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_seed uuid:=gen_random_uuid();v_total numeric;v_pick numeric;v_prize record;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  if not public._reward_v2_can_manage(v_teacher,p_assignment_id) then raise exception 'ไม่มีสิทธิ์ทดลองวงล้อ'; end if;
  if p_wheel_type not in ('two','three') then raise exception 'ประเภทวงล้อไม่ถูกต้อง'; end if;
  select sum(weight) into v_total from public.reward_wheel_prizes where assignment_id=p_assignment_id and wheel_type=p_wheel_type and active=true;
  if coalesce(v_total,0)<=0 then raise exception 'วงล้อยังไม่มีรางวัลที่เปิดใช้'; end if;
  v_pick:=((('x'||substr(md5(v_seed::text),1,8))::bit(32)::bigint % 1000000)::numeric/1000000)*v_total;
  select q.* into v_prize from (
    select p.id,p.title,p.prize_kind,p.amount,sum(p.weight) over(order by p.id) cumulative
    from public.reward_wheel_prizes p where p.assignment_id=p_assignment_id and p.wheel_type=p_wheel_type and p.active=true
  ) q where q.cumulative>=v_pick order by q.id limit 1;
  return jsonb_build_object('ok',true,'trial',true,'prize_id',v_prize.id,'prize',v_prize.title,'prize_kind',v_prize.prize_kind,'amount',v_prize.amount);
end $$;

create or replace function public.lottery_v2_confirm_results(p_token uuid,p_round_id bigint)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_round public.lottery_rounds_v2%rowtype;v_draw bigint;v_count integer;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  select * into v_round from public.lottery_rounds_v2 where id=p_round_id for update;
  if not public._reward_v2_can_manage(v_teacher,v_round.assignment_id) then raise exception 'ไม่มีสิทธิ์ยืนยันผล'; end if;
  if v_round.status<>'pending_confirmation' then raise exception 'ผลรางวัลไม่อยู่ในสถานะรอยืนยัน'; end if;
  select id into v_draw from public.lottery_draws_v2 where round_id=p_round_id for update;
  update public.lottery_draws_v2 set status='confirmed',confirmed_by=v_teacher,confirmed_at=now() where id=v_draw;
  insert into public.lottery_winner_rights(round_id,result_id,ticket_id,student_id,ticket_type)
  select p_round_id,r.id,t.id,t.sold_to,t.ticket_type
  from public.lottery_draw_results r
  join public.lottery_ticket_inventory t on t.round_id=p_round_id and t.ticket_type=r.ticket_type
    and t.number_text=r.number_text and t.sold_to is not null
  where r.draw_id=v_draw
  on conflict(result_id,ticket_id) do nothing;
  get diagnostics v_count=row_count;
  insert into public.reward_notifications(assignment_id,recipient_type,student_id,event_type,title,body,entity_type,entity_id)
  select distinct v_round.assignment_id,'student',w.student_id,'lottery_winner','ถูกรางวัลล็อตเตอรี่',
    'คุณได้รับสิทธิ์หมุนวงล้อจากงวด '||v_round.title,'lottery_round',p_round_id::text
  from public.lottery_winner_rights w where w.round_id=p_round_id;
  update public.lottery_rounds_v2 set status='confirmed',updated_at=now() where id=p_round_id;
  perform public._reward_v2_audit(v_teacher,'teacher','confirm_results','lottery_rounds_v2',p_round_id::text,'ยืนยันผลรางวัลอย่างเป็นทางการ',jsonb_build_object('winner_rights',v_count));
  return jsonb_build_object('ok',true,'winner_rights',v_count);
end $$;

create or replace function public.lottery_v2_spin_wheel(p_token uuid,p_winner_right_id bigint)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_right public.lottery_winner_rights%rowtype;v_prize public.reward_wheel_prizes%rowtype;
  v_total numeric;v_pick numeric;v_seed uuid:=gen_random_uuid();v_spin bigint;v_ledger bigint;v_coupon bigint;
  v_score_used integer;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  select * into v_right from public.lottery_winner_rights where id=p_winner_right_id for update;
  if v_right.id is null then raise exception 'ไม่พบสิทธิ์หมุนวงล้อ'; end if;
  if v_right.spin_status<>'ready' then raise exception 'สิทธิ์นี้ถูกใช้แล้ว'; end if;
  if not public._reward_v2_can_manage(v_teacher,(select assignment_id from public.lottery_rounds_v2 where id=v_right.round_id)) then
    raise exception 'ไม่มีสิทธิ์หมุนวงล้อนี้';
  end if;
  select sum(weight) into v_total from public.reward_wheel_prizes
  where assignment_id=(select assignment_id from public.lottery_rounds_v2 where id=v_right.round_id)
    and wheel_type=v_right.ticket_type and active=true;
  if coalesce(v_total,0)<=0 then raise exception 'วงล้อยังไม่มีรางวัลที่เปิดใช้'; end if;
  v_pick:=((('x'||substr(md5(v_seed::text),1,8))::bit(32)::bigint % 1000000)::numeric/1000000)*v_total;
  select q.* into v_prize from (
    select p.*,sum(p.weight) over(order by p.id) cumulative
    from public.reward_wheel_prizes p
    where p.assignment_id=(select assignment_id from public.lottery_rounds_v2 where id=v_right.round_id)
      and p.wheel_type=v_right.ticket_type and p.active=true
  ) q where q.cumulative>=v_pick order by q.id limit 1;
  if v_prize.prize_kind='score' then
    select coalesce(sum(c.amount),0) into v_score_used from public.reward_coupons c
    where c.round_id=v_right.round_id and c.student_id=v_right.student_id and c.coupon_kind='score' and c.status<>'voided';
    if v_score_used+coalesce(v_prize.amount,0)>3 then
      select * into v_prize from public.reward_wheel_prizes
      where assignment_id=v_prize.assignment_id and wheel_type=v_right.ticket_type and active=true and prize_kind<>'score'
      order by id limit 1;
    end if;
  end if;
  insert into public.reward_wheel_spins(winner_right_id,prize_id,student_id,assignment_id,seed,spun_by)
  values(v_right.id,v_prize.id,v_right.student_id,v_prize.assignment_id,v_seed,v_teacher) returning id into v_spin;
  if v_prize.prize_kind='coin' then
    v_ledger:=public._reward_v2_post(v_prize.assignment_id,v_right.student_id,v_prize.amount,'wheel_reward','wheel_spin',v_spin::text,
      'รางวัลวงล้อ: '||v_prize.title,null,null,false,v_teacher,'wheel-spin:'||v_spin,null,jsonb_build_object('round_id',v_right.round_id));
    update public.reward_wheel_spins set ledger_id=v_ledger where id=v_spin;
  else
    insert into public.reward_coupons(coupon_code,assignment_id,round_id,student_id,spin_id,coupon_kind,title,amount,expires_on)
    values(upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),v_prize.assignment_id,v_right.round_id,v_right.student_id,v_spin,
      v_prize.prize_kind,v_prize.title,v_prize.amount,public._reward_v2_add_school_days((now() at time zone 'Asia/Bangkok')::date,3))
    returning id into v_coupon;
  end if;
  update public.lottery_winner_rights set spin_status='spun' where id=v_right.id;
  if not exists(select 1 from public.lottery_winner_rights where round_id=v_right.round_id and spin_status='ready') then
    update public.lottery_rounds_v2 set status='completed',updated_at=now() where id=v_right.round_id;
  end if;
  insert into public.reward_notifications(assignment_id,recipient_type,student_id,event_type,title,body,entity_type,entity_id)
  values(v_prize.assignment_id,'student',v_right.student_id,'wheel_reward','ผลหมุนวงล้อ',v_prize.title,'wheel_spin',v_spin::text);
  perform public._reward_v2_audit(v_teacher,'teacher','spin','reward_wheel_spins',v_spin::text,'หมุนวงล้อและบันทึกรางวัล',jsonb_build_object('winner_right_id',v_right.id,'prize_id',v_prize.id));
  return jsonb_build_object('ok',true,'spin_id',v_spin,'prize_id',v_prize.id,'prize',v_prize.title,'prize_kind',v_prize.prize_kind,'amount',v_prize.amount,'ledger_id',v_ledger,'coupon_id',v_coupon);
end $$;

create or replace function public.reward_v2_redeem_coupon(
  p_token uuid,p_coupon_id bigint,p_delivery_note text default null,p_grade_structure_id integer default null
) returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_coupon public.reward_coupons%rowtype;v_old numeric;v_new numeric;v_max numeric;v_grade bigint;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  select * into v_coupon from public.reward_coupons where id=p_coupon_id for update;
  if v_coupon.id is null then raise exception 'ไม่พบคูปอง'; end if;
  if not public._reward_v2_can_manage(v_teacher,v_coupon.assignment_id) then raise exception 'ไม่มีสิทธิ์ใช้คูปองนี้'; end if;
  if v_coupon.status<>'issued' then raise exception 'คูปองนี้ถูกใช้หรือหมดอายุแล้ว'; end if;
  if v_coupon.expires_on<(now() at time zone 'Asia/Bangkok')::date then
    update public.reward_coupons set status='expired' where id=v_coupon.id;
    raise exception 'คูปองหมดอายุแล้ว';
  end if;
  if v_coupon.coupon_kind='score' then
    if p_grade_structure_id is null then raise exception 'กรุณาเลือกงานที่อนุญาตให้ใช้คะแนนโบนัส'; end if;
    select max_score into v_max from public.grade_structures
    where id=p_grade_structure_id and assignment_id=v_coupon.assignment_id and coupon_eligible=true;
    if v_max is null then raise exception 'งานนี้ไม่ได้เปิดให้ใช้คูปองคะแนนโบนัส'; end if;
    select id,score into v_grade,v_old from public.grades where structure_id=p_grade_structure_id and student_id=v_coupon.student_id for update;
    v_new:=least(v_max,coalesce(v_old,0)+coalesce(v_coupon.amount,0));
    if v_grade is null then
      insert into public.grades(structure_id,student_id,teacher_id,score,note)
      values(p_grade_structure_id,v_coupon.student_id,v_teacher,v_new,'คูปองคะแนนโบนัส '||v_coupon.coupon_code) returning id into v_grade;
    else
      update public.grades set score=v_new,teacher_id=v_teacher,updated_at=now(),
        note=concat_ws(' · ',nullif(note,''),'คูปองคะแนนโบนัส '||v_coupon.coupon_code) where id=v_grade;
    end if;
    insert into public.grade_history(grade_id,old_score,new_score,changed_by,reason)
    values(v_grade,v_old,v_new,v_teacher,'ใช้คูปองคะแนนโบนัส '||v_coupon.coupon_code);
  end if;
  update public.reward_coupons set status='redeemed',redeemed_grade_structure_id=p_grade_structure_id,
    redeemed_by=v_teacher,redeemed_at=now(),delivery_note=nullif(trim(p_delivery_note),'') where id=v_coupon.id;
  perform public._reward_v2_audit(v_teacher,'teacher','redeem','reward_coupons',v_coupon.id::text,'ใช้คูปอง',jsonb_build_object('kind',v_coupon.coupon_kind,'grade_structure_id',p_grade_structure_id));
  return jsonb_build_object('ok',true,'coupon_id',v_coupon.id,'grade_id',v_grade,'new_score',v_new);
end $$;

-- ===== Sanitized read APIs =====
create or replace function public.reward_v2_teacher_dashboard(p_token uuid,p_assignment_id integer)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  if not public._reward_v2_can_manage(v_teacher,p_assignment_id) then raise exception 'ไม่มีสิทธิ์ดูรายวิชานี้'; end if;
  return jsonb_build_object(
    'settings',(select to_jsonb(s) from public.reward_assignment_settings s where s.assignment_id=p_assignment_id),
    'students',(select coalesce(jsonb_agg(jsonb_build_object(
      'id',st.id,'student_code',st.student_code,'fullname',st.fullname,'order_no',st.order_no,
      'balance',coalesce(w.balance,0)
    ) order by st.order_no,st.fullname),'[]'::jsonb)
      from public.enrollments e join public.students st on st.id=e.student_id
      left join public.reward_wallets w on w.assignment_id=e.assignment_id and w.student_id=e.student_id
      where e.assignment_id=p_assignment_id and e.status='active'),
    'rounds',(select coalesce(jsonb_agg(jsonb_build_object(
      'id',r.id,'title',r.title,'description',r.description,'status',public._lottery_v2_sync_round(r.id),
      'price_two',r.price_two,'price_three',r.price_three,'total_tickets',r.total_tickets,
      'two_ticket_count',r.two_ticket_count,'three_ticket_count',r.three_ticket_count,
      'sale_opens_at',r.sale_opens_at,'sale_closes_at',r.sale_closes_at,'draw_at',r.draw_at,
      'board_confirmed_at',r.board_confirmed_at,
      'sold_two',(select count(*) from public.lottery_ticket_inventory t where t.round_id=r.id and t.ticket_type='two' and t.sold_to is not null),
      'sold_three',(select count(*) from public.lottery_ticket_inventory t where t.round_id=r.id and t.ticket_type='three' and t.sold_to is not null),
      'buyers',(select count(distinct t.sold_to) from public.lottery_ticket_inventory t where t.round_id=r.id and t.sold_to is not null)
    ) order by r.created_at desc),'[]'::jsonb) from public.lottery_rounds_v2 r where r.assignment_id=p_assignment_id),
    'recent_ledger',(select coalesce(jsonb_agg(x),'[]'::jsonb) from (
      select l.id,l.student_id,st.fullname,l.amount,l.entry_type,l.reason,l.student_note,l.private_note,l.reversal_of,l.created_at,
        exists(select 1 from public.reward_ledger rv where rv.reversal_of=l.id) reversed
      from public.reward_ledger l join public.students st on st.id=l.student_id
      where l.assignment_id=p_assignment_id order by l.created_at desc limit 100
    ) x),
    'templates',(select coalesce(jsonb_agg(t order by t.title),'[]'::jsonb) from public.reward_activity_templates t where t.assignment_id=p_assignment_id),
    'top_week',(select coalesce(jsonb_agg(x order by rank_no,fullname),'[]'::jsonb) from (
      select student_id,fullname,coins,dense_rank() over(order by coins desc) rank_no from (
        select e.student_id,st.fullname,coalesce(sum(l.amount) filter(where l.rank_eligible),0) coins
        from public.enrollments e join public.students st on st.id=e.student_id
        left join public.reward_ledger l on l.assignment_id=e.assignment_id and l.student_id=e.student_id
          and l.created_at>=date_trunc('week',now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok'
        where e.assignment_id=p_assignment_id and e.status='active' group by e.student_id,st.fullname
      ) a
    ) x where rank_no<=10),
    'top_month',(select coalesce(jsonb_agg(x order by rank_no,fullname),'[]'::jsonb) from (
      select student_id,fullname,coins,dense_rank() over(order by coins desc) rank_no from (
        select e.student_id,st.fullname,coalesce(sum(l.amount) filter(where l.rank_eligible),0) coins
        from public.enrollments e join public.students st on st.id=e.student_id
        left join public.reward_ledger l on l.assignment_id=e.assignment_id and l.student_id=e.student_id
          and l.created_at>=date_trunc('month',now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok'
        where e.assignment_id=p_assignment_id and e.status='active' group by e.student_id,st.fullname
      ) a
    ) x where rank_no<=10),
    'eligible_grade_structures',(select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'max_score',g.max_score) order by g.order_no,g.id),'[]'::jsonb)
      from public.grade_structures g where g.assignment_id=p_assignment_id and g.coupon_eligible=true),
    'ranking_prizes',(select coalesce(jsonb_agg(p order by p.period_type,p.id),'[]'::jsonb) from public.reward_ranking_prizes p where p.assignment_id=p_assignment_id),
    'ranking_awards',(select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'period_type',a.period_type,'period_start',a.period_start,
      'fullname',st.fullname,'earned_coins',a.earned_coins,'title',p.title,'kind',p.prize_kind) order by a.created_at desc),'[]'::jsonb)
      from public.reward_ranking_awards a join public.students st on st.id=a.student_id join public.reward_ranking_prizes p on p.id=a.prize_id
      where a.assignment_id=p_assignment_id),
    'wheel_prizes',(select coalesce(jsonb_agg(p order by p.wheel_type,p.id),'[]'::jsonb) from public.reward_wheel_prizes p where p.assignment_id=p_assignment_id),
    'coupons',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'coupon_code',c.coupon_code,'student_id',c.student_id,
      'fullname',st.fullname,'kind',c.coupon_kind,'title',c.title,'amount',c.amount,'status',c.status,'expires_on',c.expires_on)
      order by c.created_at desc),'[]'::jsonb) from public.reward_coupons c join public.students st on st.id=c.student_id where c.assignment_id=p_assignment_id)
  );
end $$;

create or replace function public.reward_v2_student_assignments(p_token uuid)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_student integer;
begin
  v_student:=public._reward_v2_student(p_token);
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id',ta.id,'subject_code',s.subject_code,'subject_name',s.subject_name,
      'room_name',c.room_name,'group_no',ta.group_no,'school_year',ta.year,'semester',ta.semester,
      'balance',coalesce(w.balance,0),
      'unread',(select count(*) from public.reward_notifications n where n.assignment_id=ta.id and n.student_id=v_student and n.read_at is null)
    ) order by s.subject_code,c.room_name,ta.group_no),'[]'::jsonb)
    from public.enrollments e
    join public.teaching_assignments ta on ta.id=e.assignment_id
    join public.reward_assignment_settings cfg on cfg.assignment_id=ta.id and cfg.enabled=true
    join public.subjects s on s.id=ta.subject_id
    join public.classrooms c on c.id=ta.classroom_id
    left join public.reward_wallets w on w.assignment_id=ta.id and w.student_id=v_student
    where e.student_id=v_student and e.status='active'
  );
end $$;

create or replace function public.lottery_v2_teacher_board(p_token uuid,p_round_id bigint)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_teacher integer;v_assignment integer;
begin
  v_teacher:=public._reward_v2_teacher(p_token);
  select assignment_id into v_assignment from public.lottery_rounds_v2 where id=p_round_id;
  if not public._reward_v2_can_manage(v_teacher,v_assignment) then raise exception 'ไม่มีสิทธิ์ดูงวดนี้'; end if;
  perform public._lottery_v2_sync_round(p_round_id);
  return jsonb_build_object(
    'round',(select to_jsonb(r) from public.lottery_rounds_v2 r where r.id=p_round_id),
    'tickets',(select coalesce(jsonb_agg(jsonb_build_object(
      'id',t.id,'type',t.ticket_type,'number',t.number_text,'copy',t.copy_code,
      'state',case when t.sold_to is not null then 'sold' when t.reserved_until>now() then 'held' else 'available' end,
      'student_id',t.sold_to,'fullname',st.fullname
    ) order by t.ticket_type,t.number_text,t.copy_code),'[]'::jsonb)
      from public.lottery_ticket_inventory t left join public.students st on st.id=t.sold_to where t.round_id=p_round_id),
    'results',(select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'slot',r.result_slot,'type',r.ticket_type,'number',r.number_text) order by r.id),'[]'::jsonb)
      from public.lottery_draw_results r join public.lottery_draws_v2 d on d.id=r.draw_id where d.round_id=p_round_id),
    'winner_rights',(select coalesce(jsonb_agg(jsonb_build_object(
      'id',w.id,'student_id',w.student_id,'fullname',st.fullname,'type',w.ticket_type,
      'number',t.number_text,'copy',t.copy_code,'spin_status',w.spin_status,
      'prize',(select p.title from public.reward_wheel_spins sp join public.reward_wheel_prizes p on p.id=sp.prize_id where sp.winner_right_id=w.id)
    ) order by w.id),'[]'::jsonb)
      from public.lottery_winner_rights w join public.students st on st.id=w.student_id
      join public.lottery_ticket_inventory t on t.id=w.ticket_id where w.round_id=p_round_id)
  );
end $$;

create or replace function public.reward_v2_student_dashboard(p_token uuid,p_assignment_id integer)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_student integer;v_week date:=(now() at time zone 'Asia/Bangkok')::date-(extract(isodow from (now() at time zone 'Asia/Bangkok')::date)::integer-1);
begin
  v_student:=public._reward_v2_student(p_token);
  if not public._reward_v2_is_enrolled(v_student,p_assignment_id) then raise exception 'ไม่ได้ลงทะเบียนในรายวิชานี้'; end if;
  if not exists(select 1 from public.reward_assignment_settings where assignment_id=p_assignment_id and enabled=true) then raise exception 'รายวิชานี้ไม่ได้เปิดโมดูลเหรียญ'; end if;
  return jsonb_build_object(
    'wallet',coalesce((select jsonb_build_object('balance',w.balance,'school_year',w.school_year,'semester',w.semester) from public.reward_wallets w where w.assignment_id=p_assignment_id and w.student_id=v_student),jsonb_build_object('balance',0)),
    'ledger',(select coalesce(jsonb_agg(x),'[]'::jsonb) from (select id,amount,entry_type,reason,student_note,reversal_of,created_at from public.reward_ledger where assignment_id=p_assignment_id and student_id=v_student order by created_at desc limit 100) x),
    'rounds',(select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'title',r.title,'description',r.description,
      'status',public._lottery_v2_sync_round(r.id),'price_two',r.price_two,'price_three',r.price_three,
      'sale_opens_at',r.sale_opens_at,'sale_closes_at',r.sale_closes_at,'draw_at',r.draw_at,
      'my_tickets',(select count(*) from public.lottery_ticket_inventory t where t.round_id=r.id and t.sold_to=v_student),
      'my_wins',(select count(*) from public.lottery_winner_rights wr where wr.round_id=r.id and wr.student_id=v_student)
    ) order by r.created_at desc),'[]'::jsonb) from public.lottery_rounds_v2 r where r.assignment_id=p_assignment_id and r.status<>'draft'),
    'coupons',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'coupon_code',coupon_code,'kind',coupon_kind,'title',title,'amount',amount,'status',status,'expires_on',expires_on) order by created_at desc),'[]'::jsonb) from public.reward_coupons where assignment_id=p_assignment_id and student_id=v_student),
    'notifications',(select coalesce(jsonb_agg(x),'[]'::jsonb) from (select id,event_type,title,body,read_at,created_at from public.reward_notifications where assignment_id=p_assignment_id and student_id=v_student order by created_at desc limit 30) x),
    'top_week',(select coalesce(jsonb_agg(jsonb_build_object('rank',rank_no,'name',fullname,'is_me',student_id=v_student) order by rank_no,fullname),'[]'::jsonb) from (
      select student_id,fullname,dense_rank() over(order by coins desc) rank_no from (
        select e.student_id,st.fullname,coalesce(sum(l.amount) filter(where l.rank_eligible),0) coins
        from public.enrollments e join public.students st on st.id=e.student_id
        left join public.reward_ledger l on l.assignment_id=e.assignment_id and l.student_id=e.student_id and l.created_at>=v_week
        where e.assignment_id=p_assignment_id and e.status='active' group by e.student_id,st.fullname
      ) a
    ) ranked where rank_no<=10),
    'top_month',(select coalesce(jsonb_agg(jsonb_build_object('rank',rank_no,'name',fullname,'is_me',student_id=v_student) order by rank_no,fullname),'[]'::jsonb) from (
      select student_id,fullname,dense_rank() over(order by coins desc) rank_no from (
        select e.student_id,st.fullname,coalesce(sum(l.amount) filter(where l.rank_eligible),0) coins
        from public.enrollments e join public.students st on st.id=e.student_id
        left join public.reward_ledger l on l.assignment_id=e.assignment_id and l.student_id=e.student_id
          and l.created_at>=date_trunc('month',now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok'
        where e.assignment_id=p_assignment_id and e.status='active' group by e.student_id,st.fullname
      ) a
    ) ranked where rank_no<=10)
  );
end $$;

create or replace function public.lottery_v2_get_board(p_token uuid,p_round_id bigint)
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_student integer;v_round public.lottery_rounds_v2%rowtype;
begin
  v_student:=public._reward_v2_student(p_token);
  select * into v_round from public.lottery_rounds_v2 where id=p_round_id;
  if not public._reward_v2_is_enrolled(v_student,v_round.assignment_id) then raise exception 'ไม่ได้ลงทะเบียนในรายวิชานี้'; end if;
  perform public._lottery_v2_sync_round(p_round_id);
  return jsonb_build_object(
    'round',(select jsonb_build_object('id',id,'title',title,'status',status,'price_two',price_two,'price_three',price_three,'sale_closes_at',sale_closes_at,'draw_at',draw_at) from public.lottery_rounds_v2 where id=p_round_id),
    'tickets',(select coalesce(jsonb_agg(jsonb_build_object(
      'id',id,'type',ticket_type,'number',number_text,'copy',copy_code,
      'state',case when sold_to=v_student then 'mine' when sold_to is not null then 'sold'
        when reserved_until>now() then 'held' else 'available' end
    ) order by ticket_type,number_text,copy_code),'[]'::jsonb) from public.lottery_ticket_inventory where round_id=p_round_id and voided_at is null),
    'results',(select coalesce(jsonb_agg(jsonb_build_object('slot',r.result_slot,'type',r.ticket_type,'number',r.number_text) order by r.id),'[]'::jsonb)
      from public.lottery_draw_results r join public.lottery_draws_v2 d on d.id=r.draw_id where d.round_id=p_round_id and d.status='confirmed'),
    'my_rights',(select coalesce(jsonb_agg(jsonb_build_object('id',w.id,'type',w.ticket_type,'spin_status',w.spin_status,
      'number',t.number_text,'copy',t.copy_code) order by w.id),'[]'::jsonb)
      from public.lottery_winner_rights w join public.lottery_ticket_inventory t on t.id=w.ticket_id where w.round_id=p_round_id and w.student_id=v_student)
  );
end $$;

create or replace function public.reward_v2_mark_notifications_read(p_token uuid,p_ids bigint[])
returns integer language plpgsql security definer
set search_path=public,extensions as $$
declare v_student integer;v_count integer;
begin
  v_student:=public._reward_v2_student(p_token);
  update public.reward_notifications set read_at=coalesce(read_at,now()) where id=any(p_ids) and student_id=v_student;
  get diagnostics v_count=row_count;return v_count;
end $$;

create or replace function public._reward_v2_award_rankings(
  p_assignment integer,p_period_type text,p_period_start date,p_period_end date
) returns integer language plpgsql security definer
set search_path=public,extensions as $$
declare v_prize record;v_student record;v_award bigint;v_ledger bigint;v_coupon bigint;v_count integer:=0;v_label text;
begin
  if p_period_type not in ('weekly','monthly') or p_period_end<=p_period_start then return 0; end if;
  v_label:=case when p_period_type='weekly' then 'ประจำสัปดาห์' else 'ประจำเดือน' end;
  for v_prize in select * from public.reward_ranking_prizes rp
    where rp.assignment_id=p_assignment and rp.period_type=p_period_type and rp.active=true order by rp.id
  loop
    for v_student in
      with scores as (
        select e.student_id,coalesce(sum(l.amount) filter(where l.rank_eligible),0)::integer coins
        from public.enrollments e
        left join public.reward_ledger l on l.assignment_id=e.assignment_id and l.student_id=e.student_id
          and l.created_at>=p_period_start::timestamptz and l.created_at<p_period_end::timestamptz
        where e.assignment_id=p_assignment and e.status='active' group by e.student_id
      ), ranked as (
        select student_id,coins,dense_rank() over(order by coins desc) rank_no from scores
      ) select student_id,coins from ranked where rank_no=1 and coins>0
    loop
      insert into public.reward_ranking_awards(prize_id,assignment_id,student_id,period_type,period_start,earned_coins)
      values(v_prize.id,p_assignment,v_student.student_id,p_period_type,p_period_start,v_student.coins)
      on conflict(prize_id,period_start,student_id) do nothing returning id into v_award;
      if v_award is null then continue; end if;
      if v_prize.prize_kind='coin' then
        v_ledger:=public._reward_v2_post(p_assignment,v_student.student_id,v_prize.amount,'ranking_reward','ranking_award',v_award::text,
          'รางวัลอันดับ 1 '||v_label||': '||v_prize.title,null,null,false,null,
          'ranking:'||v_prize.id||':'||p_period_start||':'||v_student.student_id,null,
          jsonb_build_object('period_type',p_period_type,'period_start',p_period_start,'earned_coins',v_student.coins));
        update public.reward_ranking_awards set ledger_id=v_ledger where id=v_award;
      else
        insert into public.reward_coupons(coupon_code,assignment_id,student_id,coupon_kind,title,amount,expires_on)
        values(upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),p_assignment,v_student.student_id,
          v_prize.prize_kind,v_prize.title,v_prize.amount,
          public._reward_v2_add_school_days((now() at time zone 'Asia/Bangkok')::date,3)) returning id into v_coupon;
        update public.reward_ranking_awards set coupon_id=v_coupon where id=v_award;
      end if;
      insert into public.reward_notifications(assignment_id,recipient_type,student_id,event_type,title,body,entity_type,entity_id)
      values(p_assignment,'student',v_student.student_id,'ranking_reward','รางวัลอันดับ 1 '||v_label,
        v_prize.title,'ranking_award',v_award::text);
      v_count:=v_count+1;
    end loop;
  end loop;
  return v_count;
end $$;

-- Service-role maintenance: เรียกจาก Edge Function/scheduler เท่านั้น
create or replace function public.reward_v2_maintenance(p_run_date date default ((now() at time zone 'Asia/Bangkok')::date))
returns jsonb language plpgsql security definer
set search_path=public,extensions as $$
declare v_key text:='reward-maintenance:'||to_char(now() at time zone 'Asia/Bangkok','YYYY-MM-DD HH24:MI');
  v_run bigint;v_setting record;v_week date;v_month date;v_rounds integer;v_holds integer;v_coupons integer;
  v_weeks integer:=0;v_rank_awards integer:=0;
begin
  insert into public.reward_job_runs(job_name,run_key) values('reward-maintenance',v_key)
  on conflict(run_key) do nothing returning id into v_run;
  if v_run is null then return jsonb_build_object('ok',true,'idempotent',true,'run_key',v_key); end if;
  update public.lottery_carts set state='expired' where state='active' and expires_at<=now();get diagnostics v_holds=row_count;
  update public.lottery_ticket_inventory set reserved_cart_id=null,reserved_until=null where sold_to is null and reserved_until<=now();
  update public.reward_coupons set status='expired' where status='issued' and expires_on<p_run_date;get diagnostics v_coupons=row_count;
  insert into public.reward_notifications(assignment_id,recipient_type,student_id,event_type,title,body,entity_type,entity_id)
  select c.assignment_id,'student',c.student_id,'coupon_expiring','คูปองใกล้หมดอายุ',
    c.title||' เหลือวันเรียนสุดท้าย','reward_coupon',c.id::text
  from public.reward_coupons c
  where c.status='issued' and c.expires_on=public._reward_v2_add_school_days(p_run_date,1)
    and not exists(
      select 1 from public.reward_notifications n
      where n.event_type='coupon_expiring' and n.entity_type='reward_coupon' and n.entity_id=c.id::text
    );
  update public.lottery_rounds_v2 set status='open',updated_at=now()
    where status='board_ready' and board_confirmed_at is not null and now()>=sale_opens_at and now()<sale_closes_at;
  update public.lottery_rounds_v2 set status='closed',updated_at=now()
    where status in ('open','sold_out') and now()>=sale_closes_at;get diagnostics v_rounds=row_count;
  v_week:=p_run_date-(extract(isodow from p_run_date)::integer-1)-7;
  v_month:=(date_trunc('month',p_run_date)::date-interval '1 month')::date;
  for v_setting in select assignment_id from public.reward_assignment_settings where enabled=true loop
    perform public._reward_v2_materialize_week(v_setting.assignment_id,v_week);
    perform public._reward_v2_reconcile_week(v_setting.assignment_id,v_week);v_weeks:=v_weeks+1;
    perform public._reward_v2_materialize_week(v_setting.assignment_id,v_week+7);
    v_rank_awards:=v_rank_awards+public._reward_v2_award_rankings(v_setting.assignment_id,'weekly',v_week,v_week+7);
    v_rank_awards:=v_rank_awards+public._reward_v2_award_rankings(v_setting.assignment_id,'monthly',v_month,(v_month+interval '1 month')::date);
  end loop;
  update public.reward_job_runs set status='success',finished_at=now(),result=jsonb_build_object('expired_holds',v_holds,'expired_coupons',v_coupons,'closed_rounds',v_rounds,'assignments',v_weeks,'ranking_awards',v_rank_awards) where id=v_run;
  return jsonb_build_object('ok',true,'expired_holds',v_holds,'expired_coupons',v_coupons,'closed_rounds',v_rounds,'assignments',v_weeks,'ranking_awards',v_rank_awards);
exception when others then
  update public.reward_job_runs set status='failed',finished_at=now(),error_text=sqlerrm where id=v_run;
  raise;
end $$;

-- Internal helpers must never be callable by anon/authenticated directly.
revoke all on function public._reward_v2_teacher(uuid) from public,anon,authenticated;
revoke all on function public._reward_v2_student(uuid) from public,anon,authenticated;
revoke all on function public._reward_v2_can_manage(integer,integer) from public,anon,authenticated;
revoke all on function public._reward_v2_is_enrolled(integer,integer) from public,anon,authenticated;
revoke all on function public._reward_v2_audit(integer,text,text,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function public._reward_v2_post(integer,integer,integer,text,text,text,text,text,text,boolean,integer,text,bigint,jsonb) from public,anon,authenticated;
revoke all on function public._reward_v2_add_school_days(date,integer) from public,anon,authenticated;
revoke all on function public._reward_v2_materialize_week(integer,date) from public,anon,authenticated;
revoke all on function public._reward_v2_reconcile_week(integer,date) from public,anon,authenticated;
revoke all on function public._reward_v2_award_rankings(integer,text,date,date) from public,anon,authenticated;
revoke all on function public._lottery_v2_sync_round(bigint) from public,anon,authenticated;

grant execute on function public.reward_v2_set_assignment(uuid,integer,boolean,integer,integer,integer) to anon,authenticated;
grant execute on function public.reward_v2_grant(uuid,integer,integer[],integer,text,text,text,bigint) to anon,authenticated;
grant execute on function public.reward_v2_reverse_ledger(uuid,bigint,text) to anon,authenticated;
grant execute on function public.reward_v2_save_template(uuid,integer,bigint,text,integer,text,boolean) to anon,authenticated;
grant execute on function public.reward_v2_save_wheel_prize(uuid,integer,bigint,text,text,text,integer,numeric,boolean) to anon,authenticated;
grant execute on function public.reward_v2_delete_wheel_prize(uuid,integer,bigint) to anon,authenticated;
grant execute on function public.reward_v2_save_ranking_prize(uuid,integer,bigint,text,text,text,integer,boolean) to anon,authenticated;
grant execute on function public.reward_v2_save_attendance(uuid,integer,date,integer,jsonb,boolean,text,integer) to anon,authenticated;
grant execute on function public.reward_v2_clear_attendance(uuid,integer,integer,date,integer,text) to anon,authenticated;
grant execute on function public.lottery_v2_create_round(uuid,integer,text,text,timestamptz,timestamptz,timestamptz,integer,integer,integer) to anon,authenticated;
grant execute on function public.lottery_v2_generate_board(uuid,bigint,integer) to anon,authenticated;
grant execute on function public.lottery_v2_confirm_board(uuid,bigint) to anon,authenticated;
grant execute on function public.lottery_v2_hold_numbers(uuid,bigint,bigint[],text) to anon,authenticated;
grant execute on function public.lottery_v2_release_cart(uuid,uuid) to anon,authenticated;
grant execute on function public.lottery_v2_purchase_cart(uuid,uuid,text) to anon,authenticated;
grant execute on function public.lottery_v2_draw_step(uuid,bigint) to anon,authenticated;
grant execute on function public.lottery_v2_trial_draw(uuid,bigint) to anon,authenticated;
grant execute on function public.lottery_v2_draw_preview(uuid,bigint) to anon,authenticated;
grant execute on function public.lottery_v2_confirm_results(uuid,bigint) to anon,authenticated;
grant execute on function public.lottery_v2_trial_wheel(uuid,integer,text) to anon,authenticated;
grant execute on function public.lottery_v2_spin_wheel(uuid,bigint) to anon,authenticated;
grant execute on function public.reward_v2_redeem_coupon(uuid,bigint,text,integer) to anon,authenticated;
grant execute on function public.reward_v2_teacher_dashboard(uuid,integer) to anon,authenticated;
grant execute on function public.reward_v2_student_dashboard(uuid,integer) to anon,authenticated;
grant execute on function public.reward_v2_student_assignments(uuid) to anon,authenticated;
grant execute on function public.lottery_v2_get_board(uuid,bigint) to anon,authenticated;
grant execute on function public.lottery_v2_teacher_board(uuid,bigint) to anon,authenticated;
grant execute on function public.reward_v2_mark_notifications_read(uuid,bigint[]) to anon,authenticated;
revoke all on function public.reward_v2_maintenance(date) from public,anon,authenticated;
grant execute on function public.reward_v2_maintenance(date) to service_role;

notify pgrst,'reload schema';
