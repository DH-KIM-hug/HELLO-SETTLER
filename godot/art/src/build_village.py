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
    STEP, SOOT, plank_roof, lift, sod_tufts, SHINGLE, SHINGLE_UNDER, BARK, BARK_UNDER, SOD, SOD_UNDER, REED_ROOF,
    REED_ROOF_UNDER, SLATE_ROOF, SLATE_ROOF_UNDER, TEAL_TILE, TEAL_TILE_UNDER)
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
    """어장 (어부, v3): fishing shack up on stilts with a deck and ladder, straight reed-thatch gable, nets drying on
    poles, a rowing boat pulled up, fish on a rack, baskets."""
    m = house("fisher", 1.5, 1.05, 1.05, 0.95, -0.15, [0.4], None, 201, walls=("plank", TEAL_WOOD), roof="tile",
              roof_col=REED_ROOF, roof_under=REED_ROOF_UNDER, side_win=False, boxes=False, steps=0, shutter=SHUTTER[3])
    lift(m, 0.6)
    # deck + stilts + ladder
    m.box((1.9, 1.75, 0.08), pos=(0, -0.2, 0.52), color="PLANK",
          colfn=lambda f: shade("PLANK", 1.05) if f.normal.z > 0.7 else "WOOD")
    for x in (-0.85, 0.0, 0.85):
        for y in (-1.0, 0.55):
            m.cyl(0.06, 0.06, 0.55, pos=(x, y, 0), color="WOOD_DARK", seg=6)
    for sx in (-1, 1):                                      # cross braces under the deck
        m.box((0.04, 1.6, 0.05), pos=(sx * 0.85, -0.22, 0.28), rot=(0.35, 0, 0), color="WOOD")
    for x in (-0.9, 0.9):
        post(m, x, -1.03, 0.95, 0.05, "WOOD")
    m.box((1.85, 0.04, 0.04), pos=(0, -1.03, 0.92), color="WOOD")
    for sx in (-1, 1):
        m.box((0.04, 0.04, 0.85), pos=(0.45 + sx * 0.14, -1.25, 0), rot=(-0.4, 0, 0), color="WOOD")
    for k in range(4):
        m.box((0.32, 0.035, 0.035), pos=(0.45, -1.36 + k * 0.08, 0.12 + k * 0.13), color="WOOD_DARK")
    # nets drying + boat + fish rack + baskets
    net_frame(m, -1.85, -1.05, -0.65, 1.0)
    net_frame(m, -1.85, -1.05, 0.25, 0.9)
    boat(m, 1.45, -0.2, rz=1.45, L=1.2)
    m.cyl(0.02, 0.02, 1.0, pos=(1.1, 0.5, 0.08), rot=(0, 1.35, 0.4), color="WOOD", seg=4)          # oar

    def hang(px, y, z, k):
        fish(m, px, y, z - 0.05, FISH if k % 3 else "c9b38a")
    drying_rack(m, 1.0, 1.7, -1.05, 0.8, hang)
    m.cyl(0.15, 0.12, 0.2, pos=(-0.45, -1.3, 0), color="d9b98a", seg=8, cap="WOOD_DARK")            # fish basket
    for k in range(2):
        fish(m, -0.49 + k * 0.08, -1.31, 0.24)
    m.export(OUT)


