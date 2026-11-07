"""Buildings for every sim building type (godot/data/balance.gd Balance.B) + pier + bridge.
References: design/concept/5-1.png (buildings), style-test/flat2_map_a/b.png (thatched stone cottages, well, woodpile).
Run: blender -b --factory-startup --python build_buildings.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, srgb, out_dir_from_argv  # noqa: E402
import bmesh  # noqa: E402

OUT = out_dir_from_argv()
SACK = mix("THATCH", "PLASTER", 0.55)
SOOT = "6a625c"
STEP = mix("PATH", "STONE", 0.3)
SHUTTER = ("6f9a9a", "a8574a", "7d9a62", "5f7c96")


# ───────────────────────── shared parts ─────────────────────────
def thatch_roof(m, W, D, H, rise, ox=0.24, oy=0.17, thick=0.2, col="THATCH", under="THATCH_DARK", K=10, p=1.55,
                droop=0.05, end=0.2, end_drop=0.14, end_pinch=0.86, layers=(0.42, 0.74), step=0.07, strip=0.21,
                ridge=False, moss=0, straw=True, seed=0):
    """Thick, rounded gable roof (ridge along X). Eaves overhang ox / oy beyond walls W x D whose top is H.
    Layered thatch: the slope steps out at |s| = layers (each course overhangs the one below with a dark lip).
    The two end sections are pinched and dropped -> rounded 'loaf' ends like hand-drawn thatch.
    straw=True: the slope is cut into strips along the ridge (~strip wide) and each strip gets a slightly different
    shade -> texture-free straw streaks (vertex colour only). ridge=True: a rounded ridge roll on top.
    moss = number of soft moss cushions on the slopes (old roofs)."""
    import random as _r
    rnd = _r.Random(seed * 31 + int(W * 100))
    hy = D / 2 + oy

    def zb(s):
        return H - droop + (rise + droop) * (1 - abs(s) ** p) ** (1 / p)

    def off(s):          # outward offset of the course that contains s (ridge course is proudest)
        return step * sum(1 for b in layers if abs(s) < b)

    # outer profile front eave -> ridge -> back eave, with lip segments at course boundaries
    ss = sorted(set([-1 + 2 * i / K for i in range(K + 1)] + [x * b for b in layers for x in (-1, 1)]))
    outer = []
    for s in ss:
        is_b = any(abs(abs(s) - b) < 1e-6 for b in layers)
        if is_b:
            lo, hi = off(s * 1.0001), off(s * 0.9999)
            first, second = (lo, hi) if s < 0 else (hi, lo)
            outer.append((s, first))
            outer.append((s, second))
        else:
            outer.append((s, off(s)))
    pts = [(s * (hy + o * 0.6), zb(s) + o) for (s, o) in outer]
    kinds = ["l" if abs(outer[i][0] - outer[i + 1][0]) < 1e-9 else "s" for i in range(len(outer) - 1)]
    course = [off((outer[i][0] + outer[i + 1][0]) / 2) for i in range(len(outer) - 1)]

    def inner_pts(scale, dz):
        out = []
        for i in range(K + 1):
            s = -1 + 2 * i / K
            out.append(((s * (hy - thick * 0.55)) * scale, zb(s) - thick + dz))
        return out

    L = W + 2 * ox
    n_mid = max(1, int(round((L - 2 * end) / strip)))
    xs = [-L / 2] + [-L / 2 + end + (L - 2 * end) * k / n_mid for k in range(n_mid + 1)] + [L / 2]
    if not straw:
        xs = [-L / 2, -L / 2 + end, L / 2 - end, L / 2]

    def sec(j):
        e = j in (0, len(xs) - 1)
        return (end_pinch, -end_drop) if e else (1.0, 0.0)

    bm = m._bm("body")
    # outer shell: slope profile + the inner eave corners (front and back) -> the eave thickness faces
    rings = []
    for j, x in enumerate(xs):
        sc, dz = sec(j)
        inn = inner_pts(sc, dz)
        ring = [Vector((x, y * sc, z + dz)) for y, z in pts] + [Vector((x, inn[-1][0], inn[-1][1])),
                                                                 Vector((x, inn[0][0], inn[0][1]))]
        rings.append(ring)
    n = len(rings[0])
    n_out = len(pts) - 1
    vr = [[bm.verts.new(q) for q in r] for r in rings]
    faces = []
    tone = {}
    slope_f = set()
    shades = (1.0, 0.95, 1.05, 0.97, 1.02, 0.92)
    for j, (a, b) in enumerate(zip(vr[:-1], vr[1:])):
        streak = shades[rnd.randrange(len(shades))] if straw else 1.0
        for i in range(n):
            k = (i + 1) % n
            f = bm.faces.new((a[i], b[i], b[k], a[k]))
            faces.append(f)
            if i < n_out and kinds[i] == "s":
                lift = 1.0 + 0.06 * course[i] / max(step, 1e-6) - 0.03       # upper courses a touch lighter
                tone[f] = shade(col, streak * lift * (0.94 if j in (0, len(xs) - 2) else 1.0))
                slope_f.add(f)
            else:
                tone[f] = under
    caps = [bm.faces.new(list(reversed(vr[0]))), bm.faces.new(vr[-1])]
    # underside (few stations: it is only seen at the eaves)
    us = []
    for x, j in ((xs[0], 0), (xs[1], 1), (xs[-2], len(xs) - 2), (xs[-1], len(xs) - 1)):
        sc, dz = sec(j)
        us.append([Vector((x, y, z)) for y, z in inner_pts(sc, dz)])
    uv = [[bm.verts.new(q) for q in r] for r in us]
    under_f = []
    for a, b in zip(uv[:-1], uv[1:]):
        for i in range(K):
            under_f.append(bm.faces.new((a[i], a[i + 1], b[i + 1], b[i])))
    bmesh.ops.recalc_face_normals(bm, faces=faces + caps)
    for f in under_f:
        f.normal_update()
        if f.normal.z > 0:
            f.normal_flip()
    bm.normal_update()
    for f in faces:
        m._finish(bm, [f], tone[f], f in slope_f)
    m._finish(bm, caps, shade(col, 0.86), False)
    m._finish(bm, under_f, under, False)
    if ridge:
        zt = zb(0) + off(0)
        m.cyl(0.12, 0.12, L - 2 * end + 0.1, pos=(-(L - 2 * end + 0.1) / 2, 0, zt - 0.06), rot=(0, math.pi / 2, 0),
              color=shade(col, 0.82), seg=7, smooth=True, cap=shade(col, 0.7), bottom_cap=shade(col, 0.7))
        for k in range(4):       # binding bands round the roll
            x = -(L - 2 * end) / 2 + (k + 0.5) * (L - 2 * end) / 4
            m.cyl(0.128, 0.128, 0.05, pos=(x - 0.025, 0, zt - 0.06), rot=(0, math.pi / 2, 0), color=shade(col, 0.62),
                  seg=7, smooth=True)
    for k in range(moss):
        x = rnd.uniform(-L / 2 + 0.35, L / 2 - 0.35)
        s = rnd.uniform(-0.75, -0.2) * (1 if k % 2 == 0 else -1)
        y = s * hy
        z = zb(s) + off(s) + 0.01
        m.sphere(rnd.uniform(0.12, 0.17), pos=(x, y, z), scl=(1.6, 1.0, 0.3), color=mix("MOSS", "LEAF_MID", 0.35), seg=8, rings=4,
                 lumps=0.15, group="body_nl")
    return lambda s_: (s_ * (hy + off(s_) * 0.6), zb(s_) + off(s_))


def gable_wall(m, W, D, H, rise, droop=0.05, thick=0.2, oy=0.17, p=1.55, col="PLASTER", timber=True):
    """Triangular-ish wall under the roof curve at both gable ends (+ half-timber beams)."""
    hy = D / 2 + oy - thick * 0.55
    prof = [(-D / 2, H - 0.02), (D / 2, H - 0.02)]
    K = 10
    for i in range(K + 1):
        y = D / 2 - D * i / K
        s = y / hy
        z = H - droop + (rise + droop) * (1 - abs(s) ** p) ** (1 / p) - thick - 0.03
        prof.append((y, max(z, H - 0.02)))
    for sx in (-1, 1):
        m.prism(prof, 0.06, pos=(sx * (W / 2 - 0.03), 0, 0), color=col)
        if timber:
            top = H - droop + (rise + droop) - thick - 0.1
            m.box((0.04, 0.07, top - H), pos=(sx * W / 2, 0, H), color="WOOD_DARK")
            for sy in (-1, 1):
                ln = math.hypot(D * 0.32, (top - H) * 0.7)
                ang = math.atan2((top - H) * 0.7, D * 0.32)
                m.box((0.04, ln, 0.06), pos=(sx * W / 2, sy * D * 0.17, H + (top - H) * 0.17),
                      rot=(-sy * ang, 0, 0), color="WOOD_DARK")
            m.box((0.04, D, 0.07), pos=(sx * W / 2, 0, H - 0.03), color="WOOD_DARK")


def stone_walls(m, W, D, H, col="STONE", dark="STONE_DARK", n_stones=9, seed=0, quoins=True):
    m.box((W, D, H), color=col)
    m.box((W + 0.08, D + 0.08, 0.14), color=dark)                     # plinth
    r = m.rng
    if quoins:
        for sx in (-1, 1):
            for k in range(3):
                z = 0.2 + k * (H - 0.25) / 3
                wide = k % 2 == 0
                m.box((0.16 if wide else 0.1, 0.1 if wide else 0.16, 0.16),
                      pos=(sx * (W / 2 - (0.06 if wide else 0.03)), -D / 2 + (0.03 if wide else 0.06), z),
                      color=shade(col, 1.06))
    # a few slightly proud stones on the front + one side -> lines read as masonry
    for i in range(n_stones):
        w = r.uniform(0.14, 0.24)
        h = r.uniform(0.09, 0.13)
        x = r.uniform(-W / 2 + 0.2, W / 2 - 0.2)
        z = r.uniform(0.22, H - 0.18)
        c = shade(col, r.choice((0.9, 0.94, 1.05)))
        if i % 3 == 2:
            m.box((0.02, w, h), pos=(W / 2 + 0.008, r.uniform(-D / 2 + 0.2, D / 2 - 0.2), z), color=c)
        else:
            m.box((w, 0.02, h), pos=(x, -D / 2 - 0.008, z), color=c)


def plank_walls(m, W, D, H, col="WOOD"):
    m.box((W, D, H), color=col)
    n = int(W / 0.2)
    for i in range(n):
        x = -W / 2 + (i + 0.5) * W / n
        m.box((W / n * 0.9, 0.02, H - 0.05), pos=(x, -D / 2 - 0.008, 0.02), color=shade(col, 0.92 if i % 2 else 1.04))
    m.box((W + 0.06, D + 0.06, 0.1), color="STONE_DARK")


def door(m, x, y, w=0.36, h=0.6, col="WOOD", arch=True, face=-1):
    """Arched plank door on the wall plane y (face -1 = front): flat slab + frame + step."""
    def outline(ww, hh):
        pts = [(-ww / 2, 0.0), (ww / 2, 0.0)]
        k = 5 if arch else 1
        for i in range(k + 1):
            a = i / k * math.pi
            pts.append((ww / 2 * math.cos(a), hh - (ww / 2 if arch else 0) + (ww / 2 * math.sin(a) if arch else 0)))
        return [(-px, pz) for px, pz in pts]      # prism profile y -> world -x after the 90 deg turn
    m.prism(outline(w + 0.1, h + 0.05), 0.03, pos=(x, y + face * 0.012, 0.0), rot=(0, 0, math.pi / 2), color="WOOD_DARK")
    m.prism(outline(w, h), 0.03, pos=(x, y + face * 0.03, 0.0), rot=(0, 0, math.pi / 2), color=col)
    for k in (-1, 1):
        m.box((0.035, 0.02, h * 0.62), pos=(x + k * w * 0.2, y + face * 0.05, 0.08), color=shade(col, 0.8))
    m.box((0.05, 0.03, 0.05), pos=(x + w * 0.3, y + face * 0.05, h * 0.42), color="WOOD_DARK")   # handle
    m.box((w + 0.18, 0.2, 0.07), pos=(x, y + face * 0.1, 0.0), color=shade(STEP, 0.92))           # step


def window(m, x, z, y, w=0.3, h=0.28, face=-1, side=False):
    """Warm lit window with a wooden frame and cross mullion. side=True -> on a wall facing +X/-X at x."""
    if side:
        m.box((0.03, w + 0.08, h + 0.08), pos=(x, y, z - 0.04), color="WOOD_DARK")
        m.box((0.05, w, h), pos=(x + face * 0.01, y, z), color="WINDOW_LIT")
        m.box((0.06, 0.035, h), pos=(x + face * 0.012, y, z), color="WOOD_DARK")
        m.box((0.06, w, 0.035), pos=(x + face * 0.012, y, z + h / 2 - 0.017), color="WOOD_DARK")
        return
    m.box((w + 0.08, 0.03, h + 0.08), pos=(x, y + face * 0.008, z - 0.04), color="WOOD_DARK")
    m.box((w, 0.05, h), pos=(x, y + face * 0.012, z), color="WINDOW_LIT")
    m.box((0.035, 0.06, h), pos=(x, y + face * 0.014, z), color="WOOD_DARK")
    m.box((w, 0.06, 0.035), pos=(x, y + face * 0.014, z + h / 2 - 0.017), color="WOOD_DARK")
    m.box((w + 0.12, 0.1, 0.05), pos=(x, y + face * 0.04, z - 0.07), color="STONE_DARK")       # sill


def flower_box(m, x, y, w=0.36, z=0.45, face=-1, seed=0, cols=None):
    """Window box with round flower heads and a few leaves (front wall plane y)."""
    cols = cols or ("LOTUS", "FLAME2", "PLASTER")
    m.box((w, 0.13, 0.1), pos=(x, y + face * 0.07, z), color="WOOD",
          colfn=lambda f: "FIELD_SOIL" if f.normal.z > 0.7 else "WOOD")
    m.box((w - 0.04, 0.1, 0.06), pos=(x, y + face * 0.07, z + 0.09), color=shade("BUSH", 0.95))       # leaves
    n = max(3, int(w / 0.11))
    for i in range(n):
        px = x - w / 2 + (i + 0.5) * w / n
        m.sphere(0.055, pos=(px, y + face * (0.08 + 0.03 * (i % 2)), z + 0.17), scl=(1, 1, 0.8),
                 color=cols[(i + seed) % len(cols)], seg=5, rings=3, group="body_nl")


def shutters(m, x, z, y, w, h, col, face=-1):
    for sx in (-1, 1):
        m.box((w * 0.42, 0.03, h + 0.04), pos=(x + sx * (w / 2 + w * 0.24), y + face * 0.02, z - 0.02), color=col)
        m.box((w * 0.3, 0.035, 0.03), pos=(x + sx * (w / 2 + w * 0.24), y + face * 0.025, z + h * 0.5), color=shade(col, 0.8))


def stepping_stones(m, x, y, n=2, face=-1):
    for k in range(n):
        m.cyl(0.17 - 0.02 * k, 0.15 - 0.02 * k, 0.05, pos=(x + (0.06 if k % 2 else -0.04), y + face * (0.32 + k * 0.3), 0.0),
              color=STEP, seg=6, cap=shade(STEP, 1.08), scl=(1.25, 1.0, 1.0))


def picket_fence(m, x0, y0, x1, y1, h=0.42, col="WOOD"):
    """Short picket fence from (x0, y0) to (x1, y1): pickets with pointed tops + two rails."""
    d = Vector((x1 - x0, y1 - y0, 0))
    ln = d.length
    ang = math.atan2(d.y, d.x)
    n = max(2, int(ln / 0.16))
    pc = shade(col, 1.25)
    for i in range(n + 1):
        t = i / n
        px, py = x0 + d.x * t, y0 + d.y * t
        m.box((0.06, 0.04, h), pos=(px, py, 0), rot=(0, 0, ang), color=pc)
    for z in (h * 0.3, h * 0.72):
        m.box((ln, 0.03, 0.05), pos=((x0 + x1) / 2, (y0 + y1) / 2 + 0.03 * math.cos(ang), z), rot=(0, 0, ang),
              color=shade(col, 1.05))


def lantern(m, x, y, z, face=-1):
    m.box((0.03, 0.12, 0.03), pos=(x, y + face * 0.06, z + 0.1), color="WOOD_DARK")
    m.box((0.09, 0.09, 0.12), pos=(x, y + face * 0.12, z - 0.02), color="WINDOW_LIT",
          colfn=lambda f: "WOOD_DARK" if abs(f.normal.z) > 0.7 else "WINDOW_LIT")
    m.cyl(0.075, 0.0, 0.06, pos=(x, y + face * 0.12, z + 0.1), color="WOOD_DARK", seg=4, rot=(0, 0, math.pi / 4))


def barrel(m, x, y, s=1.0, z=0.0):
    m.cyl(0.17 * s, 0.17 * s, 0.4 * s, pos=(x, y, z), color="WOOD", seg=8, smooth=True, cap="STUMP_TOP")
    for hz in (0.07, 0.31):
        m.cyl(0.18 * s, 0.18 * s, 0.035 * s, pos=(x, y, z + hz * s), color="WOOD_DARK", seg=8, smooth=True)


def sack(m, x, y, s=1.0, z=0.0, rz=0.0):
    m.sphere(0.2 * s, pos=(x, y, z + 0.17 * s), scl=(1.0, 0.8, 0.95), color=SACK, seg=8, rings=5, lumps=0.12, rot=(0, 0, rz))
    m.cyl(0.07 * s, 0.03 * s, 0.1 * s, pos=(x, y, z + 0.32 * s), color=shade(SACK, 0.85), seg=6)


def crate(m, x, y, s=1.0, z=0.0, rz=0.0):
    c = shade("WOOD", 1.2)
    m.box((0.36 * s, 0.36 * s, 0.32 * s), pos=(x, y, z), rot=(0, 0, rz), color=c)
    m.box((0.38 * s, 0.38 * s, 0.05 * s), pos=(x, y, z + 0.27 * s), rot=(0, 0, rz), color="WOOD")


def log(m, x, y, z, length, r=0.11, rot_z=0.0, col="TRUNK"):
    """Horizontal log along local X rotated by rot_z, ends show rings."""
    m.cyl(r, r, length, pos=(x - math.cos(rot_z) * length / 2, y - math.sin(rot_z) * length / 2, z),
          rot=(0, math.pi / 2, rot_z), color=col, seg=7, smooth=True, cap="STUMP_TOP", bottom_cap="STUMP_TOP")


def post(m, x, y, h, w=0.09, col="WOOD_DARK"):
    m.box((w, w, h), pos=(x, y, 0), color=col)


def plank_roof(m, W, D, z, rise, col="WOOD", over=0.15):
    """Small gable roof made of planks (well, salt shelter): two sloped slabs, ridge along X."""
    half = D / 2 + over
    ln = math.hypot(half, rise)
    ang = math.atan2(rise, half)
    for sy in (-1, 1):
        n = 4
        for k in range(n):
            x = -W / 2 - over + (k + 0.5) * (W + 2 * over) / n
            m.box(((W + 2 * over) / n - 0.015, ln, 0.06), pos=(x, sy * half / 2, z + rise / 2 - 0.03),
                  rot=(sy * ang, 0, 0), color=shade(col, 1.0 if k % 2 else 0.9))
    m.box((W + 2 * over + 0.05, 0.1, 0.08), pos=(0, 0, z + rise - 0.04), color="WOOD_DARK")


# ───────────────────────── A19: round thatch, wall colours, timber frames ─────────────────────────
# wall plasters (title painting / flat2_map: cream, warm ochre, pale rose; stone grey = stone_walls)
CREAM = "f6ead0"
OCHRE = "edcb8f"
ROSE = "f2d2c4"
LIME = "f8f4ea"                                   # lime-washed white (healer, chapel)
# roof straw / tile
GOLD = "f3c97f"                                   # fresh golden thatch
GOLD_UNDER = "c99a5c"
MOSSY = mix("f0c886", "8fc46c", 0.3)              # older thatch with moss growing in
MOSSY_UNDER = mix("c99a5c", "6f9a5a", 0.35)
OLD = mix("f0c886", "9a7150", 0.22)               # weathered grey-brown straw
OLD_UNDER = mix("c99a5c", "5b4537", 0.3)
TILE = "d9775a"                                   # red clay tile (later eras)
TILE_UNDER = "a85a40"


def _se(theta, a, b, n):
    """Point on a superellipse (rounded rectangle for n ~ 3-4) with half-extents a, b."""
    c, s = math.cos(theta), math.sin(theta)
    return (a * math.copysign(abs(c) ** (2 / n), c), b * math.copysign(abs(s) ** (2 / n), s))


def bun_roof(m, W, D, H, rise, ox=0.27, oy=0.25, hip=0.82, col=GOLD, under=GOLD_UNDER, n=3.4, NU=7, NT=28,
             phi0=0.4, roll=0.09, wobble=0.035, ridge=False, scallop=True, moss=0, seed=0, bands=(0.48,)):
    """Round, puffy thatch (A19): a hipped 'bun' lofted through rounded-rectangle rings (superellipse, exponent n).
    The slope profile is a quarter ellipse started at phi0 -> soft bulge, steep rolled eaves, deep overhang
    (ox / oy beyond the W x D walls whose top is H). hip = how far the ends pull in (1 = ridge half-length A - B).
    Under the eave a fat rolled lip (roll) curls back to the wall. Everything is smooth-shaded (one clean toon
    terminator) and the vertex colours are 'painted': darker toward the eave, lighter toward the ridge, straw streaks
    running eave -> ridge, a darker course band (bands = u positions), a scalloped ridge cap (scallop) + ridge roll.
    Returns roof(x, y) -> surface height (for chimneys) and surf(u) -> (y, z) on the front slope at x = 0."""
    import random as _r
    rnd = _r.Random(seed * 17 + 3)
    A, B = W / 2 + ox, D / 2 + oy
    lo = math.sin(phi0)

    def abz(u):
        phi = phi0 + (math.pi / 2 - phi0) * u
        c = math.cos(phi) / math.cos(phi0)
        b = B * c
        return A - B * hip * (1 - c), max(b, 0.035), H + rise * (math.sin(phi) - lo) / (1 - lo)

    noise_off = [rnd.uniform(-1, 1) for _ in range(NT)]
    smooth_noise = [(noise_off[i - 1] + 2 * noise_off[i] + noise_off[(i + 1) % NT]) / 4 for i in range(NT)]
    thetas = [-math.pi / 2 + math.tau * i / NT for i in range(NT)]   # start at the front middle (-Y)

    def ring(a, b, z, wob=0.0, push=0.0):
        pts = []
        for i, t in enumerate(thetas):
            x, y = _se(t, a + push, b + push, n)
            pts.append(Vector((x, y, z + wob * smooth_noise[i])))
        return pts

    # rows: underside (wall) -> under-roll -> roll front -> eave -> slope rings -> ridge
    rings, kinds = [], []
    rings.append(ring(W / 2 - 0.03, D / 2 - 0.03, H - 0.03)); kinds.append("u")
    rings.append(ring(A - roll * 1.6, B - roll * 1.6, H - roll * 0.9, wobble)); kinds.append("u")
    rings.append(ring(A, B, H - roll * 1.15, wobble, -roll * 0.25)); kinds.append("r")
    rings.append(ring(A, B, H - roll * 0.35, wobble, roll * 0.32)); kinds.append("r")
    us = [k / NU for k in range(NU + 1)]
    for u in us:
        a, b, z = abz(u)
        rings.append(ring(a, b, z, wobble * (1 - u)))
        kinds.append("s%f" % u)
    bm = m._bm("body")
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    streak = [1.0 + 0.05 * smooth_noise[i] + (0.02 if i % 3 == 0 else -0.005) for i in range(NT)]
    faces = []
    for j in range(len(vr) - 1):
        a_, b_ = vr[j], vr[j + 1]
        kind = kinds[j + 1]
        for i in range(NT):
            k = (i + 1) % NT
            f = bm.faces.new((a_[i], a_[k], b_[k], b_[i]))
            faces.append(f)
            if kind == "u" or j == 0:
                c = under
            elif kind == "r":
                c = shade(col, (0.8 if j == 1 else 0.9) * streak[i])
            else:
                u = float(kind[1:])
                c = shade(col, (0.9 + 0.16 * u) * streak[i])
                for bu in bands:
                    if abs(u - bu) < 0.5 / NU + 1e-6 and u >= bu:
                        c = shade(col, 0.84 * streak[i])
                if scallop and u > 0.7:
                    cap = mix(col, "fff3d6", 0.2)
                    top = u > 0.86 or (i % 2 == 0)
                    c = shade(cap, 1.0 + 0.04 * smooth_noise[i]) if top else c
            m._finish(bm, [f], c, True)
    cap = bm.faces.new(list(vr[-1]))
    faces.append(cap)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    m._finish(bm, [cap], mix(col, "fff3d6", 0.2), True)
    a_t, b_t, z_t = abz(1.0)
    if ridge:      # fat ridge roll with two binding bands
        m.sphere(1.0, pos=(0, 0, z_t - 0.02), scl=(a_t + 0.12, 0.16, 0.13), color=shade(mix(col, "9a7150", 0.25), 0.95),
                 seg=12, rings=5)
    for k in range(moss):
        t = rnd.uniform(0, math.tau)
        u = rnd.uniform(0.15, 0.6)
        a, b, z = abz(u)
        x, y = _se(t, a, b, n)
        m.sphere(rnd.uniform(0.07, 0.1), pos=(x, y, z + 0.02), scl=(1.6, 1.3, 0.5),
                 color=mix(mix("MOSS", "LEAF_MID", 0.25), col, 0.3), seg=7, rings=4, lumps=0.15, group="body_nl")

    def roof(x, y):
        lo_u, hi_u = 0.0, 1.0
        for _ in range(18):
            mid = (lo_u + hi_u) / 2
            a, b, z = abz(mid)
            if (abs(x) / a) ** n + (abs(y) / b) ** n <= 1.0:
                lo_u = mid
            else:
                hi_u = mid
        return abz(lo_u)[2]

    def surf(u):
        a, b, z = abz(u)
        return -b, z
    return roof, surf


def tile_roof(m, W, D, H, rise, col=TILE, under=TILE_UNDER, seed=0, **kw):
    """Red clay tile gable for later eras: the course roof (thatch_roof) made straighter and thinner, with tile
    strips and a ridge of round tiles."""
    surf = thatch_roof(m, W, D, H, rise, col=col, under=under, p=1.12, thick=0.12, step=0.05, layers=(0.3, 0.6, 0.85),
                       strip=0.16, end=0.12, end_drop=0.04, end_pinch=0.96, droop=0.02, seed=seed, **kw)
    L = W + 2 * 0.24
    zt = H + rise + 3 * 0.05
    m.cyl(0.075, 0.075, L - 0.1, pos=(-(L - 0.1) / 2, 0, zt - 0.05), rot=(0, math.pi / 2, 0), color=shade(col, 0.85),
          seg=7, smooth=True, cap=shade(col, 0.7), bottom_cap=shade(col, 0.7))
    return surf


def rotated(m, fn, angle, offset=(0, 0, 0)):
    """Run fn() (adds geometry to m), then turn everything it added by angle around Z and move it by offset
    (e.g. a gable roof whose ridge should run front-to-back, or a porch roof beside the house)."""
    before = {g: len(bm.verts) for g, bm in m.groups.items()}
    fn()
    from mathutils import Matrix
    rot = Matrix.Translation(offset) @ Matrix.Rotation(angle, 4, "Z")
    for g, bm in m.groups.items():
        bm.verts.ensure_lookup_table()
        vs = bm.verts[before.get(g, 0):]
        if vs:
            bmesh.ops.transform(bm, matrix=rot, verts=vs)
        bm.normal_update()


def framed_walls(m, W, D, H, col=CREAM, beam="WOOD_DARK", base="STONE", base_h=0.32, braces=True, posts=None,
                 back=False):
    """Plaster walls with a half-timber frame on the front and both sides over a low stone footing."""
    m.box((W, D, H), color=col)
    m.box((W + 0.07, D + 0.07, base_h), color=base)
    m.box((W + 0.11, D + 0.11, 0.1), color="STONE_DARK")
    t = 0.03
    xs = posts if posts is not None else [-W / 2, W / 2]
    # front
    for x in xs:
        m.box((0.075, t, H - base_h), pos=(x, -D / 2 - 0.012, base_h), color=beam)
    for z in (base_h, H - 0.07):
        m.box((W + 0.04, t, 0.075), pos=(0, -D / 2 - 0.012, z), color=beam)
    # sides
    for sx in (-1, 1):
        for y in (-D / 2, 0.0, D / 2):
            m.box((t, 0.075, H - base_h), pos=(sx * (W / 2 + 0.012), y * 0.985, base_h), color=beam)
        for z in (base_h, H - 0.07):
            m.box((t, D + 0.04, 0.075), pos=(sx * (W / 2 + 0.012), 0, z), color=beam)
        if braces:
            for sy in (-1, 1):
                ln = math.hypot(D / 2, H - base_h - 0.1)
                a = math.atan2(H - base_h - 0.1, D / 2)
                m.box((t, ln, 0.06), pos=(sx * (W / 2 + 0.014), sy * D / 4, base_h + (H - base_h) / 2 - 0.08),
                      rot=(sy * a, 0, 0), color=beam)
    if back:
        for x in xs:
            m.box((0.075, t, H - base_h), pos=(x, D / 2 + 0.012, base_h), color=beam)


def chimney(m, x, y, top, w=0.36, col="STONE"):
    """Chunky round-shouldered stone chimney: fat base courses, a slightly narrower stack, flared cap, clay pot."""
    z = 0.0
    k = 0
    course = 0.24
    while z < top - 0.01:
        h = min(course, top - z)
        ww = w + (0.06 if z < 0.6 else 0.0)
        dx = 0.016 if k % 2 else -0.016
        m.box((ww + (0.03 if k % 2 else 0.0), ww + (0.0 if k % 2 else 0.03), h), pos=(x + dx, y, z),
              color=shade(col, (1.0, 0.92, 1.06, 0.96)[k % 4]))
        z += h
        k += 1
    m.box((w + 0.12, w + 0.12, 0.1), pos=(x, y, top), color="STONE_DARK",
          colfn=lambda f: shade("STONE", 1.05) if f.normal.z > 0.7 else "STONE_DARK")
    m.cyl(0.1, 0.085, 0.15, pos=(x, y, top + 0.1), color=shade("ROOF_RED", 0.92), seg=7, smooth=True, cap=SOOT)


def dormer(m, x, surf, col, under, roof_fn):
    """Eyebrow dormer for bun_roof: lit window in a small plaster face under a round thatch hood."""
    y0, z0 = surf(0.12)
    y1, z1 = surf(0.42)
    w = 0.52
    m.box((w - 0.08, 0.35, z1 - z0 + 0.05), pos=(x, y0 + 0.24, z0 - 0.06), color=CREAM)
    m.box((0.3, 0.05, 0.22), pos=(x, y0 + 0.07, z0 + 0.0), color="WINDOW_LIT")
    m.box((0.035, 0.06, 0.22), pos=(x, y0 + 0.065, z0 + 0.0), color="WOOD_DARK")
    m.box((0.36, 0.06, 0.04), pos=(x, y0 + 0.065, z0 - 0.03), color="WOOD_DARK")
    hood = m.sphere(0.5, pos=(x, y0 + 0.24, z1 - 0.02), scl=(0.66, 0.6, 0.34), color=shade(col, 0.98), seg=12, rings=6)
    bm = m._bm("body")
    for f in hood:
        if f.normal.z < -0.25:
            m._finish(bm, [f], under, True)


def herb_bundle(m, x, y, z, col="7fb565"):
    m.box((0.02, 0.02, 0.08), pos=(x, y, z - 0.08), color="WOOD_DARK")
    m.cyl(0.02, 0.07, 0.16, pos=(x, y, z - 0.24), color=col, seg=5)


def round_bush(m, x, y, r=0.2, col="BUSH", flowers=None, seed=0):
    m.sphere(r, pos=(x, y, r * 0.75), scl=(1.15, 1.0, 0.85), color=col, seg=8, rings=5, lumps=0.18, group="body_nl")
    if flowers:
        for k in range(3):
            a = seed + k * 2.1
            m.sphere(0.035, pos=(x + math.cos(a) * r * 0.8, y + math.sin(a) * r * 0.8 - r * 0.2, r * 1.15),
                     color=flowers, seg=5, rings=3, group="body_nl")


# ───────────────────────── v3: roof / wall materials so building types read apart ─────────────────────────
SHINGLE = "b07b52"                                # split-wood shingles (목조주택, 벌목장)
SHINGLE_UNDER = "7a5236"
SHINGLE_BLUE = "7d97a6"                           # blue-grey painted shingles (목조주택 b)
SHINGLE_BLUE_UNDER = "566e7c"
SLATE_ROOF = "7c8a8e"                             # slate (석조주택, 예배당)
SLATE_ROOF_UNDER = "5b676b"
TEAL_TILE = "6aa59a"                              # glazed green-teal tile (치료소)
TEAL_TILE_UNDER = "4b7d74"
SOD = "86b964"                                    # turf / moss roof (약초원)
SOD_UNDER = "5f7f45"
BARK = "7d5b42"                                   # bark / dark plank roof (사냥막, 묘목원)
BARK_UNDER = "553d2c"
REED_ROOF = "c9b47c"                              # reed thatch, straight gable (어장)
REED_ROOF_UNDER = "9b8656"
BARN_RED = "b65a45"                               # barn boards (창고)
BRICK = "c98262"                                  # bakery bricks
BRICK_DARK = "a4644a"
SMOKE = "eeeae2"


def log_walls(m, W, D, H, col="TRUNK"):
    """Log-cabin walls: a dark core + round logs stacked on all four sides, ends crossing at the corners."""
    m.box((W - 0.08, D - 0.08, H), color=shade(col, 0.75))
    r = 0.085
    n = max(3, int(H / (2 * r * 0.95)))
    dz = H / n
    for k in range(n):
        z = k * dz
        c = shade(col, (1.0, 0.92, 1.06)[k % 3])
        for sy in (-1, 1):
            m.cyl(r, r, W + 0.26, pos=(-(W + 0.26) / 2, sy * (D / 2 - 0.02), z + r), rot=(0, math.pi / 2, 0),
                  color=c, seg=6, cap="STUMP_TOP", bottom_cap="STUMP_TOP")
        zs = z + dz * 0.5
        if zs + r <= H + 0.02:
            for sx in (-1, 1):
                m.cyl(r, r, D + 0.22, pos=(sx * (W / 2 - 0.02), (D + 0.22) / 2, zs + r), rot=(math.pi / 2, 0, 0),
                      color=shade(c, 0.95), seg=6, cap="STUMP_TOP", bottom_cap="STUMP_TOP")
    m.box((W + 0.1, D + 0.1, 0.1), color="STONE_DARK")


def brick_walls(m, W, D, H, col=BRICK, dark=BRICK_DARK):
    """Warm brick walls: body + offset brick courses on the front and sides, stone plinth."""
    m.box((W, D, H), color=col)
    m.box((W + 0.08, D + 0.08, 0.16), color="STONE")
    rows = int((H - 0.2) / 0.14)
    n = int(W / 0.3)
    for k in range(rows):
        z = 0.2 + k * 0.14
        for i in range(n):
            if (i + k) % 3:
                continue
            x = -W / 2 + 0.15 + (i + (0.5 if k % 2 else 0)) * (W - 0.3) / n
            m.box((0.24, 0.02, 0.1), pos=(x, -D / 2 - 0.008, z), color=dark if (i + k) % 2 else shade(col, 1.08))
        if k % 2:
            for sx in (-1, 1):
                m.box((0.02, 0.24, 0.1), pos=(sx * (W / 2 + 0.008), -D / 4 + (k % 4) * 0.12, z), color=dark)


def lathe(m, prof, seg=16, colfn=None, color="THATCH", smooth=True, top=True, group="body"):
    """Surface of revolution through profile [(r, z), ...] (bottom -> top). colfn(face, z) -> colour."""
    rings = [[Vector((math.cos(i * math.tau / seg) * r, math.sin(i * math.tau / seg) * r, z)) for i in range(seg)]
             for r, z in prof]
    fs = m.strip(rings, close=True, smooth=smooth, color=color, group=group)
    bm = m._bm(group)
    caps = []
    if top:
        caps.append(bm.faces.new([bm.verts.new(p) for p in rings[-1]]))
    bmesh.ops.recalc_face_normals(bm, faces=fs + caps)
    bm.normal_update()
    if colfn:
        for f in fs:
            m._finish(bm, [f], colfn(f, f.calc_center_median().z), smooth)
    for f in caps:
        m._finish(bm, [f], colfn(f, prof[-1][1]) if colfn else color, smooth)
    return fs


def cone_roof(m, R, H, rise, col=GOLD, under=GOLD_UNDER, over=0.3, seg=18, bulge=0.18, x=0.0, y=0.0, finial=True):
    """Round conical thatch (round huts): rolled eave lip, slightly bulging cone, darker course band, knot finial.
    Walls of radius R end at height H. Centre (x, y)."""
    Re = R + over
    prof = [(R - 0.02, H - 0.02), (Re - 0.06, H - 0.16), (Re + 0.03, H - 0.08), (Re + 0.02, H + 0.04)]
    K = 7
    for k in range(1, K + 1):
        t = k / K
        r = Re * (1 - t) * (1 + bulge * math.sin(t * math.pi) * 0.6)
        prof.append((max(r, 0.03), H + 0.04 + rise * t))

    def cf(f, z):
        if f.normal.z < -0.2:
            return under
        t = (z - H) / rise
        if 0.38 < t < 0.52:
            return shade(col, 0.86)
        return shade(col, 0.9 + 0.18 * max(0.0, t))
    bm = m._bm("body")
    n0 = len(bm.verts)
    lathe(m, prof, seg=seg, colfn=cf, color=col)
    if x or y:
        bm.verts.ensure_lookup_table()
        bmesh.ops.translate(bm, verts=bm.verts[n0:], vec=Vector((x, y, 0)))
    if finial:
        m.cyl(0.07, 0.03, 0.22, pos=(x, y, H + rise - 0.04), color=shade(col, 0.75), seg=6)
        m.sphere(0.06, pos=(x, y, H + rise + 0.2), color=shade(col, 0.7), seg=6, rings=3)


def sod_tufts(m, W, D, H, rise, n=10, flowers=("ffffff", "f4d64c", "LOTUS"), seed=0, over=0.24):
    """Grass blades + little flowers on a turf gable roof (ridge along X)."""
    import random as _r
    rnd = _r.Random(seed)
    hy = D / 2 + over
    for k in range(n):
        x = rnd.uniform(-W / 2, W / 2)
        s = rnd.uniform(0.2, 0.8) * (-1 if k % 2 else 1)
        y = s * hy
        z = H + rise * (1 - abs(s)) + 0.04
        for j in range(3):
            a = j * 2.1 + k
            m.blade((x, y, z), (x + math.cos(a) * 0.06, y + math.sin(a) * 0.06, z + 0.16), 0.06, color="TUFT")
        if k % 3 == 0:
            m.sphere(0.045, pos=(x + 0.04, y, z + 0.09), color=flowers[k % len(flowers)], seg=5, rings=3, group="body_nl")


def smoke(m, x, y, z, n=3):
    """Static soft smoke puffs rising from a chimney."""
    for k in range(n):
        m.sphere(0.11 + 0.05 * k, pos=(x + 0.08 * k, y + 0.04 * k, z + 0.12 + k * 0.24), scl=(1, 1, 0.8), color=SMOKE,
                 seg=7, rings=4, lumps=0.2, group="body_nl")


def big_doors(m, x, y, w=1.0, h=1.0, col="WOOD", frame="WOOD_DARK"):
    """Barn double doors on the front wall plane y: two plank leaves with pale Z braces."""
    m.box((w + 0.12, 0.04, h + 0.08), pos=(x, y - 0.015, 0.0), color=frame)
    for sx in (-1, 1):
        cx = x + sx * w / 4
        m.box((w / 2 - 0.03, 0.05, h), pos=(cx, y - 0.04, 0.02), color=col)
        for z in (0.1, h - 0.12):
            m.box((w / 2 - 0.06, 0.06, 0.07), pos=(cx, y - 0.06, z), color="f2ead8")
        ln = math.hypot(w / 2 - 0.1, h - 0.3)
        a = math.atan2(h - 0.3, w / 2 - 0.1)
        m.box((ln, 0.06, 0.06), pos=(cx, y - 0.065, 0.14 + (h - 0.3) / 2 - 0.03), rot=(0, -sx * a, 0), color="f2ead8")
    m.box((w + 0.25, 0.22, 0.06), pos=(x, y - 0.12, 0.0), color=shade(STEP, 0.92))


def lift(m, dz):
    """Move everything built so far up by dz (stilt houses)."""
    for g, bm in m.groups.items():
        bmesh.ops.translate(bm, verts=bm.verts[:], vec=Vector((0, 0, dz)))
        bm.normal_update()


def house(name, W, D, H, rise, door_x, win_xs, chim, seed, extras=None, walls=("framed", CREAM), roof="bun",
          roof_col=GOLD, roof_under=GOLD_UNDER, hip=0.82, side_win=True, shutter=None, boxes=True, moss=0, steps=2,
          lamp=False, dormer_x=None, ox=0.27, oy=0.25, phi0=0.4, posts=None, door_col="DOOR", upper=None):
    """A19 cottage builder: walls (('framed', plaster) | ('stone', col) | ('plank', col)) + roof ('bun' thatch |
    'tile' red tile gable) + arched door, lit windows, chunky chimney, flower boxes, shutters."""
    m = Model(name, seed)
    kind, wc = walls
    if kind == "framed":
        framed_walls(m, W, D, H, col=wc, posts=posts)
    elif kind == "stone":
        stone_walls(m, W, D, H, col=wc, seed=seed)
    elif kind == "plank":
        plank_walls(m, W, D, H, col=wc)
    elif kind == "log":
        log_walls(m, W, D, H, col=wc)
    elif kind == "brick":
        brick_walls(m, W, D, H, col=wc)
    if roof == "bun":
        roof_fn, surf = bun_roof(m, W, D, H, rise, col=roof_col, under=roof_under, hip=hip, moss=moss, seed=seed,
                                 ox=ox, oy=oy, phi0=phi0)
        if dormer_x is not None:
            dormer(m, dormer_x, surf, roof_col, roof_under, roof_fn)
    elif roof == "tile":
        gable_wall(m, W, D, H, rise, p=1.12, col=wc if kind != "stone" else "STONE", timber=kind == "framed",
                   thick=0.12, droop=0.02)
        tile_roof(m, W, D, H, rise, col=roof_col, under=roof_under, seed=seed)
        roof_fn = lambda x, y: H + rise * (1 - abs(y) / (D / 2 + 0.2))        # noqa: E731
    else:      # "tile_front": gable end facing the camera (title painting), ridge front-to-back
        gcol = wc if kind != "stone" else "STONE"

        def _r():
            gable_wall(m, D, W, H, rise, p=1.12, col=gcol, timber=kind == "framed", thick=0.12, droop=0.02)
            tile_roof(m, D, W, H, rise, col=roof_col, under=roof_under, seed=seed)
        rotated(m, _r, -math.pi / 2)
        roof_fn = lambda x, y: H + rise * (1 - abs(x) / (W / 2 + 0.2))        # noqa: E731
        # plaster gable face in front of the roof's end cap, with a timber king post and a round lit window
        yf = -(D / 2 + 0.24) - 0.02
        tri = [(-W / 2 + 0.06, H - 0.02), (W / 2 - 0.06, H - 0.02), (0.0, H + rise - 0.12)]
        m.prism([(-x, z) for x, z in tri], 0.03, pos=(0, yf, 0), rot=(0, 0, math.pi / 2),
                color=CREAM if kind == "stone" else wc)
        m.box((W - 0.1, 0.04, 0.07), pos=(0, yf - 0.02, H - 0.05), color="WOOD_DARK")
        m.box((0.07, 0.04, rise - 0.5), pos=(0, yf - 0.02, H + 0.02), color="WOOD_DARK")
        zw = H + rise * 0.4
        m.cyl(0.17, 0.17, 0.04, pos=(0, yf - 0.01, zw), rot=(math.pi / 2, 0, 0), color="WOOD_DARK", seg=12)
        m.cyl(0.13, 0.13, 0.05, pos=(0, yf - 0.02, zw), rot=(math.pi / 2, 0, 0), color="WINDOW_LIT", seg=12)
        m.box((0.03, 0.06, 0.26), pos=(0, yf - 0.03, zw - 0.13), color="WOOD_DARK")
        m.box((0.26, 0.06, 0.03), pos=(0, yf - 0.03, zw - 0.015), color="WOOD_DARK")
    dh = min(0.9, H - 0.38)
    door(m, door_x, -D / 2, w=0.42, h=dh, col=door_col)
    if steps:
        stepping_stones(m, door_x, -D / 2 - 0.1, steps)
    if lamp:
        lantern(m, door_x + 0.36, -D / 2, dh - 0.05)
    wz = min(H * 0.48, 0.6)
    for i, x in enumerate(win_xs):
        window(m, x, wz, -D / 2)
        if shutter is not None:
            shutters(m, x, wz, -D / 2, 0.3, 0.28, shutter)
        if boxes:
            flower_box(m, x, -D / 2, w=0.4, z=wz - 0.17, seed=seed + i)
    if upper:
        for x in upper:
            window(m, x, H - 0.55, -D / 2, w=0.28, h=0.26)
            if shutter is not None:
                shutters(m, x, H - 0.55, -D / 2, 0.28, 0.26, shutter)
    if side_win:
        window(m, W / 2 + 0.01, wz, 0.0, w=0.26, h=0.24, face=1, side=True)
    if chim is not None:
        cx, cy = chim
        chimney(m, cx, cy, roof_fn(cx, cy) + 0.32)
    if extras:
        extras(m)
    return m


# ───────────────────────── cottages ─────────────────────────
def build_cottages():
    def a_extra(m):
        barrel(m, 1.18, -0.32)
        sack(m, 1.16, 0.05, 0.8)
        picket_fence(m, -1.4, -1.0, -1.4, 0.3)
        picket_fence(m, -1.4, -1.0, -0.8, -1.0)
        round_bush(m, -1.05, -0.85, 0.2, flowers="LOTUS", seed=1)
    # v3: small ROUND hut — cream cob wall under a tall golden cone of thatch
    round_hut("cottage_a", 0.82, 1.05, 1.35, CREAM, GOLD, GOLD_UNDER, 11, extras=a_extra, shutter=SHUTTER[0]).export(OUT)

    def b_extra(m):
        sack(m, -1.25, -0.45, 0.9)
        barrel(m, -1.3, -0.1, 0.85)
        m.cyl(0.12, 0.09, 0.2, pos=(0.8, -0.98, 0), color="ROOF_RED", seg=8, cap="FIELD_SOIL")       # flower pot
        m.sphere(0.13, pos=(0.8, -0.98, 0.27), color="BUSH", seg=7, rings=4, lumps=0.2, group="body_nl")
        for k in range(3):
            m.sphere(0.04, pos=(0.75 + k * 0.05, -1.05, 0.36 + 0.02 * k), color="FLAME2", seg=5, rings=3, group="body_nl")
    # pale rose plaster, mossy thatch with an eyebrow dormer
    house("cottage_b", 2.1, 1.3, 1.25, 1.25, 0.3, [-0.45, 0.82], (0.7, 0.12), 12, extras=b_extra,
          roof_col=MOSSY, roof_under=MOSSY_UNDER, shutter=SHUTTER[1], lamp=True,
          walls=("framed", ROSE), moss=2).export(OUT)
    # warm ochre plaster, golden thatch, green shutters, woodpile corner
    def c_extra(m):
        for k in range(3):
            log(m, 1.25, 0.05 + k * 0.0, 0.1 + k * 0.18, 0.7, 0.09, 1.57)
        round_bush(m, -1.2, -0.8, 0.22, flowers="ffffff", seed=3)
        m.cyl(0.12, 0.09, 0.2, pos=(0.85, -0.98, 0), color="ROOF_RED", seg=8, cap="FIELD_SOIL")
        m.sphere(0.13, pos=(0.85, -0.98, 0.27), color="BUSH", seg=7, rings=4, lumps=0.2, group="body_nl")
    # v3: round hut on a fieldstone footing, ochre wall, weathered straw cone
    round_hut("cottage_c", 0.86, 1.0, 1.25, OCHRE, OLD, OLD_UNDER, 14, extras=c_extra, shutter=SHUTTER[2],
              stone_base=True).export(OUT)

    # grey fieldstone cottage under a small red clay tile gable (v3 — a third home silhouette)
    def d_extra(m):
        barrel(m, -1.2, -0.35, 0.85)
        picket_fence(m, 0.7, -1.05, 1.4, -1.05)
        picket_fence(m, 1.4, -1.05, 1.4, -0.1)
        round_bush(m, 1.1, -0.65, 0.2, flowers="LOTUS", seed=6)
    house("cottage_d", 1.85, 1.25, 1.2, 0.95, -0.25, [0.45], (0.6, 0.12), 15, extras=d_extra, shutter=SHUTTER[3],
          walls=("stone", "STONE"), roof="tile", roof_col=TILE, roof_under=TILE_UNDER).export(OUT)

    # 벌목장 (나무꾼): log cabin under a shingle gable + a log yard (stacked trunks on bearers), saw horse.
    # The woodpile shed and the axe-in-stump chopping block are yard props added by village_view (YARD).
    def hut_extra(m):
        for row in range(3):
            for i in range(4 - row):
                m.cyl(0.12, 0.12, 1.15, pos=(-0.55 + (i + row * 0.5) * 0.25, 0.95, 0.12 + row * 0.21),
                      rot=(0, math.pi / 2, 0), color=shade("TRUNK", (1.0, 0.9, 1.08)[(i + row) % 3]), seg=7,
                      cap="STUMP_TOP", bottom_cap="STUMP_TOP")
        for x in (-0.55, 0.45):
            m.box((0.12, 0.6, 0.06), pos=(x, 0.95, 0), color="WOOD_DARK")
        # saw horse with a half-cut log
        for dx in (-0.25, 0.25):
            for s in (-1, 1):
                m.box((0.04, 0.04, 0.5), pos=(1.15 + dx, -0.55, 0), rot=(s * 0.35, 0, 0), color="WOOD")
        log(m, 1.15, -0.55, 0.38, 0.85, 0.1, 0.0)
        m.box((0.5, 0.02, 0.12), pos=(1.15, -0.62, 0.5), rot=(0, 0.4, 0), color="ROCK")
    house("hut", 1.5, 1.1, 1.0, 0.95, 0.15, [-0.4], (0.45, 0.2), 13, walls=("log", "TRUNK"), side_win=False,
          roof="tile", roof_col=SHINGLE, roof_under=SHINGLE_UNDER, boxes=False, steps=1, extras=hut_extra).export(OUT)


def round_hut(name, R, H, rise, wall, roof_col, roof_under, seed, extras=None, shutter=None, stone_base=False):
    """v3 오두막 variant: round cob hut under a cone of thatch (reads apart from the square bun cottages)."""
    m = Model(name, seed)
    m.cyl(R + 0.07, R + 0.07, 0.3 if stone_base else 0.12, color="STONE" if stone_base else "STONE_DARK", seg=14)
    if stone_base:
        for k in range(9):
            a = -math.pi / 2 + (k - 4) * 0.5
            m.box((0.2, 0.05, 0.12), pos=(math.cos(a) * (R + 0.08), math.sin(a) * (R + 0.08), 0.06 + (k % 2) * 0.12),
                  rot=(0, 0, a + math.pi / 2), color=shade("STONE", 0.9 if k % 2 else 1.06))
    m.cyl(R, R * 0.97, H, color=wall, seg=14, smooth=True)
    for k in range(6):                                      # timber posts round the wall
        a = -math.pi / 2 + (k - 2.5) * 0.62
        m.box((0.07, 0.03, H - 0.1), pos=(math.cos(a) * (R + 0.004), math.sin(a) * (R + 0.004), 0.1),
              rot=(0, 0, a + math.pi / 2), color="WOOD_DARK")
    cone_roof(m, R, H, rise, col=roof_col, under=roof_under, over=0.32)
    door(m, 0.0, -R + 0.03, w=0.4, h=min(0.8, H - 0.2), col="DOOR")
    stepping_stones(m, 0.0, -R - 0.12, 2)
    for a in (-math.pi / 2 + 0.95,):
        def at(rr, s=0.0):
            return (math.cos(a) * rr - math.sin(a) * s, math.sin(a) * rr + math.cos(a) * s)
        x, y = at(R + 0.0)
        m.box((0.32, 0.06, 0.3), pos=(x, y, 0.47), rot=(0, 0, a + math.pi / 2), color="WOOD_DARK")
        x, y = at(R + 0.02)
        m.box((0.24, 0.06, 0.22), pos=(x, y, 0.51), rot=(0, 0, a + math.pi / 2), color="WINDOW_LIT")
        if shutter is not None:
            for s in (-1, 1):
                x, y = at(R + 0.03, s * 0.21)
                m.box((0.1, 0.05, 0.27), pos=(x, y, 0.49), rot=(0, 0, a + math.pi / 2), color=shutter)
    if extras:
        extras(m)
    return m


def build_houses():
    def t_extra(m):
        for k, x in enumerate((-0.75, 0.75)):
            flower_box(m, x, -0.75, w=0.38, z=1.15, seed=k)
        barrel(m, 1.42, -0.82)
        barrel(m, 1.22, -1.02, 0.85)
        round_bush(m, -1.45, -0.7, 0.24, flowers="FLAME2", seed=2)
    # 목조주택 (v3): two storeys, timber-framed plaster under a straight wood-shingle gable (no thatch) + a variant
    house("house_timber", 2.4, 1.5, 1.95, 1.1, -0.35, [0.55], (0.85, 0.15), 21, walls=("framed", OCHRE), roof="tile",
          roof_col=SHINGLE, roof_under=SHINGLE_UNDER, extras=t_extra, shutter=SHUTTER[2], lamp=True,
          upper=(-0.75, 0.0, 0.75), posts=[-1.2, -0.4, 0.4, 1.2]).export(OUT)
    house("house_timber_b", 2.4, 1.5, 1.95, 1.1, 0.35, [-0.55], (-0.85, 0.15), 23, walls=("framed", ROSE), roof="tile",
          roof_col=SHINGLE_BLUE, roof_under=SHINGLE_BLUE_UNDER, extras=t_extra, shutter=SHUTTER[1], lamp=True,
          upper=(-0.75, 0.0, 0.75), posts=[-1.2, -0.4, 0.4, 1.2]).export(OUT)

    # 석조주택 (v3): big stone house, gable to the front, grey slate roof; variant with red clay tile
    def s_extra(m):
        crate(m, 1.45, -0.85, 0.9)
        round_bush(m, -1.5, -0.6, 0.22, flowers="LOTUS", seed=4)
    house("house_stone", 2.4, 1.55, 1.75, 1.3, 0.0, [-0.75, 0.75], (-0.7, 0.35), 22, walls=("stone", "STONE"),
          roof="tile_front", roof_col=SLATE_ROOF, roof_under=SLATE_ROOF_UNDER, extras=s_extra, shutter=SHUTTER[3],
          lamp=True, upper=(-0.75, 0.75)).export(OUT)
    house("house_stone_b", 2.4, 1.55, 1.75, 1.3, 0.0, [-0.75, 0.75], (0.7, 0.35), 24, walls=("stone", "STONE"),
          roof="tile_front", roof_col=TILE, roof_under=TILE_UNDER, extras=s_extra, shutter=SHUTTER[0], lamp=True,
          upper=(-0.75, 0.75)).export(OUT)


# ───────────────────────── work buildings ─────────────────────────
def build_store():
    """창고 (v3): long red-board barn, gable to the front, big double doors with Z braces, hay loft door,
    sacks / barrels / crates stacked outside."""
    def ex(m):
        big_doors(m, 0.0, -0.8, w=1.05, h=1.05, col=shade(BARN_RED, 0.85))
        # hay loft door in the gable (over the round window) + hoist beam with a rope and a sack
        yf = -(1.6 / 2 + 0.24) - 0.05
        m.box((0.42, 0.05, 0.42), pos=(0, yf, 1.55), color="WOOD_DARK")
        m.box((0.34, 0.06, 0.34), pos=(0, yf - 0.01, 1.59), color=shade(BARN_RED, 0.8))
        m.box((0.1, 0.5, 0.1), pos=(0, yf - 0.2, 2.15), color="WOOD_DARK")
        m.box((0.015, 0.015, 0.35), pos=(0, yf - 0.4, 1.82), color="d9b98a")
        sack(m, 0.0, yf - 0.4, 0.7, z=1.62)
        # outside: barrels left, sacks + crates right
        barrel(m, -1.15, -1.0)
        barrel(m, -1.45, -0.75, 0.9)
        barrel(m, -1.3, -0.88, 0.85, z=0.4)
        sack(m, 1.05, -1.05)
        sack(m, 1.35, -0.95, 0.9, rz=0.5)
        sack(m, 1.2, -1.0, 0.85, z=0.28)
        crate(m, 1.55, -0.45)
        crate(m, 1.55, -0.45, 0.8, z=0.3, rz=0.3)
        m.box((0.8, 0.5, 0.12), pos=(-1.6, 0.3, 0), color="WOOD")                       # hay on a pallet
        m.sphere(0.32, pos=(-1.6, 0.3, 0.2), scl=(1.25, 0.8, 0.55), color="CROP_RIPE", seg=8, rings=4, lumps=0.2,
                 group="body_nl")
    house("storehouse", 2.6, 1.6, 1.35, 1.25, 0.0, [], None, 31, walls=("plank", BARN_RED), roof="tile_front",
          roof_col=SHINGLE, roof_under=SHINGLE_UNDER, boxes=False, side_win=False, steps=0, extras=ex).export(OUT)


def build_well():
    m = Model("well", 41)
    m.cyl(0.46, 0.44, 0.5, color="STONE", seg=12, smooth=False)
    for k in range(7):
        a = -math.pi / 2 + (k - 3) * 0.42 + (0.1 if k % 2 else 0)
        z = 0.1 + (k % 3) * 0.12
        m.box((0.16, 0.03, 0.09), pos=(math.cos(a) * 0.455, math.sin(a) * 0.455, z), rot=(0, 0, a + math.pi / 2),
              color=shade("STONE", 0.9 if k % 2 else 1.05))
    m.cyl(0.5, 0.5, 0.09, pos=(0, 0, 0.5), color="STONE_DARK", seg=12, cap="STONE")
    m.cyl(0.33, 0.33, 0.02, pos=(0, 0, 0.58), color="WATER", seg=8)
    for sx in (-1, 1):
        post(m, sx * 0.42, 0, 1.25, 0.1)
    m.cyl(0.04, 0.04, 0.95, pos=(-0.47, 0, 0.98), rot=(0, math.pi / 2, 0), color="WOOD", seg=6)   # windlass
    m.box((0.04, 0.2, 0.04), pos=(0.52, -0.1, 0.96), color="WOOD")
    m.box((0.015, 0.015, 0.35), pos=(0, 0, 0.62), color="WOOD_DARK")                                 # rope
    m.cyl(0.09, 0.08, 0.14, pos=(0, 0, 0.6), color="WOOD", seg=8, cap="WATER")                         # bucket
    m.box((1.0, 0.1, 0.08), pos=(0, 0, 1.2), color="WOOD_DARK")
    bun_roof(m, 0.84, 0.5, 1.24, 0.42, ox=0.12, oy=0.18, hip=0.75, NT=14, NU=4, roll=0.05, wobble=0.02, seed=41,
             bands=())
    for sx in (-1, 1):
        m.sphere(0.12, pos=(sx * 0.62, -0.32, 0.1), color="BUSH", seg=6, rings=3, lumps=0.2)
    m.export(OUT)


def build_woodpile():
    """Woodpile shed (기준 그림의 장작 헛간) — also used beside the woodcutter."""
    m = Model("woodpile", 51)
    W, D, H = 1.4, 0.75, 0.95
    for x in (-W / 2, W / 2):
        post(m, x, -D / 2, H)
        post(m, x, D / 2, H + 0.2)
    ln = math.hypot(D + 0.3, 0.2)
    m.box((W + 0.3, ln, 0.07), pos=(0, 0, H + 0.08), rot=(-math.atan2(0.2, D + 0.3), 0, 0), color="WOOD")
    for k in range(5):
        m.box((0.03, ln + 0.01, 0.075), pos=(-W / 2 - 0.15 + (k + 0.5) * (W + 0.3) / 5, 0, H + 0.085),
              rot=(-math.atan2(0.2, D + 0.3), 0, 0), color="WOOD_DARK")
    m.box((W, 0.06, 0.06), pos=(0, D / 2, 0.02), color="WOOD_DARK")
    r = 0.105
    for row in range(4):
        n = 6 - row
        for i in range(n):
            x = -((n - 1) * 2 * r) / 2 + i * 2 * r
            m.cyl(r, r, D - 0.05, pos=(x, -D / 2 + 0.025, r + row * r * 1.75), rot=(-math.pi / 2, 0, 0),
                  color="TRUNK", seg=7, cap="STUMP_TOP", bottom_cap="STUMP_TOP")
    m.export(OUT)


def build_chopblock():
    """Stump with an axe + a couple of split logs (woodcutter yard)."""
    m = Model("chopblock", 52)
    m.cyl(0.24, 0.27, 0.3, color="TRUNK", seg=9, cap="STUMP_TOP", smooth=True)
    m.box((0.05, 0.05, 0.42), pos=(0.02, 0, 0.3), rot=(0.5, 0, 0.3), color="WOOD")
    m.box((0.16, 0.03, 0.1), pos=(0.0, 0.08, 0.27), rot=(0.5, 0, 0.3), color="ROCK_DARK")
    log(m, 0.45, 0.2, 0.0, 0.5, 0.09, 0.4)
    log(m, 0.5, -0.12, 0.0, 0.45, 0.08, -0.3)
    m.export(OUT)


def build_planter():
    """Forester's sapling bed."""
    m = Model("planter", 53)
    m.box((1.2, 0.5, 0.18), color="WOOD")
    m.box((1.1, 0.4, 0.04), pos=(0, 0, 0.16), color="FIELD_SOIL")
    for i in range(5):
        x = -0.44 + i * 0.22
        m.cyl(0.02, 0.02, 0.22, pos=(x, 0, 0.18), color="TRUNK", seg=4)
        m.sphere(0.1, pos=(x, 0, 0.42), color="LEAF_YOUNG" if i % 2 else "LEAF_TOP", seg=7, rings=4, lumps=0.25)
    m.export(OUT)


