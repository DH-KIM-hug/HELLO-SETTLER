"""Resident face atlas (A20 v3, design/characters/expressions_a.png) -> godot/art/models/resident_face.png (512 x 512).
Data channels, tinted per resident in render/resident.gdshader:
  R = ink (brows, closed eyes, mouth line, nose)   G = iris (eye colour from genes, kept dark)
  B = white (highlight inside the iris)            A = warm (blush; with ink = inside of an open mouth)
2 columns x 4 rows of 256 x 128 cells:  0 normal 1 happy | 2 sad 3 sick | 4 sleep 5 surprised | 6 talking 7 blink
Cell space = the face region projected from the front (build_residents.py FACE_W / FACE_TOP / FACE_H):
  x in [-0.25, 0.25], z (relative to the head centre) from +0.1 (top) to -0.2 (bottom).
Run: python3 paint_face_atlas.py [out.png]   (system python with Pillow; drawn 4x and filtered down = soft painted edges)
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "models", "resident_face.png")
SS = 4
CW, CH = 256, 128
FW, FTOP, FH = 0.5, 0.1, 0.3
NAMES = ["normal", "happy", "sad", "sick", "sleep", "surprised", "talking", "blink"]

EX, EZ = 0.095, -0.012         # eyes (v5: a little larger and higher so they read under the 48-degree camera / the fringe)
MZ = -0.125                    # mouth


class Cell:
    def __init__(self, layers, col, row):
        self.L = layers
        self.ox = col * CW * SS
        self.oy = row * CH * SS

    def P(self, x, z):
        return (self.ox + (x + FW / 2) / FW * CW * SS, self.oy + (FTOP - z) / FH * CH * SS)

    def sx(self, w):
        return w / FW * CW * SS

    def sz(self, h):
        return h / FH * CH * SS

    def ellipse(self, ch, x, z, w, h, v=255):
        a = self.P(x - w / 2, z + h / 2)
        b = self.P(x + w / 2, z - h / 2)
        self.L[ch].ellipse([a, b], fill=v)

    def arc(self, ch, x, z, w, h, up=True, t=0.011, v=255, n=16):
        """Curved stroke through (x-w/2, z) .. (x+w/2, z) bulging by h (up = ^ shape, else u)."""
        pts = []
        for i in range(n + 1):
            u = i / n
            px = x - w / 2 + w * u
            pz = z + (1 if up else -1) * h * math.sin(u * math.pi)
            pts.append(self.P(px, pz))
        self.L[ch].line(pts, fill=v, width=max(1, int(self.sz(t))), joint="curve")
        r = self.sz(t) / 2
        for p in (pts[0], pts[-1]):
            self.L[ch].ellipse([(p[0] - r, p[1] - r), (p[0] + r, p[1] + r)], fill=v)

    def line(self, ch, pts, t=0.011, v=255):
        q = [self.P(*p) for p in pts]
        self.L[ch].line(q, fill=v, width=max(1, int(self.sz(t))), joint="curve")
        r = self.sz(t) / 2
        for p in (q[0], q[-1]):
            self.L[ch].ellipse([(p[0] - r, p[1] - r), (p[0] + r, p[1] + r)], fill=v)

    def poly(self, ch, pts, v=255):
        self.L[ch].polygon([self.P(*p) for p in pts], fill=v)


def blush(c, k=1.0):
    for s in (-1, 1):
        c.ellipse("A", s * 0.155, -0.072, 0.09, 0.048, int(180 * k))


def eyes(c, w=0.05, h=0.07, hl=True, half=False):
    for s in (-1, 1):
        x = s * EX
        c.ellipse("G", x, EZ, w, h)
        if hl:
            c.ellipse("B", x + 0.008, EZ + h * 0.22, w * 0.38, h * 0.3)
            c.ellipse("G", x + 0.008, EZ + h * 0.22, w * 0.38, h * 0.3)
        if half:                                   # heavy lids: cover the top half with skin, line on the lid
            c.poly("G", [(x - w, EZ + 0.004), (x + w, EZ + 0.004), (x + w, EZ + h), (x - w, EZ + h)], v=0)
            c.poly("B", [(x - w, EZ + 0.004), (x + w, EZ + 0.004), (x + w, EZ + h), (x - w, EZ + h)], v=0)
            c.line("R", [(x - w * 0.65, EZ + 0.006), (x + w * 0.65, EZ + 0.004)], t=0.011)


def brows(c, lift=0.0, tilt=0.0, w=0.055, z=0.06):
    """tilt > 0 = worried (inner ends up)."""
    for s in (-1, 1):
        x0, x1 = s * (EX - w / 2), s * (EX + w / 2)
        zi = z + lift + tilt * 0.02             # inner end (toward the nose)
        zo = z + lift - tilt * 0.012
        inner, outer = (x0, zi), (x1, zo)
        mid = ((x0 + x1) / 2, (zi + zo) / 2 + 0.006)
        c.line("R", [inner, mid, outer], t=0.009, v=200)


def nose(c):
    c.arc("R", 0.0, -0.068, 0.022, 0.006, up=False, t=0.007, v=140)


def mouth_smile(c, w=0.06, h=0.016):
    c.arc("R", 0, MZ + 0.004, w, h, up=False, t=0.01)


def mouth_open(c, w=0.07, h=0.045, round_=False):
    if round_:
        c.ellipse("R", 0, MZ - 0.005, w, h, v=160)
        c.ellipse("A", 0, MZ - 0.005, w, h, v=255)
        return
    pts = []
    for i in range(17):                            # D shape: flat top, round bottom
        u = i / 16
        pts.append((-w / 2 + w * u, MZ + 0.01 - h * math.sin(u * math.pi)))
    c.poly("R", pts, v=150)
    c.poly("A", pts, v=255)
    c.line("R", [(-w / 2, MZ + 0.01), (w / 2, MZ + 0.01)], t=0.008)


def paint(c, name):
    nose(c)
    if name == "normal":
        eyes(c)
        brows(c)
        blush(c)
        mouth_smile(c)
    elif name == "happy":
        for s in (-1, 1):
            c.arc("R", s * EX, EZ - 0.012, 0.055, 0.026, up=True, t=0.012)
        brows(c, lift=0.012)
        blush(c, 1.3)
        mouth_open(c, 0.075, 0.05)
    elif name == "sad":
        eyes(c, h=0.052)
        brows(c, tilt=1.0)
        blush(c, 0.5)
        c.arc("R", 0, MZ - 0.012, 0.05, 0.014, up=True, t=0.01)
    elif name == "sick":
        eyes(c, half=True)
        brows(c, tilt=1.0)
        pts = [(-0.03 + 0.06 * i / 8, MZ - 0.004 + 0.006 * math.sin(i / 8 * math.pi * 2)) for i in range(9)]
        c.line("R", pts, t=0.009)
    elif name == "sleep":
        for s in (-1, 1):
            c.arc("R", s * EX, EZ - 0.002, 0.052, 0.018, up=False, t=0.011)
        brows(c, lift=-0.004)
        blush(c, 0.8)
        c.arc("R", 0, MZ, 0.03, 0.006, up=False, t=0.009)
    elif name == "surprised":
        eyes(c, w=0.048, h=0.068)
        brows(c, lift=0.022)
        blush(c, 0.7)
        mouth_open(c, 0.04, 0.045, round_=True)
    elif name == "talking":
        eyes(c)
        brows(c, lift=0.006)
        blush(c)
        mouth_open(c, 0.055, 0.032)
    elif name == "blink":
        for s in (-1, 1):
            c.arc("R", s * EX, EZ - 0.006, 0.05, 0.012, up=False, t=0.011)
        brows(c)
        blush(c)
        mouth_smile(c)


def main():
    W, H = 2 * CW * SS, 4 * CH * SS
    imgs = {ch: Image.new("L", (W, H), 0) for ch in "RGBA"}
    layers = {ch: ImageDraw.Draw(imgs[ch]) for ch in "RGBA"}
    for i, n in enumerate(NAMES):
        paint(Cell(layers, i % 2, i // 2), n)
    imgs["A"] = imgs["A"].filter(ImageFilter.GaussianBlur(SS * 3)).point(lambda v: min(255, int(v * 1.6)))
    # the open mouth keeps a crisp warm inside: redraw mouths sharp on top of the blurred blush
    sharp = Image.new("L", (W, H), 0)
    sd = {"A": ImageDraw.Draw(sharp), "R": ImageDraw.Draw(Image.new("L", (W, H))), "G": ImageDraw.Draw(Image.new("L", (W, H))),
          "B": ImageDraw.Draw(Image.new("L", (W, H)))}
    for i, n in enumerate(NAMES):
        c = Cell(sd, i % 2, i // 2)
        if n == "happy":
            mouth_open(c, 0.075, 0.05)
        elif n == "surprised":
            mouth_open(c, 0.04, 0.045, round_=True)
        elif n == "talking":
            mouth_open(c, 0.055, 0.032)
    imgs["A"] = Image.fromarray(__import__("numpy").maximum(__import__("numpy").array(imgs["A"]), __import__("numpy").array(sharp)))
    out = Image.merge("RGBA", [imgs[ch].resize((W // SS, H // SS), Image.LANCZOS) for ch in "RGBA"])
    out.save(OUT)
    print("face atlas ->", os.path.normpath(OUT), out.size)
    # preview (composited on a skin tone) for checking by eye
    prev = os.environ.get("FACE_PREVIEW")
    if prev:
        import numpy as np
        a = np.asarray(out).astype(float) / 255.0
        skin = np.array([0.93, 0.74, 0.6])
        c = np.ones(a.shape[:2] + (3,)) * skin
        c = c * (1 - a[..., 3:4]) + np.array([0.94, 0.6, 0.55]) * a[..., 3:4]
        wht = a[..., 2:3] * (1 - a[..., 1:2])
        c = c * (1 - wht) + wht
        c = c * (1 - a[..., 1:2]) + np.array([0.18, 0.12, 0.1]) * a[..., 1:2]
        hl = a[..., 2:3] * a[..., 1:2]
        c = c * (1 - hl) + hl
        c = c * (1 - a[..., 0:1]) + np.array([0.29, 0.23, 0.19]) * a[..., 0:1]
        Image.fromarray((c * 255).astype("uint8")).resize((1024, 1024), Image.NEAREST).save(prev)


if __name__ == "__main__":
    main()
