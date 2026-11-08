"""Pioneer-era bread chain + giant's things (BALANCE v5, GD 7.3, SHOP 설계도):
  quern_house        맷돌간: small open thatched shed on four posts; a round two-stone hand quern on a stump stand,
                     a flour bowl under its spout, flour sack + wheat sheaf beside it. The TOP stone is NOT in here:
  quern_stone        the turning top stone with its upright wooden handle, origin = the spin axis on the lower stone's
                     top face. view/village_view.gd places it at QUERN_STONE_AT (Godot coords) and turns it while milling.
  oven               공용 화덕: domed clay bread oven on a stone plinth, dark arched mouth, little chimney, wooden peel
                     leaning on the plinth, a small woodpile and a bread board. The fire in the mouth is separate:
  oven_glow          the glowing fire disc for the mouth (same origin as oven). view toggles it with an emissive
                     material while baking (VillageView.OVEN_GLOW).
  blueprint_scroll   설계도: a rolled paper scroll tied with a red ribbon (lying on the ground, long axis along X).
  blueprint_open     the same sheet unrolled flat (curled ends) with a little house plan drawn on it.
  carry/pram         유모차: wooden baby carriage (basket body, cloth hood, push handle) — carry prop for resident
                     units scaled by PRAM_UNIT into cells (A23). Parts: "pram" body (origin = ground under the basket centre) ·
                     "pram__far" blob · "pram_wheel_fl/fr/bl/br" (pivot = axle centre, axle along X) so they can spin.
Units: 1 = one cell; adult resident ~1.0 tall in the village (models above), front = -Y (Godot +Z).
Run: blender -b --factory-startup --python build_pioneer.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, PartSet, Vector, shade, mix, out_dir_from_argv  # noqa: E402
from far_kit import add_far  # noqa: E402  (far LOD node "body__far", buildings GDD decision 1)
from build_buildings import smoke  # noqa: E402

OUT = out_dir_from_argv()
Model.nl_thin = 0.12      # (P1 perf pass 4) thin pieces: hull outline only, no crease lines (lowpoly.Model.nl_thin)
CLAY = "d79a6a"
CLAY_DARK = "b07650"
CLAY_LIGHT = "e8b88a"
SOOT = "4e423c"
QUERN = "a9b0ac"
QUERN_DARK = "858f8c"
FLOUR = "f3e8cf"
PAPER = "f2e7c9"
PAPER_EDGE = "dccca2"
INK = "5d7894"
RIBBON = "c4513d"
STRAW = "e8c45f"
STRAW_DARK = "c79f42"

# top stone sits on the lower stone: (x, y, z) in Blender coords of quern_house
QX, QY = 0.0, 0.05
STAND_H = 0.34
LOW_H = 0.12
QZ = STAND_H + LOW_H


# ───────────── tiny-folk materials (GAME_DESIGN 3.0: no planks / logs — reeds, twigs, grass, leaves, pebbles) ─────────────
REED = "cdbb84"            # dry hollow reed stem
REED_NODE = "a8935e"
TWIG = "8a6b52"
TWIG_DARK = "6b5240"
GRASS_WEAVE = "c9b26a"     # woven dry grass
GRASS_WEAVE_DARK = "a89050"
LEAF_A = "7fb565"
LEAF_B = "5f9a52"
LEAF_VEIN = "4f8346"
BARK_SCRAP = "8f6f56"
ACORN_CAP = "9a7448"
ACORN_DARK = "7a5838"
PEBBLE = "b4b8ae"
TIE = "8a6a3f"


def stem(m, a, b, r, col=REED, node=REED_NODE, nodes=2, seg=7):
    """Straight reed / twig from a to b with darker node rings (the joints of a grass stalk)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = d.to_track_quat("Z", "Y").to_euler()
    m.cyl(r, r * 0.9, d.length, pos=a, rot=rot, color=col, seg=seg, smooth=True, cap=shade(col, 1.15),
          bottom_cap=shade(col, 1.15))
    for k in range(nodes):
        t = (k + 1) / (nodes + 1)
        m.cyl(r * 1.15, r * 1.15, min(0.03, d.length * 0.05), pos=a + d * t, rot=rot, color=node, seg=seg, smooth=True)


