-- ================================================================
-- ขยาย Schema — ระบบดูแลช่วยเหลือนักเรียน โรงเรียนนายางกลักพิทยาคม
-- เพิ่มโมดูลใหม่โดยไม่ทับข้อมูลเดิม
-- ================================================================

-- ===== 1. ขยายตาราง teachers เพิ่ม role ครูผู้สอน =====
ALTER TABLE teachers DROP CONSTRAINT IF EXISTS teachers_role_check;
ALTER TABLE teachers ADD CONSTRAINT teachers_role_check
  CHECK (role IN ('admin','teacher','subject_teacher'));

-- ===== 2. ขยาย subjects =====
ALTER TABLE subjects ADD COLUMN IF NOT EXISTS semester INTEGER DEFAULT 1;
ALTER TABLE subjects ADD COLUMN IF NOT EXISTS year INTEGER DEFAULT 2569;
ALTER TABLE subjects ADD COLUMN IF NOT EXISTS hours_per_week INTEGER DEFAULT 1;

-- ===== 3. timetable ปรับให้ครบ =====
ALTER TABLE timetable ADD COLUMN IF NOT EXISTS start_time TIME;
ALTER TABLE timetable ADD COLUMN IF NOT EXISTS end_time TIME;
ALTER TABLE timetable ADD COLUMN IF NOT EXISTS room_location TEXT;

-- ===== 4. เช็คชื่อรายวิชา (subject_attendance) =====
DROP TABLE IF EXISTS subject_attendance CASCADE;
CREATE TABLE subject_attendance (
  id SERIAL PRIMARY KEY,
  timetable_id INTEGER REFERENCES timetable(id),
  student_id INTEGER REFERENCES students(id),
  teacher_id INTEGER REFERENCES teachers(id),
  att_date DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT NOT NULL DEFAULT 'present'
    CHECK (status IN ('present','absent','late','leave')),
  reason TEXT,
  recorded_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(timetable_id, student_id, att_date)
);

-- ===== 5. เช็คชื่อตอนเย็น ขยาย =====
ALTER TABLE afternoon_attendance DROP CONSTRAINT IF EXISTS afternoon_attendance_status_check;
ALTER TABLE afternoon_attendance ADD CONSTRAINT afternoon_attendance_status_check
  CHECK (status IN ('present','gone_home','absent','special_leave','leave'));

-- ===== 6. ประเภทความดี =====
DROP TABLE IF EXISTS good_deed_categories CASCADE;
CREATE TABLE good_deed_categories (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  default_score INTEGER DEFAULT 1,
  description TEXT,
  active BOOLEAN DEFAULT true
);
INSERT INTO good_deed_categories (name, default_score) VALUES
('ช่วยเหลือเพื่อน', 1),
('ทำความดีต่อสังคม', 2),
('ดูแลห้องเรียน', 1),
('มีน้ำใจ', 1),
('มารยาทดี', 1),
('ตรงต่อเวลา', 1),
('ผลการเรียนดีขึ้น', 2),
('อื่นๆ', 1);

-- ===== 7. ความดี ขยาย =====
ALTER TABLE good_deeds ADD COLUMN IF NOT EXISTS category_id INTEGER REFERENCES good_deed_categories(id);
ALTER TABLE good_deeds ADD COLUMN IF NOT EXISTS evidence_url TEXT;
ALTER TABLE good_deeds ADD COLUMN IF NOT EXISTS is_offset BOOLEAN DEFAULT false;
ALTER TABLE good_deeds ADD COLUMN IF NOT EXISTS offset_behavior_id INTEGER;

-- ===== 8. ประเภทพฤติกรรม =====
DROP TABLE IF EXISTS behavior_categories CASCADE;
CREATE TABLE behavior_categories (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  default_score INTEGER DEFAULT -1,
  description TEXT,
  active BOOLEAN DEFAULT true
);
INSERT INTO behavior_categories (name, default_score) VALUES
('มาสาย', -1),
('ไม่ส่งงาน', -2),
('พูดไม่สุภาพ', -2),
('ไม่เข้าเรียน', -3),
('ฝ่าฝืนระเบียบ', -3),
('ทะเลาะวิวาท', -5),
('ทุจริตการสอบ', -5),
('อื่นๆ', -1);

