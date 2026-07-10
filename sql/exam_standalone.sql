-- exam_standalone.sql
-- รัน SQL นี้ใน Supabase SQL Editor ก่อนใช้ฟีเจอร์ข้อสอบอิสระ (สอบซ่อม/ไม่ผูกโครงสร้าง)

-- 1. ทำ assignment_id และ structure_id เป็น nullable ใน exam_subjects
ALTER TABLE exam_subjects ALTER COLUMN assignment_id DROP NOT NULL;
ALTER TABLE exam_subjects ALTER COLUMN structure_id DROP NOT NULL;

-- 2. เพิ่ม column สำหรับข้อสอบอิสระ
ALTER TABLE exam_subjects ADD COLUMN IF NOT EXISTS is_standalone boolean NOT NULL DEFAULT false;
ALTER TABLE exam_subjects ADD COLUMN IF NOT EXISTS room_ids text;         -- เช่น "1,2,3" (classroom IDs)
ALTER TABLE exam_subjects ADD COLUMN IF NOT EXISTS created_by integer;    -- teacher ID ที่สร้าง

-- 3. ทำ assignment_id และ structure_id เป็น nullable ใน exam_results (ถ้ามี constraint)
DO $$ BEGIN ALTER TABLE exam_results ALTER COLUMN assignment_id DROP NOT NULL; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE exam_results ALTER COLUMN structure_id DROP NOT NULL; EXCEPTION WHEN others THEN NULL; END $$;

-- ตรวจสอบหลังรัน
SELECT column_name, is_nullable
FROM information_schema.columns
WHERE table_name = 'exam_subjects'
  AND column_name IN ('assignment_id','structure_id','is_standalone','room_ids','created_by');
