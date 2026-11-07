"""Far LOD for buildings (design/gdd/buildings.md main decision 1, art bible 8.3 / 8.7): every building model gets one
extra node "body__far" built from a handful of plain shapes - wall body + roof in its roof colour + the one or two
things that make the silhouette (chimney, tower, sails, tripod). <= 600 tris (landmarks <= 800). No crease lines and no
hull outline on it (godot/art/art.gd model_far), shown by godot/view/village_view.gd below ppu 24 (hysteresis 22/26).

Usage: build scripts call add_far(m) right before m.export(OUT); models without a recipe are left alone.
Coordinates as lowpoly.py / tiny_kit.py: Blender Z-up, 1 unit = 1 cell, FRONT = -Y. Recipes mirror the near model's
main dimensions (see the build_* function of the same name).
"""
import math

from mathutils import Vector

from tiny_kit import (PETALS, WEAVE, WEAVE_DARK, WEAVE_GREEN, REED, REED_GREEN, TWIG, DAUB, DAUB_OCHRE, DAUB_ROSE,
                      DAUB_WHITE, CLAY, CLAY_DARK, PEBBLE, PEBBLE_WARM, SLATE, BARK, LEAF_A, LEAF_B, LEAF_C, LEAF_DRY,
                      LILY_PAD, DOOR_DARK)

FAR = "body__far"
BUDGET = 600
BUDGET_LANDMARK = 800
LANDMARKS = {"chapel", "plaza", "watchtower", "windmill"}


# ───────────── shapes (all in group FAR) ─────────────
def fcyl(m, x, y, z, r, h, col, seg=8, r_top=None, cap=None, rz=0.0):
    m.cyl(r, r if r_top is None else r_top, h, pos=(x, y, z), rot=(0, 0, rz), color=col, seg=seg, group=FAR, cap=cap)


def fcone(m, x, y, z, r, h, col, seg=8):
    m.cyl(r, 0.0, h, pos=(x, y, z), color=col, seg=seg, group=FAR)


def fdome(m, x, y, z, rx, ry, h, col, seg=8, rings=4):
    """Upper half-ish of a squashed sphere sitting on z (the hidden lower half stays - cheaper than cutting)."""
    m.sphere(1.0, pos=(x, y, z), scl=(rx, ry, h), color=col, seg=seg, rings=rings, smooth=False, group=FAR)


def fbox(m, x, y, z, w, d, h, col, rz=0.0, rot=None):
    m.box((w, d, h), pos=(x, y, z), rot=rot if rot is not None else (0, 0, rz), color=col, group=FAR)


def fgable(m, x, y, z, w, d, rise, col, rz=0.0, over=0.15):
    """Gable roof: ridge along X (length w + eaves), slopes across Y (depth d + eaves), base at z."""
    o = over
    prof = [(-d / 2 - o, -0.06), (d / 2 + o, -0.06), (0.0, rise)]
    m.prism(prof, w + 2 * o, pos=(x, y, z), rot=(0, 0, rz), color=col, group=FAR)


def fpost(m, a, b, r, col, seg=4):
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
    m.cyl(r, r, d.length, pos=a, rot=tuple(rot), color=col, seg=seg, group=FAR)


def fblob(m, x, y, z, r, col, scl=(1, 1, 0.8)):
    m.sphere(r, pos=(x, y, z), scl=scl, color=col, seg=6, rings=3, smooth=False, group=FAR)


def fdoor(m, x, y, w=0.42, h=0.78, rz=0.0):
    fbox(m, x, y - 0.03, 0.0, w, 0.06, h, DOOR_DARK, rz)


def P(name):
    return PETALS[name][0]


# ───────────── recipes (one per model name) ─────────────
def _cottage_a(m):
    fcyl(m, 0, 0, 0, 0.8, 1.0, WEAVE, seg=10)
    fcone(m, 0, 0, 0.95, 1.02, 1.35, P("pink"), seg=10)
    fdoor(m, 0, -0.8)


