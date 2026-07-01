-- เพิ่มคอลัมน์ student_visible ใน grade_structures
-- รัน SQL นี้ใน Supabase SQL Editor ก่อนใช้ฟีเจอร์เปิด/ปิดช่องคะแนน

ALTER TABLE grade_structures
  ADD COLUMN IF NOT EXISTS student_visible BOOLEAN DEFAULT TRUE;

-- อัปเดตแถวเก่าที่มีอยู่แล้วให้เปิดทั้งหมดก่อน
UPDATE grade_structures SET student_visible = TRUE WHERE student_visible IS NULL;
