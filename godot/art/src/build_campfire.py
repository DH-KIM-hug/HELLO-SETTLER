"""Village campfire (모닥불) — stone ring + a teepee of dry twigs + ash bed, extra festival twigs, reed-bundle seats.
Tiny-folk materials (GAME_DESIGN 3.0, E3-5): no logs — straight dry twigs and grass stalks, charred at the tips.
The flame / embers / smoke / glow are NOT modelled here — view/campfire.gd draws them (shader cards + particles).
Units: adult resident ~1.9 tall. Ring radius ~0.62 (residents sit 1.0-2.5 from the fire centre — ResidentAI.near).
  campfire        ring of 9 stones, ash bed with coals, a teepee of 8 forked twigs with charred tips + 2 tied kindling bundles
  campfire_extra  4 more leaning twigs and a dry stalk (big festival fire)
  campfire_seat   one bench: a tied reed bundle on two pebbles with a dry leaf laid on top (view places 3 around the fire)
Run: blender -b --factory-startup --python build_campfire.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, out_dir_from_argv  # noqa: E402
from flora_kit import leaf  # noqa: E402
from tiny_kit import reed_bundle, pebble, twig, PEBBLE, PEBBLE_DARK, REED, REED_NODE, LEAF_DRY, LEAF_DRY_B, TWIG_PALE  # noqa: E402

OUT = out_dir_from_argv()
ASH = "9a938a"
ASH_DARK = "5c544e"
CHAR = "3b302b"
COAL = "c8572e"
BARK = "8a6b52"           # dry twig
BARK_DARK = "6b5240"
CUT = TWIG_PALE


def bark_log(m, a, b, r, char_from=None, seg=7, group="body"):
    """Round log from point a to point b (bark sides, pale cut ends). char_from = 0..1 along the log where
    the bark turns to charcoal (towards b)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    ln = d.length
    rot = d.to_track_quat("Z", "Y").to_euler()
    if char_from is None:
        m.cyl(r, r * 0.92, ln, pos=a, rot=rot, color=BARK, seg=seg, smooth=True, cap=CUT, bottom_cap=CUT, group=group)
        return
    l1 = ln * char_from
    m.cyl(r, r * 0.95, l1, pos=a, rot=rot, color=BARK, seg=seg, smooth=True, bottom_cap=CUT, group=group)
    m.cyl(r * 0.95, r * 0.55, ln - l1, pos=a + d.normalized() * l1, rot=rot, color=CHAR, seg=seg, smooth=True,
          cap=shade(CHAR, 0.8), group=group)
    # a bark ring / knot so it does not read as a plain tube
    m.cyl(r * 1.04, r * 1.04, 0.03, pos=a + d.normalized() * l1 * 0.45, rot=rot, color=BARK_DARK, seg=seg, group=group)