def _cottage_b(m):
    fbox(m, 0, 0, 0, 1.9, 1.15, 0.95, DAUB_ROSE)
    fdome(m, 0.05, 0, 0.77, 1.38, 1.0, 1.12, LEAF_A, seg=10, rings=6)
    fcyl(m, -0.55, 0.38, 0.95, 0.11, 1.3, CLAY, seg=6)
    fdoor(m, 0.3, -0.575)


def _cottage_c(m):
    fcyl(m, 0, 0, 0, 0.92, 0.3, PEBBLE, seg=10)
    fcyl(m, 0, 0, 0.3, 0.84, 0.7, DAUB_OCHRE, seg=10)
    fcone(m, 0, 0, 0.98, 1.1, 1.35, WEAVE, seg=10)
    fdoor(m, 0, -0.86)


def _cottage_d(m):
    fcyl(m, 0, 0, 0, 0.82, 0.88, PEBBLE, seg=10)
    fdome(m, 0, 0, 0.84, 1.05, 1.05, 1.0, P("blue"), seg=10, rings=6)
    fdoor(m, 0.2, -0.82)


def _timber(wall, roof_col, door_x, chim_x):
    def r(m):
        W, D, H = 2.4, 1.5, 1.95
        fbox(m, 0, 0, 0, W, D, 1.0, wall)
        fbox(m, 0, 0, 1.0, W, D, H - 1.0, WEAVE)
        fgable(m, 0, 0, H, W, D, 1.1, roof_col, over=0.22)
        fcyl(m, chim_x, 0.25, H, 0.12, 1.25, CLAY, seg=6)
        fdoor(m, door_x, -D / 2, 0.44, 0.84)
    return r


def _stone(roof_col, chim_x):
    def r(m):
        W, D, H = 2.4, 1.55, 1.75
        fbox(m, 0, 0, 0, W, D, H, PEBBLE)
        fgable(m, 0, 0, H, D, W, 1.3, roof_col, rz=math.pi / 2, over=0.2)
        fcyl(m, chim_x, 0.35, H + 0.45, 0.17, 1.0, PEBBLE_WARM, seg=6)
        fdoor(m, 0, -D / 2, 0.48, 0.92)
    return r


def _storehouse(m):
    for (cx, cy, R, H, lid, legs) in ((-0.42, 0.12, 0.82, 1.45, 0.85, 0.3), (0.9, 0.3, 0.52, 1.0, 0.6, 0.22)):
        fcyl(m, cx, cy, 0, R * 0.6, legs, PEBBLE, seg=6)
        fcyl(m, cx, cy, legs, R, H, WEAVE, seg=10, r_top=R * 0.75)
        fcone(m, cx, cy, legs + H - 0.04, R * 0.72 + 0.18, lid, WEAVE_DARK, seg=10)
    fbox(m, 1.0, -0.65, 0, 0.9, 0.45, 0.3, WEAVE_DARK)


def _well(m):
    fcyl(m, 0, 0, 0, 0.48, 0.46, PEBBLE, seg=8, cap="WATER")
    top = (0, 0, 1.45)
    for k in range(3):
        a = k * math.tau / 3 - math.pi / 2 + 0.6
        fpost(m, (math.cos(a) * 0.62, math.sin(a) * 0.5, 0), top, 0.05, REED)
    fcone(m, 0, 0, 1.45, 0.26, 0.35, WEAVE, seg=6)


def _hut(m):
    for x in (-0.45 - 0.55, -0.45 + 0.55):
        for y in (0.5 - 0.4, 0.5 + 0.4):
            fpost(m, (x, y, 0), (x, y, 0.8), 0.05, TWIG)
    fdome(m, -0.45, 0.5, 0.73, 0.92, 0.8, 0.45, LEAF_DRY)
    fbox(m, -0.45, 0.55, 0, 0.95, 0.5, 0.3, TWIG)
    fbox(m, 0.9, 0.58, 0.0, 0.42, 1.6, 0.85, TWIG)
    fcone(m, -1.0, -0.45, 0, 0.38, 1.05, TWIG, seg=6)
    fbox(m, 0.15, -0.55, 0, 0.95, 0.36, 0.28, TWIG, rz=0.12)


