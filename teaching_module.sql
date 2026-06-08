-- ================================================================
-- โมดูล: ระบบจัดการการสอนครู (Teaching Management)
-- โรงเรียนนายางกลักพิทยาคม — เพิ่มเข้าระบบเดิมโดยไม่ทับข้อมูล
-- รันใน Supabase SQL Editor (RLS ปิดอยู่แล้ว)
-- ================================================================

-- ===== 1. กลุ่มเรียนรายวิชา (1 วิชา + 1 ห้อง + กลุ่มที่ N) =====
CREATE TABLE IF NOT EXISTS teaching_assignments (
  id SERIAL PRIMARY KEY,
  subject_id INTEGER REFERENCES subjects(id),
  classroom_id INTEGER REFERENCES classrooms(id),
  teacher_id INTEGER REFERENCES teachers(id),    -- ครูเจ้าของวิชา
  group_no INTEGER DEFAULT 1,
  semester INTEGER DEFAULT 1,
  year INTEGER DEFAULT 2569,
  attendance_mode TEXT DEFAULT 'period',         -- period | daily
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(subject_id, classroom_id, group_no, semester, year)
);

-- ===== 2. ลงทะเบียนนักเรียนเข้ากลุ่มเรียน =====
CREATE TABLE IF NOT EXISTS enrollments (
  id SERIAL PRIMARY KEY,
  assignment_id INTEGER REFERENCES teaching_assignments(id) ON DELETE CASCADE,
  student_id INTEGER REFERENCES students(id),
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(assignment_id, student_id)
);

-- ===== 3. ครูร่วมสอน / คำเชิญ =====
CREATE TABLE IF NOT EXISTS assignment_teachers (
  id SERIAL PRIMARY KEY,
  assignment_id INTEGER REFERENCES teaching_assignments(id) ON DELETE CASCADE,
  teacher_id INTEGER REFERENCES teachers(id),
  role TEXT DEFAULT 'co',                         -- owner | co
  invite_status TEXT DEFAULT 'accepted',          -- pending | accepted
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(assignment_id, teacher_id)
);

-- ===== 4. ผูกตารางสอน / เช็คชื่อ / โครงสร้างคะแนน เข้ากับกลุ่มเรียน =====
ALTER TABLE timetable          ADD COLUMN IF NOT EXISTS assignment_id INTEGER REFERENCES teaching_assignments(id);
ALTER TABLE subject_attendance ADD COLUMN IF NOT EXISTS assignment_id INTEGER REFERENCES teaching_assignments(id);
ALTER TABLE subject_attendance ADD COLUMN IF NOT EXISTS period INTEGER;
ALTER TABLE grade_structures   ADD COLUMN IF NOT EXISTS assignment_id INTEGER REFERENCES teaching_assignments(id);

-- subject_attendance เดิม UNIQUE(timetable_id, student_id, att_date)
-- เพิ่ม UNIQUE ใหม่สำหรับการเช็คชื่อแบบผูกกลุ่มเรียน+คาบ (กันซ้ำตอน upsert)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'subject_attendance_assign_uq'
  ) THEN
    ALTER TABLE subject_attendance
      ADD CONSTRAINT subject_attendance_assign_uq
      UNIQUE (assignment_id, student_id, att_date, period);
  END IF;
END $$;

-- ===== 4.5 ปิด RLS ให้ตรงกับตารางอื่นในระบบ (สำคัญมาก!) =====
-- ตารางที่สร้างใหม่จะถูกเปิด RLS อัตโนมัติ ทำให้ insert/update ไม่ได้ (error 42501)
ALTER TABLE teaching_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments          DISABLE ROW LEVEL SECURITY;
ALTER TABLE assignment_teachers  DISABLE ROW LEVEL SECURITY;
-- ตารางเดิมที่สร้างใน expand_schema.sql ก็ถูกเปิด RLS ไว้ ปิดด้วยให้บันทึกได้
ALTER TABLE subject_attendance   DISABLE ROW LEVEL SECURITY;
ALTER TABLE grade_structures     DISABLE ROW LEVEL SECURITY;
ALTER TABLE grades               DISABLE ROW LEVEL SECURITY;

-- ===== 5. ดัชนีช่วยค้นหา =====
CREATE INDEX IF NOT EXISTS idx_ta_teacher    ON teaching_assignments(teacher_id);
CREATE INDEX IF NOT EXISTS idx_enr_assign    ON enrollments(assignment_id);
CREATE INDEX IF NOT EXISTS idx_sa_assign     ON subject_attendance(assignment_id, att_date);
CREATE INDEX IF NOT EXISTS idx_gs_assign     ON grade_structures(assignment_id);

-- ================================================================
-- 6. ข้อมูลตัวอย่าง — รายวิชา (subjects ว่างอยู่ ใส่เพื่อให้ทดสอบได้)
--    subject_group = กลุ่มสาระ, level = ระดับชั้น
-- ================================================================
INSERT INTO subjects (subject_code, subject_name, subject_group, level, credits) VALUES
  ('ว32203', 'ฟิสิกส์ 3',            'วิทยาศาสตร์และเทคโนโลยี', 'ม.5', 1.5),
  ('ว30283', 'การสร้างสื่อดิจิทัล',  'วิทยาศาสตร์และเทคโนโลยี', 'ม.6', 1.0),
  ('ว33205', 'ฟิสิกส์ 5',            'วิทยาศาสตร์และเทคโนโลยี', 'ม.6', 1.5)
ON CONFLICT (subject_code) DO NOTHING;

-- ================================================================
-- เสร็จสิ้น — ตรวจผล:
--   SELECT * FROM teaching_assignments;
--   SELECT * FROM enrollments;
--   SELECT * FROM subjects;
-- ================================================================
