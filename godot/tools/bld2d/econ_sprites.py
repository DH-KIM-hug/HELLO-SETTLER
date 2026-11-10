"""Code-drawn 'visible economy' sprites for the 2D buildings (ROADMAP Q6 / E0-3): material piles in three fill levels, site
progress pegs, thought bubbles for stalled workplaces, work puffs / chips / sparkles. Same family as the painted building
pictures: dark-brown ink outline, warm wood / straw palette, chunky rounded shapes that still read at village zoom.
usage: python3 godot/tools/bld2d/econ_sprites.py [preview.png]
-> godot/art/bld2d/econ_atlas.png      every sprite in one atlas (one MultiMesh = one draw call, view/bld2d/bld_econ.gd)
-> godot/view/bld2d/bld_econ_pics.gd   generated table (world size, atlas rect, index)
No external images — everything is drawn here (PIL)."""
import math
import sys
from contextlib import contextmanager
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

T = Path(__file__).parent
G = T.parent.parent
ART = G / "art" / "bld2d"
OUT_GD = G / "view" / "bld2d" / "bld_econ_pics.gd"
PPU = 128          # atlas pixels per world unit (zoom step 4 = 132 device px per unit on the phone)
SS = 4             # supersample
ATLAS_W = 1024
PAD = 3
OUT = 0.017        # ink outline (world units)
GROUND = 0.1       # ground line above the sheet's bottom edge (room for the outline under a pile)

INK = "#3a2a22"
WOOD_L, WOOD, WOOD_D = "#dba562", "#bd7f42", "#93602f"
BARK, BARK_D = "#a66a3a", "#84502a"
GRAIN, GRAIN_D = "#f4dba6", "#d5a868"
PLANK_L, PLANK, PLANK_D = "#f1c988", "#dfa95c", "#bd8440"
STONE_L, STONE, STONE_D = "#d8d3c8", "#b5afa4", "#928c83"
GOLD_L, GOLD, GOLD_D = "#fbe08a", "#f2c44a", "#d79c2c"
STRAW, STRAW_D = "#ecd184", "#cfa955"
LEAF_L, LEAF, LEAF_D = "#b9d977", "#93c153", "#6c9a3b"
SACK_L, SACK, SACK_D = "#fff5dc", "#f5e3ba", "#dcc08c"
CRUST_L, CRUST, CRUST_D = "#f8cf88", "#e9a24c", "#c67a2f"
WATER_L, WATER, WATER_D = "#d3f1f8", "#8fd3e8", "#5aa9c9"
SALT_L, SALT, SALT_D = "#ffffff", "#f1f4f4", "#cdd8de"
CAP_L, CAP, CAP_D = "#f39a78", "#e2674a", "#bb4a33"
DRY_L, DRY, DRY_D = "#d6a878", "#b9824f", "#935f35"
BUB, BUB_D = "#fffaea", "#ecdfc0"
CLOTH, CLOTH_D = "#f0b7a0", "#d98f78"


