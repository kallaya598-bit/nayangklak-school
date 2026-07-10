from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import math

ROOT=Path(__file__).parent
S=2; W,H=390,844
FONT=r"C:\Windows\Fonts\tahoma.ttf"; FONT_B=r"C:\Windows\Fonts\tahomabd.ttf"
apps=[
("clipboard","รายงานเช็คชื่อ","#16a6c7"),("absent","นักเรียนขาด","#ed3b4a"),("heart","บันทึกความดี","#db2674"),("warning","บันทึกพฤติกรรม","#ff6235"),
("bars","คะแนนสุทธิ","#39a34a"),("home","เยี่ยมบ้านนักเรียน","#0ba1c1"),("map","แผนที่บ้านนักเรียน","#08a4c4"),("mind","สุขภาพจิต","#9639b7"),
("groups","กิจกรรมชุมนุม","#5361c3"),("calendar","ตารางสอน","#0aa4c4"),("star","คะแนนรายวิชา","#ff8a0a"),("analytics","เวลาเรียนรายวิชา","#3a9e4a"),
("school","เวลาเรียนรายห้อง","#08a1c1"),("table","ตารางนักเรียน","#08a4c4"),("calendar_x","ขาดเรียนรายวิชา","#ff5c35"),("run","นักเรียนหนีเรียน","#e63b48"),
("pdf","ออกรายงาน PDF","#079dbc")]
def C(h):return tuple(int(h[i:i+2],16) for i in(1,3,5))
def mix(a,b,t):a=C(a)if isinstance(a,str)else a;b=C(b)if isinstance(b,str)else b;return tuple(round(a[i]*(1-t)+b[i]*t)for i in range(3))
def F(n,b=False):return ImageFont.truetype(FONT_B if b else FONT,n*S)
def text(d,xy,s,n,fill,b=False,anchor="mm"):d.text((xy[0]*S,xy[1]*S),s,font=F(n,b),fill=fill,anchor=anchor)
def rr(d,b,r,fill,outline=None,w=1):d.rounded_rectangle(tuple(v*S for v in b),r*S,fill=fill,outline=outline,width=w*S)
def line(d,pts,fill,w=2):d.line([(x*S,y*S)for x,y in pts],fill=fill,width=w*S,joint="curve")
def symbol(d,k,cx,cy,col):
 x,y=cx*S,cy*S
 if k=="heart": line(d,[(cx-15,cy-5),(cx-11,cy-13),(cx-3,cy-14),(cx,cy-8),(cx+3,cy-14),(cx+11,cy-13),(cx+15,cy-5),(cx+13,cy+3),(cx,cy+16),(cx-13,cy+3),(cx-15,cy-5)],col)
 elif k=="warning":line(d,[(cx,cy-17),(cx+17,cy+15),(cx-17,cy+15),(cx,cy-17)],col);line(d,[(cx,cy-6),(cx,cy+5)],col,3);d.ellipse((x-2*S,y+10*S,x+2*S,y+14*S),fill=col)
 elif k=="star":
  p=[]
  for i in range(10):
   a=-math.pi/2+i*math.pi/5;r=(17 if i%2==0 else 7)*S;p.append((x+math.cos(a)*r,y+math.sin(a)*r))
  d.line(p+[p[0]],fill=col,width=2*S,joint="curve")
 elif k in("calendar","calendar_x"):
  d.rounded_rectangle((x-15*S,y-15*S,x+15*S,y+16*S),4*S,outline=col,width=2*S);line(d,[(cx-15,cy-6),(cx+15,cy-6)],col);line(d,[(cx-8,cy-19),(cx-8,cy-11)],col);line(d,[(cx+8,cy-19),(cx+8,cy-11)],col)
  if k=="calendar_x":line(d,[(cx-6,cy),(cx+6,cy+12)],col,3);line(d,[(cx+6,cy),(cx-6,cy+12)],col,3)
  else:
   for ox in(-7,0,7):
    for oy in(1,8):d.ellipse(((cx+ox-1)*S,(cy+oy-1)*S,(cx+ox+1)*S,(cy+oy+1)*S),fill=col)
 elif k in("bars","analytics"):
  for ox,hh in[(-12,17),(-3,27),(7,11)]:d.rectangle(((cx+ox)*S,(cy+15-hh)*S,(cx+ox+6)*S,(cy+15)*S),fill=col)
  if k=="analytics":d.rounded_rectangle((x-18*S,y-19*S,x+18*S,y+19*S),3*S,outline=col,width=2*S)
 elif k=="groups":
  for ox,oy,r in[(-9,-6,5),(0,-10,6),(9,-6,5)]:d.ellipse(((cx+ox-r)*S,(cy+oy-r)*S,(cx+ox+r)*S,(cy+oy+r)*S),outline=col,width=2*S)
  line(d,[(cx-17,cy+15),(cx-15,cy+5),(cx-7,cy+1),(cx,cy+4),(cx+7,cy+1),(cx+15,cy+5),(cx+17,cy+15)],col)
 elif k in("clipboard","table","pdf"):
  d.rounded_rectangle((x-14*S,y-16*S,x+14*S,y+17*S),3*S,outline=col,width=2*S)
  if k=="clipboard":
   d.rounded_rectangle((x-6*S,y-20*S,x+6*S,y-14*S),2*S,outline=col,width=2*S)
   for oy in(-7,1,9):line(d,[(cx-8,cy+oy),(cx+8,cy+oy)],col)
  elif k=="table":line(d,[(cx-14,cy-6),(cx+14,cy-6)],col);line(d,[(cx-5,cy-6),(cx-5,cy+17)],col);line(d,[(cx+5,cy-6),(cx+5,cy+17)],col)
  else:text(d,(cx,cy),"PDF",9,col,True)
 elif k in("home","school"):
  line(d,[(cx-17,cy),(cx,cy-16),(cx+17,cy),(cx+14,cy+16),(cx-14,cy+16),(cx-17,cy)],col);d.rectangle((x-4*S,y+5*S,x+4*S,y+16*S),outline=col,width=2*S)
 elif k=="map":line(d,[(cx-17,cy-15),(cx-6,cy-18),(cx+6,cy-14),(cx+17,cy-18),(cx+17,cy+15),(cx+6,cy+18),(cx-6,cy+14),(cx-17,cy+18),(cx-17,cy-15)],col);line(d,[(cx-6,cy-18),(cx-6,cy+14)],col);line(d,[(cx+6,cy-14),(cx+6,cy+18)],col)
 elif k=="mind":d.ellipse((x-14*S,y-16*S,x+11*S,y+12*S),outline=col,width=2*S);line(d,[(cx+9,cy+2),(cx+17,cy+8),(cx+9,cy+9),(cx+9,cy+17)],col);d.ellipse((x-4*S,y-6*S,x+4*S,y+2*S),outline=col,width=2*S)
 elif k=="absent":line(d,[(cx-16,cy-16),(cx+16,cy+16)],col,3);line(d,[(cx-13,cy+10),(cx+13,cy+10)],col);d.arc((x-9*S,y-17*S,x+9*S,y+1*S),180,360,fill=col,width=2*S)
 elif k=="run":d.ellipse((x+3*S,y-18*S,x+10*S,y-11*S),fill=col);line(d,[(cx+5,cy-9),(cx-3,cy),(cx+7,cy+5),(cx+12,cy+16)],col,3);line(d,[(cx-3,cy),(cx-13,cy+5)],col,3);line(d,[(cx+1,cy+4),(cx-8,cy+16)],col,3)