def _forester(m):
    fdome(m, -1.45, 0.2, 0.66, 0.6, 0.6, 0.55, LEAF_C)
    fbox(m, -1.1, 0.2, 0, 0.06, 1.0, 0.8, WEAVE, )
    for j, y in enumerate((-0.6, 0.0, 0.55)):
        fbox(m, 0.4, y, 0, 2.0, 0.42, 0.06, "FIELD_SOIL")
        fbox(m, 0.4, y, 0.06, 1.85, 0.3, 0.18 + 0.15 * j, LEAF_C)
    for k in range(3):
        x = -0.3 + k * 0.7
        fpost(m, (x, 0.55, 0.05), (x, 0.55, 1.0), 0.03, LEAF_B)
        fblob(m, x, 0.55, 1.08 + 0.1 * (k % 2), 0.22, ("LEAF_YOUNG", "LEAF_TOP")[k % 2])


def _quarry(m):
    for i, (x, y, s) in enumerate(((-1.05, 0.6, 0.62), (-0.35, 0.75, 0.75), (0.45, 0.65, 0.55), (1.1, 0.7, 0.5))):
        fblob(m, x, y, s * 0.55, s, ("ROCK", "MOSS")[i % 2], scl=(1.15, 0.85, 0.95))
    top = (0.95, -0.2, 1.65)
    for k in range(3):
        a = k * math.tau / 3 + 0.4
        fpost(m, (0.95 + math.cos(a) * 0.55, -0.2 + math.sin(a) * 0.45, 0), top, 0.05, REED)
    fblob(m, 0.95, -0.2, 0.62, 0.22, PEBBLE)
    for (x, y) in ((-0.75, -0.4), (-0.25, -0.6), (0.2, -0.3)):
        fcyl(m, x, y, 0, 0.2, 0.25, PEBBLE, seg=6)


def _sawmill(m):
    for x in (-0.95, 0.95):
        for y in (-0.55, 0.55):
            fpost(m, (x, y, 0), (x, y, 1.1), 0.05, REED)
    fdome(m, 0.1, 0, 0.98, 1.38, 0.97, 0.55, LEAF_A)
    fbox(m, 0, -0.05, 0.38, 1.9, 0.25, 0.25, REED_GREEN)
    fbox(m, -1.35, -0.95, 0, 1.0, 0.55, 0.16, REED, rz=0.15)
    fbox(m, 1.35, -0.25, 0, 0.6, 1.35, 0.24, TWIG, rz=-0.25)


def _windmill(m):
    fcyl(m, 0, 0, 0, 0.88, 0.22, PEBBLE, seg=10)
    fcyl(m, 0, 0, 0.2, 0.8, 2.12, WEAVE, seg=10, r_top=0.56)
    fcone(m, 0, 0, 2.28, 0.82, 0.85, P("gold"), seg=10)
    hub = (0, -0.82, 1.95)
    for k in range(4):
        a = k * math.pi / 2 + 0.35
        fbox(m, hub[0], hub[1], hub[2], 0.42, 0.04, 1.45, "f6f1e4", rot=(0, a, 0))
    fdoor(m, 0, -0.8, 0.38, 0.62)


