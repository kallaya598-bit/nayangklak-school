from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path

ROOT = Path(__file__).parent
S = 2
W, H = 390, 844
FONT = r"C:\Windows\Fonts\tahoma.ttf"
FONT_B = r"C:\Windows\Fonts\tahomabd.ttf"

apps = [
    ("clipboard", "รายงานเช็คชื่อ", "#0798b8"), ("absent", "นักเรียนขาด", "#dd3038"),
    ("heart", "บันทึกความดี", "#d21f70"), ("warning", "บันทึกพฤติกรรม", "#f35b23"),
    ("bars", "คะแนนสุทธิ", "#2f963b"), ("home", "เยี่ยมบ้านนักเรียน", "#008fb1"),
    ("map", "แผนที่บ้านนักเรียน", "#0098b9"), ("mind", "สุขภาพจิต", "#8e2dad"),
    ("groups", "กิจกรรมชุมนุม", "#3f4cad"), ("calendar", "ตารางสอน", "#0099b9"),
    ("star", "คะแนนรายวิชา", "#f57c00"), ("analytics", "เวลาเรียนรายวิชา", "#338f3b"),
    ("school", "เวลาเรียนรายห้อง", "#008cb0"), ("table", "ตารางนักเรียน", "#0098b8"),
    ("calendar_x", "ขาดเรียนรายวิชา", "#f05428"), ("run", "นักเรียนหนีเรียน", "#dc3439"),
    ("pdf", "ออกรายงาน PDF", "#008bae"),
]

def C(h): return tuple(int(h[i:i+2], 16) for i in (1,3,5))
def mix(a,b,t):
    a=C(a) if isinstance(a,str) else a; b=C(b) if isinstance(b,str) else b
    return tuple(round(a[i]*(1-t)+b[i]*t) for i in range(3))
def fnt(n,b=False): return ImageFont.truetype(FONT_B if b else FONT, n*S)
def rr(d, box, r, fill, outline=None, width=1):
    d.rounded_rectangle(tuple(v*S for v in box), r*S, fill=fill, outline=outline, width=width*S)
def txt(d, xy, text, font, fill, anchor="mm"):
    d.text((xy[0]*S,xy[1]*S),text,font=font,fill=fill,anchor=anchor)