def label(d,s,cx,y):
 parts=[s] if len(s)<=12 else [s[:len(s)//2],s[len(s)//2:]]
 for i,p in enumerate(parts):text(d,(cx,y+i*14),p,12,"#17345e",True)
def base():
 im=Image.new("RGB",(W*S,H*S),C("#f6f9fe"));d=ImageDraw.Draw(im)
 # fixed original layout: only icons differ
 text(d,(25,23),"14:29",13,"#17345e",True,"lm");text(d,(365,23),"▮▮▮  ◉  36%",10,"#17345e",True,"rm")
 rr(d,(12,44,378,108),20,C("#173765"));rr(d,(22,55,64,97),13,C("#ffffff22"));text(d,(43,76),"☰",24,"white")
 rr(d,(72,55,114,97),12,"white");text(d,(93,76),"นพ",12,"#1565c0",True)
 rr(d,(122,55,318,97),13,C("#eff5fb"));text(d,(139,76),"⌕",18,"#244c79",True);text(d,(157,76),"ค้นหานักเรียน",12,"#7c8da4",False,"lm");text(d,(347,76),"ออก",12,"white",True)
 return im,d
def render(v):
 im,d=base()
 for i,(kind,name,hx) in enumerate(apps):
  row,col=divmod(i,4);cx=50+col*96;cy=169+row*113;c=C(hx)
  shadow=Image.new("RGBA",im.size,(0,0,0,0));sd=ImageDraw.Draw(shadow)
  sd.rounded_rectangle(((cx-33)*S,(cy-33)*S,(cx+33)*S,(cy+33)*S),15*S,fill=(18,41,72,55))
  shadow=shadow.filter(ImageFilter.GaussianBlur((6 if v<3 else 9)*S));im.paste(shadow,(0,0),shadow);d=ImageDraw.Draw(im)
  if v==1: # iOS vivid gradient
   for yy in range(-33,34):
    t=(yy+33)/66;cc=mix(mix(c,(255,255,255),.24),mix(c,(0,0,0),.08),t)
    d.line(((cx-33)*S,(cy+yy)*S,(cx+33)*S,(cy+yy)*S),fill=cc,width=S)
   rr(d,(cx-33,cy-33,cx+33,cy+33),15,None,C("#ffffff55"))
   symbol(d,kind,cx,cy,(255,255,255))
  elif v==2: # frosted iOS tile
   rr(d,(cx-33,cy-33,cx+33,cy+33),15,mix(c,(255,255,255),.82),mix(c,(255,255,255),.48))
   d.ellipse(((cx-26)*S,(cy-27)*S,(cx+12)*S,(cy+11)*S),fill=mix(c,(255,255,255),.70))
   symbol(d,kind,cx,cy,c)
  elif v==3: # duotone iOS
   rr(d,(cx-33,cy-33,cx+33,cy+33),15,mix(c,(255,255,255),.12))
   d.rounded_rectangle(((cx-25)*S,(cy-25)*S,(cx+25)*S,(cy+25)*S),12*S,fill=mix(c,(0,0,0),.16))
   symbol(d,kind,cx,cy,(255,255,255))
  else: # clean white app icon with color glyph
   rr(d,(cx-33,cy-33,cx+33,cy+33),15,"white",mix(c,(255,255,255),.58))
   d.ellipse(((cx-24)*S,(cy-24)*S,(cx+24)*S,(cy+24)*S),fill=mix(c,(255,255,255),.88))
   symbol(d,kind,cx,cy,c)
  label(d,name,cx,cy+44)
 rr(d,(15,770,375,828),18,"white",C("#d9e5f4"));d.ellipse((28*S,794*S,36*S,802*S),fill=C("#35b557"));text(d,(44,799),"ออนไลน์ · ภาคเรียน 1/2569",11,"#17345e",True,"lm");text(d,(355,799),"796 คน",10,"#8292aa",True,"rm")
 return im
for i in range(1,5):
 p=ROOT/f"ios-icon-only-mockup-{i}.png";render(i).save(p,optimize=True);print(p)
