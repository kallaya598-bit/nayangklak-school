# แผนพอร์ตระบบไปโรงเรียนใหม่ (StudentCare 360°)

> เอกสารนี้เตรียมไว้ล่วงหน้า สำหรับตอนที่มีโรงเรียนอื่นต้องการใช้ระบบนี้
> อ้างอิงจากบทสนทนาวันที่ 2569-07-01 — เมื่อถึงเวลาจริง ให้ Claude อ่านไฟล์นี้ก่อนเริ่มงาน

## หลักการ
- **โค้ด/ฟีเจอร์ไม่ต้องแก้เลย** — index.html ใช้ร่วมกันได้ 100%
- สิ่งที่ต้องทำแบ่งเป็น 3 กลุ่ม: (1) Supabase project ใหม่ (2) credentials ในโค้ด (3) branding/ชื่อโรงเรียน

---

## ขั้นตอนที่ 1: Supabase — โครงสร้างฐานข้อมูล
1. สร้าง Supabase project ใหม่ → จะได้ URL + ANON KEY ใหม่
2. รัน `pg_dump --schema-only` จากโปรเจกต์เดิม (`ujajukwmxulayxxxxmpr`) → restore เข้าโปรเจกต์ใหม่
   - ได้ครบ: ตาราง, function/RPC (`login`, `calc_score_summary`, `admin_create_teacher`), trigger, RLS policy
   - **ไม่ได้ครบ** ต้องทำเพิ่ม:
     - Seed data: `good_deed_categories` (8 ประเภท), `behavior_categories` (8 ประเภท), ค่า default ใน `system_settings` (เช่น `line_school_group_id`) — ก็อบ INSERT จากไฟล์ setup SQL เดิม
     - เปิด extension `pgcrypto` (ใช้ใน `admin_rpc.sql` สำหรับ bcrypt) ผ่าน Supabase Dashboard
     - สร้าง Storage bucket ใหม่ + policy (ถ้าใช้รูปนักเรียน `photo_url`)
3. ทางเลือกสำรอง ถ้า pg_dump ยุ่งยาก: ไล่รัน SQL ทีละไฟล์ตามลำดับ (ดู "รายการไฟล์ SQL" ด้านล่าง)
4. **รัน `security_hardening.sql` เป็นไฟล์สุดท้ายเสมอ** (หลังตาราง `teachers` ถูกสร้างครบทุกคอลัมน์แล้ว
   รวม `permissions`/`is_academic`/`shortcuts`) — เปิด RLS ทุกตาราง + ล็อกคอลัมน์รหัสผ่านครู
   + ผูก RPC สำคัญกับ header ลับ **ต้องแก้ secret ในไฟล์นี้เป็นค่าใหม่ก่อนรัน** (ดูขั้นตอนที่ 3)
   ถ้าใช้ pg_dump แทนการไล่รันไฟล์ จะได้ RLS policy/RPC เดิมติดมาด้วย (รวม secret เดิม) —
   ต้องรัน `security_hardening.sql` ซ้ำอีกครั้งด้วย secret ใหม่หลัง dump เสมอ ไม่งั้นสอง
   โรงเรียนจะใช้ secret เดียวกัน

## ขั้นตอนที่ 2: นำเข้าข้อมูลจริงของโรงเรียนใหม่
- `classrooms` (ห้องเรียน), `teachers` (ครู), `students` (นักเรียน), `room_teachers` (ครูที่ปรึกษาผูกห้อง)
- สร้างบัญชี admin + ครู ผ่าน RPC `admin_create_teacher` (ใน `admin_rpc.sql`) — อย่า insert ตรงเพราะรหัสผ่านต้อง bcrypt
- ตั้งรหัสผ่านเริ่มต้นใหม่ (ไม่ใช้ `admin1234` เดิม)

## ขั้นตอนที่ 3: แก้ credentials ใน index.html
- ตัวแปร `SB` (Supabase URL) และ `KEY` (ANON KEY) → แทนที่ด้วยของโปรเจกต์ใหม่
- `VAPID_PUBLIC_KEY` (บรรทัด ~3045) → generate คู่ VAPID key ใหม่สำหรับ Web Push (คู่ private key ฝั่ง server ที่ส่ง push ก็ต้องเปลี่ยนตาม)
- `APP_KEY` (บรรทัด ~3051, ถัดจาก `VAPID_PUBLIC_KEY`) → generate secret ใหม่ด้วย `openssl rand -hex 24`
  แล้วแก้ค่าเดียวกันใน `security_hardening.sql` (ฟังก์ชัน `app_authorized()`) ก่อนรัน — **ห้ามใช้ secret
  ซ้ำกับโรงเรียนเดิม** (ดูขั้นตอนที่ 1.4)
- ค่า `line_school_group_id` ใน `system_settings` ของโรงเรียนใหม่ (ถ้าใช้ LINE Notify)

