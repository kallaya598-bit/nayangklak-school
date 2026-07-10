-- ============================================================
-- ส่วน B: หักคะแนนอัตโนมัติจากการเช็คชื่อ + สถานะ "หนีเรียน"
-- วิธีใช้: คัดลอกทั้งหมด → Supabase → SQL Editor → Run (ครั้งเดียว)
-- ============================================================

-- 1) อนุญาตสถานะใหม่ 'skip' (หนีเรียน) ในตารางเช็คชื่อทั้ง 3
--    (รวมสถานะเดิมทั้งหมดไว้ด้วย เผื่อ constraint เก่าไม่ครบ)
ALTER TABLE morning_attendance   DROP CONSTRAINT IF EXISTS morning_attendance_status_check;
ALTER TABLE morning_attendance   ADD  CONSTRAINT morning_attendance_status_check
  CHECK (status IN ('present','late','absent','leave','gone_home','special_leave','skip'));

ALTER TABLE afternoon_attendance DROP CONSTRAINT IF EXISTS afternoon_attendance_status_check;
ALTER TABLE afternoon_attendance ADD  CONSTRAINT afternoon_attendance_status_check
  CHECK (status IN ('present','late','absent','leave','gone_home','special_leave','skip'));

ALTER TABLE subject_attendance   DROP CONSTRAINT IF EXISTS subject_attendance_status_check;
ALTER TABLE subject_attendance   ADD  CONSTRAINT subject_attendance_status_check
  CHECK (status IN ('present','late','absent','leave','gone_home','special_leave','skip'));

-- 2) ค่าเริ่มต้นการหักคะแนน (แก้ได้ภายหลังในหน้า Admin → ตั้งค่าหักคะแนน)
INSERT INTO system_settings (key, value, description) VALUES
  ('att_auto_deduct', '1', 'เปิด/ปิดหักคะแนนอัตโนมัติจากเช็คชื่อ (1=เปิด,0=ปิด)'),
  ('deduct_late',     '1', 'คะแนนหักเมื่อมาสาย'),
  ('deduct_absent',   '3', 'คะแนนหักเมื่อขาดเรียน'),
  ('deduct_skip',     '5', 'คะแนนหักเมื่อหนีเรียน')
ON CONFLICT (key) DO NOTHING;
