"""E3-14 kitchen without milk or eggs (docs/FOOD.md 5, sim/kitchen.gd) — view props -> models/props/kit_*.glb.
Scale: 1 unit = 1 cell = an adult resident (~5 cm real). Front = -Y (towards the camera). Origin = ground centre
unless noted.
  kit_aphid        pear-shaped green aphid, 0.16 long (real 2.5 mm, drawn at the critter scale: ladybug 0.44)  -> MultiMesh
  kit_ranch        aphid ranch: rose cane with thorns + leaves + bud, grass-stalk fence ring (r 1.05, gate at -Y),
                   trampled patch, bark pail of honeydew by the gate
  kit_dew          one honeydew drop (origin = centre)
  kit_quail_egg    whole quail egg, 0.72 long x 0.56 thick (real 3.5 x 2.7 cm — lying on its side it is waist high,
                   GAME_DESIGN 3.0 "소인에게 허리 높이"), cream with brown blotches; origin = centre, long axis = X
  kit_egg_half     cracked blunt half (cup, jagged rim, speckled outside, pale inside); origin = bottom of the cup
  kit_shell_basin  half shell set in the ground as a rain basin (water inside)
  kit_shell_boat   half shell boat with a twig mast and a leaf sail (origin = waterline)
  kit_egg_feast    yolk pool on spilled white + a flat stone griddle with fried pieces + leaf plates
  kit_press        seed press frame (stone slab, two twig posts, seed on a trough, oil cup); kit_press_lever = the beam
                   (origin = pivot, beam along +X, stone weight at the far end)
Run: blender -b --factory-startup --python build_kitchen.py -- [out_dir]   (or build_all.sh kitchen)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, out_dir_from_argv  # noqa: E402
from mathutils import Matrix, noise  # noqa: E402
import bmesh  # noqa: E402

OUT = os.path.join(out_dir_from_argv(), "props")

APHID = "a9d46c"
APHID_BELLY = "84b452"
APHID_DARK = "5f8a3d"
EYE = "1e1612"
STEM = "5f9a4e"
STEM_DARK = "4b7f40"
THORN = "b0604a"
ROSE_LEAF = "3f8f5a"
ROSE_LEAF_LIGHT = "5aa86a"
BUD = "d9707f"
STRAW = "c9b56a"
STRAW_DARK = "a8954f"
PATCH = mix("GRASS", "SOIL_GROUND", 0.45)
HONEY = "f0cf6a"
SHELL = "e8dcc0"
SHELL_IN = "f1ead8"
BLOTCH = "7a5440"
BLOTCH_DARK = "4a362a"
WHITE_EGG = "f2eedc"
YOLK = "f0a23a"
FRIED = "e8b860"
FRIED_EDGE = "c98a4a"
OIL = "e3b84a"
SEED = "4a3e36"
SEED_STRIPE = "d9cfb8"


def rod(m, a, b, r0, r1=None, color="WOOD", seg=5, group="body"):
    """Cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    h = d.length
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
    return m.cyl(r0, r0 if r1 is None else r1, h, pos=a, rot=(rot.x, rot.y, rot.z), color=color, seg=seg, group=group)


def egg_r(s, L, R):
    """Egg radius at distance s from the blunt end (blunt end a little fuller)."""
    u = max(-1.0, min(1.0, (s - L / 2) / (L / 2)))
    return R * math.sqrt(max(0.0, 1.0 - u * u)) * (1.0 - 0.1 * u)


def speckle(p, seed):
    """Quail-egg blotches: 0 = shell, 1 = brown, 2 = dark brown (by 3D noise at the face centre)."""
    n = noise.noise(Vector(p) * 9.0 + Vector((seed, seed * 0.7, seed * 1.3)))
    n2 = noise.noise(Vector(p) * 23.0 + Vector((seed * 2.1, 3.0, seed)))
    if n > 0.32 or n2 > 0.55:
        return 2 if (n > 0.45 or n2 > 0.66) else 1
    return 0


