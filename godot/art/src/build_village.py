"""Village-era buildings (ROADMAP A6, BUILDINGS 3.1) + the mushroom-picker's hut (버섯꾼).
Same kit / style as build_buildings.py (round 'bun' thatch, plaster colours, timber frames). Sizes follow
BUILDINGS 3.2: small (1 cell) ~1.6-2.0 wide, medium (2 cells) ~2.4-2.8, large (4 cells) ~3.4-4.2.
Run: blender -b --factory-startup --python build_village.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, out_dir_from_argv  # noqa: E402
from build_buildings import (  # noqa: E402
    house, bun_roof, tile_roof, gable_wall, rotated, framed_walls, stone_walls, plank_walls, door, window, chimney,
    barrel, sack, crate, post, log, picket_fence, lantern, flower_box, round_bush, herb_bundle, stepping_stones,
    shutters, SHUTTER, CREAM, OCHRE, ROSE, LIME, GOLD, GOLD_UNDER, MOSSY, MOSSY_UNDER, OLD, OLD_UNDER, TILE, TILE_UNDER,
    STEP)
import bmesh  # noqa: E402

OUT = out_dir_from_argv()
BONE = "efe3c8"
HIDE = "b98a5e"
FISH = "9fb8c4"
CLOTH = "fbf8f0"
BLANKET = ("9cc3d6", "b7d39a", "efc9bd")
LAVENDER = "a98ad0"
BELL = "e2b44e"
IRON = "5d6466"
WOOL = "f6f1e6"
YARN = ("5f7c96", "c8644e", "efc35a", "7d9a62")
SLATE = "7f8c8c"
SLATE_UNDER = "5f6a6a"
TEAL_WOOD = "86a3a0"


# ───────────────────────── small props ─────────────────────────
def boat(m, x, y, rz=0.0, L=1.15, w=0.32, h=0.2, col="WOOD"):
    """Little rowing boat: lofted U hull (outer + darker inner skin), seat plank, pointed ends."""
    c, s = math.cos(rz), math.sin(rz)

    def P(px, py, pz):
        return Vector((x + px * c - py * s, y + px * s + py * c, pz))
    K = 7
    outer, inner = [], []
    for k in range(K + 1):
        t = k / K
        taper = max(0.04, math.sin(math.pi * t) ** 0.6)
        xx = -L / 2 + L * t
        lift = 0.05 * (abs(t - 0.5) * 2) ** 2
        sec = [(-1.0, 1.0), (-0.85, 0.35), (0.0, 0.0), (0.85, 0.35), (1.0, 1.0)]
        outer.append([P(xx, sy * w * taper, sz * h + lift) for sy, sz in sec])
        inner.append([P(xx, sy * (w * taper - 0.03), sz * (h - 0.03) + lift + 0.03) for sy, sz in reversed(sec)])
    bm = m._bm("body")
    fo = m.strip(outer, color=col)
    fi = m.strip(inner, color="PLANK")
    for f in fo:
        if f.normal.z > 0.5:
            f.normal_flip()
    bm.normal_update()
    m.box((0.08, w * 1.6, 0.03), pos=tuple(P(0.05, 0, h * 0.6)), rot=(0, 0, rz), color=shade(col, 1.2))
    for f in fo:
        m._finish(bm, [f], col if f.calc_center_median().z > y * 0 + h * 0.55 else shade(col, 0.88), True)
    # bright rim stripe
    m.box((L * 0.7, 0.025, 0.035), pos=tuple(P(0, -w + 0.012, h - 0.02)), rot=(0, 0, rz), color="f2d06b")
    m.box((L * 0.7, 0.025, 0.035), pos=tuple(P(0, w - 0.012, h - 0.02)), rot=(0, 0, rz), color="f2d06b")


def fish(m, x, y, z, col=FISH):
    m.sphere(0.06, pos=(x, y, z), scl=(0.45, 0.3, 1.0), color=col, seg=6, rings=4)
    m.cyl(0.05, 0.0, 0.06, pos=(x, y, z - 0.04), rot=(math.pi, 0, 0), color=shade(col, 0.85), seg=3)


def drying_rack(m, x0, x1, y, h=0.85, hang=None):
    for x in (x0, x1):
        post(m, x, y, h, 0.06, "WOOD")
    m.cyl(0.025, 0.025, x1 - x0 + 0.1, pos=(x0 - 0.05, y, h - 0.04), rot=(0, math.pi / 2, 0), color="WOOD_DARK", seg=5)
    n = max(2, int((x1 - x0) / 0.16))
    for k in range(n):
        px = x0 + (k + 0.5) * (x1 - x0) / n
        if hang:
            hang(px, y, h - 0.06, k)


def pot(m, x, y, s=1.0, plant="BUSH", flower=None):
    m.cyl(0.1 * s, 0.075 * s, 0.17 * s, pos=(x, y, 0), color="ROOF_RED", seg=7, cap="FIELD_SOIL")
    m.sphere(0.11 * s, pos=(x, y, 0.22 * s), color=plant, seg=7, rings=4, lumps=0.2, group="body_nl")
    if flower:
        m.sphere(0.035 * s, pos=(x + 0.03, y - 0.06 * s, 0.3 * s), color=flower, seg=5, rings=3, group="body_nl")


def bed(m, x, y, rz=0.0, blanket=BLANKET[0]):
    """Small cot: wooden frame, white mattress + pillow, coloured blanket over the lower half."""
    def R(px, py):
        c, s = math.cos(rz), math.sin(rz)
        return (x + px * c - py * s, y + px * s + py * c)
    m.box((0.42, 0.78, 0.2), pos=(*R(0, 0), 0), rot=(0, 0, rz), color="WOOD")
    m.box((0.38, 0.74, 0.07), pos=(*R(0, 0), 0.2), rot=(0, 0, rz), color=CLOTH)
    m.box((0.3, 0.16, 0.06), pos=(*R(0, 0.26), 0.26), rot=(0, 0, rz), color="ffffff")
    m.box((0.41, 0.42, 0.04), pos=(*R(0, -0.17), 0.26), rot=(0, 0, rz), color=blanket)
    m.box((0.46, 0.05, 0.36), pos=(*R(0, 0.39), 0), rot=(0, 0, rz), color="WOOD_DARK")


def line_with(m, x0, x1, y, h, items):
    """A washing line between two posts with things hung on it: items = [(colour, w, l)]."""
    for x in (x0, x1):
        post(m, x, y, h, 0.05, "WOOD")
    m.box((x1 - x0, 0.015, 0.015), pos=((x0 + x1) / 2, y, h - 0.05), color="WOOD_DARK")
    n = len(items)
    for k, (c, w, ln) in enumerate(items):
        px = x0 + (k + 0.5) * (x1 - x0) / n
        m.box((w, 0.025, ln), pos=(px, y, h - 0.05 - ln), color=c)


def bunting(m, a, b, z, sag=0.18, cols=("LOTUS", "FLAME2", "9cc3d6", "b7d39a", "ffffff"), n=7):
    """String of pennants between points a and b (x, y) at height z, sagging in the middle."""
    a, b = Vector((a[0], a[1], z)), Vector((b[0], b[1], z))
    d = b - a
    pts = []
    for k in range(n * 2 + 1):
        t = k / (n * 2)
        pts.append(a + d * t + Vector((0, 0, -sag * 4 * t * (1 - t))))
    for k in range(len(pts) - 1):
        p, q = pts[k], pts[k + 1]
        mid = (p + q) / 2
        ln = (q - p).length
        m.box((ln, 0.012, 0.012), pos=(mid.x, mid.y, mid.z - 0.006), rot=(0, -math.atan2(q.z - p.z, ln), math.atan2(q.y - p.y, q.x - p.x)),
              color="WOOD_DARK", group="body_nh")
    for k in range(n):
        p, q = pts[2 * k], pts[2 * k + 1]
        tip = (p + pts[2 * k + 2]) / 2 + Vector((0, 0, -0.17))
        bm = m._bm("body_nh")
        c = cols[k % len(cols)]
        v = [bm.verts.new(p), bm.verts.new(pts[2 * k + 2]), bm.verts.new(tip)]
        f1 = bm.faces.new(v)
        v2 = [bm.verts.new(x.co) for x in reversed(v)]
        f2 = bm.faces.new(v2)
        bm.normal_update()
        m._finish(bm, [f1, f2], c, False)


def hay_bale(m, x, y, rz=0.0, s=1.0):
    m.cyl(0.22 * s, 0.22 * s, 0.4 * s, pos=(x - math.cos(rz) * 0.2 * s, y - math.sin(rz) * 0.2 * s, 0.22 * s),
          rot=(0, math.pi / 2, rz), color="e9c46a", seg=9, smooth=True, cap="d9ae52", bottom_cap="d9ae52")


def rail_fence(m, x0, y0, x1, y1, h=0.5, step=0.7, gap=None, col="WOOD"):
    """Post-and-rail fence (pasture). gap = (t0, t1) fraction of the run left open (gate)."""
    d = Vector((x1 - x0, y1 - y0, 0))
    ln = d.length
    ang = math.atan2(d.y, d.x)
    n = max(1, int(round(ln / step)))
    for i in range(n + 1):
        t = i / n
        m.box((0.09, 0.09, h + 0.06), pos=(x0 + d.x * t, y0 + d.y * t, 0), rot=(0, 0, ang), color=shade(col, 0.9))
    spans = [(0.0, 1.0)] if gap is None else [(0.0, gap[0]), (gap[1], 1.0)]
    for (t0, t1) in spans:
        if t1 - t0 < 1e-3:
            continue
        cx, cy = x0 + d.x * (t0 + t1) / 2, y0 + d.y * (t0 + t1) / 2
        for z in (h * 0.42, h * 0.85):
            m.box((ln * (t1 - t0), 0.05, 0.065), pos=(cx, cy, z), rot=(0, 0, ang), color=shade(col, 1.12))


def headstone(m, x, y, rz=0.0, s=1.0, col="STONE", moss=False):
    m.box((0.3 * s, 0.1 * s, 0.32 * s), pos=(x, y, 0), rot=(0, 0, rz), color=col)
    m.cyl(0.15 * s, 0.15 * s, 0.1 * s, pos=(x - math.sin(rz) * 0.05 * s, y + math.cos(rz) * 0.05 * s, 0.32 * s),
          rot=(math.pi / 2, 0, rz), color=col, seg=8, smooth=True)
    if moss:
        m.sphere(0.07 * s, pos=(x, y, 0.42 * s), scl=(1.4, 0.9, 0.5), color="MOSS", seg=6, rings=3, group="body_nl")
    m.box((0.36 * s, 0.4 * s, 0.03), pos=(x - math.sin(rz) * -0.2 * s, y - 0.2 * s, 0), rot=(0, 0, rz),
          color=mix("b9d687", "8fc46c", 0.6))           # little grave mound turf


def stool(m, x, y, h=0.22):
    m.cyl(0.11, 0.11, 0.04, pos=(x, y, h), color="WOOD", seg=7, cap="STUMP_TOP")
    for k in range(3):
        a = k * math.tau / 3
        m.box((0.03, 0.03, h), pos=(x + math.cos(a) * 0.07, y + math.sin(a) * 0.07, 0), color="WOOD_DARK")


# ───────────────────────── small huts ─────────────────────────
def build_fisher():
    """어부 오두막: teal-grey plank hut, golden bun thatch, fish drying racks, a little boat, net and baskets."""
    def ex(m):
        def hang(px, y, z, k):
            fish(m, px, y, z - 0.05, FISH if k % 3 else "c9b38a")
        drying_rack(m, -1.55, -0.85, -0.35, 0.85, hang)
        drying_rack(m, -1.55, -0.85, 0.2, 0.8, hang)
        boat(m, 1.3, -0.35, rz=1.35, L=1.2)
        m.cyl(0.02, 0.02, 1.0, pos=(1.0, 0.25, 0.08), rot=(0, 1.35, 0.4), color="WOOD", seg=4)       # oar
        m.sphere(0.24, pos=(-0.9, -0.95, 0.06), scl=(1.3, 1.0, 0.45), color=mix("TUFT", "WOOD", 0.4), seg=8, rings=4,
                 lumps=0.35, group="body_nl")                                                         # heaped net
        for k in range(3):
            m.sphere(0.03, pos=(-1.08 + k * 0.17, -0.98 + 0.05 * k, 0.15), color="FLAME", seg=5, rings=3)   # floats
        m.cyl(0.15, 0.12, 0.2, pos=(0.62, -0.95, 0), color="d9b98a", seg=8, cap="WOOD_DARK")          # fish basket
        for k in range(2):
            fish(m, 0.58 + k * 0.08, -0.96, 0.24)
    house("fisher", 1.6, 1.15, 1.1, 1.05, -0.15, [0.4], None, 201, extras=ex, walls=("plank", TEAL_WOOD),
          roof_col=GOLD, roof_under=GOLD_UNDER, side_win=False, boxes=False, steps=1, shutter=SHUTTER[3]).export(OUT)


def build_hunter():
    """사냥꾼 오두막: dark log hut with mossy weathered thatch, antlers over the door, a hide on a stretching frame."""
    def ex(m):
        # log ends at the corners -> reads as a log cabin
        for sx in (-1, 1):
            for k in range(5):
                m.cyl(0.075, 0.075, 0.12, pos=(sx * 0.82, -0.6, 0.12 + k * 0.17), rot=(math.pi / 2, 0, 0),
                      color="TRUNK", seg=6, cap="STUMP_TOP", bottom_cap="STUMP_TOP")
        # antlers on a board beside the door
        cx, cz = -0.45, 0.72
        m.box((0.22, 0.03, 0.2), pos=(cx, -0.585, cz - 0.12), color="WOOD")
        m.box((0.16, 0.05, 0.12), pos=(cx, -0.62, cz - 0.06), color=BONE)
        for sx in (-1, 1):
            m.cyl(0.022, 0.016, 0.3, pos=(cx + sx * 0.05, -0.64, cz), rot=(0, sx * 0.9, 0), color=BONE, seg=4)
            tip = (cx + sx * 0.27, cz + 0.17)
            m.cyl(0.016, 0.01, 0.2, pos=(tip[0], -0.64, tip[1]), rot=(0, sx * 0.2, 0), color=BONE, seg=4)
            m.cyl(0.016, 0.01, 0.14, pos=(cx + sx * 0.17, -0.64, cz + 0.1), rot=(0, -sx * 0.3, 0), color=BONE, seg=4)
        # hide stretched on a frame (left)
        fx, fy = -1.35, -0.25
        for dx in (-0.35, 0.35):
            m.box((0.05, 0.05, 1.0), pos=(fx + dx, fy, 0), color="WOOD")
        for z in (0.2, 0.95):
            m.box((0.85, 0.05, 0.05), pos=(fx, fy, z), color="WOOD")
        pts = []
        for k in range(10):
            a = k / 10 * math.tau
            r = 0.27 + 0.05 * math.cos(a * 2) + 0.03 * math.sin(a * 5)
            pts.append(Vector((fx + math.cos(a) * r, fy - 0.03, 0.57 + math.sin(a) * r * 1.15)))
        f = m.poly(list(reversed(pts)), color=HIDE)
        m.poly(pts, color=shade(HIDE, 0.85))
        del f
        for k in range(4):
            a = k / 4 * math.tau + 0.4
            m.box((0.012, 0.012, 0.12), pos=(fx + math.cos(a) * 0.32, fy - 0.03, 0.57 + math.sin(a) * 0.36), color="WOOD_DARK")
        # woodpile of short logs + stump
        for k in range(3):
            log(m, 1.25, 0.15 + k * 0.0, 0.1 + k * 0.17, 0.6, 0.09, 1.57)
        m.cyl(0.18, 0.2, 0.25, pos=(1.1, -0.85, 0), color="TRUNK", seg=8, cap="STUMP_TOP", smooth=True)
        m.box((0.4, 0.06, 0.05), pos=(1.1, -0.86, 0.3), rot=(0, 0, 0.5), color="WOOD")              # bow on the stump
    house("hunter", 1.6, 1.15, 1.15, 1.0, 0.1, [0.5], (0.55, 0.1), 202, extras=ex, walls=("plank", "WOOD_DARK"),
          roof_col=OLD, roof_under=OLD_UNDER, moss=3, boxes=False, side_win=False, steps=1).export(OUT)


def build_herbalist():
    """약초꾼 오두막: pale rose cottage, mossy thatch, herb bundles under the eaves, pots and a lavender bed."""
    def ex(m):
        for k in range(6):
            herb_bundle(m, -0.75 + k * 0.3, -0.82, 1.1, ("7fb565", LAVENDER, "a6c46a", "d9b25a")[k % 4])
        m.box((0.035, 0.035, 1.7), pos=(-0.75, -0.82, 1.05), rot=(0, math.pi / 2, 0), color="WOOD_DARK")
        for k, (x, y, s, fl) in enumerate(((1.1, -0.75, 1.0, "LOTUS"), (1.3, -0.45, 0.8, None),
                                           (1.25, -1.0, 0.7, "FLAME2"), (-1.15, -0.9, 0.9, LAVENDER))):
            pot(m, x, y, s, plant=("BUSH", "a6c46a", "BUSH", "7fb565")[k], flower=fl)
        # raised herb bed on the left
        m.box((0.55, 1.0, 0.16), pos=(-1.3, 0.1, 0), color="WOOD")
        m.box((0.48, 0.92, 0.03), pos=(-1.3, 0.1, 0.15), color="FIELD_SOIL")
        for k in range(6):
            x = -1.42 + (k % 2) * 0.24
            y = -0.25 + (k // 2) * 0.33
            m.sphere(0.1, pos=(x, y, 0.24), scl=(1, 1, 0.9), color=("7fb565", "a6c46a")[k % 2], seg=6, rings=4,
                     lumps=0.25, group="body_nl")
            m.sphere(0.04, pos=(x + 0.02, y - 0.02, 0.33), color=(LAVENDER, "ffffff", "FLAME2")[k % 3], seg=5, rings=3,
                     group="body_nl")
        # mortar on a stool
        stool(m, 0.75, -1.0)
        m.cyl(0.07, 0.05, 0.08, pos=(0.75, -1.0, 0.26), color="STONE", seg=7, cap="7fb565")
    house("herbalist", 1.7, 1.15, 1.15, 1.1, 0.1, [-0.4], (0.5, 0.12), 203, extras=ex, walls=("framed", ROSE),
          roof_col=MOSSY, roof_under=MOSSY_UNDER, moss=2, boxes=True, shutter=SHUTTER[2], steps=1).export(OUT)


def build_mushroom_hut():
    """버섯꾼 오두막: round cream walls under a giant spotted mushroom cap, drying rack of mushroom slices."""
    m = Model("mushroom_hut", 204)
    R, H = 0.72, 1.2
    m.cyl(R + 0.06, R + 0.06, 0.12, color="STONE_DARK", seg=14)
    m.cyl(R, R * 0.96, H, pos=(0, 0, 0.0), color="MUSHROOM_STEM", seg=14, smooth=True)
    # timber ribs on the round wall
    for k in range(7):
        a = -math.pi / 2 + (k - 3) * 0.55
        m.box((0.06, 0.03, H - 0.1), pos=(math.cos(a) * (R + 0.005), math.sin(a) * (R + 0.005), 0.1),
              rot=(0, 0, a + math.pi / 2), color="WOOD")
    # cap: lathe of a dome with a rolled rim + cream gill underside
    cap_c = "MUSHROOM_CAP"
    Rc, zc, hc = 1.02, H + 0.0, 0.78
    prof = [(R * 0.9, zc + 0.12), (Rc * 0.9, zc - 0.08), (Rc, zc + 0.02), (Rc * 1.0, zc + 0.12)]
    for j in range(1, 7):
        a = j / 6 * math.pi / 2
        prof.append((Rc * math.cos(a) * (1 - 0.03 * j / 6), zc + 0.12 + hc * math.sin(a) ** 0.85))
    prof[-1] = (0.03, prof[-1][1])
    seg = 24
    rings = [[Vector((math.cos(i * math.tau / seg) * r, math.sin(i * math.tau / seg) * r, z)) for i in range(seg)]
             for r, z in prof]
    fs = m.strip(rings, close=True, smooth=True, color=cap_c)
    bm = m._bm("body")
    top = bm.faces.new([bm.verts.new(p) for p in rings[-1]])
    bmesh.ops.recalc_face_normals(bm, faces=fs + [top])
    bm.normal_update()
    for f in fs:
        c = f.calc_center_median()
        if c.z < zc + 0.05 and f.normal.z < 0:
            col = shade("MUSHROOM_DOT", 0.92 if int((math.atan2(c.y, c.x) + 4) * 6) % 2 else 1.0)
        else:
            h = (c.z - zc) / hc
            col = shade(cap_c, 0.9 + 0.18 * h)
        m._finish(bm, [f], col, True)
    m._finish(bm, [top], shade(cap_c, 1.08), True)
    # cream spots on the cap
    for (a, h, r) in ((-1.6, 0.3, 0.13), (-0.85, 0.5, 0.11), (-2.35, 0.55, 0.1), (-1.2, 0.78, 0.09), (0.4, 0.45, 0.12),
                      (2.2, 0.4, 0.13), (-0.25, 0.22, 0.08), (-2.9, 0.25, 0.09), (1.3, 0.7, 0.1), (-1.95, 0.12, 0.07),
                      (-1.05, 0.12, 0.07), (2.8, 0.75, 0.09)):
        phi = h * math.pi / 2
        rr = Rc * math.cos(phi) * 0.99
        z = zc + 0.12 + hc * math.sin(phi) ** 0.85
        nrm = Vector((math.cos(a) * math.cos(phi), math.sin(a) * math.cos(phi), math.sin(phi)))
        rot_x = math.acos(max(-1, min(1, nrm.z)))
        m.sphere(r, pos=(math.cos(a) * rr + nrm.x * 0.0, math.sin(a) * rr, z), scl=(1, 1, 0.3), rot=(0, rot_x, a),
                 color="MUSHROOM_DOT", seg=10, rings=4)
    # door, windows, stovepipe
    door(m, 0.0, -R + 0.02, w=0.38, h=0.7, col="DOOR")
    stepping_stones(m, 0.0, -R - 0.1, 1)
    for a in (-math.pi / 2 + 0.75, -math.pi / 2 - 0.85):
        x, y = math.cos(a) * (R - 0.01), math.sin(a) * (R - 0.01)
        m.cyl(0.13, 0.13, 0.04, pos=(x, y, 0.62), rot=(math.pi / 2, 0, a + math.pi / 2), color="WOOD_DARK", seg=10)
        m.cyl(0.1, 0.1, 0.05, pos=(x * 1.01, y * 1.01, 0.62), rot=(math.pi / 2, 0, a + math.pi / 2), color="WINDOW_LIT", seg=10)
    m.cyl(0.06, 0.06, 0.6, pos=(0.55, 0.45, H + 0.5), color=IRON, seg=6, cap="SOOT" if False else "4a4a4a")
    m.cyl(0.1, 0.06, 0.08, pos=(0.55, 0.45, H + 1.1), color=IRON, seg=6)
    # drying rack with brown mushroom slices + basket + little mushrooms round the foot
    def hang(px, y, z, k):
        m.cyl(0.05, 0.05, 0.02, pos=(px, y, z - 0.08), rot=(math.pi / 2, 0, 0), color="8a5a36", seg=6)
    drying_rack(m, -1.5, -0.95, -0.2, 0.8, hang)
    m.cyl(0.16, 0.13, 0.18, pos=(0.85, -0.75, 0), color="d9b98a", seg=8, cap="WOOD_DARK")
    for k in range(3):
        m.sphere(0.06, pos=(0.8 + k * 0.06, -0.77, 0.2), scl=(1, 1, 0.6), color="MUSHROOM_DOT", seg=6, rings=3)
    for (x, y, s) in ((-0.85, -0.7, 1.0), (-0.72, -0.85, 0.7), (0.75, 0.35, 0.8), (-0.5, 0.75, 0.9)):
        m.cyl(0.03 * s, 0.035 * s, 0.14 * s, pos=(x, y, 0), color="MUSHROOM_STEM", seg=5)
        m.sphere(0.09 * s, pos=(x, y, 0.14 * s), scl=(1, 1, 0.6), color=cap_c, seg=7, rings=4)
    m.export(OUT)


# ───────────────────────── medium ─────────────────────────
def build_healer():
    """치료소: long lime-white cottage, golden thatch; open side porch with two cots and white cloths on a line."""
    def ex(m):
        # open porch on the right: a striped cloth canopy over the bed heads, cots sticking out toward the front
        px0, px1 = 1.4, 2.35
        m.box((px1 - px0 + 0.1, 1.45, 0.06), pos=((px0 + px1) / 2, 0, 0), color=shade("PLANK", 0.95))
        for x in (px0 + 0.05, px1):
            post(m, x, 0.0, 1.0, 0.07)
            post(m, x, 0.7, 1.25, 0.07)
        ln = math.hypot(0.85, 0.3)
        for k in range(5):
            x = px0 + (k + 0.5) * (px1 - px0 + 0.1) / 5
            m.box(((px1 - px0 + 0.1) / 5 + 0.002, ln, 0.03), pos=(x, 0.33, 1.08), rot=(math.atan2(0.3, 0.85), 0, 0),
                  color=CLOTH if k % 2 else "cfe3e8")
        for k in range(5):
            x = px0 + (k + 0.5) * (px1 - px0 + 0.1) / 5
            m.box((0.12, 0.03, 0.1), pos=(x, -0.09, 0.93), color=CLOTH if k % 2 else "cfe3e8")       # scalloped hem
        bed(m, 1.66, -0.3, 0.0, BLANKET[0])
        bed(m, 2.14, -0.3, 0.0, BLANKET[1])
        stool(m, 1.9, -0.85, 0.22)
        m.cyl(0.05, 0.04, 0.09, pos=(1.9, -0.85, 0.26), color="ffffff", seg=6, cap="WATER")
        line_with(m, -2.0, -1.25, -0.6, 0.85, [(CLOTH, 0.18, 0.3), ("ffffff", 0.16, 0.25), (BLANKET[2], 0.18, 0.28)])
        # herb sign (green leaf on a white board) over the door
        m.box((0.36, 0.04, 0.22), pos=(-0.3, -0.84, 1.0), color="ffffff")
        m.sphere(0.07, pos=(-0.3, -0.87, 1.11), scl=(1.0, 0.3, 1.5), color="7fb565", seg=6, rings=3)
        pot(m, 0.95, -1.0, 0.9, flower="LOTUS")
    house("healer", 2.5, 1.5, 1.25, 1.2, -0.3, [0.5], (-0.85, 0.15), 211, extras=ex, walls=("framed", LIME),
          roof_col=GOLD, roof_under=GOLD_UNDER, shutter=SHUTTER[0], lamp=True,
          posts=[-1.25, -0.6, 0.15, 1.25]).export(OUT)


def build_weaver():
    """방직소: ochre cottage, golden thatch, loom under a lean-to, yarn skeins, dyed cloth drying, wool basket."""
    def ex(m):
        # lean-to on the left
        x0, x1 = -2.15, -1.4
        for y in (-0.6, 0.55):
            post(m, x0, y, 0.9, 0.08)
        rotated(m, lambda: bun_roof(m, 0.8, 1.2, 0.9, 0.42, ox=0.1, oy=0.16, hip=0.45, NT=20, NU=5, roll=0.05, seed=19,
                                    bands=(), col=MOSSY, under=MOSSY_UNDER), 0.0, ((x0 + x1) / 2, 0, 0))
        # loom: frame + coloured warp + cloth roll
        lx, ly = -1.75, -0.05
        for dx in (-0.28, 0.28):
            m.box((0.05, 0.05, 0.75), pos=(lx + dx, ly, 0), color="WOOD")
        m.box((0.62, 0.06, 0.05), pos=(lx, ly, 0.72), color="WOOD")
        m.box((0.62, 0.06, 0.05), pos=(lx, ly, 0.28), color="WOOD")
        m.box((0.5, 0.02, 0.4), pos=(lx, ly - 0.01, 0.32), color=YARN[0])
        m.box((0.5, 0.025, 0.12), pos=(lx, ly - 0.015, 0.32), color=shade(YARN[0], 1.2))
        stool(m, lx, ly - 0.35, 0.2)
        # yarn skeins + wool basket
        for k, c in enumerate(YARN):
            m.sphere(0.07, pos=(0.85 + (k % 2) * 0.15, -0.95 + (k // 2) * 0.05, 0.07 + (k // 2) * 0.1), color=c, seg=7, rings=4)
        m.cyl(0.17, 0.14, 0.2, pos=(1.25, -0.8, 0), color="d9b98a", seg=8, cap="WOOD_DARK")
        for k in range(3):
            m.sphere(0.08, pos=(1.2 + k * 0.06, -0.82 + (k % 2) * 0.05, 0.22), color=WOOL, seg=6, rings=4, lumps=0.3,
                     group="body_nl")
        line_with(m, 0.95, 1.85, 0.25, 0.95, [(YARN[1], 0.2, 0.4), (YARN[2], 0.2, 0.36), (YARN[3], 0.2, 0.42)])
    house("weaver", 2.3, 1.45, 1.3, 1.2, 0.35, [-0.45], (-0.6, 0.15), 212, extras=ex, walls=("framed", OCHRE),
          roof_col=GOLD, roof_under=GOLD_UNDER, shutter=SHUTTER[1]).export(OUT)


def build_smithy():
    """대장간: stone workshop with a slate roof; open-fronted forge shed on the right (glowing coals, hood,
    anvil on a stump, quench barrel, tool rack, bellows)."""
    m = house("smithy", 1.5, 1.5, 1.3, 1.15, -0.15, [], None, 213, walls=("stone", "STONE"), roof="tile_front",
              roof_col=SLATE, roof_under=SLATE_UNDER, boxes=False, side_win=False, steps=1)
    # open forge shed on the right: four posts + a sloping plank roof (low at the front)
    sx0, sx1 = 0.8, 2.2
    for x in (sx0 + 0.02, sx1):
        post(m, x, -0.65, 0.95, 0.1)
        post(m, x, 0.7, 1.25, 0.1)
    m.box((sx1 - sx0 + 0.1, 1.5, 0.05), pos=((sx0 + sx1) / 2, 0, 0), color=shade("PATH", 0.85))
    ln = math.hypot(1.6, 0.3)
    ang = math.atan2(0.3, 1.6)
    for k in range(6):
        x = sx0 - 0.05 + (k + 0.5) * (sx1 - sx0 + 0.2) / 6
        m.box(((sx1 - sx0 + 0.2) / 6 - 0.015, ln, 0.06), pos=(x, 0.02, 1.07), rot=(ang, 0, 0),
              color=shade("WOOD", (1.0, 0.9, 1.06)[k % 3]))
    m.box((sx1 - sx0 + 0.25, 0.08, 0.1), pos=((sx0 + sx1) / 2, -0.78, 0.88), color="WOOD_DARK")
    # hearth with glowing coals (at the open front), stone hood + chimney through the roof
    hx, hy = 1.75, -0.3
    m.box((0.62, 0.55, 0.5), pos=(hx, hy, 0), color="STONE",
          colfn=lambda f: "STONE_DARK" if f.normal.z > 0.7 else "STONE")
    m.cyl(0.17, 0.17, 0.05, pos=(hx, hy - 0.26, 0.22), rot=(math.pi / 2, 0, 0), color="FLAME", seg=8)
    m.cyl(0.11, 0.11, 0.06, pos=(hx, hy - 0.27, 0.19), rot=(math.pi / 2, 0, 0), color="FLAME2", seg=8)
    m.box((0.38, 0.06, 0.12), pos=(hx, hy - 0.3, 0.0), color="STONE_DARK")
    m.cyl(0.24, 0.24, 0.02, pos=(hx, hy - 0.05, 0.5), color="FLAME", seg=8)
    for k in range(5):
        m.sphere(0.07, pos=(hx - 0.14 + (k % 3) * 0.14, hy - 0.12 + (k // 3) * 0.14, 0.52), scl=(1, 1, 0.6),
                 color=("FLAME2", "FLAME")[k % 2], seg=6, rings=3, group="body_nl")
    chimney(m, hx, hy + 0.32, 1.75, w=0.26)
    # bellows
    m.cyl(0.12, 0.02, 0.35, pos=(hx + 0.45, hy, 0.3), rot=(0, -math.pi / 2, 0), color="8a5a3a", seg=5, scl=(1, 1.6, 1))
    # anvil on a stump
    ax, ay = 1.15, -0.9
    m.cyl(0.18, 0.2, 0.3, pos=(ax, ay, 0), color="TRUNK", seg=8, cap="STUMP_TOP", smooth=True)
    m.box((0.12, 0.14, 0.12), pos=(ax, ay, 0.3), color=IRON)
    m.box((0.34, 0.16, 0.08), pos=(ax, ay, 0.42), color=IRON, colfn=lambda f: "7d878a" if f.normal.z > 0.7 else IRON)
    m.cyl(0.06, 0.0, 0.12, pos=(ax - 0.17, ay, 0.46), rot=(0, -math.pi / 2, 0), color=IRON, seg=5)
    m.box((0.2, 0.04, 0.04), pos=(ax + 0.1, ay - 0.05, 0.52), rot=(0, 0, 0.4), color="WOOD")          # hammer
    m.box((0.06, 0.08, 0.06), pos=(ax + 0.2, ay - 0.0, 0.5), color=IRON)
    barrel(m, 2.1, -0.95, 0.8)
    m.cyl(0.11, 0.11, 0.01, pos=(2.1, -0.95, 0.33), color="WATER", seg=8)
    # tool rack on the left wall
    m.box((0.05, 0.5, 0.05), pos=(-0.83, 0.0, 0.9), color="WOOD_DARK")
    for k in range(3):
        m.box((0.03, 0.03, 0.4), pos=(-0.86, -0.18 + k * 0.18, 0.5), color="WOOD")
        m.box((0.04, 0.1, 0.07), pos=(-0.87, -0.18 + k * 0.18, 0.48), color=IRON)
    # iron bars + coal heap
    m.sphere(0.2, pos=(-0.95, -0.85, 0.02), scl=(1.2, 1.0, 0.5), color="3f4446", seg=7, rings=4, lumps=0.3)
    for k in range(3):
        m.box((0.5, 0.05, 0.05), pos=(0.55, -0.95 + k * 0.06, 0.03 + k * 0.03), color="7d878a")
    m.export(OUT)


def build_graveyard():
    """묘지: a small fenced plot (picket fence, gate), simple rounded headstones with moss, a bench, flowers."""
    m = Model("graveyard", 221)
    W, D = 2.6, 2.2
    m.box((W, D, 0.03), color=mix("b9d687", "a6d08a", 0.6))
    picket_fence(m, -W / 2, -D / 2, -0.3, -D / 2, h=0.36)
    picket_fence(m, 0.3, -D / 2, W / 2, -D / 2, h=0.36)
    picket_fence(m, -W / 2, D / 2, W / 2, D / 2, h=0.36)
    picket_fence(m, -W / 2, -D / 2, -W / 2, D / 2, h=0.36)
    picket_fence(m, W / 2, -D / 2, W / 2, D / 2, h=0.36)
    for sx in (-1, 1):                                           # gate posts
        m.box((0.1, 0.1, 0.55), pos=(sx * 0.32, -D / 2, 0), color="WOOD_DARK")
        m.cyl(0.07, 0.0, 0.08, pos=(sx * 0.32, -D / 2, 0.55), color="WOOD_DARK", seg=4, rot=(0, 0, math.pi / 4))
    cols = ("STONE", shade("STONE", 0.92), mix("STONE", "f2e6cc", 0.4))
    graves = ((-0.75, 0.55, 1.0), (0.0, 0.6, 1.15), (0.75, 0.5, 0.95), (-0.7, -0.25, 0.9), (0.7, -0.2, 1.05))
    for i, (x, y, s) in enumerate(graves):
        headstone(m, x, y, 0.05 * ((i % 3) - 1), s, cols[i % 3], moss=i % 2 == 0)
        m.sphere(0.04, pos=(x + 0.1, y - 0.3, 0.06), color=("LOTUS", "ffffff", "FLAME2")[i % 3], seg=5, rings=3,
                 group="body_nl")
    # path stones to the middle, a bench and a bush
    for k in range(3):
        m.cyl(0.15, 0.14, 0.04, pos=(0.02 * (k % 2), -D / 2 + 0.25 + k * 0.3, 0), color=STEP, seg=6, scl=(1.2, 1, 1))
    m.box((0.6, 0.2, 0.05), pos=(-0.15, -0.55, 0.28), color="WOOD")
    for dx in (-0.4, 0.1):
        m.box((0.06, 0.18, 0.28), pos=(dx, -0.55, 0), color="WOOD_DARK")
    round_bush(m, 1.0, 0.85, 0.24)
    round_bush(m, -1.05, 0.85, 0.2, flowers="ffffff", seed=3)
    m.export(OUT)


def build_ferry():
    """나루터: pier along +X from the shore (origin, ground) like pier.glb, a flat ferry raft moored beside it,
    mooring posts with rope, a lantern post, crates. Deck at z = 0.18."""
    m = Model("ferry", 231)
    L, Wd = 2.6, 1.0
    n = int(L / 0.24)
    for i in range(n):
        x = 0.12 + i * L / n
        m.box((L / n - 0.025, Wd, 0.07), pos=(x + 0.1, 0, 0.18), color=shade("PLANK", (0.92, 1.0, 1.06)[i % 3]))
    for x in (0.25, L / 2, L):
        for sy in (-1, 1):
            m.cyl(0.075, 0.075, 1.6, pos=(x, sy * (Wd / 2 + 0.02), -1.1), color="WOOD_DARK", seg=7, cap="STUMP_TOP")
    # raft: plank deck on two logs, low rail, tied on the +Y side
    rx, ry = 1.7, Wd / 2 + 0.75
    for sy in (-1, 1):
        log(m, rx, ry + sy * 0.4, -0.04, 1.5, 0.1, 0.0)
    for k in range(7):
        m.box((0.2, 1.05, 0.05), pos=(rx - 0.66 + k * 0.22, ry, 0.06), color=shade("PLANK", (0.95, 1.05)[k % 2]))
    for x in (rx - 0.65, rx + 0.65):
        for sy in (-1, 1):
            m.box((0.05, 0.05, 0.35), pos=(x, ry + sy * 0.48, 0.1), color="WOOD_DARK")
    for sy in (-1, 1):
        m.box((1.35, 0.04, 0.04), pos=(rx, ry + sy * 0.48, 0.4), color="WOOD")
    crate(m, rx - 0.35, ry + 0.1, 0.75, z=0.11)
    sack(m, rx + 0.3, ry - 0.1, 0.75, z=0.11)
    # ropes from posts to the raft + a long ferry cable post at the end
    for x in (0.95, 2.4):
        m.box((0.03, 0.75, 0.03), pos=(x, Wd / 2 + 0.36, 0.22), rot=(0.12, 0, 0), color="d9b98a")
    m.cyl(0.08, 0.08, 1.1, pos=(L + 0.05, -0.3, 0.2), color="WOOD", seg=7, cap="STUMP_TOP")
    m.cyl(0.11, 0.11, 0.18, pos=(L + 0.05, -0.3, 0.55), color="d9b98a", seg=7)                       # coiled rope
    # lantern post at the shore end + bell
    m.box((0.08, 0.08, 1.3), pos=(0.3, -Wd / 2 - 0.1, 0.18), color="WOOD_DARK")
    m.box((0.35, 0.06, 0.06), pos=(0.42, -Wd / 2 - 0.1, 1.42), color="WOOD_DARK")
    lantern(m, 0.55, -Wd / 2 - 0.1 + 0.12, 1.25, face=-1)
    crate(m, 0.55, 0.2, 0.8, z=0.22)
    barrel(m, 0.9, 0.25, 0.75, z=0.22)
    m.export(OUT)


# ───────────────────────── large ─────────────────────────
def build_chapel():
    """교회: lime-white chapel, gable to the front under a steep slate roof, bellcote with a golden bell on the
    front gable, tall arched windows, round window, big arched door, little yard with flowers."""
    W, D, H, rise = 2.0, 3.0, 1.5, 1.6
    m = house("chapel", W, D, H, rise, 0.0, [], None, 241, walls=("framed", LIME), roof="tile_front",
              roof_col=SLATE, roof_under=SLATE_UNDER, boxes=False, side_win=False, steps=2, lamp=False,
              posts=[-W / 2, W / 2], door_col="8a5a3a")
    # wider double door overlay
    door(m, 0.0, -D / 2 - 0.005, w=0.62, h=1.05, col="8a5a3a")
    # tall arched side windows
    for y in (-0.8, 0.0, 0.8):
        for sx in (-1, 1):
            m.box((0.03, 0.26, 0.6), pos=(sx * (W / 2 + 0.012), y, 0.55), color="WOOD_DARK")
            m.box((0.04, 0.18, 0.5), pos=(sx * (W / 2 + 0.02), y, 0.58), color="WINDOW_LIT")
            m.cyl(0.09, 0.09, 0.04, pos=(sx * (W / 2 + 0.0), y, 1.08), rot=(0, math.pi / 2, 0), color="WINDOW_LIT", seg=5)
    # bellcote standing on the front of the ridge: two piers, a little pyramid roof, a golden bell in between
    yb = -D / 2 + 0.05
    zt = H + rise + 0.02
    m.box((0.62, 0.42, 0.1), pos=(0, yb, zt - 0.08), color=LIME)
    for sx in (-1, 1):
        m.box((0.12, 0.36, 0.62), pos=(sx * 0.24, yb, zt), color=LIME)
    m.box((0.66, 0.46, 0.08), pos=(0, yb, zt + 0.6), color=shade(LIME, 0.92))
    m.cyl(0.42, 0.0, 0.45, pos=(0, yb, zt + 0.68), color=SLATE, seg=4, rot=(0, 0, math.pi / 4))
    m.box((0.05, 0.05, 0.25), pos=(0, yb, zt + 1.1), color=BELL)
    m.box((0.18, 0.05, 0.05), pos=(0, yb, zt + 1.24), color=BELL)
    m.cyl(0.16, 0.08, 0.26, pos=(0, yb, zt + 0.22), color=BELL, seg=10, smooth=True, cap=shade(BELL, 0.8))
    m.sphere(0.045, pos=(0, yb, zt + 0.2), color=shade(BELL, 0.7), seg=5, rings=3)
    # yard: two flower bushes and a low stone wall stub, path
    round_bush(m, -1.25, -1.6, 0.25, flowers="LOTUS", seed=1)
    round_bush(m, 1.25, -1.55, 0.23, flowers="ffffff", seed=5)
    for sx in (-1, 1):
        m.box((0.7, 0.16, 0.22), pos=(sx * 0.95, -D / 2 - 0.85, 0), color="STONE",
              colfn=lambda f: "MOSS" if f.normal.z > 0.7 else "STONE")
    m.export(OUT)


def build_plaza():
    """광장: paved circle (two rings of pavers), a stone fountain, bunting strung between four poles, benches,
    flower tubs."""
    m = Model("plaza", 251)
    R = 1.9
    seg = 24
    stone_a, stone_b = mix("PATH", "STONE", 0.45), mix("PATH", "STONE", 0.25)
    m.cyl(R, R, 0.05, color=shade(stone_a, 0.9), seg=seg, cap=stone_a)
    # paver rings: alternating wedge tiles (flat tops) -> reads as cobbles
    for ring_i, (r0, r1) in enumerate(((0.75, 1.3), (1.3, 1.82))):
        n = 12 if ring_i == 0 else 18
        for k in range(n):
            a0 = k / n * math.tau + 0.02 + ring_i * 0.1
            a1 = (k + 1) / n * math.tau - 0.02 + ring_i * 0.1
            c = shade(stone_b if (k + ring_i) % 2 else stone_a, (1.0, 1.05, 0.96)[k % 3])
            pts = [Vector((math.cos(a0) * r0, math.sin(a0) * r0, 0.065)), Vector((math.cos(a1) * r0, math.sin(a1) * r0, 0.065)),
                   Vector((math.cos(a1) * r1, math.sin(a1) * r1, 0.065)), Vector((math.cos(a0) * r1, math.sin(a0) * r1, 0.065))]
            m.poly(pts, color=c, group="body_nl")
    # fountain: octagonal basin, water, central pillar + bowl + spout
    m.cyl(0.72, 0.72, 0.32, color="STONE", seg=8, cap="STONE_DARK")
    m.cyl(0.62, 0.62, 0.02, pos=(0, 0, 0.3), color="WATER", seg=8)
    for k in range(8):
        a = k / 8 * math.tau + math.pi / 8
        m.box((0.3, 0.04, 0.2), pos=(math.cos(a) * 0.66, math.sin(a) * 0.66, 0.06), rot=(0, 0, a + math.pi / 2),
              color=shade("STONE", 0.9 if k % 2 else 1.05))
    m.cyl(0.12, 0.09, 0.65, pos=(0, 0, 0.3), color="STONE", seg=8, smooth=True)
    m.cyl(0.08, 0.34, 0.14, pos=(0, 0, 0.82), color="STONE", seg=10, smooth=True, cap="WATER")
    m.cyl(0.05, 0.02, 0.28, pos=(0, 0, 0.96), color="DROP", seg=6, smooth=True)
    m.sphere(0.07, pos=(0, 0, 1.25), color="DROP", seg=6, rings=4)
    for k in range(6):                                            # falling water drops from the bowl
        a = k / 6 * math.tau
        m.sphere(0.04, pos=(math.cos(a) * 0.38, math.sin(a) * 0.38, 0.55), scl=(1, 1, 2.2), color="DROP", seg=5, rings=3,
                 group="body_nl")
    # poles + bunting
    poles = [(-1.7, -1.0), (1.7, -1.0), (1.7, 1.0), (-1.7, 1.0)]
    for (x, y) in poles:
        m.cyl(0.045, 0.04, 1.7, pos=(x, y, 0), color="WOOD", seg=6)
        m.sphere(0.06, pos=(x, y, 1.72), color="FLAME2", seg=6, rings=3)
    for (a, b) in ((poles[0], poles[1]), (poles[1], poles[2]), (poles[2], poles[3]), (poles[3], poles[0]),
                   (poles[0], poles[2])):
        bunting(m, a, b, 1.6, sag=0.25, n=6 if abs(a[0] - b[0]) > 1 else 4)
    # benches + flower tubs
    for (x, y, rz) in ((0.0, -1.55, 0.0), (0.0, 1.55, 0.0)):
        m.box((0.8, 0.22, 0.05), pos=(x, y, 0.26), rot=(0, 0, rz), color="WOOD")
        for dx in (-0.3, 0.3):
            m.box((0.06, 0.2, 0.26), pos=(x + dx, y, 0), color="WOOD_DARK")
    for (x, y, fl) in ((-1.25, -1.35, "LOTUS"), (1.25, -1.35, "FLAME2"), (1.3, 1.3, "ffffff"), (-1.3, 1.3, "LOTUS")):
        m.cyl(0.17, 0.14, 0.2, pos=(x, y, 0), color="WOOD", seg=8, cap="FIELD_SOIL")
        round_bush(m, x, y, 0.15, flowers=fl, seed=int(x * 10))
    m.export(OUT)


def build_pasture():
    """목장: a fenced pasture (post-and-rail, gate at the front), meadow patch with tufts, a little thatched
    shed at the back corner, water trough, hay bales."""
    m = Model("pasture", 261)
    W, D = 4.0, 3.4
    m.box((W - 0.1, D - 0.1, 0.03), color=mix("b9d687", "d6e39a", 0.4))
    hw, hd = W / 2, D / 2
    rail_fence(m, -hw, -hd, hw, -hd, gap=(0.42, 0.58))
    rail_fence(m, -hw, hd, hw, hd)
    rail_fence(m, -hw, -hd, -hw, hd)
    rail_fence(m, hw, -hd, hw, hd)
    # gate (open, swung in)
    m.box((0.6, 0.05, 0.06), pos=(-0.05, -hd + 0.3, 0.2), rot=(0, 0, 1.2), color=shade("WOOD", 1.12))
    m.box((0.6, 0.05, 0.06), pos=(-0.05, -hd + 0.3, 0.42), rot=(0, 0, 1.2), color=shade("WOOD", 1.12))
    # shed at the back-left corner (open toward the front)
    sx, sy = -1.2, 0.95
    m.box((1.2, 0.08, 0.9), pos=(sx, sy + 0.45, 0), color="WOOD")
    for dx in (-0.6, 0.6):
        m.box((0.08, 0.95, 0.9), pos=(sx + dx, sy, 0), color="WOOD")
    rotated(m, lambda: bun_roof(m, 1.2, 0.9, 0.9, 0.55, ox=0.15, oy=0.18, hip=0.6, NT=20, NU=5, roll=0.06, seed=7,
                                bands=(), col=MOSSY, under=MOSSY_UNDER), 0.0, (sx, sy, 0))
    hay_bale(m, sx - 0.2, sy + 0.1, 0.0, 0.9)
    hay_bale(m, sx + 0.25, sy + 0.15, 0.3, 0.8)
    # trough, hay bales outside, tufts and flowers
    m.box((0.9, 0.3, 0.25), pos=(1.0, 0.9, 0), color="WOOD")
    m.box((0.8, 0.22, 0.02), pos=(1.0, 0.9, 0.24), color="WATER")
    hay_bale(m, 1.4, -0.9, 0.5)
    hay_bale(m, 1.7, -0.55, 1.2, 0.85)
    r = m.rng
    for k in range(9):
        x, y = r.uniform(-hw + 0.3, hw - 0.3), r.uniform(-hd + 0.3, hd - 0.4)
        if x < -0.4 and y > 0.3:
            continue
        for j in range(3):
            a = j * 2.1 + k
            m.blade((x, y, 0.02), (x + math.cos(a) * 0.08, y + math.sin(a) * 0.08, 0.2), 0.07, color="TUFT")
        if k % 3 == 0:
            m.sphere(0.035, pos=(x + 0.05, y, 0.1), color=("ffffff", "FLAME2")[k % 2], seg=5, rings=3, group="body_nl")
    m.export(OUT)


def build_watchtower():
    """망루: four tapered log legs with cross braces, a railed platform, round thatch hat, ladder, pennant."""
    m = Model("watchtower", 271)
    B, T, Hp = 0.55, 0.42, 2.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            a = Vector((sx * B, sy * B, 0))
            b = Vector((sx * T, sy * T, Hp + 0.9))
            d = b - a
            pitch = math.acos(d.normalized().z)
            yaw = math.atan2(d.y, d.x)
            m.cyl(0.07, 0.06, d.length, pos=tuple(a), rot=(0, pitch, yaw), color="TRUNK", seg=6, cap="STUMP_TOP")
            m.box((0.22, 0.22, 0.12), pos=(sx * B, sy * B, 0), color="STONE")
    # cross braces on front + sides (X shapes)
    for z0, z1 in ((0.25, 1.35), (1.35, 2.45)):
        for side in range(4):
            for flip in (-1, 1):
                t0, t1 = z0 / (Hp + 0.9), z1 / (Hp + 0.9)
                r0, r1 = B + (T - B) * t0, B + (T - B) * t1
                ang = side * math.pi / 2
                ca, sa = math.cos(ang), math.sin(ang)
                p0 = Vector((-flip * r0, -r0, z0))
                p1 = Vector((flip * r1, -r1, z1))
                p0 = Vector((p0.x * ca - p0.y * sa, p0.x * sa + p0.y * ca, p0.z))
                p1 = Vector((p1.x * ca - p1.y * sa, p1.x * sa + p1.y * ca, p1.z))
                d = p1 - p0
                m.cyl(0.03, 0.03, d.length, pos=tuple(p0), rot=(0, math.acos(d.normalized().z), math.atan2(d.y, d.x)),
                      color="WOOD", seg=4)
    # platform + rails
    P = 0.68
    m.box((2 * P, 2 * P, 0.1), pos=(0, 0, Hp), color="PLANK", colfn=lambda f: shade("PLANK", 1.05) if f.normal.z > 0.7 else "WOOD")
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box((0.07, 0.07, 1.05), pos=(sx * (P - 0.04), sy * (P - 0.04), Hp + 0.1), color="WOOD_DARK")
    for z in (Hp + 0.35, Hp + 0.6):
        for (sz, rz) in (((0, -P + 0.02), 0), ((0, P - 0.02), 0), ((-P + 0.02, 0), math.pi / 2), ((P - 0.02, 0), math.pi / 2)):
            m.box((2 * P, 0.04, 0.06), pos=(sz[0], sz[1], z), rot=(0, 0, rz), color="WOOD")
    # round thatch hat
    bun_roof(m, 1.1, 1.1, Hp + 1.15, 0.75, ox=0.14, oy=0.14, hip=1.0, n=2.6, NT=20, NU=5, roll=0.06, seed=27, bands=())
    m.cyl(0.025, 0.025, 0.5, pos=(0, 0, Hp + 1.8), color="WOOD_DARK", seg=4)
    pts = [Vector((0.02, 0, Hp + 2.28)), Vector((0.42, 0.0, Hp + 2.18)), Vector((0.02, 0, Hp + 2.06))]
    m.poly(pts, color="c8644e", group="body_nh")
    m.poly(list(reversed(pts)), color="c8644e", group="body_nh")
    # hanging horn + ladder on the front
    m.cyl(0.05, 0.015, 0.25, pos=(0.35, -P - 0.02, Hp + 0.5), rot=(0, 1.9, 0), color=BONE, seg=6)
    for sx in (-1, 1):
        m.box((0.05, 0.05, Hp + 0.3), pos=(sx * 0.18, -B - 0.35, 0), rot=(-0.13, 0, 0), color="WOOD")
    for k in range(8):
        z = 0.25 + k * 0.32
        m.box((0.36, 0.04, 0.04), pos=(0, -B - 0.35 + z * 0.13, z), color="WOOD_DARK")
    m.export(OUT)


if __name__ == "__main__":
    print("village buildings ->", OUT)
    build_fisher()
    build_hunter()
    build_herbalist()
    build_mushroom_hut()
    build_healer()
    build_weaver()
    build_smithy()
    build_graveyard()
    build_ferry()
    build_chapel()
    build_plaza()
    build_pasture()
    build_watchtower()
