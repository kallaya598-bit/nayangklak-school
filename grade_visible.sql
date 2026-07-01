-- รัน SQL นี้ใน Supabase SQL Editor (รันซ้ำได้เลย ไม่มีผลเสีย)

ALTER TABLE grade_structures
  ADD COLUMN IF NOT EXISTS student_visible BOOLEAN DEFAULT TRUE;

-- แก้ DEFAULT ให้ถูกต้องในกรณีที่ column เคยถูกสร้างมาก่อน
ALTER TABLE grade_structures
  ALTER COLUMN student_visible SET DEFAULT TRUE;

-- รีเซ็ตทุกแถวให้เปิด (รวมที่เป็น false หรือ null)
UPDATE grade_structures SET student_visible = TRUE;
