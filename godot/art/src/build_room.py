"""The giant's room (docs/GIANT_ROOM.md 1, UI.md '00 시작 흐름'): windowsill shelf, glass jar + cork, soil plug inside the
jar, oil lamp (+ its glass chimney), window frame, curtain, flowerpot with moss and a dandelion, watering can, tweezers,
sugar bowl. -> godot/art/models/room/*.glb (not wired into the title - see tools/preview_room.gd).

Scale: 1 unit = 1 giant centimetre. Shelf top = z 0. The jar stands at the origin.
  jar: outer radius 6.0, height 13.0 (body) + neck to 15.2; inner radius 5.6 -> a village SubViewport quad / the
  soil plug (jar_soil: top surface at z 3.2, radius 5.55) sits inside. Glass and cork are separate meshes so the
  glass can get its own see-through material in Godot (the toon material is opaque).
Colours: warm wood / cream / peach (icon L_2 mood).
Front = -Y (towards the camera).
Run: blender -b --factory-startup --python build_room.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, out_dir_from_argv  # noqa: E402
import bmesh  # noqa: E402

OUT = os.path.join(out_dir_from_argv(), "room")
os.makedirs(OUT, exist_ok=True)

OAK = "c98f5a"
OAK_DARK = "a06a3e"
OAK_LIGHT = "dfae74"
CREAM = "f3e6cc"
PEACH = "f2b99a"
CORK = "c99a62"
CORK_DARK = "a87a48"
BRASS = "d9a648"
BRASS_DARK = "a87a2c"
TERRACOTTA = "d27b55"
GLASS = "dff1f0"
FLAME = "ffcf6a"
CURTAIN = "f0a98a"
CAN = "7fb2a8"

JAR_R = 6.0
JAR_H = 13.0
JAR_IN = 5.6
SOIL_TOP = 3.2


def lathe(m, prof, seg, color, group="body", smooth=True, colfn=None, flip=False, pos=(0, 0, 0)):
    rings = [[Vector((pos[0] + math.cos(i * math.tau / seg) * r, pos[1] + math.sin(i * math.tau / seg) * r, pos[2] + z))
              for i in range(seg)] for (r, z) in prof]
    fs = m.strip(rings, color=color, group=group, smooth=smooth, close=True)
    bm = m._bm(group)
    for f in fs:
        f.normal_update()
        c = f.calc_center_median()
        out = Vector((c.x - pos[0], c.y - pos[1], 0))
        if out.length > 1e-6 and (out.dot(f.normal) < 0) != flip:
            f.normal_flip()
    bm.normal_update()
    if colfn:
        for f in fs:
            m._finish(bm, [f], colfn(f), smooth)
    return fs


def disc(m, r, z, seg, color, up=True, group="body", pos=(0, 0)):
    bm = m._bm(group)
    vs = [bm.verts.new((pos[0] + math.cos(i * math.tau / seg) * r, pos[1] + math.sin(i * math.tau / seg) * r, z))
          for i in range(seg)]
    f = bm.faces.new(vs if up else list(reversed(vs)))
    f.normal_update()
    if (f.normal.z > 0) != up:
        f.normal_flip()
    m._finish(bm, [f], color, False)
    return f


# ───────────── shelf + window ─────────────
def build_shelf():
    """Windowsill shelf: one thick oak plank with a rounded front nose, grain streaks, two brackets below."""
    m = Model("shelf", 601)
    L, D, T = 60.0, 18.0, 2.2
    n = 16
    for k in range(n):               # plank cut into long boards -> grain streaks along X
        y = -D / 2 + (k + 0.5) * D / n
        c = shade(OAK, (1.0, 0.95, 1.04, 0.98, 1.06, 0.93)[(k * 7) % 6])
        m.box((L, D / n + 0.002, T), pos=(0, y, -T), color=c,
              colfn=lambda f, c=c: c if f.normal.z > 0.5 else shade(OAK, 0.8))
    m.cyl(T / 2, T / 2, L, pos=(-L / 2, -D / 2, -T / 2), rot=(0, math.pi / 2, 0), color=OAK_LIGHT, seg=10, smooth=True,
          cap=shade(OAK, 0.85), bottom_cap=shade(OAK, 0.85))
    for x in (-22, 22):
        m.box((1.6, D * 0.8, 6.0), pos=(x, 0, -T - 6.0), color=OAK_DARK)
        m.prism([(-D * 0.35, 0.0), (D * 0.4, 0.0), (D * 0.4, -5.5)], 1.4, pos=(x, 0, -T), color=OAK_DARK)
    # back wall strip and window ledge behind the shelf
    m.box((L, 1.0, 40.0), pos=(0, D / 2 + 0.5, -10.0), color="e9dcc4",
          colfn=lambda f: "e9dcc4" if f.normal.y < -0.5 else shade("e9dcc4", 0.9))
    m.export(OUT)


def build_window():
    """Window frame on the wall behind the shelf (upper left): four panes, cross mullions, a deep sill."""
    m = Model("window_frame", 602)
    W, H, F = 26.0, 30.0, 1.6
    y = 8.0
    for x in (-W / 2, W / 2):
        m.box((F, 2.0, H), pos=(x, y, 0), color=CREAM)
    for z in (0, H - F):
        m.box((W + F, 2.0, F), pos=(0, y, z), color=CREAM)
    m.box((F * 0.6, 1.4, H), pos=(0, y + 0.2, 0), color=CREAM)
    m.box((W, 1.4, F * 0.6), pos=(0, y + 0.2, H * 0.55), color=CREAM)
    m.box((W + 4, 4.0, 1.2), pos=(0, y - 1.2, -1.2), color=shade(CREAM, 0.95))     # sill
    # the view outside: one sky panel behind the panes (the title can tint it by time of day) + a far tree line
    m.box((W, 0.3, H), pos=(0, y + 0.6, 0), color="bfe6f0", group="body_nl", colfn=lambda f: "bfe6f0")
    for k in range(6):
        m.sphere(3.2, pos=(-W / 2 + 2 + k * 4.6, y + 0.4, 2.0 + 1.2 * (k % 2)), scl=(1, 0.2, 0.8),
                 color=("a8d49a", "93c78a")[k % 2], seg=10, rings=4, group="body_nl")
    m.export(OUT)


def build_curtain():
    """Peach curtain: a gathered cloth panel (wavy folds) tied back with a band."""
    m = Model("curtain", 603)
    H = 34.0
    K, J = 14, 10
    rings = []
    for j in range(J + 1):
        t = j / J
        z = H * (1 - t)
        pinch = 1.0 - 0.55 * math.exp(-((t - 0.62) ** 2) / 0.02)        # tie-back
        flare = 1.0 + 0.25 * max(0.0, t - 0.62) * 2.5
        ring = []
        for k in range(K + 1):
            u = k / K
            x = u * 7.0 * pinch * flare
            y = 0.7 * math.sin(u * math.pi * 6) * (0.6 + 0.4 * t)
            ring.append(Vector((x, y, z)))
        rings.append(ring)
    fs = m.strip(rings, color=CURTAIN, smooth=True)
    back = m.strip([[Vector((p.x, p.y + 0.15, p.z)) for p in r] for r in rings], color=shade(CURTAIN, 0.8))
    bm = m._bm("body")
    for f in fs:
        f.normal_update()
        if f.normal.y > 0:
            f.normal_flip()
    for f in back:
        f.normal_update()
        if f.normal.y < 0:
            f.normal_flip()
    bm.normal_update()
    for i, f in enumerate(fs):
        c = f.calc_center_median()
        m._finish(bm, [f], shade(CURTAIN, 0.9) if f.normal.x > 0.35 else CURTAIN, True)
    m.box((3.6, 1.6, 1.0), pos=(1.6, -0.3, H * (1 - 0.62) - 0.5), color="e9d6b8")          # tie band
    m.cyl(0.4, 0.4, 40.0, pos=(-6, 0.5, H + 0.6), rot=(0, math.pi / 2, 0), color=OAK_DARK, seg=8)   # rod
    m.sphere(0.9, pos=(-6.5, 0.5, H + 0.6), color=BRASS, seg=8, rings=4)
    m.export(OUT)


# ───────────── jar ─────────────
JAR_PROF = [(0.0001, 0.0), (4.6, 0.0), (5.6, 0.25), (5.95, 0.9), (JAR_R, 2.0), (JAR_R, JAR_H - 2.6), (5.7, JAR_H - 1.2),
            (4.9, JAR_H - 0.3), (4.5, JAR_H + 0.4), (4.55, JAR_H + 1.6), (4.85, JAR_H + 1.9), (4.85, JAR_H + 2.2)]


def build_jar():
    """Glass jar: outer + inner shell (glass thickness 0.4) and a rolled lip. One colour + white highlight streaks;
    in Godot give it a see-through material (tools/preview_room.gd does)."""
    m = Model("jar_glass", 611)
    seg = 40

    def hl(f):
        c = f.calc_center_median()
        a = math.atan2(c.y, c.x)
        if abs(((a + 2.2) % math.tau) - math.pi) < 0.12 and 2.5 < c.z < JAR_H - 2:
            return "ffffff"                # long highlight stripe (front left)
        if abs(((a + 1.75) % math.tau) - math.pi) < 0.05 and 3.5 < c.z < JAR_H - 4:
            return "ffffff"
        return GLASS
    lathe(m, JAR_PROF[1:], seg, GLASS, colfn=hl, group="body_nl")
    inner = [(max(0.0001, r - 0.4), z + (0.4 if i == 0 else 0)) for i, (r, z) in enumerate(JAR_PROF[1:-2])]
    lathe(m, inner, seg, shade(GLASS, 0.92), flip=True, group="body_nl")
    # lip top ring between outer and inner
    rings = [[Vector((math.cos(i * math.tau / seg) * r, math.sin(i * math.tau / seg) * r, z)) for i in range(seg)]
             for (r, z) in ((JAR_PROF[-1][0], JAR_PROF[-1][1]), (inner[-1][0], JAR_PROF[-1][1]))]
    fs = m.strip(rings, color=GLASS, close=True, group="body_nl")
    for f in fs:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    disc(m, 4.6, 0.0, seg, shade(GLASS, 0.9), up=False, group="body_nl")
    disc(m, inner[0][0], 0.4, seg, shade(GLASS, 0.9), up=True, group="body_nl")
    m.export(OUT)


def build_cork():
    m = Model("jar_cork", 612)
    seg = 28
    z0 = JAR_H + 0.4
    rng = m.rng

    def speck(f):
        return CORK
    lathe(m, [(4.05, z0), (4.15, z0 + 1.8), (4.75, z0 + 1.9), (5.1, z0 + 2.4), (5.15, z0 + 3.6), (4.95, z0 + 4.0)],
          seg, CORK, colfn=speck)
    disc(m, 4.95, z0 + 4.0, seg, shade(CORK, 1.05), up=True)
    for k in range(22):        # pores on the side
        a = rng.uniform(-2.6, -0.5)
        z = rng.uniform(z0 + 2.6, z0 + 3.8)
        m.sphere(rng.uniform(0.1, 0.2), pos=(math.cos(a) * 5.13, math.sin(a) * 5.13, z), scl=(1, 1, 0.7), color=CORK_DARK,
                 seg=5, rings=2, group="body_nl")
    disc(m, 4.05, z0, seg, CORK_DARK, up=False)
    for k in range(14):        # pores on the top
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.5, 4.2)
        m.cyl(rng.uniform(0.12, 0.3), 0.1, 0.06, pos=(math.cos(a) * d, math.sin(a) * d, z0 + 4.0), color=CORK_DARK, seg=6)
    m.export(OUT)


def build_soil():
    """Soil plug inside the jar: layered cross-section seen through the glass (topsoil, earth, rock, a vein, core
    pebbles) and a grassy top at SOIL_TOP. The village SubViewport quad goes on top of it."""
    m = Model("jar_soil", 613)
    seg = 40
    R = JAR_IN - 0.05
    layers = [(0.4, 1.0, "6f5a4a"), (1.0, 1.9, "8a6a4a"), (1.9, 2.7, "a07c56"), (2.7, SOIL_TOP - 0.25, "8a6a4a"),
              (SOIL_TOP - 0.25, SOIL_TOP, "8fc46c")]
    for (z0, z1, c) in layers:
        lathe(m, [(R, z0), (R, z1)], seg, c, smooth=True)
    disc(m, R, SOIL_TOP, seg, "b9d687", up=True)
    rng = m.rng
    for k in range(18):           # pebbles / ore bits pressed against the glass
        a = rng.uniform(0, math.tau)
        z = rng.uniform(0.6, 2.6)
        m.ico(rng.uniform(0.15, 0.32), pos=(math.cos(a) * (R - 0.05), math.sin(a) * (R - 0.05), z),
              color=rng.choice(("9aa9a6", "7d8d8c", "e3b23c", "2f3033", "f4f2ea")), subdiv=1)
    m.export(OUT)


# ───────────── props ─────────────
def build_lamp():
    """Brass oil lamp: round foot, oil font, burner collar, glass chimney (separate mesh), small flame."""
    m = Model("oil_lamp", 621)
    seg = 24
    lathe(m, [(3.0, 0.0), (3.0, 0.4), (2.5, 0.7), (0.9, 1.2), (0.8, 2.4), (2.6, 3.2), (3.2, 4.6), (2.9, 5.8), (1.6, 6.5),
              (1.2, 6.6)], seg, BRASS, colfn=lambda f: BRASS_DARK if f.normal.z < -0.3 else
              (shade(BRASS, 1.12) if f.calc_center_median().z > 3.0 and f.normal.y < -0.6 else BRASS))
    lathe(m, [(1.6, 6.5), (1.8, 7.2), (1.75, 7.6)], seg, BRASS_DARK)
    disc(m, 1.75, 7.6, seg, BRASS_DARK)
    m.box((0.6, 0.2, 0.5), pos=(1.9, 0, 6.9), color=BRASS)      # wick knob
    m.cyl(0.3, 0.3, 1.0, pos=(2.2, 0, 7.15), rot=(0, math.pi / 2, 0), color=BRASS_DARK, seg=8)
    # loop handle
    for k in range(8):
        a0 = k / 8 * math.pi
        a1 = (k + 1) / 8 * math.pi
        p0 = Vector((-3.0 - 1.6 * math.sin(a0), 0, 3.2 + 1.6 * math.cos(a0) - 1.6 + 1.6))
        p1 = Vector((-3.0 - 1.6 * math.sin(a1), 0, 3.2 + 1.6 * math.cos(a1) - 1.6 + 1.6))
        v = p1 - p0
        m.cyl(0.32, 0.32, v.length, pos=p0, rot=tuple(v.to_track_quat("Z", "Y").to_euler()), color=BRASS, seg=6, smooth=True)
    m.sphere(0.55, pos=(0, 0, 8.4), scl=(1, 1, 1.9), color=FLAME, seg=8, rings=5, group="body_nl")
    m.sphere(0.28, pos=(0, -0.1, 8.2), scl=(1, 1, 1.6), color="fff4c2", seg=6, rings=4, group="body_nl")
    m.export(OUT)
    g = Model("oil_lamp_glass", 622)
    lathe(g, [(1.55, 7.6), (2.3, 8.6), (2.4, 9.8), (1.5, 11.6), (1.25, 13.6), (1.35, 13.9)], seg, GLASS, group="body_nl",
          colfn=lambda f: "ffffff" if abs(((math.atan2(f.calc_center_median().y, f.calc_center_median().x) + 2.2)
                                              % math.tau) - math.pi) < 0.15 else GLASS)
    g.export(OUT)


def build_flowerpot():
    """Terracotta pot (where the creation soil came from): moss mounds and a dandelion - one flower, one seed puff."""
    m = Model("flowerpot", 631)
    seg = 24
    lathe(m, [(3.0, 0.0), (3.6, 4.6), (4.2, 4.7), (4.25, 5.8), (3.85, 5.9)], seg, TERRACOTTA,
          colfn=lambda f: shade(TERRACOTTA, 1.08) if f.calc_center_median().z > 4.6 else TERRACOTTA)
    disc(m, 3.0, 0.0, seg, shade(TERRACOTTA, 0.8), up=False)
    disc(m, 3.85, 5.5, seg, "6f5a4a")
    rng = m.rng
    for k in range(9):
        a = k * 2.39996
        d = rng.uniform(0.3, 3.0)
        m.ico(rng.uniform(0.7, 1.2), pos=(math.cos(a) * d, math.sin(a) * d, 5.55), scl=(1, 1, 0.55),
              color=("8fc46c", "7cb860", "a4d07a")[k % 3], subdiv=2, smooth=True, lumps=0.15, group="body_nl")
    # dandelion: leaves, two stems, a flower and a puff (giant room scale - small)
    for k in range(5):
        a = k * math.tau / 5 + 0.3
        m.blade((0, 0, 5.9), (math.cos(a) * 3.2, math.sin(a) * 3.2, 6.6), 1.0, color="5f9a3a" if k % 2 else "4a7d2c",
                group="body_nh", bend=(0, 0, 0.5))
    for (dx, h, head) in ((-0.6, 9.0, "flower"), (0.9, 11.0, "puff")):
        top = Vector((dx * 1.6, 0.2, 5.8 + h))
        m.cyl(0.16, 0.12, h, pos=(dx * 0.3, 0, 5.8), rot=(0, math.atan2(dx * 1.3, h), 0), color="8fbf55", seg=6, smooth=True)
        if head == "flower":
            m.sphere(1.1, pos=top, scl=(1, 1, 0.4), rot=(0.5, 0, 0), color="e09a16", seg=12, rings=4)
            for ring, (n, rr, up) in enumerate(((18, 1.55, 0.15), (14, 1.1, 0.5), (9, 0.6, 0.9))):
                for i in range(n):
                    a = (i + 0.5 * ring) * math.tau / n
                    lp = Vector((math.cos(a) * rr, math.sin(a) * rr, 0.25 * ring))
                    lp = Vector((lp.x, lp.y * math.cos(0.5) - lp.z * math.sin(0.5), lp.y * math.sin(0.5) + lp.z * math.cos(0.5)))
                    m.sphere(0.5, pos=top + lp, scl=(1.5 - 0.3 * ring, 0.55, 0.22), rot=(0.5, -up, a),
                             color=("f6c624", "ffd84a", "f2b818")[(i + ring) % 3], seg=6, rings=3, group="body_nl")
        else:
            m.ico(2.0, pos=top, color="f7f5ee", subdiv=3, smooth=True, lumps=0.1, group="body_nl")
            for i in range(14):
                yy = 1.0 - (i + 0.5) / 14 * 1.6
                rr = math.sqrt(max(0.0, 1 - yy * yy))
                a = i * 2.39996
                d = Vector((math.cos(a) * rr, math.sin(a) * rr, yy))
                m.ico(0.6, pos=top + d * 1.85, color="ffffff", subdiv=2, smooth=True, lumps=0.15, group="body_nl")
    m.export(OUT)


def build_watering_can():
    m = Model("watering_can", 641)
    seg = 20
    lathe(m, [(3.2, 0.0), (3.3, 0.3), (3.3, 5.6), (2.9, 6.4), (1.6, 6.8)], seg, CAN,
          colfn=lambda f: shade(CAN, 0.85) if f.calc_center_median().z < 0.5 else
          (shade(CAN, 1.1) if 2.4 < f.calc_center_median().z < 3.0 else CAN))
    disc(m, 3.2, 0.0, seg, shade(CAN, 0.7), up=False)
    disc(m, 1.6, 6.8, seg, shade(CAN, 0.6))
    # spout
    p0, p1 = Vector((2.4, -1.0, 1.4)), Vector((8.0, -2.6, 7.2))
    v = p1 - p0
    m.cyl(0.75, 0.35, v.length, pos=p0, rot=tuple(v.to_track_quat("Z", "Y").to_euler()), color=CAN, seg=10, smooth=True)
    m.cyl(0.9, 0.95, 0.5, pos=p1, rot=tuple(v.to_track_quat("Z", "Y").to_euler()), color=BRASS, seg=10,
          cap=shade(BRASS, 0.8))
    # arched handle over the top
    for k in range(10):
        a0, a1 = k / 10 * math.pi, (k + 1) / 10 * math.pi
        q0 = Vector((-2.6 * math.cos(a0) - 0.4, 0.8, 6.0 + 3.0 * math.sin(a0)))
        q1 = Vector((-2.6 * math.cos(a1) - 0.4, 0.8, 6.0 + 3.0 * math.sin(a1)))
        d = q1 - q0
        m.cyl(0.38, 0.38, d.length, pos=q0, rot=tuple(d.to_track_quat("Z", "Y").to_euler()), color=shade(CAN, 0.92),
              seg=6, smooth=True)
    m.export(OUT)


def build_tweezers():
    m = Model("tweezers", 651)
    L = 12.0
    for side in (-1, 1):
        p0 = Vector((0, 0, 0.25))
        p1 = Vector((L, side * 0.9, 0.25))
        d = p1 - p0
        m.box((d.length, 0.55, 0.22), pos=(L / 2, side * 0.45, 0.14), rot=(0, 0, math.atan2(d.y, d.x)), color="c9d1d3",
              colfn=lambda f: "e9eff0" if f.normal.z > 0.6 else "a9b3b6")
        m.box((1.0, 0.6, 0.24), pos=(L - 0.3, side * 0.9, 0.12), rot=(0, 0, 0), color="a9b3b6")
        for k in range(3):        # grip ridges
            m.box((0.12, 0.6, 0.08), pos=(3.0 + k * 0.4, side * (0.22 + 0.075 * (3.0 + k * 0.4)), 0.36), color="a9b3b6")
    m.cyl(0.55, 0.55, 0.5, pos=(0, 0, 0.0), color="c9d1d3", seg=10)
    m.export(OUT)


def build_sugar_bowl():
    m = Model("sugar_bowl", 661)
    seg = 24
    lathe(m, [(1.8, 0.0), (2.0, 0.4), (3.6, 2.2), (3.8, 3.2), (3.5, 3.25)], seg, CREAM,
          colfn=lambda f: PEACH if 1.3 < f.calc_center_median().z < 1.9 else CREAM)
    disc(m, 1.8, 0.0, seg, shade(CREAM, 0.8), up=False)
    disc(m, 3.5, 2.6, seg, shade(CREAM, 0.85))
    for (x, y, z, r) in ((-1.0, 0.3, 2.6, 0.2), (0.6, -0.4, 2.6, -0.3), (0.2, 0.9, 3.1, 0.5), (-0.4, -0.6, 3.3, 0.9)):
        m.box((1.2, 1.2, 1.15), pos=(x, y, z), rot=(0.1, 0.05, r), color="fbfaf4",
              colfn=lambda f: "ffffff" if f.normal.z > 0.6 else "e8ecea")
    m.export(OUT)


if __name__ == "__main__":
    print("room ->", OUT)
    build_shelf()
    build_window()
    build_curtain()
    build_jar()
    build_cork()
    build_soil()
    build_lamp()
    build_flowerpot()
    build_watering_can()
    build_tweezers()
    build_sugar_bowl()
