-- ================================================================
-- RPC สำหรับให้ครูเปลี่ยนรหัสผ่านตัวเอง
-- รหัสผ่านเข้ารหัส bcrypt ผ่าน pgcrypto
-- รันใน Supabase SQL Editor
-- ================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ครูเปลี่ยนรหัสผ่านของตัวเอง (ส่ง teacher_id มาจาก session ฝั่ง client)
CREATE OR REPLACE FUNCTION teacher_change_password(
  p_teacher_id INT,
  p_new_password TEXT
) RETURNS VOID AS $$
  UPDATE teachers
  SET password = crypt(p_new_password, gen_salt('bf'))
  WHERE id = p_teacher_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- ================================================================
-- ตรวจผล:
--   SELECT teacher_change_password(2, 'newpass123');
--   SELECT * FROM login('adisak', 'newpass123');
-- ================================================================