def _bakery(m):
    fbox(m, -0.45, 0, 0, 1.9, 1.3, 1.15, DAUB)
    fgable(m, -0.45, 0, 1.15, 1.9, 1.3, 1.0, WEAVE, over=0.22)
    fcyl(m, -0.95, 0.3, 1.15, 0.12, 1.3, CLAY, seg=6)
    fcyl(m, 1.2, 0.2, 0, 0.67, 0.25, "STONE", seg=8)
    fdome(m, 1.2, 0.2, 0.24, 0.62, 0.62, 0.6, CLAY)
    fbox(m, 1.2, -0.42, 0.3, 0.4, 0.12, 0.3, DOOR_DARK)
    fbox(m, 0.38, -1.0, 0.95, 0.85, 0.95, 0.06, LEAF_A)
    fdoor(m, -0.6, -0.65, 0.44, 0.84)


def _saltpan(m):
    for i in range(2):
        for j in range(2):
            x, y = -0.55 + i * 1.1, -0.5 + j * 1.05
            fcyl(m, x, y, 0, 0.5, 0.12, CLAY, seg=8, cap="SALT" if (i + j) % 2 else "WATER")
    for (x, y, s) in ((1.25, -0.8, 1.0), (1.45, -0.45, 0.7), (-1.25, 0.95, 0.8)):
        fcone(m, x, y, 0, 0.32 * s, 0.38 * s, "SALT", seg=6)
    fbox(m, -0.6, 1.3, 0.72, 1.1, 0.5, 0.05, LEAF_C)


def _quern_house(m):
    W, D, H = 1.25, 1.0, 1.1
    fbox(m, 0, 0, 0, W + 0.3, D + 0.3, 0.04, "PATH")
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            fpost(m, (x, y, 0), (x, y, H), 0.055, REED)
    fbox(m, 0, D / 2 - 0.02, 0.04, W, 0.05, 0.55, WEAVE)
    fgable(m, 0, 0, H - 0.02, W, D, 0.45, LEAF_A, over=0.24)
    fcyl(m, 0.0, 0.05, 0, 0.3, 0.46, "a9b0ac", seg=8)
    fblob(m, -0.4, 0.0, 0.2, 0.2, "f3e8cf")


def _oven(m):
    fcyl(m, 0, 0.05, 0, 0.62, 0.32, "STONE", seg=8)
    fdome(m, 0, 0.09, 0.35, 0.48, 0.5, 0.46, CLAY)
    fbox(m, 0, -0.42, 0.42, 0.36, 0.1, 0.3, DOOR_DARK)
    fcyl(m, 0.12, 0.33, 0.62, 0.09, 0.38, CLAY_DARK, seg=6)
    fbox(m, -0.72, 0.05, 0.0, 0.26, 0.6, 0.24, TWIG)


def _fisher(m):
    cx, cy, R, Hs = -0.75, 0.15, 0.62, 0.5
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        x, y = cx + math.cos(a) * R * 0.75, cy + math.sin(a) * R * 0.75
        fpost(m, (x, y, 0), (x, y, Hs), 0.05, REED_GREEN)
    fcyl(m, cx, cy, Hs - 0.05, R + 0.2, 0.06, WEAVE, seg=8)
    fcyl(m, cx, cy, Hs, R, 0.8, WEAVE_GREEN, seg=8)
    fdome(m, cx, cy, Hs + 0.82, 1.0, 1.0, 0.3, LILY_PAD, seg=10)
    for tip in ((2.0, -0.9, 1.25), (1.95, -0.25, 1.05)):
        fpost(m, (0.95, -0.55, 0), tip, 0.03, REED_GREEN)
    fbox(m, -1.3, -0.85, 0.0, 0.9, 0.08, 0.75, TWIG)
    fcyl(m, 1.35, 0.45, 0, 0.42, 0.03, LILY_PAD, seg=8)


def _hunter(m):
    fcone(m, -0.35, 0.1, 0, 0.88, 2.4, BARK, seg=8)
    fpost(m, (0.75, -0.55, 0), (0.78, -0.55, 1.55), 0.03, TWIG)
    fbox(m, 0.95, -0.57, 0.6, 0.18, 0.04, 0.95, "f6f1e4", rot=(0, -0.25, 0))
    fcyl(m, 1.3, 0.25, 0.0, 0.38, 0.05, "c9a27a", seg=8)
    fbox(m, -0.45, 0.65, 0, 2.2, 0.08, 0.7, TWIG)