def lash(m, p, r=0.06):
    """A grass-twine lashing knot where stems meet."""
    m.sphere(r, pos=p, scl=(1, 1, 0.7), color=TIE, seg=6, rings=3)


def leaf_roof(m, W, D, H, rise, n=3, over=0.24, seed=0):
    """Gable roof (ridge along X) of overlapping big leaves: n leaves per slope in two courses (upper overlaps
    lower), each with a midrib running down-slope; a rolled leaf along the ridge."""
    half = D / 2 + over
    ang = math.atan2(rise, half)
    ln = math.hypot(half, rise)
    cols = (LEAF_A, LEAF_B)
    for sy in (-1, 1):
        for course in (1, 0):
            for k in range(n):
                x = -W / 2 - over * 0.5 + (k + 0.5) * (W + over) / n + (0.07 if course else -0.05)
                t = 0.66 if course else 0.3                      # along the slope, 0 = ridge
                y = sy * half * t
                z = H + rise * (1 - t) + 0.05 + (0.0 if course else 0.03)
                tw = (k % 2 - 0.5) * 0.12
                m.sphere(1.0, pos=(x, y, z), scl=((W + over) / n * 0.62, ln * 0.42, 0.035), rot=(-sy * ang, 0, tw),
                         color=cols[(k + course + seed) % 2], seg=10, rings=4)
                m.box((0.024, ln * 0.7, 0.056), pos=(x, y, z - 0.028), rot=(-sy * ang, 0, tw), color=LEAF_VEIN)
    m.cyl(0.07, 0.07, W + over * 1.6, pos=(-(W + over * 1.6) / 2, 0, H + rise + 0.04), rot=(0, math.pi / 2, 0),
          color=LEAF_B, seg=8, smooth=True, cap=LEAF_VEIN, bottom_cap=LEAF_VEIN)


def woven_wall(m, x0, x1, y, z0, h, rows=5):
    """Woven grass screen along X at y: horizontal grass bands of alternating shade between upright twig stakes."""
    w = x1 - x0
    for r in range(rows):
        m.box((w, 0.05, h / rows * 0.95), pos=((x0 + x1) / 2, y + (0.012 if r % 2 else -0.012), z0 + r * h / rows),
              color=GRASS_WEAVE if r % 2 else GRASS_WEAVE_DARK)
    nst = max(2, int(w / 0.25))
    for k in range(nst + 1):
        stem(m, (x0 + k * w / nst, y, z0 - 0.02), (x0 + k * w / nst, y, z0 + h + 0.06), 0.022, TWIG, TWIG_DARK, 1, 5)


def acorn_bowl(m, x, y, z, r, fill=None):
    """Acorn-cap bowl: a cupped half-sphere with scaly darker bands."""
    m.sphere(r, pos=(x, y, z + r * 0.55), scl=(1, 1, 0.6), color=ACORN_CAP, seg=10, rings=5,
             colfn=lambda f: ACORN_DARK if int((f.calc_center_median().z - z) * 50) % 2 else ACORN_CAP)
    if fill:
        m.sphere(r * 0.82, pos=(x, y, z + r * 0.95), scl=(1, 1, 0.3), color=fill, seg=8, rings=3)


def grass_pouch(m, x, y, z, s=1.0, rz=0.0):
    """Woven-grass pouch of flour tied with grass twine, flour puffing out of the top."""
    m.sphere(0.2 * s, pos=(x, y, z + 0.17 * s), scl=(1.0, 0.85, 0.95), rot=(0, 0, rz), color=GRASS_WEAVE, seg=9, rings=6,
             colfn=lambda f: GRASS_WEAVE_DARK if int((f.calc_center_median().z - z) * 40 / s) % 2 else GRASS_WEAVE)
    m.cyl(0.07 * s, 0.05 * s, 0.08 * s, pos=(x, y, z + 0.32 * s), color=TIE, seg=6)
    m.sphere(0.07 * s, pos=(x, y, z + 0.41 * s), scl=(1.2, 1.2, 0.6), color=FLOUR, seg=7, rings=3)