def build_sawmill():
    """제재소 (v3): open plank-roofed shed at the back, a tall frame saw cutting a log on the bench in front,
    a log ramp sloping up from the right, a stack of fresh planks on the left."""
    m = Model("sawmill", 61)
    W, D, H = 2.2, 1.1, 1.15
    m.box((W + 0.4, D + 1.4, 0.06), pos=(0, -0.45, 0), color=shade("PATH", 0.95))
    y0 = 0.35
    for x in (-W / 2, W / 2):
        for y in (y0 - D / 2, y0 + D / 2):
            post(m, x, y, H, 0.12)
    m.box((W, 0.08, H - 0.1), pos=(0, y0 + D / 2, 0.06), color="WOOD")             # back wall
    for i in range(10):
        m.box((W / 10 - 0.02, 0.02, H - 0.15), pos=(-W / 2 + (i + 0.5) * W / 10, y0 + D / 2 - 0.05, 0.08),
              color=shade("WOOD", 0.92 if i % 2 else 1.05))
    for y in (y0 - D / 2, y0 + D / 2):
        m.box((W + 0.1, 0.1, 0.1), pos=(0, y, H - 0.08), color="WOOD_DARK")
    rotated(m, lambda: plank_roof(m, W, D, H, 0.45, col=SHINGLE, over=0.2), 0.0, (0, y0, 0))
    # sawdust heap + tool rack under the shed
    m.sphere(0.25, pos=(0.7, y0 + 0.1, 0.0), scl=(1.3, 1.0, 0.5), color="e9d3a4", seg=8, rings=4, lumps=0.2,
             group="body_nl")
    # bench + log + tall frame saw in front
    by = -0.55
    m.box((1.5, 0.36, 0.38), pos=(-0.1, by, 0.0), color="WOOD")
    log(m, -0.1, by, 0.5, 1.5, 0.13)
    for dx in (-0.32, 0.32):
        m.box((0.1, 0.1, 1.9), pos=(-0.1 + dx, by, 0.0), color="WOOD_DARK")
    m.box((0.82, 0.12, 0.12), pos=(-0.1, by, 1.85), color="WOOD_DARK")
    m.box((0.56, 0.06, 0.08), pos=(-0.1, by, 1.2), color="WOOD")                    # saw sash
    m.box((0.56, 0.06, 0.08), pos=(-0.1, by, 0.66), color="WOOD")
    m.box((0.035, 0.04, 0.62), pos=(-0.1, by, 0.66), color="dfe6e6")               # blade
    m.cyl(0.1, 0.1, 0.06, pos=(0.27, by - 0.07, 1.62), rot=(math.pi / 2, 0, 0), color="WOOD_DARK", seg=8)   # pulley
    # log ramp from the right: two sloping rails with logs on it
    for dy in (-0.25, 0.25):
        m.box((1.2, 0.07, 0.07), pos=(1.25, by + dy, 0.18), rot=(0, 0.3, 0), color="WOOD_DARK")
    for k in range(3):
        x = 1.0 + k * 0.33
        log(m, x, by, 0.43 - k * 0.1, 0.75, 0.11, 1.57)
    # fresh plank stack (left)
    for k in range(5):
        m.box((0.95, 0.3, 0.06), pos=(-1.35 + (k % 2) * 0.03, -1.05, k * 0.065), rot=(0, 0, 0.12),
              color=shade("PLANK", 1.0 if k % 2 else 0.92))
    m.export(OUT)