def _herbalist(m):
    cx, cy, R, H = -0.75, 0.2, 0.6, 0.85
    fcyl(m, cx, cy, 0, R, H, WEAVE_GREEN, seg=8)
    for k in range(3):
        a = k * math.tau / 3 + math.pi / 2
        fdome(m, cx + math.cos(a) * 0.48, cy + math.sin(a) * 0.48, H + 0.2, 0.55, 0.55, 0.16, "7cc173")
    fdoor(m, cx, cy - R, 0.36, 0.66)
    fbox(m, -1.22, -0.75, 0.0, 1.0, 0.08, 0.82, TWIG)
    for (y, col) in ((-0.75, "7fb565"), (-0.15, "b49ce0"), (0.45, "f4c84c")):
        fbox(m, 1.05, y, 0, 1.1, 0.48, 0.16, col)


def _mushroom_hut(m):
    fcyl(m, 0, 0, 0, 0.72, 1.2, "MUSHROOM_STEM", seg=10)
    fdome(m, 0, 0, 1.12, 1.04, 1.04, 0.92, "MUSHROOM_CAP", seg=10, rings=6)
    fdoor(m, 0, -0.72)
    fbox(m, 1.3, -0.2, 0, 0.08, 1.4, 0.8, TWIG)


def _healer(m):
    fbox(m, -0.6, 0, 0, 2.4, 1.4, 1.1, DAUB_WHITE)
    fgable(m, -0.6, 0, 1.1, 2.4, 1.4, 0.95, P("white"), over=0.2)
    fcyl(m, -1.3, 0.3, 1.1, 0.12, 1.25, CLAY, seg=6)
    fgable(m, 1.53, 0, 0.95, 1.67, 1.2, 0.45, LEAF_A, over=0.15)
    for x in (0.73, 2.35):
        for y in (-0.6, 0.6):
            fpost(m, (x, y, 0), (x, y, 0.95), 0.04, REED)
    fbox(m, 1.55, -1.25, 0.25, 1.25, 0.04, 0.55, "f6f1e4")
    fdoor(m, -1.0, -0.7, 0.44, 0.84)


def _weaver(m):
    fbox(m, 0.6, 0.05, 0, 1.9, 1.4, 1.15, WEAVE_GREEN)
    fgable(m, 0.6, 0.05, 1.15, 1.9, 1.4, 1.0, P("magenta"), over=0.2)
    fdome(m, -1.3, 0.0, 1.7, 0.95, 0.75, 0.42, LEAF_A)
    fbox(m, -1.35, 0, 0, 1.0, 0.12, 1.6, REED)
    fbox(m, -1.35, -0.05, 0.4, 0.8, 0.13, 0.7, P("magenta"))


def _smithy(m):
    fbox(m, -0.35, 0.05, 0, 1.5, 1.4, 1.15, PEBBLE)
    fgable(m, -0.35, 0.05, 1.15, 1.5, 1.4, 0.85, SLATE, over=0.2)
    fbox(m, 1.2, 0.05, 0.92, 1.0, 1.3, 0.1, SLATE)
    for y in (-0.55, 0.65):
        fpost(m, (1.65, y, 0), (1.65, y, 0.95), 0.05, REED)
    fcyl(m, 1.1, -0.05, 0, 0.36, 0.6, "STONE", seg=6, cap="FLAME")


