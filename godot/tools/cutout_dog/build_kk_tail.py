"""꿀떡이 only: the feathery white tail plume (Q2-e second pass, 2026-11-10) — a small texture of its own, drawn here.

usage: python3 build_kk_tail.py [preview.png]
out: art/cutout/dog_a/kk_tail.png   R = fur brightness (1 = plain coat), G = ink (outline / feather strokes), A = cover
     art/cutout/dog_a/kk_tail.json  per cell: views that use it, uv, rect relative to the tail root (rig units)

The shared atlas / mask / dog_lib.json are not touched: the shader (proto/cutout_dog/dog_doll.gdshader) swaps the curl-tail
quad for one of these cells only for the one dog with the 꿀떡이 look (pat_c.w), in the three views that show the tail
(q_front, q_back, back). Same flat cutout style: one dark outline of the atlas' weight, flat fur, a soft shade on the inner
side. Nothing is copied from other frames or from outside pictures — the plume is a soft union of rounded shapes: a curled
spine with a few round, scalloped locks along its edges (soft lobes leaning toward the tip — fur, not spikes).
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "dog_a"))
PPU = 0.5            # texture px per rig unit — the atlas' resolution (dog_lib.json: 430 rig units ≈ 215 px)
SS = 8               # supersampling
LINE = 7.0           # outline weight (rig units) — the atlas' outline
STROKE = 2.4         # fur lines inside
SMOOTH = 4.0         # how softly a lock melts into the plume (rig units) — round scallops, no sharp notches
INNER = 0.945          # brightness of the inner tone
PAD = 8              # px around a cell (small mip levels must not mix the two pictures)


def catmull(pts, n):
    """n points along a Catmull-Rom curve through pts (ends doubled)"""
    p = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    segs = len(pts) - 1
    for i in range(n):
        u = i / (n - 1) * segs
        k = min(int(u), segs - 1)
        t = u - k
        p0, p1, p2, p3 = [np.array(p[k + j], float) for j in range(4)]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return np.array(out)


def lerp_table(tab, s):
    for (s0, v0), (s1, v1) in zip(tab, tab[1:]):
        if s <= s1:
            return v0 + (v1 - v0) * (s - s0) / max(s1 - s0, 1e-6)
    return tab[-1][1]


def cone(P, a, b, ra, rb):
    """signed distance to a rounded cone a→b (radius ra→rb)"""
    a = np.array(a, float)
    b = np.array(b, float)
    ab = b - a
    t = np.clip(((P[..., 0] - a[0]) * ab[0] + (P[..., 1] - a[1]) * ab[1]) / max(ab @ ab, 1e-6), 0.0, 1.0)
    dx = P[..., 0] - a[0] - ab[0] * t
    dy = P[..., 1] - a[1] - ab[1] * t
    return np.hypot(dx, dy) - (ra + (rb - ra) * t)


def rot(v, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return np.array([c * v[0] - s * v[1], s * v[0] + c * v[1]])


def plume(spine_pts, width, tufts, tip, rect, inner_sign, strokes_at):
    """rect = (x0, y0, x1, y1) rig units relative to the tail root. Returns RGBA uint8 (h, w, 4) at PPU.
    tufts (+ tip): round locks — (s along the spine, side +1 = left of travel / -1 = right / 0 = on the spine,
    bulge = how far the lock stands out of the plume's edge, radius, lean = how far it leans toward the tip)
    strokes_at: (s, offset across the spine -1..1, length) — short fur lines along the plume"""
    w = int(round((rect[2] - rect[0]) * PPU))
    h = int(round((rect[3] - rect[1]) * PPU))
    xs = rect[0] + (np.arange(w * SS) + 0.5) / (PPU * SS)
    ys = rect[3] - (np.arange(h * SS) + 0.5) / (PPU * SS)
    P = np.stack(np.meshgrid(xs, ys), axis=-1)
    sp = catmull(spine_pts, 64)
    n = len(sp)
    sd = np.full(P.shape[:2], 1e9)
    side = np.zeros(P.shape[:2])          # signed offset from the spine (+ = left of travel), at the nearest spine point
    along = np.zeros(P.shape[:2])         # how far along the spine (0..1) that nearest point is
    best = np.full(P.shape[:2], 1e9)
    for i in range(n - 1):
        s0, s1 = i / (n - 1), (i + 1) / (n - 1)
        r0, r1 = lerp_table(width, s0), lerp_table(width, s1)
        sd = np.minimum(sd, cone(P, sp[i], sp[i + 1], r0, r1))
        tan = sp[i + 1] - sp[i]
        tan = tan / max(np.hypot(*tan), 1e-6)
        mid = (sp[i] + sp[i + 1]) * 0.5
        dist = np.hypot(P[..., 0] - mid[0], P[..., 1] - mid[1])
        off = (-(P[..., 0] - mid[0]) * tan[1] + (P[..., 1] - mid[1]) * tan[0]) / max((r0 + r1) * 0.5, 1.0)
        closer = dist < best
        best = np.where(closer, dist, best)
        side = np.where(closer, off, side)
        along = np.where(closer, (s0 + s1) * 0.5, along)

    def frame(s):
        k = min(int(s * (n - 1)), n - 2)
        tan = sp[k + 1] - sp[k]
        tan = tan / max(np.hypot(*tan), 1e-6)
        return sp[k], tan, np.array([-tan[1], tan[0]]), lerp_table(width, s)

    for (s, sgn, bulge, rad, lean) in tufts + tip:
        o, tan, nor, r = frame(s)
        base = o + nor * sgn * (r + bulge - rad)
        lock = cone(P, base, base + tan * lean + nor * sgn * lean * 0.25, rad, rad * 0.78)
        hh = np.clip(0.5 + 0.5 * (lock - sd) / SMOOTH, 0.0, 1.0)
        sd = lock * (1.0 - hh) + sd * hh - SMOOTH * hh * (1.0 - hh)
    strokes = np.full(P.shape[:2], 1e9)
    for (s, across, length) in strokes_at:
        o, tan, nor, r = frame(s)
        a = o + nor * across * r
        d = rot(tan, 24.0 * (1.0 if across >= 0.0 else -1.0))
        strokes = np.minimum(strokes, cone(P, a, a + d * length, STROKE * 0.5, STROKE * 0.15))
    inside = sd < 0.0
    line = sd > -LINE
    stroke = (strokes < 0.0) & ~line
    # two flat tones like the atlas tail: the inner side of the curl a touch darker, with a wavy edge between
    wave = 0.5 + 0.1 * np.sin(along * math.pi * 2.0 * 5.5)
    shade = np.where(side * inner_sign > wave, INNER, 1.0)
    R = np.where(inside, shade, 1.0)
    G = np.where(inside, np.where(stroke, 0.45, line.astype(float)), 1.0)      # outside = ink, so the edge never bleeds light
    A = inside.astype(float)
    img = np.stack([R, G, np.zeros_like(R), A], axis=-1)
    img = img.reshape(h, SS, w, SS, 4).mean(axis=(1, 3))
    return (np.clip(img, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


# ── the two pictures (rig units, tail root = (0, 0), +y up, the dog faces image-right) ──
def locks(s0, s1, n, sgn, bulge, rad, lean):
    """n round locks evenly from s0 to s1 on one side — each a touch different so the edge is not a cog"""
    out = []
    for i in range(n):
        k = 1.0 + 0.1 * math.sin(i * 2.4 + 0.7)
        out.append((s0 + (s1 - s0) * i / max(n - 1, 1), sgn, bulge * k, rad * k, lean))
    return out


# side (q_front · q_back): up from the rump, a fat plume curled forward over the back, the tip hanging down
SIDE = dict(
    views=[1, 2],
    rect=(-130.0, -40.0, 100.0, 190.0),
    spine=[(4, -6), (-18, 16), (-36, 44), (-38, 76), (-22, 98), (2, 102), (18, 90), (22, 72)],
    width=[(0.0, 19.0), (0.2, 32.0), (0.5, 40.0), (0.8, 34.0), (1.0, 24.0)],
    tufts=locks(0.12, 0.88, 6, 1, 14.5, 25.0, 14.0) + locks(0.7, 0.9, 2, -1, 9.0, 17.0, 9.0),
    tip=[(0.99, 0, 0.0, 22.0, 10.0)],
    strokes=[(0.3, 0.45, 14), (0.5, 0.5, 15), (0.7, 0.45, 14), (0.45, 0.05, 12)],
    inner=-1.0,
)
# back: from behind — up from beside the tail-base spot, arcing over to one side of the rump, the tip hanging down
BACK = dict(
    views=[3],
    rect=(-80.0, -40.0, 170.0, 170.0),
    spine=[(20, 22), (22, 46), (34, 70), (56, 84), (80, 76), (92, 56)],
    width=[(0.0, 14.0), (0.25, 27.0), (0.55, 35.0), (0.85, 30.0), (1.0, 21.0)],
    tufts=locks(0.16, 0.88, 5, 1, 14.0, 23.0, 12.0) + locks(0.6, 0.88, 2, -1, 8.5, 16.0, 8.0),
    tip=[(0.99, 0, 0.0, 20.0, 9.0)],
    strokes=[(0.32, 0.4, 12), (0.55, 0.45, 13), (0.76, 0.4, 12), (0.5, 0.0, 11)],
    inner=-1.0,
)


def main():
    cells = []
    imgs = []
    rects = []
    for spec in (SIDE, BACK):
        im = plume(spec["spine"], spec["width"], spec["tufts"], spec["tip"], spec["rect"], spec["inner"], spec["strokes"])
        # trim to the picture (+2 px) — the rect in the json follows, so the plume stays where it was drawn
        ys, xs = np.nonzero(im[..., 3] > 0)
        x0, x1 = max(xs.min() - 2, 0), min(xs.max() + 3, im.shape[1])
        y0, y1 = max(ys.min() - 2, 0), min(ys.max() + 3, im.shape[0])
        r = spec["rect"]
        rects.append([r[0] + x0 / PPU, r[3] - y1 / PPU, r[0] + x1 / PPU, r[3] - y0 / PPU])
        imgs.append(im[y0:y1, x0:x1])
    W = sum(im.shape[1] for im in imgs) + PAD * (len(imgs) + 1)
    H = max(im.shape[0] for im in imgs) + PAD * 2
    W += (-W) % 4
    H += (-H) % 4
    sheet = np.zeros((H, W, 4), np.uint8)
    sheet[..., 0] = 255
    sheet[..., 1] = 255          # empty = ink colour under zero cover (no light fringe when filtered)
    x = PAD
    for spec, im, rect in zip((SIDE, BACK), imgs, rects):
        h, w = im.shape[:2]
        sheet[PAD:PAD + h, x:x + w] = im
        cells.append({"views": spec["views"], "rect": rect, "uv": [x / W, PAD / H, (x + w) / W, (PAD + h) / H]})
        x += w + PAD
    Image.fromarray(sheet, "RGBA").save(os.path.join(OUT, "kk_tail.png"))
    with open(os.path.join(OUT, "kk_tail.json"), "w", encoding="utf-8") as f:
        json.dump({"size": [W, H], "ppu": PPU, "line": LINE, "cells": cells}, f, indent=1)
        f.write("\n")
    print("kk_tail.png", (W, H), [c["uv"] for c in cells])
    if len(sys.argv) > 1:          # eyeball check (kept out of the repository): white fur + ink over grass, ×6
        a = sheet.astype(float) / 255.0
        fur = np.array([0.95, 0.93, 0.9])[None, None] * a[..., :1]
        col = fur * (1.0 - a[..., 1:2]) + np.array([0.22, 0.13, 0.08])[None, None] * a[..., 1:2]
        bg = np.array([0.66, 0.79, 0.54])[None, None]
        out = col * a[..., 3:4] + bg * (1.0 - a[..., 3:4])
        im = Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGB")
        im.resize((W * 6, H * 6), Image.BILINEAR).save(sys.argv[1])


if __name__ == "__main__":
    main()
