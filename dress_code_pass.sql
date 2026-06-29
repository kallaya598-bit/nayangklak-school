-- dress_code_pass.sql
-- รันใน Supabase SQL Editor (1 ครั้ง) หลังจากรัน dress_code_module.sql แล้ว
-- เพิ่มหมวด "ผ่านการตรวจ" สำหรับบันทึกนักเรียนที่แต่งกายถูกระเบียบ (score=0)

INSERT INTO behavior_categories (name, default_score, active, kind)
VALUES ('ผ่านการตรวจ', 0, true, 'dress_pass');
