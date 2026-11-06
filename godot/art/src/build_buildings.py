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


# ───────────────────────── shared parts ─────────────────────────
def thatch_roof(m, W, D, H, rise, ox=0.24, oy=0.17, thick=0.2, col="THATCH", under="THATCH_DARK", K=12, p=1.55,
                droop=0.05, end=0.2, end_drop=0.14, end_pinch=0.86, layers=(0.42, 0.74), step=0.07):
    """Thick, rounded gable roof (ridge along X). Eaves overhang ox / oy beyond walls W x D whose top is H.
    Layered thatch: the slope steps out at |s| = layers (each course overhangs the one below with a dark lip).
    The two end sections are pinched and dropped -> rounded 'loaf' ends like hand-drawn thatch."""
    hy = D / 2 + oy

    def zb(s):
        return H - droop + (rise + droop) * (1 - abs(s) ** p) ** (1 / p)

    def off(s):          # outward offset of the course that contains s (ridge course is proudest)
        return step * sum(1 for b in layers if abs(s) < b)

    # outer profile front eave -> ridge -> back eave, with lip segments at course boundaries
    ss = sorted(set([-1 + 2 * i / K for i in range(K + 1)] + [x * b for b in layers for x in (-1, 1)]))
    outer, kinds = [], []          # kinds[i] = type of segment i -> i+1: 's' slope, 'l' lip
    for s in ss:
        is_b = any(abs(abs(s) - b) < 1e-6 for b in layers)
        if is_b:
            lo, hi = off(s * 1.0001), off(s * 0.9999)        # outer side (lower course) / inner side (upper course)
            first, second = (lo, hi) if s < 0 else (hi, lo)
            outer.append((s, first))
            outer.append((s, second))
        else:
            outer.append((s, off(s)))
    pts = []
    for i, (s, o) in enumerate(outer):
        pts.append((s * (hy + o * 0.6), zb(s) + o))
    for i in range(len(outer) - 1):
        kinds.append("l" if abs(outer[i][0] - outer[i + 1][0]) < 1e-9 else "s")

    def section(scale, dz):
        out = [(y * scale, z + dz) for y, z in pts]
        inner = []
        for i in range(K + 1):
            s = -1 + 2 * i / K
            inner.append((s * (hy - thick * 0.55) * scale, zb(s) - thick + dz))
        return out, inner

    L = W + 2 * ox
    xs = [-L / 2, -L / 2 + end, L / 2 - end, L / 2]
    rings = []
    for j, x in enumerate(xs):
        e = j in (0, 3)
        out, inner = section(*((end_pinch, -end_drop) if e else (1.0, 0.0)))
        rings.append([Vector((x, y, z)) for y, z in out] + [Vector((x, y, z)) for y, z in reversed(inner)])
    n = len(rings[0])
    n_out = len(pts) - 1
    bm = m._bm("body")
    vr = [[bm.verts.new(q) for q in r] for r in rings]
    slope, lips, other = [], [], []
    for a, b in zip(vr[:-1], vr[1:]):
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((a[i], b[i], b[j], a[j]))
            if i < n_out:
                (lips if kinds[i] == "l" else slope).append(f)
            else:
                other.append(f)
    caps = [bm.faces.new(list(reversed(vr[0]))), bm.faces.new(vr[-1])]
    bmesh.ops.recalc_face_normals(bm, faces=slope + lips + other + caps)
    bm.normal_update()
    m._finish(bm, slope, col, True)
    m._finish(bm, lips, under, False)
    m._finish(bm, other, under, False)
    m._finish(bm, caps, shade(col, 0.86), False)
    return hy


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
        k = 7 if arch else 1
        for i in range(k + 1):
            a = i / k * math.pi
            pts.append((ww / 2 * math.cos(a), hh - (ww / 2 if arch else 0) + (ww / 2 * math.sin(a) if arch else 0)))
        return [(-px, pz) for px, pz in pts]      # prism profile y -> world -x after the 90 deg turn
    m.prism(outline(w + 0.1, h + 0.05), 0.03, pos=(x, y + face * 0.012, 0.0), rot=(0, 0, math.pi / 2), color="WOOD_DARK")
    m.prism(outline(w, h), 0.03, pos=(x, y + face * 0.03, 0.0), rot=(0, 0, math.pi / 2), color=col)
    for k in (-1, 1):
        m.box((0.035, 0.02, h * 0.62), pos=(x + k * w * 0.2, y + face * 0.05, 0.08), color=shade(col, 0.8))
    m.box((0.05, 0.03, 0.05), pos=(x + w * 0.3, y + face * 0.05, h * 0.42), color="WOOD_DARK")   # handle
    m.box((w + 0.18, 0.18, 0.06), pos=(x, y + face * 0.09, 0.0), color="STONE_DARK")             # step


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


