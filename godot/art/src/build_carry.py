"""Carried goods (ROADMAP A22 / E0, OPENING 3.1c): the little things residents carry along the roads -
wheat sheaf -> flour sack -> dough bowl -> bread basket, plus logs, planks, stones, fish, salt, herbs, water, mushrooms ...

One glb per prop: godot/art/models/carry/<name>.glb with two parts (Art.parts):
  "<name>"      close look, ~150-400 tris, storybook low-poly (smooth round shapes + flat caps), fixed palette colours
  "<name>_far"  a tiny coloured blob (~30 tris) of the same size for the far LOD
Every part is centred on its bounding box (pivot = bbox centre) in its natural upright pose (long things along X).
Godot (view/resident_model.gd CARRY) puts it on a socket (hands / shoulder / back / head / hand) and turns it there;
the bbox decides the offset (sits on the shoulder, hangs from the hand ...), so props can be reshaped freely here.
Sizes are a bit oversized (resident is ~1.95 units tall before Style.RESIDENT_SCALE) so they read at the default zoom.
Run: blender -b --factory-startup --python build_carry.py -- [out_dir]   (out_dir = art/models; writes into out_dir/carry)
"""
import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, PartSet, shade, mix, srgb, out_dir_from_argv  # noqa: E402

OUT = os.path.join(out_dir_from_argv(), "carry")

# soft storybook colours (kept off the resident shader's tint keys: r never ~0, never r~1 & g~0)
FLOUR = "f3e8cf"
FLOUR_DUST = "fbf6ea"
SACK_TIE = "b5523a"
BURLAP = "c9a774"
SALT_CLOTH = "e4e6e2"
SALT_TIE = "5f87a8"
DOUGH = "f2dfb6"
CLOTH_RED = "c8573f"
CLOTH_LIGHT = "f1e3cc"
WICKER = "c8a05a"
WICKER_DARK = "9c7a40"
FISH = "8fb1c0"
FISH_BELLY = "dbe7e6"
POT = "a5674a"
POT_DARK = "7c4a35"
PORRIDGE = "eedcae"
TWINE = "8a6a3f"
BUNDLE = "6f93b0"
STRAW = "e8c45f"
STRAW_DARK = "c79f42"
EAR = "f0cf6a"
LEAF = "6f9a3e"
LEAF_LIGHT = "8db454"

PROPS = []   # (name, Model, far colour)


def prop(name, far):
    m = Model(name, seed=len(PROPS) + 3)
    PROPS.append((name, m, far))
    return m


def arc(m, center, r, a0, a1, n, thick, color, axis="x"):
    """A bent handle: n short cylinders along an arc in the XZ (axis x) or YZ (axis y) plane."""
    pts = []
    for k in range(n + 1):
        a = a0 + (a1 - a0) * k / n
        d = Vector((math.cos(a) * r, 0, math.sin(a) * r)) if axis == "x" else Vector((0, math.cos(a) * r, math.sin(a) * r))
        pts.append(Vector(center) + d)
    for p, q in zip(pts[:-1], pts[1:]):
        seg = q - p
        rot = seg.to_track_quat("Z", "Y").to_euler()
        m.cyl(thick, thick, seg.length, pos=p, rot=rot, color=color, seg=5, smooth=True)


def sack(m, body, tie, scale=1.0, dust=None, top=None):
    s = scale
    m.sphere(0.24 * s, pos=(0, 0, 0), scl=(1.0, 0.82, 1.12), color=body, seg=10, rings=7, lumps=0.07, seed=5)
    m.cyl(0.085 * s, 0.05 * s, 0.1 * s, pos=(0, 0, 0.22 * s), color=shade(body, 0.9), seg=8, smooth=True)   # neck
    m.cyl(0.062 * s, 0.062 * s, 0.035 * s, pos=(0, 0, 0.26 * s), color=tie, seg=8)                          # tie
    m.sphere(0.075 * s, pos=(0, 0, 0.33 * s), scl=(1.25, 1.0, 0.75), color=shade(body, 1.04), seg=8, rings=4)  # puffed top
    if dust:                                    # a little flour dust on the shoulder of the sack
        for i, (x, y, z) in enumerate(((-0.12, -0.15, 0.13), (0.06, -0.19, 0.08), (0.15, -0.1, 0.16))):
            m.sphere(0.045 * s, pos=(x * s, y * s, z * s), scl=(1.3, 0.5, 0.8), color=dust, seg=6, rings=3)
    if top:                                     # salt crystals peeking out
        for i, (x, y) in enumerate(((-0.03, 0.0), (0.035, 0.02), (0.0, -0.035))):
            m.box((0.04 * s, 0.04 * s, 0.04 * s), pos=(x * s, y * s, 0.37 * s), rot=(0.4 * i, 0.3, 0.7 * i), color=top)