def build_quarry():
    m = Model("quarry", 71)
    r = m.rng

    def moss_top(f):
        return "MOSS" if f.normal.z > 0.75 else None

    # blocky rock face at the back: columns of cut stone with moss on top
    for i in range(6):
        x = -1.2 + i * 0.48
        h = r.uniform(0.9, 1.5)
        w = r.uniform(0.42, 0.55)
        y = 0.55 + r.uniform(-0.1, 0.12)
        rz = r.uniform(-0.15, 0.15)
        col = shade("ROCK", r.choice((0.95, 1.0, 1.06)))
        mossy = i % 3 == 1
        m.box((w, 0.7, h), pos=(x, y, 0), rot=(0, 0, rz), color=col,
              colfn=lambda f, c=col, mo=mossy: "MOSS" if (mo and f.normal.z > 0.75) else (shade(c, 1.08) if f.normal.z > 0.75 else c))
    for i in range(2):
        m.ico(0.26, pos=(-0.9 + i * 1.5, 0.85, 1.3), scl=(1.3, 1.0, 0.5), color="MOSS", subdiv=2, smooth=True, lumps=0.2)
    # cut blocks in front
    for (x, y, s, rz) in ((-0.6, -0.35, 0.36, 0.2), (-0.2, -0.55, 0.3, -0.3), (0.45, -0.3, 0.4, 0.1), (0.5, -0.3, 0.3, 0.5)):
        z = 0.4 if (x, y, s, rz) == (0.5, -0.3, 0.3, 0.5) else 0.0
        m.box((s * 1.2, s, s), pos=(x, y, z), rot=(0, 0, rz), color="STONE")
    # A-frame crane with rope and block
    for sx in (-1, 1):
        m.box((0.08, 0.08, 1.5), pos=(0.95 + sx * 0.3, -0.1, 0), rot=(0, sx * -0.2, 0), color="WOOD")
    m.box((0.75, 0.08, 0.08), pos=(0.95, -0.1, 1.42), color="WOOD_DARK")
    m.box((0.015, 0.015, 0.75), pos=(0.95, -0.1, 0.68), color="WOOD_DARK")
    m.box((0.3, 0.3, 0.25), pos=(0.95, -0.1, 0.42), color="STONE")
    for i in range(5):
        m.ico(0.1, pos=(r.uniform(-1.3, 1.3), r.uniform(-0.9, -0.5), 0.03), color="ROCK_DARK", subdiv=1)
    m.export(OUT)


