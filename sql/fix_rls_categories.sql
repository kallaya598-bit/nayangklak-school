-- ============================================================
-- แก้ปัญหา: new row violates row-level security policy
--   (เจอกับ good_deed_categories, score_summary และอาจมีตารางอื่นอีก)
-- สาเหตุ: บางตารางยังเปิด RLS อยู่ แต่ระบบนี้ใช้ anon key + ตั้งใจปิด RLS ทุกตาราง
-- วิธีใช้: คัดลอกทั้งหมด → Supabase → SQL Editor → Run
-- ============================================================

-- ปิด RLS ให้ "ทุกตาราง" ใน schema public ในครั้งเดียว (กันปัญหาโผล่ทีละตาราง)
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY;', r.tablename);
  END LOOP;
END $$;

-- (เผื่อตรวจ) ตารางไหนยังเปิด RLS อยู่บ้าง — ควรได้ "0 rows"
SELECT tablename
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public' AND c.relrowsecurity = true;