def basket(m, r=0.22, h=0.15):
    m.cyl(r * 0.82, r, h, pos=(0, 0, -h), color=WICKER_DARK, seg=10, smooth=True, cap=shade(WICKER_DARK, 0.8))
    m.cyl(r * 1.04, r * 1.04, 0.035, pos=(0, 0, -0.03), color=WICKER, seg=10, smooth=True)   # rim band
    m.cyl(r * 0.92, r * 0.94, 0.03, pos=(0, 0, -h * 0.6), color=WICKER, seg=10, smooth=True)   # weave band


# ───────── the bread chain ─────────
m = prop("wheat_sheaf", EAR)            # tied golden bundle, ears at +X (Godot: on the shoulder, ears behind)
m.cyl(0.075, 0.105, 0.5, pos=(-0.42, 0, 0), rot=(0, math.pi / 2, 0), color=STRAW, seg=8, smooth=True,
      cap=STRAW_DARK, bottom_cap=STRAW_DARK)                                                         # stalks
m.cyl(0.11, 0.11, 0.06, pos=(-0.2, 0, 0), rot=(0, math.pi / 2, 0), color=SACK_TIE, seg=8, smooth=True)   # the tie
for i, (dy, dz, r) in enumerate(((0, 0, 0.15), (0.07, 0.06, 0.11), (-0.07, 0.07, 0.11), (0.0, -0.07, 0.1))):
    m.sphere(r, pos=(0.17 + 0.03 * i, dy, dz), scl=(1.5, 0.85, 0.85), color=shade(EAR, 1.0 - 0.05 * i), seg=8, rings=5,
             lumps=0.12, seed=11 + i)                                                               # ears
for i in range(4):                                                                                  # whiskers (awns)
    a = (i - 1.5) * 0.35
    m.cyl(0.008, 0.004, 0.18, pos=(0.36, math.sin(a) * 0.06, math.cos(a) * 0.05), rot=(a, math.pi / 2 - 0.25, 0),
          color=STRAW_DARK, seg=3)

m = prop("flour_sack", FLOUR)           # cream cloth sack, red tie, a little flour dust
sack(m, FLOUR, SACK_TIE, 1.0, dust=FLOUR_DUST)
for z in (-0.06, 0.0):                  # two blue stripes - reads as "flour sack" (and apart from the white apron)
    m.cyl(0.236, 0.236, 0.03, pos=(0, 0, z), scl=(1.0, 0.82, 1.0), color="5f87a8", seg=12, smooth=True)

m = prop("grain_sack", BURLAP)          # burlap sack of grain (낟알)
sack(m, BURLAP, TWINE, 0.95)
for i in range(2):
    m.sphere(0.03, pos=(-0.05 + 0.09 * i, -0.02, 0.36), scl=(1, 1, 0.7), color=EAR, seg=6, rings=3)

m = prop("salt_sack", SALT_CLOTH)       # small white sack, blue tie, crystals on top
sack(m, SALT_CLOTH, SALT_TIE, 0.82, top="ffffff")