def build_windmill():
    m = Model("windmill", 81)
    m.cyl(0.78, 0.56, 2.1, color="STONE", seg=12, smooth=True)
    m.cyl(0.84, 0.84, 0.14, color="STONE_DARK", seg=12)
    for k in range(10):
        a = k * 0.9
        z = 0.3 + (k % 5) * 0.34
        rr = 0.78 - (0.22 * z / 2.1) + 0.005
        m.box((0.18, 0.03, 0.1), pos=(math.cos(a) * rr, math.sin(a) * rr, z), rot=(0, 0, a + math.pi / 2), color=shade("STONE", 0.9))
    # round thatched cap (A19): a bun with equal sides = a puffy dome
    bun_roof(m, 1.12, 1.12, 2.08, 0.95, ox=0.1, oy=0.1, hip=1.0, n=2.0, NT=24, seed=81, bands=(0.45,))
    m.sphere(0.09, pos=(0, 0, 3.02), color="WOOD_DARK", seg=6, rings=3)
    door(m, 0.0, -0.76, w=0.34, h=0.55)
    window(m, 0.0, 1.35, -0.64, w=0.22, h=0.22)
    # sails on a hub facing front (-y)
    hub = Vector((0, -0.72, 2.0))
    m.cyl(0.09, 0.09, 0.3, pos=(0, -0.45, 2.0), rot=(math.pi / 2, 0, 0), color="WOOD_DARK", seg=8)
    for k in range(4):
        a = k * math.pi / 2 + 0.35
        d = Vector((math.cos(a), 0, math.sin(a)))
        c = hub + d * 0.85
        m.box((1.7, 0.05, 0.07), pos=(c.x, hub.y - 0.03, c.z - 0.035), rot=(0, -a, 0), color="WOOD_DARK")
        side = Vector((-d.z, 0, d.x))
        sc = hub + d * 1.0 + side * 0.17
        m.box((1.05, 0.03, 0.3), pos=(sc.x, hub.y - 0.01, sc.z - 0.15), rot=(0, -a, 0), color="PLASTER")
        for t in (0.55, 1.0, 1.45):
            lc = hub + d * t + side * 0.17
            m.box((0.03, 0.04, 0.32), pos=(lc.x, hub.y - 0.04, lc.z - 0.16), rot=(0, -a, 0), color="WOOD")
    for x in (-0.95, -0.6, 0.6, 0.95):
        post(m, x, -1.0, 0.35, 0.06, "WOOD")
    m.box((0.5, 0.04, 0.05), pos=(-0.78, -1.0, 0.24), color="WOOD")
    m.box((0.5, 0.04, 0.05), pos=(0.78, -1.0, 0.24), color="WOOD")
    m.export(OUT)


