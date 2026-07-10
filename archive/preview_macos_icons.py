from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ICON_DIR = ROOT / "assets" / "menu-icons"
OUT = ROOT / "macos-icons-preview.png"
FILES = [
    ("01-student-info.png","ข้อมูลนักเรียน"),
    ("02-morning-flag.png","เสาธงเช้า"),
    ("03-evening-attendance.png","ตอนเย็น"),
    ("04-class-check.png","เช็คเวลาเรียน"),
    ("05-attendance-report.png","รายงานเช็คชื่อ"),
    ("06-absent-student.png","นักเรียนขาด"),
    ("07-good-deed.png","บันทึกความดี"),
    ("08-behavior-record.png","บันทึกพฤติกรรม"),
    ("09-net-score.png","คะแนนสุทธิ"),
    ("10-home-visit.png","เยี่ยมบ้าน"),
    ("11-home-map.png","แผนที่บ้าน"),
    ("12-mental-health.png","สุขภาพจิต"),
    ("13-club-activities.png","กิจกรรมชุมนุม"),
    ("14-teaching-schedule.png","ตารางสอน"),
    ("15-subject-grades.png","คะแนนรายวิชา"),
    ("16-subject-time.png","เวลาเรียนรายวิชา"),
    ("17-classroom-time.png","เวลาเรียนรายห้อง"),
    ("18-student-timetable.png","ตารางนักเรียน"),
    ("19-subject-absence.png","ขาดเรียนรายวิชา"),
    ("20-truancy.png","นักเรียนหนีเรียน"),
    ("21-pdf-report.png","ออกรายงาน PDF"),
]

def font(size, bold=False):
    for p in [
        "C:/Windows/Fonts/leelawdb.ttf" if bold else "C:/Windows/Fonts/leelawad.ttf",
        "C:/Windows/Fonts/tahomabd.ttf" if bold else "C:/Windows/Fonts/tahoma.ttf",
    ]:
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

def wrap(draw, text, f, max_w):
    lines, cur = [], ""
    for ch in text:
        test = cur + ch
        if draw.textbbox((0,0), test, font=f)[2] <= max_w or not cur:
            cur = test
        else:
            lines.append(cur)
            cur = ch
    if cur: lines.append(cur)
    if len(lines) > 2:
        lines = [lines[0], "".join(lines[1:])]
    return lines

def main():
    cols = 4
    cell_w, cell_h = 176, 142
    pad_x, pad_y = 32, 34
    rows = (len(FILES) + cols - 1) // cols
    W = pad_x*2 + cols*cell_w
    H = pad_y*2 + rows*cell_h + 58
    im = Image.new("RGB", (W,H), (240,246,253))
    d = ImageDraw.Draw(im)
    for x in range(0,W,28):
        d.line([(x,0),(x,H)], fill=(217,228,242), width=1)
    for y in range(0,H,28):
        d.line([(0,y),(W,y)], fill=(217,228,242), width=1)
    ftitle, flabel = font(28, True), font(15, True)
    d.text((pad_x, 20), "พรีวิวไอคอน macOS no-drama — ไฟล์จริง 21 เมนู", font=ftitle, fill=(18,49,95))
    for i, (file,label) in enumerate(FILES):
        col, row = i % cols, i // cols
        x = pad_x + col*cell_w + (cell_w-82)//2
        y = 78 + row*cell_h
        src = Image.open(ICON_DIR/file).convert("RGBA")
        scaled = src.resize((112,112), Image.Resampling.LANCZOS)
        icon = scaled.crop(((112-82)//2, (112-82)//2, (112-82)//2+82, (112-82)//2+82))
        im.paste(icon.convert("RGB"), (x,y))
        lines = wrap(d, label, flabel, cell_w-18)
        ty = y + 89
        for ln in lines:
            bbox = d.textbbox((0,0), ln, font=flabel)
            d.text((pad_x + col*cell_w + (cell_w-(bbox[2]-bbox[0]))/2, ty), ln, font=flabel, fill=(18,49,95))
            ty += 18
    im.save(OUT, quality=95)
    print(OUT)

if __name__ == "__main__":
    main()
