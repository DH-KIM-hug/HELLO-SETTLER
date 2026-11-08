"""Strict part-sheet template for the 2D paper-cutout PUPPY (E3-13 / E3-13b, 2026-11-08).
Same idea as tools/cutout_a/sheet_layout.py (residents): one fixed 1536x1024 canvas, the assembled dog top-left at a fixed
height, every part in its own fixed cell. `python3 sheet_layout.py` writes art/cutout/dog_a/raw/template.png.
Guide lines are a darker chroma green (#00B000) so that if the model copies them they are keyed out anyway."""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "dog_a"))
W, H = 1536, 1024
FIG_BOX = (30, 30, 610, 600)
HEAD_TOP_Y = 150       # top of the head / ears of the standing dog
FEET_Y = 580           # soles of the paws
FIG_H = FEET_Y - HEAD_TOP_Y
# part cells (x0, y0, x1, y1)
CELLS = [
    ("A", "body", (640, 30, 1110, 340)),
    ("B", "head", (1130, 30, 1500, 340)),
    ("C", "head_sleep", (640, 360, 900, 620)),
    ("D", "head_bark", (920, 360, 1180, 620)),
    ("E", "tail_curl", (1200, 360, 1345, 620)),
    ("F", "tail_straight", (1360, 360, 1505, 620)),
    ("G", "ear_pointy", (640, 640, 780, 830)),
    ("H", "ear_folded", (800, 640, 940, 830)),
    ("I", "ear_floppy", (960, 640, 1100, 830)),
    ("J", "leg_fa", (1120, 640, 1210, 1000)),
    ("K", "leg_fb", (1215, 640, 1305, 1000)),
    ("L", "leg_ha", (1315, 640, 1405, 1000)),
    ("M", "leg_hb", (1410, 640, 1500, 1000)),
    ("N", "sweater", (30, 630, 610, 1000)),
]


def template(cells, fig=True):
    im = Image.new("RGB", (W, H), (0, 255, 0))
    d = ImageDraw.Draw(im)
    g = (0, 176, 0)
    if fig:
        d.rectangle(FIG_BOX, outline=g, width=3)
        d.line((FIG_BOX[0], HEAD_TOP_Y, FIG_BOX[2], HEAD_TOP_Y), fill=g, width=3)
        d.line((FIG_BOX[0], FEET_Y, FIG_BOX[2], FEET_Y), fill=g, width=3)
    for _, _, b in cells:
        d.rectangle(b, outline=g, width=3)
    return im


if __name__ == "__main__":
    os.makedirs(os.path.join(ART, "raw"), exist_ok=True)
    template(CELLS).save(os.path.join(ART, "raw", "template.png"))
    print("ok")
