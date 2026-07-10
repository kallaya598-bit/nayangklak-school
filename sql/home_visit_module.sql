-- ============================================================
-- โมดูลการเยี่ยมบ้านนักเรียน (ระบบดูแลช่วยเหลือนักเรียน สพฐ.)
-- ขั้นที่ 1 การรู้จักนักเรียนเป็นรายบุคคล
-- รันใน Supabase SQL Editor (รันซ้ำได้ ปลอดภัย) · RLS ปิดตามนโยบายระบบ
-- ============================================================

-- ---------- 1) ตารางบันทึกการเยี่ยมบ้าน ----------
-- สร้างโครงเริ่มต้น (ถ้ายังไม่มี)
CREATE TABLE IF NOT EXISTS home_visits (
  id            SERIAL PRIMARY KEY,
  student_id    INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE
);

-- เพิ่มคอลัมน์ทีละตัวแบบปลอดภัย (รองรับกรณีตารางเดิมมีอยู่แล้วแต่คอลัมน์ไม่ครบ)
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS year            INTEGER NOT NULL DEFAULT 2569; -- ปีการศึกษา (เยี่ยม 1 ครั้ง/ปี)
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS visit_date      DATE;        -- วันที่เยี่ยม
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS visitors        TEXT;        -- ครูผู้ออกเยี่ยม
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS risk_group      TEXT;        -- 'ปกติ'|'เสี่ยง'|'มีปัญหา'|'พิเศษ'
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS risk            JSONB;       -- ผลคัดกรอง 5 ด้าน
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS lat             DOUBLE PRECISION;
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS lng             DOUBLE PRECISION;
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS photos          JSONB DEFAULT '[]'::jsonb;
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS sign_parent     TEXT;
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS sign_teacher    TEXT;
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS data            JSONB DEFAULT '{}'::jsonb;
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS teacher_opinion TEXT;
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS created_by      INTEGER;
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS created_at      TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE home_visits ADD COLUMN IF NOT EXISTS updated_at      TIMESTAMPTZ DEFAULT NOW();

-- กันปัญหานักเรียนกรอกแบบฟอร์มเองไม่ได้: ตารางเดิม (จากสคีมาเก่าก่อนไฟล์นี้) มี visit_date เป็น
-- NOT NULL อยู่ — แต่ visit_date คือ "วันที่ครูออกเยี่ยม" ซึ่งนักเรียนไม่ได้กรอกตอนส่งฟอร์ม
-- (เห็น error 23502 null value in column "visit_date" ตอน insert จากฝั่งนักเรียน) จึงต้องเปิดให้เป็น NULL ได้
ALTER TABLE home_visits ALTER COLUMN visit_date DROP NOT NULL;

-- เยี่ยม 1 ครั้ง/ปีการศึกษา ต่อคน (สร้าง unique constraint ถ้ายังไม่มี — จำเป็นต่อ upsert)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'home_visits_student_year_key') THEN
    ALTER TABLE home_visits ADD CONSTRAINT home_visits_student_year_key UNIQUE (student_id, year);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_hv_student ON home_visits(student_id);
CREATE INDEX IF NOT EXISTS idx_hv_year ON home_visits(year);

-- ปิด RLS (โปรเจกต์นี้ปิด RLS ทุกตาราง) — สำคัญ! ไม่งั้นบันทึกไม่ได้
ALTER TABLE home_visits DISABLE ROW LEVEL SECURITY;

-- ---------- 2) Storage bucket สำหรับรูปบ้าน/นักเรียน ----------
-- bucket ชื่อ 'homevisit' แบบ public (เปิดให้ดูรูปผ่าน URL ตรงได้)
INSERT INTO storage.buckets (id, name, public)
VALUES ('homevisit', 'homevisit', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- นโยบายให้ anon (ระบบใช้ anon key) อัปโหลด/อ่าน/ลบรูปใน bucket นี้ได้
DROP POLICY IF EXISTS "homevisit_read"   ON storage.objects;
DROP POLICY IF EXISTS "homevisit_insert" ON storage.objects;
DROP POLICY IF EXISTS "homevisit_update" ON storage.objects;
DROP POLICY IF EXISTS "homevisit_delete" ON storage.objects;

CREATE POLICY "homevisit_read"   ON storage.objects FOR SELECT
  USING (bucket_id = 'homevisit');
CREATE POLICY "homevisit_insert" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'homevisit');
CREATE POLICY "homevisit_update" ON storage.objects FOR UPDATE
  USING (bucket_id = 'homevisit');
CREATE POLICY "homevisit_delete" ON storage.objects FOR DELETE
  USING (bucket_id = 'homevisit');

-- เสร็จแล้ว ✅  (ถ้าหน้าเว็บขึ้น 404 ที่ /rest/v1/home_visits แปลว่ายังไม่ได้รัน SQL นี้)