m = prop("dough_bowl", DOUGH)           # wooden bowl with a soft dough dome
m.cyl(0.15, 0.25, 0.15, pos=(0, 0, -0.1), color="WOOD", seg=12, smooth=True, bottom_cap="WOOD_DARK")
m.cyl(0.255, 0.255, 0.03, pos=(0, 0, 0.04), color=shade("WOOD", 1.15), seg=12, smooth=True, cap="WOOD_DARK")
m.sphere(0.21, pos=(0, 0, 0.05), scl=(1.0, 1.0, 0.55), color=DOUGH, seg=12, rings=6, lumps=0.05, seed=4)
m.sphere(0.045, pos=(0.06, -0.06, 0.15), scl=(1, 1, 0.5), color=shade(DOUGH, 0.92), seg=6, rings=3)   # a finger poke

m = prop("bread_basket", "BREAD")       # wicker basket, a checked cloth and three fat loaves
basket(m, 0.24, 0.16)
m.sphere(0.2, pos=(0.04, 0.08, 0.0), scl=(1.15, 0.8, 0.28), rot=(0.25, 0, 0.2), color=CLOTH_RED, seg=8, rings=4)
m.sphere(0.07, pos=(0.2, 0.17, 0.02), scl=(1.0, 0.8, 0.6), color=CLOTH_LIGHT, seg=6, rings=3)          # cloth corner
for i, (x, y, rz) in enumerate(((-0.11, -0.04, 0.3), (0.05, -0.08, -0.2), (0.0, 0.07, 0.1))):
    m.sphere(0.115, pos=(x, y, 0.06 + 0.03 * (i == 2)), scl=(1.45, 0.85, 0.75), rot=(0, 0, rz), color="BREAD",
             seg=8, rings=5)
    for k in range(1):                                                                                # scoring
        m.box((0.02, 0.1, 0.02), pos=(x - 0.04 + 0.08 * k, y, 0.13 + 0.03 * (i == 2)), rot=(0, 0, rz),
              color=shade("BREAD", 1.22))
arc(m, (0, 0, -0.01), 0.23, 0.2, math.pi - 0.2, 4, 0.016, WICKER_DARK)                                  # handle

m = prop("loaf", "BREAD")               # a child's single fat loaf
m.sphere(0.15, pos=(0, 0, 0), scl=(1.5, 0.95, 0.85), color="BREAD", seg=12, rings=7)
for k in range(3):
    m.box((0.025, 0.14, 0.03), pos=(-0.1 + 0.1 * k, 0, 0.1), rot=(0, 0.2, 0.35), color=shade("BREAD", 1.25))

m = prop("porridge_pot", POT)           # clay pot of porridge with a wooden spoon
m.sphere(0.2, pos=(0, 0, 0), scl=(1, 1, 0.8), color=POT, seg=12, rings=7)
m.cyl(0.15, 0.16, 0.05, pos=(0, 0, 0.12), color=POT_DARK, seg=12, smooth=True, cap=PORRIDGE)
for sx in (-1, 1):
    m.sphere(0.045, pos=(sx * 0.21, 0, 0.06), scl=(0.8, 1.2, 0.6), color=POT_DARK, seg=6, rings=4)
m.cyl(0.014, 0.014, 0.3, pos=(0.03, 0.02, 0.1), rot=(0.4, 0.35, 0), color="WOOD", seg=5)

# ───────── building stuff ─────────
m = prop("log", "TRUNK")                # a round log with a little leafy twig
m.cyl(0.13, 0.13, 0.95, pos=(-0.475, 0, 0), rot=(0, math.pi / 2, 0), color="TRUNK", seg=9, smooth=True,
      cap="STUMP_TOP", bottom_cap="STUMP_TOP")
m.cyl(0.07, 0.07, 0.012, pos=(0.476, 0, 0), rot=(0, math.pi / 2, 0), color=shade("STUMP_TOP", 0.85), seg=8)   # ring
m.cyl(0.025, 0.018, 0.17, pos=(0.12, 0, 0.1), rot=(0.0, 0.6, 0), color="TRUNK", seg=5)
for k in range(2):
    m.sphere(0.05, pos=(0.2 + 0.03 * k, -0.03 + 0.06 * k, 0.24 - 0.02 * k), scl=(1.5, 0.8, 0.45),
             rot=(0, -0.4, 0.6 * k), color=LEAF if k else LEAF_LIGHT, seg=6, rings=3)

