-- dress_code_module.sql
-- รันใน Supabase SQL Editor (1 ครั้ง)
-- เพิ่มหมวดหมู่การแต่งกาย/ทรงผมสำหรับระบบบันทึกครูปกครอง

-- 1. เพิ่มคอลัมน์ kind ใน behavior_categories (ถ้ายังไม่มี)
ALTER TABLE behavior_categories ADD COLUMN IF NOT EXISTS kind VARCHAR(20) DEFAULT 'behavior';

-- 2. อัปเดตรายการเดิมให้มี kind='behavior'
UPDATE behavior_categories SET kind='behavior' WHERE kind IS NULL OR kind='';

-- 3. ใส่รายการตรวจการแต่งกาย/ทรงผมมาตรฐาน
INSERT INTO behavior_categories (name, default_score, active, kind) VALUES
  ('ผมยาว/ผิดทรง',             -2, true, 'dress'),
  ('ทำสีผม',                    -3, true, 'dress'),
  ('เสื้อ/กางเกง/กระโปรงผิดระเบียบ', -2, true, 'dress'),
  ('ไม่ติดป้ายชื่อ',             -1, true, 'dress'),
  ('รองเท้า/ถุงเท้าผิดระเบียบ',  -1, true, 'dress'),
  ('ไม่คาดเข็มขัด/เข็มขัดผิด',   -1, true, 'dress'),
  ('เล็บยาว/ทาเล็บ',             -1, true, 'dress'),
  ('เครื่องประดับเกินกำหนด',      -1, true, 'dress');

-- หมายเหตุ: ถ้าต้องการเพิ่ม/แก้รายการภายหลัง ทำได้ใน Admin Panel
-- หรือรัน: INSERT INTO behavior_categories (name, default_score, active, kind) VALUES ('...', -1, true, 'dress');