def build_bakery():
    """빵집 (v3): warm brick bakehouse, red tile gable to the front, a big domed brick oven on the right with a glowing
    mouth and its own smoking chimney, a hanging bread sign, a bread table under a striped awning."""
    def extras(m):
        # domed brick oven on the +x side
        ox, oy = 1.4, 0.05
        m.box((0.95, 0.95, 0.35), pos=(ox, oy, 0), color="STONE")
        m.sphere(0.5, pos=(ox, oy, 0.35), scl=(1, 1, 0.9), color=BRICK, seg=12, rings=6,
                 colfn=lambda f: BRICK_DARK if (int(f.calc_center_median().z * 9) % 2) else BRICK)
        m.cyl(0.2, 0.2, 0.1, pos=(ox, oy - 0.45, 0.36), rot=(math.pi / 2, 0, 0), color="FLAME", seg=8)
        m.cyl(0.12, 0.12, 0.11, pos=(ox, oy - 0.46, 0.33), rot=(math.pi / 2, 0, 0), color="FLAME2", seg=8)
        m.box((0.5, 0.12, 0.08), pos=(ox, oy - 0.52, 0.25), color="STONE_DARK")
        m.cyl(0.1, 0.09, 0.55, pos=(ox + 0.12, oy + 0.2, 0.7), color=BRICK_DARK, seg=7, cap=SOOT)
        smoke(m, ox + 0.12, oy + 0.2, 1.2, 3)
        # peel leaning on the oven + firewood
        m.box((0.04, 0.04, 1.0), pos=(ox + 0.55, oy - 0.35, 0.0), rot=(0, -0.35, 0), color="WOOD")
        for k in range(3):
            log(m, ox + 0.15, oy + 0.65, 0.08 + k * 0.15, 0.55, 0.07, 1.57)
        # hanging bread sign on a bracket (front-left corner)
        sx, sy = -1.12, -0.7
        m.box((0.06, 0.06, 1.45), pos=(sx, sy, 0), color="WOOD_DARK")
        m.box((0.42, 0.05, 0.05), pos=(sx - 0.18, sy, 1.4), color="WOOD_DARK")
        m.box((0.36, 0.05, 0.3), pos=(sx - 0.24, sy, 1.02), color="f3e2bf")
        m.box((0.4, 0.04, 0.34), pos=(sx - 0.24, sy + 0.01, 1.0), color="WOOD")
        m.sphere(0.11, pos=(sx - 0.24, sy - 0.04, 1.17), scl=(1.3, 0.5, 0.75), color="BREAD", seg=8, rings=4)
        # awning + table with loaves at the front
        m.box((1.0, 0.6, 0.05), pos=(-0.35, -1.0, 0.95), rot=(-0.35, 0, 0), color="PLASTER")
        for k in range(4):
            m.box((0.11, 0.62, 0.055), pos=(-0.74 + k * 0.27, -1.0, 0.955), rot=(-0.35, 0, 0), color="ROOF_RED")
        for x in (-0.82, 0.12):
            post(m, x, -1.27, 0.85, 0.06, "WOOD")
        m.box((0.85, 0.36, 0.06), pos=(-0.35, -1.1, 0.42), color="WOOD")
        for x in (-0.68, -0.02):
            post(m, x, -1.1, 0.42, 0.06, "WOOD_DARK")
        for k in range(3):
            m.sphere(0.12, pos=(-0.6 + k * 0.25, -1.1, 0.53), scl=(1.2, 0.9, 0.7), color="BREAD", seg=8, rings=5)
        barrel(m, 1.0, -0.85, 0.8)
    m = house("bakery", 2.0, 1.3, 1.3, 1.15, 0.35, [-0.35], (-0.55, 0.3), 91, extras=extras, walls=("brick", BRICK),
              roof="tile_front", roof_col=TILE, roof_under=TILE_UNDER, shutter=SHUTTER[0], boxes=False)
    smoke(m, -0.55, 0.3, 2.65, 2)
    m.export(OUT)