m = prop("plank_stack", "PLANK")        # three boards with a rope
for k in range(3):
    m.box((0.95, 0.24, 0.055), pos=(0.03 * (k - 1), 0.01 * k, -0.08 + k * 0.06), color=shade("PLANK", (0.9, 1.0, 1.08)[k]))
for x in (-0.28, 0.28):
    m.box((0.05, 0.27, 0.2), pos=(x, 0, -0.095), color=TWINE)

m = prop("stone_block", "STONE")        # a cut stone block (a soft bevel on top)
m.box((0.34, 0.27, 0.19), pos=(0, 0, -0.12), color="STONE")
m.box((0.3, 0.23, 0.04), pos=(0, 0, 0.07), color=shade("STONE", 1.1))
m.box((0.36, 0.29, 0.02), pos=(0, 0, -0.13), color="STONE_DARK")
m.sphere(0.04, pos=(0.1, -0.12, 0.03), scl=(1.2, 0.5, 0.9), color="MOSS", seg=6, rings=3)

# ───────── food & gathering ─────────
m = prop("fish_string", FISH)           # three little fish on a cord (hangs from the hand, heads up)
m.cyl(0.008, 0.008, 0.18, pos=(0, 0, 0.0), color=TWINE, seg=4)
m.cyl(0.03, 0.03, 0.01, pos=(0, 0, 0.18), rot=(math.pi / 2, 0, 0), color=TWINE, seg=6)
for i, (x, y, z) in enumerate(((-0.07, 0.0, -0.12), (0.05, 0.02, -0.15), (0.0, -0.05, -0.2))):
    m.sphere(0.06, pos=(x, y, z), scl=(0.55, 0.85, 2.0), color=FISH if i != 1 else shade(FISH, 1.1), seg=8, rings=5)
    m.sphere(0.035, pos=(x, y - 0.02, z - 0.02), scl=(0.6, 0.8, 1.8), color=FISH_BELLY, seg=6, rings=3)
    m.cyl(0.055, 0.0, 0.08, pos=(x, y, z - 0.1), rot=(math.pi, 0, 0), scl=(1.0, 0.25, 1.0), color=shade(FISH, 0.8), seg=4)
    m.sphere(0.012, pos=(x + 0.03, y - 0.02, z + 0.07), color="252122", seg=4, rings=2)           # eye

m = prop("herb_bundle", LEAF)          # a bunch of herbs tied with twine (stems up, hanging from the hand)
m.cyl(0.04, 0.03, 0.12, pos=(0, 0, 0.0), color="LOOK_HERB", seg=6)
m.cyl(0.045, 0.045, 0.03, pos=(0, 0, 0.03), color=TWINE, seg=6)
for k in range(6):
    a = k / 6 * math.tau
    m.sphere(0.065, pos=(math.cos(a) * 0.05, math.sin(a) * 0.05, -0.1 - 0.02 * (k % 2)), scl=(0.7, 0.45, 1.6),
             rot=(math.sin(a) * 0.35, -math.cos(a) * 0.35, 0), color=LEAF if k % 2 else LEAF_LIGHT, seg=6, rings=4)
m.sphere(0.03, pos=(0.02, -0.06, -0.2), color="f2e6a0", seg=5, rings=3)                         # a tiny flower

m = prop("water_bucket", "WATER")       # wooden bucket with water and a rope handle
m.cyl(0.13, 0.16, 0.24, pos=(0, 0, -0.12), color="WOOD", seg=12, smooth=True, cap="WATER", bottom_cap="WOOD_DARK")
for z in (-0.08, 0.06):
    m.cyl(0.152 + z * 0.1, 0.155 + z * 0.1, 0.03, pos=(0, 0, z), color="WOOD_DARK", seg=12, smooth=True)
arc(m, (0, 0, 0.1), 0.15, 0.1, math.pi - 0.1, 6, 0.012, TWINE)

