-- แก้ปัญหาด่วน: ปิด Row Level Security (RLS) ทุกตารางใน schema public
-- สาเหตุ: ระบบนี้ไม่ได้ใช้ Supabase Auth (ไม่มี session/JWT แยกรายคน) —
-- ทุก request จากเว็บใช้ anon key ตัวเดียวกันหมด (ครู/แอดมิน/นักเรียนใช้ key เดียวกัน)
-- ดังนั้น RLS แบบจำกัดสิทธิ์ตามผู้ใช้จริงๆ ทำไม่ได้ในสถาปัตยกรรมปัจจุบัน
-- ถ้า RLS เปิดอยู่ (มี policy หรือไม่มีก็ตาม) anon key จะถูกบล็อกอ่าน/เขียนข้อมูลทันที
-- → เว็บทั้งระบบใช้งานไม่ได้ (ครูเข้าไม่ได้ ดึงข้อมูลนักเรียนไม่ได้ ฯลฯ)
--
-- วิธีใช้: รันทั้งไฟล์นี้ใน Supabase SQL Editor ครั้งเดียว จะปิด RLS ทุกตารางใน public schema
-- (ใช้ pg_tables วนลูปอัตโนมัติ กันกรณีมีตารางใหม่ที่ยังไม่รู้จัก ไม่ต้องพิมพ์ชื่อตารางเอง)

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY;', r.tablename);
  END LOOP;
END $$;

-- ตรวจสอบผลหลังรัน: ตารางไหนยังเปิด RLS อยู่ (ควรว่างเปล่าถ้าปิดครบแล้ว)
SELECT tablename FROM pg_tables
WHERE schemaname = 'public' AND rowsecurity = true;