def _graveyard(m):
    F, G = 1.25, 1.05
    for (x, y, w, d) in ((0, -G, 2 * F, 0.06), (0, G, 2 * F, 0.06), (-F, 0, 0.06, 2 * G), (F, 0, 0.06, 2 * G)):
        fbox(m, x, y, 0, w, d, 0.4, TWIG)
    for k, (x, y) in enumerate(((-0.75, 0.55), (-0.15, 0.6), (0.5, 0.5), (-0.5, -0.1), (0.2, -0.05), (0.8, -0.15))):
        fbox(m, x, y, 0, 0.28, 0.09, 0.42, (PEBBLE, PEBBLE_WARM, "c2c6bc")[k % 3])


def _ferry(raft):
    def r(m):
        L, Wd, z = 2.6, 0.9, 0.25
        fbox(m, L / 2 + 0.1, 0, z - 0.14, L, Wd, 0.14, REED)
        for x in (0.3, 1.2, 2.0, L - 0.05):
            for y in (-Wd / 2 - 0.05, Wd / 2 + 0.05):
                fpost(m, (x, y, -0.4), (x, y, z + 0.15), 0.06, REED_GREEN)
        fpost(m, (L, 0.3, -0.3), (L, 0.3, 1.1), 0.04, REED)
        if not raft:
            fdome(m, L - 0.2, -1.0, 0.0, 0.6, 0.25, 0.2, LEAF_A)
    return r


def _chapel(m):
    W, D, H, rise, hy = 2.0, 3.0, 1.75, 1.35, 0.35
    fbox(m, 0, hy, 0, W, D, H, DAUB_WHITE)
    fgable(m, 0, hy, H, D, W, rise, P("white"), rz=math.pi / 2, over=0.2)
    ty = hy - D / 2 - 0.42
    fbox(m, 0, ty, 0, 0.84, 0.84, 1.55, WEAVE)
    fcyl(m, 0, ty, 1.5, 0.59, 2.3, REED, seg=4, r_top=0.48, rz=math.pi / 4)
    fcyl(m, 0, ty, 3.75, 0.48, 0.08, WEAVE, seg=8)
    fcone(m, 0, ty, 3.8, 0.45, 1.3, P("white"), seg=8)
    s0 = Vector((0.3, ty, 4.5))
    pts = [s0, s0 + Vector((0.25, -0.05, 0.45)), s0 + Vector((0.7, -0.3, 0.5)), s0 + Vector((1.0, -0.55, 0.2))]
    for a, b in zip(pts[:-1], pts[1:]):
        fpost(m, a, b, 0.045, LEAF_B)
    for k, q in enumerate((pts[1].lerp(pts[2], 0.45), pts[1].lerp(pts[2], 0.72), pts[3])):
        fblob(m, q.x, q.y, q.z - 0.22, 0.12, "f6f1e4", scl=(1, 1, 1.1))
    fdoor(m, 0, ty - 0.42, 0.46, 0.92)


def _plaza(m):
    fcyl(m, 0, 0, 0, 1.85, 0.03, "STONE_PATH", seg=16)
    fcyl(m, 0, 0, 0, 0.62, 0.3, PEBBLE, seg=10, cap="WATER")
    fcyl(m, 0, 0, 0.3, 0.2, 0.5, PEBBLE, seg=6, r_top=0.12)
    fblob(m, 0, 0, 0.88, 0.14, "DROP", scl=(1, 1, 1.2))
    poles = [(-1.55, -1.0), (1.55, -1.0), (1.55, 1.0), (-1.55, 1.0)]
    for (x, y) in poles:
        fpost(m, (x, y, 0), (x, y, 1.75), 0.045, REED)
    cols = ("f2a2b8", "f4c84c", "8fb8ea", "a9c070")
    for i in range(4):
        a, b = Vector(poles[i] + (1.55,)), Vector(poles[(i + 1) % 4] + (1.55,))
        mid = (a + b) / 2
        d = b - a
        fbox(m, mid.x, mid.y, mid.z, d.length, 0.03, 0.14, cols[i], rz=math.atan2(d.y, d.x))
    fbox(m, 0, 1.3, 0, 1.0, 0.2, 0.3, REED)
    fbox(m, -1.25, 0.25, 0, 0.2, 1.0, 0.3, REED)