m = prop("mushroom_basket", "MUSHROOM_CAP")   # basket with three plump mushrooms
basket(m, 0.21, 0.14)
for i, (x, y, r) in enumerate(((-0.08, -0.03, 0.09), (0.08, -0.05, 0.08), (0.0, 0.07, 0.1))):
    m.cyl(0.035, 0.03, 0.08, pos=(x, y, -0.03), color="MUSHROOM_STEM", seg=6)
    m.sphere(r, pos=(x, y, 0.05), scl=(1, 1, 0.6), color="MUSHROOM_CAP", seg=8, rings=4)
    m.sphere(0.02, pos=(x + 0.03, y - 0.03, 0.05 + r * 0.5), scl=(1, 1, 0.5), color="MUSHROOM_DOT", seg=5, rings=2)

m = prop("bundle", BUNDLE)              # generic: a cloth bundle with knot ears (any good we have no prop for)
m.sphere(0.21, pos=(0, 0, 0), scl=(1.1, 0.9, 0.85), color=BUNDLE, seg=10, rings=6, lumps=0.06, seed=9)
m.sphere(0.06, pos=(0, 0, 0.17), scl=(1, 1, 0.8), color=shade(BUNDLE, 0.85), seg=6, rings=4)
for sx in (-1, 1):
    m.sphere(0.055, pos=(sx * 0.07, 0, 0.23), scl=(1.4, 0.6, 0.8), rot=(0, sx * 0.6, 0), color=shade(BUNDLE, 1.1), seg=6, rings=3)
for k in range(3):                                                                                    # polka dots
    a = k * 2.1
    m.sphere(0.03, pos=(math.cos(a) * 0.15, -0.16 + 0.03 * k, math.sin(a) * 0.08), scl=(1, 0.4, 1),
             color=CLOTH_LIGHT, seg=5, rings=2)


# (E3-6, GD 3.0 물가 — 2026-11-07 사용자) the fish residents catch are medaka (송사리), about a resident's size:
# a small one is hugged by one carrier, a bigger one is slung on a pole between two. Big lake fish are scenery only.
POLE_HALF = 1.3          # half the gap between the two carriers (model units — view/resident_model.gd POLE_GAP / 2)
MEDAKA = "e2e8d6"        # pale, see-through-looking body (pale olive-cream)
MEDAKA_BACK = "c3cba6"   # a faint darker line along the back
MEDAKA_BELLY = "f6f3e8"
MEDAKA_FIN = "eef0e4"


def medaka(m, cx, cz, L=1.1):
    """A slim medaka along X (head at +X), upright (back +Z), centred at (cx, 0, cz): long thin pale body, a faint
    back line, big round eyes with white rims near the snout, upturned little mouth, broad pale tail fin, a long
    anal fin underneath and a small dorsal fin set far back."""
    m.sphere(L * 0.5, pos=(cx, 0, cz), scl=(1.0, 0.2, 0.25), color=MEDAKA, seg=8, rings=5)
    m.sphere(L * 0.42, pos=(cx - 0.02, 0, cz + L * 0.05), scl=(1.0, 0.13, 0.13), color=MEDAKA_BACK, seg=6, rings=3)
    m.sphere(L * 0.4, pos=(cx + 0.02, 0, cz - L * 0.05), scl=(1.0, 0.17, 0.14), color=MEDAKA_BELLY, seg=6, rings=3)
    m.cyl(L * 0.17, 0.0, L * 0.2, pos=(cx - L * 0.44, 0, cz), rot=(0, -math.pi / 2, 0), scl=(1.0, 0.18, 1.0),
          color=MEDAKA_FIN, seg=4)                                                                # tail fin
    m.box((L * 0.4, L * 0.02, L * 0.09), pos=(cx - L * 0.12, 0, cz - L * 0.19), color=MEDAKA_FIN)    # anal fin
    m.cyl(L * 0.06, 0.0, L * 0.08, pos=(cx - L * 0.26, 0, cz + L * 0.1), scl=(1.4, 0.2, 1.0), color=MEDAKA_FIN, seg=4)
    for sy in (-1, 1):                                                                            # big eyes
        m.sphere(L * 0.07, pos=(cx + L * 0.33, sy * L * 0.08, cz + L * 0.02), scl=(1, 0.5, 1), color="ffffff", seg=6, rings=3)
        m.sphere(L * 0.05, pos=(cx + L * 0.34, sy * L * 0.105, cz + L * 0.02), scl=(1, 0.5, 1), color="252122", seg=6, rings=3)
    m.sphere(L * 0.035, pos=(cx + L * 0.49, 0, cz + L * 0.04), scl=(0.8, 1.2, 0.6), color=MEDAKA_BACK, seg=5, rings=3)  # mouth


