-- ============================================================
-- โมดูลแบบประเมินสุขภาพจิต: SDQ / EQ / PHQ (ซึมเศร้า+เสี่ยงฆ่าตัวตาย)
-- รันใน Supabase SQL Editor (รันซ้ำได้ ปลอดภัย) · RLS ปิดตามนโยบายระบบ
-- ============================================================

CREATE TABLE IF NOT EXISTS mh_assessments (
  id          SERIAL PRIMARY KEY,
  student_id  INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  kind        TEXT NOT NULL,              -- 'sdq' | 'eq' | 'phq'
  form        TEXT NOT NULL DEFAULT 'self', -- 'student' | 'parent' | 'teacher' | 'self'
  answers     JSONB,                       -- คำตอบรายข้อ {"0":2,"1":1,...}
  scores      JSONB,                       -- คะแนนรายด้าน {"emotion":4,...}
  result      TEXT,                        -- ข้อความแปลผลรวม
  risk_level  TEXT,                        -- 'normal'|'risk'|'problem'|'low'|'moderate'|'high'
  assessor    TEXT,                        -- ผู้กรอก เช่น 'teacher:5' / 'student' / 'parent'
  year        INTEGER DEFAULT 2569,
  term        INTEGER DEFAULT 1,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(student_id, kind, form, year, term)
);

CREATE INDEX IF NOT EXISTS idx_mh_student ON mh_assessments(student_id);
CREATE INDEX IF NOT EXISTS idx_mh_kind ON mh_assessments(kind, form);

-- ปิด RLS (โปรเจกต์นี้ปิด RLS ทุกตาราง) — สำคัญ! ไม่งั้นบันทึกไม่ได้
ALTER TABLE mh_assessments DISABLE ROW LEVEL SECURITY;

-- เสร็จแล้ว ✅
