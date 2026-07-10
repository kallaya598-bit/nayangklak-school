-- ================================================================
-- RPC สำหรับ Admin Panel — ระบบดูแลช่วยเหลือนักเรียน
-- รหัสผ่านครูเข้ารหัส bcrypt (pgcrypto) จึงต้องใช้ RPC ในการตั้ง/เปลี่ยน
-- รันใน Supabase SQL Editor
-- ================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- เผื่อ role ยังไม่รองรับ subject_teacher
ALTER TABLE teachers DROP CONSTRAINT IF EXISTS teachers_role_check;
ALTER TABLE teachers ADD CONSTRAINT teachers_role_check
  CHECK (role IN ('admin','teacher','subject_teacher'));

-- เพิ่มครูใหม่ (hash รหัสผ่าน) — คืนค่า id ครู
CREATE OR REPLACE FUNCTION admin_create_teacher(
  p_username TEXT, p_password TEXT, p_fullname TEXT, p_role TEXT DEFAULT 'teacher'
) RETURNS INT AS $$
  INSERT INTO teachers(username, password, fullname, role, active)
  VALUES (lower(trim(p_username)), crypt(p_password, gen_salt('bf')), trim(p_fullname),
          COALESCE(NULLIF(trim(p_role),''),'teacher'), true)
  RETURNING id;
$$ LANGUAGE sql SECURITY DEFINER;

-- เปลี่ยน/รีเซ็ตรหัสผ่านครู (hash bcrypt)
CREATE OR REPLACE FUNCTION admin_set_password(
  p_teacher_id INT, p_new_password TEXT
) RETURNS VOID AS $$
  UPDATE teachers SET password = crypt(p_new_password, gen_salt('bf'))
  WHERE id = p_teacher_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- ================================================================
-- ตรวจผล:
--   SELECT admin_create_teacher('testuser','1234','ครูทดสอบ','teacher');
--   SELECT admin_set_password(2,'1234');
--   SELECT * FROM login('testuser','1234');
-- ================================================================
