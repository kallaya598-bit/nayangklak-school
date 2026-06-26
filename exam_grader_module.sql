-- ระบบตรวจข้อสอบ OMR
-- รันใน Supabase SQL Editor ถ้ายังไม่มีตาราง exam_subjects / exam_results

create table if not exists exam_subjects (
  id bigint generated always as identity primary key,
  subject_name text not null,
  class_level text,
  room text,
  exam_title text,
  school_name text default 'โรงเรียนนายางกลักพิทยาคม',
  num_questions int not null default 20,
  choices int not null default 4,
  answer_key jsonb not null default '{}'::jsonb,
  question_scores jsonb not null default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table exam_subjects disable row level security;
create index if not exists idx_exam_subjects_name on exam_subjects(subject_name);

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
  student_name text,
  student_no text,
  room text,
  score numeric,
  total numeric,
  percent numeric,
  answers jsonb,
  graded_at timestamptz default now()
);

alter table exam_results disable row level security;
create index if not exists idx_exam_results_subject on exam_results(subject_id);

alter table exam_subjects
  add column if not exists choices int not null default 4,
  add column if not exists question_scores jsonb not null default '{}'::jsonb;

alter table exam_results alter column score type numeric using score::numeric;
alter table exam_results alter column total type numeric using total::numeric;
