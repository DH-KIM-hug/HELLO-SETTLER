"""Resident part kit (design/concept/4-1.png): ~4 heads tall chibi villagers, one glb with separately pivoted parts.
Godot (view/resident_model.gd) picks parts per resident and tints them in render/resident.gdshader.

Tint keys (vertex colour, sRGB) -> replaced per resident, the blue channel = brightness:
  (0, 0, b)   cloth      (1, 0, b)   skin      (0, 1, b)   hair      (0, .5, b) accent (scarf / cap)
Everything else is a fixed colour (boots, belt, apron, straw, eyes, props) from Balance.LOOK_FIXED / Style.

Part pivots (object origin = joint): legs at the hip, arms at the shoulder, head things at the neck, items at the
hands' carry point, tools at the right hand. Rest pose = standing, facing -Y (front).
Run: blender -b --factory-startup --python build_residents.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, PartSet, Vector, shade, mix, out_dir_from_argv  # noqa: E402

OUT = out_dir_from_argv()

CLOTH = (0, 0, 1.0)
CLOTH_D = (0, 0, 0.82)
CLOTH_DD = (0, 0, 0.7)
SKIN = (1, 0, 1.0)
SKIN_D = (1, 0, 0.9)
HAIR = (0, 1, 1.0)
HAIR_D = (0, 1, 0.82)
ACCENT = (0, 0.5, 1.0)
ACCENT_D = (0, 0.5, 0.85)

HIP = 0.6
SHOULDER = 1.22
NECK = 1.26
HEAD_R = 0.32                 # head radius -> head ~0.64 tall, body ~2.25 => ~3.5-4 heads
HEAD_C = NECK + 0.3
ITEM = Vector((0, -0.36, 0.92))
HAND_R = Vector((0.3, -0.06, SHOULDER - 0.58))


def part(name):
    return Model(name)


def build():
    ps = PartSet("resident")

    # ── legs (one mesh per style, used for both sides; pivot = hip joint) ──
    for nm, col in (("leg_trousers", "LOOK_TROUSER"), ("leg_stocking", "LOOK_STOCKING")):
        m = part(nm)
        m.cyl(0.1, 0.11, HIP - 0.12, pos=(0, 0, 0.1), color=col, seg=8, smooth=True)
        m.sphere(0.13, pos=(0, -0.05, 0.08), scl=(0.95, 1.35, 0.7), color="LOOK_BOOT", seg=9, rings=5)
        ps.add(nm, m, pivot=(0, 0, HIP))

    # ── torsos (pivot = ground centre; the whole body bobs) ──
    m = part("torso_tunic")
    m.cyl(0.27, 0.23, SHOULDER - HIP + 0.08, pos=(0, 0, HIP - 0.05), color=CLOTH, seg=10, smooth=True, scl=(1, 0.78, 1))
    m.cyl(0.31, 0.28, 0.2, pos=(0, 0, HIP - 0.16), color=CLOTH_D, seg=10, smooth=True, scl=(1, 0.8, 1))       # hem
    m.cyl(0.285, 0.285, 0.07, pos=(0, 0, HIP + 0.1), color="LOOK_BELT", seg=10, scl=(1, 0.8, 1))
    m.box((0.08, 0.03, 0.07), pos=(0, -0.235, HIP + 0.1), color="WINDOW_LIT")                                   # buckle
    m.sphere(0.24, pos=(0, 0, SHOULDER - 0.04), scl=(1.15, 0.85, 0.5), color=CLOTH, seg=10, rings=5)            # shoulders
    m.box((0.14, 0.03, 0.12), pos=(0, -0.2, SHOULDER - 0.16), color=SKIN_D)                                       # v-neck
    ps.add("torso_tunic", m)

    m = part("torso_dress")
    m.cyl(0.25, 0.22, SHOULDER - HIP + 0.04, pos=(0, 0, HIP + 0.0), color=CLOTH, seg=10, smooth=True, scl=(1, 0.78, 1))
    m.cyl(0.4, 0.25, HIP + 0.05, pos=(0, 0, 0.1), color=CLOTH_D, seg=12, smooth=True, scl=(1, 0.85, 1))         # skirt
    m.box((0.36, 0.04, HIP + 0.02), pos=(0, -0.29, 0.13), rot=(-0.24, 0, 0), color="LOOK_APRON")                # apron
    m.box((0.3, 0.03, 0.3), pos=(0, -0.205, HIP + 0.2), color="LOOK_APRON")                                        # bib
    m.sphere(0.23, pos=(0, 0, SHOULDER - 0.04), scl=(1.12, 0.85, 0.5), color=CLOTH, seg=10, rings=5)
    m.cyl(0.26, 0.26, 0.05, pos=(0, 0, HIP + 0.1), color="LOOK_APRON", seg=10, scl=(1, 0.8, 1))                  # apron tie
    ps.add("torso_dress", m)

    # ── arm (pivot = shoulder) ──
    m = part("arm")
    m.cyl(0.085, 0.1, 0.42, pos=(0, 0, SHOULDER - 0.46), color=CLOTH_DD, seg=7, smooth=True)
    m.sphere(0.085, pos=(0, 0, SHOULDER - 0.53), color=SKIN, seg=7, rings=5)
    ps.add("arm", m, pivot=(0, 0, SHOULDER))

    # ── heads (pivot = neck) ──
    for nm, scl in (("head_round", (1.0, 0.95, 0.95)), ("head_long", (0.94, 0.92, 1.04))):
        m = part(nm)
        m.sphere(HEAD_R, pos=(0, 0, HEAD_C), scl=scl, color=SKIN, seg=12, rings=8)
        for sx in (-1, 1):
            m.sphere(0.07, pos=(sx * HEAD_R * scl[0] * 0.97, 0.02, HEAD_C - 0.02), scl=(0.6, 1, 1), color=SKIN_D, seg=6, rings=4)
            m.sphere(0.04, pos=(sx * 0.11, -HEAD_R * scl[1] * 0.93, HEAD_C - 0.0), scl=(1, 0.6, 1.25), color="LOOK_EYE", seg=6, rings=4)
            m.sphere(0.035, pos=(sx * 0.17, -HEAD_R * scl[1] * 0.86, HEAD_C - 0.09), scl=(1.2, 0.5, 0.8), color=(0.94, 0.62, 0.55), seg=6, rings=3)
        m.sphere(0.035, pos=(0, -HEAD_R * scl[1] - 0.005, HEAD_C - 0.06), color=SKIN_D, seg=6, rings=4)            # nose
        m.cyl(0.09, 0.1, 0.08, pos=(0, 0, NECK - 0.02), color=SKIN_D, seg=7)                                         # neck
        ps.add(nm, m, pivot=(0, 0, NECK))

    def cap(m, depth=0.0, front_cut=0.45):
        """Hair cap: a slightly bigger sphere shell over the top/back, trimmed at the brow."""
        def fn(f):
            c = f.calc_center_median()
            return HAIR if c.z > HEAD_C - 0.02 or c.y > 0.05 else HAIR_D
        faces = m.sphere(HEAD_R * 1.07, pos=(0, 0.02, HEAD_C + 0.02), scl=(1.02, 1.0, 0.98), color=HAIR, seg=12, rings=8, colfn=fn)
        bm = m._bm("body")
        import bmesh
        kill = [f for f in faces if f.calc_center_median().y < -HEAD_R * front_cut and f.calc_center_median().z < HEAD_C + 0.13
                or f.calc_center_median().z < HEAD_C - 0.22 - depth]
        bmesh.ops.delete(bm, geom=kill, context="FACES")

    # ── hair (pivot = neck) ──
    m = part("hair_short")
    cap(m)
    m.sphere(0.12, pos=(-0.08, -0.22, HEAD_C + 0.2), scl=(1.6, 0.8, 0.6), rot=(0, 0, 0.3), color=HAIR, seg=8, rings=4)   # fringe
    ps.add("hair_short", m, pivot=(0, 0, NECK))

    m = part("hair_braids")
    cap(m, depth=0.05)
    for sx in (-1, 1):
        for k in range(3):
            m.sphere(0.07 - k * 0.008, pos=(sx * 0.3, 0.05, HEAD_C - 0.22 - k * 0.11), color=HAIR_D if k % 2 else HAIR, seg=7, rings=4)
        m.sphere(0.04, pos=(sx * 0.3, 0.05, HEAD_C - 0.55), color="LOOK_SCARF_B", seg=6, rings=3)
    ps.add("hair_braids", m, pivot=(0, 0, NECK))

    m = part("hair_bun")
    cap(m)
    m.sphere(0.14, pos=(0, 0.26, HEAD_C + 0.12), color=HAIR, seg=9, rings=6)
    m.cyl(0.1, 0.1, 0.04, pos=(0, 0.17, HEAD_C + 0.12), rot=(math.pi / 2, 0, 0), color=HAIR_D, seg=8)
    ps.add("hair_bun", m, pivot=(0, 0, NECK))

    m = part("hair_long")
    cap(m, depth=0.12)
    m.box((0.56, 0.12, 0.5), pos=(0, 0.22, HEAD_C - 0.5), color=HAIR_D)
    m.sphere(0.29, pos=(0, 0.2, HEAD_C - 0.2), scl=(1.0, 0.45, 1.0), color=HAIR, seg=10, rings=6)
    ps.add("hair_long", m, pivot=(0, 0, NECK))

    # ── curl variants (stage 7: appearance genes — 0 straight / 1 wave / 2 curly) ──
    def curls(m, n_ring, rings_z, r_shell, ball, back_only_below=None, jitter=0.0):
        """Small round lumps over the hair shell -> curly silhouette (alternating light/dark hair key)."""
        k = 0
        for zi, (z, n) in enumerate(zip(rings_z, n_ring)):
            for i in range(n):
                a = (i + 0.5 * (zi % 2)) / n * 2 * math.pi
                rr = math.sqrt(max(0.0, r_shell ** 2 - (z - HEAD_C) ** 2)) if abs(z - HEAD_C) < r_shell else 0.05
                x, y = math.sin(a) * rr, math.cos(a) * rr + 0.02
                if back_only_below is not None and z < back_only_below and y < 0.0:
                    continue
                if y < -HEAD_R * 0.55 and z < HEAD_C + 0.12:       # keep the face open
                    continue
                m.sphere(ball * (1.0 + 0.12 * ((k * 7) % 3 - 1)), pos=(x, y, z), color=HAIR if k % 3 else HAIR_D, seg=7, rings=5)
                k += 1

    m = part("hair_curly")
    cap(m)
    curls(m, (7, 9, 9), (HEAD_C + 0.3, HEAD_C + 0.18, HEAD_C + 0.02), HEAD_R * 1.12, 0.09, back_only_below=HEAD_C + 0.1)
    m.sphere(0.1, pos=(0, 0.02, HEAD_C + 0.36), color=HAIR, seg=8, rings=5)
    ps.add("hair_curly", m, pivot=(0, 0, NECK))

    m = part("hair_curly_long")
    cap(m, depth=0.1)
    curls(m, (7, 9, 10, 9, 7), (HEAD_C + 0.3, HEAD_C + 0.18, HEAD_C + 0.02, HEAD_C - 0.16, HEAD_C - 0.32), HEAD_R * 1.14, 0.095,
          back_only_below=HEAD_C + 0.1)
    m.sphere(0.1, pos=(0, 0.02, HEAD_C + 0.36), color=HAIR, seg=8, rings=5)
    ps.add("hair_curly_long", m, pivot=(0, 0, NECK))

    m = part("hair_wave")
    cap(m)
    m.sphere(0.13, pos=(-0.1, -0.21, HEAD_C + 0.2), scl=(1.7, 0.8, 0.65), rot=(0, 0.25, 0.35), color=HAIR, seg=8, rings=5)   # swept fringe
    m.sphere(0.1, pos=(0.14, -0.2, HEAD_C + 0.24), scl=(1.3, 0.8, 0.6), rot=(0, -0.3, -0.2), color=HAIR_D, seg=8, rings=5)
    for sx in (-1, 1):
        m.sphere(0.09, pos=(sx * 0.31, 0.08, HEAD_C - 0.12), scl=(0.7, 1.2, 1.0), color=HAIR_D, seg=7, rings=4)            # flick over ears
    m.sphere(0.12, pos=(0, 0.3, HEAD_C - 0.1), scl=(1.6, 0.6, 0.8), color=HAIR, seg=8, rings=5)                         # nape wave
    ps.add("hair_wave", m, pivot=(0, 0, NECK))

    m = part("hair_wave_long")
    cap(m, depth=0.12)
    m.sphere(0.13, pos=(-0.1, -0.21, HEAD_C + 0.2), scl=(1.7, 0.8, 0.65), rot=(0, 0.25, 0.35), color=HAIR, seg=8, rings=5)
    for k in range(4):                                                                                                  # wavy fall at the back
        z = HEAD_C - 0.12 - k * 0.13
        m.sphere(0.17 - k * 0.012, pos=((0.05 if k % 2 else -0.05), 0.22 + 0.02 * k, z), scl=(1.75, 0.6, 0.85),
                 color=HAIR if k % 2 == 0 else HAIR_D, seg=9, rings=5)
    for sx in (-1, 1):
        for k in range(3):
            m.sphere(0.08, pos=(sx * (0.3 + 0.03 * (k % 2)), 0.06, HEAD_C - 0.14 - k * 0.12), color=HAIR_D if k % 2 else HAIR, seg=7, rings=4)
    ps.add("hair_wave_long", m, pivot=(0, 0, NECK))

    m = part("beard")
    m.sphere(0.2, pos=(0, -0.17, HEAD_C - 0.17), scl=(1.25, 0.7, 0.9), color=HAIR, seg=9, rings=6)
    m.sphere(0.06, pos=(0, -0.3, HEAD_C - 0.05), scl=(2.0, 0.6, 0.6), color=HAIR_D, seg=6, rings=4)     # moustache
    ps.add("beard", m, pivot=(0, 0, NECK))

    # ── hats (pivot = neck) ──
    m = part("hat_straw")
    m.cyl(0.52, 0.5, 0.05, pos=(0, 0, HEAD_C + 0.17), color="LOOK_STRAW", seg=12, smooth=False)
    m.cyl(0.27, 0.23, 0.22, pos=(0, 0, HEAD_C + 0.2), color="LOOK_STRAW", seg=10, smooth=True, cap="LOOK_STRAW")
    m.cyl(0.275, 0.275, 0.06, pos=(0, 0, HEAD_C + 0.22), color="LOOK_STRAW_DARK", seg=10)
    ps.add("hat_straw", m, pivot=(0, 0, NECK))

    m = part("hat_scarf")
    sc = m.sphere(HEAD_R * 1.1, pos=(0, 0.03, HEAD_C + 0.03), color=ACCENT, seg=12, rings=8)
    import bmesh
    bm = m._bm("body")
    bmesh.ops.delete(bm, geom=[f for f in sc if f.calc_center_median().y < -HEAD_R * 0.5 and f.calc_center_median().z < HEAD_C + 0.18
                               or f.calc_center_median().z < HEAD_C - 0.12], context="FACES")
    m.sphere(0.09, pos=(0, 0.34, HEAD_C - 0.05), color=ACCENT_D, seg=7, rings=4)                     # knot
    m.box((0.08, 0.04, 0.2), pos=(0.05, 0.36, HEAD_C - 0.3), rot=(0.2, 0.2, 0), color=ACCENT_D)     # tail
    ps.add("hat_scarf", m, pivot=(0, 0, NECK))

    m = part("hat_cap")
    m.sphere(HEAD_R * 1.1, pos=(0, 0.02, HEAD_C + 0.12), scl=(1.05, 1.05, 0.55), color=ACCENT, seg=12, rings=6)
    m.cyl(0.2, 0.2, 0.03, pos=(0, -0.28, HEAD_C + 0.12), scl=(1.2, 0.7, 1), color=ACCENT_D, seg=10)       # peak
    ps.add("hat_cap", m, pivot=(0, 0, NECK))

    # ── carried items (pivot = carry point in front of the chest) ──
    o = ITEM
    m = part("item_log")
    m.cyl(0.12, 0.12, 0.95, pos=o + Vector((-0.475, 0, 0)), rot=(0, math.pi / 2, 0.12), color="TRUNK", seg=7, smooth=True,
          cap="STUMP_TOP", bottom_cap="STUMP_TOP")
    ps.add("item_log", m, pivot=o)
    m = part("item_plank")
    for k in range(3):
        m.box((0.95, 0.3, 0.06), pos=o + Vector((0.02 * k, 0, -0.1 + k * 0.065)), color=shade("PLANK", (0.92, 1.0, 1.06)[k]))
    ps.add("item_plank", m, pivot=o)
    m = part("item_stone")
    m.ico(0.2, pos=o + Vector((0, 0, 0.02)), scl=(1.1, 1, 0.85), color="ROCK", subdiv=2, smooth=True, lumps=0.2, seed=3)
    ps.add("item_stone", m, pivot=o)
    m = part("item_sack")
    m.sphere(0.22, pos=o + Vector((0, 0, 0.02)), scl=(1, 0.8, 1.1), color=mix("THATCH", "PLASTER", 0.55), seg=9, rings=6, lumps=0.1)
    m.cyl(0.07, 0.03, 0.12, pos=o + Vector((0, 0, 0.22)), color=shade(mix("THATCH", "PLASTER", 0.55), 0.85), seg=6)
    ps.add("item_sack", m, pivot=o)
    m = part("item_basket")
    m.cyl(0.24, 0.3, 0.2, pos=o + Vector((0, 0, -0.1)), color="LOOK_STRAW_DARK", seg=10, smooth=True, cap="LOOK_STRAW")
    for k in range(3):
        m.sphere(0.1, pos=o + Vector((-0.12 + k * 0.12, 0.02 * k, 0.12)), scl=(1.2, 1, 0.75), color="BREAD", seg=7, rings=4)
    ps.add("item_basket", m, pivot=o)
    m = part("item_crate")
    m.box((0.4, 0.34, 0.32), pos=o + Vector((0, 0, -0.14)), color=shade("WOOD", 1.2))
    m.box((0.42, 0.36, 0.05), pos=o + Vector((0, 0, 0.13)), color="WOOD")
    ps.add("item_crate", m, pivot=o)
    m = part("item_water")
    m.cyl(0.17, 0.15, 0.3, pos=o + Vector((0, 0, -0.14)), color="WOOD", seg=9, smooth=True, cap="WATER")
    m.cyl(0.18, 0.18, 0.04, pos=o + Vector((0, 0, 0.02)), color="WOOD_DARK", seg=9)
    ps.add("item_water", m, pivot=o)

    # ── tools (pivot = right hand; handle points down the arm axis -Z) ──
    h = HAND_R
    m = part("tool_axe")
    m.cyl(0.03, 0.03, 0.7, pos=h + Vector((0, 0, -0.1)), rot=(math.pi / 2 - 0.1, 0, 0), color="WOOD", seg=5)
    m.box((0.05, 0.22, 0.16), pos=h + Vector((0, -0.64, -0.12)), color="ROCK_DARK")
    ps.add("tool_axe", m, pivot=h)
    m = part("tool_hammer")
    m.cyl(0.03, 0.03, 0.55, pos=h + Vector((0, 0, -0.08)), rot=(math.pi / 2 - 0.1, 0, 0), color="WOOD", seg=5)
    m.box((0.2, 0.1, 0.1), pos=h + Vector((0, -0.5, -0.12)), color="ROCK_DARK")
    ps.add("tool_hammer", m, pivot=h)
    m = part("tool_sickle")
    m.cyl(0.03, 0.03, 0.3, pos=h + Vector((0, 0, -0.05)), rot=(math.pi / 2, 0, 0), color="WOOD", seg=5)
    for k in range(5):
        a = k / 4 * math.pi * 0.9
        m.box((0.05, 0.08, 0.035), pos=h + Vector((math.sin(a) * 0.14, -0.3 - (1 - math.cos(a)) * 0.0 - math.sin(a) * 0.06, -0.02 + math.cos(a) * 0.12 - 0.1)),
              rot=(0, -a, 0), color="ROCK")
    ps.add("tool_sickle", m, pivot=h)

    ps.export(OUT)


if __name__ == "__main__":
    print("residents ->", OUT)
    build()
