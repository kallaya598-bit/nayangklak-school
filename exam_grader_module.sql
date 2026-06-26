-- ระบบตรวจข้อสอบ OMR
-- รันใน Supabase SQL Editor ถ้ายังไม่มีตาราง exam_subjects / exam_results

create table if not exists exam_subjects (
  id bigint generated always as identity primary key,
  assignment_id integer,
  structure_id integer,
  scope text not null default 'single',
  subject_name text not null,
  class_level text,
  room text,
  exam_title text,
  school_name text default 'โรงเรียนนายางกลักพิทยาคม',
  num_questions int not null default 20,
  choices int not null default 4,
  objective_full numeric not null default 0,
  subjective_full numeric not null default 0,
  target_full numeric,
  answer_key jsonb not null default '{}'::jsonb,
  question_scores jsonb not null default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table exam_subjects disable row level security;
create index if not exists idx_exam_subjects_name on exam_subjects(subject_name);
create index if not exists idx_exam_subjects_target on exam_subjects(assignment_id, structure_id);
create unique index if not exists ux_exam_subjects_single_slot
  on exam_subjects(structure_id, assignment_id)
  where scope <> 'shared';
create unique index if not exists ux_exam_subjects_shared_slot
  on exam_subjects(structure_id)
  where scope = 'shared';

create or replace function set_exam_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_exam_subjects_updated on exam_subjects;
create trigger trg_exam_subjects_updated
  before update on exam_subjects
  for each row execute function set_exam_updated_at();

create table if not exists exam_results (
  id bigint generated always as identity primary key,
  subject_id bigint references exam_subjects(id) on delete cascade,
  assignment_id integer,
  structure_id integer,
  student_id integer,
  student_name text,
  student_no text,
  room text,
  objective_score numeric,
  objective_total numeric,
  subjective_score numeric,
  subjective_total numeric,
  raw_score numeric,
  raw_total numeric,
  score numeric,
  total numeric,
  percent numeric,
  answers jsonb,
  qr_data jsonb,
  map_method text,
  issue text,
  graded_at timestamptz default now()
);

alter table exam_results disable row level security;
create index if not exists idx_exam_results_subject on exam_results(subject_id);

alter table exam_subjects
  add column if not exists assignment_id integer,
  add column if not exists structure_id integer,
  add column if not exists scope text not null default 'single',
  add column if not exists choices int not null default 4,
  add column if not exists objective_full numeric not null default 0,
  add column if not exists subjective_full numeric not null default 0,
  add column if not exists target_full numeric,
  add column if not exists question_scores jsonb not null default '{}'::jsonb;

alter table exam_results
  add column if not exists assignment_id integer,
  add column if not exists structure_id integer,
  add column if not exists student_id integer,
  add column if not exists objective_score numeric,
  add column if not exists objective_total numeric,
  add column if not exists subjective_score numeric,
  add column if not exists subjective_total numeric,
  add column if not exists raw_score numeric,
  add column if not exists raw_total numeric,
  add column if not exists qr_data jsonb,
  add column if not exists map_method text,
  add column if not exists issue text;

alter table exam_results alter column score type numeric using score::numeric;
alter table exam_results alter column total type numeric using total::numeric;
create index if not exists idx_exam_results_student_slot on exam_results(structure_id, student_id);
