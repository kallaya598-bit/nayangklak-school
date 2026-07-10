from pathlib import Path
from PIL import Image, ImageStat
from collections import deque
import shutil
from datetime import datetime

ROOT = Path(__file__).resolve().parent
SRC = Path(r"C:\Users\Adisak\.codex\generated_images\019ef30a-f855-7203-8fa9-20df4e528063\ig_0c6c4683c4edba79016a3b4b16d3ec8191a873f0b0cd0aef6e.png")
ICON_DIR = ROOT / "assets" / "menu-icons"
SHEET_OUT = ICON_DIR / "macos-icon-sheet-source.png"

FILES = [
    "01-student-info.png",
    "02-morning-flag.png",
    "03-evening-attendance.png",
    "04-class-check.png",
    "05-attendance-report.png",
    "06-absent-student.png",
    "07-good-deed.png",
    "08-behavior-record.png",
    "09-net-score.png",
    "10-home-visit.png",
    "11-home-map.png",
    "12-mental-health.png",
    "13-club-activities.png",
    "14-teaching-schedule.png",
    "15-subject-grades.png",
    "16-subject-time.png",
    "17-classroom-time.png",
    "18-student-timetable.png",
    "19-subject-absence.png",
    "20-truancy.png",
    "21-pdf-report.png",
]

def bg_color(cell):
    w, h = cell.size
    samples = []
    pad = max(4, min(w, h) // 18)
    regions = [
        (0, 0, pad, pad),
        (w - pad, 0, w, pad),
        (0, h - pad, pad, h),
        (w - pad, h - pad, w, h),
    ]
    for box in regions:
        stat = ImageStat.Stat(cell.crop(box).convert("RGB"))
        samples.append(tuple(stat.mean))
    return tuple(sum(s[i] for s in samples) / len(samples) for i in range(3))

def largest_icon_bbox(cell):
    """Find the main icon tile in a generated cell and crop around it.

    A fixed center crop can cut off icons that are slightly off-center. A raw
    threshold crop can catch thin slivers from neighboring cells. This keeps the
    largest connected non-background component, which is the actual icon tile.
    """
    rgb = cell.convert("RGB")
    w, h = rgb.size
    bg = bg_color(rgb)
    pix = rgb.load()
    mask = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b = pix[x, y]
            dist = abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])
            sat = max(r, g, b) - min(r, g, b)
            if dist > 24 or sat > 18:
                mask[y][x] = True

    seen = [[False] * w for _ in range(h)]
    best = None
    for yy in range(h):
        for xx in range(w):
            if not mask[yy][xx] or seen[yy][xx]:
                continue
            q = deque([(xx, yy)])
            seen[yy][xx] = True
            area = 0
            x0 = x1 = xx
            y0 = y1 = yy
            touches = False
            while q:
                x, y = q.popleft()
                area += 1
                x0, x1 = min(x0, x), max(x1, x)
                y0, y1 = min(y0, y), max(y1, y)
                if x <= 1 or y <= 1 or x >= w - 2 or y >= h - 2:
                    touches = True
                for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                    if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        q.append((nx, ny))
            # Neighbor slivers often touch a cell edge and are small; don't let
            # them win over the actual centered icon tile.
            score = area * (0.25 if touches else 1)
            if best is None or score > best[0]:
                best = (score, area, x0, y0, x1, y1)

    if best is None:
        side = int(round(min(w, h) * 0.78))
        cx, cy = w // 2, h // 2
    else:
        _, _, x0, y0, x1, y1 = best
        bw, bh = x1 - x0 + 1, y1 - y0 + 1
        side = int(round(max(bw, bh) * 1.08))
        side = min(side, int(round(min(w, h) * 0.84)))
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2

    sx0 = int(round(cx - side / 2))
    sy0 = int(round(cy - side / 2))
    sx1, sy1 = sx0 + side, sy0 + side
    if sx0 < 0:
        sx1 -= sx0
        sx0 = 0
    if sy0 < 0:
        sy1 -= sy0
        sy0 = 0
    if sx1 > w:
        sx0 -= sx1 - w
        sx1 = w
    if sy1 > h:
        sy0 -= sy1 - h
        sy1 = h
    return (max(0, sx0), max(0, sy0), min(w, sx1), min(h, sy1))

def main():
    if not SRC.exists():
        raise FileNotFoundError(SRC)
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = ICON_DIR / f"backup-before-macos-{stamp}"
    backup.mkdir()
    for name in FILES:
        p = ICON_DIR / name
        if p.exists():
            shutil.copy2(p, backup / name)
    sheet = Image.open(SRC).convert("RGBA")
    shutil.copy2(SRC, SHEET_OUT)
    sw, sh = sheet.size
    cols, rows = 7, 3
    for i, name in enumerate(FILES):
        col, row = i % cols, i // cols
        x0 = round(col * sw / cols)
        x1 = round((col + 1) * sw / cols)
        y0 = round(row * sh / rows)
        y1 = round((row + 1) * sh / rows)
        cell = sheet.crop((x0, y0, x1, y1))
        box = largest_icon_bbox(cell)
        icon = cell.crop(box)
        icon = icon.resize((512, 512), Image.Resampling.LANCZOS)
        icon.save(ICON_DIR / name, optimize=True)
    print(f"source={SHEET_OUT}")
    print(f"backup={backup}")
    print(f"icons={len(FILES)}")

if __name__ == "__main__":
    main()
