"""Small-world flora (GAME_DESIGN 3.0, ROADMAP E3-1): the giant flower / grass / moss forest the tiny residents live in,
fallen twigs (the wood resource - thin natural twigs and dry stalks, never sawn logs) and the little natural building
materials (big fallen leaf, acorn cap, seed-shell half, flat pebble).

Scale: 1 unit = 1 cell = one adult resident (resident.glb ~1.95 x Style.RESIDENT_SCALE 0.52 ~ 1.0 tall).
  grass 4-12, clover 2.5-5, flowers 8-32 (sunflower the biggest), moss mounds 1.5-3.
Output: godot/art/models/flora/<name>.glb  (Art.model("flora/<name>")), carried twigs -> carry/twig_bundle.glb.
Origin = base of the plant on the ground (wind sway pivots there; sway amount can grow with height).
Node (= mesh group) names say what a part is, so code can recolour or hide them:
  "stem"                 stems, stalks, twigs (crease lines + hull outline)
  "leaf_nl"              leaves / blades / fronds (hull outline, no crease lines)
  "petal_<colour>_nl"    petals of one colour (e.g. petal_pink_nl, petal_white_nl) -> per-colour season / variety swap
  "center_<colour>_nl"   flower centres, seed faces, stamens
Flowers face a little towards the camera (front = -Y here = Godot +Z) so their faces read from the 48 deg map camera.
Run: blender -b --factory-startup --python build_flora.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, PartSet, Vector, shade, mix, out_dir_from_argv  # noqa: E402
from flora_kit import V, bezier, tube, leaf, leaf_line, cup, pad, tri_count  # noqa: E402,F401

ROOT = out_dir_from_argv()
OUT = os.path.join(ROOT, "flora")

# ── colours (sRGB hex; soft storybook tones next to style.gd's mint/teal greens) ──
STEM = "6aa65a"
STEM_DARK = "4f8a4c"
LEAF = "5eae6a"
LEAF_LIGHT = "84c574"
LEAF_DARK = "3f8a62"
PETAL = {
    "yellow": "f4d64c", "gold": "f2b83a", "white": "f6f1e4", "cream": "f3e6c0", "pink": "f2a2b8", "rose": "e0607a",
    "magenta": "d2569a", "red": "d9473c", "crimson": "d23a48", "orange": "ef8a3a", "violet": "8c6cc8",
    "blue": "7f95dc", "sky": "8fb8ea", "lilac": "b49ce0", "rust": "c9673a", "silver": "e6e2d2",
}
CENTER = {"yellow": "f2c230", "dark": "5a4030", "brown": "7a5434", "green": "9cc65a", "black": "3b3038", "orange": "e88a2a"}
TWIG = "8a6a4c"
TWIG_DARK = "6b5240"
TWIG_DRY = "b39a72"
GRASS_TIE = "8fb45c"
FACE = V(0, -0.42, 1).normalized()        # flower faces tilt this way (towards the camera)

BUILT = []                               # (name, tris) for the summary


def pg(col):
    return "petal_%s_nl" % col


def cg(col):
    return "center_%s_nl" % col


def done(m):
    t = m.export(OUT)
    BUILT.append((m.name, t))


# ───────────── building blocks ─────────────
def stem(m, pts, r0, r1=None, seg=5, color=STEM, group="stem"):
    r1 = r0 * 0.7 if r1 is None else r1
    n = len(pts)
    return tube(m, pts, [r0 + (r1 - r0) * i / (n - 1) for i in range(n)], seg=seg, color=color, group=group)


def stem_curve(base, top, bend=(0, 0), n=4):
    base, top = Vector(base), Vector(top)
    h = top - base
    b = Vector((bend[0], bend[1], 0))
    return bezier(base, base + h * 0.35 + b * 0.5, base + h * 0.7 + b, top, n)


def strap(m, base, ang, ln, w, lift, droop, color=LEAF, n=4, teeth=False, up=V(0, 0, 1), group="leaf_nl", shape=None):
    d = V(math.cos(ang), math.sin(ang), 0)
    pts = leaf_line(Vector(base), d, ln, up, lift=lift, droop=droop, n=n)
    if shape is None:
        ws = [w * math.sin(math.pi * min(0.98, 0.12 + i / n * 0.95)) for i in range(n + 1)]
    else:
        ws = [w * s for s in shape]
    ws[-1] = 0.0
    if teeth:
        ws = [x * (1.0 if i % 2 == 0 else 0.55) for i, x in enumerate(ws)]
    nrm = [V(-d.y, d.x, 0).cross(pts[min(i + 1, n)] - pts[max(i - 1, 0)]).normalized() * -1 for i in range(n + 1)]
    nrm = [x if x.z > 0 else -x for x in nrm]
    return leaf(m, pts, ws, nrm, thick=max(0.04, w * 0.12), color=color, group=group)


def blade(m, base, ang, h, w, arch, color=LEAF, n=4, group="leaf_nl"):
    """Upright grass blade arching over (arch = horizontal reach at the tip)."""
    d = V(math.cos(ang), math.sin(ang), 0)
    base = Vector(base)
    pts = [base + d * arch * (i / n) ** 2 + V(0, 0, h * (1 - 0.35 * (i / n) ** 2) * (i / n)) for i in range(n + 1)]
    ws = [w * (1 - 0.85 * (i / n) ** 1.5) for i in range(n + 1)]
    ws[-1] = 0.0
    nrm = V(-d.y, d.x, 0)
    face = [(pts[min(i + 1, n)] - pts[max(i - 1, 0)]).cross(nrm).normalized() for i in range(n + 1)]
    return leaf(m, pts, ws, face, thick=w * 0.18, color=color, group=group)


def petal_ring(m, c, face, n, ln, w, cup_k, col, segs=2, phase=0.0, shape=None, thick=None, droop=0.0, grp=None,
               jitter=0.0):
    """Ring of petals round centre c, opening towards face. cup_k > 0 curls tips up (cup), droop < 0 bends back."""
    face = face.normalized()
    ref = V(1, 0, 0) if abs(face.x) < 0.9 else V(0, 1, 0)
    a0 = face.cross(ref).normalized()
    b0 = face.cross(a0)
    out = []
    for i in range(n):
        a = phase + i * math.tau / n + (jitter * math.sin(i * 7.3))
        d = a0 * math.cos(a) + b0 * math.sin(a)
        pts = []
        for j in range(segs + 1):
            t = j / segs
            pts.append(c + d * ln * t + face * ((cup_k - droop) * ln * t * t))
        if shape is None:
            ws = [w * 0.35, w, w * 0.55][:segs + 1] if segs == 2 else [w * (0.3 + 0.7 * math.sin(math.pi * min(0.95, 0.15 + j / segs * 0.8))) for j in range(segs + 1)]
        else:
            ws = [w * s for s in shape]
        nrm = [face.cross(d).cross(pts[min(j + 1, segs)] - pts[max(j - 1, 0)]).normalized() for j in range(segs + 1)]
        nrm = [x if x.dot(face) > 0 else -x for x in nrm]
        ccol = PETAL.get(col, col)
        out += leaf(m, pts, ws, nrm, thick=thick if thick else w * 0.14, color=ccol, color_under=shade(ccol, 0.86),
                    group=grp or pg(col))
    return out


def disc(m, c, face, r, h, col, seg=10, rings=3, lumps=0.0, grp=None, colfn=None):
    """Flower centre: a flattened dome facing `face`."""
    q = V(0, 0, 1).rotation_difference(face.normalized())
    fs = m.sphere(1.0, pos=(0, 0, 0), color=CENTER.get(col, PETAL.get(col, col)) if isinstance(col, str) else col, seg=seg, rings=rings, group=grp or cg(col),
                  lumps=lumps, seed=3)
    bm = m._bm(grp or cg(col))
    vs = {v: True for f in fs for v in f.verts}
    for v in vs:
        x, y, z = v.co
        v.co = c + q @ V(x * r, y * r, max(z, -0.3) * h)
    bm.normal_update()
    if colfn:
        for f in fs:
            m._finish(bm, [f], colfn(f), True)
    return fs


def heart_leaf(m, base, ang, ln, w, lift, color=LEAF, n=4):
    shape = [0.25, 0.95, 1.0, 0.7, 0.0][:n + 1]
    return strap(m, base, ang, ln, w, lift, lift * 0.25, color=color, n=n, shape=shape)


def toward(base, top, k):
    return Vector(base).lerp(Vector(top), k)


# ───────────── spring ─────────────
def build_dandelion():
    # a, b: open flowers on tall stems (one bent), bud, seed puff
    for name, h, bend, kind, seed in (("dandelion_a", 13.0, (0.6, -0.8), "flower", 1), ("dandelion_b", 15.5, (-1.6, -0.6), "flower", 2),
                                      ("dandelion_bud", 11.0, (0.8, 0.4), "bud", 3), ("dandelion_puff", 15.0, (1.0, -0.5), "puff", 4)):
        m = Model(name, seed)
        top = V(bend[0] * 1.2, bend[1] * 1.2, h)
        pts = stem_curve((0, 0, 0), top, bend, n=5)
        stem(m, pts, 0.28, 0.2, seg=6, color=mix(STEM, "a8c870", 0.25))
        for i in range(5):                                   # toothed rosette on the ground
            a = i * math.tau / 5 + 0.4 * seed
            strap(m, (0, 0, 0.05), a, 4.6 + 0.9 * ((i * 0.618 + seed) % 1), 0.75, 0.6, 0.3, color=LEAF if i % 2 else LEAF_DARK,
                  n=6, teeth=True)
        f = FACE
        if kind == "flower":
            disc(m, top, f, 1.0, 0.45, "green", seg=8, rings=3, grp="leaf_nl")            # green bracts cup
            c = top + f * 0.35
            petal_ring(m, c, f, 16, 2.5, 0.62, 0.15, "yellow", segs=1, shape=[0.6, 0.25])
            petal_ring(m, c + f * 0.25, f, 12, 1.8, 0.6, 0.4, "yellow", segs=1, shape=[0.6, 0.25], phase=0.3)
            disc(m, c + f * 0.4, f, 0.85, 0.5, "f0b72a", seg=8, rings=3, grp=cg("yellow"))
        elif kind == "bud":
            q = V(0, 0, 1)
            cup(m, top - V(0, 0, 0.1), q, [(0.35, 0), (0.75, 0.6), (0.7, 1.4), (0.35, 2.1), (0.05, 2.4)], seg=8,
                color=mix(STEM, LEAF_DARK, 0.4), group="leaf_nl")
            cup(m, top + V(0, 0, 1.9), q, [(0.36, 0), (0.12, 0.45), (0.02, 0.6)], seg=8, color=PETAL["yellow"], group=pg("yellow"))
        else:
            disc(m, top, f, 0.55, 0.4, "cream", seg=6, rings=3, grp=cg("cream"))
            m.ico(2.3, pos=top + V(0, 0, 1.9), color=PETAL["white"], subdiv=2, smooth=False, lumps=0.22, lump_scale=4.5,
                  seed=seed, group=pg("white"),
                  colfn=lambda fc: (shade(PETAL["silver"], 0.95) if int(fc.calc_center_median().length * 7) % 3 == 0
                                    else "fbf8f0") if fc.normal.z > -0.35 else shade(PETAL["silver"], 0.85))
        done(m)


def build_daisy():
    for name, h, n_heads, seed in (("daisy_a", 11.0, 1, 11), ("daisy_b", 13.0, 2, 12)):
        m = Model(name, seed)
        for k in range(n_heads):
            hh = h * (1.0 if k == 0 else 0.78)
            off = V(0, 0, 0) if k == 0 else V(1.6, 0.9, 0)
            top = off + V(0.5 - k, -0.6, hh)
            stem(m, stem_curve(off, top, (0.4 - k, -0.3), n=4), 0.2, 0.15, seg=5)
            strap(m, off + V(0, 0, 3.0), 0.8 + k * 2, 2.0, 0.45, 0.6, 0.2, n=3)
            c = top + FACE * 0.1
            petal_ring(m, c, FACE, 16, 2.1, 0.36, 0.0, "white", segs=2, phase=k * 0.2, thick=0.06)
            disc(m, c + FACE * 0.08, FACE, 0.8, 0.55, "yellow", seg=8, rings=4)
        for i in range(4):
            strap(m, (0, 0, 0.05), i * 1.6 + 0.3, 2.6, 0.7, 0.5, 0.25, n=3, color=LEAF if i % 2 else LEAF_LIGHT)
        done(m)


def build_tulip():
    for name, col, h, seed in (("tulip_red", "red", 15.0, 21), ("tulip_yellow", "yellow", 14.0, 22), ("tulip_pink", "pink", 16.0, 23)):
        m = Model(name, seed)
        top = V(0.3, -0.5, h)
        stem(m, stem_curve((0, 0, 0), top, (0.3, -0.2), n=4), 0.3, 0.24, seg=6)
        for i, (a, ln) in enumerate(((0.6, 7.0), (3.3, 6.0))):          # two broad leaves wrapping the stem
            strap(m, (0, 0, 0.2), a + seed, ln * 0.55, 1.5, ln * 0.9, ln * 0.25, color=mix(LEAF, "8fbfa0", 0.3), n=4)
        c = PETAL[col]
        # the cup: six petals = outer cup with three tips + inner cup offset by 60 deg
        cup(m, top, V(0, 0, 1), [(0.3, -0.2), (1.25, 0.6), (1.55, 1.8), (1.25, 3.0)], seg=12, color=c,
            inner=mix(shade(c, 0.9), "fff4d0", 0.25), tips=3, tip_h=0.7, group=pg(col))
        cup(m, top + V(0, 0, 0.1), V(0, 0, 1), [(0.25, -0.1), (1.05, 0.6), (1.3, 1.8), (1.0, 2.8)], seg=12,
            color=shade(c, 1.06), tips=3, tip_h=0.6, group=pg(col),
            wave=lambda a, j: 1.0 + 0.04 * math.cos(a * 3 + math.pi))
        done(m)


def build_violet():
    for name, col, seed in (("violet_a", "violet", 31), ("violet_b", "lilac", 32)):
        m = Model(name, seed)
        for i in range(5):                                   # heart-shaped basal leaves on short stalks
            a = i * math.tau / 5 + seed
            heart_leaf(m, V(math.cos(a), math.sin(a), 0) * 0.3 + V(0, 0, 0.2), a, 3.4, 1.5, 1.8,
                       color=LEAF if i % 2 else LEAF_DARK)
        for k, (h, off) in enumerate(((9.0, (0, 0)), (7.0, (1.2, 0.8)))):
            top = V(off[0] + 1.6, off[1] - 1.0, h)
            pts = bezier(V(off[0], off[1], 0), V(off[0], off[1], h * 0.6), V(off[0] + 0.8, off[1] - 0.3, h * 1.12), top, 5)
            stem(m, pts, 0.16, 0.12)
            f = V(0.4, -0.9, 0.35).normalized()                 # nodding face
            c = top + f * 0.2
            pc = PETAL[col]
            # 2 up, 2 side, 1 big lower lip
            for j, (ang, ln, w, cc) in enumerate(((1.25, 1.6, 0.75, pc), (1.9, 1.6, 0.75, pc), (0.2, 1.4, 0.6, pc),
                                                    (2.95, 1.4, 0.6, pc), (-1.57, 1.8, 0.9, shade(pc, 0.86)))):
                ref = V(0, 0, 1)
                a0 = f.cross(ref).normalized()
                b0 = f.cross(a0)
                d = a0 * math.cos(ang) + b0 * math.sin(ang)
                pts2 = [c + d * ln * t + f * 0.25 * t * t for t in (0, 0.5, 1)]
                leaf(m, pts2, [w * 0.3, w, w * 0.7], f, thick=0.1, color=cc, group=pg(col))
            disc(m, c + f * 0.15, f, 0.32, 0.3, "yellow", seg=6, rings=3)
        done(m)


def build_daffodil():
    for name, col, cup_col, seed in (("daffodil_a", "yellow", "orange", 41), ("daffodil_b", "cream", "yellow", 42)):
        m = Model(name, seed)
        for i in range(5):
            strap(m, (0.2 * math.cos(i), 0.2 * math.sin(i), 0), i * 1.25 + seed, 9.5, 0.55, 7.5, 3.0, n=5,
                  color=mix(LEAF, "8fbfa0", 0.35), shape=[0.8, 1, 1, 0.95, 0.8, 0])
        h = 14.0
        top = V(0.6, -0.4, h)
        pts = bezier(V(0, 0, 0), V(0, 0, h * 0.7), V(0.3, -0.1, h * 1.02), top, 5)
        stem(m, pts, 0.24, 0.2)
        f = V(0.15, -0.95, 0.15).normalized()               # facing sideways towards the camera
        c = top + f * 0.4
        petal_ring(m, c, f, 6, 2.2, 0.8, 0.08, col, segs=2, shape=[0.4, 1.0, 0.05], phase=0.5)
        cup(m, c, f, [(0.45, 0), (0.6, 0.8), (0.85, 1.6), (1.05, 1.8)], seg=12, color=PETAL[cup_col],
            inner=shade(PETAL[cup_col], 0.8), group=pg(cup_col), wave=lambda a, j: 1.0 + (0.08 * math.cos(a * 6) if j == 3 else 0))
        done(m)


def build_lily_valley():
    for name, seed in (("lily_valley_a", 51), ("lily_valley_b", 52)):
        m = Model(name, seed)
        for i, a in enumerate((0.4 + seed, 2.6 + seed)):        # two broad upright leaves
            pts = leaf_line(V(0, 0, 0), V(math.cos(a), math.sin(a), 0), 1.6, V(0, 0, 1), n=4)
            pts = [p + V(0, 0, 8.0 * k / 4) for k, p in enumerate(pts)]
            d = V(math.cos(a), math.sin(a), 0)
            leaf(m, pts, [0.5, 1.8, 2.0, 1.5, 0.0], [V(-d.y, d.x, 0).cross(V(0, 0, 1)) * -1] * 5,
                 thick=0.18, color=LEAF if i else LEAF_DARK)
        h = 10.0
        pts = bezier(V(0, 0, 0), V(0, 0, h * 0.8), V(1.4, -0.4, h * 1.1), V(3.4, -1.2, h * 0.9), 6)
        stem(m, pts, 0.14, 0.08)
        for k in range(5):                                   # bells hanging down along the arch
            t = 0.42 + k * 0.13
            i = min(5, int(t * 6))
            p = pts[i].lerp(pts[i + 1], t * 6 - i)
            s = 1.05 - 0.09 * k
            b = p - V(0.3 * (k % 2) - 0.15, 0.5 * (k % 2), 1.3)
            tube(m, [p, b + V(0, 0, 0.5)], 0.05, seg=4, color=STEM, group="stem")
            cup(m, b + V(0, 0, 0.5), V(0, 0, -1), [(0.15 * s, 0), (0.6 * s, 0.15), (0.75 * s, 0.6), (0.7 * s, 0.95), (0.85 * s, 1.1)],
                seg=8, color=PETAL["white"], inner=shade(PETAL["white"], 0.82), group=pg("white"),
                wave=lambda a, j: 1.0 + (0.12 * math.cos(a * 6) if j == 4 else 0.0))
        done(m)


def build_bluebell():
    for name, col, h, seed in (("bluebell_a", "blue", 18.0, 61), ("bluebell_b", "violet", 16.0, 62)):
        m = Model(name, seed)
        for i in range(4):
            strap(m, (0, 0, 0), i * 1.6 + seed, 8.0, 0.55, 3.0, 2.5, n=4, color=LEAF if i % 2 else LEAF_DARK)
        pts = bezier(V(0, 0, 0), V(0, 0, h * 0.85), V(1.2, -0.6, h * 1.08), V(4.5, -1.8, h * 0.82), 7)
        stem(m, pts, 0.22, 0.1)
        for k in range(6):
            i = 3 + (k % 5)
            p = pts[min(i, 7)].lerp(pts[min(i + 1, 7)], 0.4 if k < 5 else 0.9)
            s = 1.15 - 0.08 * k
            b = p - V(0.0, 0.25 * (k % 2), 1.0)
            tube(m, [p, b + V(0, 0, 0.6)], 0.06, seg=4, color=STEM, group="stem")
            # long bell with the tips curled back
            cup(m, b + V(0, 0, 0.6), V(0.1 * (k % 2 - 0.5), -0.15, -1), [(0.18 * s, 0), (0.55 * s, 0.4), (0.62 * s, 1.5), (0.95 * s, 2.0)],
                seg=8, color=PETAL[col], inner=shade(PETAL[col], 0.75), group=pg(col),
                wave=lambda a, j: 1.0 + (0.18 * math.cos(a * 6) if j == 3 else 0.0))
        done(m)


def build_clover():
    for name, flower, seed in (("clover_a", False, 71), ("clover_b", False, 72), ("clover_flower", True, 73)):
        m = Model(name, seed)
        rng = m.rng
        for i in range(5 if not flower else 4):
            a = rng.uniform(0, math.tau)
            d = rng.uniform(0.5, 2.4)
            base = V(math.cos(a) * d, math.sin(a) * d, 0)
            h = rng.uniform(2.4, 4.0)
            top = base + V(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), h)
            stem(m, stem_curve(base, top, (0.2, -0.2), n=3), 0.11, 0.09, seg=4, color=mix(STEM, "c8d890", 0.2))
            for k in range(3):                               # three heart leaflets = an umbrella
                b = a + k * math.tau / 3
                dd = V(math.cos(b), math.sin(b), 0)
                pts = [top + dd * 0.05, top + dd * 0.7 + V(0, 0, 0.15), top + dd * 1.35 + V(0, 0, 0.05)]
                col = mix("7cc173", "a8d88a", 0.25) if k == 0 else ("7cc173" if (i + k) % 2 else shade("7cc173", 0.88))
                leaf(m, pts, [0.12, 0.62, 0.38], V(0, 0, 1), thick=0.07, color=col, color_under=shade("7cc173", 0.7))
                # the pale chevron on each leaflet
                leaf(m, [p + V(0, 0, 0.09) for p in pts[:2]], [0.05, 0.3], V(0, 0, 1), thick=0.02,
                     color=mix("7cc173", "e8f0d0", 0.55))
        if flower:
            for k, (x, y, h) in enumerate(((0.3, -0.4, 5.2), (-1.0, 0.4, 4.6))):
                top = V(x + 0.3, y - 0.2, h)
                stem(m, stem_curve((x, y, 0), top, (0.3, -0.2), n=3), 0.13, 0.1, seg=4)
                m.ico(0.75, pos=top + V(0, 0, 0.55), scl=(1, 1, 1.1), color=PETAL["white"], subdiv=1, smooth=True,
                      lumps=0.2, lump_scale=3.0, seed=k + 1, group=pg("white"),
                      colfn=lambda fc: PETAL["white"] if fc.normal.z > -0.1 else mix(PETAL["white"], PETAL["pink"], 0.55))
        done(m)


# ───────────── summer ─────────────
def build_rose():
    for name, col, seed in (("rose_red", "crimson", 81), ("rose_pink", "rose", 82)):
        m = Model(name, seed)
        rng = m.rng
        # dense low wide bush of dark leaf cushions
        for (x, y, z, rx, rz) in ((0, 0, 5.5, 6.5, 4.0), (5.5, 1.5, 4.0, 4.5, 3.2), (-5.2, 1.0, 4.2, 4.6, 3.4),
                                  (1.5, -3.6, 4.6, 4.2, 3.0), (-2.0, 3.2, 7.5, 4.0, 2.8), (2.5, 2.6, 8.5, 3.6, 2.4)):
            pad(m, (x, y, z), rx, rx * 0.85, rz, mix(LEAF_DARK, "4d9a6a", 0.5), LEAF_DARK, shade(LEAF_DARK, 0.75), seg=10,
                rings=5, lumps=0.22, seed=int(x * 3 + y), flat=0.7)
        # thorny canes arching out of the bush
        for k in range(6):
            a = k * math.tau / 6 + 0.3
            d = V(math.cos(a), math.sin(a), 0)
            base = d * 2.0 + V(0, 0, 3.0)
            tip = d * (8.5 + rng.uniform(0, 2)) + V(0, 0, 6.0 + rng.uniform(0, 4))
            pts = bezier(base, base + V(0, 0, 5), tip + V(0, 0, 3), tip, 4)
            tube(m, pts, [0.35, 0.3, 0.25, 0.2, 0.14], seg=5, color="5f8a4a", group="stem")
            for j in range(1, 4):                                # thorns: little red-brown cones
                p = pts[j]
                tn = (pts[j + 1] - pts[j - 1]).normalized()
                for s in (1, -1):
                    side = tn.cross(V(0, 0, 1)).normalized() * s
                    if side.length < 0.1:
                        continue
                    dirn = (side + V(0, 0, 0.5) - tn * 0.4).normalized()
                    rot = dirn.to_track_quat("Z", "Y").to_euler()
                    m.cyl(0.18, 0.01, 0.75, pos=p + side * 0.15, rot=tuple(rot), color="a0583a", seg=3, group="stem")
        # roses: three nested wavy cups each
        spots = [(0, -3.0, 9.6), (4.5, -1.5, 7.6), (-4.2, -1.8, 7.8), (2.0, 2.0, 10.8), (-2.6, 2.6, 10.2), (6.6, 2.6, 6.8),
                 (-6.8, 2.0, 7.0)]
        for k, (x, y, z) in enumerate(spots):
            c = V(x, y, z)
            f = (V(0, -0.5, 1) + V(x, y, 0) * 0.04).normalized()
            pc = PETAL[col]
            for j, (r, hh, cc) in enumerate(((2.0, 0.9, shade(pc, 0.92)), (1.4, 1.2, pc), (0.8, 1.1, shade(pc, 1.12)))):
                cup(m, c + f * (0.15 * j), f, [(0.4 * r, 0), (r, hh * 0.5), (r * 0.95, hh)], seg=9, color=cc,
                    inner=shade(cc, 1.12), group=pg(col), wave=lambda a, jj, j=j: 1.0 + 0.12 * math.cos(a * 5 + j * 1.3))
            disc(m, c + f * 0.6, f, 0.35, 0.25, shade(pc, 0.7), seg=6, rings=3, grp=pg(col))
        done(m)


def build_sunflower():
    for name, h, seed in (("sunflower_a", 32.0, 91), ("sunflower_b", 27.0, 92)):
        m = Model(name, seed)
        top = V(0.4, -1.0, h)
        pts = stem_curve((0, 0, 0), top, (0.4, -0.6), n=6)
        stem(m, pts, 0.7, 0.5, seg=7, color=mix(STEM, "8faa5a", 0.3))
        for k, z in enumerate((0.25, 0.42, 0.58, 0.72)):         # big heart leaves up the stem
            p = pts[int(z * 6)]
            heart_leaf(m, p, k * 2.3 + seed, 5.5 - k * 0.7, 2.5 - k * 0.3, 1.2)
        f = V(0, -0.8, 0.6).normalized()
        c = top + f * 0.5
        disc(m, top, f, 2.6, 0.8, "green", seg=10, rings=3, grp="leaf_nl")            # green back
        petal_ring(m, c, f, 22, 4.6, 0.8, 0.0, "gold", segs=2, shape=[0.4, 1.0, 0.1], thick=0.1)
        petal_ring(m, c + f * 0.12, f, 20, 3.9, 0.75, 0.0, "yellow", segs=2, shape=[0.4, 1.0, 0.1], phase=0.15, thick=0.1)

        def seeds(fc):
            p = fc.calc_center_median() - c
            rr = (p - f * p.dot(f)).length
            ang = math.atan2(p.x, p.z)
            k = int(rr * 2.2 + ang * 2.0) % 2
            return CENTER["dark"] if rr < 2.1 else CENTER["brown"]
        disc(m, c + f * 0.3, f, 2.7, 0.55, "dark", seg=16, rings=5, grp=cg("dark"),
             colfn=lambda fc: (CENTER["brown"] if (int((fc.calc_center_median() - c).length * 2.4) % 2) else CENTER["dark"]))
        done(m)


def build_hydrangea():
    for name, col, alt, seed in (("hydrangea_blue", "sky", "blue", 101), ("hydrangea_pink", "pink", "lilac", 102)):
        m = Model(name, seed)
        for (x, y, z, rx) in ((0, 0, 4.5, 5.5), (4.5, 1.0, 3.8, 3.8), (-4.2, 1.5, 3.8, 3.8), (0.5, 3.5, 6.0, 3.5)):
            pad(m, (x, y, z), rx, rx * 0.8, 3.2, mix(LEAF, LEAF_LIGHT, 0.5), LEAF, LEAF_DARK, seg=10, rings=5, lumps=0.2,
                seed=int(x + 7), flat=0.6)
        for k, (x, y, z, r) in enumerate(((0, -1.8, 9.5, 3.0), (4.8, -0.4, 8.0, 2.4), (-4.6, 0.0, 8.2, 2.5),
                                          (1.0, 3.6, 11.0, 2.5), (-2.4, -3.8, 7.0, 2.0))):
            pa, pb = PETAL[col], PETAL[alt]

            def florets(fc, pa=pa, pb=pb, k=k):
                cc = fc.calc_center_median()
                n = math.sin(cc.x * 4.1 + k) * math.cos(cc.y * 3.7) + math.sin(cc.z * 4.5)
                base = mix(pa, pb, 0.5 + 0.45 * max(-1, min(1, n)))
                if int((cc.x + cc.y * 1.3 + cc.z * 0.7) * 3) % 4 == 0:
                    base = mix(base, "ffffff", 0.35)
                return base if fc.normal.z > -0.1 else shade(base, 0.85)
            m.ico(r, pos=(x, y, z), scl=(1, 1, 0.85), color=pa, subdiv=2, smooth=False, lumps=0.26, lump_scale=6.0,
                  seed=k + seed, group=pg(col), colfn=florets)
        done(m)


def build_morning_glory():
    for name, col, seed in (("morning_glory_a", "blue", 111), ("morning_glory_b", "magenta", 112)):
        m = Model(name, seed)
        # a dry grass stalk the vine climbs
        stalk = stem_curve((0, 0, 0), (0.8, 0.3, 20.0), (0.6, 0.2), n=5)
        stem(m, stalk, 0.35, 0.18, seg=5, color=TWIG_DRY)
        vine = []
        for i in range(25):
            t = i / 24
            p = stalk[0].lerp(stalk[-1], t * 0.92)
            a = t * math.tau * 3.2
            vine.append(p + V(math.cos(a) * 0.6, math.sin(a) * 0.6, 0))
        tube(m, vine, 0.12, seg=4, color=STEM, group="stem")
        for k in range(6):                                  # heart leaves on the vine
            p = vine[3 + k * 3]
            a = k * 2.4 + seed
            heart_leaf(m, p, a, 2.6, 1.3, 0.4, color=LEAF if k % 2 else LEAF_LIGHT, n=4)
        for k, (i, d) in enumerate(((8, V(-0.3, -1, 0.45)), (15, V(0.7, -1, 0.3)), (22, V(-0.8, -1, 0.7)))):
            p = vine[i]
            f = d.normalized()
            cup(m, p, f, [(0.12, 0), (0.25, 1.0), (0.9, 1.9), (1.9, 2.3), (2.2, 2.35)], seg=10, color=PETAL[col],
                inner=mix(PETAL[col], "ffffff", 0.35), group=pg(col),
                wave=lambda a, j: 1.0 + (0.07 * math.cos(a * 5) if j >= 3 else 0.0))
            disc(m, p + f * 1.6, f, 0.35, 0.2, "white", seg=6, rings=3, grp=pg("white"))
        done(m)


def build_poppy():
    for name, col, seed in (("poppy_red", "red", 121), ("poppy_orange", "orange", 122), ("poppy_white", "white", 123)):
        m = Model(name, seed)
        for i in range(4):
            strap(m, (0, 0, 0), i * 1.57 + seed, 3.8, 0.7, 0.8, 0.4, n=4, teeth=True, color=mix(LEAF, "9cc0a0", 0.4))
        h = 17.0
        top = V(1.5, -1.2, h)
        pts = bezier(V(0, 0, 0), V(-0.4, 0, h * 0.5), V(1.8, -0.4, h * 0.85), top, 6)
        stem(m, pts, 0.2, 0.16, color=mix(STEM, "9cc0a0", 0.4))
        f = V(0.1, -0.6, 1).normalized()
        pc = PETAL[col]
        # 4 big crinkled petals in two pairs = one wide wobbly bowl
        cup(m, top, f, [(0.3, 0), (2.2, 0.8), (3.1, 1.8), (3.0, 2.4)], seg=16, color=pc, inner=shade(pc, 0.82), group=pg(col),
            wave=lambda a, j: 1.0 + (0.18 * abs(math.cos(a * 2)) - 0.09 + 0.05 * math.sin(a * 9)) * (j / 3.0))
        disc(m, top + f * 0.5, f, 0.85, 0.55, "black", seg=8, rings=3)
        disc(m, top + f * 0.95, f, 0.5, 0.35, "green", seg=8, rings=3, grp=cg("green"))
        done(m)


def build_cosmos():
    for name, col, h, seed in (("cosmos_pink", "pink", 27.0, 131), ("cosmos_white", "white", 25.0, 132),
                               ("cosmos_magenta", "magenta", 29.0, 133)):
        m = Model(name, seed)
        top = V(1.4, -1.4, h)
        pts = stem_curve((0, 0, 0), top, (1.5, -0.8), n=7)
        stem(m, pts, 0.16, 0.1, seg=4)
        for k in range(5):                                  # feathery thread leaves
            p = pts[1 + k]
            a = k * 2.2 + seed
            for s in (-0.5, 0, 0.5):
                d = V(math.cos(a + s), math.sin(a + s), 0)
                tube(m, [p, p + d * 1.6 + V(0, 0, 0.8), p + d * 2.6 + V(0, 0, 0.6)], [0.07, 0.06, 0.02], seg=3, color=LEAF,
                     group="leaf_nl")
        # side stem with a bud
        b0 = pts[5]
        bud = b0 + V(-2.4, 0.5, 3.0)
        stem(m, [b0, b0 + V(-1.0, 0.2, 1.8), bud], 0.1, 0.08, seg=4)
        m.sphere(0.5, pos=bud + V(0, 0, 0.3), scl=(1, 1, 1.3), color=mix(PETAL[col], STEM, 0.5), seg=6, rings=4, group=pg(col))
        f = V(0, -0.55, 1).normalized()
        petal_ring(m, top, f, 8, 3.2, 0.95, 0.0, col, segs=2, shape=[0.3, 1.0, 0.85], jitter=0.06, thick=0.08)
        disc(m, top + f * 0.2, f, 0.7, 0.55, "yellow", seg=8, rings=3)
        done(m)


# ───────────── autumn ─────────────
def build_chrysanthemum():
    for name, col, seed in (("chrysanthemum_gold", "gold", 141), ("chrysanthemum_white", "white", 142),
                            ("chrysanthemum_rust", "rust", 143)):
        m = Model(name, seed)
        pad(m, (0, 0, 3.0), 4.5, 4.0, 3.0, LEAF_LIGHT, LEAF, LEAF_DARK, seg=10, rings=5, lumps=0.25, seed=seed, flat=0.7)
        for k, (x, y, h) in enumerate(((0, -1.2, 12.0), (2.6, 0.6, 10.5), (-2.4, 0.8, 10.8), (0.6, 2.4, 11.5), (-1.2, -3.0, 9.0))):
            top = V(x * 1.15, y * 1.15, h)
            stem(m, [V(x * 0.4, y * 0.4, 2), V(x * 0.8, y * 0.8, h * 0.6), top], 0.18, 0.14, seg=4)
            pc = PETAL[col]
            # pompom: a ball of short petals
            m.ico(1.5, pos=top + V(0, 0, 1.0), scl=(1, 1, 0.8), color=pc, subdiv=2, smooth=False, lumps=0.22, lump_scale=5.0,
                  seed=k + seed, group=pg(col),
                  colfn=lambda fc, pc=pc: shade(pc, 1.05) if fc.normal.z > 0.5 else (pc if fc.normal.z > -0.2 else shade(pc, 0.8)))
        done(m)


def build_silver_grass():
    for name, seed in (("silver_grass_a", 151), ("silver_grass_b", 152)):
        m = Model(name, seed)
        rng = m.rng
        for i in range(9):
            a = i * math.tau / 9 + rng.uniform(-0.3, 0.3)
            blade(m, V(math.cos(a), math.sin(a), 0) * 0.3, a, rng.uniform(6.5, 9.0), 0.32, rng.uniform(3.0, 5.0),
                  color=mix("8fb06a", "c8c890", 0.3 if i % 2 else 0.0))
        for k in range(3):                                   # plumes: stalk + drooping silver fingers
            a = k * 2.1 + seed
            h = rng.uniform(10.5, 13.0)
            top = V(math.cos(a) * 1.2, math.sin(a) * 1.2 - 0.6, h)
            pts = stem_curve((0, 0, 0), top, (math.cos(a) * 0.8, math.sin(a) * 0.8), n=4)
            stem(m, pts, 0.15, 0.1, seg=4, color="b8b07a")
            d0 = (pts[-1] - pts[-2]).normalized()
            hd = V(math.cos(a), math.sin(a), 0)               # the plume leans out to one side
            for j in range(9):
                b = (j - 4) * 0.28
                side = (hd * math.cos(b) + V(-hd.y, hd.x, 0) * math.sin(b)).normalized()
                p0 = top - V(0, 0, 0.35 * j)
                ln = 2.6 + 0.5 * math.sin(j * 1.7)
                pp = [p0, p0 + side * ln * 0.4 + V(0, 0, 0.5), p0 + side * ln * 0.8 - V(0, 0, 0.3), p0 + side * ln - V(0, 0, 1.6)]
                c1 = mix(PETAL["silver"], "d9b48f", 0.15 + 0.3 * (j % 3) / 2)
                leaf(m, pp, [0.12, 0.42, 0.36, 0.0], [V(0, 0, 1)] * 4, thick=0.16, color=c1, color_under=shade(c1, 0.85),
                     group=pg("silver"))
        done(m)


def build_foxtail():
    for name, seed in (("foxtail_a", 161), ("foxtail_b", 162)):
        m = Model(name, seed)
        rng = m.rng
        for i in range(6):
            a = i * math.tau / 6 + rng.uniform(-0.3, 0.3)
            blade(m, (0, 0, 0), a, rng.uniform(3.5, 5.0), 0.3, rng.uniform(1.5, 2.6), color=LEAF if i % 2 else LEAF_LIGHT)
        for k in range(3):
            a = k * 2.3 + seed
            h = rng.uniform(6.5, 8.0)
            top = V(math.cos(a) * 2.2, math.sin(a) * 2.2 - 0.6, h)
            pts = bezier(V(0, 0, 0), V(0, 0, h * 0.6), V(math.cos(a) * 1.0, math.sin(a) * 1.0, h * 1.05), top, 4)
            stem(m, pts, 0.12, 0.09, seg=4)
            # nodding fuzzy spike
            d = (top - pts[-2]).normalized()
            spike = [top + d * 0.45 * j - V(0, 0, 0.16 * j * j) for j in range(7)]
            tube(m, spike, 0.12, seg=4, color="9cae4a", group="stem")
            for j in range(1, 7):
                r = (0.42, 0.62, 0.7, 0.66, 0.55, 0.38)[j - 1]
                m.ico(r, pos=spike[j], scl=(1, 1, 1), color="c4cc62", subdiv=1, smooth=False, lumps=0.35, lump_scale=4.0,
                      seed=j + k * 7, group=pg("foxtail"),
                      colfn=lambda fc: "d2d474" if fc.normal.z > 0.2 else "a8b450")
        done(m)


# ───────────── always ─────────────
def build_grass():
    for name, seed, cols, n, hmax in (("grass_a", 171, (LEAF, LEAF_LIGHT), 7, 6.5), ("grass_b", 172, ("7fb565", "9ccc72"), 6, 5.0),
                                      ("grass_c", 173, ("6aa86a", "8fc07a"), 9, 8.0)):
        m = Model(name, seed)
        rng = m.rng
        for i in range(n):
            a = i * math.tau / n + rng.uniform(-0.4, 0.4)
            base = V(math.cos(a), math.sin(a), 0) * rng.uniform(0.1, 0.8)
            blade(m, base, a, rng.uniform(hmax * 0.55, hmax), rng.uniform(0.3, 0.42), rng.uniform(0.8, 2.8),
                  color=cols[i % 2])
        done(m)


def build_fern():
    for name, seed, n in (("fern_a", 181, 5), ("fern_b", 182, 4)):
        m = Model(name, seed)
        for i in range(n):
            a = i * math.tau / n + 0.3 + (0.2 if i % 2 else 0)
            ln = 8.5 + 1.5 * (i % 3)
            d = V(math.cos(a), math.sin(a), 0)
            side = V(-d.y, d.x, 0)
            K = 12
            pts, ws = [], []
            for k in range(K + 1):
                t = k / K
                pts.append(d * ln * t * 0.85 + V(0, 0, 0.1 + 7.5 * math.sin(math.pi * t * 0.75) - 1.5 * t * t))
                ws.append(1.4 * math.sin(math.pi * min(1.0, 0.08 + t * 1.0)) * (1.0 if k % 2 else 0.45) + 0.02)
            ws[-1] = 0.0
            col = mix("4fae74", "66c98a", 0.35 if i % 2 else 0.1)
            nrm = [(pts[min(k + 1, K)] - pts[max(k - 1, 0)]).cross(side).normalized() for k in range(K + 1)]
            nrm = [x if x.z > 0 else -x for x in nrm]
            leaf(m, pts, ws, nrm, thick=0.12, color=col, color_under=shade(col, 0.78))
        # a curled fiddlehead in the middle
        coil = [V(0.3, 0, 0)] + [V(0.3 + 0.6 * math.sin(t), 0, 3.5 + 0.6 * math.cos(t)) * 1.0 for t in (0, 1.2, 2.4, 3.6, 4.8)]
        coil = [V(0.3, 0, 0), V(0.3, 0, 2.0)] + [V(0.3 + 0.7 * math.sin(t), 0, 3.4 + 0.7 * math.cos(t)) for t in (0.6, 1.8, 3.0, 4.2)]
        tube(m, coil, [0.25, 0.25, 0.25, 0.25, 0.22, 0.18], seg=5, color="7cb86a", group="leaf_nl")
        done(m)


def build_moss():
    for name, seed, r, h, stalks in (("moss_a", 191, 3.0, 1.8, 5), ("moss_b", 192, 2.2, 1.3, 3), ("moss_c", 193, 4.2, 2.6, 7)):
        m = Model(name, seed)
        rng = m.rng
        pad(m, (0, 0, h * 0.45), r, r * 0.85, h, "8fc46c", "6fae6a", "4f8f62", seg=12, rings=6, lumps=0.25, seed=seed, flat=0.45)
        pad(m, (r * 0.55, -r * 0.3, h * 0.3), r * 0.5, r * 0.45, h * 0.6, "9ccc72", "77b46c", "4f8f62", seg=8, rings=4, lumps=0.3,
            seed=seed + 1, flat=0.4)
        for i in range(stalks):                              # spore stalks with little capsules
            a = rng.uniform(0, math.tau)
            d = rng.uniform(0, r * 0.6)
            base = V(math.cos(a) * d, math.sin(a) * d, h * 0.8)
            top = base + V(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(1.2, 2.2))
            tube(m, [base, top], [0.06, 0.04], seg=3, color="b0703a", group="stem")
            m.sphere(0.16, pos=top + V(0.05, 0, 0.1), scl=(1, 1, 1.5), rot=(0, 0.5, a), color="c88a40", seg=5, rings=3,
                     group="stem")
        done(m)


# ───────────── twigs (the wood resource — natural, thin, dry) ─────────────
def twig(m, base, d, ln, r, rng, forks=2, col=TWIG):
    """One natural twig: a slightly crooked tapering stick with a forked side shoot or two and a dry leaf bud."""
    d = d.normalized()
    perp = d.cross(V(0, 0, 1)).normalized()
    pts = []
    for i in range(5):
        t = i / 4
        k = 0.12 * ln * math.sin(t * 3.1 + rng.uniform(-0.4, 0.4))
        pts.append(base + d * ln * t + perp * k * 0.4 + V(0, 0, k * 0.15))
    tube(m, pts, [r, r * 0.9, r * 0.75, r * 0.5, r * 0.15], seg=5, color=col, group="stem", cap=shade(col, 0.9),
         colfn=lambda f: col if f.normal.z > -0.2 else shade(col, 0.82))
    for j in range(forks):
        t = 0.35 + 0.3 * j
        p = base + d * ln * t
        s = (d.cross(V(0, 0, 1)) * (1 if j % 2 else -1)).normalized()
        q = p + (d * 0.6 + s * 0.8).normalized() * ln * 0.3
        tube(m, [p, p.lerp(q, 0.5) + V(0, 0, 0.05), q], [r * 0.5, r * 0.35, r * 0.08], seg=4, color=col, group="stem")
    return pts


def build_twigs():
    for name, seed, n in (("twig_pile_a", 201, 8), ("twig_pile_b", 202, 5)):
        m = Model(name, seed)
        rng = m.rng
        for i in range(n):                                   # crossing heap of thin twigs and dry stalks
            a = rng.uniform(0, math.pi) + i * 0.7
            d = V(math.cos(a), math.sin(a), 0)
            ln = rng.uniform(3.5, 5.5)
            z = 0.2 + 0.32 * (i // 3)
            base = -d * ln * 0.5 + V(rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), z)
            if i % 3 == 2:                                  # dry hollow grass stalk with joints (straw colour)
                pts = [base + d * ln * t for t in (0, 0.33, 0.66, 1.0)]
                tube(m, pts, [0.1, 0.17, 0.17, 0.08], seg=6, color=TWIG_DRY, group="stem", cap=shade(TWIG_DRY, 0.8))
                for p in pts[1:3]:
                    m.cyl(0.21, 0.21, 0.12, pos=p - d * 0.06, rot=tuple(d.to_track_quat("Z", "Y").to_euler()),
                          color=shade(TWIG_DRY, 0.86), seg=5, group="stem")
            else:
                twig(m, base, d, ln, rng.uniform(0.14, 0.22), rng, forks=1 + i % 2, col=TWIG if i % 2 else TWIG_DARK)
        for k in range(3):                                  # a few dry leaves caught in the heap
            a = rng.uniform(0, math.tau)
            p = V(math.cos(a) * 1.2, math.sin(a) * 1.2, 0.5)
            leaf(m, [p, p + V(math.cos(a), math.sin(a), 0.1) * 0.7, p + V(math.cos(a), math.sin(a), 0.05) * 1.4],
                 [0.15, 0.45, 0.0], V(0, 0, 1), thick=0.05, color=("c9a05a", "b8783e", "d4b06a")[k], group="leaf_nl")
        done(m)


def build_twig_bundle():
    """Carried twig bundle (carry/twig_bundle.glb, Art.parts like build_carry.py): a handful of thin twigs and dry
    stalks tied with two twists of green grass. Resident-model units (resident ~1.95 before RESIDENT_SCALE),
    long axis = X so it rides on the shoulder like the old log."""
    m = Model("twig_bundle", 211)
    rng = m.rng
    L = 1.05
    for i in range(7):
        a = i * math.tau / 7
        off = V(0, math.cos(a), math.sin(a)) * (0.06 if i else 0.0)
        ln = L * rng.uniform(0.85, 1.05)
        x0 = -ln / 2 + rng.uniform(-0.05, 0.05)
        pts = [V(x0 + ln * t, off.y * (1 + 0.6 * abs(t - 0.5)), off.z * (1 + 0.6 * abs(t - 0.5)) + 0.01 * math.sin(t * 7 + i))
               for t in (0, 0.33, 0.66, 1.0)]
        col = TWIG_DRY if i % 3 == 2 else (TWIG if i % 2 else TWIG_DARK)
        tube(m, pts, [0.03, 0.028, 0.025, 0.018], seg=4, color=col, group="body", cap="d8c49a")
    # forked tips sticking out
    for s, x in ((1, 0.48), (-1, -0.42)):
        tube(m, [V(x, 0.03 * s, 0.05), V(x + 0.14 * s, 0.07 * s, 0.11)], [0.016, 0.01], seg=3, color=TWIG, group="body")
    for x in (-0.24, 0.24):                                   # grass ties
        m.cyl(0.115, 0.115, 0.06, pos=(x - 0.03, 0, 0), rot=(0, math.pi / 2, 0), color=GRASS_TIE, seg=7, group="body")
    m.blade((0.24, 0, 0.1), (0.33, -0.04, 0.2), 0.04, color=GRASS_TIE)
    blob = Model("twig_bundle_far")
    blob.sphere(1.0, pos=(0, 0, 0), scl=(0.52, 0.11, 0.11), color=TWIG, seg=6, rings=4)
    ps = PartSet("twig_bundle")
    ps.add("twig_bundle", m, pivot=(0, 0, 0))
    ps.add("twig_bundle_far", blob, pivot=(0, 0, 0))
    tris = ps.export(os.path.join(ROOT, "carry"))
    BUILT.append(("carry/twig_bundle", tris.get("twig_bundle", 0)))


# ───────────── natural building / container materials (GAME_DESIGN 3.0) ─────────────
def build_materials():
    # big fallen leaf: fresh green and dry brown, edges curling up (a roof sheet / a boat / a floor)
    for name, col, vein, seed in (("fallen_leaf_green", "6ab06a", "a8d890", 221), ("fallen_leaf_dry", "c08a48", "e0b878", 222)):
        m = Model(name, seed)
        n = 6
        ln = 6.5
        pts = [V(-ln / 2 + ln * i / n, 0, 0.15 + 0.5 * ((i / n) - 0.5) ** 2 * 4) for i in range(n + 1)]
        ws = [0.3, 1.3, 1.9, 2.0, 1.7, 1.1, 0.0]
        nrm = [V(0, 0, 1)] * (n + 1)
        # curled: two halves tilted up (V-shaped section) -> two leaves sharing the midrib
        for s in (1, -1):
            half = [p + V(0, s * w * 0.5, w * 0.28) for p, w in zip(pts, ws)]
            leaf(m, [p for p in half], [w * 0.52 for w in ws], [V(0, -s * 0.5, 1).normalized()] * (n + 1), thick=0.08,
                 color=col if s > 0 else shade(col, 0.93), color_under=shade(col, 0.75))
        tube(m, [V(-ln / 2 - 0.9, 0, 0.12)] + pts[:-1], [0.1] * (n + 1), seg=4, color=vein, group="stem")
        done(m)
    # acorn cap: a scaly cup (bowl / bucket / helmet) lying mouth up
    m = Model("acorn_cap", 231)
    cup(m, V(0, 0, 0.0), V(0, 0, 1), [(0.4, 0.0), (1.0, 0.25), (1.35, 0.8), (1.4, 1.2)], seg=14, color="9a7048",
        inner="c8a678", group="body", smooth=True,
        wave=lambda a, j: 1.0 + (0.05 * math.cos(a * 7 + j * 1.6) if j < 3 else 0.0))
    for j, (r, z) in enumerate(((0.9, 0.3), (1.25, 0.65), (1.38, 1.0))):      # scale rows
        for i in range(10 + 2 * j):
            a = i * math.tau / (10 + 2 * j) + j * 0.3
            m.sphere(0.2, pos=(math.cos(a) * r, math.sin(a) * r, z), scl=(1, 0.8, 0.55), rot=(0, 0.9, a), color=shade("9a7048", 0.85 + 0.1 * (i % 2)),
                     seg=4, rings=2, group="body_nl")
    tube(m, [V(0, 0, 0.05), V(0.15, 0, -0.25)], [0.15, 0.1], seg=4, color="7a5636", group="body")
    done(m)
    # seed-shell half: a boat-shaped split husk (cart body, boat, cradle)
    m = Model("seed_shell", 241)
    L, W, H = 3.2, 1.4, 0.9
    K, J = 8, 6
    outer, inner_r = [], []
    for k in range(K + 1):
        t = k / K
        x = -L / 2 + L * t
        w = W * math.sin(math.pi * t) ** 0.7 + 0.03
        ring_o, ring_i = [], []
        for j in range(J + 1):
            u = j / J
            a = math.pi * (1 - u)
            ring_o.append(V(x, math.cos(a) * w, H * 0.9 - math.sin(a) * H * math.sin(math.pi * t) ** 0.5))
            ring_i.append(V(x, math.cos(a) * w * 0.86, H * 0.9 - math.sin(a) * H * 0.8 * math.sin(math.pi * t) ** 0.5 + 0.08))
        outer.append(ring_o)
        inner_r.append(ring_i)
    fo = m.strip(outer, color="b58650", smooth=True, group="body")
    fi = m.strip(inner_r, color="ecdcb4", smooth=True, group="body")
    rim = m.strip([[r[0] for r in outer], [r[0] for r in inner_r]], color="d8bc88", group="body")
    rim2 = m.strip([[r[-1] for r in outer], [r[-1] for r in inner_r]], color="d8bc88", group="body")
    bm = m._bm("body")
    for f in fo:
        f.normal_update()
        if f.normal.z > 0.3 and f.calc_center_median().z > H * 0.5 or f.normal.dot(V(0, f.calc_center_median().y, -0.5)) < 0:
            f.normal_flip()
    for f in fi:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    for f in rim + rim2:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    for f in fo:                                             # long stripes on the husk
        c = f.calc_center_median()
        m._finish(bm, [f], shade("b58650", 0.88 if int((math.atan2(c.y, -c.z + H) + 2) * 4) % 2 else 1.0), True)
    bm.normal_update()
    done(m)
    # flat pebbles: stepping stones / floor tiles / wheel
    for name, col, seed, (rx, ry, h) in (("pebble_flat_a", "b8b4a8", 251, (1.4, 1.1, 0.45)), ("pebble_flat_b", "a8a49c", 252, (1.0, 0.85, 0.35))):
        m = Model(name, seed)
        m.ico(1.0, pos=(0, 0, h * 0.5), scl=(rx, ry, h), color=col, subdiv=2, smooth=True, lumps=0.08, seed=seed,
              colfn=lambda f, col=col: shade(col, 1.08) if f.normal.z > 0.8 else (col if f.normal.z > -0.3 else shade(col, 0.8)))
        done(m)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("flora ->", OUT)
    build_dandelion()
    build_daisy()
    build_tulip()
    build_violet()
    build_daffodil()
    build_lily_valley()
    build_bluebell()
    build_clover()
    build_rose()
    build_sunflower()
    build_hydrangea()
    build_morning_glory()
    build_poppy()
    build_cosmos()
    build_chrysanthemum()
    build_silver_grass()
    build_foxtail()
    build_grass()
    build_fern()
    build_moss()
    build_twigs()
    build_twig_bundle()
    build_materials()
    print("  flora: %d models, %d tris total" % (len(BUILT), sum(t for _, t in BUILT)))
