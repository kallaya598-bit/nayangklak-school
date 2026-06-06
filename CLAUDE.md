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
├── expand_schema.sql       ← SQL ขยาย database
├── fix_room_teachers.sql   ← SQL ผูกครูกับห้อง
├── nayangklak_all_in_one.sql ← SQL ตั้งต้นระบบ
└── teacher_accounts.xlsx   ← username/password ครูทุกคน
```

## สิ่งที่ทำสำเร็จแล้ว ✅
- Login / Logout ด้วย username + password
- เช็คชื่อเสาธงเช้า (บันทึก/แก้ไข/ดึงข้อมูล)
- เช็คชื่อตอนเย็น
- Dashboard แสดงสถิติ
- UI ธีมฟ้าขาว ใช้งานบน iPhone ได้
- Deploy บน GitHub Pages

## สิ่งที่ยังค้างอยู่ ⏳
- [ ] บันทึกความดี (UI ยังไม่ perfect)
- [ ] บันทึกพฤติกรรม (UI ยังไม่ perfect)
- [ ] คะแนนสุทธิ (ความดีหักลบพฤติกรรม)
- [ ] คะแนนรายวิชา
- [ ] ตารางสอน
- [ ] PDF รายงาน ภาษาไทย (ใช้ html2canvas)
- [ ] Admin Panel เต็มรูปแบบ
- [ ] ยังไม่มีข้อมูลรายวิชา (subjects table ว่าง)

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
