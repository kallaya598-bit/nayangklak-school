-- ============================================================
-- เพิ่มบทบาท "viewer" (ผู้บริหาร — ดูอย่างเดียว)
-- รันใน Supabase SQL Editor ก่อนสร้างบัญชีผู้บริหาร
-- แก้ปัญหา: new row for relation "teachers" violates check
--           constraint "teachers_role_check"
-- ============================================================

ALTER TABLE teachers DROP CONSTRAINT IF EXISTS teachers_role_check;
ALTER TABLE teachers ADD CONSTRAINT teachers_role_check
  CHECK (role IN ('admin','teacher','subject_teacher','viewer'));

-- ตรวจสอบว่าผ่าน
-- SELECT conname, pg_get_constraintdef(oid)
-- FROM pg_constraint WHERE conname = 'teachers_role_check';
