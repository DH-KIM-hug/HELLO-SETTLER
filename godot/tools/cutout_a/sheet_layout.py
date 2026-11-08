"""Strict part-sheet template for the concept-A cutout prototype v2 (2026-11-08).
One fixed canvas (1536x1024): the assembled figure on the left at a fixed height, the parts in fixed grid cells on the right.
`python3 sheet_layout.py` writes art/cutout/woman_a/raw/template.png (guide image given to the image model).
Guide lines are a darker chroma green (#00B000) so that if the model copies them they are keyed out anyway."""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "woman_a"))
W, H = 1536, 1024
FIG_BOX = (40, 30, 560, 1000)
HEAD_TOP_Y = 70        # top of the headscarf
FEET_Y = 990           # soles of the shoes
FIG_H = FEET_Y - HEAD_TOP_Y
# part cells (x0, y0, x1, y1) — letter, name, description used in the prompt
CELLS = [
    ("A", "body", (600, 30, 1090, 650)),
    ("B", "head", (1110, 30, 1500, 400)),
    ("C", "knot", (1110, 420, 1300, 650)),
    ("D", "tail", (1320, 420, 1500, 650)),
    ("E", "sleeve_a", (600, 680, 760, 1000)),
    ("F", "sleeve_b", (780, 680, 940, 1000)),
    ("G", "arm_a", (960, 680, 1080, 1000)),
    ("H", "arm_b", (1100, 680, 1220, 1000)),
    ("I", "leg_a", (1240, 680, 1360, 1000)),
    ("J", "leg_b", (1380, 680, 1500, 1000)),
]
PROP_CELLS = [
    ("A", "bread", (60, 60, 520, 480)),
    ("B", "twigs", (560, 60, 1000, 480)),
    ("C", "basket", (1040, 60, 1480, 480)),
    ("D", "bread_q", (60, 540, 520, 960)),
    ("E", "twigs_q", (560, 540, 1000, 960)),
    ("F", "basket_q", (1040, 540, 1480, 960)),
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
    template(PROP_CELLS, fig=False).save(os.path.join(ART, "raw", "template_props.png"))
    print("ok")
