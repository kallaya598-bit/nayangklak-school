-- ระบบแอดมิน: บันทึกการเข้าใช้งาน + ประวัติแก้ไข + สิทธิ์ผู้ใช้
-- รันใน Supabase SQL Editor

create table if not exists public.login_events (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  source text not null default 'web',
  actor_id bigint null,
  actor_name text null,
  actor_username text null,
  actor_role text null,
  action text not null default 'login',
  success boolean not null default true,
  entity text null,
  entity_id text null,
  summary text null,
  ip text null,
  user_agent text null
);

create index if not exists login_events_created_at_idx on public.login_events (created_at desc);
create index if not exists login_events_actor_id_idx on public.login_events (actor_id);

create table if not exists public.audit_log (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  source text not null default 'web',
  actor_id bigint null,
  actor_name text null,
  actor_username text null,
  actor_role text null,
  action text not null,
  entity text not null,
  entity_id text null,
  summary text null,
  path text null,
  payload jsonb null
);

create index if not exists audit_log_created_at_idx on public.audit_log (created_at desc);
create index if not exists audit_log_actor_id_idx on public.audit_log (actor_id);
create index if not exists audit_log_entity_idx on public.audit_log (entity);

alter table public.teachers
  add column if not exists permissions jsonb not null default '{}'::jsonb;

comment on column public.teachers.permissions is 'JSON permissions for admin/security screens';