def icon(d, kind, cx, cy, color, sw=2):
    x,y=cx*S,cy*S; k=S; w=sw*S
    def line(points, fill=color, width=w, joint="curve"):
        d.line([(a*S,b*S) for a,b in points],fill=fill,width=width,joint=joint)
    if kind=="heart":
        line([(cx-17,cy-5),(cx-12,cy-13),(cx-4,cy-14),(cx,cy-8),(cx+4,cy-14),(cx+12,cy-13),(cx+17,cy-5),(cx+15,cy+3),(cx,cy+17),(cx-15,cy+3),(cx-17,cy-5)])
    elif kind=="warning":
        line([(cx,cy-18),(cx+18,cy+16),(cx-18,cy+16),(cx,cy-18)])
        line([(cx,cy-7),(cx,cy+5)],width=3*k); d.ellipse((x-2*k,y+10*k,x+2*k,y+14*k),fill=color)
    elif kind=="star":
        pts=[]; import math
        for i in range(10):
            a=-math.pi/2+i*math.pi/5; r=(18 if i%2==0 else 8)*S
            pts.append((x+math.cos(a)*r,y+math.sin(a)*r))
        d.line(pts+[pts[0]],fill=color,width=w,joint="curve")
    elif kind in ("calendar","calendar_x"):
        d.rounded_rectangle((x-17*k,y-15*k,x+17*k,y+17*k),4*k,outline=color,width=w)
        line([(cx-17,cy-6),(cx+17,cy-6)]); line([(cx-9,cy-20),(cx-9,cy-11)]); line([(cx+9,cy-20),(cx+9,cy-11)])
        if kind=="calendar_x": line([(cx-6,cy),(cx+6,cy+12)],width=3*k);line([(cx+6,cy),(cx-6,cy+12)],width=3*k)
        else:
            for ox in (-8,0,8):
                for oy in (1,9): d.ellipse((x+(ox-1)*k,y+(oy-1)*k,x+(ox+1)*k,y+(oy+1)*k),fill=color)
    elif kind in ("bars","analytics"):
        for ox,hh in [(-13,18),(-3,29),(7,12)]:
            d.rectangle((x+ox*k,y+(16-hh)*k,x+(ox+7)*k,y+16*k),fill=color)
        if kind=="analytics": d.rounded_rectangle((x-19*k,y-20*k,x+19*k,y+20*k),3*k,outline=color,width=w)
    elif kind=="groups":
        for ox,oy,r in [(-10,-7,5),(0,-11,6),(10,-7,5)]: d.ellipse((x+(ox-r)*k,y+(oy-r)*k,x+(ox+r)*k,y+(oy+r)*k),outline=color,width=w)
        line([(cx-18,cy+15),(cx-16,cy+5),(cx-8,cy+1),(cx,cy+4),(cx+8,cy+1),(cx+16,cy+5),(cx+18,cy+15)])
    elif kind in ("clipboard","table","pdf"):
        d.rounded_rectangle((x-15*k,y-17*k,x+15*k,y+18*k),3*k,outline=color,width=w)
        if kind=="clipboard":
            d.rounded_rectangle((x-7*k,y-21*k,x+7*k,y-14*k),2*k,outline=color,width=w)
            for oy in (-7,1,9): line([(cx-8,cy+oy),(cx+9,cy+oy)])
        elif kind=="table":
            line([(cx-15,cy-7),(cx+15,cy-7)]); line([(cx-5,cy-7),(cx-5,cy+18)]); line([(cx+5,cy-7),(cx+5,cy+18)])
        else: txt(d,(cx,cy),"PDF",fnt(10,True),color)
    elif kind=="home" or kind=="school":
        line([(cx-18,cy),(cx,cy-17),(cx+18,cy),(cx+15,cy+17),(cx-15,cy+17),(cx-18,cy)])
        d.rectangle((x-4*k,y+5*k,x+4*k,y+17*k),outline=color,width=w)
        if kind=="school": line([(cx-22,cy-3),(cx,cy-20),(cx+22,cy-3)])
    elif kind=="map":
        line([(cx-18,cy-15),(cx-6,cy-19),(cx+6,cy-14),(cx+18,cy-19),(cx+18,cy+15),(cx+6,cy+19),(cx-6,cy+14),(cx-18,cy+19),(cx-18,cy-15)])
        line([(cx-6,cy-19),(cx-6,cy+14)]);line([(cx+6,cy-14),(cx+6,cy+19)])
    elif kind=="mind":
        d.ellipse((x-15*k,y-17*k,x+12*k,y+13*k),outline=color,width=w)
        line([(cx+10,cy+2),(cx+18,cy+8),(cx+10,cy+9),(cx+10,cy+18)])
        d.ellipse((x-5*k,y-7*k,x+5*k,y+3*k),outline=color,width=w)
    elif kind=="absent":
        line([(cx-17,cy-17),(cx+17,cy+17)],width=3*k); line([(cx-14,cy+10),(cx+14,cy+10)])
        d.arc((x-10*k,y-18*k,x+10*k,y+2*k),180,360,fill=color,width=w)
    elif kind=="run":
        d.ellipse((x+3*k,y-19*k,x+10*k,y-12*k),fill=color)
        line([(cx+5,cy-10),(cx-3,cy),(cx+7,cy+5),(cx+13,cy+17)],width=3*k)
        line([(cx-3,cy),(cx-14,cy+5)],width=3*k); line([(cx+1,cy+4),(cx-8,cy+17)],width=3*k)