def chimney(m, x, y, top, w=0.3, col="STONE"):
    m.box((w, w, top), pos=(x, y, 0.3), color=col)
    m.box((w + 0.08, w + 0.08, 0.1), pos=(x, y, 0.3 + top), color="STONE_DARK")
    m.box((w - 0.1, w - 0.1, 0.02), pos=(x, y, 0.3 + top + 0.095), color="WINDOW")
    for k in range(2):
        m.box((w + 0.02, 0.02, 0.09), pos=(x, y - w / 2 - 0.005, 0.3 + top - 0.25 - k * 0.3), color=shade(col, 0.9))


def barrel(m, x, y, s=1.0, z=0.0):
    m.cyl(0.17 * s, 0.17 * s, 0.4 * s, pos=(x, y, z), color="WOOD", seg=9, smooth=True, cap="STUMP_TOP")
    for hz in (0.07, 0.31):
        m.cyl(0.18 * s, 0.18 * s, 0.035 * s, pos=(x, y, z + hz * s), color="WOOD_DARK", seg=9, smooth=True)


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


# ───────────────────────── cottages ─────────────────────────
def cottage(name, W, D, H, rise, door_x, win_xs, chim_x, seed, extras=None, walls="stone", roof_col="THATCH",
            roof_under="THATCH_DARK", p=1.55, side_win=True):
    m = Model(name, seed)
    if walls == "stone":
        stone_walls(m, W, D, H, seed=seed)
    elif walls == "plank":
        plank_walls(m, W, D, H)
    else:
        walls(m, W, D, H)
    gable_wall(m, W, D, H, rise, p=p, col="PLASTER")
    thatch_roof(m, W, D, H, rise, col=roof_col, under=roof_under, p=p)
    door(m, door_x, -D / 2, w=0.4, h=min(0.82, H - 0.4))
    for x in win_xs:
        window(m, x, min(H * 0.5, 0.68), -D / 2)
    if side_win:
        window(m, W / 2 + 0.01, H * 0.5, 0.0, w=0.26, h=0.24, face=1, side=True)
    if chim_x is not None:
        chimney(m, chim_x, D * 0.18, H + rise - 0.05)
    if extras:
        extras(m)
    return m


def build_cottages():
    cottage("cottage_a", 1.9, 1.25, 1.4, 1.2, -0.3, [0.45], 0.55, 11,
            extras=lambda m: (barrel(m, 1.12, -0.3), sack(m, 1.1, 0.05, 0.8))).export(OUT)
    def b_extra(m):
        sack(m, -1.25, -0.45, 0.9)
        barrel(m, -1.28, -0.1, 0.85)
    cottage("cottage_b", 2.1, 1.3, 1.35, 1.25, 0.3, [-0.45, 0.82], -0.6, 12, extras=b_extra).export(OUT)
    # pioneer hut: plank walls, low roof, no chimney
    cottage("hut", 1.5, 1.1, 1.15, 1.0, 0.15, [-0.4], None, 13, walls="plank", side_win=False).export(OUT)