def pebble_stack(m, x, y, h):
    """Quern stand: three flat pebbles stacked."""
    z = 0.0
    for k, (r, t) in enumerate(((0.34, h * 0.4), (0.31, h * 0.32), (0.3, h * 0.3))):
        m.sphere(1.0, pos=(x + 0.02 * (k % 2), y, z + t / 2), scl=(r, r * 0.92, t / 2 + 0.012), rot=(0, 0, k * 0.7),
                 color=shade(PEBBLE, 0.9 + 0.06 * k), seg=12, rings=4, lumps=0.05, seed=k + 3)
        z += t


def wheat_sheaf_standing(m, x, y, h=0.55, lean=0.0):
    """Upright sheaf: a bundle of stalks tied in the middle, ears fanned at the top."""
    m.cyl(0.11, 0.09, h * 0.7, pos=(x, y, 0), rot=(lean, 0, 0), color=STRAW_DARK, seg=8, smooth=True)
    m.cyl(0.095, 0.095, 0.04, pos=(x, y + math.sin(lean) * h * 0.3, h * 0.3), color=TIE, seg=8)
    for k in range(7):
        a = k * math.tau / 7
        m.sphere(0.05, pos=(x + math.cos(a) * 0.07, y + math.sin(a) * 0.07 - math.sin(lean) * h * 0.7, h * 0.72 + 0.02 * (k % 2)),
                 scl=(0.8, 0.8, 1.7), rot=(math.sin(a) * 0.4, -math.cos(a) * 0.4, 0), color=STRAW if k % 2 else "CROP_RIPE",
                 seg=6, rings=4)


def build_quern_house():
    m = Model("quern_house", 151)
    W, D, H = 1.25, 1.0, 1.1
    # packed-earth floor laid with flat pebbles
    m.box((W + 0.3, D + 0.3, 0.04), pos=(0, 0, 0), color=mix("PATH", "STONE", 0.25))
    for k in range(9):
        a = k * 2.4
        rr = 0.3 + 0.07 * (k % 4)
        m.sphere(1.0, pos=(math.cos(a) * rr * 1.5, math.sin(a) * rr * 1.1, 0.04), scl=(0.12, 0.09, 0.02),
                 rot=(0, 0, a), color=shade(PEBBLE, 1.0 + 0.05 * (k % 2)), seg=8, rings=3)
    # frame: four hollow reed posts + reed beams, lashed with grass twine at the corners
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            stem(m, (x, y, 0.0), (x, y, H + 0.06), 0.055, nodes=2)
    for y in (-D / 2, D / 2):
        stem(m, (-W / 2 - 0.1, y, H - 0.02), (W / 2 + 0.1, y, H - 0.02), 0.04, nodes=1)
    for x in (-W / 2, W / 2):
        stem(m, (x, -D / 2 - 0.1, H - 0.02), (x, D / 2 + 0.1, H - 0.02), 0.04, nodes=1)
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            lash(m, (x, y, H - 0.02), 0.07)
    # back wall: woven grass screen with a bark-scrap patch
    woven_wall(m, -W / 2, W / 2, D / 2 - 0.02, 0.04, 0.55)
    m.box((0.3, 0.03, 0.22), pos=(0.3, D / 2 - 0.06, 0.2), color=BARK_SCRAP)
    leaf_roof(m, W, D, H, 0.45, n=2, seed=1)
    # quern stand (pebble stack) + lower stone with a spout + acorn-cap bowl
    pebble_stack(m, QX, QY, STAND_H)
    m.cyl(0.3, 0.3, LOW_H, pos=(QX, QY, STAND_H), color=QUERN_DARK, seg=14, smooth=True, cap=QUERN)
    m.box((0.1, 0.16, 0.05), pos=(QX, QY - 0.33, STAND_H + 0.04), color=QUERN_DARK)               # spout
    acorn_bowl(m, QX, QY - 0.52, 0.03, 0.14, FLOUR)
    for (x, y, r) in ((QX - 0.16, QY - 0.38, 0.04), (QX + 0.14, QY - 0.42, 0.035)):               # spilt flour
        m.sphere(r, pos=(x, y, 0.05), scl=(1.4, 1, 0.3), color=FLOUR, seg=6, rings=3)
    # woven-grass flour pouches, wheat sheaves leaning on the right post
    grass_pouch(m, -0.42, -0.18, 0.04, 1.15)
    grass_pouch(m, -0.38, 0.22, 0.04, 0.95, 0.6)
    wheat_sheaf_standing(m, 0.48, -0.2, 0.62, 0.15)
    wheat_sheaf_standing(m, 0.5, 0.18, 0.55, -0.1)
    add_far(m)
    m.export(OUT)