def rgb(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


class Cv:
    """One sprite canvas. Coordinates are world units: x centred (-w/2..w/2), y up from the ground line (0..h)."""

    def __init__(self, w=2.2, h=1.5):          # generous sheet; done() crops to the painted box (x stays centred)
        self.w, self.h = w, h
        self.W, self.H = round(w * PPU) * SS, round(h * PPU) * SS
        self.img = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
        self.layer = None
        self.d = None
        self.tf = [(0.0, 0.0, 1.0)]

    # transform stack: origin + scale (so a pile can be redrawn small inside a bubble)
    @contextmanager
    def at(self, ox, oy, s=1.0):
        px, py, ps = self.tf[-1]
        self.tf.append((px + ox * ps, py + oy * ps, ps * s))
        yield
        self.tf.pop()

    def P(self, x, y):
        ox, oy, s = self.tf[-1]
        return ((ox + x * s + self.w / 2) * PPU * SS, self.H - (GROUND + oy + y * s) * PPU * SS)

    def S(self, v):
        return v * self.tf[-1][2] * PPU * SS

    @contextmanager
    def part(self, ow=OUT):
        """Everything drawn inside becomes one inked shape (outline around the union), composited over what is there."""
        self.layer = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.layer)
        yield
        if ow > 0:
            r = max(1.0, ow * self.tf[-1][2] * PPU * SS)
            a = self.layer.getchannel("A").filter(ImageFilter.GaussianBlur(r * 0.75)).point(lambda v: 255 if v > 26 else 0)
            a = a.filter(ImageFilter.GaussianBlur(SS * 0.35))
            ink = Image.new("RGBA", (self.W, self.H), rgb(INK))
            ink.putalpha(a)
            self.img.alpha_composite(ink)
        self.img.alpha_composite(self.layer)
        self.layer = None
        self.d = None

    @contextmanager
    def inside(self):
        """Shading: drawn only where the current part already has paint."""
        base = self.layer
        mask = base.getchannel("A").copy()
        self.layer = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.layer)
        yield
        a = np.minimum(np.asarray(self.layer.getchannel("A")), np.asarray(mask))
        self.layer.putalpha(Image.fromarray(a))
        base.alpha_composite(self.layer)
        self.layer = base
        self.d = ImageDraw.Draw(self.layer)

    # ── primitives ──
    def ell(self, cx, cy, rx, ry, fill, rot=0.0):
        pts = []
        cr, sr = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        for i in range(40):
            a = i / 40 * math.tau
            x, y = math.cos(a) * rx, math.sin(a) * ry
            pts.append(self.P(cx + x * cr - y * sr, cy + x * sr + y * cr))
        self.d.polygon(pts, fill=rgb(fill))

    def poly(self, pts, fill):
        self.d.polygon([self.P(x, y) for x, y in pts], fill=rgb(fill))

    def rpoly(self, pts, fill, r):
        """Polygon with rounded corners (radius r)."""
        m = Image.new("L", (self.W, self.H), 0)
        ImageDraw.Draw(m).polygon([self.P(x, y) for x, y in pts], fill=255)
        rr = max(1.0, self.S(r))
        m = m.filter(ImageFilter.GaussianBlur(rr * 0.6)).point(lambda v: 255 if v > 127 else 0).filter(ImageFilter.GaussianBlur(SS * 0.3))
        col = Image.new("RGBA", (self.W, self.H), rgb(fill))
        col.putalpha(m)
        self.layer.alpha_composite(col)

    def rrect(self, cx, cy, w, h, r, fill, rot=0.0):
        cr, sr = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        pts = [(cx + x * cr - y * sr, cy + x * sr + y * cr) for x, y in [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]]
        self.rpoly(pts, fill, r)

    def line(self, pts, col, wd):
        p = [self.P(x, y) for x, y in pts]
        w = max(1, round(self.S(wd)))
        self.d.line(p, fill=rgb(col), width=w, joint="curve")
        for x, y in (p[0], p[-1]):
            self.d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=rgb(col))

    def arc(self, cx, cy, rx, ry, a0, a1, col, wd, n=14):
        self.line([(cx + math.cos(math.radians(a0 + (a1 - a0) * i / n)) * rx, cy + math.sin(math.radians(a0 + (a1 - a0) * i / n)) * ry)
                   for i in range(n + 1)], col, wd)

    def done(self):
        img = self.img.resize((self.W // SS, self.H // SS), Image.LANCZOS)
        a = np.asarray(img).astype(np.float32)
        al = a[..., 3:4] / 255.0
        ink = np.array(rgb(INK)[:3], np.float32)
        c = np.where(al > 0.02, a[..., :3], ink)          # transparent texels carry ink so mip / linear bleed stays an outline
        out = np.dstack([c, a[..., 3]]).clip(0, 255).astype(np.uint8)
        ys, xs = np.nonzero(out[..., 3] >= 96)
        mid = out.shape[1] // 2
        half = max(mid - xs.min(), xs.max() + 1 - mid) + 1
        top, bot = max(0, ys.min() - 1), min(out.shape[0], ys.max() + 2)
        return Image.fromarray(out[top:bot, mid - half:mid + half], "RGBA")


# ───────────────────────── goods ─────────────────────────
def log(c, x, y, ln=0.42, r=0.088, tilt=0.0):
    """A chunky log lying on its side, cut face toward the viewer on the left."""
    with c.part():
        c.rrect(x + 0.02, y, ln, r * 2, r * 0.95, BARK, tilt)
        with c.inside():
            c.rrect(x + 0.02, y - r * 0.75, ln, r * 0.8, r * 0.3, BARK_D, tilt)
            c.line([(x - ln * 0.1, y + r * 0.35), (x + ln * 0.22, y + r * 0.35)], BARK_D, 0.014)
            c.line([(x + ln * 0.12, y - r * 0.1), (x + ln * 0.36, y - r * 0.1)], BARK_D, 0.014)
    cr = math.cos(math.radians(tilt))
    sr = math.sin(math.radians(tilt))
    ex, ey = x + 0.02 - (ln / 2 - r * 0.55) * cr, y - (ln / 2 - r * 0.55) * sr
    with c.part(OUT * 0.8):
        c.ell(ex, ey, r * 0.62, r * 0.93, GRAIN, tilt)
        with c.inside():
            c.ell(ex + r * 0.1, ey - r * 0.15, r * 0.62, r * 0.93, GRAIN_D, tilt)
            c.ell(ex, ey, r * 0.5, r * 0.78, GRAIN, tilt)
            c.ell(ex, ey, r * 0.22, r * 0.36, GRAIN_D, tilt)
            c.ell(ex, ey, r * 0.1, r * 0.17, GRAIN, tilt)


def logs(c, lv):
    if lv == 1:
        log(c, 0.0, 0.1, tilt=-4)
    elif lv == 2:
        log(c, -0.19, 0.095)
        log(c, 0.21, 0.095)
        log(c, 0.02, 0.25, tilt=3)
    else:
        for x in (-0.36, 0.0, 0.36):
            log(c, x, 0.095, ln=0.4)
        for x in (-0.18, 0.18):
            log(c, x, 0.25, ln=0.4)
        log(c, 0.02, 0.405, ln=0.4, tilt=-3)


def plank(c, x, y, ln=0.6, th=0.07, tilt=0.0, shade=False):
    with c.part():
        c.rrect(x, y, ln, th, 0.014, PLANK_D if shade else PLANK, tilt)
        with c.inside():
            c.rrect(x, y + th * 0.3, ln, th * 0.42, 0.01, PLANK if shade else PLANK_L, tilt)
            cr, sr = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
            for k in (-0.25, 0.12):
                c.line([(x + ln * k * cr, y + ln * k * sr - th * 0.12), (x + ln * (k + 0.16) * cr, y + ln * (k + 0.16) * sr - th * 0.12)],
                       PLANK_D, 0.011)
            c.rrect(x - (ln / 2 - 0.03) * cr, y - (ln / 2 - 0.03) * sr, 0.06, th, 0.0, WOOD if not shade else WOOD_D, tilt)


def planks(c, lv):
    if lv == 1:
        plank(c, -0.02, 0.05, tilt=3)
        plank(c, 0.03, 0.125, tilt=-5)
    elif lv == 2:
        for i, (dx, t) in enumerate([(0.0, 0), (0.03, 2), (-0.03, -2), (0.02, 3)]):
            plank(c, dx, 0.05 + i * 0.078, tilt=t, shade=(i % 2 == 1))
    else:
        for i, (dx, t) in enumerate([(-0.02, 0), (0.03, 1), (-0.03, -1), (0.02, 2), (-0.01, -2), (0.03, 3)]):
            plank(c, dx, 0.05 + i * 0.078, ln=0.66, tilt=t, shade=(i % 2 == 1))
        with c.part(OUT * 0.7):          # straw tie
            c.rrect(0.17, 0.26, 0.05, 0.5, 0.012, LEAF)
            with c.inside():
                c.rrect(0.182, 0.26, 0.022, 0.5, 0.0, LEAF_D)


def stone(c, x, y, s=1.0, k=0):
    shapes = [[(-0.13, 0.0), (0.13, 0.0), (0.15, 0.1), (0.07, 0.19), (-0.08, 0.2), (-0.15, 0.09)],
              [(-0.12, 0.0), (0.12, 0.0), (0.14, 0.12), (0.03, 0.17), (-0.11, 0.15), (-0.15, 0.06)],
              [(-0.11, 0.0), (0.13, 0.0), (0.12, 0.13), (0.0, 0.21), (-0.13, 0.12)]]
    pts = [(x + px * s, y + py * s) for px, py in shapes[k % 3]]
    with c.part():
        c.rpoly(pts, STONE, 0.035 * s)
        with c.inside():
            c.ell(x + 0.03 * s, y + 0.0 * s, 0.2 * s, 0.085 * s, STONE_D)
            c.ell(x - 0.035 * s, y + 0.15 * s, 0.085 * s, 0.045 * s, STONE_L, 12)


def stones(c, lv):
    if lv == 1:
        stone(c, 0.0, 0.0, 1.05, 0)
    elif lv == 2:
        stone(c, -0.14, 0.0, 1.0, 1)
        stone(c, 0.15, 0.0, 0.95, 2)
        stone(c, 0.0, 0.13, 0.95, 0)
    else:
        stone(c, -0.28, 0.0, 1.0, 1)
        stone(c, 0.29, 0.0, 0.95, 0)
        stone(c, 0.0, 0.0, 1.05, 2)
        stone(c, -0.15, 0.15, 0.95, 0)
        stone(c, 0.14, 0.15, 0.95, 1)
        stone(c, 0.0, 0.31, 0.9, 2)


def sheaf(c, x, y, s=1.0, lean=0.0):
    """A wheat sheaf standing on its cut end: flared straw, a green tie, a fat fan of golden ears."""
    with c.at(x, y, s):
        t = math.tan(math.radians(lean))
        with c.part():
            c.rpoly([(-0.1, 0.0), (0.1, 0.0), (0.045 + t * 0.2, 0.2), (-0.045 + t * 0.2, 0.2)], STRAW, 0.02)
            with c.inside():
                c.rpoly([(0.02, 0.0), (0.1, 0.0), (0.045 + t * 0.2, 0.2), (0.015 + t * 0.2, 0.2)], STRAW_D, 0.01)
                for k in (-0.045, 0.0):
                    c.line([(k, 0.02), (k * 0.5 + t * 0.17, 0.17)], STRAW_D, 0.01)
        tx, ty = t * 0.2, 0.2
        with c.part():
            for i, a in enumerate((-48, 48, -24, 24, 0)):
                aa = a - lean
                dx, dy = math.sin(math.radians(aa)), math.cos(math.radians(aa))
                c.ell(tx + dx * 0.15, ty + dy * 0.15 + 0.02, 0.055, 0.125, GOLD_D if i < 2 else GOLD, -aa)
            with c.inside():
                for a in (-24, 24, 0):
                    aa = a - lean
                    dx, dy = math.sin(math.radians(aa)), math.cos(math.radians(aa))
                    c.ell(tx + dx * 0.17 - 0.012, ty + dy * 0.17 + 0.03, 0.02, 0.07, GOLD_L, -aa)
        with c.part(OUT * 0.7):
            c.rrect(tx, ty, 0.125, 0.05, 0.02, LEAF, -lean)


def wheat(c, lv):
    if lv == 1:
        sheaf(c, 0.0, 0.0, 1.1)
    elif lv == 2:
        sheaf(c, -0.15, 0.0, 1.05, -10)
        sheaf(c, 0.15, 0.0, 1.05, 10)
        sheaf(c, 0.0, 0.0, 1.12)
    else:
        sheaf(c, -0.12, 0.1, 1.0, -8)
        sheaf(c, 0.14, 0.1, 1.0, 8)
        sheaf(c, -0.3, 0.0, 1.05, -14)
        sheaf(c, 0.3, 0.0, 1.05, 14)
        sheaf(c, 0.0, 0.0, 1.15)


def sack(c, x, y, s=1.0, mark="wheat", lean=0.0):
    """A plump tied sack. mark: 'wheat' (flour — a little golden ear) or '' (plain)."""
    with c.at(x, y, s):
        with c.part():          # tied top ears
            c.ell(-0.05 + lean * 0.3, 0.33, 0.05, 0.035, SACK_D, 28)
            c.ell(0.05 + lean * 0.3, 0.33, 0.05, 0.035, SACK_D, -28)
        with c.part():
            c.rpoly([(-0.15, 0.0), (0.15, 0.0), (0.17, 0.12), (0.1 + lean * 0.25, 0.3), (-0.1 + lean * 0.25, 0.3), (-0.17, 0.12)], SACK, 0.07)
            with c.inside():
                c.ell(0.1, 0.03, 0.17, 0.11, SACK_D)
                c.ell(-0.06, 0.2, 0.06, 0.05, SACK_L, 20)
                if mark == "wheat":
                    for i, (dx, dy) in enumerate([(0.0, 0.2), (-0.028, 0.165), (0.028, 0.165), (-0.028, 0.125), (0.028, 0.125)]):
                        c.ell(dx + 0.01, dy - 0.04, 0.017, 0.026, GOLD_D, 0 if i == 0 else (28 if dx < 0 else -28))
                    c.line([(0.01, 0.05), (0.01, 0.12)], GOLD_D, 0.012)
        with c.part(OUT * 0.7):
            c.rrect(lean * 0.25, 0.292, 0.15, 0.04, 0.016, LEAF)


def flour(c, lv):
    if lv == 1:
        sack(c, 0.0, 0.0, 1.1)
    elif lv == 2:
        sack(c, -0.16, 0.0, 1.0, lean=-0.05)
        sack(c, 0.16, 0.0, 1.05, lean=0.05)
    else:
        sack(c, -0.29, 0.0, 1.0, lean=-0.05)
        sack(c, 0.29, 0.0, 1.0, lean=0.05)
        sack(c, 0.0, 0.0, 1.05)
        sack(c, -0.14, 0.24, 0.95, lean=-0.03)
        sack(c, 0.15, 0.24, 0.95, lean=0.04)


def loaf(c, x, y, s=1.0, rot=0.0):
    with c.at(x, y, s):
        with c.part():
            c.ell(0.0, 0.085, 0.15, 0.1, CRUST, rot)
            with c.inside():
                c.ell(0.03, 0.03, 0.16, 0.07, CRUST_D, rot)
                c.ell(-0.02, 0.115, 0.115, 0.055, CRUST_L, rot)
                for k in (-0.06, 0.0, 0.06):
                    c.line([(k - 0.022, 0.085), (k + 0.022, 0.14)], CRUST_D, 0.016)


def tray(c, w):
    with c.part():
        c.rrect(0.0, 0.035, w, 0.07, 0.03, WOOD)
        with c.inside():
            c.rrect(0.0, 0.055, w, 0.03, 0.0, WOOD_L)


def basket(c, x, y, s=1.0, w=0.4, h=0.2):
    """Woven basket body (open top) — the heap is drawn by the caller before / after."""
    with c.at(x, y, s):
        with c.part():
            c.rpoly([(-w / 2, h), (w / 2, h), (w * 0.42, 0.0), (-w * 0.42, 0.0)], WOOD, 0.04)
            with c.inside():
                c.rpoly([(0.02, h), (w / 2, h), (w * 0.42, 0.0), (0.06, 0.0)], BARK, 0.0)
                for yy in (0.055, 0.11):
                    c.line([(-w / 2, yy * h / 0.2), (w / 2, yy * h / 0.2)], WOOD_D, 0.012)
                for i in range(-3, 4):
                    c.line([(i * w / 7.5, 0.0), (i * w / 7.0, h)], WOOD_D, 0.009)
        with c.part(OUT * 0.8):
            c.rrect(0.0, h, w + 0.05, 0.05, 0.02, WOOD_L)


def bread(c, lv):
    if lv == 1:
        tray(c, 0.42)
        loaf(c, 0.0, 0.05, 1.1)
    elif lv == 2:
        tray(c, 0.62)
        loaf(c, -0.15, 0.05, 1.0, 6)
        loaf(c, 0.15, 0.05, 1.0, -6)
        loaf(c, 0.0, 0.17, 1.0)
    else:
        for (x, y, r) in [(-0.2, 0.2, 8), (0.2, 0.2, -8), (0.0, 0.25, 0)]:
            loaf(c, x, y, 0.95, r)
        loaf(c, -0.1, 0.36, 0.95, 5)
        loaf(c, 0.11, 0.36, 0.95, -6)
        loaf(c, 0.0, 0.48, 0.95)
        basket(c, 0.0, 0.0, 1.0, 0.66, 0.24)


def bucket(c, x, y, s=1.0):
    with c.at(x, y, s):
        with c.part(OUT * 0.8):          # rope handle
            c.arc(0.0, 0.25, 0.125, 0.16, 10, 170, STRAW_D, 0.026)
        with c.part():
            c.rpoly([(-0.15, 0.27), (0.15, 0.27), (0.115, 0.0), (-0.115, 0.0)], WOOD, 0.03)
            with c.inside():
                c.rpoly([(0.03, 0.27), (0.15, 0.27), (0.115, 0.0), (0.045, 0.0)], BARK, 0.0)
                for k in (-0.07, 0.0, 0.07):
                    c.line([(k * 1.2, 0.27), (k, 0.0)], WOOD_D, 0.009)
                c.rrect(0.0, 0.065, 0.3, 0.03, 0.0, WOOD_D)
                c.rrect(0.0, 0.195, 0.32, 0.03, 0.0, WOOD_D)
        with c.part(OUT * 0.8):
            c.ell(0.0, 0.272, 0.15, 0.052, WATER)
            with c.inside():
                c.ell(0.03, 0.255, 0.13, 0.04, WATER_D)
                c.ell(-0.05, 0.285, 0.05, 0.016, WATER_L)


def water(c, lv):
    if lv == 1:
        bucket(c, 0.0, 0.0, 1.05)
    elif lv == 2:
        bucket(c, -0.17, 0.0, 1.0)
        bucket(c, 0.17, 0.0, 1.05)
    else:
        bucket(c, -0.16, 0.12, 0.95)
        bucket(c, 0.17, 0.12, 0.95)
        bucket(c, -0.32, 0.0, 1.0)
        bucket(c, 0.32, 0.0, 1.0)
        bucket(c, 0.0, 0.0, 1.08)


def heap(c, x, y, w, h, cols, mat=True):
    lt, md, dk = cols
    with c.at(x, y):
        if mat:
            with c.part():
                c.ell(0.0, 0.035, w * 0.62, 0.05, LEAF)
                with c.inside():
                    c.ell(0.05, 0.02, w * 0.6, 0.04, LEAF_D)
        with c.part():
            c.rpoly([(-w / 2, 0.03), (w / 2, 0.03), (w * 0.2, h * 0.75), (0.0, h), (-w * 0.2, h * 0.75)], md, min(w, h) * 0.3)
            with c.inside():
                c.ell(w * 0.2, 0.05, w * 0.45, h * 0.35, dk)
                c.ell(-w * 0.1, h * 0.62, w * 0.14, h * 0.16, lt, 30)


def sparkle(c, x, y, r, col=GOLD_L):
    with c.part(OUT * 0.7):
        pts = []
        for i in range(8):
            a = i / 8 * math.tau + math.pi / 2
            rr = r if i % 2 == 0 else r * 0.36
            pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
        c.poly(pts, col)


def salt(c, lv):
    cols = (SALT_L, SALT, SALT_D)
    if lv == 1:
        heap(c, 0.0, 0.0, 0.32, 0.2, cols)
    elif lv == 2:
        heap(c, 0.0, 0.0, 0.48, 0.3, cols)
    else:
        heap(c, -0.2, 0.0, 0.36, 0.24, cols)
        heap(c, 0.14, 0.0, 0.56, 0.4, cols)
        sparkle(c, 0.3, 0.42, 0.05, SALT_L)


def cap(c, x, y, s=1.0, cols=(CAP_L, CAP, CAP_D), rot=0.0):
    lt, md, dk = cols
    with c.at(x, y, s):
        with c.part():
            c.rrect(0.0, 0.07, 0.085, 0.14, 0.03, SACK, rot * 0.5)
        with c.part():
            c.rpoly([(-0.16, 0.11), (0.16, 0.11), (0.1, 0.24), (0.0, 0.27), (-0.1, 0.24)], md, 0.06)
            with c.inside():
                c.ell(0.06, 0.1, 0.16, 0.05, dk)
                c.ell(-0.06, 0.2, 0.03, 0.022, SACK_L)
                c.ell(0.04, 0.215, 0.022, 0.017, SACK_L)
                c.ell(0.09, 0.165, 0.018, 0.014, SACK_L)


def mushrooms(c, lv, cols=(CAP_L, CAP, CAP_D)):
    if lv == 1:
        cap(c, 0.0, 0.0, 1.1, cols)
    elif lv == 2:
        cap(c, -0.15, 0.0, 1.0, cols)
        cap(c, 0.16, 0.0, 0.95, cols)
        cap(c, 0.0, 0.12, 1.0, cols)
    else:
        cap(c, -0.11, 0.24, 0.9, cols)
        cap(c, 0.12, 0.24, 0.9, cols)
        cap(c, -0.21, 0.12, 0.9, cols)
        cap(c, 0.21, 0.12, 0.9, cols)
        cap(c, 0.0, 0.14, 0.95, cols)
        basket(c, 0.0, 0.0, 1.0, 0.6, 0.2)


def goods(c, lv):
    """Anything without its own picture: a covered basket (herbs, fish, meat, porridge …)."""
    def one(x, y, s):
        with c.at(x, y, s):
            with c.part():
                c.ell(0.0, 0.2, 0.19, 0.11, CLOTH)
                with c.inside():
                    c.ell(0.06, 0.17, 0.17, 0.08, CLOTH_D)
                    c.ell(-0.06, 0.25, 0.05, 0.025, BUB)
            basket(c, 0.0, 0.0, 1.0, 0.4, 0.2)
    if lv == 1:
        one(0.0, 0.0, 1.05)
    elif lv == 2:
        one(-0.2, 0.0, 0.95)
        one(0.2, 0.0, 1.0)
    else:
        one(-0.01, 0.2, 0.9)
        one(-0.24, 0.0, 0.95)
        one(0.24, 0.0, 1.0)


# ───────────────────────── site ─────────────────────────
def peg(c, on):
    """Progress peg in front of a building site: bare stake → stake with a leaf flag once that share is built."""
    with c.part():
        c.ell(0.0, 0.02, 0.085, 0.03, "#b98b5e")
    with c.part():
        c.rpoly([(-0.035, 0.01), (0.035, 0.01), (0.04, 0.2), (-0.04, 0.2)], WOOD_L if on else "#cdb89a", 0.018)
        with c.inside():
            c.rrect(0.022, 0.1, 0.03, 0.2, 0.0, WOOD if on else "#b29c7e")
    if on:
        with c.part():
            c.rpoly([(0.03, 0.2), (0.2, 0.25), (0.035, 0.31)], LEAF, 0.02)
            with c.inside():
                c.rpoly([(0.03, 0.2), (0.2, 0.25), (0.05, 0.245)], LEAF_D, 0.0)
        with c.part(OUT * 0.8):
            c.ell(0.0, 0.215, 0.05, 0.03, GOLD)


# ───────────────────────── fx ─────────────────────────
def puff(c, r=0.15):
    with c.part(OUT * 0.8):
        c.ell(-r * 0.55, r * 0.75, r * 0.6, r * 0.55, "#ffffff")
        c.ell(r * 0.5, r * 0.8, r * 0.62, r * 0.58, "#ffffff")
        c.ell(0.0, r * 1.15, r * 0.7, r * 0.66, "#ffffff")
        with c.inside():
            c.ell(r * 0.25, r * 0.45, r * 1.0, r * 0.35, "#e2e0da")


def chip(c):
    """Wood chip — chunky and two-toned so it still reads as a chip (not a smudge) at the default village zoom."""
    with c.part(OUT * 1.15):
        c.rpoly([(-0.11, 0.03), (0.09, 0.015), (0.12, 0.105), (-0.07, 0.15)], PLANK_L, 0.022)
        with c.inside():
            c.rpoly([(-0.12, 0.02), (0.1, 0.0), (0.105, 0.05), (-0.1, 0.07)], PLANK, 0.0)


def pebble(c):
    """Stone chip flying off a quarried rock."""
    with c.part(OUT * 1.15):
        c.rpoly([(-0.1, 0.02), (0.09, 0.02), (0.11, 0.1), (0.02, 0.16), (-0.09, 0.12)], STONE, 0.028)
        with c.inside():
            c.ell(0.01, 0.02, 0.15, 0.05, STONE_D)
            c.ell(-0.02, 0.115, 0.05, 0.028, STONE_L, 12)


def leaf(c):
    with c.part(OUT * 0.8):
        c.rpoly([(-0.08, 0.06), (0.0, 0.1), (0.09, 0.06), (0.0, 0.02)], LEAF, 0.02)
        with c.inside():
            c.rpoly([(-0.08, 0.06), (0.09, 0.06), (0.0, 0.02)], LEAF_D, 0.0)


def drop(c):
    with c.part(OUT * 0.8):
        c.rpoly([(0.0, 0.16), (0.055, 0.06), (0.0, 0.015), (-0.055, 0.06)], WATER, 0.03)
        with c.inside():
            c.ell(-0.015, 0.07, 0.015, 0.022, WATER_L)


# ───────────────────────── bubbles ─────────────────────────
def bubble(c, icon):
    """Thought bubble (a stalled workplace thinks of what it lacks). icon(c) draws around (0, 0) in a ~0.5 box."""
    with c.part():
        c.ell(0.07, 0.035, 0.03, 0.026, BUB)
    with c.part():
        c.ell(0.02, 0.12, 0.052, 0.045, BUB)
    with c.part(OUT * 1.1):
        c.rrect(0.0, 0.53, 0.78, 0.62, 0.25, BUB)
        with c.inside():
            c.ell(0.1, 0.25, 0.45, 0.1, BUB_D)
    with c.at(0.0, 0.3):
        icon(c)


def icon_good(fn, s=0.82, dy=0.0):
    def f(c):
        with c.at(0.0, dy, s):
            fn(c, 1)
    return f


def icon_noworker(c):
    """A straw hat with nobody under it."""
    for i in range(10):          # dashed head
        a0 = i * 36 + 4
        c2 = (0.0, 0.14)
        with c.part(0):
            c.arc(c2[0], c2[1], 0.105, 0.105, a0, a0 + 20, "#b7a58c", 0.022, 4)
    with c.part():
        c.ell(0.0, 0.26, 0.22, 0.06, GOLD)
        with c.inside():
            c.ell(0.04, 0.245, 0.2, 0.045, GOLD_D)
    with c.part():
        c.rpoly([(-0.1, 0.27), (0.1, 0.27), (0.075, 0.4), (-0.075, 0.4)], GOLD, 0.045)
        with c.inside():
            c.rrect(0.0, 0.295, 0.22, 0.04, 0.0, LEAF)
            c.ell(-0.03, 0.365, 0.03, 0.02, GOLD_L)


GHOST = "#b7a58c"          # dashed "it is not there" line (same as the empty head under the straw hat)


def dashed(c, pts, wd=0.022, dash=0.045, gap=0.035, closed=False):
    """Dashed poly-line: the outline of something that is missing."""
    if closed:
        pts = list(pts) + [pts[0]]
    carry = 0.0
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        ln = math.hypot(x1 - x0, y1 - y0)
        if ln < 1e-6:
            continue
        t = carry
        while t < ln:
            a, b = t, min(t + dash, ln)
            with c.part(0):
                c.line([(x0 + (x1 - x0) * a / ln, y0 + (y1 - y0) * a / ln), (x0 + (x1 - x0) * b / ln, y0 + (y1 - y0) * b / ln)], GHOST, wd)
            t += dash + gap
        carry = t - ln


def ring(cx, cy, rx, ry, n=20, a0=0.0):
    return [(cx + math.cos(a0 + i / n * math.tau) * rx, cy + math.sin(a0 + i / n * math.tau) * ry) for i in range(n)]


def icon_no_tree(c):
    """Nothing left to cut in reach: a fresh stump, and the dashed outline of the big flower that stood on it."""
    dashed(c, [(0.0, 0.135), (0.0, 0.265)], wd=0.028, dash=0.05, gap=0.035)                         # stalk
    dashed(c, ring(0.0, 0.37, 0.125, 0.105, 24, 0.3), wd=0.028, dash=0.06, gap=0.036, closed=True)  # flower head
    with c.part(0):
        c.ell(0.0, 0.37, 0.034, 0.03, GHOST)
    with c.part():                                                               # stump
        c.rpoly([(-0.12, 0.0), (0.12, 0.0), (0.095, 0.1), (-0.095, 0.1)], BARK, 0.03)
        with c.inside():
            c.rrect(0.05, 0.04, 0.12, 0.12, 0.0, BARK_D)
    with c.part(OUT * 0.8):
        c.ell(0.0, 0.1, 0.095, 0.04, GRAIN)
        with c.inside():
            c.ell(0.0, 0.1, 0.05, 0.02, GRAIN_D)
            c.ell(0.0, 0.1, 0.022, 0.009, GRAIN)
    with c.at(0.17, 0.0, 0.62):                                                  # one chip left behind
        chip(c)


def icon_no_rock(c):
    """Nothing left to dig in reach: the dashed outline of a boulder, two crumbs where it was."""
    dashed(c, [(-0.2, 0.05), (-0.23, 0.2), (-0.12, 0.36), (0.07, 0.4), (0.21, 0.27), (0.22, 0.05)], wd=0.028, dash=0.06, gap=0.036, closed=True)
    dashed(c, [(-0.1, 0.28), (-0.02, 0.31)], wd=0.022, dash=0.03, gap=0.03)
    with c.at(-0.07, 0.0, 0.62):
        stone(c, 0.0, 0.0, 1.0, 1)
    with c.at(0.1, 0.0, 0.5):
        stone(c, 0.0, 0.0, 1.0, 2)


def icon_full(c):
    """A basket heaped over the brim, three little burst strokes above."""
    with c.at(0.0, 0.0, 0.8):
        with c.part():
            for x, y in [(-0.12, 0.2), (0.12, 0.2), (0.0, 0.27), (-0.07, 0.33), (0.08, 0.34)]:
                c.ell(x, y, 0.085, 0.07, CRUST)
            with c.inside():
                for x, y in [(-0.12, 0.2), (0.12, 0.2), (0.0, 0.27), (-0.07, 0.33), (0.08, 0.34)]:
                    c.ell(x - 0.02, y + 0.025, 0.04, 0.025, CRUST_L)
        basket(c, 0.0, 0.0, 1.0, 0.44, 0.2)
    for a in (-38, 0, 38):
        dx, dy = math.sin(math.radians(a)), math.cos(math.radians(a))
        with c.part(0):
            c.line([(dx * 0.3, 0.14 + dy * 0.22), (dx * 0.36, 0.14 + dy * 0.28)], "#e2674a", 0.03)


# name -> draw(c). Sizes come from what was painted (Cv.done crops).
def table():
    t = {}
    for nm, fn in [("logs", logs), ("planks", planks), ("stone", stones), ("wheat", wheat), ("flour", flour), ("bread", bread),
                   ("water", water), ("salt", salt), ("mushroom", mushrooms),
                   ("dried", lambda c, lv: mushrooms(c, lv, (DRY_L, DRY, DRY_D))), ("goods", goods)]:
        for lv in (1, 2, 3):
            t[f"{nm}_{lv}"] = (lambda c, fn=fn, lv=lv: fn(c, lv))
    t["peg_off"] = lambda c: peg(c, False)
    t["peg_on"] = lambda c: peg(c, True)
    t["puff"] = lambda c: puff(c, 0.16)
    t["chip"] = chip
    t["leaf"] = leaf
    t["drop"] = drop
    t["star"] = lambda c: sparkle(c, 0.0, 0.1, 0.075)
    t["pebble"] = pebble
    for nm, ic in [("want_logs", icon_good(logs, 0.9, 0.12)), ("want_wheat", icon_good(wheat, 0.82)),
                   ("want_flour", icon_good(flour, 0.9, 0.02)), ("want_goods", icon_good(goods, 0.9, 0.05)),
                   ("want_planks", icon_good(planks, 0.72, 0.12)), ("want_stone", icon_good(stones, 1.0, 0.08)),
                   ("noworker", icon_noworker), ("full", icon_full),
                   ("no_tree", icon_no_tree), ("no_rock", icon_no_rock)]:      # appended last: earlier indices stay put
        t["bub_" + nm] = (lambda c, ic=ic: bubble(c, ic))
    return t


IMPORT_PARAMS = {"mipmaps/generate": "true", "detect_3d/compress_to": "0", "compress/mode": "0"}


def import_settings(png: Path) -> None:
    imp = png.with_suffix(".png.import")
    if not imp.exists():
        imp.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n' +
                       "".join(f"{k}={v}\n" for k, v in IMPORT_PARAMS.items()))
        return
    out = []
    for ln in imp.read_text().splitlines():
        k = ln.split("=", 1)[0]
        out.append(f"{k}={IMPORT_PARAMS[k]}" if k in IMPORT_PARAMS else ln)
    imp.write_text("\n".join(out) + "\n")


def main() -> None:
    tb = table()
    imgs = {}
    for nm, fn in tb.items():
        c = Cv()
        fn(c)
        imgs[nm] = c.done()
    order = sorted(imgs, key=lambda n: -imgs[n].height)
    x = y = shelf = 0
    pos = {}
    for n in order:
        im = imgs[n]
        if x + im.width + PAD * 2 > ATLAS_W:
            x = 0
            y += shelf
            shelf = 0
        pos[n] = (x + PAD, y + PAD)
        x += im.width + PAD * 2
        shelf = max(shelf, im.height + PAD * 2)
    H = (y + shelf + 3) // 4 * 4
    atlas = np.zeros((H, ATLAS_W, 4), np.uint8)
    atlas[..., :3] = np.array(rgb(INK)[:3], np.uint8)
    for n, (px, py) in pos.items():
        a = np.asarray(imgs[n])
        atlas[py:py + a.shape[0], px:px + a.shape[1]] = a
    ART.mkdir(parents=True, exist_ok=True)
    png = ART / "econ_atlas.png"
    Image.fromarray(atlas, "RGBA").save(png, optimize=True)
    import_settings(png)
    L = ["## GENERATED by godot/tools/bld2d/econ_sprites.py — do not edit by hand (tune the script, re-run it).",
         "## 보이는 살림 그림 (ROADMAP Q6): 더미 세 단계 · 짓는 터 말뚝 · 막힌 일터 생각 풍선 · 일하는 김/부스러기. BldEcon(view/bld2d/bld_econ.gd)이 읽음.",
         "extends RefCounted", "",
         "const ATLAS := \"res://art/bld2d/econ_atlas.png\"",
         f"const ATLAS_SIZE := Vector2i({ATLAS_W}, {H})",
         "## name -> {w, h (world units on screen), uv (atlas rect), i (index)}",
         "const PICS := {"]
    for i, n in enumerate(tb):
        px, py = pos[n]
        im = imgs[n]
        L.append(f"\t\"{n}\": {{\"w\": {im.width / PPU:.3f}, \"h\": {im.height / PPU:.3f}, "
                 f"\"uv\": Rect2({px / ATLAS_W:.6f}, {py / H:.6f}, {im.width / ATLAS_W:.6f}, {im.height / H:.6f}), \"i\": {i}}},")
    L.append("}")
    OUT_GD.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"{len(tb)} sprites -> {png} {ATLAS_W}x{H}")
    if len(sys.argv) > 1:          # preview sheet on grass (2x, sprite box outlined) for a quick look
        cw, ch, per = 330, 200, 6
        names = list(tb)
        sheet = Image.new("RGBA", (cw * per, ch * ((len(names) + per - 1) // per)), (169, 214, 142, 255))
        dr = ImageDraw.Draw(sheet)
        for j, n in enumerate(names):
            im = imgs[n]
            a = np.asarray(im).copy()
            a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
            im2 = Image.fromarray(a, "RGBA").resize((im.width * 2, im.height * 2), Image.NEAREST)
            ox, oy = (j % per) * cw + (cw - im2.width) // 2, (j // per) * ch + (ch - 16 - im2.height) // 2
            dr.rectangle([ox - 1, oy - 1, ox + im2.width, oy + im2.height], outline=(120, 170, 100, 255))
            sheet.alpha_composite(im2, (ox, oy))
            dr.text(((j % per) * cw + 4, (j // per) * ch + ch - 14), n, fill=(58, 42, 34, 255))
        sheet.convert("RGB").save(sys.argv[1])


if __name__ == "__main__":
    main()