def build_houses():
    # 목조주택: two storeys, half-timbered plaster over a stone ground course
    def timber_walls(m, W, D, H):
        m.box((W, D, H), color="PLASTER")
        m.box((W + 0.06, D + 0.06, 0.45), color="STONE")
        m.box((W + 0.1, D + 0.1, 0.12), color="STONE_DARK")
        for x in (-W / 2, -W / 6, W / 6, W / 2):
            m.box((0.07, 0.03, H - 0.45), pos=(x, -D / 2 - 0.012, 0.45), color="WOOD_DARK")
        for z in (0.45, H * 0.6, H - 0.06):
            m.box((W + 0.02, 0.03, 0.07), pos=(0, -D / 2 - 0.012, z), color="WOOD_DARK")
        for x0 in (-W / 3, W / 3):
            ln = math.hypot(W / 3, H * 0.6 - 0.45)
            a = math.atan2(H * 0.6 - 0.45, W / 3)
            m.box((ln, 0.03, 0.06), pos=(x0 - math.copysign(W / 6, x0) * 0 , -D / 2 - 0.014, 0.45 + (H * 0.6 - 0.45) / 2 - 0.03),
                  rot=(0, -a if x0 < 0 else a, 0), color="WOOD_DARK")
        for y in (-D / 2, D / 2):
            for sx in (-1, 1):
                m.box((0.03, 0.07, H - 0.45), pos=(sx * (W / 2 + 0.012), y * 0.98, 0.45), color="WOOD_DARK")

    def t_extra(m):
        for x in (-0.75, 0.0, 0.75):
            window(m, x, 1.38, -0.75, w=0.28, h=0.26)
        m.box((0.4, 0.12, 0.08), pos=(0.75, -0.83, 1.25), color="WOOD")       # flower box
        for k in range(3):
            m.sphere(0.06, pos=(0.63 + k * 0.12, -0.83, 1.35), color=("LOTUS", "WINDOW_LIT", "LOTUS")[k], seg=6, rings=4)
        barrel(m, 1.4, -0.8)
        barrel(m, 1.2, -1.0, 0.85)

    cottage("house_timber", 2.4, 1.5, 2.0, 1.3, -0.35, [0.55], 0.75, 21, walls=timber_walls, extras=t_extra).export(OUT)

    # 석조주택: big stone house, grey slate roof (straighter, thinner)
    def s_extra(m):
        window(m, -0.75, 1.25, -0.775, w=0.3, h=0.3)
        window(m, 0.75, 1.25, -0.775, w=0.3, h=0.3)
        crate(m, 1.45, -0.85, 0.9)
    m = cottage("house_stone", 2.4, 1.55, 1.8, 1.1, 0.0, [-0.75, 0.75], -0.75, 22, roof_col="ROOF_GREY",
                roof_under=shade("ROOF_GREY", 0.8), p=1.15, extras=s_extra)
    chimney(m, 0.8, 0.3, 1.8 + 1.1 - 0.05)
    m.export(OUT)


# ───────────────────────── work buildings ─────────────────────────
def build_store():
    """창고: open-fronted thatched shed on posts with barrels, sacks and crates."""
    m = Model("storehouse", 31)
    W, D, H = 2.5, 1.7, 1.15
    m.box((W + 0.1, D + 0.1, 0.1), color="STONE_DARK")
    m.box((W, 0.1, H), pos=(0, D / 2 - 0.05, 0.1), color="WOOD")                     # back wall
    for i in range(int(W / 0.22)):
        x = -W / 2 + 0.11 + i * 0.22
        m.box((0.2, 0.02, H - 0.05), pos=(x, D / 2 - 0.105, 0.12), color=shade("WOOD", 0.92 if i % 2 else 1.05))
    for sx in (-1, 1):
        m.box((0.1, D, H), pos=(sx * (W / 2 - 0.05), 0, 0.1), color="WOOD")              # side walls
    for x in (-W / 2, 0, W / 2):
        post(m, x, -D / 2 + 0.05, H + 0.1, 0.12)
        m.box((0.18, 0.18, 0.12), pos=(x, -D / 2 + 0.05, 0), color="STONE")
    m.box((W + 0.1, 0.1, 0.1), pos=(0, -D / 2 + 0.05, H), color="WOOD_DARK")
    gable_wall(m, W, D, H + 0.1, 0.9, col="WOOD", timber=False)
    thatch_roof(m, W, D, H + 0.1, 0.9)
    barrel(m, -0.85, 0.35)
    barrel(m, -0.5, 0.45)
    barrel(m, -0.68, 0.38, z=0.4)
    sack(m, 0.0, 0.2)
    sack(m, 0.3, 0.35, 0.9, rz=0.6)
    sack(m, 0.12, 0.42, 0.85, z=0.28)
    crate(m, 0.85, 0.35)
    crate(m, 0.85, 0.35, 0.85, z=0.32, rz=0.3)
    crate(m, 1.15, -0.6)
    m.export(OUT)