def speck_col(f, seed, base=SHELL):
    k = speckle(f.calc_center_median(), seed)
    return (base, BLOTCH, BLOTCH_DARK)[k]


def loft(bm, rings, close_start=None, close_end=None):
    """rings = [[Vector...]] equal length (closed loops); fan-close with a point at either end. Returns faces."""
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    faces = []
    for a, b in zip(vs[:-1], vs[1:]):
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
    if close_start is not None:
        c = bm.verts.new(close_start)
        for i in range(n):
            faces.append(bm.faces.new((vs[0][(i + 1) % n], vs[0][i], c)))
    if close_end is not None:
        c = bm.verts.new(close_end)
        for i in range(n):
            faces.append(bm.faces.new((vs[-1][i], vs[-1][(i + 1) % n], c)))
    loft.last = vs
    return faces


# ───────────────────────── aphid ─────────────────────────
def build_aphid():
    m = Model("kit_aphid", 1401)
    # pear body: fat at the back, head towards -Y
    m.sphere(0.062, pos=(0, 0.012, 0.058), scl=(0.82, 1.18, 0.78), color=APHID, seg=9, rings=5,
             colfn=lambda f: APHID_BELLY if f.normal.z < -0.3 else APHID)
    m.sphere(0.034, pos=(0, -0.06, 0.05), scl=(1.0, 0.95, 0.9), color=APHID, seg=7, rings=4)
    for x in (-0.022, 0.022):
        m.sphere(0.009, pos=(x, -0.085, 0.062), color=EYE, seg=5, rings=3, group="body_nl")
        # cornicles (the two little tail pipes)
        rod(m, (x * 0.9, 0.06, 0.075), (x * 1.6, 0.1, 0.105), 0.008, 0.006, color=APHID_DARK, seg=4, group="body_nl")
        # antennae swept back
        rod(m, (x * 0.8, -0.075, 0.075), (x * 3.0, -0.02, 0.13), 0.004, 0.003, color=APHID_DARK, seg=3, group="body_nl")
    for side in (-1, 1):
        for k, y in enumerate((-0.03, 0.0, 0.03)):
            rod(m, (side * 0.035, y, 0.04), (side * 0.07, y + (k - 1) * 0.015, 0.0), 0.005, 0.004, color=APHID_DARK,
                seg=3, group="body_nl")
    m.export(OUT)


# ───────────────────────── ranch ─────────────────────────
FENCE_R = 1.05
GATE_HALF = 0.42          # half-angle of the gate gap (radians), centred on -Y (front)
STEM_AT = (0.0, 0.18)


def stem_path(t):
    """Rose cane centreline: leans a little and bends back near the top (t 0..1)."""
    h = 2.4
    return Vector((STEM_AT[0] + 0.12 * math.sin(t * 2.2), STEM_AT[1] + 0.1 * t * t, t * h))


