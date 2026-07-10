-- ================================================================
-- ระบบดูแลช่วยเหลือนักเรียน โรงเรียนนายางกลักพิทยาคม
-- สพม.ชัยภูมิ | ภาคเรียนที่ 1/2569
-- วิธีใช้: Copy ทั้งหมดไปวางใน Supabase > SQL Editor > Run
-- ================================================================

-- เปิดใช้ extension pgcrypto สำหรับ hash password
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ================================================================
-- ตารางที่ 1: ครู (teachers)
-- ================================================================
DROP TABLE IF EXISTS teachers CASCADE;
CREATE TABLE teachers (
  id          SERIAL PRIMARY KEY,
  username    TEXT UNIQUE NOT NULL,
  password    TEXT NOT NULL,
  fullname    TEXT NOT NULL,
  role        TEXT DEFAULT 'teacher' CHECK (role IN ('admin','teacher')),
  active      BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- ตารางที่ 2: ห้องเรียน (classrooms)
-- ================================================================
DROP TABLE IF EXISTS classrooms CASCADE;
CREATE TABLE classrooms (
  id           SERIAL PRIMARY KEY,
  room_name    TEXT UNIQUE NOT NULL,  -- เช่น ม.5/1
  level        INTEGER NOT NULL,      -- 1-6
  room_number  INTEGER NOT NULL,      -- 1-4
  year         INTEGER DEFAULT 2569,
  semester     INTEGER DEFAULT 1
);

-- ================================================================
-- ตารางที่ 3: ครูที่ปรึกษา-ห้องเรียน (room_teachers)
-- ================================================================
DROP TABLE IF EXISTS room_teachers CASCADE;
CREATE TABLE room_teachers (
  id           SERIAL PRIMARY KEY,
  teacher_id   INTEGER REFERENCES teachers(id),
  classroom_id INTEGER REFERENCES classrooms(id),
  is_primary   BOOLEAN DEFAULT true
);

-- ================================================================
-- ตารางที่ 4: นักเรียน (students)
-- ================================================================
DROP TABLE IF EXISTS students CASCADE;
CREATE TABLE students (
  id            SERIAL PRIMARY KEY,
  student_code  TEXT UNIQUE NOT NULL,  -- เลขประจำตัว
  fullname      TEXT NOT NULL,
  classroom_id  INTEGER REFERENCES classrooms(id),
  order_no      INTEGER,               -- เลขที่ในห้อง
  gender        TEXT,
  birthdate     DATE,
  parent_phone  TEXT,
  status        TEXT DEFAULT 'active' CHECK (status IN ('active','leave','transfer')),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- ตารางที่ 5: วิชา (subjects)
-- ================================================================
DROP TABLE IF EXISTS subjects CASCADE;
CREATE TABLE subjects (
  id           SERIAL PRIMARY KEY,
  subject_code TEXT UNIQUE NOT NULL,
  subject_name TEXT NOT NULL,
  subject_group TEXT,
  level        TEXT,
  credits      NUMERIC(3,1)
);

-- ================================================================
-- ตารางที่ 6: ตารางสอน (timetable)
-- ================================================================
DROP TABLE IF EXISTS timetable CASCADE;
CREATE TABLE timetable (
  id           SERIAL PRIMARY KEY,
  teacher_id   INTEGER REFERENCES teachers(id),
  subject_id   INTEGER REFERENCES subjects(id),
  classroom_id INTEGER REFERENCES classrooms(id),
  day_of_week  TEXT CHECK (day_of_week IN ('จันทร์','อังคาร','พุธ','พฤหัสบดี','ศุกร์')),
  period       INTEGER CHECK (period BETWEEN 1 AND 8),
  semester     INTEGER DEFAULT 1,
  year         INTEGER DEFAULT 2569
);

-- ================================================================
-- ตารางที่ 7: เช็คชื่อเช้า (morning_attendance)
-- ================================================================
DROP TABLE IF EXISTS morning_attendance CASCADE;
CREATE TABLE morning_attendance (
  id           SERIAL PRIMARY KEY,
  student_id   INTEGER REFERENCES students(id),
  teacher_id   INTEGER REFERENCES teachers(id),
  att_date     DATE NOT NULL,
  status       TEXT DEFAULT 'present' CHECK (status IN ('present','late','absent','leave')),
  remark       TEXT,
  recorded_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX ON morning_attendance(student_id, att_date);

-- ================================================================
-- ตารางที่ 8: เช็คชื่อตอนเย็น (afternoon_attendance)
-- ================================================================
DROP TABLE IF EXISTS afternoon_attendance CASCADE;
CREATE TABLE afternoon_attendance (
  id           SERIAL PRIMARY KEY,
  student_id   INTEGER REFERENCES students(id),
  teacher_id   INTEGER REFERENCES teachers(id),
  att_date     DATE NOT NULL,
  status       TEXT DEFAULT 'present' CHECK (status IN ('present','late','absent','leave')),
  remark       TEXT,
  recorded_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX ON afternoon_attendance(student_id, att_date);

-- ================================================================
-- ตารางที่ 9: บันทึกความดี (good_deeds)
-- ================================================================
DROP TABLE IF EXISTS good_deeds CASCADE;
CREATE TABLE good_deeds (
  id           SERIAL PRIMARY KEY,
  student_id   INTEGER REFERENCES students(id),
  teacher_id   INTEGER REFERENCES teachers(id),
  deed_date    DATE NOT NULL DEFAULT CURRENT_DATE,
  category     TEXT,
  description  TEXT NOT NULL,
  score        INTEGER DEFAULT 1,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- ตารางที่ 10: บันทึกพฤติกรรม (behavior_records)
-- ================================================================
DROP TABLE IF EXISTS behavior_records CASCADE;
CREATE TABLE behavior_records (
  id           SERIAL PRIMARY KEY,
  student_id   INTEGER REFERENCES students(id),
  teacher_id   INTEGER REFERENCES teachers(id),
  record_date  DATE NOT NULL DEFAULT CURRENT_DATE,
  category     TEXT,
  description  TEXT NOT NULL,
  score        INTEGER DEFAULT -1,
  action_taken TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- ตารางที่ 11: ข้อมูล SDQ
-- ================================================================
DROP TABLE IF EXISTS sdq_records CASCADE;
CREATE TABLE sdq_records (
  id           SERIAL PRIMARY KEY,
  student_id   INTEGER REFERENCES students(id),
  teacher_id   INTEGER REFERENCES teachers(id),
  record_date  DATE NOT NULL DEFAULT CURRENT_DATE,
  total_score  INTEGER,
  emotion_score INTEGER,
  conduct_score INTEGER,
  hyperactive_score INTEGER,
  peer_score   INTEGER,
  prosocial_score INTEGER,
  remark       TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- ตารางที่ 12: บันทึกเยี่ยมบ้าน (home_visit)
-- ================================================================
DROP TABLE IF EXISTS home_visits CASCADE;
CREATE TABLE home_visits (
  id           SERIAL PRIMARY KEY,
  student_id   INTEGER REFERENCES students(id),
  teacher_id   INTEGER REFERENCES teachers(id),
  visit_date   DATE NOT NULL,
  summary      TEXT,
  photo_url    TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- INSERT: ห้องเรียนทั้งหมด
-- ================================================================
INSERT INTO classrooms (room_name, level, room_number) VALUES
('ม.1/1',1,1),('ม.1/2',1,2),('ม.1/3',1,3),('ม.1/4',1,4),
('ม.2/1',2,1),('ม.2/2',2,2),('ม.2/3',2,3),('ม.2/4',2,4),
('ม.3/1',3,1),('ม.3/2',3,2),('ม.3/3',3,3),('ม.3/4',3,4),
('ม.4/1',4,1),('ม.4/2',4,2),('ม.4/3',4,3),('ม.4/4',4,4),
('ม.5/1',5,1),('ม.5/2',5,2),('ม.5/3',5,3),('ม.5/4',5,4),
('ม.6/1',6,1),('ม.6/2',6,2),('ม.6/3',6,3),('ม.6/4',6,4);

-- ================================================================
-- INSERT: ครู 46 คน (password เริ่มต้น = 1234)
-- ================================================================
INSERT INTO teachers (username, password, fullname, role) VALUES
('admin',    crypt('admin1234', gen_salt('bf')), 'ผู้ดูแลระบบ', 'admin'),
('adisak',   crypt('1234', gen_salt('bf')), 'นายอดิศักดิ์ วนาใส', 'teacher'),
('noppamas', crypt('1234', gen_salt('bf')), 'นางนพมาศ ศรีระทัต', 'teacher'),
('malinee',  crypt('1234', gen_salt('bf')), 'นางมาลินี อาบสุวรรณ์', 'teacher'),
('jantiwaporn', crypt('1234', gen_salt('bf')), 'นางสาวจันทิวาพร ภูมิโคกรักษ์', 'teacher'),
('chayaphat', crypt('1234', gen_salt('bf')), 'นางสาวชญาพัฏฐ์ วรภรไพศาล', 'teacher'),
('napat',    crypt('1234', gen_salt('bf')), 'นางสาวณภัทร ทานะสุข', 'teacher'),
('tikamporn', crypt('1234', gen_salt('bf')), 'นางสาวทิฆัมพร บุตรทิพย์', 'teacher'),
('tananya',  crypt('1234', gen_salt('bf')), 'นางสาวธนัญญา จูหมื่นไวย์', 'teacher'),
('theerisa', crypt('1234', gen_salt('bf')), 'นางสาวธีริศรา แสงเงิน', 'teacher'),
('priyakorn', crypt('1234', gen_salt('bf')), 'นางสาวปริยากร ครูทำนา', 'teacher'),
('phantong', crypt('1234', gen_salt('bf')), 'นางสาวพานทอง มนตรี', 'teacher'),
('lakkika',  crypt('1234', gen_salt('bf')), 'นางสาวลักขิกา พูที', 'teacher'),
('wanichaya', crypt('1234', gen_salt('bf')), 'นางสาววนิชยา กลิ่นสุมาลย์', 'teacher'),
('warangkana', crypt('1234', gen_salt('bf')), 'นางสาววรางคณา จันทร์งาม', 'teacher'),
('anong',    crypt('1234', gen_salt('bf')), 'นางสาวอนงค์ สิงห์สนั่น', 'teacher'),
('ananya',   crypt('1234', gen_salt('bf')), 'นางสาวอนัญญา จรรยา', 'teacher'),
('amonrat',  crypt('1234', gen_salt('bf')), 'นางสาวอมรรัตน์ เทียมจัตุรัส', 'teacher'),
('ariya',    crypt('1234', gen_salt('bf')), 'นางสาวอาริยา เจียกกระโทก', 'teacher'),
('uthumporn', crypt('1234', gen_salt('bf')), 'นางสาวอุทุมพร พลธรรม', 'teacher'),
('sujitra',  crypt('1234', gen_salt('bf')), 'นางสุจิตรา นามพิมล', 'teacher'),
('amora',    crypt('1234', gen_salt('bf')), 'นางอมรา ศึกขุนทด', 'teacher'),
('koraphat', crypt('1234', gen_salt('bf')), 'นายกรภัทร์ สิริทรัพย์พัฒนา', 'teacher'),
('jatuporn', crypt('1234', gen_salt('bf')), 'นายจตุพร บุตรเจริญ', 'teacher'),
('jaturong', crypt('1234', gen_salt('bf')), 'นายจตุรงค์ ชัยพัฒน์', 'teacher'),
('jittipong', crypt('1234', gen_salt('bf')), 'นายจิตติพงศ์ เคียงจัตุรัส', 'teacher'),
('chatchai', crypt('1234', gen_salt('bf')), 'นายชัชชัย มุ่งปั่นกลาง', 'teacher'),
('disnon',   crypt('1234', gen_salt('bf')), 'นายดิศนนท์ อุเทนสุด', 'teacher'),
('tanakom',  crypt('1234', gen_salt('bf')), 'นายธนาคม กางทา', 'teacher'),
('theerapong', crypt('1234', gen_salt('bf')), 'นายธีรพงษ์ พิมเคณา', 'teacher'),
('bodin',    crypt('1234', gen_salt('bf')), 'นายบดินทร์ พินิจมนตรี', 'teacher'),
('bunsong',  crypt('1234', gen_salt('bf')), 'นายบุญส่ง ผาสุขมูล', 'teacher'),
('patiwat',  crypt('1234', gen_salt('bf')), 'นายปฏิวัติ ศรสุรินทร์', 'teacher'),
('pongsakorn', crypt('1234', gen_salt('bf')), 'นายพงศกร กุลดิษฐ์', 'teacher'),
('pongtep',  crypt('1234', gen_salt('bf')), 'นายพงษ์เทพ ชาคาร', 'teacher'),
('palop',    crypt('1234', gen_salt('bf')), 'นายพัลลภ แก้วจัตุรัส', 'teacher'),
('phubet',   crypt('1234', gen_salt('bf')), 'นายภูเบศ ฝาชัยภูมิ', 'teacher'),
('wittawat.kh', crypt('1234', gen_salt('bf')), 'นายวิทวัช คำหา', 'teacher'),
('wittawat.wg', crypt('1234', gen_salt('bf')), 'นายวิทวัช วงค์บุตดี', 'teacher'),
('songkran', crypt('1234', gen_salt('bf')), 'นายสงกรานต์ อาบสุวรรณ์', 'teacher'),
('sanchai',  crypt('1234', gen_salt('bf')), 'นายสันต์ชัย มานิมนต์', 'teacher'),
('satit',    crypt('1234', gen_salt('bf')), 'นายสาธิต สิทธิวงศ์', 'teacher'),
('surachai', crypt('1234', gen_salt('bf')), 'นายสุรชัย วุฒิมาก', 'teacher'),
('hannarong', crypt('1234', gen_salt('bf')), 'นายหาญณรงค์ ศรีระทัต', 'teacher'),
('ittiporn', crypt('1234', gen_salt('bf')), 'นายอิทธิพร เฝ้าทรัพย์', 'teacher'),
('chalermpol', crypt('1234', gen_salt('bf')), 'นายเฉลิมพล แสงบำรุง', 'teacher'),
('siriporn', crypt('1234', gen_salt('bf')), 'ว่าที่ร้อยตรีหญิงศิริพร วันทา', 'teacher');

-- ================================================================
-- INSERT: ครูที่ปรึกษา-ห้อง
-- ================================================================
INSERT INTO room_teachers (teacher_id, classroom_id, is_primary)
SELECT t.id, c.id, true FROM teachers t, classrooms c
WHERE (t.username='sanchai'    AND c.room_name='ม.1/1')
OR    (t.username='palop'      AND c.room_name='ม.1/1')
OR    (t.username='ariya'      AND c.room_name='ม.1/2')
OR    (t.username='wittawat.wg' AND c.room_name='ม.1/2')
OR    (t.username='jaturong'   AND c.room_name='ม.1/3')
OR    (t.username='tanakom'    AND c.room_name='ม.1/4')
OR    (t.username='warangkana' AND c.room_name='ม.1/4')
OR    (t.username='priyakorn'  AND c.room_name='ม.2/1')
OR    (t.username='bodin'      AND c.room_name='ม.2/1')
OR    (t.username='tikamporn'  AND c.room_name='ม.2/2')
OR    (t.username='bunsong'    AND c.room_name='ม.2/2')
OR    (t.username='chalermpol' AND c.room_name='ม.2/3')
OR    (t.username='pongsakorn' AND c.room_name='ม.2/3')
OR    (t.username='lakkika'    AND c.room_name='ม.2/4')
OR    (t.username='pongtep'    AND c.room_name='ม.2/4')
OR    (t.username='chatchai'   AND c.room_name='ม.3/1')
OR    (t.username='satit'      AND c.room_name='ม.3/1')
OR    (t.username='sujitra'    AND c.room_name='ม.3/2')
OR    (t.username='ittiporn'   AND c.room_name='ม.3/2')
OR    (t.username='jantiwaporn' AND c.room_name='ม.3/3')
OR    (t.username='noppamas'   AND c.room_name='ม.3/3')
OR    (t.username='chayaphat'  AND c.room_name='ม.3/4')
OR    (t.username='patiwat'    AND c.room_name='ม.3/4')
OR    (t.username='siriporn'   AND c.room_name='ม.4/1')
OR    (t.username='koraphat'   AND c.room_name='ม.4/1')
OR    (t.username='theerapong' AND c.room_name='ม.4/2')
OR    (t.username='amonrat'    AND c.room_name='ม.4/2')
OR    (t.username='surachai'   AND c.room_name='ม.4/3')
OR    (t.username='phubet'     AND c.room_name='ม.4/3')
OR    (t.username='uthumporn'  AND c.room_name='ม.4/4')
OR    (t.username='songkran'   AND c.room_name='ม.4/4')
OR    (t.username='adisak'     AND c.room_name='ม.5/1')
OR    (t.username='disnon'     AND c.room_name='ม.5/1')
OR    (t.username='ananya'     AND c.room_name='ม.5/2')
OR    (t.username='anong'      AND c.room_name='ม.5/3')
OR    (t.username='theerisa'   AND c.room_name='ม.5/3')
OR    (t.username='jatuporn'   AND c.room_name='ม.5/4')
OR    (t.username='tananya'    AND c.room_name='ม.5/4')
OR    (t.username='malinee'    AND c.room_name='ม.6/1')
OR    (t.username='jittipong'  AND c.room_name='ม.6/1')
OR    (t.username='hannarong'  AND c.room_name='ม.6/2')
OR    (t.username='wanichaya'  AND c.room_name='ม.6/2')
OR    (t.username='wittawat.kh' AND c.room_name='ม.6/3')
OR    (t.username='phantong'   AND c.room_name='ม.6/3')
OR    (t.username='amora'      AND c.room_name='ม.6/4')
OR    (t.username='napat'      AND c.room_name='ม.6/4');

-- ================================================================
-- function สำหรับ Login (ใช้ใน application)
-- ================================================================
CREATE OR REPLACE FUNCTION login(p_username TEXT, p_password TEXT)
RETURNS TABLE(id INT, username TEXT, fullname TEXT, role TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT t.id, t.username, t.fullname, t.role
  FROM teachers t
  WHERE t.username = p_username
    AND t.password = crypt(p_password, t.password)
    AND t.active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