def build_forester():
    """묘목원 (산림관, v3): a steep A-frame tool shed (bark roof down to the ground, plank gable with a green door)
    between rows of sapling beds; watering can, little picket fence. Reads as 'nursery', not 'house'."""
    m = Model("forester", 101)
    L, B, T = 1.4, 0.78, 1.75
    tri = [(-B + 0.06, 0.0), (B - 0.06, 0.0), (0.0, T - 0.08)]
    m.prism(tri, L, rot=(0, 0, math.pi / 2), color="WOOD", cap_color=shade("PLANK", 0.95))
    ang = math.atan2(T, B)
    sl = math.hypot(B, T) + 0.2
    for sx in (-1, 1):
        m.box((sl, L + 0.3, 0.1), pos=(sx * (B / 2 + 0.04), 0, T / 2 - 0.12), rot=(0, sx * ang, 0), color=BARK,
              colfn=lambda f: shade(BARK, 1.08) if f.normal.z > 0.2 else BARK_UNDER)
        for k in range(3):                                    # shingle courses
            t = 0.25 + k * 0.25
            m.box((0.04, L + 0.32, 0.12), pos=(sx * (B * (1 - t) + 0.07), 0, T * t - 0.1), rot=(0, sx * ang, 0),
                  color=shade(BARK, 0.85))
    m.box((0.16, L + 0.36, 0.14), pos=(0, 0, T - 0.06), color=shade(BARK, 0.8))
    for k in range(3):
        m.sphere(0.09, pos=((-1) ** k * 0.32, -0.3 + k * 0.3, T * 0.55), scl=(1.5, 1.2, 0.5), color="MOSS", seg=6,
                 rings=3, lumps=0.2, group="body_nl")
    # green door + round window in the front gable
    door(m, 0.0, -L / 2, w=0.38, h=0.72, col="6f9a5a")
    m.cyl(0.11, 0.11, 0.04, pos=(0, -L / 2 - 0.01, 1.08), rot=(math.pi / 2, 0, 0), color="WOOD_DARK", seg=10)
    m.cyl(0.08, 0.08, 0.05, pos=(0, -L / 2 - 0.02, 1.08), rot=(math.pi / 2, 0, 0), color="WINDOW_LIT", seg=10)
    # sapling beds: two long rows on the left, one on the right
    def bed(x, y, n, ln):
        m.box((0.42, ln, 0.16), pos=(x, y, 0), color="WOOD")
        m.box((0.36, ln - 0.06, 0.04), pos=(x, y, 0.14), color="FIELD_SOIL")
        for i in range(n):
            yy = y - ln / 2 + (i + 0.5) * ln / n
            h = 0.14 + 0.05 * ((i * 7) % 3)
            m.cyl(0.018, 0.018, h, pos=(x, yy, 0.17), color="TRUNK", seg=4)
            m.sphere(0.075 + 0.02 * ((i * 5) % 3), pos=(x, yy, 0.2 + h), color=("LEAF_YOUNG", "LEAF_TOP", "8fd07e")[i % 3],
                     seg=6, rings=4, lumps=0.25, group="body_nl")
    bed(-1.15, -0.1, 5, 1.5)
    bed(-1.7, -0.1, 5, 1.5)
    bed(1.2, 0.1, 4, 1.2)
    # seedling trays + watering can at the front right
    for k in range(2):
        m.box((0.36, 0.26, 0.08), pos=(0.95 + k * 0.4, -0.95, 0), color="WOOD")
        for j in range(3):
            m.sphere(0.05, pos=(0.85 + k * 0.4 + j * 0.1, -0.95, 0.11), color="LEAF_YOUNG", seg=5, rings=3, group="body_nl")
    m.cyl(0.09, 0.08, 0.16, pos=(0.55, -0.95, 0), color="7d9a9e", seg=8, cap="WATER")
    m.cyl(0.015, 0.015, 0.22, pos=(0.62, -0.95, 0.08), rot=(0, 1.0, 0), color="7d9a9e", seg=4)
    picket_fence(m, -1.95, -1.05, -0.95, -1.05, h=0.32)
    m.export(OUT)


