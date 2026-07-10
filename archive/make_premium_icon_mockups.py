from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
from pathlib import Path
import math

ROOT = Path(__file__).resolve().parent
ICON_DIR = ROOT / "assets" / "menu-icons"
OUT = ROOT / "premium-icon-button-mockups.png"

W, H = 1500, 1150
BG = (238, 246, 255)

items = [
    ("01-student-info.png", "ข้อมูลนักเรียน"),
    ("06-absent-student.png", "นักเรียนขาด"),
    ("10-home-visit.png", "เยี่ยมบ้าน"),
    ("07-good-deed.png", "บันทึกความดี"),
    ("08-behavior-record.png", "พฤติกรรม"),
    ("09-net-score.png", "คะแนนสุทธิ"),
    ("11-home-map.png", "แผนที่บ้าน"),
    ("12-mental-health.png", "สุขภาพจิต"),
    ("14-teaching-schedule.png", "ตารางสอน"),
    ("15-subject-grades.png", "คะแนนรายวิชา"),
    ("19-subject-absence.png", "ขาดรายวิชา"),
    ("21-pdf-report.png", "รายงาน PDF"),
]

def font(size, bold=False):
    candidates = [
        "C:/Windows/Fonts/leelawdb.ttf" if bold else "C:/Windows/Fonts/leelawad.ttf",
        "C:/Windows/Fonts/tahomabd.ttf" if bold else "C:/Windows/Fonts/tahoma.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
    ]
    for p in candidates:
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

F_TITLE = font(36, True)
F_SUB = font(18, False)
F_H = font(24, True)
F_TAG = font(13, True)
F_LABEL = font(15, True)

def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size[0]-1, size[1]-1], radius=radius, fill=255)
    return m

