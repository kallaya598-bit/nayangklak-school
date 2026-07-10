-- =======================================================
-- Student Photo Setup
-- รัน SQL นี้ใน Supabase SQL Editor ก่อนใช้งานรูปนักเรียน
-- =======================================================

-- 1. เพิ่มคอลัมน์ photo_url ในตาราง students (ถ้ายังไม่มี)
ALTER TABLE students ADD COLUMN IF NOT EXISTS photo_url text;

-- 2. สร้าง Storage bucket "students" (public)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'students', 'students', true,
  2097152,  -- 2MB max per file
  ARRAY['image/jpeg','image/png','image/webp']
)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 3. Policy: ให้ทุกคนอ่านได้ (public bucket)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'students_photo_select' AND tablename = 'objects'
  ) THEN
    CREATE POLICY "students_photo_select" ON storage.objects
      FOR SELECT USING (bucket_id = 'students');
  END IF;
END $$;

-- 4. Policy: ให้ anon อัปโหลดได้
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'students_photo_insert' AND tablename = 'objects'
  ) THEN
    CREATE POLICY "students_photo_insert" ON storage.objects
      FOR INSERT WITH CHECK (bucket_id = 'students');
  END IF;
END $$;

-- 5. Policy: ให้ anon อัปเดตได้ (upsert)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'students_photo_update' AND tablename = 'objects'
  ) THEN
    CREATE POLICY "students_photo_update" ON storage.objects
      FOR UPDATE USING (bucket_id = 'students');
  END IF;
END $$;

-- 6. Policy: ให้ anon ลบได้
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'students_photo_delete' AND tablename = 'objects'
  ) THEN
    CREATE POLICY "students_photo_delete" ON storage.objects
      FOR DELETE USING (bucket_id = 'students');
  END IF;
END $$;

-- ตรวจสอบ
-- SELECT id, name, public FROM storage.buckets WHERE id = 'students';
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'students' AND column_name = 'photo_url';
