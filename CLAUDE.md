# ระบบดูแลช่วยเหลือนักเรียน — โรงเรียนนายางกลักพิทยาคม

## ข้อมูลโปรเจกต์
- **ชื่อโรงเรียน:** โรงเรียนนายางกลักพิทยาคม
- **สังกัด:** สำนักงานเขตพื้นที่การศึกษามัธยมศึกษาชัยภูมิ (สพม.ชัยภูมิ)
- **ภาคเรียน:** 1/2569
- **เจ้าของระบบ:** นายอดิศักดิ์ วนาใส (ครูที่ปรึกษา ม.5/1)

## URL ที่ใช้งานจริง
- **เว็บไซต์:** https://kallaya598-bit.github.io/nayangklak-school
- **GitHub Repo:** https://github.com/kallaya598-bit/nayangklak-school
- **Supabase Project:** https://ujajukwmxulayxxxxmpr.supabase.co

## Supabase Credentials
```
URL: https://ujajukwmxulayxxxxmpr.supabase.co
ANON KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqYWp1a3dteHVsYXl4eHh4bXByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAxNDc4MDAsImV4cCI6MjA5NTcyMzgwMH0.DbiP5Qelewl0ozjTNn8GpAkjq256bCGusO4irblMVOo
```

## Stack / เทคโนโลยีที่ใช้
- **Frontend:** HTML + CSS + Vanilla JavaScript (ไฟล์เดียว ไม่ใช้ Framework)
- **Database:** Supabase (PostgreSQL)
- **Auth:** Custom login ผ่าน RPC function `login(p_username, p_password)`
- **Hosting:** GitHub Pages
- **PDF:** html2canvas + jsPDF (render HTML เป็น PDF เพื่อรองรับภาษาไทย)
- **Font:** Sarabun (Google Fonts)
- **Theme:** ฟ้าขาว (--blue: #1565c0, --blue2: #1976d2)

## โครงสร้างฐานข้อมูล (Supabase Tables)

### ตารางหลัก (มีข้อมูลแล้ว)
| ตาราง | รายละเอียด | จำนวนข้อมูล |
|-------|-----------|-------------|
| `teachers` | ครู + username/password | 47 คน |
| `classrooms` | ห้องเรียน | 24 ห้อง (ม.1-ม.6) |
| `students` | นักเรียน | 796 คน |
| `room_teachers` | ครูที่ปรึกษาแต่ละห้อง | ครบทุกห้อง |
| `good_deed_categories` | ประเภทความดี | 8 ประเภท |
| `behavior_categories` | ประเภทพฤติกรรม | 8 ประเภท |

### ตารางบันทึกข้อมูล (ว่างอยู่ รอใช้งาน)
| ตาราง | รายละเอียด |
|-------|-----------|
| `morning_attendance` | เช็คชื่อเสาธงเช้า |
| `afternoon_attendance` | เช็คชื่อตอนเย็น |
| `good_deeds` | บันทึกความดี |
| `behavior_records` | บันทึกพฤติกรรม |
| `score_summary` | คะแนนสุทธิ (คำนวณอัตโนมัติ) |
| `subjects` | รายวิชา (ต้องเพิ่มข้อมูล) |
| `timetable` | ตารางสอน |
| `grade_structures` | โครงสร้างคะแนน |
| `grades` | คะแนนรายวิชา |
| `subject_attendance` | เช็คชื่อรายวิชา |
| `audit_log` | ประวัติแก้ไข |
| `system_settings` | ตั้งค่าระบบ |

## Login Credentials
| Username | Password | Role | ห้อง |
|----------|----------|------|------|
| `admin` | `admin1234` | admin | - |
| `adisak` | `1234` | teacher | ม.5/1 |
| ครูทุกคน | `1234` | teacher | ตามห้อง |

## Supabase API Pattern (ใช้ fetch โดยตรง ไม่ใช้ library)
```javascript
// Headers
var H = {
  'apikey': KEY,
  'Authorization': 'Bearer ' + KEY,
  'Content-Type': 'application/json'
};

// SELECT
fetch(SB + '/rest/v1/students?classroom_id=eq.5&status=eq.active&select=id,fullname', {headers: H})

// INSERT / UPSERT
fetch(SB + '/rest/v1/morning_attendance', {
  method: 'POST',
  headers: {...H, 'Prefer': 'resolution=merge-duplicates'},
  body: JSON.stringify(records)
})

// RPC
fetch(SB + '/rest/v1/rpc/login', {
  method: 'POST',
  headers: H,
  body: JSON.stringify({p_username: 'adisak', p_password: '1234'})
})

// COUNT
fetch(SB + '/rest/v1/students?select=id&classroom_id=eq.5', {
  headers: {...H, 'Prefer': 'count=exact'}
})
// → ดึงจาก response header: content-range → "0-25/26"
```

## โครงสร้างไฟล์
```
ระบบดูแลนักเรียน/
├── index.html              ← ระบบหลัก (deploy บน GitHub Pages)
├── nayangklak_system.html  ← ระบบหลัก (สำเนาสำหรับแก้ไข)
├── CLAUDE.md               ← ไฟล์นี้
├── sql/                     ← ไฟล์ SQL ทั้งหมด (รันบน Supabase SQL Editor)
│   ├── expand_schema.sql       ← SQL ขยาย database
│   ├── fix_room_teachers.sql   ← SQL ผูกครูกับห้อง
│   └── nayangklak_all_in_one.sql ← SQL ตั้งต้นระบบ
├── archive/                 ← ไฟล์ mockup/backup เก่า (ไม่กระทบเว็บจริง)
└── teacher_accounts.xlsx   ← username/password ครูทุกคน
```

## สิ่งที่ทำสำเร็จแล้ว ✅
- Login / Logout ด้วย username + password
- เช็คชื่อเสาธงเช้า (บันทึก/แก้ไข/ดึงข้อมูล)
- เช็คชื่อตอนเย็น
- Dashboard แสดงสถิติ
- UI ธีมฟ้าขาว ใช้งานบน iPhone ได้
- Deploy บน GitHub Pages
- **โมดูลระบบจัดการการสอนครู (เพิ่มใหม่):**
  - เลือก/ค้นหารายวิชาที่สอน (รหัส/ชื่อ/ระดับชั้น/กลุ่มสาระ) + เพิ่มรายวิชาใหม่
  - จัดการรายวิชาที่สอน: สร้างกลุ่มเรียน, เพิ่ม/ลบนักเรียน (enrollments), เชิญครูร่วม, ลบกลุ่ม
  - ตารางสอนแก้ไขได้ (คลิกช่อง→กำหนดคาบ, สีตามวิชา, คลิก→เช็คชื่อ)
  - เช็คชื่อรายวิชา ผูก enrollments + คาบ + วันที่ (มา/ขาด/สาย/ลา + เช็คทั้งหมด)
  - คะแนนรายวิชา: ตั้งโครงสร้างคะแนนเอง, เกรด 0–4 อัตโนมัติ, สรุป GPA/การกระจายเกรด
  - รายงาน ปพ.5 (PDF ภาษาไทย ผ่าน html2canvas, แนวนอน) + Export Excel (CSV UTF-8 BOM)
  - **รายงานเวลาเรียนรายวิชา** (pgSubjAttReport): ตารางรายครั้งทั้งภาคเรียน (ลบรายคาบได้) + สรุป % รายคน · พิมพ์ (window ใหม่ ฟอนต์จริง) + Excel
  - **รายงานเวลาเรียนรายห้อง** (pgRoomAttReport): เลือกห้อง+วัน → ตอนเข้า/ทุกคาบ/ตอนเย็น ของทั้งห้อง (ข้อมูลจาก subject_attendance + morning/afternoon) · พิมพ์ + Excel
  - **โมดูล "ตารางสอน" รวม:** รายวิชาที่สอน/จัดการรายวิชา/จัดการตารางสอน เป็นแท็บย่อย (.schedTabs) ในเมนูเดียว
  - **เช็คเวลาเรียน (เดิมเช็คชื่อรายวิชา):** เปิดมาเป็นตารางสอน สีตามสถานะสัปดาห์นี้ (เขียว=เช็คแล้ว/แดง=ลืม/เหลือง=ยังเช็คได้/เทา=ยังไม่ถึงวัน คลิกไม่ได้) · ล็อกหลังเช็ค (เขียว=เพิ่งบันทึก, แดง STOP=เคยเช็ค)
  - **เช็คชื่อรายวิชาอัจฉริยะ:** คาบให้เลือกเฉพาะคาบที่สอนวันนั้น (ตามตารางสอน) + ติ๊ก "เช็คนอกตาราง" สำหรับสอนชดเชย · วันหยุด/ไม่มีคาบจะเตือน
  - **tab "ยังไม่เช็ค" (buildSarMissing):** แจกแจงคาบที่ต้องสอนทั้งภาคจากตารางสอน → แสดงวันไหนเช็คแล้ว/ยังไม่เช็ค (แถวแดง) → กดเช็คย้อนหลัง/แก้ไข (ทั้งห้องด้วย checkbox หัวคอลัมน์ หรือรายคน)

## ⚠️ ต้องทำก่อนใช้โมดูลการสอน
รัน `sql/teaching_module.sql` ใน Supabase SQL Editor ก่อน (สร้างตาราง teaching_assignments,
enrollments, assignment_teachers + ALTER timetable/subject_attendance/grade_structures
+ INSERT วิชาตัวอย่าง) — ตอนนี้ตารางยังไม่ถูกสร้าง (API จะ 404 จนกว่าจะรัน SQL)

## ตารางใหม่ (จาก sql/teaching_module.sql)
| ตาราง | รายละเอียด |
|-------|-----------|
| `teaching_assignments` | กลุ่มเรียนรายวิชา (วิชา+ห้อง+ครู+กลุ่มที่) |
| `enrollments` | นักเรียนที่ลงทะเบียนแต่ละกลุ่มเรียน |
| `assignment_teachers` | ครูร่วมสอน/คำเชิญ |
| (ALTER) | timetable.assignment_id, subject_attendance.assignment_id+period, grade_structures.assignment_id |

## Admin Panel (เพิ่มใหม่)
- จัดการนักเรียน: เลือกห้อง → เพิ่ม/แก้ไข/ลบ (ลบไม่ได้ถ้ามีประวัติ → เปลี่ยนเป็นพ้นสภาพ)
- จัดการครู: เพิ่มครู, แก้ username/ชื่อ/บทบาท/เปิด-ปิด, **รีเซ็ตรหัสผ่าน**, เลือกครูที่ปรึกษาหลายห้อง
- ดูรายงานทุกห้อง: ปุ่ม "ดูห้องนี้" (adminViewRoom) → set G.room → เข้าถึงเช็คชื่อ/ความดี/คะแนน/รายงานของห้องนั้น
- **โอนรายวิชา/เปลี่ยนครูผู้สอน** (admAssignments): ครูย้าย→โอนเจ้าของกลุ่ม เช็คชื่อ/คะแนน/รายชื่อเดิมตามไปครบ (ผูก assignment_id)
- **สอนร่วม (co-teacher):** loadMyAssigns รวมกลุ่มจาก assignment_teachers → ครูที่ถูกเชิญเห็นกลุ่ม (badge "ร่วมสอน")
- **ต้องรัน `sql/admin_rpc.sql` ก่อน** (RPC admin_create_teacher / admin_set_password — รหัสผ่าน bcrypt)

## การตรวจเครื่องแต่งกาย + การ์ดแจ้งนักเรียน (เพิ่มใหม่)
- **ครั้งที่ตรวจ (round_no):** หน้าบันทึกการแต่งกาย (แท็บ "บันทึก") มีช่อง "ครั้งที่ตรวจ" กำหนดได้ว่าเป็นการตรวจครั้งที่เท่าไหร่ของเทอม → เก็บลง `behavior_records.round_no` (แท็บ "แก้ไข" แสดงครั้งที่ในหัวตาราง)
- **การ์ดผลตรวจในพอร์ทัลนักเรียน/ผู้ปกครอง (stuDressCard):** แสดงในแท็บ "ภาพรวม" — แบนเนอร์ผลตรวจครั้งล่าสุด (✅ ผ่าน / ❌ ไม่ผ่าน + รายการที่ผิด) พร้อมประวัติการตรวจครั้งก่อน จัดกลุ่มตาม ครั้งที่+วันที่
- **⚠️ ต้องรัน `sql/dress_code_round.sql` ก่อน** (ALTER behavior_records ADD round_no) — ถ้ายังไม่รัน การบันทึก round_no จะ error

## ส่งคะแนนเข้า SGS (SGS Helper — เพิ่มใหม่)
- **ปุ่ม "🚀 SGS"** ในหน้าคะแนนรายวิชา (pgGrades) → modal `modalSGS`: พรีวิวคะแนน + ปุ่ม "คัดลอกข้อมูล SGS" (JSON `SGSPKG1:{...}` ลง clipboard) + วิธีติดตั้ง bookmarklet ในตัว (ฟังก์ชัน `sgsOpenExport/sgsBuildPackage/sgsCopyData`)
- **`sgs-helper.js`** (root repo, โฮสต์บน GitHub Pages) — โหลดผ่าน bookmarklet บนหน้า SGS: วางข้อมูล → สแกนตาราง (จับคู่ด้วย **student_code เท่านั้น** รองรับเลขศูนย์นำหน้า, อ่านหัวตารางแบบกาง colspan/rowspan, รองรับ iframe same-origin) → mapping UI จับคู่ช่องเรา↔SGS (จำใน localStorage, มีช่องเสมือน "รวมรายช่วง/รวมทั้งหมด" ◆ และโหมด **"🧩 กำหนดเอง (รวมหลายช่อง)"** ให้ติ๊กเลือกหลายช่องย่อยจากระบบเรามารวมเป็น 1 ช่อง SGS เอง — ถ้าช่วงประกอบขาดแม้ช่องเดียวจะไม่รวม/ข้าม ป้องกันรวมผิด) → พรีวิว diff → **เติมเฉพาะช่องว่าง ไม่ทับค่า ไม่กดปุ่มบันทึกของ SGS เอง**
  - **ยืนยันจากหน้า SGS จริง (Edit-TblTranscripts1-Table.aspx):** ช่องคะแนนทุกคอลัมน์ (S1-S9/กลางภาค/Remark) เป็น `disabled` ไว้ก่อน ต้องติ๊ก checkbox หัวคอลัมน์ก่อนถึงพิมพ์ได้ — สคริปต์กด checkbox ให้อัตโนมัติก่อนเติม (`ensureColumnEnabled`) · ช่อง "ก่อนกลางภาค" คำนวณอัตโนมัติไม่มี onchange ห้ามเติม (ตรวจด้วย `isFillable`) · **หน้านี้ auto-save ทันทีที่ onchange (ไม่มีปุ่ม Save แยก)** จึงมี `confirm()` ยืนยันก่อนเติมทุกครั้ง
- **โหมด "🧪 วิเคราะห์หน้า"** ใน panel: คัดลอกโครงหน้า SGS (headers/inputs/sample row) ส่งให้ผู้พัฒนาปรับจูน — ใช้ตอนเจอหน้า SGS จริงครั้งแรก
- **หน้าทดสอบ:** `tmp/sgs-mock.html` (SGS จำลอง WebForms + ข้อมูลตัวอย่าง) — ทดสอบผ่านแล้วทุกเคส (เติม/ขัดแย้ง/ตรงแล้ว/หาไม่เจอ)
- ✅ bookmarklet ชี้ `https://kallaya598-bit.github.io/nayangklak-school/sgs-helper.js` — deploy แล้ว (2026-07-14) และ **ทดสอบกับ SGS จริงผ่านแล้ว ใช้งานได้ดี**

## ระบบสอบออนไลน์ (oe_ = online exam — เพิ่มใหม่ 2026-07-20)
- **เมนู "สอบออนไลน์"** (pgOnlineExam, อยู่ในกลุ่ม "การสอน" ต่อจาก "ตรวจข้อสอบ") — ฝั่งครู: สร้าง/แก้ไขชุดข้อสอบ (เลือกห้องเรียนที่สอบได้, เวลาสอบ, ช่วงเปิด-ปิดสอบ, จำนวนครั้งที่สอบได้, สุ่มข้อ/สุ่มตัวเลือก, สุ่มจำนวนข้อจากคลัง, รหัสเข้าสอบเสริม, เปิด/ปิดแสดงคะแนน, โหมดแสดงเฉลย never/after_close/immediate) → ใส่คำถามทีละข้อในฟอร์ม (ปรนัย 4 ตัวเลือก หรือ ถูก/ผิด, ข้อความล้วน ยังไม่รองรับรูปภาพ) หรือ**วางคำถามจาก Word/เอกสารทีเดียวหลายข้อ** (แยกอัตโนมัติจากเลขข้อ+ตัวเลือก ก./ข./ค./ง. และจับคำตอบที่ถูกจากตัวหนา/สีแดงที่ paste มา ผ่าน contenteditable+getComputedStyle — เฉพาะปรนัย 4 ตัวเลือก, มีหน้าพรีวิวให้ครูตรวจ/แก้ก่อนนำเข้าเสมอ ไม่บันทึกอัตโนมัติ) → ดูผลสอบ/ปรับคะแนนรายคน/Export Excel
- **นักเรียนเข้าสอบผ่านลิงก์ ไม่ต้องล็อกอิน:** `index.html?exam=รหัส6หลัก` (ปุ่ม "คัดลอกลิงก์" ในแท็บตั้งค่า) → กรอกชื่อ-สกุล+ชั้น/ห้อง+เลขประจำตัว ยืนยันตรงกับตาราง `students` ก่อนเข้าสอบได้ → ทำข้อสอบ (autosave ทุกข้อ, จับเวลาถอยหลัง, สลับข้อได้อิสระ, ทำเครื่องหมาย 🚩 ทบทวน, ส่งอัตโนมัติเมื่อหมดเวลา)
  - หน้าทำข้อสอบเป็นคอนเทนเนอร์แยก `#oeTakePage` (เต็มจอ ไม่ใช้ระบบ `.page` เดิม) — bootstrap เช็ค `?exam=` **ก่อน** logic resume session ปกติเสมอ (ดู `oeTakeCheckBoot()` ท้ายไฟล์) จึงไม่กระทบผู้ใช้ครู/แอดมินที่ล็อกอินอยู่
  - **กันทุจริตระดับกลาง:** ขอ fullscreen ตอนเริ่มสอบ (เบราว์เซอร์ที่ไม่รองรับ เช่น iOS Safari จะข้ามเงียบๆ ไม่บล็อกการสอบ) + นับครั้งสลับแท็บ/ออกจาก fullscreen (`oe_log_event` RPC) → ครบ 3 ครั้งส่งข้อสอบอัตโนมัติ + บันทึกลง `oe_events`
- **⚠️ ต้องรัน `sql/online_exam_module.sql` ก่อนใช้งาน** (สร้างตาราง oe_exams/oe_questions/oe_options/oe_attempts/oe_answers/oe_events + RLS + RPC 5 ตัว) — ถ้ายังไม่รัน หน้าทั้งสองฝั่งจะขึ้นข้อความแจ้งเตือนสีแดง ไม่ crash
- **สถาปัตยกรรมเฉลย (สำคัญ ต้องเข้าใจก่อนแก้โค้ดส่วนนี้):** ระบบไม่มี Supabase Auth แยกสิทธิ์จริง (อ่านหมายเหตุใน `sql/security_hardening.sql`) จึงป้องกันเฉลยรั่วได้แค่ "ช่องทางใช้งานปกติ" เท่านั้น — หน้าทำข้อสอบนักเรียนต้องเรียกผ่าน RPC เท่านั้น (`oe_start_attempt`/`oe_save_answer`/`oe_log_event`/`oe_submit_attempt`/`oe_get_review`) **ห้ามอ่านตาราง `oe_options`/`oe_questions` ตรงๆ จากฝั่งนักเรียนเด็ดขาด** เพราะ RPC (SECURITY DEFINER) เป็นจุดเดียวที่ตัดคอลัมน์ `is_correct` ออกก่อนส่งกลับ — ไม่ใช่การป้องกันแบบสมบูรณ์ (นักเรียนที่เปิด DevTools ยิง REST ตรงยังอ่านได้เหมือนตารางอื่นทุกตารางในระบบนี้)
- **จำกัดของรอบแรก (ทำต่อได้ในอนาคต):** ยังไม่รองรับรูปภาพในคำถาม/ตัวเลือก, ยังไม่มีคลังคำถามกลาง/นำเข้า Excel, ไม่มีประวัติการแก้ไขคำถามหลังนักเรียนตอบไปแล้ว (แก้ได้อิสระ ควรระวังเองถ้ามีคนสอบไปแล้ว), หน้ารายงานเหตุการณ์ทุจริตมีแค่ตัวเลขสะสม (warn_count) ยังไม่มีตาราง log แยกให้ครูดูรายละเอียด

## สิ่งที่ยังค้างอยู่ ⏳
- [ ] รัน sql/dress_code_round.sql บน Supabase (เพิ่มคอลัมน์ round_no)
- [ ] รัน sql/teaching_module.sql + sql/admin_rpc.sql บน Supabase + ทดสอบ end-to-end
- [ ] รัน sql/online_exam_module.sql บน Supabase + ทดสอบ end-to-end (ระบบสอบออนไลน์)
- [ ] Admin Panel เต็มรูปแบบ
- [ ] รายงานเช็คชื่อรายวิชา รายเดือน/% (ตอนนี้มีเฉพาะเสาธง/เย็น)

## กฎการแก้ไขโค้ด (สำคัญมาก)
1. **ห้ามเขียนระบบใหม่ทั้งหมด** — ต่อยอดจากโค้ดเดิมเสมอ
2. **ไม่ใช้ Supabase JS library** — ใช้ fetch ตรงเท่านั้น (Safari iOS ไม่รองรับ)
3. **PDF ต้องใช้ html2canvas** — ไม่ใช้ jsPDF text API (ภาษาไทยพัง)
4. **Single HTML file** — CSS + JS อยู่ในไฟล์เดียวเสมอ
5. **Font: Sarabun** — ทุก element ใช้ Sarabun เสมอ
6. **Theme สี:** blue #1565c0, blue2 #1976d2, bluel #e3f2fd, green #2e7d32, red #c62828
7. **Mobile first** — ต้องใช้งานบน iPhone Safari ได้เสมอ
8. **RLS disabled** — Supabase ปิด Row Level Security ทุกตาราง

## ตัวอย่างโครงสร้าง Global State
```javascript
var G = {
  user: null,      // {id, username, fullname, role}
  room: null,      // {id, room_name}
  students: [],    // [{id, student_code, fullname, order_no}]
  att: {},         // {student_id: {status, remark}}
  settings: {
    absScore: -3,
    lateScore: -1,
    leaveScore: 0,
    baseScore: 100,
    teacherName: '',
    roomName: ''
  }
};
```

## วิธี deploy ขึ้น GitHub Pages
1. แก้ไขไฟล์เสร็จแล้ว
2. เปิด github.com → repo nayangklak-school → index.html → Edit
3. วางโค้ดใหม่ → Commit changes
4. รอ 2 นาที → เปิด URL ได้เลย

## คำสั่ง SQL ที่ใช้บ่อย (Supabase SQL Editor)
```sql
-- ดูนักเรียนห้อง ม.5/1
SELECT s.fullname, s.order_no FROM students s
JOIN classrooms c ON s.classroom_id = c.id
WHERE c.room_name = 'ม.5/1' ORDER BY s.order_no;

-- ดูการเช็คชื่อวันนี้
SELECT s.fullname, ma.status FROM morning_attendance ma
JOIN students s ON s.id = ma.student_id
WHERE ma.att_date = CURRENT_DATE;

-- คำนวณคะแนนสุทธิ
SELECT calc_score_summary(student_id) FROM students WHERE classroom_id = 17;
```