def build_campfire():
    m = Model("campfire", 31)

    # ash bed: soft grey mound, darker in the middle, a few glowing coals (colour only — no emission)
    def ash_col(f):
        c = f.calc_center_median()
        r = math.hypot(c.x, c.y)
        return mix(ASH_DARK, ASH, min(1.0, r / 0.5))
    m.sphere(0.56, pos=(0, 0, -0.03), scl=(1, 1, 0.13), color=ASH, seg=14, rings=5, colfn=ash_col, lumps=0.12,
             seed=3, group="body_nl")
    for i, (x, y, r) in enumerate(((0.12, 0.05, 0.07), (-0.1, 0.12, 0.06), (0.02, -0.14, 0.065), (-0.16, -0.06, 0.05),
                                   (0.2, -0.12, 0.045))):
        m.ico(r, pos=(x, y, 0.045), scl=(1.2, 1, 0.7), color=COAL if i % 2 == 0 else CHAR, subdiv=1, smooth=False,
              group="body_nl")

    # stone ring: 9 rounded stones, varied size, some moss on top
    def mossy(f):
        return "MOSS" if f.normal.z > 0.82 else ("ROCK" if f.normal.z > -0.1 else "ROCK_DARK")
    n = 9
    for i in range(n):
        a = i * math.tau / n + 0.17
        k = 0.85 + 0.3 * ((i * 7) % 5) / 4.0
        rr = 0.64 + 0.03 * ((i * 3) % 3)
        m.ico(0.15 * k, pos=(math.cos(a) * rr, math.sin(a) * rr, 0.07 * k), scl=(1.25, 1.0, 0.85),
              rot=(0, 0, a + 0.4), color="ROCK", subdiv=2, colfn=mossy, lumps=0.16, seed=10 + i, smooth=True)

    # teepee: 8 dry twigs (some forked) leaning into a point above the centre, charred towards the top
    apex = Vector((0.0, 0.0, 0.46))
    for i in range(8):
        a = i * math.tau / 8 + 0.3
        rr = 0.42 + 0.04 * (i % 3)
        base = Vector((math.cos(a) * rr, math.sin(a) * rr, 0.03))
        tip = apex + (apex - base).normalized() * (0.05 + 0.03 * (i % 2)) + Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, 0))
        bark_log(m, base, tip, 0.034 - 0.006 * (i % 2), char_from=0.68, seg=5)
        if i % 3 == 0:                                   # a side shoot
            p = base.lerp(tip, 0.4)
            q = p + Vector((math.cos(a + 1.2) * 0.12, math.sin(a + 1.2) * 0.12, 0.08))
            bark_log(m, p, q, 0.016, seg=4)
    # two tied kindling bundles of thin dry stalks across the base
    for (a, r) in ((0.5, 0.07), (-0.65, 0.065)):
        h = 0.4
        p0 = Vector((-math.cos(a) * h, -math.sin(a) * h, r))
        p1 = Vector((math.cos(a) * h, math.sin(a) * h, r))
        reed_bundle(m, p0, p0.lerp(p1, 0.38), r, "b39a72", "8f7a48", ties=1, n=5)
        reed_bundle(m, p1, p1.lerp(p0, 0.38), r, CHAR, CHAR, ties=0, n=4)
        m.sphere(r * 1.0, pos=(p0 + p1) / 2, scl=(1, 1, 0.9), color=CHAR, seg=7, rings=4)
    # a couple of loose twigs
    for (x, y, a) in ((0.32, -0.32, 0.9), (-0.36, 0.22, 2.4)):
        bark_log(m, (x, y, 0.03), (x + math.cos(a) * 0.3, y + math.sin(a) * 0.3, 0.05), 0.02, seg=4)
    m.export(OUT)


def build_extra():
    m = Model("campfire_extra", 32)
    apex = Vector((0.0, 0.0, 0.62))
    for i in range(5):
        a = i * math.tau / 5 + 1.0
        base = Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, 0.04))
        bark_log(m, base, apex + (apex - base).normalized() * 0.05, 0.036, char_from=0.62, seg=5)
    m.export(OUT)


def build_seat():
    """Bench: a fat tied reed bundle resting on two pebbles, a dry leaf laid on top to sit on."""
    m = Model("campfire_seat", 33)
    L, h = 1.0, 0.18
    for x in (-0.32, 0.32):
        pebble(m, x, 0, 0.07, 0.1, 0.1, 0.08, shade(PEBBLE, 0.95 if x < 0 else 1.02), x, 3)
    reed_bundle(m, (-L / 2, 0, h), (L / 2, 0, h), 0.1, REED, REED_NODE, ties=2, n=5, seg=5)
    pts = [Vector((-0.42 + 0.21 * k, 0.0, h + 0.1 + 0.015 * math.sin(k))) for k in range(5)]
    leaf(m, pts, [0.03, 0.12, 0.14, 0.11, 0.02], Vector((0, 0, 1)), thick=0.02, color=LEAF_DRY, color_under=LEAF_DRY_B,
         group="body")
    m.export(OUT)


build_campfire()
build_extra()
build_seat()
