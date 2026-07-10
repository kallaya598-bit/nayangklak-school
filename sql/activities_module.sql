-- ============================================================
-- โมดูลกิจกรรมพัฒนาผู้เรียน / ชุมนุม (ลงทะเบียน · เช็คชื่อ · ผ่าน/ไม่ผ่าน)
-- รันใน Supabase SQL Editor (รันซ้ำได้ ปลอดภัย) · RLS ปิดตามนโยบายระบบ
-- ============================================================

-- 1) กิจกรรม
CREATE TABLE IF NOT EXISTS activities (
  id          SERIAL PRIMARY KEY,
  name        TEXT NOT NULL,                 -- ชื่อกิจกรรม/ชุมนุม
  category    TEXT NOT NULL DEFAULT 'club',  -- 'club' (ชุมนุม) | 'develop' (พัฒนาผู้เรียน)
  atype       TEXT,                          -- ชุมนุม/ลูกเสือ/เนตรนารี/ยุวกาชาด/ผู้บำเพ็ญประโยชน์/นศท.
  counts_both BOOLEAN DEFAULT false,         -- นับเป็นทั้งชุมนุม+พัฒนา (เช่น นศท.)
  capacity    INTEGER DEFAULT 0,             -- จำนวนรับ (0 = ไม่จำกัด)
  day         TEXT,                          -- วันที่จัด
  period      TEXT,                          -- คาบ/เวลา
  location    TEXT,                          -- สถานที่
  description TEXT,
  level_min   INTEGER,                       -- ระดับชั้นต่ำสุดที่รับ (1-6, NULL=ทุกชั้น)
  level_max   INTEGER,
  is_open     BOOLEAN DEFAULT true,          -- เปิดรับสมัคร
  allow_self  BOOLEAN DEFAULT false,         -- ให้นักเรียนสมัครเองได้ (ชุมนุม=true)
  term        INTEGER DEFAULT 1,
  year        INTEGER DEFAULT 2569,
  created_by  INTEGER REFERENCES teachers(id),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2) ครูที่ปรึกษากิจกรรม (หลายคนต่อกิจกรรม)
CREATE TABLE IF NOT EXISTS activity_teachers (
  id          SERIAL PRIMARY KEY,
  activity_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  teacher_id  INTEGER NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
  role        TEXT DEFAULT 'co',             -- 'owner' | 'co'
  UNIQUE(activity_id, teacher_id)
);

-- 3) การสมัคร/สมาชิก (นักเรียนข้ามห้องได้)
CREATE TABLE IF NOT EXISTS activity_enrollments (
  id            SERIAL PRIMARY KEY,
  activity_id   INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  student_id    INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  registered_by TEXT DEFAULT 'student',      -- 'student' | 'teacher:<id>'
  result        TEXT,                         -- NULL | 'pass' | 'fail'
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(activity_id, student_id)
);

-- 4) เช็คชื่อกิจกรรม
CREATE TABLE IF NOT EXISTS activity_attendance (
  id          SERIAL PRIMARY KEY,
  activity_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  student_id  INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  att_date    DATE NOT NULL,
  status      TEXT,                           -- present/absent/late/leave
  UNIQUE(activity_id, student_id, att_date)
);

CREATE INDEX IF NOT EXISTS idx_act_enr_student ON activity_enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_act_enr_activity ON activity_enrollments(activity_id);
CREATE INDEX IF NOT EXISTS idx_act_teacher ON activity_teachers(teacher_id);

-- ปิด RLS (โปรเจกต์นี้ปิด RLS ทุกตาราง) — สำคัญ! ไม่งั้นบันทึกไม่ได้
ALTER TABLE activities            DISABLE ROW LEVEL SECURITY;
ALTER TABLE activity_teachers     DISABLE ROW LEVEL SECURITY;
ALTER TABLE activity_enrollments  DISABLE ROW LEVEL SECURITY;
ALTER TABLE activity_attendance   DISABLE ROW LEVEL SECURITY;

-- เสร็จแล้ว ✅
