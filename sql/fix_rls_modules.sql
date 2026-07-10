-- ============================================================
-- แก้ปัญหา "บันทึกไม่ได้" — new row violates row-level security policy
-- ปิด RLS บนตารางใหม่ทุกตัว (โปรเจกต์นี้ปิด RLS ทุกตารางตามนโยบาย)
-- รันใน Supabase SQL Editor ครั้งเดียว (รันซ้ำได้ ปลอดภัย)
-- ============================================================

ALTER TABLE activities            DISABLE ROW LEVEL SECURITY;
ALTER TABLE activity_teachers     DISABLE ROW LEVEL SECURITY;
ALTER TABLE activity_enrollments  DISABLE ROW LEVEL SECURITY;
ALTER TABLE activity_attendance   DISABLE ROW LEVEL SECURITY;
ALTER TABLE mh_assessments        DISABLE ROW LEVEL SECURITY;

-- เสร็จแล้ว ✅  กลับไปกดบันทึกกิจกรรม/แบบประเมินได้เลย