def build_saltpan():
    m = Model("saltpan", 111)
    for i in range(2):
        for j in range(2):
            x, y = -0.55 + i * 1.1, -0.5 + j * 1.05
            m.box((1.0, 0.95, 0.12), pos=(x, y, 0), color="STONE")
            m.box((0.82, 0.77, 0.02), pos=(x, y, 0.11), color="SALT" if (i + j) % 2 else mix("WATER", "SALT", 0.6))
    for (x, y, s) in ((1.25, -0.8, 1.0), (1.45, -0.45, 0.7), (-1.25, 0.9, 0.8)):
        m.cyl(0.32 * s, 0.02, 0.38 * s, pos=(x, y, 0), color="SALT", seg=9, smooth=True)
    # little shelter
    for x in (-0.35, 0.35):
        for y in (0.95, 1.45):
            post(m, x - 0.5, y, 0.75, 0.07)
    plank_roof(m, 0.7, 0.5, 0.75, 0.3)
    for k in range(2):
        m.cyl(0.13, 0.11, 0.12, pos=(-0.68 + k * 0.32, 1.2, 0), color="WOOD", seg=8, cap="SALT")
    # rake
    m.box((0.035, 0.035, 1.0), pos=(1.0, 0.2, 0.05), rot=(0.0, 0.9, 0.3), color="WOOD")
    m.box((0.3, 0.05, 0.04), pos=(1.38, 0.32, 0.02), rot=(0, 0, 0.3), color="WOOD_DARK")
    m.export(OUT)