-- ===== 9. พฤติกรรม ขยาย =====
ALTER TABLE behavior_records ADD COLUMN IF NOT EXISTS category_id INTEGER REFERENCES behavior_categories(id);
ALTER TABLE behavior_records ADD COLUMN IF NOT EXISTS management_status TEXT DEFAULT 'pending'
  CHECK (management_status IN ('pending','warned','parent_notified','following','closed'));
ALTER TABLE behavior_records ADD COLUMN IF NOT EXISTS is_offset BOOLEAN DEFAULT false;

-- ===== 10. โครงสร้างคะแนนรายวิชา =====
DROP TABLE IF EXISTS grade_structures CASCADE;
CREATE TABLE grade_structures (
  id SERIAL PRIMARY KEY,
  subject_id INTEGER REFERENCES subjects(id),
  name TEXT NOT NULL,
  max_score NUMERIC(6,2) NOT NULL,
  weight NUMERIC(5,2) DEFAULT 1,
  grade_type TEXT DEFAULT 'homework'
    CHECK (grade_type IN ('homework','quiz','midterm','final','other')),
  order_no INTEGER DEFAULT 1
);

-- ===== 11. คะแนนรายวิชา =====
DROP TABLE IF EXISTS grades CASCADE;
CREATE TABLE grades (
  id SERIAL PRIMARY KEY,
  structure_id INTEGER REFERENCES grade_structures(id),
  student_id INTEGER REFERENCES students(id),
  teacher_id INTEGER REFERENCES teachers(id),
  score NUMERIC(6,2),
  recorded_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  note TEXT,
  UNIQUE(structure_id, student_id)
);

-- ===== 12. ประวัติแก้ไขคะแนน =====
DROP TABLE IF EXISTS grade_history CASCADE;
CREATE TABLE grade_history (
  id SERIAL PRIMARY KEY,
  grade_id INTEGER REFERENCES grades(id),
  old_score NUMERIC(6,2),
  new_score NUMERIC(6,2),
  changed_by INTEGER REFERENCES teachers(id),
  changed_at TIMESTAMPTZ DEFAULT NOW(),
  reason TEXT
);

-- ===== 13. Audit Log =====
DROP TABLE IF EXISTS audit_log CASCADE;
CREATE TABLE audit_log (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES teachers(id),
  action TEXT NOT NULL,
  table_name TEXT,
  record_id INTEGER,
  old_data JSONB,
  new_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===== 14. คะแนนสุทธิ (คำนวณอัตโนมัติ) =====
DROP TABLE IF EXISTS score_summary CASCADE;
CREATE TABLE score_summary (
  id SERIAL PRIMARY KEY,
  student_id INTEGER REFERENCES students(id) UNIQUE,
  good_score INTEGER DEFAULT 0,
  bad_score INTEGER DEFAULT 0,
  net_score INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===== Function: คำนวณคะแนนสุทธิ =====
CREATE OR REPLACE FUNCTION calc_score_summary(p_student_id INTEGER)
RETURNS void AS $$
DECLARE
  v_good INTEGER;
  v_bad INTEGER;
BEGIN
  SELECT COALESCE(SUM(score),0) INTO v_good
  FROM good_deeds WHERE student_id = p_student_id;

  SELECT COALESCE(SUM(score),0) INTO v_bad
  FROM behavior_records WHERE student_id = p_student_id;

  INSERT INTO score_summary (student_id, good_score, bad_score, net_score, updated_at)
  VALUES (p_student_id, v_good, v_bad, v_good + v_bad, NOW())
  ON CONFLICT (student_id)
  DO UPDATE SET good_score=v_good, bad_score=v_bad,
    net_score=v_good+v_bad, updated_at=NOW();
END;
$$ LANGUAGE plpgsql;

-- ===== 15. ตั้งค่าระบบ =====
DROP TABLE IF EXISTS system_settings CASCADE;
CREATE TABLE system_settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO system_settings (key, value, description) VALUES
('school_name', 'โรงเรียนนายางกลักพิทยาคม', 'ชื่อโรงเรียน'),
('school_sub', 'สำนักงานเขตพื้นที่การศึกษามัธยมศึกษาชัยภูมิ', 'สังกัด'),
('current_year', '2569', 'ปีการศึกษาปัจจุบัน'),
('current_semester', '1', 'ภาคเรียนปัจจุบัน'),
('good_deed_base', '100', 'คะแนนความดีเริ่มต้น'),
('allow_offset', 'true', 'อนุญาตให้ใช้ความดีหักลบพฤติกรรมได้');