def build_ranch():
    m = Model("kit_ranch", 1402)
    rng = m.rng
    # trampled patch inside the fence (no outline — just a ground mark)
    m.cyl(FENCE_R + 0.06, FENCE_R + 0.02, 0.025, pos=(0, 0, -0.012), color=PATCH, seg=18, group="body_nh",
          cap=mix(PATCH, "GRASS", 0.2))
    # rose cane
    bm = m._bm("body")
    rings = []
    SEG, N = 7, 9
    for j in range(N + 1):
        t = j / N
        c = stem_path(t)
        r = 0.075 - 0.03 * t
        rings.append([c + Vector((math.cos(i * math.tau / SEG) * r, math.sin(i * math.tau / SEG) * r, 0))
                      for i in range(SEG)])
    rings[0] = [p - Vector((0, 0, 0.05)) for p in rings[0]]
    fs = loft(bm, rings, close_end=stem_path(1.0) + Vector((0, 0, 0.01)))
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    for f in fs:
        f.smooth = True
    m._finish(bm, fs, STEM, True, colfn=lambda f: STEM_DARK if f.normal.y > 0.4 else STEM)
    # thorns: little hooked cones pointing down-out
    for k in range(13):
        t = 0.08 + 0.8 * k / 12
        c = stem_path(t)
        a = k * 2.4 + 0.3
        r = 0.075 - 0.03 * t
        out = Vector((math.cos(a), math.sin(a), 0))
        base = c + out * (r * 0.8)
        tip = c + out * (r + 0.09) + Vector((0, 0, -0.045))
        rod(m, base, tip, 0.028, 0.002, color=THORN, seg=4, group="body_nl")
    # compound leaves: petiole + five leaflets
    for k, (t, a) in enumerate(((0.42, 0.6), (0.62, 2.9), (0.8, 4.6))):
        c = stem_path(t)
        out = Vector((math.cos(a), math.sin(a), 0.25)).normalized()
        end = c + out * 0.55
        rod(m, c, end, 0.018, 0.01, color=STEM, seg=4, group="body_nl")
        side = out.cross(Vector((0, 0, 1))).normalized()
        for q, (u, s) in enumerate(((0.45, 1), (0.45, -1), (0.75, 1), (0.75, -1), (1.0, 0))):
            p = c + out * (0.55 * u) + side * (0.13 * s) + Vector((0, 0, 0.02))
            yaw = math.atan2(out.y, out.x) + s * 0.5
            m.sphere(0.1, pos=p, scl=(1.25, 0.6, 0.18), rot=(0.25 * s, -0.25, yaw), seg=8, rings=4,
                     color=ROSE_LEAF_LIGHT if q % 2 else ROSE_LEAF, group="body_nl")
    # bud on top with sepals
    top = stem_path(1.0)
    m.sphere(0.1, pos=top + Vector((0, 0, 0.1)), scl=(1, 1, 1.35), color=BUD, seg=8, rings=5)
    for k in range(5):
        a = k * math.tau / 5
        m.blade(top + Vector((0, 0, 0.03)), top + Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, 0.2)), 0.06,
                color=STEM, group="body_nh")
    # grass-stalk fence ring with a gate at the front (-Y)
    posts = []
    NP = 22
    for k in range(NP):
        a = -math.pi / 2 + (k + 0.5) * math.tau / NP
        da = math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))
        if abs(da) < GATE_HALF:
            continue
        h = 0.34 + 0.05 * rng.random()
        p = Vector((math.cos(a) * FENCE_R, math.sin(a) * FENCE_R, 0))
        lean = Vector((rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), 0))
        rod(m, p - Vector((0, 0, 0.03)), p + lean + Vector((0, 0, h)), 0.026, 0.02,
            color=STRAW if k % 3 else STRAW_DARK, seg=5)
        # a seed-head tuft on every third post
        if k % 3 == 0:
            m.sphere(0.035, pos=p + lean + Vector((0, 0, h + 0.03)), scl=(1, 1, 1.6), color=STRAW_DARK, seg=5, rings=3,
                     group="body_nl")
        posts.append((a, p))
    for z in (0.13, 0.27):           # two rails, broken at the gate
        for (a0, p0), (a1, p1) in zip(posts[:-1], posts[1:]):
            if a1 - a0 > 2 * math.tau / NP:
                continue
            rod(m, p0 + Vector((0, 0, z)), p1 + Vector((0, 0, z + 0.01)), 0.014, color=STRAW, seg=4, group="body_nl")
    # gate posts a little taller
    for s in (-1, 1):
        a = -math.pi / 2 + s * GATE_HALF
        p = Vector((math.cos(a) * FENCE_R, math.sin(a) * FENCE_R, 0))
        rod(m, p - Vector((0, 0, 0.03)), p + Vector((0, 0, 0.46)), 0.032, 0.026, color=STRAW_DARK, seg=5)
    # bark pail of honeydew just inside the gate
    px, py = 0.42, -0.62
    m.cyl(0.085, 0.1, 0.14, pos=(px, py, 0), color="WOOD", seg=8, cap=HONEY,
          colfn=lambda f: "WOOD_DARK" if f.normal.x > 0.5 else "WOOD")
    m.cyl(0.104, 0.104, 0.02, pos=(px, py, 0.115), color="WOOD_DARK", seg=8, group="body_nl")
    for k in range(6):
        a = math.pi * k / 5
        b = math.pi * (k + 1) / 5
        rod(m, (px + math.cos(a) * 0.09, py, 0.14 + math.sin(a) * 0.09),
            (px + math.cos(b) * 0.09, py, 0.14 + math.sin(b) * 0.09), 0.008, color="WOOD_DARK", seg=3, group="body_nl")
    m.export(OUT)


