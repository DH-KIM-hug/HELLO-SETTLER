"""Village campfire (모닥불) — stone ring + teepee logs + ash bed, extra festival logs, log seats.
Storybook low-poly kit (same as build_nature.py: rounded lumpy stones, bark logs with pale cut ends).
The flame / embers / smoke / glow are NOT modelled here — view/campfire.gd draws them (shader cards + particles).
Units: adult resident ~1.9 tall. Ring radius ~0.62 (residents sit 1.0-2.5 from the fire centre — ResidentAI.near).
  campfire        ring of 9 stones, ash bed with coals, 5-log teepee with charred tips + 2 base logs
  campfire_extra  3 more leaning logs (big festival fire)
  campfire_seat   one split-log bench (view places 3 around the fire, ~1.8 out)
Run: blender -b --factory-startup --python build_campfire.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, out_dir_from_argv  # noqa: E402

OUT = out_dir_from_argv()
ASH = "9a938a"
ASH_DARK = "5c544e"
CHAR = "3b302b"
COAL = "c8572e"
BARK = "TRUNK"
BARK_DARK = "TRUNK_DARK"
CUT = "STUMP_TOP"


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

    # teepee: 5 logs leaning into a point above the centre, charred towards the top
    apex = Vector((0.0, 0.0, 0.44))
    for i in range(5):
        a = i * math.tau / 5 + 0.3
        base = Vector((math.cos(a) * 0.42, math.sin(a) * 0.42, 0.04))
        tip = apex + (apex - base).normalized() * 0.06 + Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, 0))
        bark_log(m, base, tip, 0.06 - 0.006 * (i % 2), char_from=0.7)
    # two thicker crossed logs at the base
    for (a, r) in ((0.5, 0.075), (-0.65, 0.07)):
        h = 0.42
        p0 = Vector((-math.cos(a) * h, -math.sin(a) * h, r * 0.9))
        p1 = Vector((math.cos(a) * h, math.sin(a) * h, r * 0.9))
        mid = (p0 + p1) / 2
        bark_log(m, p0, mid + (p0 - mid) * 0.15, r)       # outer half: bark
        bark_log(m, p1, mid + (p1 - mid) * 0.15, r, char_from=0.45)
        m.sphere(r * 1.0, pos=mid, scl=(1, 1, 0.9), color=CHAR, seg=7, rings=4)
    # a couple of kindling sticks
    for (x, y, a) in ((0.32, -0.32, 0.9), (-0.36, 0.22, 2.4)):
        bark_log(m, (x, y, 0.03), (x + math.cos(a) * 0.3, y + math.sin(a) * 0.3, 0.05), 0.022, seg=5)
    m.export(OUT)


def build_extra():
    m = Model("campfire_extra", 32)
    apex = Vector((0.0, 0.0, 0.6))
    for i in range(3):
        a = i * math.tau / 3 + 1.0
        base = Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, 0.05))
        bark_log(m, base, apex + (apex - base).normalized() * 0.05, 0.065, char_from=0.6)
    m.export(OUT)


def build_seat():
    """Split log bench: half-round log on two little chocks, flat pale top, bark underneath."""
    m = Model("campfire_seat", 33)
    L, r = 1.05, 0.15
    pts = [(r * math.cos(k * math.pi / 6), -r * 0.9 * math.sin(k * math.pi / 6)) for k in range(7)]   # flat top, bark dome below
    h = 0.27
    m.prism(pts, L, pos=(0, 0, h), color=BARK, cap_color=CUT, smooth=False)
    # flat sitting top (pale wood)
    m.box((L, 2 * r * 0.96, 0.02), pos=(0, 0, h - 0.005), color=shade(CUT, 0.95))
    m.box((L * 0.98, 0.012, 0.022), pos=(0, 0.03, h), color=shade(CUT, 0.8))          # grain line
    for x in (-L * 0.32, L * 0.32):
        m.cyl(0.1, 0.11, h - 0.1, pos=(x, 0, 0), color=BARK_DARK, seg=7, smooth=True, cap=CUT)
    m.sphere(0.06, pos=(L * 0.42, -0.08, h - 0.02), scl=(1.4, 1, 0.5), color="MOSS", seg=6, rings=3)
    m.export(OUT)


build_campfire()
build_extra()
build_seat()
