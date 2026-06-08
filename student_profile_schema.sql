-- ================================================================
-- ขยาย Schema: เมนูข้อมูลนักเรียน (Student Profile)
-- โรงเรียนนายางกลักพิทยาคม — รันใน Supabase > SQL Editor > Run
-- ปลอดภัย: ไม่ลบข้อมูลเดิม ใช้ ADD COLUMN IF NOT EXISTS
-- ================================================================

-- ===== 1. เพิ่มฟิลด์รายละเอียดในตาราง students =====
ALTER TABLE students ADD COLUMN IF NOT EXISTS nickname     TEXT;       -- ชื่อเล่น
ALTER TABLE students ADD COLUMN IF NOT EXISTS fullname_en  TEXT;       -- ชื่อ-สกุล อังกฤษ
ALTER TABLE students ADD COLUMN IF NOT EXISTS citizen_id   TEXT;       -- เลขบัตรประชาชน
ALTER TABLE students ADD COLUMN IF NOT EXISTS phone        TEXT;       -- เบอร์โทรนักเรียน
ALTER TABLE students ADD COLUMN IF NOT EXISTS blood_type   TEXT;       -- กรุ๊ปเลือด
ALTER TABLE students ADD COLUMN IF NOT EXISTS address      TEXT;       -- ที่อยู่
ALTER TABLE students ADD COLUMN IF NOT EXISTS photo_url    TEXT;       -- รูปนักเรียน (data URL หรือ link)
ALTER TABLE students ADD COLUMN IF NOT EXISTS religion     TEXT;       -- ศาสนา
ALTER TABLE students ADD COLUMN IF NOT EXISTS updated_at   TIMESTAMPTZ DEFAULT NOW();

-- ===== 2. ตารางข้อมูลครอบครัว/ผู้ปกครอง =====
CREATE TABLE IF NOT EXISTS parents (
  id                SERIAL PRIMARY KEY,
  student_id        INTEGER REFERENCES students(id) ON DELETE CASCADE UNIQUE,
  father_name       TEXT,
  father_phone      TEXT,
  father_job        TEXT,
  mother_name       TEXT,
  mother_phone      TEXT,
  mother_job        TEXT,
  guardian_name     TEXT,
  guardian_phone    TEXT,
  guardian_relation TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ===== 3. ปิด RLS (ตามนโยบายโปรเจกต์) =====
ALTER TABLE parents DISABLE ROW LEVEL SECURITY;

-- ===== 4. View รวมข้อมูลนักเรียน + ห้อง + ผู้ปกครอง (อ่านง่าย) =====
CREATE OR REPLACE VIEW student_full AS
SELECT
  s.*,
  c.room_name, c.level, c.room_number,
  p.father_name, p.father_phone, p.mother_name, p.mother_phone,
  p.guardian_name, p.guardian_phone, p.guardian_relation
FROM students s
LEFT JOIN classrooms c ON c.id = s.classroom_id
LEFT JOIN parents p ON p.student_id = s.id;

-- ================================================================
-- เสร็จแล้ว — กลับไปใช้งานเมนู "ข้อมูลนักเรียน" ในเว็บได้เลย
-- ================================================================