def build_dew():
    m = Model("kit_dew", 1403)
    m.sphere(0.05, pos=(0, 0, 0), color=HONEY, seg=8, rings=5)
    m.cyl(0.03, 0.0, 0.05, pos=(0, 0, 0.03), color=HONEY, seg=6)
    m.sphere(0.012, pos=(-0.018, -0.03, 0.02), color="fff2c4", seg=4, rings=3, group="body_nh")
    m.export(OUT)


# ───────────────────────── quail egg ─────────────────────────
EGG_L = 0.72
EGG_R = 0.28


def build_quail_egg():
    m = Model("kit_quail_egg", 1404)
    bm = m._bm("body")
    SEG, N = 18, 12
    rings = []
    for j in range(1, N):
        s = EGG_L * (1 - math.cos(math.pi * j / N)) / 2       # denser near the ends
        r = egg_r(s, EGG_L, EGG_R)
        x = s - EGG_L / 2
        rings.append([Vector((x, math.cos(i * math.tau / SEG) * r, math.sin(i * math.tau / SEG) * r)) for i in range(SEG)])
    fs = loft(bm, rings, close_start=Vector((-EGG_L / 2, 0, 0)), close_end=Vector((EGG_L / 2, 0, 0)))
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    for f in fs:
        f.smooth = True
    m._finish(bm, fs, SHELL, True, colfn=lambda f: speck_col(f, 3.0))
    m.export(OUT)


def half_cup(m, depth=0.4, th=0.024, seed=5.0, origin_bottom=True, group="body"):
    """Blunt half of the egg as an open cup (axis Z, opening up, jagged rim). Returns the rim height."""
    bm = m._bm(group)
    SEG, N = 18, 7
    rim = []
    for i in range(SEG):
        zig = 0.04 if i % 2 else -0.025
        rim.append(zig + 0.015 * math.sin(i * 1.7 + seed))
    outer, inner = [], []
    for j in range(1, N + 1):
        s = depth * (1 - math.cos(math.pi / 2 * j / N))
        r = egg_r(s, EGG_L, EGG_R)
        ring = []
        for i in range(SEG):
            z = s + (rim[i] if j == N else 0.0)
            a = i * math.tau / SEG
            ring.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
        outer.append(ring)
        si = max(th, s)
        ri = max(0.01, egg_r(si, EGG_L, EGG_R) - th)
        ring = []
        for i in range(SEG):
            z = si + (rim[i] if j == N else 0.0)
            a = i * math.tau / SEG
            ring.append(Vector((math.cos(a) * ri, math.sin(a) * ri, z)))
        inner.append(ring)
    fo = loft(bm, outer, close_start=Vector((0, 0, 0)))
    ro = loft.last[-1]
    fi = loft(bm, inner, close_start=Vector((0, 0, th)))
    ri_ = loft.last[-1]
    # rim band joining the last outer and inner rings
    fr = []
    for i in range(SEG):
        j = (i + 1) % SEG
        fr.append(bm.faces.new((ro[i], ro[j], ri_[j], ri_[i])))
    allf = fo + fi + fr
    bmesh.ops.recalc_face_normals(bm, faces=allf)
    for f in fi:      # inner surface faces inward after the recalc (closed solid) — keep smooth
        f.smooth = True
    for f in fo:
        f.smooth = True
    m._finish(bm, fo, SHELL, True, colfn=lambda f: speck_col(f, seed))
    m._finish(bm, fi, SHELL_IN, True)
    m._finish(bm, fr, shade(SHELL_IN, 0.95), False)
    bm.normal_update()
    return depth


