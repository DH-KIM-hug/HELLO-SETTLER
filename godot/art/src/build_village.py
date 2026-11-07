"""Village-era buildings (ROADMAP A6, BUILDINGS 3.1) + the mushroom-picker's drying yard, in the tiny-folk materials
of GAME_DESIGN 3.0 (E3-5) and the waterside set (E3-6): no planks, logs or sawn timber — reeds and twigs lashed with
grass cord, woven grass, clay daub, pebbles, petals, leaves, acorn caps, seed shells, lily pads. Shared shapes in
tiny_kit.py. Each building has its own silhouette tied to its use (lily-pad hat on stilts = 어장, bark tepee with a
feather = 사냥막, clover roof = 약초원, bell-flower tower = 예배당 ...).
Footprints follow the v3 models (view/village_view.gd BUILDING_MODELS comment):
  어부 1.6x1.2 · 사냥꾼 1.6x1.2 · 약초꾼 1.7x1.2 · 치료소 2.5x1.5 (+porch right) · 방직소 2.3x1.5 (+loom left)
  대장간 1.5x1.5 (+forge right) · 교회 2.0x3.0 (+tower front) · 광장 d3.8 · 묘지 2.6x2.2 · 목장 4.0x3.4 · 망루 1.4x1.4 h~4.8
  나루터 = like pier.glb: origin at the shore, deck along +X 2.6 over the water (deck top z ~0.25), a leaf boat beside.
Run: blender -b --factory-startup --python build_village.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, out_dir_from_argv  # noqa: E402
from flora_kit import leaf, tube, cup  # noqa: E402
from tiny_kit import *  # noqa: E402,F401,F403
import bmesh  # noqa: E402

OUT = out_dir_from_argv()
FISH = "9fb8c4"
FISH_DARK = "7d97a6"
HIDE = "b98a5e"
HIDE_LIGHT = "d4ad82"
WOOL = "f6f1e6"
YARN = ("5f7c96", "c8644e", "efc35a", "7d9a62", "b49ce0")
LAVENDER = "a98ad0"
IRON = "5d6466"


# ───────────────────────── small parts ─────────────────────────
def fish(m, x, y, z, s=1.0, rz=0.0, col=FISH):
    """Little fish lying on its side (body + tail fin)."""
    m.sphere(0.12 * s, pos=(x, y, z), scl=(1.6, 0.55, 0.8), rot=(0, 0, rz), color=col, seg=8, rings=4)
    c, sn = math.cos(rz), math.sin(rz)
    tx, ty = x - c * 0.22 * s, y - sn * 0.22 * s
    m.cyl(0.0, 0.09 * s, 0.12 * s, pos=(tx + c * 0.06 * s, ty + sn * 0.06 * s, z), rot=(0, -math.pi / 2, rz),
          color=FISH_DARK, seg=4)


def hanging_fish(m, x, y, z, s=1.0):
    m.box((0.012, 0.012, 0.08), pos=(x, y, z - 0.08), color=CORD, group="body_nh")
    m.sphere(0.1 * s, pos=(x, y, z - 0.22 * s), scl=(0.55, 0.8, 1.6), color=FISH, seg=7, rings=4)
    m.cyl(0.0, 0.07 * s, 0.1 * s, pos=(x, y, z - 0.46 * s), color=FISH_DARK, seg=4)


def drying_rail(m, x0, x1, y, h, items):
    """Two forked twig posts with a reed rail; items(x, z, k) hangs things along it."""
    forked_post(m, x0, y, h)
    forked_post(m, x1, y, h)
    stem(m, (x0 - 0.1, y, h), (x1 + 0.1, y, h), 0.03, REED, REED_NODE, 2, 5)
    n = max(2, int((x1 - x0) / 0.22))
    for k in range(n):
        items(x0 + (k + 0.5) * (x1 - x0) / n, h, k)


def lily_hat(m, cx, cy, z, r=1.0, col=LILY_PAD):
    """A giant lily pad laid over as a hat roof: shallow dome, notch at the back, radial pale veins, rolled rim."""
    seg, J = 20, 4
    notch = 0.32
    rings = []
    for j in range(J + 1):
        t = j / J
        rr = r * (1 - t) + 0.04
        ring = []
        for i in range(seg + 1):
            a = math.pi / 2 + notch / 2 + (math.tau - notch) * i / seg
            ring.append(Vector((cx + math.cos(a) * rr, cy + math.sin(a) * rr, z + 0.32 * math.sin(t * math.pi / 2) - 0.06 * (1 - t))))
        rings.append(ring)
    fs = m.strip(rings, color=col, group="body_nl", smooth=True)
    under = m.strip([[p - Vector((0, 0, 0.05)) for p in r_] for r_ in rings], color=shade(col, 0.75), group="body_nl", smooth=True)
    bm = m._bm("body_nl")
    for f in fs:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    for f in under:
        f.normal_update()
        if f.normal.z > 0:
            f.normal_flip()
    edge = m.strip([rings[0], [p - Vector((0, 0, 0.05)) for p in rings[0]]], color=shade(col, 0.85), group="body_nl")
    for f in edge:
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(Vector((c.x - cx, c.y - cy, 0))) < 0:
            f.normal_flip()
    bm.normal_update()
    for k in range(7):
        a = math.pi / 2 + notch / 2 + (math.tau - notch) * (k + 0.5) / 7
        pts = [Vector((cx + math.cos(a) * r * t, cy + math.sin(a) * r * t, z + 0.32 * math.sin((1 - t) * math.pi / 2) - 0.06 * t + 0.03))
               for t in (0.1, 0.5, 0.95)]
        tube(m, pts, 0.022, seg=3, color=LILY_VEIN, group="body_nh")
    m.sphere(0.07, pos=(cx, cy, z + 0.34), color=shade(col, 0.8), seg=6, rings=3)


def feather(m, base, d, ln=1.0, w=0.16, col="f4efe2", band="8a6a4c"):
    """A big feather (banner): quill + vane with dark bands."""
    base = Vector(base)
    d = Vector(d).normalized()
    pts = [base + d * ln * t for t in (0, 0.25, 0.5, 0.75, 1.0)]
    side = d.cross(Vector((0, 0, 1)))
    nrm = side.cross(d).normalized() if side.length > 1e-4 else Vector((0, -1, 0))
    nrm = Vector((0, -1, 0)) if abs(d.z) > 0.9 else nrm

    def cf(f, k):
        return band if k in (2, 4) else col
    leaf(m, pts, [0.02, w * 0.8, w, w * 0.8, 0.02], nrm, thick=0.025, color=col, colfn=cf, group="body_nl")
    tube(m, [base - d * 0.15, base + d * ln * 0.95], 0.015, seg=3, color="e8dcc0", group="body_nh")


def hide_frame(m, x, y, rz=0.0, r=0.4, col=HIDE):
    """A hide stretched in a bent-twig hoop on a forked stand."""
    def _b():
        pts = [Vector((math.cos(a) * r, 0, 0.75 + math.sin(a) * r * 1.1)) for a in [i * math.tau / 10 for i in range(11)]]
        tube(m, pts, 0.025, seg=4, color=TWIG)
        m.sphere(1.0, pos=(0, 0, 0.75), scl=(r * 0.85, 0.03, r * 0.95), color=col, seg=10, rings=5, lumps=0.08,
                 colfn=lambda f: HIDE_LIGHT if f.normal.y < 0 and f.calc_center_median().z > 0.8 else col)
        for k in range(6):
            a = k * math.tau / 6
            cord(m, (math.cos(a) * r * 0.85, 0, 0.75 + math.sin(a) * r * 0.95),
                 (math.cos(a) * r, 0, 0.75 + math.sin(a) * r * 1.1), r=0.008, n=1)
        for s in (-1, 1):
            twig(m, (s * 0.2, 0.05, 0), (s * r * 0.75, 0.0, 0.48), 0.025, TWIG_DARK)
    placed(m, _b, (x, y, 0), rz)


def slate_gable(m, W, D, H, rise, over=0.2, rows=4, seed=0, sides=(-1, 1), ridge=True):
    """Gable roof (ridge along X) of overlapping flat slate pebbles in offset rows, a pebble ridge."""
    half = D / 2 + over
    ang = math.atan2(rise, half)
    ln = math.hypot(half, rise)
    Wt = W + over * 1.2
    for sy in sides:
        prof = [(0, H + rise), (sy * half, H - 0.02), (sy * half, H - 0.07), (0, H + rise - 0.07)]
        m.prism(prof if sy < 0 else list(reversed(prof)), Wt, color=shade(SLATE, 0.75), group="body_nl")
        down = Vector((0, sy * math.cos(ang), -math.sin(ang)))
        nrm = Vector((0, sy * math.sin(ang), math.cos(ang)))
        for r in range(rows):
            n = max(3, int(Wt / 0.34)) + (r % 2)
            t = 1 - (r + 0.5) / rows
            for k in range(n):
                x = -Wt / 2 + (k + (0.5 if r % 2 == 0 else 0.0)) * Wt / (n - (r % 2))
                x = max(-Wt / 2 + 0.12, min(Wt / 2 - 0.12, x))
                c = Vector((x, 0, H + rise)) + down * (ln * t) + nrm * (0.04 + 0.015 * r)
                col = (SLATE, shade(SLATE, 1.1), "9fa8a4", shade(SLATE, 0.92))[(k * 3 + r + seed) % 4]
                m.sphere(1.0, pos=c, scl=(Wt / n * 0.62, ln / rows * 0.75, 0.04), rot=(-sy * ang, 0, ((k + r) % 3 - 1) * 0.08),
                         color=col, seg=8, rings=3, smooth=False)
    for k in range(int(Wt / 0.3) + 1 if ridge else 0):
        pebble(m, -Wt / 2 + 0.15 + k * 0.3, 0, H + rise + 0.02, 0.15, 0.13, 0.08, shade(PEBBLE, 0.9 + 0.05 * (k % 3)), k, k + seed)


def cot(m, x, y, rz=0.0, blanket="9cc3d6"):
    """Sick-bed: reed frame on four short twig legs, a puffy dandelion-down mattress, a petal blanket, a pillow."""
    def _b():
        for sx in (-1, 1):
            stem(m, (sx * 0.24, -0.5, 0.22), (sx * 0.24, 0.5, 0.22), 0.03, REED, REED_NODE, 2, 5)
            for sy in (-1, 1):
                twig(m, (sx * 0.24, sy * 0.45, 0), (sx * 0.24, sy * 0.45, 0.24), 0.025, TWIG_DARK)
        m.sphere(1.0, pos=(0, 0, 0.3), scl=(0.25, 0.5, 0.08), color=DOWN, seg=10, rings=4, lumps=0.08)
        m.sphere(1.0, pos=(0, 0.08, 0.36), scl=(0.27, 0.36, 0.05), color=blanket, seg=8, rings=3)
        m.sphere(0.1, pos=(0, -0.36, 0.38), scl=(1.6, 0.9, 0.6), color="ffffff", seg=7, rings=4)
    placed(m, _b, (x, y, 0), rz)


def bell_flower(m, p, r=0.13, col="f6f1e4"):
    """Lily-of-the-valley bell hanging mouth down from p (scalloped rim)."""
    p = Vector(p)
    cup(m, p - Vector((0, 0, r * 1.5)), Vector((0, 0, 1)), [(r * 1.05, 0.0), (r * 0.95, r * 0.3), (r * 0.85, r * 0.9),
                                                              (r * 0.4, r * 1.4), (0.01, r * 1.5)],
        seg=10, color=col, inner=shade(col, 0.82), group="body", tips=5, tip_h=-r * 0.25)


def headstone(m, x, y, rz=0.0, s=1.0, moss=False, col=PEBBLE):
    """Grave marker: an upright flat pebble, a little pebble ring and a petal before it."""
    m.sphere(1.0, pos=(x, y, 0.2 * s), scl=(0.18 * s, 0.07 * s, 0.24 * s), rot=(0, 0, rz), color=col, seg=10, rings=5,
             lumps=0.05, seed=int(x * 10), colfn=(lambda f: "MOSS" if f.normal.z > 0.6 else col) if moss else None)
    for k in range(4):
        a = k * math.pi / 3 - math.pi / 2 - math.pi / 2 + rz
        pebble(m, x + math.cos(a) * 0.22 * s, y - 0.18 * s + math.sin(a) * 0.08, 0.02, 0.05, 0.04, 0.03, PEBBLE_DARK, a, k)


# ───────────────────────── small ─────────────────────────
def build_fisher():
    """어장 (어부): a woven round hut on reed stilts under a giant lily-pad hat, a ladder down; two long grass-stalk
    fishing rods bending out from a pebble pile with silk lines and bead floats, a woven fish trap, fish drying on a
    reed rail, a lily pad on the ground with the day's catch."""
    m = Model("fisher", 201)
    cx, cy, R, Hs = -0.75, 0.15, 0.62, 0.5
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        stem(m, (cx + math.cos(a) * R * 0.75, cy + math.sin(a) * R * 0.75, 0), (cx + math.cos(a) * R * 0.75, cy + math.sin(a) * R * 0.75, Hs + 0.05),
             0.05, REED_GREEN, REED_GREEN_NODE, 1, 6)
    lathe(m, cx, cy, Hs - 0.05, [(R + 0.2, 0.0), (R + 0.2, 0.06)], seg=16, colfn=weave_fn(), top=WEAVE)  # woven floor
    woven_round(m, cx, cy, R, 0.8, z0=Hs, cols=(WEAVE_GREEN, WEAVE_GREEN_DARK), stakes=False)
    lily_hat(m, cx, cy, Hs + 0.82, 1.0)
    placed(m, lambda: round_door(m, 0, 0, 0.36, 0.62, "leaf", LEAF_C), (cx + math.cos(-1.2) * R, cy + math.sin(-1.2) * R, Hs), -1.2 + math.pi / 2)
    placed(m, lambda: round_window(m, 0, 0, 0.42, 0.11), (cx + math.cos(-2.3) * R, cy + math.sin(-2.3) * R, Hs), -2.3 + math.pi / 2)
    reed_ladder(m, (cx + 0.3, cy - 1.15, 0), (cx + 0.3, cy - 0.78, Hs + 0.02), 0.26, 3)
    # rods from a pebble pile, bending out to the right with lines and floats
    for k in range(3):
        pebble(m, 0.9 + 0.12 * k, -0.55 + 0.06 * (k % 2), 0.08 + 0.06 * (k == 1), 0.16, 0.14, 0.12, shade(PEBBLE, 0.95 + 0.04 * k), k, k + 1)
    for k, (dy, tip) in enumerate(((-0.05, Vector((2.0, -0.9, 1.25))), (0.12, Vector((1.95, -0.25, 1.05))))):
        base = Vector((0.95, -0.55 + dy, 0.0))
        pts = [base, base + Vector((0.12, 0, 0.6)), base + Vector((0.45, (tip.y - base.y) * 0.5, 1.15)), tip]
        tube(m, pts, [0.03, 0.026, 0.02, 0.012], seg=4, color=REED_GREEN, cap=REED_GREEN_NODE)
        cord(m, tip, (tip.x + 0.02, tip.y, 0.12), r=0.006, col="e8e4da", n=1)
        m.sphere(0.05, pos=(tip.x + 0.02, tip.y, 0.1), color="e0607a", seg=6, rings=3)
    # woven fish trap (cone basket lying down)
    def _trap2():
        def _lie():
            lathe(m, 0, 0, 0, [(0.2, 0.0), (0.2, 0.15), (0.15, 0.4), (0.04, 0.62)], seg=10, colfn=weave_fn())
            m.cyl(0.21, 0.21, 0.04, pos=(0, 0, 0.0), color=CORD, seg=10)
        before = {g: set(bm.verts) for g, bm in m.groups.items()}
        _lie()
        from mathutils import Matrix
        rot = Matrix.Rotation(math.pi / 2, 4, "Y")
        for g, bm in m.groups.items():
            vs = [v for v in bm.verts if v not in before.get(g, ())]
            if vs:
                bmesh.ops.transform(bm, matrix=rot, verts=vs)
                bm.normal_update()
    placed(m, _trap2, (0.0, -1.05, 0.2), 0.35)
    # fish drying on a reed rail
    drying_rail(m, -1.75, -1.15, -0.85, 0.75, lambda x, z, k: hanging_fish(m, x, -0.85, z, 0.9))
    lily_pad(m, 1.35, 0.45, 0.0, 0.42, 1.1)
    fish(m, 1.3, 0.42, 0.1, 1.0, 0.5)
    fish(m, 1.45, 0.55, 0.12, 0.8, 2.2)
    woven_basket(m, 0.55, 0.55, 0, 0.17, 0.18, fill=FISH)
    m.export(OUT)