def build_quern_stone():
    """Top stone: centre hole (feed eye), slightly domed, an upright wooden handle peg near the rim."""
    m = Model("quern_stone", 152)
    m.cyl(0.28, 0.26, 0.11, pos=(0, 0, 0), color=QUERN, seg=14, smooth=True, cap=shade(QUERN, 1.06))
    m.cyl(0.07, 0.07, 0.02, pos=(0, 0, 0.105), color=QUERN_DARK, seg=8, cap="WOOD_DARK")         # eye with grain
    m.sphere(0.04, pos=(0, 0, 0.12), scl=(1, 1, 0.4), color="CROP_RIPE", seg=6, rings=3)
    # dressing grooves on the rim (darker notches)
    for k in range(8):
        a = k * math.tau / 8 + 0.2
        m.box((0.04, 0.02, 0.1), pos=(math.cos(a) * 0.27, math.sin(a) * 0.27, 0.005), rot=(0, 0, a), color=QUERN_DARK)
    # handle: upright stick with a rounded grip
    hx, hy = 0.19, 0.0
    stem(m, (hx, hy, 0.08), (hx, hy, 0.4), 0.032, TWIG, TWIG_DARK, 1, 7)          # a straight twig peg
    lash(m, (hx, hy, 0.115), 0.042)
    add_far(m)
    m.export(OUT)


