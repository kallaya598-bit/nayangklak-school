-- ============================================================================
-- Backfill สำหรับ Coin + Number Lottery V2
-- รันหลัง coin_lottery_v2.sql
-- ไม่แจกเหรียญย้อนหลัง และไม่เปิดโมดูลให้รายวิชาใดโดยอัตโนมัติ
-- ============================================================================

begin;

-- สร้าง configuration ปิดไว้ก่อน ครูประจำวิชาเป็นผู้เปิดจากหน้าเว็บ
insert into public.reward_assignment_settings(
  assignment_id,school_year,semester,enabled,opening_balance
)
select ta.id,ta.year,ta.semester,false,0
from public.teaching_assignments ta
on conflict(assignment_id) do nothing;

-- สร้าง session อ้างอิงจากประวัติเช็กชื่อเดิมเพื่อให้รายงานย้อนหลังต่อเนื่อง
-- ไม่มี reward_attendance_awards จึงไม่สร้างเหรียญย้อนหลัง
insert into public.reward_subject_sessions(
  assignment_id,timetable_id,session_date,period,status,recorded_by,recorded_at
)
select
  sa.assignment_id,
  min(sa.timetable_id),
  sa.att_date,
  sa.period,
  'completed',
  min(sa.teacher_id),
  max(sa.recorded_at)
from public.subject_attendance sa
where sa.assignment_id is not null and sa.period is not null
group by sa.assignment_id,sa.att_date,sa.period
on conflict(assignment_id,session_date,period) do nothing;

commit;

-- ผลที่ควรตรวจหลังรัน:
-- select count(*) from reward_assignment_settings;
-- select count(*) from reward_subject_sessions;
-- select count(*) from reward_wallets;  -- ต้องยังเป็น 0 จนกว่าครูเปิดใช้/แจกเหรียญ