def pole(m, x0, x1, z=0.0):
    """A straight grass-stalk pole along X (joints + two lashings)."""
    m.cyl(0.035, 0.035, x1 - x0, pos=(x0, 0, z), rot=(0, math.pi / 2, 0), color="a9c070", seg=6, smooth=True,
          cap="d8c896", bottom_cap="d8c896")
    for k in range(1, 3):
        x = x0 + (x1 - x0) * k / 3
        m.cyl(0.043, 0.043, 0.035, pos=(x, 0, z), rot=(0, math.pi / 2, 0), color="8fa45c", seg=6)


m = prop("medaka", MEDAKA)              # a small medaka hugged in both arms by one carrier
medaka(m, 0.0, 0.0, 0.62)

m = prop("fish_pole", MEDAKA)             # front carrier: the pole from his shoulder back to the middle, the fish slung under it
pole(m, -0.15, POLE_HALF + 0.05)
medaka(m, POLE_HALF, -0.42, 1.15)
for x in (POLE_HALF - 0.3, POLE_HALF + 0.32):           # two cords from the pole round the fish
    m.cyl(0.014, 0.014, 0.4, pos=(x, 0, -0.38), color=TWINE, seg=4)
    m.cyl(0.05, 0.05, 0.03, pos=(x, 0, -0.02), color=TWINE, seg=6)

m = prop("pole_half", "a9c070")         # back carrier: the other half of the pole (meets the front half over the fish)
pole(m, -0.15, POLE_HALF + 0.05)
m.cyl(0.05, 0.05, 0.05, pos=(POLE_HALF, 0, 0), rot=(0, math.pi / 2, 0), color=TWINE, seg=6)
m.sphere(0.06, pos=(-0.05, 0, 0.02), scl=(1.2, 1.0, 0.6), color=TWINE, seg=6, rings=3)   # a pad on the shoulder

m = prop("fruit_piece", "f39a5a")       # (E3-3) a wedge cut from the giant fruit: blush skin outside, juicy flesh on the cut faces
fp = m.sphere(0.3, pos=(0, 0, 0), color="f39a5a", seg=10, rings=7)
bmw = m._bm("body")
for v in {v: True for f in fp for v in f.verts}:
    if v.co.y < 0:
        v.co.y = 0.0
    if v.co.z < -0.05:
        v.co.z = -0.05
bmw.normal_update()
for f in fp:
    n = f.normal
    flat = n.y < -0.9 or n.z < -0.9
    m._finish(bmw, [f], "f6dc8a" if flat else mix("f6c065", "e0703f", max(0.0, min(1.0, 0.5 + 0.5 * n.x))), not flat)
m.sphere(0.04, pos=(0.08, 0.02, 0.27), scl=(1.0, 1.0, 0.5), color="6f9a3e", seg=5, rings=3)   # a bit of stalk


def bbox(model):
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for bm in model.groups.values():
        for v in bm.verts:
            lo = Vector(map(min, lo, v.co))
            hi = Vector(map(max, hi, v.co))
    return lo, hi


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for name, model, far in PROPS:
        lo, hi = bbox(model)
        c = (lo + hi) / 2
        half = (hi - lo) / 2
        blob = Model(name + "_far")
        blob.sphere(1.0, pos=c, scl=tuple(max(0.05, h * 0.92) for h in half), color=far, seg=6, rings=4)
        ps = PartSet(name)
        ps.add(name, model, pivot=c)
        ps.add(name + "_far", blob, pivot=c)
        tris = ps.export(OUT)
        total += tris.get(name, 0)
    print("  carry props: %d, avg %d tris" % (len(PROPS), total // max(1, len(PROPS))))