def build_oven():
    m = Model("oven", 161)
    ox, oy = 0.0, 0.05
    PL = 0.32
    # stone plinth (rough stones round the base)
    m.cyl(0.6, 0.62, PL, pos=(ox, oy, 0), color="STONE", seg=10, cap="STONE_DARK",
          colfn=lambda f: "STONE_DARK" if int(f.calc_center_median().z * 14) % 2 else "STONE")
    for k in range(10):
        a = k * math.tau / 10
        x = ox + math.cos(a) * 0.62
        y = oy + math.sin(a) * 0.62
        m.ico(0.07 + 0.015 * (k % 3), pos=(x, y, 0.06 + 0.1 * (k % 2)), scl=(1.3, 1.0, 0.8), color=shade("STONE", 0.92 + 0.08 * (k % 2)),
              subdiv=1, smooth=True)
    # clay dome — lighter on top, darker at the foot, a few patch rings
    def clay(f):
        z = f.calc_center_median().z
        if z < PL + 0.12:
            return CLAY_DARK
        return CLAY_LIGHT if z > PL + 0.48 else CLAY
    m.sphere(0.48, pos=(ox, oy + 0.04, PL + 0.03), scl=(1, 1.05, 0.95), color=CLAY, seg=14, rings=7, colfn=clay, lumps=0.04, seed=7)
    # mouth: arched opening facing front (-Y), dark inside, a clay lip round it, a stone sill
    my = oy + 0.04 - 0.46
    m.cyl(0.22, 0.2, 0.12, pos=(ox, my - 0.04, PL + 0.2), rot=(math.pi / 2, 0, 0), color=CLAY_DARK, seg=12, cap=SOOT)
    m.box((0.46, 0.18, 0.06), pos=(ox, my - 0.1, PL), color="STONE_DARK")
    # chimney at the back top
    m.cyl(0.09, 0.08, 0.32, pos=(ox + 0.12, oy + 0.28, PL + 0.35), color=CLAY_DARK, seg=8, smooth=True, cap=SOOT)
    m.cyl(0.105, 0.105, 0.05, pos=(ox + 0.12, oy + 0.28, PL + 0.64), color=CLAY, seg=8, cap=SOOT)
    smoke(m, ox + 0.12, oy + 0.28, PL + 0.7, 2)
    # peel leaning on the plinth (right side): twig handle lashed to a stiff bark-scrap blade
    stem(m, (ox + 0.66, oy - 0.42, 0.02), (ox + 0.5, oy - 0.2, 0.95), 0.024, TWIG, TWIG_DARK, 2, 5)
    m.box((0.22, 0.03, 0.24), pos=(ox + 0.665, oy - 0.43, 0.0), rot=(0.24, -0.17, 0), color=BARK_SCRAP)
    lash(m, (ox + 0.64, oy - 0.39, 0.22), 0.035)
    # a bundle of dry twigs for the fire, tied with grass, on the left
    for k in range(9):
        a = k * 2.3
        r = 0.09 * math.sqrt(k / 9)
        y0 = oy + math.cos(a) * r * 0.2
        x0 = ox - 0.72 + math.cos(a) * r
        z0 = 0.1 + math.sin(a) * r * 0.8 + 0.02
        stem(m, (x0, y0 - 0.3, z0), (x0 + 0.03 * (k % 3 - 1), y0 + 0.3, z0 + 0.02), 0.024,
             TWIG if k % 2 else TWIG_DARK, TWIG_DARK, 1, 5)
    m.cyl(0.12, 0.12, 0.05, pos=(ox - 0.72, oy - 0.025, 0.12), rot=(math.pi / 2, 0, 0), color=TIE, seg=8)
    # a flat pebble as the bread board, two loaves on it (front-left)
    m.sphere(1.0, pos=(ox - 0.42, oy - 0.68, 0.025), scl=(0.21, 0.14, 0.03), rot=(0, 0, 0.2), color=PEBBLE, seg=10, rings=3)
    for (x, y) in ((-0.5, -0.68), (-0.34, -0.65)):
        m.sphere(0.075, pos=(ox + x, oy + y, 0.09), scl=(1.3, 0.9, 0.7), color="BREAD", seg=8, rings=5)
    add_far(m)
    m.export(OUT)


def build_oven_glow():
    """Fire in the mouth: concentric warm discs, just inside the dark mouth (same origin as oven)."""
    m = Model("oven_glow", 162)
    ox, oy, PL = 0.0, 0.05, 0.32
    my = oy + 0.04 - 0.46
    m.cyl(0.15, 0.15, 0.02, pos=(ox, my - 0.155, PL + 0.19), rot=(math.pi / 2, 0, 0), color="FLAME", seg=10, group="body_nh")
    m.cyl(0.1, 0.1, 0.02, pos=(ox, my - 0.165, PL + 0.17), rot=(math.pi / 2, 0, 0), color="FLAME2", seg=8, group="body_nh")
    for (x, r) in ((-0.07, 0.035), (0.05, 0.03), (0.0, 0.04)):                                  # embers on the floor
        m.sphere(r, pos=(ox + x, my - 0.19, PL + 0.06), scl=(1.2, 1, 0.6), color="FLAME", seg=5, rings=3, group="body_nh")
    add_far(m)
    m.export(OUT)


