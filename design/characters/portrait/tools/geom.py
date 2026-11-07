"""Canonical bust geometry for the layered portrait (512x512 cell). Everything registers to this."""
import math
from PIL import Image, ImageDraw

CELL = 512
CX = 256
HEAD_TOP = 110
HEAD_MID = 236          # widest row
CHIN = 352
HALF_W = 116
EAR_Y = 262
EAR_DX = 112
NECK = (224, 318, 288, 420)
MAGENTA = (255, 0, 255)
GREEN = (0, 220, 70)


def head_poly(cx=CX, top=HEAD_TOP, mid=HEAD_MID, chin=CHIN, hw=HALF_W, n=90):
    pts = []
    for i in range(n + 1):           # upper half: ellipse
        a = math.pi + math.pi * i / n
        pts.append((cx + hw * math.cos(a), mid + (mid - top) * math.sin(a)))
    for i in range(1, n):            # lower half: softer chin (superellipse)
        a = math.pi * i / n
        c, s = math.cos(a), math.sin(a)
        x = math.copysign(abs(c) ** (2 / 2.4), c)
        y = abs(s) ** (2 / 2.6)
        pts.append((cx + hw * x, mid + (chin - mid) * y))
    return pts


def shoulders_poly(cx=CX):
    left = []
    for i in range(21):
        t = i / 20
        left.append((cx - 34 - 150 * math.sin(t * math.pi / 2), 392 + 46 * (1 - math.cos(t * math.pi / 2)) ** 0.8 + 6 * t))
    right = [(2 * cx - x, y) for x, y in reversed(left)]
    return left + [(cx - 196, 512), (cx + 196, 512)] + right


def draw_template(d, ox=0, oy=0, col=GREEN, body=True):
    sh = lambda pts: [(x + ox, y + oy) for x, y in pts]
    if body:
        d.polygon(sh(shoulders_poly()), fill=col)
        d.rectangle((NECK[0] + ox, NECK[1] + oy, NECK[2] + ox, NECK[3] + oy), fill=col)
    for s in (-1, 1):
        ex = CX + s * EAR_DX
        d.ellipse((ex - 18 + ox, EAR_Y - 26 + oy, ex + 18 + ox, EAR_Y + 26 + oy), fill=col)
    d.polygon(sh(head_poly()), fill=col)


def sheet_template(cols=3, rows=2, body=True, path=None):
    im = Image.new("RGB", (CELL * cols, CELL * rows), MAGENTA)
    d = ImageDraw.Draw(im)
    for r in range(rows):
        for c in range(cols):
            draw_template(d, c * CELL, r * CELL, body=body)
    if path:
        im.save(path)
    return im


if __name__ == "__main__":
    import sys
    out = sys.argv[1]
    sheet_template(path=out + "/template_3x2.png")