def _pasture(m):
    Fx, Fy = 1.95, 1.65
    for (x, y, w, d) in ((0, -Fy, 2 * Fx, 0.06), (0, Fy, 2 * Fx, 0.06), (-Fx, 0, 0.06, 2 * Fy), (Fx, 0, 0.06, 2 * Fy)):
        fbox(m, x, y, 0, w, d, 0.48, TWIG)
    for x in (-1.7, -0.7):
        for y in (0.65, 1.45):
            fpost(m, (x, y, 0), (x, y, 0.8), 0.04, TWIG)
    fgable(m, -1.2, 1.05, 0.78, 1.0, 0.8, 0.55, WEAVE, over=0.18)
    fbox(m, 0.9, 0.95, 0, 1.0, 0.42, 0.2, "b58650")
    for (x, y) in ((1.3, -0.9), (0.5, -1.2)):
        fcone(m, x, y, 0, 0.26, 0.6, WEAVE, seg=6)


def _watchtower(m):
    B, T, P_ = 0.6, 0.38, 3.15
    for sx in (-1, 1):
        for sy in (-1, 1):
            fpost(m, (sx * B, sy * B, 0), (sx * T, sy * T, P_ + 0.85), 0.065, REED)
    fbox(m, 0, 0, 0.9, 1.15, 0.05, 0.06, TWIG)
    fcyl(m, 0, 0, P_ - 0.04, 0.72, 0.1, WEAVE, seg=8)
    fcyl(m, 0, 0, P_ + 0.06, 0.66, 0.35, REED, seg=8)
    fcone(m, 0, 0, P_ + 0.82, 0.72, 0.85, WEAVE, seg=8)
    fpost(m, (-0.15, -1.05, 0), (-0.15, -0.62, P_), 0.03, REED)
    fpost(m, (0.15, -1.05, 0), (0.15, -0.62, P_), 0.03, REED)


RECIPES = {
    "cottage_a": _cottage_a, "cottage_b": _cottage_b, "cottage_c": _cottage_c, "cottage_d": _cottage_d,
    "house_timber": _timber(DAUB_OCHRE, LEAF_A, -0.35, 0.85), "house_timber_b": _timber(DAUB_ROSE, P("violet"), 0.35, -0.85),
    "house_stone": _stone(P("sky"), -0.7), "house_stone_b": _stone(P("orange"), 0.7),
    "storehouse": _storehouse, "well": _well, "hut": _hut, "forester": _forester, "quarry": _quarry,
    "sawmill": _sawmill, "windmill": _windmill, "bakery": _bakery, "saltpan": _saltpan,
    "quern_house": _quern_house, "oven": _oven,
    "fisher": _fisher, "hunter": _hunter, "herbalist": _herbalist, "mushroom_hut": _mushroom_hut, "healer": _healer,
    "weaver": _weaver, "smithy": _smithy, "graveyard": _graveyard, "ferry": _ferry(False), "ferry_raft": _ferry(True),
    "chapel": _chapel, "plaza": _plaza, "pasture": _pasture, "watchtower": _watchtower,
}


def far_tris(m):
    bm = m.groups.get(FAR)
    return 0 if bm is None else sum(len(f.verts) - 2 for f in bm.faces)


def add_far(m, recipe=None):
    """Add the "body__far" node to model m (recipe = function(m), default RECIPES[m.name]). Raises over budget."""
    fn = recipe or RECIPES.get(m.name)
    if fn is None:
        return 0
    fn(m)
    n = far_tris(m)
    lim = BUDGET_LANDMARK if m.name in LANDMARKS else BUDGET
    if n > lim:
        raise RuntimeError("%s far LOD %d tris > %d" % (m.name, n, lim))
    print("  %-18s far %4d tris" % (m.name, n))
    return n