# ───────────────────────── fields ─────────────────────────
def build_field(name, ripe):
    m = Model(name, 121)
    S = 3.4
    m.box((S, S, 0.08), color="FIELD_SOIL")
    r = m.rng
    crop = "CROP_RIPE" if ripe else "CROP"
    rows = 6
    for i in range(rows):
        y = -S / 2 + 0.35 + i * (S - 0.7) / (rows - 1)
        m.box((S - 0.45, 0.34, 0.05), pos=(0, y, 0.06), color=shade("FIELD_SOIL", 0.86))
        # one crop row = a zig-zag ridge lofted along X: tall ears / short gaps alternate -> reads as many stalks
        n = 28
        x0, x1 = -S / 2 + 0.32, S / 2 - 0.32
        rings = []
        for k in range(n + 1):
            x = x0 + (x1 - x0) * k / n
            tall = k % 2 == 0
            h = (r.uniform(0.44, 0.56) if tall else r.uniform(0.3, 0.36)) if ripe else \
                (r.uniform(0.26, 0.32) if tall else r.uniform(0.18, 0.22))
            if k in (0, n):
                h *= 0.6
            w = 0.16 if ripe else 0.15
            dy = r.uniform(-0.025, 0.025)
            wt = w * (0.45 if tall else 0.7)
            rings.append([Vector((x, y + dy - w, 0.1)), Vector((x, y + dy - wt, 0.1 + h * 0.86)),
                          Vector((x, y + dy, 0.1 + h)), Vector((x, y + dy + wt, 0.1 + h * 0.86)),
                          Vector((x, y + dy + w, 0.1))])
        base_c = "CROP_RIPE" if ripe else "CROP"
        stem_c = mix("CROP_RIPE", "CROP", 0.45) if ripe else shade("CROP", 0.86)

        def rc(f, base_c=base_c, stem_c=stem_c):
            c = f.calc_center_median()
            if c.z > 0.1 + (0.36 if ripe else 0.2):
                return shade(base_c, 1.1 if ripe else 1.06)
            return base_c if c.z > 0.1 + (0.2 if ripe else 0.1) else stem_c
        fs = m.strip(rings, color=base_c, caps=True, group="body_nl")
        bm = m._bm("body_nl")
        bmesh.ops.recalc_face_normals(bm, faces=fs)
        bm.normal_update()
        for f in fs:
            m._finish(bm, [f], rc(f), False)
    # fence with a gap (gate) at the front
    F = S / 2 + 0.12
    pts = []
    n = 5
    for k in range(n + 1):
        t = -F + 2 * F * k / n
        pts += [(t, -F), (t, F), (-F, t), (F, t)]
    for (x, y) in sorted(set((round(a, 3), round(b, 3)) for a, b in pts)):
        if abs(y + F) < 0.01 and abs(x) < 0.3:
            continue
        m.box((0.1, 0.1, 0.55), pos=(x, y, 0), color="WOOD")
        m.box((0.13, 0.13, 0.04), pos=(x, y, 0.55), color="WOOD_DARK")
    for z in (0.22, 0.42):
        for sy in (-1, 1):
            if sy < 0:
                for sx in (-1, 1):
                    m.box((F - 0.3, 0.05, 0.06), pos=(sx * (F + 0.3) / 2, -F, z), color=shade("WOOD", 1.12))
            else:
                m.box((2 * F, 0.05, 0.06), pos=(0, F, z), color=shade("WOOD", 1.12))
            m.box((0.05, 2 * F, 0.06), pos=(sy * F, 0, z), color=shade("WOOD", 1.12))
    m.export(OUT)


# ───────────────────────── water crossings ─────────────────────────
def build_pier():
    """Wooden pier along +X from the shore (origin, ground level) out over the water. Deck at z = 0.18."""
    m = Model("pier", 131)
    L, Wd = 3.0, 0.95
    n = int(L / 0.24)
    for i in range(n):
        x = 0.12 + i * L / n
        m.box((L / n - 0.025, Wd, 0.07), pos=(x + 0.1, 0, 0.18), color=shade("PLANK", (0.92, 1.0, 1.06)[i % 3]))
    for sy in (-1, 1):
        m.box((L, 0.08, 0.08), pos=(L / 2 + 0.1, sy * (Wd / 2 - 0.04), 0.1), color="WOOD")
    for x in (0.25, L / 2 + 0.1, L):
        for sy in (-1, 1):
            m.cyl(0.07, 0.07, 1.45, pos=(x, sy * (Wd / 2 + 0.02), -1.1), color="WOOD_DARK", seg=7, cap="STUMP_TOP")
    m.cyl(0.13, 0.12, 0.24, pos=(L - 0.25, 0.2, 0.25), color="WOOD", seg=8, cap="WATER")    # bucket
    m.export(OUT)


def build_bridge():
    """Small stone arch bridge spanning X (river runs along Y). Origin = centre, ground level."""
    m = Model("bridge", 141)
    span, half_w, top = 1.9, 0.62, 0.42
    prof = []
    # outline in (x, z): left foot -> up -> humped deck -> right foot -> arch underside back
    prof.append((-span, -0.5))
    for k in range(9):
        t = k / 8
        x = -span + 2 * span * t
        prof.append((x, top + 0.18 * math.sin(math.pi * t) - (0.12 if k in (0, 8) else 0)))
    prof.append((span, -0.5))
    ar = 0.8
    for k in range(9):
        a = k / 8 * math.pi
        prof.append((ar * math.cos(a), -0.5 + ar * 0.75 * math.sin(a)))
    # prism extrudes along local X; rotate so the profile lies in world XZ and the width is along Y
    yz = [(x, z) for x, z in prof]
    faces = m.prism(yz, 2 * half_w, rot=(0, 0, math.pi / 2), color="STONE")
    # deck faces facing up -> path colour
    for f in faces:
        if f.normal.z > 0.6:
            m._finish(m._bm("body"), [f], "PATH", False)
    # parapets
    for sy in (-1, 1):
        for k in range(4):
            t0, t1 = k / 4, (k + 1) / 4
            x0, x1 = -span + 2 * span * t0, -span + 2 * span * t1
            z0 = top + 0.18 * math.sin(math.pi * t0)
            z1 = top + 0.18 * math.sin(math.pi * t1)
            ln = math.hypot(x1 - x0, z1 - z0)
            m.box((ln + 0.04, 0.14, 0.2), pos=((x0 + x1) / 2, sy * (half_w - 0.07), (z0 + z1) / 2 - 0.02),
                  rot=(0, -math.atan2(z1 - z0, x1 - x0), 0), color=shade("STONE", 0.95 if k % 2 else 1.04))
    # voussoir stones round the arch on both faces
    for sy in (-1, 1):
        for k in range(7):
            a = (k + 0.5) / 7 * math.pi
            x, z = (ar + 0.08) * math.cos(a), -0.5 + (ar * 0.75 + 0.08) * math.sin(a)
            m.box((0.16, 0.03, 0.12), pos=(x, sy * (half_w + 0.012), z - 0.06), rot=(0, -(a - math.pi / 2), 0),
                  color=shade("STONE", 0.88))
    m.export(OUT)


if __name__ == "__main__":
    print("buildings ->", OUT)
    build_cottages()
    build_houses()
    build_store()
    build_well()
    build_woodpile()
    build_chopblock()
    build_planter()
    build_sawmill()
    build_quarry()
    build_windmill()
    build_bakery()
    build_forester()
    build_saltpan()
    build_field("field_green", False)
    build_field("field_ripe", True)
    build_pier()
    build_bridge()
