"""Small-world crisis creatures (WORLD_EVENTS 2.2 - ROADMAP B5): flying gnat, wandering water drop, dust bunny.
They come from the giant's world at REAL size, so they are big next to residents (a gnat is house-sized).
Same cel look as the mold blobs (build_mold.py): soft round shapes, vertex colours, dot eyes only -
no big white eyes, no stick limbs. Cute, not gross.
  gnat_body  : fuzzy round body + head with dot eyes + two soft antenna nubs + striped fluffy bottom (no legs)
  gnat_wing  : one thin oval wing, pivot at the wing root (view/crisis_view.gd mirrors + flaps it)
  water_drop : a fat wobbly droplet (round bottom, soft tip), light water colours + highlight (view gives it a see-through material)
  dust_bunny : grey fluff ball of lumpy clumps + lint bits (thread strands, a crumb, a fibre loop) + sleepy dot eyes
Coordinates: Blender Z-up, 1 unit = 1 cell. FRONT = -Y (Godot +Z, towards the camera). Origin = bottom centre
(gnat: body centre, wing: root).
Run: blender -b --factory-startup --python build_crises.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, out_dir_from_argv  # noqa: E402

OUT = out_dir_from_argv()

EYE = "1b1718"
# gnat: soft dusty-brown fuzz with a creamy belly, wings pale blue-white
GN_FUR = "8a7a6a"
GN_BELLY = "d8c7a8"
GN_STRIPE = "5e5248"
GN_WING = "dcecf2"
GN_VEIN = "a9c6d2"
# water
DROP = "8fd3dc"
DROP_DEEP = "5fb3c4"
DROP_HI = "f2fbfb"
# dust
DUST = "a7a6a3"
DUST_DARK = "86878a"
DUST_LIGHT = "c8c6c0"
LINT = ("d98a7a", "7aa3c9", "e2c46a", "efe8dc")


def fib(n, y0=1.0, y1=-0.8):
    for i in range(n):
        yy = y0 - (i + 0.5) / n * (y0 - y1)
        rr = math.sqrt(max(0.0, 1 - yy * yy))
        a = i * 2.39996
        yield i, Vector((math.cos(a) * rr, math.sin(a) * rr, yy))


def build_gnat():
    m = Model("gnat_body", 701)
    R = 0.42
    # fuzzy round abdomen (behind, +Y) with soft stripes, thorax in the middle
    m.sphere(R, pos=(0, 0.28, 0), scl=(0.95, 1.25, 0.9), color=GN_FUR, seg=14, rings=8)
    for k, yy in enumerate((0.12, 0.36, 0.6)):
        m.sphere(R * 0.98, pos=(0, 0.28 + (yy - 0.36) * 0.9, 0), scl=(0.99, 0.18, 0.93), color=GN_STRIPE if k != 1 else GN_BELLY,
                 seg=14, rings=6, group="body_nl")
    # fluff clumps on the back
    for i, d in fib(14, 1.0, 0.1):
        p = Vector((d.x * R * 0.8, 0.22 + d.y * R * 0.9, d.z * R * 0.8))
        m.ico(R * 0.32, pos=p, color=shade(GN_FUR, 1.0 + 0.06 * ((i * 0.37) % 1.0)), subdiv=2, smooth=True, lumps=0.12,
              group="body_nl")
    # thorax + head (front, -Y), creamy face
    m.sphere(R * 0.72, pos=(0, -0.22, 0.06), color=GN_FUR, seg=12, rings=7)
    m.sphere(R * 0.62, pos=(0, -0.56, 0.12), scl=(1.0, 0.9, 0.95), color=GN_BELLY, seg=12, rings=7)
    # dot eyes (small, dark - like the residents)
    for sx in (-1, 1):
        m.sphere(R * 0.11, pos=(sx * R * 0.27, -0.80, 0.2), scl=(0.9, 0.55, 1.2), color=EYE, seg=8, rings=4, group="body_nl")
    # rosy cheeks
    for sx in (-1, 1):
        m.sphere(R * 0.09, pos=(sx * R * 0.42, -0.76, 0.06), scl=(1.0, 0.4, 0.7), color="e8a89a", seg=6, rings=3, group="body_nl")
    # two soft antenna nubs ending in little puffs
    for sx in (-1, 1):
        b = Vector((sx * 0.1, -0.62, 0.36))
        d = Vector((sx * 0.35, -0.45, 0.85)).normalized()
        top = b + d * 0.26
        v = top - b
        m.cyl(0.03, 0.022, v.length, pos=b, rot=tuple(v.to_track_quat("Z", "Y").to_euler()), color=GN_STRIPE, seg=5)
        m.ico(0.06, pos=top, color=GN_BELLY, subdiv=2, smooth=True, group="body_nl")
    # tucked little foot-nubs under the thorax (no stick legs)
    for sx in (-1, 1):
        m.sphere(0.08, pos=(sx * 0.16, -0.24, -0.26), scl=(1, 1.2, 0.7), color=GN_STRIPE, seg=6, rings=3)
    m.export(OUT)

    w = Model("gnat_wing", 702)
    # oval wing in the XY plane, root at origin, reaching +X (view mirrors for the left wing)
    L, Wd = 1.15, 0.5
    n = 14
    ring = []
    for i in range(n):
        a = i / n * math.tau
        x = (math.cos(a) * 0.5 + 0.5) * L
        y = math.sin(a) * Wd * 0.5 * (0.55 + 0.45 * math.sin(math.cos(a) * 0.5 * math.pi + math.pi / 2))
        ring.append(Vector((x, y + 0.08 * (x / L), 0.0)))
    c = Vector((L * 0.45, 0.04, 0.0))
    for i in range(n):
        a, b = ring[i], ring[(i + 1) % n]
        w.poly([c, a, b], color=GN_WING, group="body_nh")
        w.poly([c, b, a], color=GN_WING, group="body_nh")
    # a couple of veins (thin strips, slightly above)
    for t in (0.0, 0.18):
        p0 = Vector((0.02, t * 0.4 - 0.02, 0.004))
        p1 = Vector((L * 0.92, t + 0.05, 0.004))
        side = Vector((0, 0.012, 0))
        w.poly([p0 - side, p1 - side, p1 + side, p0 + side], color=GN_VEIN, group="body_nh")
        w.poly([p0 + side, p1 + side, p1 - side, p0 - side], color=GN_VEIN, group="body_nh")
    w.export(OUT)


def build_drop():
    m = Model("water_drop", 703)
    R = 0.9
    # fat droplet: lofted rings from the round bottom to a soft tip
    rings = []
    seg = 18
    prof = []
    for i in range(13):
        t = i / 12.0                     # 0 bottom .. 1 tip
        ang = t * math.pi
        r = math.sin(ang) * R * (1.0 - 0.55 * t * t)
        z = (1 - math.cos(ang)) * R * 0.78 + t * t * R * 0.55
        prof.append((max(r, 0.002), z))
    for r, z in prof:
        rings.append([Vector((math.cos(k / seg * math.tau) * r, math.sin(k / seg * math.tau) * r, z)) for k in range(seg)])
    m.strip(rings, color=DROP, close=True, smooth=True,
            colfn=lambda f: DROP_DEEP if f.calc_center_median().z < R * 0.35 else (DROP if f.calc_center_median().z < R * 1.25 else mix(DROP, DROP_HI, 0.35)))
    m.sphere(0.02, pos=(0, 0, prof[-1][1]), color=DROP, seg=6, rings=3)       # closes the tip
    # highlights (front-left, towards the default light)
    m.sphere(R * 0.18, pos=(-R * 0.42, -R * 0.58, R * 1.05), scl=(0.8, 0.35, 1.3), color=DROP_HI, seg=8, rings=4, group="body_nl")
    m.sphere(R * 0.08, pos=(-R * 0.22, -R * 0.74, R * 0.72), scl=(1, 0.4, 1), color=DROP_HI, seg=6, rings=3, group="body_nl")
    m.export(OUT)


def build_dust():
    m = Model("dust_bunny", 704)
    R = 0.95
    cz = R * 0.9
    m.sphere(R * 0.92, pos=(0, 0, cz), scl=(1.08, 1.0, 0.92), color=DUST_DARK, seg=14, rings=8)
    # fluffy clumps (lighter on top, darker below) - leave a small face patch for the dot eyes
    for i, d in fib(34, 1.0, -0.75):
        if d.y < -0.6 and abs(d.z - 0.15) < 0.4 and abs(d.x) < 0.5:
            continue
        lump = R * (0.36 + 0.14 * ((i * 0.618) % 1.0))
        p = Vector((d.x * R * 0.92, d.y * R * 0.9, cz + d.z * R * 0.82))
        k = d.z + 0.15
        cc = DUST_LIGHT if k > 0.7 else (DUST if k > -0.1 else DUST_DARK)
        m.ico(lump, pos=p, color=shade(cc, 1.0 - 0.06 * ((i * 0.37) % 1.0)), subdiv=2, smooth=True, lumps=0.22,
              group="body_nl")
    # wispy tufts sticking out
    for i, d in fib(9, 0.9, -0.2):
        b = Vector((d.x * R * 1.0, d.y * R * 1.0, cz + d.z * R * 0.9))
        top = b + d * (0.18 + 0.08 * (i % 3))
        v = top - b
        m.cyl(0.05, 0.0, v.length, pos=b, rot=tuple(v.to_track_quat("Z", "Y").to_euler()), color=DUST_LIGHT, seg=4)
    # lint bits: coloured thread strands caught in the fluff, a crumb, a fibre loop
    strands = (((0.55, -0.55, 1.35), (0.95, -0.2, 1.1), LINT[0]),
               ((-0.7, -0.35, 1.2), (-0.95, 0.15, 0.85), LINT[1]),
               ((0.1, 0.6, 1.6), (0.5, 0.85, 1.45), LINT[2]))
    for a, b, col in strands:
        a, b = Vector(a), Vector(b)
        mid = (a + b) * 0.5 + Vector((0, 0, 0.12))
        for p0, p1 in ((a, mid), (mid, b)):
            v = p1 - p0
            m.cyl(0.022, 0.022, v.length, pos=p0, rot=tuple(v.to_track_quat("Z", "Y").to_euler()), color=col, seg=4)
    m.ico(0.09, pos=(-0.35, -0.75, 1.55), color="c9a57a", subdiv=1, smooth=False)           # a crumb
    for j in range(8):                                                                           # a little fibre loop
        a0, a1 = j / 8 * math.tau, (j + 1) / 8 * math.tau
        c = Vector((0.75, 0.35, 0.55))
        p0 = c + Vector((math.cos(a0) * 0.14, 0, math.sin(a0) * 0.14))
        p1 = c + Vector((math.cos(a1) * 0.14, 0, math.sin(a1) * 0.14))
        v = p1 - p0
        m.cyl(0.016, 0.016, v.length, pos=p0, rot=tuple(v.to_track_quat("Z", "Y").to_euler()), color=LINT[3], seg=4)
    # sleepy dot eyes (small, low on the front)
    for sx in (-1, 1):
        m.sphere(R * 0.075, pos=(sx * R * 0.24, -R * 0.93, cz + R * 0.05), scl=(1.2, 0.5, 0.75), color=EYE, seg=8, rings=4,
                 group="body_nl")
    m.export(OUT)


if __name__ == "__main__":
    print("crises ->", OUT)
    build_gnat()
    build_drop()
    build_dust()