def build_hunter():
    """사냥막 (사냥꾼, v3): low dark log lodge under a steep bark gable facing front, a big antler rack on the gable peak,
    two hides stretched on frames, a fur pile, a bow on the stump, a meat-smoking rack."""
    def hide(m, fx, fy, col=HIDE, s=1.0):
        for dx in (-0.35 * s, 0.35 * s):
            m.box((0.05, 0.05, 1.0 * s), pos=(fx + dx, fy, 0), color="WOOD")
        for z in (0.2 * s, 0.95 * s):
            m.box((0.85 * s, 0.05, 0.05), pos=(fx, fy, z), color="WOOD")
        pts = []
        for k in range(10):
            a = k / 10 * math.tau
            r = (0.27 + 0.05 * math.cos(a * 2) + 0.03 * math.sin(a * 5)) * s
            pts.append(Vector((fx + math.cos(a) * r, fy - 0.03, 0.57 * s + math.sin(a) * r * 1.15)))
        m.poly(list(reversed(pts)), color=col)
        m.poly(pts, color=shade(col, 0.85))
        for k in range(4):
            a = k / 4 * math.tau + 0.4
            m.box((0.012, 0.012, 0.12 * s), pos=(fx + math.cos(a) * 0.32 * s, fy - 0.03, 0.57 * s + math.sin(a) * 0.36 * s),
                  color="WOOD_DARK")

    def antlers(m, cx, cy, cz, s=1.0):
        m.box((0.3 * s, 0.05, 0.24 * s), pos=(cx, cy + 0.03, cz - 0.16 * s), color="WOOD")
        m.box((0.18 * s, 0.07, 0.13 * s), pos=(cx, cy, cz - 0.08 * s), color=BONE)
        for sx in (-1, 1):
            m.cyl(0.03 * s, 0.022 * s, 0.42 * s, pos=(cx + sx * 0.06 * s, cy - 0.02, cz), rot=(0, sx * 0.95, 0), color=BONE, seg=5)
            bx = cx + sx * 0.36 * s
            m.cyl(0.024 * s, 0.012 * s, 0.32 * s, pos=(bx, cy - 0.02, cz + 0.22 * s), rot=(0, sx * 0.15, 0), color=BONE, seg=4)
            m.cyl(0.02 * s, 0.01 * s, 0.22 * s, pos=(cx + sx * 0.2 * s, cy - 0.02, cz + 0.12 * s), rot=(0, -sx * 0.3, 0),
                  color=BONE, seg=4)
            m.cyl(0.02 * s, 0.01 * s, 0.2 * s, pos=(bx, cy - 0.02, cz + 0.22 * s), rot=(0, sx * 0.9, 0), color=BONE, seg=4)

    def ex(m):
        antlers(m, 0.0, -(1.15 / 2 + 0.24) - 0.06, 2.0, 1.25)
        hide(m, -1.4, -0.25)
        hide(m, 1.45, 0.15, col="9c6f4a", s=0.85)
        # fur pile + stump with bow + smoking rack with meat strips
        m.sphere(0.22, pos=(-0.95, -0.95, 0.04), scl=(1.4, 1.0, 0.45), color="a07650", seg=8, rings=4, lumps=0.3,
                 group="body_nl")
        m.sphere(0.16, pos=(-0.75, -1.05, 0.1), scl=(1.3, 1.0, 0.4), color="d8c8a8", seg=7, rings=4, lumps=0.3,
                 group="body_nl")
        m.cyl(0.18, 0.2, 0.25, pos=(1.0, -0.95, 0), color="TRUNK", seg=8, cap="STUMP_TOP", smooth=True)
        m.box((0.5, 0.05, 0.05), pos=(1.0, -0.96, 0.3), rot=(0, 0, 0.5), color="WOOD")
        for k in range(3):
            a = k * math.tau / 3
            m.box((0.04, 0.04, 0.9), pos=(1.5 + math.cos(a) * 0.15, -0.65 + math.sin(a) * 0.15, 0), color="WOOD_DARK")
        for k in range(3):
            m.box((0.05, 0.02, 0.22), pos=(1.45 + k * 0.06, -0.68, 0.55), color="a8574a")
        m.sphere(0.1, pos=(1.5, -0.65, 0.12), scl=(1.2, 1.2, 0.4), color=SOOT, seg=6, rings=3)
    house("hunter", 1.7, 1.15, 0.95, 1.3, 0.25, [-0.45], (-0.5, 0.25), 202, extras=ex, walls=("log", "TRUNK_DARK"),
          roof="tile_front", roof_col=BARK, roof_under=BARK_UNDER, boxes=False, side_win=False, steps=1).export(OUT)


