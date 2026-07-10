from pathlib import Path
from PIL import Image
from datetime import datetime
import shutil

ROOT = Path(__file__).resolve().parent
ICON_DIR = ROOT / "assets" / "menu-icons"
TARGETS = {
    # Manual crops tuned for the two off-center icons. These remove the pale
    # internal margin while keeping the rounded macOS icon body intact enough
    # for the 82px dashboard slot.
    "06-absent-student.png": (28, 34, 444, 458),
    "07-good-deed.png": (26, 28, 444, 444),
}

def main():
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = ICON_DIR / f"backup-two-icons-{stamp}"
    backup.mkdir(exist_ok=True)
    for name, box in TARGETS.items():
        path = ICON_DIR / name
        shutil.copy2(path, backup / name)
        im = Image.open(path).convert("RGBA")
        crop = im.crop(box).resize((512,512), Image.Resampling.LANCZOS)
        crop.save(path, optimize=True)
        print(name, box)
    print("backup", backup)

if __name__ == "__main__":
    main()