def wrapped(d, text, center, y, color):
    font=fnt(13,True)
    if len(text)>12:
        cut=max(text.rfind(" ",0,len(text)//2+2),len(text)//2)
        if " " not in text: cut=len(text)//2
        lines=[text[:cut].strip(),text[cut:].strip()]
    else: lines=[text]
    for i,t in enumerate(lines): txt(d,(center,y+i*15),t,font,color)

def make(variant):
    if variant==4: bg="#081b35"; ink="#edf5ff"
    elif variant==3: bg="#f7f8fb"; ink="#17345e"
    else: bg="#f7fbff"; ink="#17345e"
    im=Image.new("RGB",(W*S,H*S),C(bg)); d=ImageDraw.Draw(im)
    # phone chrome
    d.rectangle((0,0,W*S,42*S),fill=C(bg))
    txt(d,(25,23),"14:29",fnt(13,True),ink,anchor="lm"); txt(d,(365,23),"▮▮▮  ◉  36%",fnt(10,True),ink,anchor="rm")
    bar="#102c52" if variant==4 else ("#ffffff" if variant==2 else "#173765")
    rr(d,(12,44,378,108),20,C(bar),C("#d7e4f1") if variant==2 else None)
    rr(d,(22,55,64,97),13,C("#e9f2fb") if variant==2 else C("#ffffff22")); txt(d,(43,76),"☰",fnt(24),ink if variant==2 else "white")
    rr(d,(72,55,114,97),12,"white"); txt(d,(93,76),"นพ",fnt(12,True),"#1565c0")
    rr(d,(122,55,318,97),13,C("#eff5fb")); txt(d,(139,76),"⌕",fnt(18,True),"#244c79"); txt(d,(157,76),"ค้นหานักเรียน",fnt(12),"#7c8da4",anchor="lm")
    txt(d,(347,76),"ออก",fnt(12,True),"white" if variant!=2 else "#17345e")
    titles=[("PRISM SOFT","สีโปร่ง พรีเมียม"),("ORBIT","เบา เป็นมิตร"),("BENTO PRO","มินิมอล มืออาชีพ"),("MIDNIGHT","เข้ม คอนทราสต์สูง")]
    txt(d,(20,133),"เมนูระบบ",fnt(20,True),ink,anchor="lm"); txt(d,(20,153),titles[variant-1][1],fnt(10,True),mix(C(ink),C(bg),.45),anchor="lm")
    rr(d,(288,123,370,148),12,C("#e8f2ff") if variant<4 else C("#1a3a64")); txt(d,(329,136),f"0{variant} · {titles[variant-1][0]}",fnt(7,True),"#1565c0" if variant<4 else "#8bdcff")
    # grid
    for idx,(kind,label,col) in enumerate(apps):
        row,col_i=divmod(idx,4); cx=50+col_i*96; cy=196+row*113
        c=C(col)
        if variant==1:
            shadow=Image.new("RGBA",im.size,(0,0,0,0)); sd=ImageDraw.Draw(shadow)
            sd.rounded_rectangle(((cx-33)*S,(cy-33)*S,(cx+33)*S,(cy+33)*S),20*S,fill=(*c,70))
            shadow=shadow.filter(ImageFilter.GaussianBlur(9*S)); im.paste(shadow,(0,0),shadow); d=ImageDraw.Draw(im)
            rr(d,(cx-33,cy-33,cx+33,cy+33),20,mix(c,(255,255,255),.08))
            icon(d,kind,cx,cy,(255,255,255),2)
        elif variant==2:
            d.ellipse(((cx-33)*S,(cy-33)*S,(cx+33)*S,(cy+33)*S),fill=mix(c,(255,255,255),.87),outline=mix(c,(255,255,255),.62),width=2*S)
            icon(d,kind,cx,cy,c,2); d.ellipse(((cx+23)*S,(cy-24)*S,(cx+32)*S,(cy-15)*S),fill=c)
        elif variant==3:
            rr(d,(cx-43,cy-45,cx+43,cy+56),16,"white","#e1e6ee")
            rr(d,(cx-25,cy-34,cx+25,cy+16),15,mix(c,(255,255,255),.88))
            icon(d,kind,cx,cy-9,c,2)
        else:
            rr(d,(cx-33,cy-33,cx+33,cy+33),19,C("#102c4e"),mix(c,C("#102c4e"),.25))
            icon(d,kind,cx,cy,c,2)
        wrapped(d,label,cx,cy+43 if variant!=3 else cy+34,ink if variant!=4 else "#e7effa")
    foot="#102b4d" if variant==4 else ("#163a67" if variant==2 else "#ffffff")
    rr(d,(15,770,375,828),18,C(foot),C("#d9e5f4") if variant in (1,3) else None)
    d.ellipse((28*S,794*S,36*S,802*S),fill=C("#35b557"))
    txt(d,(44,799),"ออนไลน์ · ภาคเรียน 1/2569",fnt(11,True),"white" if variant in (2,4) else ink,anchor="lm")
    counter_ink=(255,255,255) if variant in (2,4) else C(ink)
    txt(d,(355,799),"796 คน",fnt(10,True),mix(counter_ink,C(foot),.4),anchor="rm")
    return im

for i in range(1,5):
    out=ROOT/f"icon-grid-mockup-{i}.png"
    make(i).save(out,optimize=True)
    print(out)
