"""Trees and ground props (style-test/flat2_map_a/b.png): lumpy two-tone broadleaf canopies with trunk + roots,
a conifer, bush, stump, sapling, mushroom cluster, mossy rock cluster, fern, clover, grass tuft, lily pads, lotus,
fallen log, reeds.
Run: blender -b --factory-startup --python build_nature.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, out_dir_from_argv  # noqa: E402

OUT = out_dir_from_argv()


def canopy_col(top_z, low_z):
    """Two-tone foliage: light mint on up-facing high faces, teal body, dark teal underneath."""
    def f(face):
        c = face.calc_center_median()
        h = (c.z - low_z) / max(0.01, top_z - low_z)
        nz = face.normal.z
        if nz > 0.35 and h > 0.55:
            return "LEAF_TOP"
        if nz < -0.25 or h < 0.18:
            return "LEAF_LOW"
        return "LEAF_MID"
    return f


def trunk(m, h, r_bot, r_top, roots=4, lean=(0.0, 0.0), seed=0):
    m.cyl(r_bot, r_top, h, color="TRUNK", seg=7, smooth=True, cap="TRUNK_DARK", rot=(lean[0], lean[1], 0))
    rng = m.rng
    for i in range(roots):                       # root flare: low wedges radiating out
        a = i * math.tau / roots + rng.uniform(-0.3, 0.3)
        ln = rng.uniform(0.38, 0.55)
        m.cyl(r_bot * 0.55, 0.02, ln, pos=(math.cos(a) * r_bot * 0.5, math.sin(a) * r_bot * 0.5, 0.05),
              rot=(0, math.pi / 2 - 0.35, a), color="TRUNK", seg=5, smooth=True)
    return h


def branch(m, base, direction, ln, r):
    d = Vector(direction).normalized()
    pitch = math.acos(max(-1, min(1, d.z)))
    yaw = math.atan2(d.y, d.x)
    m.cyl(r, r * 0.6, ln, pos=base, rot=(0, pitch, yaw), color="TRUNK", seg=5, smooth=True)


def broadleaf(name, seed, blobs, height=1.9, spread=1.15, top=3.2, lift=0.75):
    """Lumpy canopy = clusters of noisy ico-blobs. blobs = [(x, y, z, r)] in canopy space (0..1 heights)."""
    m = Model(name, seed)
    rng = m.rng
    # the camera looks down 60 deg: the canopy must sit high (lift) so trunk + roots show below its front rim
    height += lift
    top += lift
    blobs = [(x, y, z + lift, r) for (x, y, z, r) in blobs]
    trunk(m, height + 0.4, 0.3, 0.18)
    for a in (0.4, 2.5, 4.4):
        branch(m, (0, 0, height * 0.8), (math.cos(a), math.sin(a), 1.1), 0.8, 0.09)
    low_z = height - 0.15
    top_z = top + 0.6
    col = canopy_col(top_z, low_z)
    for (x, y, z, r) in blobs:
        m.ico(r, pos=(x * spread, y * spread, z), scl=(1.0, 1.0, 0.86), color="LEAF_MID", subdiv=2, smooth=True,
              colfn=col, lumps=0.13, lump_scale=2.2, group="body_nl")
    # small rim lumps -> scalloped edge seen from above
    n = 11
    for i in range(n):
        a = i * math.tau / n + rng.uniform(-0.15, 0.15)
        d = spread * rng.uniform(1.22, 1.38)
        r = rng.uniform(0.32, 0.42)
        m.ico(r, pos=(math.cos(a) * d, math.sin(a) * d, height + 0.55 + rng.uniform(-0.05, 0.25)), scl=(1, 1, 0.85),
              color="LEAF_MID", subdiv=2, smooth=True, colfn=col, lumps=0.15, group="body_nl")
    m.export(OUT)


def build_trees():
    # A: round, wide
    broadleaf("tree_a", 1, [
        (0, 0, 2.75, 1.05), (0.75, 0.3, 2.45, 0.78), (-0.7, 0.35, 2.5, 0.8), (0.15, -0.75, 2.4, 0.78),
        (-0.4, -0.55, 2.55, 0.72), (0.55, -0.5, 2.6, 0.7), (0.0, 0.75, 2.55, 0.75),
        (0.25, 0.15, 3.35, 0.72), (-0.35, -0.1, 3.25, 0.6), (0.4, -0.35, 3.15, 0.55)])
    # B: taller, two crowns
    broadleaf("tree_b", 2, [
        (-0.45, 0.1, 2.9, 0.95), (0.55, -0.15, 2.75, 0.92), (0.0, 0.7, 2.6, 0.72), (0.1, -0.75, 2.55, 0.72),
        (-0.9, -0.4, 2.45, 0.6), (0.95, 0.45, 2.45, 0.6),
        (-0.4, 0.15, 3.6, 0.7), (0.5, -0.1, 3.45, 0.68), (0.05, 0.0, 3.85, 0.5)], height=2.1, top=3.4)
    # C: lower, broad and clumpy
    broadleaf("tree_c", 3, [
        (0, 0, 2.4, 0.95), (0.8, 0.0, 2.25, 0.75), (-0.8, 0.1, 2.25, 0.75), (0.3, 0.75, 2.2, 0.72),
        (-0.3, -0.75, 2.2, 0.72), (0.55, -0.6, 2.35, 0.6), (-0.55, 0.6, 2.35, 0.6),
        (0.2, 0.1, 2.95, 0.7), (-0.35, -0.25, 2.85, 0.55)], height=1.6, spread=1.2, top=2.9)


def build_conifer():
    m = Model("conifer", 4)
    rng = m.rng
    trunk(m, 1.6, 0.2, 0.14, roots=3)
    tiers = [(1.3, 1.2, 1.3), (2.05, 0.98, 1.2), (2.75, 0.74, 1.05), (3.35, 0.48, 0.9)]
    for k, (z, r, h) in enumerate(tiers):
        # cone with a jagged hem (alternate long/short points)
        seg = 14
        bm = m._bm("body_nl")
        tip = Vector((0, 0, z + h))
        ring = []
        for i in range(seg):
            a = i * math.tau / seg + k * 0.3
            rr = r * (1.0 if i % 2 == 0 else 0.78)
            ring.append(Vector((math.cos(a) * rr, math.sin(a) * rr, z - (0.08 if i % 2 == 0 else -0.04))))
        inner = [Vector((p.x * 0.35, p.y * 0.35, z + 0.15)) for p in ring]
        rings = [inner, ring]
        faces = []
        vt = bm.verts.new(tip)
        vr = [bm.verts.new(p) for p in ring]
        vi = [bm.verts.new(p) for p in inner]
        for i in range(seg):
            j = (i + 1) % seg
            faces.append(bm.faces.new((vt, vr[i], vr[j])))
            faces.append(bm.faces.new((vr[j], vr[i], vi[i], vi[j])))
        bm.normal_update()
        for f in faces:
            if (f.calc_center_median() - Vector((0, 0, z + h * 0.3))).dot(f.normal) < 0:
                f.normal_flip()
        bm.normal_update()
        lt = "LEAF_MID" if k < 3 else "LEAF_TOP"

        def cf(f, lt=lt):
            return "LEAF_LOW" if f.normal.z < 0 else (lt if f.normal.z > 0.45 else "LEAF_LOW" if k == 0 else "LEAF_MID")
        m._finish(bm, faces, "LEAF_MID", True, cf)
    m.export(OUT)


def build_bush():
    m = Model("bush", 5)
    col = canopy_col(0.85, 0.0)
    for (x, y, z, r) in ((0, 0, 0.32, 0.42), (0.42, 0.15, 0.25, 0.33), (-0.36, 0.2, 0.24, 0.32), (0.1, -0.35, 0.22, 0.3),
                         (0.05, 0.1, 0.6, 0.28)):
        m.ico(r, pos=(x, y, z), scl=(1, 1, 0.85), color="BUSH", subdiv=2, smooth=True, colfn=col, lumps=0.15, group="body_nl")
    m.export(OUT)


def build_bush_flower():
    m = Model("bush_flower", 6)
    col = canopy_col(0.75, 0.0)
    for (x, y, z, r) in ((0, 0, 0.28, 0.36), (0.38, 0.1, 0.22, 0.3), (-0.3, 0.18, 0.22, 0.28)):
        m.ico(r, pos=(x, y, z), scl=(1, 1, 0.85), color="BUSH", subdiv=1, smooth=True, colfn=col, lumps=0.15, group="body_nl")
    rng = m.rng
    for i in range(7):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.1, 0.4)
        m.sphere(0.06, pos=(math.cos(a) * d, math.sin(a) * d, 0.5 + rng.uniform(-0.1, 0.05)),
                 color="LOTUS" if i % 3 else "PLASTER", seg=6, rings=3, group="body_nl")
    m.export(OUT)


def build_stump():
    m = Model("stump", 7)
    m.cyl(0.34, 0.3, 0.42, color="TRUNK", seg=9, smooth=True, cap="STUMP_TOP")
    m.cyl(0.2, 0.2, 0.012, pos=(0, 0, 0.42), color=shade("STUMP_TOP", 0.88), seg=9)     # ring
    m.cyl(0.08, 0.08, 0.016, pos=(0, 0, 0.42), color=shade("STUMP_TOP", 0.8), seg=7)
    for i in range(4):
        a = i * math.tau / 4 + 0.4
        m.cyl(0.12, 0.02, 0.32, pos=(math.cos(a) * 0.22, math.sin(a) * 0.22, 0.04), rot=(0, math.pi / 2 - 0.45, a),
              color="TRUNK", seg=5, smooth=True)
    m.cyl(0.035, 0.02, 0.25, pos=(0.15, 0.1, 0.4), rot=(0.4, 0.3, 0), color="TRUNK", seg=4)            # twig
    m.sphere(0.07, pos=(0.2, 0.06, 0.66), color="LEAF_YOUNG", seg=6, rings=3)
    m.export(OUT)


def build_sapling():
    m = Model("sapling", 8)
    m.cyl(0.05, 0.035, 0.7, color="TRUNK", seg=5)
    col = canopy_col(1.1, 0.5)
    for (x, y, z, r) in ((0, 0, 0.85, 0.32), (0.2, 0.1, 0.7, 0.22), (-0.18, -0.08, 0.72, 0.22)):
        m.ico(r, pos=(x, y, z), color="LEAF_YOUNG", subdiv=1, smooth=True, colfn=col, lumps=0.15, group="body_nl")
    m.export(OUT)


def build_mushrooms():
    m = Model("mushrooms", 9)
    for (x, y, k) in ((0, 0, 1.0), (0.32, 0.18, 0.72), (-0.26, 0.25, 0.6), (0.12, -0.3, 0.5), (-0.1, -0.05, 0.38)):
        m.cyl(0.075 * k, 0.09 * k, 0.48 * k, pos=(x, y, 0), color="MUSHROOM_STEM", seg=7, smooth=True)
        cap = m.sphere(0.3 * k, pos=(x, y, 0.42 * k), scl=(1, 1, 0.62), color="MUSHROOM_CAP", seg=10, rings=6)
        # flat underside of the cap (gills)
        m.cyl(0.29 * k, 0.29 * k, 0.02, pos=(x, y, 0.4 * k), color="MUSHROOM_STEM", seg=10)
        for i in range(3):
            a = i * 2.1 + k * 3
            m.sphere(0.045 * k, pos=(x + math.cos(a) * 0.15 * k, y + math.sin(a) * 0.15 * k, 0.57 * k),
                     scl=(1, 1, 0.5), color="MUSHROOM_DOT", seg=6, rings=3)
    m.export(OUT)


def build_rocks():
    m = Model("rocks", 10)

    def mossy(f):
        return "MOSS" if f.normal.z > 0.72 else ("ROCK" if f.normal.z > -0.2 else "ROCK_DARK")
    m.ico(0.62, pos=(0, 0, 0.3), scl=(1.15, 1.0, 0.85), color="ROCK", subdiv=2, colfn=mossy, lumps=0.18, seed=1, smooth=True)
    m.ico(0.42, pos=(0.75, 0.3, 0.18), scl=(1.0, 1.0, 0.8), color="ROCK", subdiv=2, colfn=mossy, lumps=0.2, seed=2, smooth=True)
    m.ico(0.3, pos=(-0.62, 0.42, 0.1), scl=(1.0, 1.0, 0.75), color="ROCK", subdiv=2, colfn=mossy, lumps=0.2, seed=3, smooth=True)
    m.ico(0.18, pos=(0.35, -0.55, 0.05), color="ROCK_DARK", subdiv=2, lumps=0.2, seed=4, smooth=True)
    m.export(OUT)


def build_rock_small():
    m = Model("rock_small", 11)

    def mossy(f):
        return "MOSS" if f.normal.z > 0.82 else "ROCK"
    m.ico(0.4, pos=(0, 0, 0.12), scl=(1.2, 1.0, 0.75), color="ROCK", subdiv=2, colfn=mossy, lumps=0.2, seed=5, smooth=True)
    m.export(OUT)


def build_fern():
    """Fan of arching fronds; each frond = one serrated ribbon (leaflet tips alternate wide/narrow)."""
    m = Model("fern", 12)
    n = 8
    for i in range(n):
        a = i * math.tau / n + 0.2 + (0.15 if i % 2 else 0)
        ln = 0.8 + 0.14 * (i % 3)
        d = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-d.y, d.x, 0))
        K = 9
        left, right = [], []
        for k in range(K + 1):
            t = k / K
            spine = Vector((0, 0, 0.04)) + d * ln * t + Vector((0, 0, 0.45 * math.sin(math.pi * t * 0.8)))
            w = 0.2 * math.sin(math.pi * min(1.0, t * 1.1)) * (1.0 if k % 2 else 0.55) + 0.01
            left.append(spine + side * w)
            right.append(spine - side * w)
        col = mix("FERN", "LEAF_TOP", 0.35 if i % 2 else 0.15)
        bm = m._bm("body_nh")
        for flip in (False, True):
            vl = [bm.verts.new(p) for p in left]
            vr = [bm.verts.new(p) for p in right]
            faces = []
            for k in range(K):
                q = (vl[k], vr[k], vr[k + 1], vl[k + 1])
                faces.append(bm.faces.new(tuple(reversed(q)) if flip else q))
            m._finish(bm, faces, col if not flip else shade(col, 0.85), False)
    m.export(OUT)


def build_clover():
    m = Model("clover", 13)
    rng = m.rng
    for i in range(7):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0, 0.28)
        cx, cy = math.cos(a) * d, math.sin(a) * d
        z = 0.06 + rng.uniform(0, 0.06)
        c = "CLOVER" if i % 3 else shade("CLOVER", 0.86)
        for k in range(3):
            b = k * math.tau / 3 + a
            m.sphere(0.075, pos=(cx + math.cos(b) * 0.065, cy + math.sin(b) * 0.065, z), scl=(1, 1, 0.35), color=c,
                     seg=7, rings=3, group="body_nl")
    m.export(OUT)


def build_tuft():
    m = Model("tuft", 14)
    rng = m.rng
    for i in range(6):
        a = -0.9 + i * 0.36 + rng.uniform(-0.1, 0.1)
        b = rng.uniform(0, math.tau)
        h = rng.uniform(0.26, 0.42)
        base = Vector((math.cos(b) * 0.04, math.sin(b) * 0.04, 0))
        tip = base + Vector((math.sin(a) * 0.2, math.cos(b) * 0.06, h))
        m.blade(base, tip, 0.07, color="TUFT" if i % 2 else shade("TUFT", 1.12))
    m.export(OUT)


def build_lily():
    m = Model("lily", 15)
    for (x, y, r, c) in ((0, 0, 0.3, "LILY"), (0.48, 0.22, 0.22, shade("LILY", 1.1)), (-0.2, 0.46, 0.18, "LILY"),
                         (0.3, -0.38, 0.16, shade("LILY", 1.05))):
        seg = 12
        bm = m._bm("body")
        cen = bm.verts.new((x, y, 0.02))
        ring = []
        for i in range(seg + 1):                 # pie with a notch
            a = 0.35 + i / seg * (math.tau - 0.5)
            ring.append(bm.verts.new((x + math.cos(a) * r, y + math.sin(a) * r, 0.02)))
        faces = [bm.faces.new((cen, ring[i], ring[i + 1])) for i in range(seg)]
        bm.normal_update()
        for f in faces:
            if f.normal.z < 0:
                f.normal_flip()
        m._finish(bm, faces, c, False)
    m.export(OUT)


def build_lotus():
    m = Model("lotus", 16)
    m.cyl(0.32, 0.32, 0.02, color="LILY", seg=12)
    for ring, (n, rr, tilt, h, c) in enumerate(((6, 0.1, 0.75, 0.24, "LOTUS"), (5, 0.04, 0.35, 0.22, shade("LOTUS", 1.08)))):
        for i in range(n):
            a = i * math.tau / n + ring * 0.5
            m.sphere(0.075, pos=(math.cos(a) * rr, math.sin(a) * rr, 0.12), scl=(1, 0.6, h / 0.15),
                     rot=(0, tilt, a), color=c, seg=6, rings=4)
    m.sphere(0.05, pos=(0, 0, 0.2), color="FLAME2", seg=6, rings=3)
    m.export(OUT)


def build_log():
    m = Model("log", 17)
    L, r = 1.6, 0.2
    m.cyl(r, r * 0.9, L, pos=(-L / 2, 0, r), rot=(0, math.pi / 2, 0), color="TRUNK", seg=8, smooth=True,
          cap="STUMP_TOP", bottom_cap="STUMP_TOP")
    m.cyl(0.07, 0.04, 0.35, pos=(0.1, 0.1, r * 1.6), rot=(-0.6, 0.2, 0), color="TRUNK", seg=5)       # branch stub
    for (x, s) in ((-0.3, 1.0), (0.35, 0.8)):
        m.sphere(0.2 * s, pos=(x, 0, r * 1.75), scl=(1.4, 1.0, 0.45), color="MOSS", seg=8, rings=4)
    m.sphere(0.07, pos=(0.62, 0.15, 0.38), scl=(1, 1, 0.6), color="MUSHROOM_CAP", seg=6, rings=3)
    m.export(OUT)


def build_reeds():
    m = Model("reeds", 18)
    rng = m.rng
    for i in range(9):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0, 0.25)
        base = Vector((math.cos(a) * d, math.sin(a) * d, -0.1))
        h = rng.uniform(0.6, 0.95)
        lean = Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), h))
        m.blade(base, base + lean, 0.05, color="REED" if i % 2 else shade("REED", 0.88))
        if i % 3 == 0:
            m.cyl(0.035, 0.035, 0.16, pos=base + lean * 0.86, color="REED_HEAD", seg=5, group="body_nl")
    m.export(OUT)


if __name__ == "__main__":
    print("nature ->", OUT)
    build_trees()
    build_conifer()
    build_bush()
    build_bush_flower()
    build_stump()
    build_sapling()
    build_mushrooms()
    build_rocks()
    build_rock_small()
    build_fern()
    build_clover()
    build_tuft()
    build_lily()
    build_lotus()
    build_log()
    build_reeds()