def build_egg_half():
    m = Model("kit_egg_half", 1405)
    half_cup(m, seed=5.0)
    m.export(OUT)


def build_shell_basin():
    m = Model("kit_shell_basin", 1406)
    half_cup(m, seed=8.0)
    m.cyl(0.255, 0.255, 0.01, pos=(0, 0, 0.3), color="PUDDLE", seg=16, group="body_nh")
    m.sphere(0.05, pos=(0.08, -0.05, 0.31), scl=(1.4, 0.8, 0.15), color="LILY", seg=6, rings=3, group="body_nl")
    # a few pebbles around the foot (it is set into the ground)
    for k in range(5):
        a = k * 1.3 + 0.4
        m.ico(0.05, pos=(math.cos(a) * 0.3, math.sin(a) * 0.3, 0.01), scl=(1.2, 1, 0.6), color="PEBBLE", group="body_nl")
    m.export(OUT)


def build_shell_boat():
    m = Model("kit_shell_boat", 1407)
    half_cup(m, seed=11.0)
    # mast + leaf sail
    rod(m, (0, 0.04, 0.03), (0.01, 0.06, 0.78), 0.016, 0.012, color="TRUNK", seg=5, group="body_nl")
    m.blade((0.02, 0.06, 0.32), (0.02, 0.06, 0.76), 0.32, color="LEAF_TOP", group="body_nh", bend=(0.12, -0.05, 0))
    m.export(OUT)


def build_egg_feast():
    m = Model("kit_egg_feast", 1408)
    rng = m.rng
    # spilled white: lumpy flat blob
    bm = m._bm("body_nl")
    SEG = 16
    ring = []
    for i in range(SEG):
        a = i * math.tau / SEG
        r = 0.55 + 0.12 * math.sin(a * 3 + 0.5) + 0.06 * math.sin(a * 5)
        ring.append(Vector((math.cos(a) * r, math.sin(a) * r * 0.85, 0.035)))
    low = [Vector((p.x * 1.04, p.y * 1.04, 0.0)) for p in ring]
    fs = loft(bm, [low, ring], close_start=Vector((0, 0, 0.0)), close_end=Vector((0, 0, 0.05)))
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    m._finish(bm, fs, WHITE_EGG, False)
    # yolk dome
    m.sphere(0.2, pos=(-0.05, 0.02, 0.04), scl=(1, 1, 0.55), color=YOLK, seg=12, rings=5)
    m.sphere(0.04, pos=(-0.11, -0.05, 0.13), scl=(1.3, 1, 0.4), color="f7c870", seg=6, rings=3, group="body_nh")
    # flat stone griddle with fried pieces
    gx, gy = 0.85, -0.25
    m.cyl(0.32, 0.3, 0.08, pos=(gx, gy, 0), color="STONE_DARK", seg=10, cap="STONE")
    for k in range(3):
        a = k * math.tau / 3 + 0.4
        p = (gx + math.cos(a) * 0.15, gy + math.sin(a) * 0.15, 0.08)
        m.sphere(0.09, pos=p, scl=(1.3, 1.0, 0.22), rot=(0, 0, a), color=FRIED, seg=8, rings=3,
                 colfn=lambda f: FRIED_EDGE if f.normal.z < 0.5 else FRIED)
    # three small embers under the griddle
    for k in range(3):
        a = k * 2.1
        m.ico(0.05, pos=(gx + math.cos(a) * 0.3, gy + math.sin(a) * 0.3, 0.0), color="FLAME", group="body_nl")
    # leaf plates with pieces
    for (x, y, a) in ((-0.75, -0.45, 0.4), (0.3, 0.62, 2.2), (-0.6, 0.55, 4.0)):
        m.sphere(0.17, pos=(x, y, 0.01), scl=(1.4, 0.75, 0.08), rot=(0, 0, a), color="LEAF_MID", seg=8, rings=3,
                 group="body_nl")
        m.sphere(0.07, pos=(x, y, 0.04), scl=(1.2, 1.0, 0.3), rot=(0, 0, a + 0.5), color=FRIED, seg=6, rings=3,
                 group="body_nl")
    m.export(OUT)