def build_blueprint_scroll():
    m = Model("blueprint_scroll", 171)
    L, R = 0.9, 0.1
    m.cyl(R, R, L, pos=(-L / 2, 0, R), rot=(0, math.pi / 2, 0), color=PAPER, seg=12, smooth=True, cap=PAPER_EDGE,
          bottom_cap=PAPER_EDGE)
    # spiral hint on the ends + the loose edge of the sheet along the roll
    for sx in (-1, 1):
        m.cyl(R * 0.55, R * 0.55, 0.012, pos=(sx * (L / 2 + 0.0), 0, R), rot=(0, sx * math.pi / 2, 0), color=shade(PAPER_EDGE, 0.85), seg=10)
    m.box((L * 0.98, 0.14, 0.012), pos=(0, -R * 0.9, 0.0), rot=(0.25, 0, 0), color=PAPER)
    # red ribbon round the middle with a bow
    m.cyl(R * 1.08, R * 1.08, 0.06, pos=(-0.03, 0, R), rot=(0, math.pi / 2, 0), color=RIBBON, seg=12, smooth=True)
    for sy in (-1, 1):
        m.sphere(0.055, pos=(0, -R * 0.4 + sy * 0.06, 2 * R + 0.01), scl=(0.6, 1.3, 0.5), rot=(sy * 0.4, 0, 0), color=RIBBON, seg=7, rings=4)
    m.sphere(0.03, pos=(0, -R * 0.4, 2 * R + 0.015), color=shade(RIBBON, 0.85), seg=6, rings=3)
    for sx in (-1, 1):
        m.box((0.035, 0.13, 0.012), pos=(sx * 0.035, -R * 0.4 - 0.1, R * 1.6), rot=(-0.9, 0, sx * 0.35), color=RIBBON)
    add_far(m)
    m.export(OUT)


def build_blueprint_open():
    m = Model("blueprint_open", 172)
    W, Dp = 1.0, 0.7
    m.box((W, Dp, 0.015), pos=(0, 0, 0.0), color=PAPER)
    for sy in (-1, 1):                                       # curled-up ends (top + bottom edge)
        m.cyl(0.05, 0.05, W, pos=(-W / 2, sy * (Dp / 2 + 0.02), 0.05), rot=(0, math.pi / 2, 0), color=PAPER, seg=10,
              smooth=True, cap=PAPER_EDGE, bottom_cap=PAPER_EDGE)
    z = 0.016
    # a little house plan in ink: elevation (gable) on the left, floor plan on the right
    def line(x0, y0, x1, y1, w=0.014):
        dx, dy = x1 - x0, y1 - y0
        ln = math.hypot(dx, dy)
        m.box((ln, w, 0.004), pos=((x0 + x1) / 2, (y0 + y1) / 2, z), rot=(0, 0, math.atan2(dy, dx)), color=INK, group="body_nh")
    x0 = -0.38
    line(x0, -0.2, x0 + 0.3, -0.2)
    line(x0, -0.2, x0, 0.02)
    line(x0 + 0.3, -0.2, x0 + 0.3, 0.02)
    line(x0 - 0.04, 0.02, x0 + 0.15, 0.2)
    line(x0 + 0.34, 0.02, x0 + 0.15, 0.2)
    line(x0 + 0.11, -0.2, x0 + 0.11, -0.07)
    line(x0 + 0.19, -0.2, x0 + 0.19, -0.07)
    line(x0 + 0.11, -0.07, x0 + 0.19, -0.07)
    px = 0.12
    for (a, b, c, d) in ((px, -0.2, px + 0.3, -0.2), (px, 0.15, px + 0.3, 0.15), (px, -0.2, px, 0.15),
                         (px + 0.3, -0.2, px + 0.3, 0.15), (px + 0.15, -0.2, px + 0.15, 0.0)):
        line(a, b, c, d)
    for k in range(4):                                       # dimension ticks
        line(px + k * 0.1, -0.25, px + k * 0.1, -0.23, 0.01)
    line(-0.42, 0.27, -0.1, 0.27, 0.02)                      # title stroke
    m.box((0.05, 0.05, 0.004), pos=(0.36, 0.26, z), rot=(0, 0, 0.785), color=RIBBON, group="body_nh")   # a red seal
    add_far(m)
    m.export(OUT)


# ───────────────────────── pram (carry prop, resident units) ─────────────────────────
# GAME_DESIGN 3.0: woven-grass basket on cut stem-disc wheels, a big curled leaf for the hood, reed/twig frame.
PRAM_BASKET = GRASS_WEAVE
PRAM_BASKET_DARK = GRASS_WEAVE_DARK
PRAM_HOOD = LEAF_A
PRAM_HOOD_DARK = LEAF_B
PRAM_BLANKET = "f1d9c9"    # soft petal-down blanket
STEM_RIND = "7fa65a"       # green rind of a cut stem
STEM_PITH = "eef0c8"       # pale pith of the cut face
STEM_RING = "a9c27a"
PRAM_UNIT = 0.52           # A23: drawn in old resident-model units (adult ~1.9) -> cells; view PRAM_WHEELS = radius x this
WHEEL_R_BACK = 0.17
WHEEL_R_FRONT = 0.13
AXLE_BACK_Y = 0.2
AXLE_FRONT_Y = -0.28
TRACK = 0.27


