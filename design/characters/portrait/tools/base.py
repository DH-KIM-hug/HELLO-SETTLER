"""Skin base layers drawn straight from the canonical guide (so they register exactly):
skin_head (adult), skin_head_child (rounder, shorter chin), skin_body (neck + shoulders).
Neutral grey fill 0.6 + one shade step (light from upper-left), dark-brown outline like the sheets.
usage: base.py <out_dir>"""
import sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
import geom

SS = 4
N = geom.CELL * SS
INK = np.array([74, 46, 31], float)
FILL = 153
SHADE = 118
OUT_PX = 256


def shape(draw_fn):
    im = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(im)
    draw_fn(d)
    return np.asarray(im) > 127


def scaled(pts):
    return [(x * SS, y * SS) for x, y in pts]


def render(parts, out):
    """parts: list of (mask, shade_mask_or_None, extra_lines_mask) drawn back to front."""
    rgb = np.zeros((N, N, 3), float)
    a = np.zeros((N, N), float)
    lw = 4 * SS
    for m, sh, lines in parts:
        inner = ndi.binary_erosion(m, iterations=lw)
        col = np.full((N, N, 3), FILL, float)
        if sh is not None:
            col[sh] = SHADE
        col[m & ~inner] = INK
        if lines is not None:
            col[lines & inner] = INK
        rgb[m] = col[m]
        a[m] = 1
    im = Image.fromarray(np.dstack([rgb, a * 255]).astype(np.uint8), "RGBA")
    pm = np.asarray(im).astype(float)
    pm[..., :3] *= pm[..., 3:4] / 255
    small = np.asarray(Image.fromarray(pm.astype(np.uint8), "RGBA").resize((geom.CELL, geom.CELL), Image.LANCZOS)).astype(float)
    al = small[..., 3:4]
    small[..., :3] = np.where(al > 0, small[..., :3] * 255 / np.maximum(al, 1), 0)
    Image.fromarray(np.clip(small, 0, 255).astype(np.uint8), "RGBA").save(out)


def crescent(m, dx, dy):
    """cel shade: the part of m not covered by m shifted toward the light (upper-left)."""
    sh = np.roll(np.roll(m, dy * SS, 0), dx * SS, 1)
    return m & ~sh


def head_parts(chin, round_chin):
    def head_poly():
        import math
        pts = []
        n = 90
        cx, top, mid, hw = geom.CX, geom.HEAD_TOP, geom.HEAD_MID, geom.HALF_W
        for i in range(n + 1):
            a = math.pi + math.pi * i / n
            pts.append((cx + hw * math.cos(a), mid + (mid - top) * math.sin(a)))
        p = 3.0 if round_chin else 2.4     # child: fuller cheeks (never inside the adult outline, so hair fitted to it still meets the face)
        for i in range(1, n):
            a = math.pi * i / n
            c, s = math.cos(a), math.sin(a)
            x = math.copysign(abs(c) ** (2 / p), c)
            y = abs(s) ** (2 / (p + 0.2))
            pts.append((cx + hw * x, mid + (chin - mid) * y))
        return pts
    ears = []
    for s in (-1, 1):
        ex = geom.CX + s * geom.EAR_DX
        ear = shape(lambda d: d.ellipse(((ex - 18) * SS, (geom.EAR_Y - 26) * SS, (ex + 18) * SS, (geom.EAR_Y + 26) * SS), fill=255))
        inner = shape(lambda d: d.arc(((ex - 8) * SS, (geom.EAR_Y - 14) * SS, (ex + 8) * SS, (geom.EAR_Y + 14) * SS),
                                      90 - s * 80 + (0 if s > 0 else 0), 270 - s * 80, fill=255, width=3 * SS))
        ears.append((ear, crescent(ear, -8, -6), inner))
    head = shape(lambda d: d.polygon(scaled(head_poly()), fill=255))
    return ears + [(head, crescent(head, -22, -10), None)]


def body_parts():
    sh = shape(lambda d: d.polygon(scaled(geom.shoulders_poly()), fill=255))
    nk = geom.NECK
    neck = shape(lambda d: d.rectangle((nk[0] * SS, (nk[1] - 30) * SS, nk[2] * SS, (nk[3] + 10) * SS), fill=255))
    chin_shadow = shape(lambda d: d.ellipse(((geom.CX - 70) * SS, (geom.CHIN - 70) * SS, (geom.CX + 70) * SS, (geom.CHIN + 26) * SS), fill=255))
    return [(sh, crescent(sh, -30, -8), None), (neck, (neck & chin_shadow) | crescent(neck, -10, 0), None)]


if __name__ == "__main__":
    out = sys.argv[1]
    render(head_parts(geom.CHIN, False), out + "/skin_head.png")
    render(head_parts(geom.CHIN + 2, True), out + "/skin_head_child.png")
    render(body_parts(), out + "/skin_body.png")