def build_well():
    m = Model("well", 41)
    m.cyl(0.46, 0.44, 0.5, color="STONE", seg=12, smooth=False)
    for k in range(12):
        a = k * math.tau / 12 + (0.13 if k % 2 else 0)
        z = 0.1 + (k % 3) * 0.12
        m.box((0.16, 0.03, 0.09), pos=(math.cos(a) * 0.455, math.sin(a) * 0.455, z), rot=(0, 0, a + math.pi / 2),
              color=shade("STONE", 0.9 if k % 2 else 1.05))
    m.cyl(0.5, 0.5, 0.09, pos=(0, 0, 0.5), color="STONE_DARK", seg=12, cap="STONE")
    m.cyl(0.33, 0.33, 0.02, pos=(0, 0, 0.58), color="WATER", seg=12)
    for sx in (-1, 1):
        post(m, sx * 0.42, 0, 1.25, 0.1)
    m.cyl(0.04, 0.04, 0.95, pos=(-0.47, 0, 0.98), rot=(0, math.pi / 2, 0), color="WOOD", seg=6)   # windlass
    m.box((0.04, 0.2, 0.04), pos=(0.52, -0.1, 0.96), color="WOOD")
    m.box((0.015, 0.015, 0.35), pos=(0, 0, 0.62), color="WOOD_DARK")                                 # rope
    m.cyl(0.09, 0.08, 0.14, pos=(0, 0, 0.6), color="WOOD", seg=8, cap="WATER")                         # bucket
    plank_roof(m, 1.0, 0.75, 1.22, 0.42)
    for sx in (-1, 1):
        m.sphere(0.12, pos=(sx * 0.62, -0.32, 0.1), color="BUSH", seg=7, rings=4, lumps=0.2)
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
    m = Model("sawmill", 61)
    W, D, H = 2.2, 1.5, 1.15
    m.box((W + 0.2, D + 0.2, 0.08), color=shade("PATH", 0.95))
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            post(m, x, y, H, 0.12)
    for y in (-D / 2, D / 2):
        m.box((W + 0.1, 0.1, 0.1), pos=(0, y, H - 0.08), color="WOOD_DARK")
        for sx in (-1, 1):   # knee braces
            m.box((0.06, 0.06, 0.4), pos=(sx * (W / 2 - 0.15), y, H - 0.35), rot=(0, sx * 0.7, 0), color="WOOD_DARK")
    thatch_roof(m, W, D, H, 0.85, droop=0.1)
    # saw bench with a log and a big blade
    m.box((1.3, 0.35, 0.35), pos=(0, 0, 0.0), color="WOOD")
    log(m, 0.1, 0.0, 0.47, 1.4, 0.13)
    m.box((0.035, 0.6, 0.5), pos=(0.0, 0.0, 0.32), color="ROCK")
    m.box((0.06, 0.08, 0.14), pos=(0.0, -0.33, 0.62), color="WOOD_DARK")
    # log pile outside (+x) and plank stack (front)
    for row in range(3):
        for i in range(3 - row):
            m.cyl(0.13, 0.13, 1.0, pos=(W / 2 + 0.45 + (i - (2 - row) / 2) * 0.27, -0.5, 0.13 + row * 0.23),
                  rot=(-math.pi / 2, 0, 0), color="TRUNK", seg=7, cap="STUMP_TOP")
    for k in range(4):
        m.box((1.0, 0.28, 0.07), pos=(-0.35 + (k % 2) * 0.03, -D / 2 - 0.45, k * 0.075), color=shade("PLANK", 1.0 if k % 2 else 0.92))
        m.box((1.0, 0.28, 0.07), pos=(-0.35, -D / 2 - 0.15, k * 0.075), color=shade("PLANK", 0.95 if k % 2 else 1.03))
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
    # thatched cap
    m.cyl(0.72, 0.02, 0.95, pos=(0, 0, 2.05), color="THATCH", seg=12, smooth=True)
    m.cyl(0.74, 0.7, 0.12, pos=(0, 0, 2.0), color="THATCH_DARK", seg=12)
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
    def extras(m):
        # clay oven on the +x side with a glowing mouth
        m.box((0.85, 0.8, 0.35), pos=(1.35, 0.0, 0), color="STONE")
        m.sphere(0.42, pos=(1.35, 0.0, 0.35), scl=(1, 1, 0.85), color="ROOF_RED", seg=10, rings=6)
        m.cyl(0.17, 0.17, 0.1, pos=(1.35, -0.38, 0.35), rot=(math.pi / 2, 0, 0), color="FLAME", seg=8)
        m.cyl(0.1, 0.1, 0.11, pos=(1.35, -0.39, 0.32), rot=(math.pi / 2, 0, 0), color="FLAME2", seg=8)
        m.cyl(0.09, 0.08, 0.35, pos=(1.45, 0.15, 0.65), color="STONE_DARK", seg=7)
        # awning + table with bread at the front
        m.box((1.1, 0.7, 0.05), pos=(-0.5, -1.05, 0.95), rot=(-0.35, 0, 0), color="PLASTER")
        for k in range(4):
            m.box((0.12, 0.72, 0.055), pos=(-0.95 + k * 0.3, -1.05, 0.955), rot=(-0.35, 0, 0), color="ROOF_RED")
        for x in (-1.0, 0.0):
            post(m, x, -1.35, 0.85, 0.06, "WOOD")
        m.box((0.9, 0.4, 0.06), pos=(-0.5, -1.15, 0.42), color="WOOD")
        for x in (-0.85, -0.15):
            post(m, x, -1.15, 0.42, 0.06, "WOOD_DARK")
        for k in range(3):
            m.sphere(0.12, pos=(-0.75 + k * 0.25, -1.15, 0.53), scl=(1.2, 0.9, 0.7), color="BREAD", seg=8, rings=5)
        barrel(m, 1.05, -0.75, 0.8)
    cottage("bakery", 2.0, 1.3, 1.4, 1.1, 0.35, [-0.35], -0.55, 91, extras=extras).export(OUT)


def build_forester():
    def extras(m):
        m.sphere(0.3, pos=(-1.15, 0.5, 0.25), color="BUSH", seg=8, rings=5, lumps=0.2)
    cottage("forester", 1.6, 1.15, 1.2, 1.05, -0.2, [0.4], 0.45, 101, extras=extras).export(OUT)


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
        m.box((S - 0.45, 0.22, 0.05), pos=(0, y, 0.06), color=shade("FIELD_SOIL", 0.88))
        n = 15
        for k in range(n):
            x = -S / 2 + 0.35 + k * (S - 0.7) / (n - 1) + r.uniform(-0.04, 0.04)
            h = r.uniform(0.38, 0.5) if ripe else r.uniform(0.22, 0.3)
            c = shade(crop, r.choice((0.92, 1.0, 1.08)))
            m.cyl(0.11, 0.035, h, pos=(x, y + r.uniform(-0.04, 0.04), 0.08), color=c, seg=5, group="body_nl")
            if ripe:
                m.sphere(0.06, pos=(x, y, 0.08 + h), scl=(1, 1, 1.6), color=shade("CROP_RIPE", 1.1), seg=5, rings=3, group="body_nl")
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
