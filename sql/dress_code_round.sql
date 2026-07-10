-- dress_code_round.sql
-- รันใน Supabase SQL Editor (1 ครั้ง) หลังจากรัน dress_code_module.sql + dress_code_pass.sql แล้ว
-- เพิ่มคอลัมน์ "ครั้งที่ตรวจ" (round_no) สำหรับกำหนดว่าเป็นการตรวจครั้งที่เท่าไหร่ของเทอม

ALTER TABLE behavior_records ADD COLUMN IF NOT EXISTS round_no SMALLINT;

-- หมายเหตุ:
--  - round_no จะถูกใส่ค่าเฉพาะรายการตรวจการแต่งกาย (kind='dress' / 'dress_pass')
--  - รายการพฤติกรรม/ความดีอื่น ๆ ปล่อยเป็น NULL ได้ (ไม่กระทบข้อมูลเดิม)
--  - ใช้จับกลุ่มการตรวจแต่ละครั้ง เพื่อแสดงในการ์ดของนักเรียน
