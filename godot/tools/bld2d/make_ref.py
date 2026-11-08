"""Build refs/ref_buildings.png = the approved spike buildings (hut, bakery, lumber camp — RENDERING.md 2026-11-08 spike)
side by side on a light background, used as the building-style reference for every new picture.
usage: python3 make_ref.py <cut_dir>   (cut_dir holds hut.png, bakery.png, lumber.png keyed by key.py)"""
import sys
from pathlib import Path
from PIL import Image

cut = Path(sys.argv[1])
ims = [Image.open(cut / f"{n}.png").convert("RGBA") for n in ("hut_a", "bakery", "lumber")]
h = 420
ims = [i.resize((int(i.width * h / i.height), h), Image.LANCZOS) for i in ims]
W = sum(i.width for i in ims) + 40 * (len(ims) + 1)
c = Image.new("RGB", (W, h + 80), (250, 246, 236))
x = 40
for i in ims:
    c.paste(i, (x, 40), i)
    x += i.width + 40
out = Path(__file__).parent / "refs" / "ref_buildings.png"
c.save(out, optimize=True)
print(out, c.size)