def build_herbalist():
    """약초원 (약초꾼, v3): little drying shed with a grass-and-flower turf roof and a green door, bundles of herbs
    hanging under an open lean-to, three raised herb beds (green, lavender, golden) in a wattle fence, pots, mortar."""
    def ex(m):
        sod_tufts(m, 1.3, 1.0, 1.0, 0.85, n=12, seed=7, flowers=("ffffff", LAVENDER, "f4d64c"))
        # open lean-to on the right with bundles hanging from two poles
        x0, x1 = 0.7, 1.55
        for y in (-0.5, 0.5):
            post(m, x1, y, 0.95, 0.07, "WOOD")
        ln = math.hypot(x1 - x0 + 0.2, 0.3)
        m.box((ln, 1.25, 0.05), pos=((x0 + x1) / 2 + 0.05, 0, 0.97), rot=(0, math.atan2(0.3, x1 - x0 + 0.2), 0), color=SHINGLE)
        for y in (-0.3, 0.25):
            m.box((x1 - x0, 0.03, 0.03), pos=((x0 + x1) / 2, y, 0.88), color="WOOD_DARK")
            for k in range(4):
                herb_bundle(m, x0 + 0.12 + k * 0.2, y, 0.88, ("7fb565", LAVENDER, "a6c46a", "d9b25a")[(k + int(y * 10)) % 4])
        # raised herb beds in front / left, inside a low wattle fence
        beds = ((-1.35, -0.25, "7fb565", "ffffff"), (-1.35, 0.55, "a98ad0", LAVENDER), (-0.55, -1.05, "a6c46a", "f4d64c"))
        for (x, y, leaf, fl) in beds:
            m.box((0.62, 0.55, 0.14), pos=(x, y, 0), color="WOOD")
            m.box((0.56, 0.49, 0.03), pos=(x, y, 0.13), color="FIELD_SOIL")
            for k in range(4):
                px, py = x - 0.15 + (k % 2) * 0.3, y - 0.12 + (k // 2) * 0.24
                m.sphere(0.1, pos=(px, py, 0.22), scl=(1, 1, 0.9), color=leaf, seg=6, rings=4, lumps=0.25, group="body_nl")
                m.sphere(0.035, pos=(px + 0.03, py - 0.03, 0.31), color=fl, seg=5, rings=3, group="body_nl")
        for (a, b) in (((-1.8, -0.7), (-1.8, 1.0)), ((-1.8, -1.45), (0.0, -1.45))):
            d = Vector((b[0] - a[0], b[1] - a[1], 0))
            n = int(d.length / 0.22)
            for i in range(n + 1):
                t = i / n
                m.box((0.04, 0.04, 0.3), pos=(a[0] + d.x * t, a[1] + d.y * t, 0), color="WOOD_DARK")
            for z in (0.12, 0.24):
                m.box((d.length, 0.03, 0.04), pos=((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, z),
                      rot=(0, 0, math.atan2(d.y, d.x)), color=mix("WOOD", "d9b98a", 0.4))
        pot(m, 0.75, -0.85, 0.9, plant="7fb565", flower=LAVENDER)
        stool(m, 1.1, -0.95)
        m.cyl(0.07, 0.05, 0.08, pos=(1.1, -0.95, 0.26), color="STONE", seg=7, cap="7fb565")
    house("herbalist", 1.3, 1.0, 1.0, 0.85, -0.1, [0.35], None, 203, extras=ex, walls=("plank", mix("WOOD", "d9b98a", 0.35)),
          roof="tile", roof_col=SOD, roof_under=SOD_UNDER, boxes=False, side_win=False, steps=1, door_col="5f8f4e",
          shutter="5f8f4e").export(OUT)


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
    # v3 버섯 말림터: a second, taller rack of whole mushrooms + slatted drying trays + basket stack on the right
    def hang2(px, y, z, k):
        m.cyl(0.012, 0.012, 0.08, pos=(px, y, z - 0.08), color="WOOD_DARK", seg=4)
        m.sphere(0.07, pos=(px, y, z - 0.14), scl=(1, 1, 0.55), color=(cap_c, "c98a5e", "MUSHROOM_DOT")[k % 3], seg=6, rings=3)
        m.cyl(0.02, 0.025, 0.08, pos=(px, y, z - 0.24), color="MUSHROOM_STEM", seg=4)
    drying_rack(m, -1.5, -0.95, 0.45, 1.0, hang2)
    for k in range(3):
        z = 0.15 + k * 0.22
        m.box((0.6, 0.4, 0.03), pos=(1.2, 0.2, z), color="WOOD")
        for j in range(4):
            m.cyl(0.05, 0.05, 0.02, pos=(1.0 + j * 0.13, 0.2, z + 0.03), color="8a5a36", seg=6)
    for dx in (-0.28, 0.28):
        for dy in (-0.18, 0.18):
            m.box((0.04, 0.04, 0.68), pos=(1.2 + dx, 0.2 + dy, 0), color="WOOD_DARK")
    for k in range(2):
        m.cyl(0.15, 0.12, 0.16, pos=(1.05 + k * 0.05, -0.95 + k * 0.0, k * 0.16), color="d9b98a", seg=8, cap="WOOD_DARK")
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
        # healer's sign: a big green leaf on a white round board on a bracket by the door (no cross)
        m.box((0.05, 0.05, 1.5), pos=(-0.95, -0.95, 0), color="WOOD_DARK")
        m.box((0.4, 0.05, 0.05), pos=(-0.78, -0.95, 1.45), color="WOOD_DARK")
        m.cyl(0.24, 0.24, 0.05, pos=(-0.68, -0.95, 1.08), rot=(math.pi / 2, 0, 0), color="ffffff", seg=12)
        m.sphere(0.13, pos=(-0.68, -0.99, 1.08), scl=(0.7, 0.25, 1.25), rot=(0, 0.5, 0), color="5fa85a", seg=8, rings=4)
        m.box((0.02, 0.03, 0.22), pos=(-0.68, -1.02, 0.97), rot=(0, 0.5, 0), color="3f7a45")
        pot(m, 0.95, -1.0, 0.9, flower="LOTUS")
    house("healer", 2.5, 1.5, 1.25, 1.0, -0.3, [0.5], (-0.85, 0.15), 211, extras=ex, walls=("framed", LIME),
          roof="tile", roof_col=TEAL_TILE, roof_under=TEAL_TILE_UNDER, shutter=SHUTTER[0], lamp=True,
          posts=[-1.25, -0.6, 0.15, 1.25]).export(OUT)


def build_weaver():
    """베틀집 (방직소, v3): ochre workshop under a red tile gable + an open plank lean-to sheltering a big loom with a
    bright warp; bolts of dyed cloth drying on a line, yarn skeins, wool basket."""
    def ex(m):
        x0, x1 = -2.2, -1.15
        for y in (-0.65, 0.6):
            post(m, x0, y, 0.95, 0.08)
        ln = math.hypot(x1 - x0 + 0.15, 0.35)
        m.box((ln, 1.45, 0.06), pos=((x0 + x1) / 2 - 0.05, 0, 1.0), rot=(0, -math.atan2(0.35, x1 - x0 + 0.15), 0),
              color=SHINGLE)
        # big loom: frame, warp in stripes, cloth beam, bench
        lx, ly = -1.7, -0.1
        for dx in (-0.38, 0.38):
            m.box((0.06, 0.06, 0.9), pos=(lx + dx, ly, 0), color="WOOD")
            m.box((0.06, 0.5, 0.06), pos=(lx + dx, ly + 0.05, 0.3), color="WOOD")
        m.box((0.82, 0.07, 0.06), pos=(lx, ly, 0.86), color="WOOD")
        m.box((0.82, 0.07, 0.06), pos=(lx, ly, 0.3), color="WOOD")
        for k in range(6):
            m.box((0.1, 0.02, 0.55), pos=(lx - 0.28 + k * 0.112, ly - 0.01, 0.33), color=YARN[k % 4])
        m.box((0.7, 0.025, 0.16), pos=(lx, ly - 0.02, 0.33), color=shade(YARN[0], 1.25))
        m.cyl(0.06, 0.06, 0.76, pos=(lx - 0.38, ly - 0.25, 0.4), rot=(0, math.pi / 2, 0), color=YARN[1], seg=6)
        stool(m, lx, ly - 0.45, 0.2)
        # dyed cloth on a line in front + bolts
        line_with(m, -0.3, 1.5, -1.05, 1.0, [(YARN[1], 0.32, 0.5), (YARN[2], 0.32, 0.42), (YARN[3], 0.32, 0.55),
                                              (YARN[0], 0.32, 0.46)])
        for k, c in enumerate(YARN):
            m.cyl(0.08, 0.08, 0.5, pos=(1.25, 0.2 + k * 0.17, 0.08 + (k % 2) * 0.0), rot=(0, math.pi / 2, 0), color=c, seg=7)
        for k, c in enumerate(YARN):
            m.sphere(0.07, pos=(0.85 + (k % 2) * 0.15, -0.7 + (k // 2) * 0.05, 0.07 + (k // 2) * 0.1), color=c, seg=7, rings=4)
        m.cyl(0.17, 0.14, 0.2, pos=(-1.0, -1.0, 0), color="d9b98a", seg=8, cap="WOOD_DARK")
        for k in range(3):
            m.sphere(0.08, pos=(-1.05 + k * 0.06, -1.02 + (k % 2) * 0.05, 0.22), color=WOOL, seg=6, rings=4, lumps=0.3,
                     group="body_nl")
    house("weaver", 2.3, 1.45, 1.3, 1.1, 0.35, [-0.45], (-0.6, 0.15), 212, extras=ex, walls=("framed", OCHRE),
          roof="tile", roof_col=TILE, roof_under=TILE_UNDER, shutter=SHUTTER[3]).export(OUT)


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
    """예배당 (교회, v3): lime-white chapel, gable to the front under a steep slate roof, a square bell tower at the
    back with open belfry, golden bell and a tall slate spire (finial ball, no cross), tall arched windows,
    round window, big arched door, yard with flowers."""
    W, D, H, rise = 2.0, 3.0, 1.5, 1.6
    m = house("chapel", W, D, H, rise, 0.0, [], None, 241, walls=("framed", LIME), roof="tile_front",
              roof_col=SLATE_ROOF, roof_under=SLATE_ROOF_UNDER, boxes=False, side_win=False, steps=2, lamp=False,
              posts=[-W / 2, W / 2], door_col="8a5a3a")
    door(m, 0.0, -D / 2 - 0.005, w=0.62, h=1.05, col="8a5a3a")
    for y in (-0.8, 0.0, 0.8):
        for sx in (-1, 1):
            m.box((0.03, 0.26, 0.6), pos=(sx * (W / 2 + 0.012), y, 0.55), color="WOOD_DARK")
            m.box((0.04, 0.18, 0.5), pos=(sx * (W / 2 + 0.02), y, 0.58), color="WINDOW_LIT")
            m.cyl(0.09, 0.09, 0.04, pos=(sx * (W / 2 + 0.0), y, 1.08), rot=(0, math.pi / 2, 0), color="WINDOW_LIT", seg=5)
    # bell tower at the back, rising well above the ridge
    T = 0.86
    ty = D / 2 - 0.2
    top = H + rise + 0.75
    m.box((T + 0.1, T + 0.1, 0.18), pos=(0, ty, 0), color="STONE")
    m.box((T, T, top), pos=(0, ty, 0), color=LIME)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box((0.1, 0.1, top), pos=(sx * (T / 2 - 0.02), ty + sy * (T / 2 - 0.02), 0), color=shade(LIME, 0.9))
    # belfry: open arches on all four sides, bell hanging in the middle
    bz = top
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box((0.14, 0.14, 0.6), pos=(sx * (T / 2 - 0.05), ty + sy * (T / 2 - 0.05), bz), color=LIME)
    m.box((T * 0.7, T * 0.7, 0.6), pos=(0, ty, bz), color="4f5f63")
    m.cyl(0.18, 0.09, 0.28, pos=(0, ty - T * 0.36, bz + 0.18), color=BELL, seg=10, smooth=True, cap=shade(BELL, 0.8))
    m.sphere(0.05, pos=(0, ty - T * 0.36, bz + 0.16), color=shade(BELL, 0.7), seg=5, rings=3)
    m.box((T + 0.2, T + 0.2, 0.1), pos=(0, ty, bz + 0.6), color=shade(LIME, 0.9))
    m.cyl((T + 0.22) * 0.72, 0.0, 1.45, pos=(0, ty, bz + 0.7), color=SLATE_ROOF, seg=4, rot=(0, 0, math.pi / 4),
          bottom_cap=SLATE_ROOF_UNDER)
    m.cyl(0.03, 0.03, 0.25, pos=(0, ty, bz + 2.1), color=BELL, seg=5)
    m.sphere(0.08, pos=(0, ty, bz + 2.38), color=BELL, seg=7, rings=4)
    # round window high on the tower front
    m.cyl(0.13, 0.13, 0.04, pos=(0, ty - T / 2 - 0.01, top - 0.45), rot=(math.pi / 2, 0, 0), color="WOOD_DARK", seg=10)
    m.cyl(0.1, 0.1, 0.05, pos=(0, ty - T / 2 - 0.02, top - 0.45), rot=(math.pi / 2, 0, 0), color="WINDOW_LIT", seg=10)
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
    rotated(m, lambda: plank_roof(m, 1.2, 0.95, 0.9, 0.35, col=SHINGLE, over=0.15), 0.0, (sx, sy, 0))
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
    # steep pyramid shingle roof (v3 — no thatch)
    m.cyl(1.05, 0.0, 0.95, pos=(0, 0, Hp + 1.12), color=SHINGLE, seg=4, rot=(0, 0, math.pi / 4), bottom_cap=SHINGLE_UNDER)
    m.cyl(1.08, 1.0, 0.08, pos=(0, 0, Hp + 1.06), color=shade(SHINGLE, 0.8), seg=4, rot=(0, 0, math.pi / 4))
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


def net_frame(m, x0, x1, y, h=0.95, col="7a735a"):
    """Fishing net hung to dry between two poles: a sagging mesh of thin cords + red floats along the top."""
    for x in (x0, x1):
        m.cyl(0.035, 0.03, h + 0.1, pos=(x, y, 0), color="WOOD", seg=5)
    w = x1 - x0
    nx, nz = 7, 4
    for i in range(nx + 1):
        x = x0 + w * i / nx
        sag = 0.12 * math.sin(math.pi * i / nx)
        m.box((0.014, 0.014, h * 0.7 - sag), pos=(x, y, h * 0.25), color=col, group="body_nh")
    for k in range(nz + 1):
        z = h * 0.25 + (h * 0.7) * k / nz
        m.box((w, 0.014, 0.014), pos=((x0 + x1) / 2, y, z - 0.1 * (k / nz)), color=col, group="body_nh")
    for i in range(1, nx):
        m.sphere(0.035, pos=(x0 + w * i / nx, y - 0.02, h * 0.95 - 0.12 * math.sin(math.pi * i / nx)), color="FLAME",
                 seg=5, rings=3)


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