# ───────────────────────── seed press ─────────────────────────
PRESS_PIVOT = (-0.45, 0.0, 0.62)


def build_press():
    m = Model("kit_press", 1409)
    # stone slab base
    m.box((1.15, 0.6, 0.1), pos=(0, 0, 0), color="STONE", colfn=lambda f: shade("STONE", 1.08) if f.normal.z > 0.7 else "STONE_DARK")
    # trough + seed being pressed
    m.box((0.36, 0.3, 0.08), pos=(0.1, 0, 0.1), color="WOOD")
    m.sphere(0.13, pos=(0.1, 0, 0.24), scl=(1.4, 0.75, 0.55), rot=(0, 0, 0.3), color=SEED, seg=8, rings=4,
             colfn=lambda f: SEED_STRIPE if abs(f.calc_center_median().y) < 0.02 else SEED)
    # oil lip + cup
    m.box((0.2, 0.06, 0.04), pos=(0.36, 0, 0.13), color="WOOD_DARK", group="body_nl")
    m.cyl(0.08, 0.1, 0.12, pos=(0.5, 0.0, 0.1), color="9a7448", seg=8, cap=OIL)
    # two twig posts (pivot fork)
    for y in (-0.12, 0.12):
        rod(m, (PRESS_PIVOT[0], y, 0.08), (PRESS_PIVOT[0] + 0.02, y, PRESS_PIVOT[2] + 0.12), 0.04, 0.032, color="TRUNK", seg=6)
    rod(m, (PRESS_PIVOT[0], -0.15, PRESS_PIVOT[2]), (PRESS_PIVOT[0], 0.15, PRESS_PIVOT[2]), 0.02, color="TRUNK_DARK", seg=5,
        group="body_nl")
    # a little sack of seed husks
    m.sphere(0.13, pos=(-0.2, -0.16, 0.18), scl=(1, 0.9, 0.85), color="d9c49c", seg=7, rings=4)
    m.export(OUT)


def build_press_lever():
    m = Model("kit_press_lever", 1410)
    rod(m, (-0.06, 0, 0), (1.15, 0, 0.02), 0.04, 0.035, color="TRUNK", seg=6)
    # press block under the beam above the seed
    m.box((0.14, 0.18, 0.14), pos=(0.55, 0, -0.17), color="WOOD_DARK")
    # stone weight hanging by a cord at the end
    rod(m, (1.08, 0, 0.0), (1.08, 0, -0.22), 0.008, color=STRAW_DARK, seg=3, group="body_nl")
    m.ico(0.12, pos=(1.08, 0, -0.3), scl=(1.1, 1, 0.9), color="ROCK", subdiv=1, lumps=0.15, seed=4)
    m.export(OUT)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("kitchen ->", OUT)
    build_aphid()
    build_ranch()
    build_dew()
    build_quail_egg()
    build_egg_half()
    build_shell_basin()
    build_shell_boat()
    build_egg_feast()
    build_press()
    build_press_lever()