## ขั้นตอนที่ 4: Branding — ชื่อโรงเรียนฝัง hardcode ~23+ จุดใน index.html
Find & replace "โรงเรียนนายางกลักพิทยาคม" (และคำที่เกี่ยวข้อง) — จุดที่พบ:
- `<title>` และ splash screen
- หัวรายงาน PDF/พิมพ์ทุกแบบ: ปพ.5, ใบรายชื่อนักเรียน, รายงานเวลาเรียน (รายวิชา/รายห้อง), รายงานเยี่ยมบ้าน, ใบข้อสอบ (`exam_standalone`)
- ตัวแปร `school_name:'โรงเรียนนายางกลักพิทยาคม'` (ในโครงสร้างข้อสอบ)
- สังกัด (สพม.ชัยภูมิ), เบอร์โทรผู้ดูแลระบบ, ชื่อผู้พัฒนา (`login-dev`)
- พิกัด GPS โรงเรียน (บรรทัด ~12013 — ใช้กับฟีเจอร์เยี่ยมบ้าน/เช็คตำแหน่ง)
- ภาคเรียน/ปีการศึกษา ("1/2569") — อาจเปลี่ยนตามรอบที่พอร์ต

**แนะนำ:** ถ้าจะพอร์ตซ้ำหลายโรงเรียนในอนาคต ควรรีแฟกเตอร์ให้ชื่อโรงเรียนเป็นตัวแปรเดียว (เช่น `SCHOOL_NAME`, `SCHOOL_LOGO`, `SCHOOL_GPS`) ที่ประกาศต้นไฟล์ แล้วอ้างอิงทุกจุด — ทำครั้งเดียว ประหยัดเวลาพอร์ตครั้งต่อไปเหลือไม่กี่นาที

## ขั้นตอนที่ 5: ไฟล์ PWA/branding อื่น
- `manifest.webmanifest` — เปลี่ยน `name`, `description`
- `icon-192.png`, `icon-512.png`, favicon → โลโก้โรงเรียนใหม่
- `sw.js` — เช็ค cache name/version ถ้าผูกกับชื่อระบบ

## ขั้นตอนที่ 6: Deploy
- สร้าง GitHub repo ใหม่ (หรือ branch แยก) → ตั้งค่า GitHub Pages
- แก้ `deploy.sh`: URL ที่ print หลัง push, ชื่อไฟล์สำเนา `nayangklak_system.html` → เปลี่ยนตามชื่อระบบใหม่
- อัปเดต CLAUDE.md ของโปรเจกต์ใหม่ (URL, Supabase credentials, ชื่อโรงเรียน) — **อย่าลืม ไฟล์นี้คือ source of truth ที่ Claude จะอ่านทุกครั้ง**

## ขั้นตอนที่ 7: ทดสอบ end-to-end
- Login (admin + ครู), เช็คชื่อเช้า/เย็น, บันทึกความดี/พฤติกรรม, ตรวจเครื่องแต่งกาย
- ออกรายงาน PDF (ปพ.5, ใบรายชื่อ) — เช็คว่าชื่อโรงเรียน/โลโก้ขึ้นถูก
- Web Push notification (ทดสอบด้วย VAPID key ใหม่)
- ทดสอบบนมือถือ iPhone Safari จริง (ตามกฎ mobile-first)

---

## ประมาณเวลารวม: 1–1.5 วันทำงาน (8–13 ชม.)
รายละเอียดแบ่งตามขั้นตอน:
| ขั้นตอน | เวลา |
|---|---|
| Supabase project + schema restore | 2–4 ชม. |
| นำเข้าข้อมูลจริง (ครู/ห้อง/นักเรียน) | 2–3 ชม. |
| แก้ credentials | 30 นาที |
| Find & replace branding | 1–2 ชม. |
| โลโก้/ไอคอน PWA | 30–45 นาที |
| Deploy setup | 30 นาที |
| สร้าง user ครู/แอดมิน | 30 นาที |
| ทดสอบ end-to-end | 1–2 ชม. |

## รายการไฟล์ SQL ทั้งหมดในโปรเจกต์ (สำรอง ถ้าไม่ใช้ pg_dump)
nayangklak_schema.sql / nayangklak_all_in_one.sql / nayangklak_setup.sql, expand_schema.sql,
fix_room_teachers.sql, teaching_module.sql, admin_rpc.sql, admin_security_module.sql,
dress_code_module.sql / dress_code_pass.sql / dress_code_round.sql,
activities_module.sql, add_viewer_role.sql, assessment_module.sql, attendance_autoscore.sql,
clubs_admin.sql, dashboard_setup.sql, exam_grader_module.sql, exam_standalone.sql,
fix_rls_categories.sql, fix_rls_modules.sql, grade_visible.sql, home_visit_module.sql,
line_notify_setup.sql, web_push_setup.sql, student_photo.sql, student_profile_schema.sql,
students_only.sql, teacher_change_password.sql,
**security_hardening.sql (รันสุดท้ายเสมอ — ดูขั้นตอนที่ 1.4)**

## ก่อนเริ่มงานจริง — สิ่งที่ควรถามผู้ใช้ก่อน
- ชื่อโรงเรียนใหม่ + สังกัด + เบอร์ติดต่อ + พิกัด GPS
- มีไฟล์ข้อมูลนักเรียน/ครู (Excel) พร้อมหรือยัง รูปแบบตรงกับ column ในตาราง `students`/`teachers` หรือไม่
- จะรีแฟกเตอร์เป็นตัวแปร `SCHOOL_NAME` ก่อนพอร์ต หรือ find&replace ตรงๆ ทุกครั้งที่พอร์ต
- ใช้ Storage bucket เก็บรูปนักเรียนหรือไม่ (มีผลต่อขั้นตอน Supabase)