def wheel(m, r):
    """Cut stem disc in the YZ plane, axle along X, centre at origin: green rind round the edge, pale pith faces,
    a ring of darker vessel dots and a twig hub (the dots show the wheel turning)."""
    m.cyl(r, r, 0.05, pos=(-0.025, 0, 0), rot=(0, math.pi / 2, 0), color=STEM_RIND, seg=12, smooth=True, cap=STEM_PITH,
          bottom_cap=STEM_PITH)
    for sx in (-1, 1):
        for k in range(4):
            a = k * math.tau / 4 + 0.4
            m.box((0.008, r * 0.2, r * 0.18), pos=(sx * 0.026, math.cos(a) * r * 0.62, math.sin(a) * r * 0.62 - r * 0.09),
                  color=STEM_RING)
    m.cyl(r * 0.22, r * 0.22, 0.07, pos=(-0.035, 0, 0), rot=(0, math.pi / 2, 0), color=TWIG_DARK, seg=6)


def pram_body():
    body = Model("pram", 181)
    zb = WHEEL_R_BACK + 0.12                                     # basket bottom
    # frame: two twig side rails, twig struts down to the axles, reed axles
    for sx in (-1, 1):
        x = sx * (TRACK - 0.06)
        stem(body, (x, AXLE_FRONT_Y - 0.06, zb - 0.06), (x, AXLE_BACK_Y + 0.06, zb - 0.06), 0.02, TWIG, TWIG_DARK, 0, 5)
        for ay, r in ((AXLE_BACK_Y, WHEEL_R_BACK), (AXLE_FRONT_Y, WHEEL_R_FRONT)):
            stem(body, (x, ay, r), (x, ay, zb - 0.05), 0.018, TWIG, TWIG_DARK, 0, 4)
    for ay, r in ((AXLE_BACK_Y, WHEEL_R_BACK), (AXLE_FRONT_Y, WHEEL_R_FRONT)):
        body.cyl(0.016, 0.016, 2 * TRACK, pos=(-TRACK, ay, r), rot=(0, math.pi / 2, 0), color=REED_NODE, seg=5)
    # basket: woven-grass tub (alternating bands) with a braided grass rim
    L, Wd, Hb = 0.62, 0.4, 0.26
    body.sphere(1.0, pos=(0, 0, zb + Hb * 0.55), scl=(Wd / 2, L / 2, Hb * 0.62), color=PRAM_BASKET, seg=10, rings=5,
                colfn=lambda f: PRAM_BASKET_DARK if int((f.calc_center_median().z - zb) * 30) % 2 else PRAM_BASKET)
    body.cyl(1.0, 1.0, 0.05, pos=(0, 0, zb + Hb * 0.85), scl=(Wd / 2 + 0.02, L / 2 + 0.02, 1), color=TIE, seg=8, smooth=True,
             cap=PRAM_BLANKET)
    # blanket + baby head peeking out under the hood
    body.sphere(1.0, pos=(0, -0.02, zb + Hb * 0.9), scl=(Wd / 2 - 0.03, L / 2 - 0.08, 0.06), color=PRAM_BLANKET, seg=8, rings=3)
    body.sphere(0.075, pos=(0, -L / 2 + 0.16, zb + Hb * 0.98), color="f0c9a6", seg=7, rings=4)
    body.sphere(0.06, pos=(0, -L / 2 + 0.2, zb + Hb * 1.03), scl=(1.15, 1.0, 0.8), color="f6e6d2", seg=6, rings=3)    # bonnet
    # hood: one big leaf curled over the front half (outside green, paler inside, midrib on top)
    hz = zb + Hb * 0.85
    rings = []
    NB = 7
    for j in range(4):
        y = -L / 2 + 0.04 + j * 0.09
        rr = (Wd / 2 + 0.04) * (0.9 + 0.1 * min(j, 2) / 2)
        hgt = 0.27 * (0.55 + 0.45 * math.sin(min(1.0, (j + 1) / 3) * math.pi / 2))
        rings.append([Vector((math.cos(math.pi * i / (NB - 1)) * rr, y, hz + math.sin(math.pi * i / (NB - 1)) * hgt))
                      for i in range(NB)])
    body.strip(rings[::-1], color=PRAM_HOOD, smooth=True)
    body.strip([list(reversed(r)) for r in rings[::-1]], color=PRAM_HOOD_DARK, smooth=True)
    tip = Vector((0, -L / 2 - 0.05, hz + 0.24))                  # the leaf tip curls forward over the baby
    body.strip([rings[0], [tip.lerp(p, 0.35) for p in rings[0]]], color=PRAM_HOOD)
    for j in range(len(rings) - 1):                              # midrib along the top
        a, b = rings[j][NB // 2], rings[j + 1][NB // 2]
        d = b - a
        body.cyl(0.014, 0.014, d.length, pos=a + Vector((0, 0, 0.005)), rot=d.to_track_quat("Z", "Y").to_euler(),
                 color=LEAF_VEIN, seg=3)
    # handle: two reed stems rising back (+Y) to a lashed reed grip at resident hand height (~0.86)
    hy0, hz0 = L / 2 - 0.04, hz
    hy1, hz1 = L / 2 + 0.3, 0.86
    for sx in (-1, 1):
        stem(body, (sx * 0.15, hy0, hz0), (sx * 0.15, hy1, hz1), 0.02, REED, REED_NODE, 1, 5)
    stem(body, (-0.21, hy1, hz1), (0.21, hy1, hz1), 0.028, REED, REED_NODE, 0, 6)
    return body, zb


def build_pram():
    """Origin = ground under the basket centre. Hood + baby at the front (-Y Blender = +Z Godot), push handle at the
    back (+Y Blender = -Z Godot): the resident walks behind the handle and the pram rolls ahead of them."""
    body, zb = pram_body()
    far = Model("pram__far")
    far.sphere(1.0, pos=(0, 0, zb + 0.12), scl=(0.24, 0.36, 0.22), color=PRAM_BASKET, seg=6, rings=4)
    far.sphere(1.0, pos=(0, -0.15, zb + 0.28), scl=(0.22, 0.16, 0.14), color=PRAM_HOOD, seg=6, rings=3)
    ps = PartSet("pram")
    ps.add("pram", body, pivot=(0, 0, 0))
    ps.add("pram__far", far, pivot=(0, 0, 0))
    for nm, sx, ay, r in (("pram_wheel_fl", 1, AXLE_FRONT_Y, WHEEL_R_FRONT), ("pram_wheel_fr", -1, AXLE_FRONT_Y, WHEEL_R_FRONT),
                          ("pram_wheel_bl", 1, AXLE_BACK_Y, WHEEL_R_BACK), ("pram_wheel_br", -1, AXLE_BACK_Y, WHEEL_R_BACK)):
        w = Model(nm)
        wheel(w, r)
        for bm in w.groups.values():                                   # move to the axle end (pivot below = axle centre)
            for v in bm.verts:
                v.co += Vector((sx * TRACK, ay, r))
        ps.add(nm, w, pivot=(sx * TRACK, ay, r))
    for i, (pn, mdl, pv) in enumerate(ps.parts):           # A23: old resident-model units -> cells (1 = adult height)
        for bm in mdl.groups.values():
            for v in bm.verts:
                v.co *= PRAM_UNIT
        ps.parts[i] = (pn, mdl, pv * PRAM_UNIT)
    tris = ps.export(os.path.join(OUT, "carry"))
    print("  pram parts", tris)


if __name__ == "__main__":
    print("pioneer ->", OUT)
    if "--pram-only" not in sys.argv:
        build_quern_house()
        build_quern_stone()
        build_oven()
        build_oven_glow()
        build_blueprint_scroll()
        build_blueprint_open()
    build_pram()