def build_hunter():
    """사냥막 (사냥꾼): a tepee of leaning twigs covered in bark strips (poles crossing out of the top, a smoke puff),
    a hide flap door; a tall feather banner, two hides stretched in twig hoops, a bent-twig bow, a rack of meat."""
    m = Model("hunter", 202)
    cx, cy, R, Ht = -0.35, 0.1, 0.85, 2.0
    n = 14
    rings = []
    for j, t in enumerate((0.0, 0.3, 0.6, 0.85)):
        ring = []
        for i in range(n):
            a = i * math.tau / n
            rr = R * (1 - t) * (1.0 + (0.04 if i % 2 else -0.02))
            ring.append(Vector((cx + math.cos(a) * rr, cy + math.sin(a) * rr, Ht * t)))
        rings.append(ring)
    fs = m.strip(rings, color=BARK, close=True)
    bm = m._bm("body")
    for idx, f in enumerate(fs):
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(Vector((c.x - cx, c.y - cy, 0))) < 0:
            f.normal_flip()
        m._finish(bm, [f], (BARK, BARK_LIGHT, BARK_DARK, BARK)[(idx % n + idx // n * 2) % 4], False)
    bm.normal_update()
    for k in range(6):                         # poles crossing out of the top
        a = k * math.tau / 6 + 0.2
        foot = Vector((cx + math.cos(a) * R * 1.02, cy + math.sin(a) * R * 1.02, 0))
        top = Vector((cx - math.cos(a) * 0.18, cy - math.sin(a) * 0.18, Ht + 0.45))
        twig(m, foot, top, 0.035, TWIG_DARK if k % 2 else TWIG)
    cord(m, (cx - 0.1, cy, Ht * 0.86), (cx + 0.1, cy, Ht * 0.86), r=0.03, n=1, group="body")
    smoke(m, cx, cy, Ht + 0.1, 2)
    # hide door flap (front)
    pts = [Vector((cx, cy - R * 0.62, Ht * 0.38)), Vector((cx - 0.02, cy - R * 0.8, Ht * 0.2)), Vector((cx, cy - R * 0.98, 0.02))]
    m.poly([pts[0] + Vector((0.0, -0.02, 0)), pts[2] + Vector((-0.24, -0.02, 0)), pts[2] + Vector((0.24, -0.02, 0))], color=DOOR_DARK)
    leaf(m, [pts[0] + Vector((0.06, -0.06, -0.05)), pts[1] + Vector((0.12, -0.06, 0)), pts[2] + Vector((0.2, -0.06, 0.02))],
         [0.04, 0.12, 0.14], Vector((0, -1, 0)), thick=0.03, color=HIDE_LIGHT, color_under=HIDE, group="body")
    # feather banner
    twig(m, (0.75, -0.55, 0), (0.78, -0.55, 1.55), 0.03, TWIG_DARK)
    feather(m, (0.78, -0.57, 1.45), (0.25, 0, 1.0), 0.95, 0.17)
    lash(m, (0.78, -0.55, 1.45), 0.04)
    hide_frame(m, 1.3, 0.25, 0.4, 0.38)
    hide_frame(m, -1.45, -0.55, -0.5, 0.3, HIDE_LIGHT)
    # bent-twig bow leaning on a pebble
    pts = [Vector((1.2 + 0.05 * math.sin(a), -0.85, 0.05 + 0.6 * (a + 1) / 2)) + Vector((0.12 * math.cos(a * 1.5), 0, 0))
           for a in [i / 4 * 2 - 1 for i in range(5)]]
    tube(m, pts, 0.02, seg=4, color=TWIG)
    cord(m, pts[0], pts[-1], r=0.006, col="e8e4da", n=1)
    pebble(m, 1.28, -0.95, 0.04, 0.1, 0.08, 0.06, PEBBLE, 0, 2)
    # meat rack
    drying_rail(m, -1.55, -1.05, 0.65, 0.7,
                lambda x, z, k: m.box((0.06, 0.03, 0.26), pos=(x, 0.65, z - 0.32), color=("b35a48", "9a4a3a")[k % 2]))
    m.export(OUT)


def build_herbalist():
    """약초원 (약초꾼): a little woven hut under a giant three-leaf clover; herb bundles hanging on a reed rail,
    three pebble-edged beds (green, lavender, golden) in a twig fence, acorn-cap pots and a stone mortar."""
    m = Model("herbalist", 203)
    cx, cy, R, H = -0.75, 0.2, 0.6, 0.85
    woven_round(m, cx, cy, R, H, cols=(WEAVE_GREEN, WEAVE_GREEN_DARK))
    stem(m, (cx, cy, H - 0.1), (cx, cy, H + 0.35), 0.06, LEAF_B, LEAF_VEIN, 1, 6)
    clover_roof(m, cx, cy, H + 0.2, 1.0)
    door_on_ring(m, cx, cy, R, -math.pi / 2, 0.36, 0.66, "leaf", LEAF_C)
    window_on_ring(m, cx, cy, R, -math.pi / 2 + 1.0, 0.45, 0.11)
    drying_rail(m, -1.7, -1.05, -0.75, 0.82,
                lambda x, z, k: hanging_bundle(m, x, -0.75, z, ("7fb565", LAVENDER, "c9b26a", "5f9a52")[k % 4], 1.1))
    for j, (y, col, fl) in enumerate(((-0.75, "7fb565", None), (-0.15, "7fb565", LAVENDER), (0.45, "8fae55", "f4c84c"))):
        x0 = 0.55
        m.box((1.2, 0.42, 0.06), pos=(x0, y, 0), color="FIELD_SOIL")
        for k in range(4):
            pebble(m, x0 - 0.45 + k * 0.3, y - 0.24, 0.03, 0.1, 0.06, 0.04, shade(PEBBLE, 0.9 + 0.05 * (k % 3)), k, k + j)
        for k in range(5):
            x = x0 - 0.45 + k * 0.23
            m.sphere(0.12, pos=(x, y, 0.13), scl=(1, 1, 0.8), color=shade(col, 0.95 + 0.06 * (k % 2)), seg=7, rings=4,
                     lumps=0.25, group="body_nl", seed=k + j * 5)
            if fl:
                for q in range(3):
                    m.sphere(0.035, pos=(x - 0.05 + q * 0.05, y + 0.03 * (q % 2), 0.25), color=fl, seg=5, rings=3,
                             group="body_nl")
    twig_fence(m, -0.15, -1.1, 1.3, -1.1, 0.36, 0.3, gap=(0.1, 0.3), seed=5)
    twig_fence(m, 1.3, -1.1, 1.3, 0.85, 0.36, 0.3, seed=6)
    for k, col in enumerate(("e0607a", LAVENDER)):
        flower_pot(m, -0.1 - 0.25 * k, -0.95 + 0.1 * k, 0, col, 0.9)
    pebble(m, -1.45, 0.75, 0.08, 0.17, 0.15, 0.1, PEBBLE_DARK, 0, 9)                 # mortar
    m.cyl(0.11, 0.11, 0.02, pos=(-1.45, 0.75, 0.17), color="7fb565", seg=8)
    twig(m, (-1.45, 0.75, 0.15), (-1.35, 0.7, 0.4), 0.025)
    m.export(OUT)


def build_mushroom_hut():
    """버섯 말림터 (버섯꾼): round clay hut under a giant spotted mushroom cap; reed drying rails strung with
    mushroom slices and whole mushrooms, woven drying trays on pebble legs, woven baskets."""
    m = Model("mushroom_hut", 204)
    R, H = 0.72, 1.2
    pebble_round(m, 0, 0, R + 0.06, 0.16, seed=3, knobs=5, courses=2)
    daub_round(m, 0, 0, R, H, col="MUSHROOM_STEM", dark=shade("MUSHROOM_STEM", 0.88), ribs=True)
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
            col = shade(cap_c, 0.9 + 0.18 * (c.z - zc) / hc)
        m._finish(bm, [f], col, True)
    m._finish(bm, [top], shade(cap_c, 1.08), True)
    for (a, h, r) in ((-1.6, 0.3, 0.13), (-0.85, 0.5, 0.11), (-2.35, 0.55, 0.1), (-1.2, 0.78, 0.09), (0.4, 0.45, 0.12),
                      (2.2, 0.4, 0.13), (-0.25, 0.22, 0.08), (-2.9, 0.25, 0.09), (1.3, 0.7, 0.1), (-1.95, 0.12, 0.07),
                      (-1.05, 0.12, 0.07), (2.8, 0.75, 0.09)):
        phi = h * math.pi / 2
        rr = Rc * math.cos(phi) * 0.99
        z = zc + 0.12 + hc * math.sin(phi) ** 0.85
        nrm = Vector((math.cos(a) * math.cos(phi), math.sin(a) * math.cos(phi), math.sin(phi)))
        m.sphere(r, pos=(math.cos(a) * rr, math.sin(a) * rr, z), scl=(1, 1, 0.3), rot=(0, math.acos(max(-1, min(1, nrm.z))), a),
                 color="MUSHROOM_DOT", seg=10, rings=4)
    door_on_ring(m, 0, 0, R, -math.pi / 2, 0.38, 0.72, "bark")
    window_on_ring(m, 0, 0, R, -math.pi / 2 + 0.8, 0.62, 0.12)
    window_on_ring(m, 0, 0, R, -math.pi / 2 - 0.9, 0.62, 0.12)
    clay_chimney(m, 0.5, 0.45, H + 0.4, H + 1.15, 0.07)
    # drying rails: slices low, whole mushrooms high
    def slice_(x, z, k):
        m.box((0.01, 0.01, 0.08), pos=(x, -0.95, z - 0.08), color=CORD, group="body_nh")
        m.cyl(0.06, 0.06, 0.025, pos=(x, -0.95 + 0.012, z - 0.16), rot=(math.pi / 2, 0, 0), color="8a5a36", seg=7,
              cap="d9b98a", bottom_cap="d9b98a")

    def whole(x, z, k):
        m.box((0.012, 0.012, 0.08), pos=(x, -0.95, z - 0.08), color=CORD, group="body_nh")
        m.sphere(0.07, pos=(x, -0.95, z - 0.14), scl=(1, 1, 0.55), color=(cap_c, "c98a5e", "MUSHROOM_DOT")[k % 3], seg=6, rings=3)
        m.cyl(0.02, 0.025, 0.08, pos=(x, -0.95, z - 0.24), color="MUSHROOM_STEM", seg=4)
    forked_post(m, -1.55, -0.95, 1.0)
    forked_post(m, -0.95, -0.95, 1.0)
    for z, fn in ((0.55, slice_), (1.0, whole)):
        stem(m, (-1.65, -0.95, z), (-0.85, -0.95, z), 0.025, REED, REED_NODE, 1, 5)
        for k in range(3):
            fn(-1.45 + k * 0.25, z, k)
    # woven drying trays on pebble legs, right
    for k in range(2):
        z = 0.22 + k * 0.32
        for dx in (-0.25, 0.25):
            for dy in (-0.18, 0.18):
                if k == 0:
                    stem(m, (1.2 + dx, 0.2 + dy, 0), (1.2 + dx, 0.2 + dy, 0.6), 0.025, REED, REED_NODE, 1, 4)
        m.box((0.62, 0.44, 0.04), pos=(1.2, 0.2, z), color=WEAVE,
              colfn=lambda f: WEAVE_DARK if f.normal.z < 0.5 else WEAVE)
        for j in range(4):
            m.cyl(0.05, 0.05, 0.02, pos=(1.0 + j * 0.13, 0.2, z + 0.04), color="8a5a36", seg=6, cap="d9b98a")
    woven_basket(m, 0.85, -0.85, 0, 0.16, 0.17, fill="MUSHROOM_DOT")
    woven_basket(m, 1.15, -1.05, 0, 0.13, 0.15, fill=cap_c)
    for (x, y, s) in ((-0.85, -0.55, 1.0), (-0.72, -0.7, 0.7), (0.75, 0.55, 0.8), (-0.5, 0.75, 0.9)):
        m.cyl(0.03 * s, 0.035 * s, 0.14 * s, pos=(x, y, 0), color="MUSHROOM_STEM", seg=5)
        m.sphere(0.09 * s, pos=(x, y, 0.14 * s), scl=(1, 1, 0.6), color=cap_c, seg=7, rings=4)
    m.export(OUT)


# ───────────────────────── medium ─────────────────────────
def build_healer():
    """치료소: a long white clay-daub house under white daisy petals; an open porch on the right under a leaf
    roof with two reed cots on dandelion-down mattresses; white cloths drying on a cord; a dandelion clock by the
    door; herb bundles at the eaves."""
    m = Model("healer", 211)
    W, D, H = 2.4, 1.4, 1.1
    def _house():
        daub_box(m, W, D, H, col=DAUB_WHITE, dark=DAUB_WHITE_SHADE, mid_posts=1)
        petal_gable(m, W, D, H, 0.95, "white", rows=3, alt="cream", ridge=LEAF_C)
        round_door(m, -0.4, -D / 2, 0.44, 0.84, "leaf", LEAF_C)
        for x in (-1.0, 0.4, 0.9):
            round_window(m, x, -D / 2, 0.58, 0.14)
        clay_chimney(m, -0.7, 0.3, H, H + 1.25)
        for k in range(3):
            hanging_bundle(m, 0.2 + k * 0.25, -D / 2 - 0.22, H - 0.05, ("7fb565", LAVENDER, "c9b26a")[k], 0.9)
    placed(m, _house, (-0.6, 0, 0))
    pebble_steps(m, -1.0, -D / 2 - 0.02, 2)
    # porch
    px0, px1 = 0.68, 2.35
    for x in (px0 + 0.05, px1):
        for y in (-0.6, 0.6):
            stem(m, (x, y, 0), (x, y, 0.95), 0.04, REED, REED_NODE, 2, 5)
    placed(m, lambda: leaf_gable(m, px1 - px0, 1.2, 0.95, 0.45, n=2, over=0.15, seed=3), ((px0 + px1) / 2 + 0.02, 0, 0))
    pebble_floor(m, (px0 + px1) / 2, 0, 0.8, 0.55, 9, seed=2)
    cot(m, 1.15, 0.0, 0.0, "9cc3d6")
    cot(m, 1.85, 0.0, 0.0, "efc9bd")
    # cloth line in front
    for x in (0.95, 2.2):
        stem(m, (x, -1.25, 0), (x, -1.25, 0.85), 0.025, REED_GREEN, REED_GREEN_NODE, 2, 5)
    cord(m, (0.95, -1.25, 0.82), (2.2, -1.25, 0.82), sag=0.05, r=0.01, n=4)
    for k in range(3):
        x = 1.15 + k * 0.4
        m.box((0.3, 0.02, 0.36), pos=(x, -1.25, 0.42), color=("ffffff", "f6f1e4", "eaf2f6")[k], group="body_nl")
    # dandelion clock by the door
    tube(m, [Vector((-1.9, -0.95, 0)), Vector((-1.88, -0.95, 0.6)), Vector((-1.84, -0.93, 1.05))], [0.03, 0.026, 0.022],
         seg=5, color=LEAF_B)
    m.sphere(0.24, pos=(-1.84, -0.93, 1.2), color=DOWN, seg=10, rings=6, lumps=0.12, group="body_nl")
    acorn_cup(m, 0.45, -1.0, 0, 0.15, fill=WATER)
    m.export(OUT)


def loom(m, x, y, rz=0.0, w=1.0, h=1.5):
    """Upright reed loom: two reed uprights, top and bottom reed beams, bright warp threads, a woven band of cloth
    growing at the bottom, a twig shuttle."""
    def _b():
        for sx in (-1, 1):
            stem(m, (sx * w / 2, 0, 0), (sx * w / 2, 0, h + 0.1), 0.045, REED, REED_NODE, 3, 6)
            twig(m, (sx * w / 2, 0.0, 0), (sx * w / 2, 0.35, 0), 0.03)
        for z in (0.28, h - 0.05):
            stem(m, (-w / 2 - 0.08, 0, z), (w / 2 + 0.08, 0, z), 0.035, REED, REED_NODE, 1, 5)
        n = 9
        for k in range(n):
            xx = -w / 2 + 0.08 + k * (w - 0.16) / (n - 1)
            m.box((0.018, 0.018, h - 0.4), pos=(xx, 0, 0.3), color=YARN[k % len(YARN)], group="body_nh")
        for r in range(4):
            m.box((w - 0.14, 0.03, 0.06), pos=(0, 0, 0.32 + r * 0.06), color=YARN[(r + 1) % len(YARN)])
        twig(m, (-0.15, -0.03, 0.62), (0.2, -0.03, 0.62), 0.02)
        m.sphere(0.04, pos=(0.02, -0.03, 0.62), scl=(1.6, 1, 1), color=YARN[2], seg=6, rings=3)
    placed(m, _b, (x, y, 0), rz)


def build_weaver():
    """베틀집 (방직소): a green woven-grass workshop under magenta petals; on the left a tall reed loom with bright
    warp threads under a big curled leaf; bolts of dyed petal-cloth drying on a cord; yarn in acorn cups, a wool pouch."""
    m = Model("weaver", 212)
    W, D, H = 1.9, 1.4, 1.15
    def _house():
        woven_box(m, W, D, H, cols=(WEAVE_GREEN, WEAVE_GREEN_DARK))
        petal_gable(m, W, D, H, 1.0, "magenta", rows=3, alt="pink")
        round_door(m, 0.35, -D / 2 - 0.02, 0.44, 0.84, "bark")
        round_window(m, -0.45, -D / 2 - 0.03, 0.6, 0.15)
        clay_chimney(m, 0.6, 0.3, H, H + 1.15)
    placed(m, _house, (0.6, 0.05, 0))
    pebble_steps(m, 0.95, -0.67, 2)
    # loom shelter
    for x in (-2.1, -0.65):
        for y in (-0.5, 0.55):
            stem(m, (x, y, 0), (x, y, 1.75), 0.04, REED, REED_NODE, 3, 5)
    curled_leaf_roof(m, 1.9, 1.5, 0.55, z0=1.7, col=LEAF_A, dark=LEAF_B, x0=-1.35, K=8, J=8)
    loom(m, -1.35, 0.15, 0.0, 1.0, 1.5)
    # dyed cloth on a cord in front
    for x in (-2.0, -0.6):
        stem(m, (x, -1.3, 0), (x, -1.3, 0.95), 0.025, REED_GREEN, REED_GREEN_NODE, 2, 5)
    cord(m, (-2.0, -1.3, 0.92), (-0.6, -1.3, 0.92), sag=0.05, r=0.01, n=4)
    for k in range(3):
        m.box((0.3, 0.02, 0.5), pos=(-1.75 + k * 0.45, -1.3, 0.38), color=("c8644e", "efc35a", "5f7c96")[k], group="body_nl")
    for k in range(3):
        acorn_cup(m, 1.6 + 0.0 * k, -0.95 + k * 0.28, 0, 0.12, fill=YARN[k])
    grass_pouch(m, 0.0, -1.1, 0, 0.9, top=WOOL)
    m.export(OUT)


def build_smithy():
    """대장간: a stacked-pebble workshop under overlapping slate pebbles; on the right an open forge under a slate
    lean-to — clay hearth with glowing coals and a tall clay hood, a flat dark anvil stone on a pebble stack,
    quench water in an acorn cup, a puffball bellows, tongs and hammers of twig and stone on a rail."""
    m = Model("smithy", 213)
    W, D, H = 1.5, 1.4, 1.15
    def _house():
        pebble_box(m, W, D, H, seed=7, courses=4)
        slate_gable(m, W, D, H, 0.85, rows=3, seed=2)
        round_door(m, -0.2, -D / 2 - 0.03, 0.44, 0.82, "bark")
        round_window(m, 0.4, -D / 2 - 0.03, 0.6, 0.14)
    placed(m, _house, (-0.35, 0.05, 0))
    # forge shed
    for x in (0.55, 2.2):
        for y in (-0.55, 0.65):
            forked_post(m, x, y, 1.05 if y < 0 else 1.3)
    placed(m, lambda: slate_gable(m, 1.85, 1.2, 1.0, 0.3, over=0.12, rows=2, seed=5, sides=(-1,), ridge=False), (1.38, 0.62, 0))
    hx, hy = 1.75, 0.3
    m.cyl(0.4, 0.42, 0.42, pos=(hx, hy, 0), color=CLAY, seg=10, cap="FLAME",
          colfn=lambda f: CLAY_DARK if f.calc_center_median().z < 0.15 else CLAY)
    for k in range(5):
        m.sphere(0.06, pos=(hx - 0.15 + k * 0.08, hy - 0.05 + 0.04 * (k % 2), 0.43), color=("FLAME", "FLAME2")[k % 2],
                 seg=5, rings=3, group="body_nl")
    m.cyl(0.3, 0.12, 0.5, pos=(hx, hy + 0.05, 0.85), color=CLAY, seg=10, smooth=True)
    clay_chimney(m, hx, hy + 0.05, 1.3, 2.2, 0.12)
    m.sphere(0.2, pos=(hx + 0.42, hy + 0.3, 0.32), scl=(1.1, 1, 0.8), color="c4a27a", seg=8, rings=5)   # puffball bellows
    twig(m, (hx + 0.42, hy + 0.1, 0.4), (hx + 0.42, hy - 0.2, 0.6), 0.025)
    for k in range(3):
        pebble(m, 1.0, -0.6, 0.08 + k * 0.12, 0.2 - 0.02 * k, 0.17, 0.08, shade(PEBBLE, 0.92 + 0.05 * k), k, k + 3)
    m.sphere(1.0, pos=(1.0, -0.6, 0.42), scl=(0.24, 0.14, 0.06), color=IRON, seg=8, rings=3)
    acorn_cup(m, 1.55, -0.95, 0, 0.17, fill=WATER)
    stem(m, (0.6, 0.66, 0.85), (2.15, 0.66, 0.85), 0.025, REED, REED_NODE, 2, 4)
    for k in range(4):
        x = 0.85 + k * 0.32
        twig(m, (x, 0.62, 0.85), (x + 0.03, 0.6, 0.45), 0.02)
        m.sphere(0.05, pos=(x + 0.03, 0.6, 0.43), scl=(1.4, 0.8, 0.8), color=(IRON, SLATE)[k % 2], seg=6, rings=3)
    m.export(OUT)


def build_graveyard():
    """묘지: a small plot in a fence of stuck twigs and grass cord with a gate gap, upright flat pebbles as
    headstones (some mossy) with petals before them, a flat-pebble bench, flowers."""
    m = Model("graveyard", 221)
    F, G = 1.25, 1.05
    twig_fence(m, -F, -G, F, -G, 0.4, 0.3, gap=(0.4, 0.6), seed=1)
    twig_fence(m, -F, G, F, G, 0.4, 0.3, seed=2)
    twig_fence(m, -F, -G, -F, G, 0.4, 0.3, seed=3)
    twig_fence(m, F, -G, F, G, 0.4, 0.3, seed=4)
    for k, (x, y) in enumerate(((-0.75, 0.55), (-0.15, 0.6), (0.5, 0.5), (-0.5, -0.1), (0.2, -0.05), (0.8, -0.15))):
        headstone(m, x, y, (k % 3 - 1) * 0.1, 0.9 + 0.1 * (k % 2), moss=k % 2 == 1, col=(PEBBLE, PEBBLE_WARM, "c2c6bc")[k % 3])
        petal_flower(m, x + 0.05, y - 0.25, 0.03, 0.04, ("ffffff", "f2a2b8", "f4c84c")[k % 3])
    pebble(m, -0.8, -0.72, 0.18, 0.3, 0.12, 0.04, PEBBLE_WARM, 0, 3)
    for sx in (-1, 1):
        pebble(m, -0.8 + sx * 0.2, -0.72, 0.08, 0.07, 0.07, 0.09, PEBBLE_DARK, 0, 4 + sx)
    mossy_tufts(m, ((0.95, 0.85, 1.0), (-1.0, 0.85, 0.8), (1.0, -0.8, 0.7)))
    m.sphere(0.2, pos=(0.95, -0.75, 0.1), scl=(1, 1, 0.8), color="BUSH", seg=7, rings=4, lumps=0.2, group="body_nl")
    petal_flower(m, 0.92, -0.8, 0.27, 0.05, "ffffff")
    m.export(OUT)


def build_ferry():
    """나루터: reed-pole piles (thick green stems with joints) along +X from the shore, a deck of slim reeds lashed
    across with flat pebbles laid on the landward half, a mooring reed with grass-cord coils at the end, a curled
    leaf boat with a petal sail moored to a lily pad, a glowing seed lantern on a reed pole."""
    m = Model("ferry", 231)
    L, Wd = 2.6, 0.9
    z = 0.25
    n = 8
    for k in range(n):
        y = -Wd / 2 + (k + 0.5) * Wd / n
        r = Wd / n / 2 * 1.02
        stem(m, (0.1 - 0.05 * (k % 3), y, z - r), (L + 0.1 + 0.05 * ((k + 1) % 3), y, z - r), r,
             (REED, "d8c896", "c4b47a")[k % 3], "8f7a48", 3, 5)
    for x in (0.3, 1.2, 2.0, L - 0.05):
        m.box((0.06, Wd + 0.06, 0.035), pos=(x, 0, z - 0.035), color="6f5430")
    for k in range(5):                          # flat pebbles on the landward half
        pebble(m, 0.3 + k * 0.22, (k % 2 - 0.5) * 0.3, z + 0.01, 0.13, 0.12, 0.035, shade(PEBBLE, 0.94 + 0.05 * (k % 3)), k, k)
    for x in (0.35, 1.4, L):
        for sy in (-1, 1):
            stem(m, (x, sy * (Wd / 2 + 0.05), -1.1), (x, sy * (Wd / 2 + 0.05), 0.42 if x < L else 0.75), 0.07,
                 REED_GREEN, REED_GREEN_NODE, 2, 6)
    for k in range(3):                          # cord coils on the mooring reed
        m.cyl(0.095, 0.095, 0.03, pos=(L, Wd / 2 + 0.05, 0.5 + k * 0.05), color=CORD, seg=8)
    # lantern pole at the shore end
    stem(m, (0.2, -Wd / 2 - 0.1, 0), (0.2, -Wd / 2 - 0.1, 1.25), 0.03, REED, REED_NODE, 3, 5)
    twig(m, (0.2, -Wd / 2 - 0.1, 1.22), (0.45, -Wd / 2 - 0.1, 1.3), 0.02)
    seed_lantern(m, 0.43, -Wd / 2 - 0.1, 1.29, 0.12)
    # leaf boat moored to a lily pad beside the pier
    leaf_boat(m, 1.55, 1.12, -0.12, 1.3, 0.48, 0.05, sail="f2a2b8")
    lily_pad(m, 2.45, 1.45, -0.04, 0.32, 0.6)
    cord(m, (2.15, 1.15, 0.18), (2.45, 1.45, 0.0), sag=0.05, r=0.01, n=2)
    cord(m, (0.95, 1.12, 0.18), (0.35, Wd / 2 + 0.05, 0.3), sag=0.08, r=0.01, n=3)
    acorn_cup(m, 0.75, -0.25, z, 0.12, fill=WATER)
    grass_pouch(m, 1.05, 0.25, z, 0.7)
    m.export(OUT)


def build_chapel():
    """예배당 (교회): a white clay-daub hall under cream-and-white petals with a rosette window in the gable; in
    front a tall tower of lashed reeds with a woven base and a petal spire, and from its top a curved green stalk
    arches out holding three white lily-of-the-valley bells — the chapel bells."""
    m = Model("chapel", 241)
    W, D, H, rise = 2.0, 3.0, 1.75, 1.35
    hy = 0.35
    m.box((W, D, H), pos=(0, hy, 0), color=DAUB_WHITE, colfn=lambda f: DAUB_WHITE_SHADE if f.calc_center_median().z < 0.1 else DAUB_WHITE)
    m.box((W + 0.04, D + 0.04, 0.14), pos=(0, hy, 0), color=DAUB_WHITE_SHADE)
    for x in (-W / 2, W / 2):
        for y in (hy - D / 2, hy, hy + D / 2):
            stem(m, (x, y, -0.02), (x, y, H + 0.05), 0.06, REED, REED_NODE, 2)
            lash(m, (x, y, H - 0.05), 0.07)
    for sx in (-1, 1):                          # tall round-topped side windows
        for y in (hy - 0.6, hy + 0.6):
            placed(m, lambda: round_window(m, 0, 0, 1.0, 0.16), (sx * (W / 2 + 0.01), y, 0), sx * math.pi / 2)
    placed(m, lambda: petal_gable(m, D, W, H, rise, "white", rows=4, alt="cream", ridge=LEAF_C), (0, hy, 0), math.pi / 2)
    for sy in (-1, 1):
        tri = [(-W / 2 + 0.05, H - 0.02), (W / 2 - 0.05, H - 0.02), (0.0, H + rise - 0.1)]
        y = hy + sy * (D / 2 - 0.02)
        pts = [Vector((x, y, z)) for x, z in tri]
        m.poly(pts if sy > 0 else list(reversed(pts)), color=DAUB_WHITE)
    # tower in front
    ty = hy - D / 2 - 0.42
    T = 0.42
    def _tower_base():
        woven_box(m, 0.84, 0.84, 1.55, cols=(WEAVE, WEAVE_DARK), post_r=0.07)
    placed(m, _tower_base, (0, ty, 0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            stem(m, (sx * T, ty + sy * T, 1.5), (sx * T * 0.8, ty + sy * T * 0.8, 3.8), 0.06, REED, REED_NODE, 3)
    for z in (2.3, 3.1):
        for (a, b) in (((-1, -1), (1, 1)), ((1, -1), (-1, 1))):
            k = 1 - 0.2 * (z - 1.5) / 2.3
            twig(m, (a[0] * T * k, ty - T * k, z - 0.35), (b[0] * T * k, ty - T * k, z + 0.35), 0.025) if a[1] < 0 else None
        for sy in (-1, 1):
            k = 1 - 0.2 * (z - 1.5) / 2.3
            stem(m, (-T * k - 0.05, ty + sy * T * k, z), (T * k + 0.05, ty + sy * T * k, z), 0.035, REED, REED_NODE, 1, 5)
            stem(m, (sy * T * k, ty - T * k - 0.05, z), (sy * T * k, ty + T * k + 0.05, z), 0.035, REED, REED_NODE, 1, 5)
    lathe(m, 0, ty, 3.75, [(0.48, 0), (0.48, 0.08)], seg=12, colfn=weave_fn(), top=WEAVE)
    petal_cone(m, 0, ty, 3.8, 0.4, 1.25, "white", courses=3, per=9, over=0.18, alt="cream")
    round_door(m, 0, ty - 0.42 - 0.03, 0.46, 0.92, "petal", "f6f1e4")
    pebble_steps(m, 0, ty - 0.47, 2)
    # bell stalk: from the spire base it arches out to the front-right, three white bells hang from it
    s0 = Vector((0.3, ty, 4.5))
    pts = [s0, s0 + Vector((0.25, -0.05, 0.45)), s0 + Vector((0.7, -0.3, 0.5)), s0 + Vector((1.0, -0.55, 0.2))]
    tube(m, pts, [0.05, 0.045, 0.035, 0.025], seg=5, color=LEAF_B, cap=LEAF_VEIN)
    for k, t in enumerate((0.45, 0.72, 0.98)):
        q = pts[1].lerp(pts[2], t) if t < 0.9 else pts[3]
        stalk_end = q - Vector((0, 0, 0.16))
        tube(m, [q, q + Vector((0.03, 0, -0.08)), stalk_end], 0.012, seg=3, color=LEAF_B, group="body_nh")
        bell_flower(m, stalk_end, 0.12 - 0.015 * k)
    leaf(m, [Vector((-0.2, ty + 0.3, 1.55)), Vector((-0.5, ty + 0.4, 2.3)), Vector((-0.55, ty + 0.45, 3.0)), Vector((-0.4, ty + 0.4, 3.4))],
         [0.05, 0.2, 0.18, 0.02], Vector((-1, 0, 0.2)).normalized(), thick=0.04, color=LEAF_A, color_under=LEAF_B)
    for x in (-0.85, 0.85):
        m.sphere(0.2, pos=(x, ty - 0.2, 0.1), scl=(1, 1, 0.8), color="BUSH", seg=7, rings=4, lumps=0.2, group="body_nl")
        petal_flower(m, x, ty - 0.25, 0.27, 0.05, "ffffff")
    m.export(OUT)


def build_plaza():
    """광장: a round plaza paved with flat pebbles, a fountain of stacked pebbles in a pebble basin with a water drop
    on top, petal bunting on four reed poles, reed-bundle benches on pebbles, acorn-cap flower tubs."""
    m = Model("plaza", 251)
    m.cyl(1.85, 1.85, 0.03, color="STONE_PATH", seg=24)
    for ring, (rr, n) in enumerate(((1.62, 18), (1.15, 13))):
        for k in range(n):
            a = k * math.tau / n + ring * 0.2
            pebble(m, math.cos(a) * rr, math.sin(a) * rr, 0.035, 0.2, 0.14, 0.03,
                   shade(PEBBLE_WARM if (k + ring) % 3 else PEBBLE, 0.95 + 0.05 * (k % 2)), a + math.pi / 2, k + ring * 20)
    pebble_round(m, 0, 0, 0.62, 0.3, seed=11, knobs=7, courses=2)
    m.cyl(0.56, 0.56, 0.02, pos=(0, 0, 0.26), color="WATER", seg=14)
    for k in range(3):
        pebble(m, 0.02 * (k % 2), 0, 0.3 + k * 0.17, 0.2 - 0.04 * k, 0.18 - 0.04 * k, 0.1, shade(PEBBLE, 0.92 + 0.05 * k), k, k + 30)
    m.sphere(0.13, pos=(0, 0, 0.88), scl=(1, 1, 1.15), color="DROP", seg=10, rings=6)
    m.cyl(0.0, 0.07, 0.16, pos=(0, 0, 0.98), color="DROP", seg=8)
    for k in range(4):                          # water streams spilling into the basin
        a = k * math.pi / 2 + 0.4
        m.box((0.04, 0.03, 0.3), pos=(math.cos(a) * 0.2, math.sin(a) * 0.2, 0.28), rot=(0, 0, a), color="DROP", group="body_nh")
    poles = [(-1.55, -1.0), (1.55, -1.0), (1.55, 1.0), (-1.55, 1.0)]
    for (x, y) in poles:
        stem(m, (x, y, 0), (x, y, 1.75), 0.04, REED, REED_NODE, 3, 5)
        m.sphere(0.06, pos=(x, y, 1.78), color="f4c84c", seg=6, rings=3)
    for i in range(4):
        bunting(m, poles[i], poles[(i + 1) % 4], 1.65, 0.22)
    for (x, y, rz) in ((0.0, 1.3, 0.0), (-1.25, 0.25, math.pi / 2)):
        def _bench():
            for sx in (-1, 1):
                pebble(m, sx * 0.3, 0, 0.08, 0.09, 0.09, 0.1, PEBBLE_DARK, 0, 5 + sx)
            reed_bundle(m, (-0.5, 0, 0.22), (0.5, 0, 0.22), 0.09, REED, REED_NODE, ties=2, n=5)
        placed(m, _bench, (x, y, 0), rz)
    for (x, y), col in zip(((1.15, -1.25), (-1.15, -1.25), (1.3, 0.6)), ("e0607a", "f4c84c", "9a7ad0")):
        flower_pot(m, x, y, 0, col, 1.4)
    m.export(OUT)


def build_pasture():
    """목장: a pasture in a fence of stuck twigs and grass cord (gate gap at the front), a small open shelter thatched
    with dry-grass bundles in the back corner, a seed-shell water trough, stooks of tied hay, grass tufts."""
    m = Model("pasture", 261)
    Fx, Fy = 1.95, 1.65
    twig_fence(m, -Fx, -Fy, Fx, -Fy, 0.5, 0.45, gap=(0.42, 0.58), seed=1)
    twig_fence(m, -Fx, Fy, Fx, Fy, 0.5, 0.45, seed=2)
    twig_fence(m, -Fx, -Fy, -Fx, Fy, 0.5, 0.45, seed=3)
    twig_fence(m, Fx, -Fy, Fx, Fy, 0.5, 0.45, seed=4)
    def _shed():
        for x in (-0.5, 0.5):
            for y in (-0.4, 0.4):
                forked_post(m, x, y, 0.8)
        bundle_gable(m, 1.0, 0.8, 0.78, 0.55, over=0.18, spacing=0.22)
        m.sphere(0.3, pos=(0, 0.1, 0.15), scl=(1.2, 0.8, 0.5), color="CROP_RIPE", seg=8, rings=4, lumps=0.2, group="body_nl")
    placed(m, _shed, (-1.2, 1.05, 0))
    seed_shell(m, 0.9, 0.95, 0, 1.0, 0.42, 0.22, rz=0.0, fill="WATER")
    for (x, y) in ((1.3, -0.9), (0.5, -1.2)):
        top = Vector((x, y, 0.55))
        for k in range(4):
            a = k * math.tau / 4 + 0.3
            foot = Vector((x + math.cos(a) * 0.2, y + math.sin(a) * 0.2, 0))
            reed_bundle(m, foot, foot.lerp(top, 0.95), 0.08, WEAVE, WEAVE_DARK, ties=1, n=5)
    for k in range(8):
        a = k * 2.3
        tuft(m, math.cos(a) * (0.4 + 0.15 * k), math.sin(a) * (0.3 + 0.12 * k), 0.28, 4, seed=k)
    m.export(OUT)


def build_watchtower():
    """망루: four tall reeds leaning in, lashed with twig cross-braces, a woven platform with a reed railing, a hat of
    tied dry grass on short reed posts, a reed ladder, a petal pennant on top."""
    m = Model("watchtower", 271)
    B, T, P = 0.6, 0.38, 3.15
    for sx in (-1, 1):
        for sy in (-1, 1):
            stem(m, (sx * B, sy * B, 0), (sx * T, sy * T, P + 0.85), 0.065, REED, REED_NODE, 4)
    for z in (0.9, 2.05):
        k = (z / (P + 0.85))
        r = B + (T - B) * k
        for sy in (-1, 1):
            twig(m, (-r, sy * r, z - 0.35), (r, sy * r, z + 0.35), 0.028)
            twig(m, (sy * r, -r, z + 0.35), (sy * r, r, z - 0.35), 0.028)
    lathe(m, 0, 0, P - 0.04, [(0.72, 0), (0.72, 0.08)], seg=14, colfn=weave_fn(), top=WEAVE)
    for k in range(12):
        a = k * math.tau / 12
        twig(m, (math.cos(a) * 0.68, math.sin(a) * 0.68, P), (math.cos(a) * 0.68, math.sin(a) * 0.68, P + 0.45), 0.02)
    m.cyl(0.69, 0.69, 0.04, pos=(0, 0, P + 0.42), color=REED, seg=14, smooth=True)
    m.cyl(0.69, 0.69, 0.03, pos=(0, 0, P + 0.22), color=CORD, seg=14, smooth=True)
    grass_cone(m, 0, 0, P + 0.82, 0.45, 0.8, over=0.25, ties=1, seg=14, knot=False)
    stem(m, (0, 0, P + 1.55), (0, 0, 4.75), 0.02, REED, REED_NODE, 1, 4)
    leaf(m, [Vector((0.02, 0, 4.7)), Vector((0.22, -0.03, 4.62)), Vector((0.42, -0.02, 4.58))], [0.08, 0.08, 0.01],
         Vector((0, -1, 0)), thick=0.02, color="e0607a", color_under="b84a62")
    reed_ladder(m, (0, -1.05, 0), (0, -0.62, P + 0.05), 0.3, 9)
    m.export(OUT)


if __name__ == "__main__":
    print("village buildings ->", OUT)
    only = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else []
    for name, fn in (("fisher", build_fisher), ("hunter", build_hunter), ("herbalist", build_herbalist),
                     ("mushroom_hut", build_mushroom_hut), ("healer", build_healer), ("weaver", build_weaver),
                     ("smithy", build_smithy), ("graveyard", build_graveyard), ("ferry", build_ferry),
                     ("chapel", build_chapel), ("plaza", build_plaza), ("pasture", build_pasture),
                     ("watchtower", build_watchtower)):
        if not only or name in only:
            fn()