def paste_shadow(base, xy, size, radius, color, blur=18, dy=10, alpha=90):
    layer = Image.new("RGBA", base.size, (0,0,0,0))
    d = ImageDraw.Draw(layer)
    x,y = xy
    d.rounded_rectangle([x, y+dy, x+size[0], y+size[1]+dy], radius=radius, fill=(*color, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(layer)

def gradient_rect(size, c1, c2, c3=None, diagonal=True):
    w,h = size
    im = Image.new("RGBA", size)
    px = im.load()
    for y in range(h):
        for x in range(w):
            t = (x+y)/(w+h) if diagonal else y/h
            if c3 and t > .55:
                tt = (t-.55)/.45
                a,b = c2,c3
            elif c3:
                tt = t/.55
                a,b = c1,c2
            else:
                tt = t
                a,b = c1,c2
            px[x,y] = tuple(int(a[i]*(1-tt)+b[i]*tt) for i in range(4))
    return im

def add_gloss(im, radius):
    w,h = im.size
    gloss = Image.new("RGBA", im.size, (0,0,0,0))
    gd = ImageDraw.Draw(gloss)
    gd.ellipse([-w*.25, -h*.42, w*.82, h*.55], fill=(255,255,255,110))
    gd.polygon([(0,0),(w*.58,0),(w*.28,h),(0,h)], fill=(255,255,255,45))
    gloss.putalpha(Image.eval(gloss.getchannel("A"), lambda a: int(a*.75)))
    im.alpha_composite(gloss)
    return im

def crop_icon(path, size, radius, scale=1.0, sat=1.05):
    icon = Image.open(path).convert("RGBA")
    icon = ImageEnhance.Color(icon).enhance(sat)
    icon = ImageEnhance.Contrast(icon).enhance(1.04)
    n = int(size*scale)
    icon.thumbnail((n,n), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size,size), (0,0,0,0))
    canvas.alpha_composite(icon, ((size-icon.width)//2, (size-icon.height)//2))
    canvas.putalpha(Image.composite(canvas.getchannel("A"), Image.new("L",(size,size),0), rounded_mask((size,size), radius)))
    return canvas

def draw_wrapped_center(draw, xy, text, fnt, fill, max_width, line_gap=2):
    words = list(text)
    lines, cur = [], ""
    for ch in words:
        test = cur + ch
        if draw.textbbox((0,0), test, font=fnt)[2] <= max_width or not cur:
            cur = test
        else:
            lines.append(cur)
            cur = ch
    if cur:
        lines.append(cur)
    if len(lines) > 2:
        lines = [lines[0], "".join(lines[1:])]
    x,y = xy
    total_h = sum(draw.textbbox((0,0), ln, font=fnt)[3] for ln in lines) + (len(lines)-1)*line_gap
    yy = y
    for ln in lines:
        box = draw.textbbox((0,0), ln, font=fnt)
        draw.text((x+(max_width-(box[2]-box[0]))/2, yy), ln, font=fnt, fill=fill)
        yy += (box[3]-box[1]) + line_gap

def draw_button(base, x, y, style, icon_path):
    size = 88
    radius = 25
    if style == 1:
        paste_shadow(base, (x,y), (size,size), radius, (19,64,120), blur=14, dy=12, alpha=80)
        tile = gradient_rect((size,size), (255,255,255,255), (220,237,255,255), (178,217,255,255))
        tile = add_gloss(tile, radius)
        icon = crop_icon(icon_path, 76, 19, scale=1.04, sat=1.05)
        tile.alpha_composite(icon, (6,6))
        border = ImageDraw.Draw(tile)
        border.rounded_rectangle([2,2,size-3,size-3], radius=radius-3, outline=(255,255,255,210), width=2)
    elif style == 2:
        paste_shadow(base, (x,y), (size,size), radius, (24,60,105), blur=13, dy=10, alpha=64)
        tile = gradient_rect((size,size), (255,255,255,255), (240,247,255,255), (217,233,250,255))
        icon = crop_icon(icon_path, 68, 18, scale=1.0, sat=1.08)
        icon_shadow = Image.new("RGBA", tile.size, (0,0,0,0))
        icon_shadow.alpha_composite(icon, (10,14))
        icon_shadow = icon_shadow.filter(ImageFilter.GaussianBlur(4))
        tile.alpha_composite(icon_shadow)
        tile.alpha_composite(icon, (10,8))
        gd=ImageDraw.Draw(tile)
        gd.rounded_rectangle([1,1,size-2,size-2], radius=radius, outline=(210,226,246,255), width=1)
        gd.arc([8,8,size-8,size-8], 205, 330, fill=(255,255,255,180), width=2)
    elif style == 3:
        paste_shadow(base, (x,y), (size,size), radius, (8,47,99), blur=16, dy=13, alpha=92)
        rim = gradient_rect((size+8,size+8), (255,255,255,255), (135,190,245,255), (255,255,255,255))
        rim.putalpha(rounded_mask((size+8,size+8), radius+4))
        base.alpha_composite(rim, (x-4,y-4))
        tile = gradient_rect((size,size), (249,252,255,255), (216,231,247,255), (171,202,235,255))
        tile = add_gloss(tile, radius)
        icon = crop_icon(icon_path, 70, 18, scale=1.0, sat=1.12)
        tile.alpha_composite(icon, (9,9))
    else:
        colors = [
            ((24,202,243,255),(11,61,135,255)),
            ((255,139,115,255),(166,15,35,255)),
            ((85,214,108,255),(10,86,45,255)),
            ((255,207,84,255),(184,74,0,255)),
        ]
        c1,c2 = colors[(x//100 + y//100) % 4]
        paste_shadow(base, (x,y), (size,size), radius, (10,48,103), blur=14, dy=11, alpha=86)
        tile = gradient_rect((size,size), c1, c2)
        tile = add_gloss(tile, radius)
        icon = crop_icon(icon_path, 66, 17, scale=1.0, sat=1.16)
        paste_shadow(tile, (11,10), (66,66), 17, (0,0,0), blur=5, dy=6, alpha=42)
        tile.alpha_composite(icon, (11,10))
    tile.putalpha(rounded_mask((size,size), radius))
    base.alpha_composite(tile, (x,y))

def draw_panel(base, x, y, w, h, title, tag, style):
    paste_shadow(base, (x,y), (w,h), 30, (30,72,128), blur=24, dy=18, alpha=42)
    panel = Image.new("RGBA", (w,h), (255,255,255,210))
    pd = ImageDraw.Draw(panel)
    pd.rounded_rectangle([0,0,w-1,h-1], radius=30, fill=(255,255,255,218), outline=(187,209,235,210), width=1)
    pd.rectangle([1,1,w-2,90], fill=(255,255,255,42))
    base.alpha_composite(panel, (x,y))
    d = ImageDraw.Draw(base)
    d.text((x+25,y+20), title, font=F_H, fill=(18,49,95))
    tw = d.textbbox((0,0), tag, font=F_TAG)[2] + 26
    d.rounded_rectangle([x+w-tw-22,y+20,x+w-22,y+48], radius=14, fill=(232,243,255), outline=(204,226,251))
    d.text((x+w-tw-9,y+25), tag, font=F_TAG, fill=(31,93,168))
    start_x = x + 42
    start_y = y + 82
    cell_w = 142
    cell_h = 128
    for idx,(file,label) in enumerate(items):
        cx = start_x + (idx%4)*cell_w + 27
        cy = start_y + (idx//4)*cell_h
        draw_button(base, cx, cy, style, ICON_DIR/file)
        draw_wrapped_center(d, (start_x+(idx%4)*cell_w, cy+94), label, F_LABEL, (23,59,112), 132)

def main():
    im = Image.new("RGBA", (W,H), BG+(255,))
    d = ImageDraw.Draw(im)
    for gx in range(0,W,28):
        d.line([(gx,0),(gx,H)], fill=(119,150,190,32), width=1)
    for gy in range(0,H,28):
        d.line([(0,gy),(W,gy)], fill=(119,150,190,32), width=1)
    # soft wash
    wash = Image.new("RGBA",(W,H),(0,0,0,0))
    wd=ImageDraw.Draw(wash)
    wd.ellipse([-180,-220,760,430], fill=(255,255,255,145))
    wd.ellipse([830,-130,1650,520], fill=(206,232,255,120))
    wash = wash.filter(ImageFilter.GaussianBlur(25))
    im.alpha_composite(wash)
    d = ImageDraw.Draw(im)
    d.text((36,28), "ม็อกอัปปุ่มไอคอนแบบพรีเมียม", font=F_TITLE, fill=(18,49,95))
    d.text((38,78), "แนวไอคอน realistic / app แพง ๆ — เลือกทิศทางก่อน แล้วค่อยทำครบทั้ง 21 เมนู", font=F_SUB, fill=(83,107,144))
    draw_panel(im, 36, 126, 700, 470, "แบบ 1 · Ceramic Glass", "หรู สะอาด", 1)
    draw_panel(im, 764, 126, 700, 470, "แบบ 2 · Soft Object", "นุ่ม แพง", 2)
    draw_panel(im, 36, 626, 700, 470, "แบบ 3 · Metallic Enamel", "เงา มีมิติ", 3)
    draw_panel(im, 764, 626, 700, 470, "แบบ 4 · App Store Vivid", "สีสด iPhone", 4)
    im.convert("RGB").save(OUT, quality=95)
    print(OUT)

if __name__ == "__main__":
    main()
