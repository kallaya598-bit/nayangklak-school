-- =======================================================
-- LINE Notification Setup — ระบบดูแลนักเรียน
-- รัน SQL นี้ใน Supabase SQL Editor ก่อนใช้งาน LINE
-- =======================================================

-- เพิ่ม key line_school_group_id ใน system_settings
-- (เก็บ Group ID ของกลุ่ม LINE ทั้งโรงเรียน)
INSERT INTO system_settings (key, value) VALUES ('line_school_group_id', '')
  ON CONFLICT (key) DO NOTHING;

-- ตรวจสอบ
-- SELECT key, value FROM system_settings WHERE key = 'line_school_group_id';
