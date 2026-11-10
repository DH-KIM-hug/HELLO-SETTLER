"""Frame-sheet template for the method-C resident spike (docs/RESIDENTS_2D.md, 2026-11-08).
One 1536x1024 canvas = 2 rows x 4 cells (384x512). In every cell: a top guide line (top of the head placeholder) and a
ground line (soles). Guide colour = darker chroma green so copied guides key out.
`python3 sheet_template.py` -> art/cutout/woman_c/raw/template.png"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "woman_c"))
W, H = 1536, 1024
CW, CH = 384, 512
TOP = 50       # top of the head placeholder, from the cell top
GROUND = 470   # soles, from the cell top


def cells():
    return [(c * CW, r * CH, (c + 1) * CW, (r + 1) * CH) for r in range(2) for c in range(4)]


if __name__ == "__main__":
    im = Image.new("RGB", (W, H), (0, 255, 0))
    d = ImageDraw.Draw(im)
    g = (0, 176, 0)
    for (x0, y0, x1, y1) in cells():
        d.rectangle((x0 + 4, y0 + 4, x1 - 4, y1 - 4), outline=g, width=3)
        d.line((x0 + 30, y0 + TOP, x1 - 30, y0 + TOP), fill=g, width=2)
        d.line((x0 + 30, y0 + GROUND, x1 - 30, y0 + GROUND), fill=g, width=4)
        d.line(((x0 + x1) // 2, y0 + GROUND - 12, (x0 + x1) // 2, y0 + GROUND + 12), fill=g, width=3)
    im.save(os.path.join(ART, "raw", "template.png"))
    print("ok")
