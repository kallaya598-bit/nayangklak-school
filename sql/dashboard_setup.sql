-- ============================================================
-- ตั้งค่าฐานข้อมูลสำหรับแดชบอร์ด ผู้บริหาร / นักเรียน / ผู้ปกครอง
-- รันใน Supabase SQL Editor (รันซ้ำได้ ปลอดภัย)
-- ============================================================

-- 1) บทบาทผู้บริหาร (viewer) — เผื่อยังไม่ได้รัน add_viewer_role.sql
ALTER TABLE teachers DROP CONSTRAINT IF EXISTS teachers_role_check;
ALTER TABLE teachers ADD CONSTRAINT teachers_role_check
  CHECK (role IN ('admin','teacher','subject_teacher','viewer'));

-- 2) สถานะ "เผยแพร่ผลการเรียน" รายกลุ่มเรียน
--    ครูเปิด published=true → นักเรียน/ผู้ปกครองจึงเห็นเกรดของกลุ่มนั้น
ALTER TABLE teaching_assignments
  ADD COLUMN IF NOT EXISTS published BOOLEAN DEFAULT false;

-- เสร็จแล้ว ✅
