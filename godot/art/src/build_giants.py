"""Giant-scale outside life (WORLD_EVENTS 1.1 / 2.6 / 2.7): the five great mushrooms (models great_*: "giant_" is reserved for the giant - art bible 8.3) and the dandelion parts.
References: design/concept/small_world/giant_mushrooms_b.png, dandelion_seeds_b.png.
Sizes follow Balance.SHROOM (h, cap_r) and Balance.DAND_H - flora_view.gd scales them while they grow.
Dandelion heads: origin = top of the stem, head tilted towards the camera (front, -Y here = +Z in Godot).
Run: blender -b --factory-startup --python build_giants.py -- [out_dir]
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, Matrix, Euler, shade, mix, srgb, out_dir_from_argv, GODOT  # noqa: E402
import bmesh  # noqa: E402

OUT = out_dir_from_argv()

# colours: flora_view.gd constants (one source - parsed from the view)
FV = {}
with open(os.path.join(GODOT, "view", "flora_view.gd"), encoding="utf-8") as f:
    for k, v in re.findall(r'^const\s+([A-Z_0-9]+)\s*:=\s*Color\("([0-9a-fA-F]{6})"\)', f.read(), re.M):
        FV[k] = v
SHROOM = {}
with open(os.path.join(GODOT, "data", "balance.gd"), encoding="utf-8") as f:
    src = f.read()
for name, body in re.findall(r'"([^"]+버섯)":\s*\{([^}]*)\}', src):
    d = dict((k, float(v)) for k, v in re.findall(r'"(\w+)":\s*([0-9.]+)', body))
    SHROOM[name] = d
DAND_H = float(re.search(r"DAND_H\s*:=\s*([0-9.]+)", src).group(1))


def C(k):
    return FV[k]


# ───────────── helpers ─────────────
def lathe(m, prof, seg=24, color="WHITE", colfn=None, smooth=True, group="body", pos=(0, 0, 0), wave=None, close_top=True):
    """Surface of revolution through profile [(r, z), ...] from the bottom up. wave(a, j) -> radius factor per vertex.
    close_top: a fan cap where the last r == 0 (dome tops)."""
    rings = []
    for j, (r, z) in enumerate(prof):
        ring = []
        for i in range(seg):
            a = i * math.tau / seg
            k = wave(a, j) if wave else 1.0
            ring.append(Vector((pos[0] + math.cos(a) * r * k, pos[1] + math.sin(a) * r * k, pos[2] + z)))
        rings.append(ring)
    fs = m.strip(rings, color=srgb(color) if isinstance(color, str) else color, group=group, smooth=smooth, close=True)
    bm = m._bm(group)
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    bm.normal_update()
    if colfn:
        for f in fs:
            m._finish(bm, [f], colfn(f), smooth)
    return fs


def stem(m, z0, z1, r0, r1, color, seg=16, bend=0.0, parts=5, fibre=True):
    """Tapered stem, slightly bent along +X, faint vertical fibres (alternate column shades)."""
    prof = []
    for j in range(parts + 1):
        u = j / parts
        prof.append((r0 + (r1 - r0) * (u ** 0.7), z0 + (z1 - z0) * u))
    rings = []
    for j, (r, z) in enumerate(prof):
        u = j / parts
        ox = bend * u * u
        rings.append([Vector((ox + math.cos(i * math.tau / seg) * r, math.sin(i * math.tau / seg) * r, z)) for i in range(seg)])
    fs = m.strip(rings, color=color, close=True, smooth=True)
    bm = m._bm("body")
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    bm.normal_update()
    if fibre:
        for f in fs:
            c = f.calc_center_median()
            col = int((math.atan2(c.y, c.x - bend * 0.5) + math.pi) / math.tau * seg)
            m._finish(bm, [f], shade(color, 0.96 if col % 3 == 0 else 1.0), True)
    return Vector((bend, 0, z1))


def dome(m, cx, cz, r, hgt, seg=32, rings=8, color="WHITE", rim=0.18, under=None, colfn=None, wave=None):
    """Mushroom cap: rounded dome (radius r, height hgt above cz) with a thick rolled rim, + flat gill disc under it."""
    prof = [(r * 0.86, cz - rim * 0.6), (r * 0.98, cz - rim * 0.35), (r, cz)]
    for j in range(1, rings + 1):
        t = j / rings
        a = t * math.pi / 2
        prof.append((r * math.cos(a) * (1 - 0.04 * t), cz + hgt * math.sin(a)))
    prof[-1] = (0.0001, prof[-1][1])
    fs = lathe(m, prof, seg, color=color, colfn=colfn, pos=(cx[0], cx[1], 0), wave=wave)
    return fs


def gills(m, c, r_in, r_out, z_in, z_out, seg=32, col="GILL"):
    """Underside: a shallow cone, radial stripes of two shades = gills."""
    prof = [(r_out * 0.86, z_out), (r_in, z_in)]
    rings = []
    for (r, z) in prof:
        rings.append([Vector((c[0] + math.cos(i * math.tau / seg) * r, c[1] + math.sin(i * math.tau / seg) * r, z))
                      for i in range(seg)])
    fs = m.strip(rings, close=True, color=col)
    bm = m._bm("body")
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    bm.normal_update()
    for i, f in enumerate(fs):
        if f.normal.z > 0:
            f.normal_flip()
        m._finish(bm, [f], shade(col, 0.88 if i % 2 else 1.0), False)
    bm.normal_update()


def drops(m, pts, r=0.2):
    for (x, y, z, s) in pts:
        m.sphere(r * s, pos=(x, y, z), scl=(1, 1, 0.5), color=C("DROP"), seg=8, rings=4, group="body_nl")
        m.sphere(r * s * 0.3, pos=(x - r * s * 0.3, y - r * s * 0.3, z + r * s * 0.32), scl=(1, 1, 0.5),
                 color="ffffff", seg=5, rings=2, group="body_nl")


def skirt(m, z, r_top, r_bot, ln, col, seg=20):
    """Hanging ring (annulus) round the stem with a scalloped bottom edge."""
    rings = []
    for j, (r, zz) in enumerate(((r_top, z), (r_bot, z - ln))):
        ring = []
        for i in range(seg * 2):
            a = i * math.tau / (seg * 2)
            dz = (0.08 if (i % 2 and j == 1) else 0.0)
            ring.append(Vector((math.cos(a) * r, math.sin(a) * r, zz + dz)))
        rings.append(ring)
    fs = m.strip(rings, color=col, close=True, smooth=True)
    bm = m._bm("body")
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    for f in fs:
        f.normal_update()
        c = f.calc_center_median()
        if Vector((c.x, c.y, 0)).dot(f.normal) < 0:
            f.normal_flip()
    bm.normal_update()
    # inner side so the skirt is not see-through from below
    rings2 = [[Vector((p.x * 0.93, p.y * 0.93, p.z)) for p in r] for r in rings]
    fs2 = m.strip(rings2, color=shade(col, 0.82), close=True)
    for f in fs2:
        f.normal_update()
        c = f.calc_center_median()
        if Vector((c.x, c.y, 0)).dot(f.normal) > 0:
            f.normal_flip()
    bm.normal_update()


# ───────────── mushrooms ─────────────
def build_white():
    d = SHROOM["흰갓버섯"]
    h, cr = d["h"], d["cap_r"]
    m = Model("great_white", 201)
    m.sphere(1.0, pos=(0, 0, 0.32), scl=(1.0, 1.0, 0.55), color=shade(C("STEM"), 0.95), seg=16, rings=6, lumps=0.06)
    top = stem(m, 0.1, h - 1.2, 0.8, 0.6, C("STEM"), bend=0.35)
    skirt(m, top.z - 1.0, 0.64, 1.08, 0.45, C("WHITE_SH"))
    gills(m, (top.x, 0), 0.5, cr, top.z + 0.05, top.z - 0.05, seg=36, col=C("GILL"))
    dome(m, (top.x, 0), top.z - 0.02, cr, cr * 0.55, seg=32, rings=7, color=C("WHITE"),
         colfn=lambda f: shade(C("WHITE"), 1.0 if f.calc_center_median().z > top.z + 0.25 else 0.95))
    pts = []
    for i in range(7):
        a = i * 2.39996 + 0.8
        u = 0.25 + 0.6 * ((i * 0.618) % 1.0)
        rr = cr * u
        z = top.z - 0.02 + cr * 0.55 * math.sqrt(max(0.0, 1 - u * u)) + 0.02
        pts.append((top.x + math.cos(a) * rr, math.sin(a) * rr, z, 0.8 + 0.5 * ((i * 0.37) % 1.0)))
    drops(m, pts, 0.22)
    m.export(OUT)


def build_brown():
    d = SHROOM["갈색갓버섯"]
    h, cr = d["h"], d["cap_r"]
    m = Model("great_brown", 202)
    m.sphere(1.25, pos=(0, 0, 0.38), scl=(1.0, 1.0, 0.5), color=shade(C("STEM"), 0.86), seg=16, rings=6, lumps=0.06)
    top = stem(m, 0.1, h - 1.5, 1.0, 0.85, shade(C("STEM"), 0.94), bend=-0.3)
    gills(m, (top.x, 0), 0.7, cr, top.z + 0.05, top.z - 0.1, seg=40, col=shade(C("GILL"), 0.9))
    hgt = cr * 0.42
    cracks = [i * math.tau / 6 + 0.4 + 0.3 * ((i * 0.618) % 1) for i in range(6)]

    def ccol(f):
        c = f.calc_center_median()
        x, y = c.x - top.x, c.y
        rr = math.hypot(x, y) / cr
        a = math.atan2(y, x)
        if c.z < top.z + 0.02:
            return shade(C("BROWN"), 0.82)         # rolled rim
        if rr < 0.36:
            return C("BROWN_LIGHT")
        return C("BROWN") if rr > 0.62 else mix(C("BROWN"), C("BROWN_LIGHT"), 0.35)
    dome(m, (top.x, 0), top.z - 0.02, cr, hgt, seg=40, rings=9, color=C("BROWN"), colfn=ccol)

    def surf(rr, a):        # point on the dome (rr = 0..1 of the radius), lifted a little
        u = min(rr, 0.999)
        tt = math.acos(u)
        z = top.z - 0.02 + hgt * math.sin(tt) + 0.04
        return Vector((top.x + math.cos(a) * u * cr * (1 - 0.04 * (tt / (math.pi / 2))), math.sin(a) * u * cr, z))

    def crack(a0, r0, r1, w, k, n=9):
        """Cream fissure: a zig-zag ribbon lying on the cap, tapering towards its end."""
        left, right = [], []
        for i in range(n + 1):
            u = i / n
            rr = r0 + (r1 - r0) * u
            a = a0 + 0.07 * math.sin(i * 2.2 + k) + 0.04 * u
            p = surf(rr, a)
            p2 = surf(rr, a + 0.01)
            side = (p2 - p).normalized()
            ww = w * (1 - 0.75 * u) * (0.8 + 0.4 * ((i * 0.618 + k) % 1.0))
            left.append(p + side * ww)
            right.append(p - side * ww)
        fs = m.strip([left, right], color=C("CRACK"), group="body_nh")
        for f in fs:
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
        m._bm("body_nh").normal_update()
    for k, ca in enumerate(cracks):
        crack(ca, 0.3, 0.98, 0.1, k)
        if k % 2 == 0:            # a side branch
            crack(ca + 0.18, 0.62, 0.9, 0.06, k + 3, n=4)
    m.export(OUT)


def build_red():
    d = SHROOM["얼룩버섯"]
    h, cr = d["h"], d["cap_r"]
    m = Model("great_red", 203)
    m.sphere(0.9, pos=(0, 0, 0.42), scl=(1.0, 1.0, 0.62), color=shade(C("SPOT"), 0.93), seg=16, rings=6, lumps=0.08)
    top = stem(m, 0.2, h - 1.3, 0.6, 0.44, C("SPOT"), bend=0.2)
    skirt(m, top.z - 0.85, 0.48, 0.9, 0.4, shade(C("SPOT"), 0.95))
    gills(m, (top.x, 0), 0.35, cr, top.z + 0.05, top.z - 0.05, seg=32, col=mix(C("GILL"), C("SPOT"), 0.5))
    hgt = cr * 0.62
    dome(m, (top.x, 0), top.z - 0.02, cr, hgt, seg=32, rings=8, color=C("RED"),
         colfn=lambda f: C("RED_DARK") if f.calc_center_median().z < top.z + 0.05 else C("RED"))
    for i in range(16):
        u = (i + 0.5) / 16
        a = i * 2.39996
        rr = cr * math.sqrt(u) * 0.9
        nr = rr / cr
        z = top.z - 0.02 + hgt * math.sqrt(max(0.0, 1 - nr * nr))
        nrm = Vector((math.cos(a) * nr / cr, math.sin(a) * nr / cr, math.sqrt(max(0.05, 1 - nr * nr)) / hgt)).normalized()
        q = nrm.to_track_quat("Z", "Y").to_euler()
        sr = 0.17 + 0.13 * ((i * 0.618) % 1.0)
        m.sphere(sr, pos=(top.x + math.cos(a) * rr, math.sin(a) * rr, z), scl=(1, 1, 0.32), rot=tuple(q), color=C("SPOT"),
                 seg=10, rings=4, group="body_nl")
    m.export(OUT)


def build_fan():
    d = SHROOM["부채버섯"]
    cr = d["cap_r"]
    m = Model("great_fan", 204)
    # rotting stump the brackets grow on
    m.cyl(0.62, 0.48, 2.9, color=mix(C("FAN_DARK"), "TRUNK", 0.5), seg=10, smooth=True, cap=mix("STUMP_TOP", "TRUNK", 0.4))
    m.sphere(0.45, pos=(0.1, 0.05, 2.9), scl=(1.2, 1.1, 0.35), color="MOSS", seg=8, rings=4, lumps=0.2, group="body_nl")
    for i in range(4):
        a = i * math.tau / 4 + 0.3
        m.cyl(0.32, 0.04, 0.6, pos=(math.cos(a) * 0.4, math.sin(a) * 0.4, 0.12), rot=(0, math.pi / 2 - 0.6, a),
              color=mix(C("FAN_DARK"), "TRUNK", 0.55), seg=5, smooth=True)
    # brackets step up the stump, all on the camera side (-Y) like the concept's layered shelves
    shelves = [(0.5, 1.9, -1.75), (1.05, 1.6, -1.2), (1.5, 1.45, -2.2), (2.0, 1.15, -1.55), (2.45, 0.9, -0.9),
               (1.3, 1.1, 0.9)]
    for (z, r, a) in shelves:
        r *= cr / 1.9
        # a fan = half-disc lofted outward from the stump, wavy rim, domed top, light rim band
        K, J = 14, 4
        rings = []
        for j in range(J + 1):
            t = j / J
            ring = []
            for k in range(K + 1):
                b = a - 0.95 + 1.9 * k / K
                wav = 1.0 + 0.07 * math.sin(k * 2.3) * t
                rr = 0.45 + r * t * wav
                ring.append(Vector((math.cos(b) * rr, math.sin(b) * rr, z + 0.22 * math.sin(math.pi * (0.2 + 0.8 * t)) - 0.12 * t * t)))
            rings.append(ring)
        top_f = m.strip(rings, color=C("FAN"), smooth=True)
        under = [[Vector((p.x, p.y, p.z - 0.12 * (1 - j / J) - 0.05)) for p in ring] for j, ring in enumerate(rings)]
        und_f = m.strip(under, color=C("FAN_DARK"))
        edge = m.strip([rings[-1], under[-1]], color=shade(C("FAN_DARK"), 1.05))
        bm = m._bm("body")
        for f in top_f:
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
            c = f.calc_center_median()
            t = (math.hypot(c.x, c.y) - 0.45) / r
            top_c = mix(C("FAN"), "ffffff", 0.3)
            m._finish(bm, [f], mix(top_c, "ffffff", 0.35) if t > 0.78 else (top_c if t > 0.3 else shade(top_c, 0.92)), True)
        for f in und_f:
            f.normal_update()
            if f.normal.z > 0:
                f.normal_flip()
        for i, f in enumerate(und_f):
            m._finish(bm, [f], shade(C("FAN_DARK"), 0.9 if i % 2 else 1.0), False)
        for f in edge:
            f.normal_update()
            c = f.calc_center_median()
            if Vector((c.x, c.y, 0)).dot(f.normal) < 0:
                f.normal_flip()
        bm.normal_update()
    m.export(OUT)


def build_glow():
    d = SHROOM["빛버섯"]
    h = d["h"]
    m = Model("great_glow", 205)
    for k, (off, sc) in enumerate((((0, 0), 1.0), ((0.26, -0.12), 0.72), ((-0.18, -0.22), 0.58), ((0.1, 0.24), 0.45))):
        hh = h * sc
        m.cyl(0.05 * sc, 0.035 * sc, hh, pos=(off[0], off[1], 0), color=C("GLOW_STEM"), seg=6, smooth=True)
        dome(m, (off[0], off[1]), hh - 0.02, 0.17 * sc, 0.13 * sc, seg=12, rings=4, rim=0.03, color=C("GLOW_CAP"))
    m.export(OUT)


# ───────────── dandelion ─────────────
TILT = (0.5, 0, 0)            # head tilts towards the camera (-Y)


def _tilted(m_xf, p):
    return m_xf @ Vector(p)


def build_dand_flower():
    m = Model("dand_flower", 211)
    R = Euler(TILT, "XYZ").to_matrix()
    m.sphere(0.27, pos=(0, 0, 0.05), scl=(1, 1, 0.6), color=C("BUD"), seg=10, rings=4)
    # reflexed green bracts under the flower
    for i in range(8):
        a = i * math.tau / 8
        p0 = Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, 0.08))
        p1 = Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, -0.12))
        m.blade(p0, p1, 0.1, color=shade(C("BUD"), 0.9), group="body_nl")
    c = R @ Vector((0, 0, 0.16))
    # full disc under the petals
    m.sphere(0.88, pos=c, scl=(1, 1, 0.24), rot=TILT, color=mix(C("YELLOW"), C("YELLOW_DARK"), 0.45), seg=20, rings=5)
    for ring, (nr, rr, lift, up) in enumerate(((24, 0.98, 0.0, 0.12), (20, 0.78, 0.1, 0.38), (15, 0.56, 0.2, 0.62),
                                                 (9, 0.32, 0.27, 0.9))):
        for i in range(nr):
            a = (i + 0.5 * ring) * math.tau / nr
            d = Vector((math.cos(a), math.sin(a), 0))
            p = c + R @ (d * rr * 0.55 + Vector((0, 0, lift)))
            col = C("YELLOW") if (i + ring) % 3 else mix(C("YELLOW"), "ffffff", 0.18)
            if ring == 3:
                col = shade(C("YELLOW"), 0.94)
            rot = (Euler(TILT, "XYZ").to_matrix().to_4x4() @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(-up, 4, "Y")).to_euler()
            m.sphere(0.5, pos=p, scl=(rr * 0.95, 0.26 - 0.03 * ring, 0.07), rot=tuple(rot), color=col, seg=6, rings=3,
                     group="body_nl")
    m.sphere(0.2, pos=c + R @ Vector((0, 0, 0.34)), scl=(1, 1, 0.55), rot=TILT, color=C("YELLOW_DARK"), seg=8, rings=4,
             group="body_nl")
    m.export(OUT)


def build_dand_closed():
    m = Model("dand_closed", 212)
    lathe(m, [(0.05, 0.0), (0.24, 0.15), (0.3, 0.35), (0.27, 0.55), (0.18, 0.75), (0.08, 0.86), (0.0001, 0.9)], seg=10,
          color=C("BUD"), colfn=lambda f: C("YELLOW_DARK") if f.calc_center_median().z > 0.74 else
          (C("BUD") if int((math.atan2(f.calc_center_median().y, f.calc_center_median().x) + 4) * 10 / math.tau) % 2
           else shade(C("BUD"), 0.9)))
    for i in range(7):
        a = i * math.tau / 7
        m.blade((math.cos(a) * 0.16, math.sin(a) * 0.16, 0.08), (math.cos(a) * 0.42, math.sin(a) * 0.42, -0.22), 0.09,
                color=shade(C("BUD"), 0.85), group="body_nl")
    m.export(OUT)


def build_dand_puff():
    m = Model("dand_puff", 213)
    c = Vector((0, 0, 0.75))
    m.sphere(0.7, pos=c, color=C("FLUFF"), seg=14, rings=7)
    m.sphere(0.17, pos=(0, 0, 0.1), color=C("FLUFF_CORE"), seg=8, rings=4)
    m.cyl(0.06, 0.05, 0.6, pos=(0, 0, 0.1), color=C("FLUFF_CORE"), seg=6)
    n = 72
    for i in range(n):
        yy = 1.0 - (i + 0.5) / n * 1.8
        rr = math.sqrt(max(0.0, 1 - yy * yy))
        a = i * 2.39996
        d = Vector((math.cos(a) * rr, math.sin(a) * rr, yy)).normalized()
        q = d.to_track_quat("Z", "Y").to_euler()
        m.sphere(0.17, pos=c + d * 0.76, scl=(1, 1, 0.5), rot=tuple(q), color=C("FLUFF") if i % 3 else "ffffff",
                 seg=5, rings=3, group="body_nl")
    m.export(OUT)


def build_dand_bare():
    m = Model("dand_bare", 214)
    m.sphere(0.24, pos=(0, 0, 0.08), scl=(1, 1, 0.5), color=C("FLUFF_CORE"), seg=10, rings=4)
    for i in range(5):
        a = i * 2.39996
        d = Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, 0.6)).normalized()
        m.sphere(0.1, pos=Vector((0, 0, 0.1)) + d * 0.35, scl=(1, 1, 0.6), color=C("FLUFF"), seg=6, rings=3, group="body_nl")
    m.export(OUT)


def _leaf(m, a, ln, w, c, c2):
    """Toothed dandelion leaf lying on the ground, tip lifting; midrib in a lighter shade."""
    n = 8
    d = Vector((math.cos(a), math.sin(a), 0))
    side = Vector((-d.y, d.x, 0))
    mid, lft, rgt = [], [], []
    for i in range(n + 1):
        u = i / n
        z = 0.05 + 0.14 * u * u * ln
        ww = w * math.sin(math.pi * min(1.0, u * 1.08)) * (1.0 if i % 2 == 0 else 0.5)
        back = 0.12 * ln / n if i % 2 == 1 else 0.0
        p = d * (u * ln - back)
        mid.append(Vector((d.x * u * ln, d.y * u * ln, z + 0.05)))
        lft.append(p + side * ww + Vector((0, 0, z)))
        rgt.append(p - side * ww + Vector((0, 0, z)))
    bm = m._bm("body_nh")
    for flip in (False, True):
        for e, cc in ((lft, c), (rgt, c2)):
            for i in range(n):
                vs = [mid[i], e[i], e[i + 1], mid[i + 1]]
                vv = [bm.verts.new(p) for p in vs]
                f = bm.faces.new(vv)
                f.normal_update()
                if (f.normal.z < 0) != flip:
                    f.normal_flip()
                m._finish(bm, [f], cc if not flip else shade(cc, 0.85), False)


def build_rosettes():
    for big in (True, False):
        m = Model("dand_leaves" if big else "dand_leaves_small", 215 if big else 216)
        n = 7 if big else 4
        for i in range(n):
            a = i * math.tau / n + 0.3 * ((i * 0.618) % 1.0)
            ln = (1.9 if big else 0.9) * (0.8 + 0.3 * ((i * 0.37) % 1.0))
            _leaf(m, a, ln, 0.34 if big else 0.2, C("LEAF"), C("LEAF_DARK"))
        m.export(OUT)


if __name__ == "__main__":
    print("giants ->", OUT)
    build_white()
    build_brown()
    build_red()
    build_fan()
    build_glow()
    build_dand_flower()
    build_dand_closed()
    build_dand_puff()
    build_dand_bare()
    build_rosettes()
