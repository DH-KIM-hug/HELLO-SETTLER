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
import flora_far  # noqa: E402

OUT = out_dir_from_argv()

## Far LOD of the small ground clutter ("body__far", flora_far.py — P1 perf pass 3): FloraBatch swaps it in below ppu 24.
## Target triangles (near: bush 400, bush_b 320, bush_flower 520, bush_berry 420, mushrooms 1160, fern 288, clover 588,
## flowers 328, flowers_b 328).
FAR_TARGET = {"bush": 110, "bush_b": 96, "bush_flower": 130, "bush_berry": 110, "mushrooms": 180, "fern": 96,
              "clover": 90, "flowers": 100, "flowers_b": 100}


def export(m):
    m.export(OUT, far=flora_far.decimated(FAR_TARGET[m.name]) if m.name in FAR_TARGET else None)


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
    m.cyl(r_bot * 1.15, r_bot, 0.25, color="TRUNK", seg=8, smooth=True)          # flared foot
    m.cyl(r_bot, r_top, h, pos=(0, 0, 0.2), color="TRUNK", seg=8, smooth=True, cap="TRUNK_DARK", rot=(lean[0], lean[1], 0))
    rng = m.rng
    for i in range(roots):                       # root flare: arching wedges radiating out, sinking into the grass
        a = i * math.tau / roots + rng.uniform(-0.3, 0.3)
        ln = rng.uniform(0.36, 0.5)
        m.cyl(r_bot * 0.62, 0.04, ln, pos=(math.cos(a) * r_bot * 0.6, math.sin(a) * r_bot * 0.6, 0.12),
              rot=(0, math.pi / 2 - 0.7, a), color=shade("TRUNK", 0.94 if i % 2 else 1.0), seg=5, smooth=True)
    return h


def branch(m, base, direction, ln, r):
    d = Vector(direction).normalized()
    pitch = math.acos(max(-1, min(1, d.z)))
    yaw = math.atan2(d.y, d.x)
    m.cyl(r, r * 0.6, ln, pos=base, rot=(0, pitch, yaw), color="TRUNK", seg=5, smooth=True)


def blob_col(z, low_z, top_z, k=0):
    """Per-blob colour (cel look: one flat colour per leaf clump, the toon terminator does the rest).
    High clumps light mint, middle teal, low/rim clumps dark teal; k nudges the shade so neighbours differ."""
    h = (z - low_z) / max(0.01, top_z - low_z)
    base = "LEAF_TOP" if h > 0.62 else ("LEAF_MID" if h > 0.25 else "LEAF_LOW")
    return shade(base, (1.0, 0.96, 1.04)[k % 3])


def broadleaf(name, seed, blobs, height=1.9, spread=1.15, top=3.2, lift=0.75, roots=5, rim=11, trunk_r=0.3):
    """Cloud canopy = clusters of smooth round clumps, each one flat colour (light on top, teal, dark teal rim),
    so the canopy reads like the concept art's stacked leaf clouds. blobs = [(x, y, z, r)] in canopy space."""
    m = Model(name, seed)
    rng = m.rng
    # the camera looks down 60 deg: the canopy must sit high (lift) so trunk + roots show below its front rim
    height += lift
    top += lift
    blobs = [(x, y, z + lift, r) for (x, y, z, r) in blobs]
    trunk(m, height + 0.4, trunk_r, trunk_r * 0.6, roots=roots)
    for a in (0.4, 2.5, 4.4):
        branch(m, (0, 0, height * 0.8), (math.cos(a), math.sin(a), 1.1), 0.8, 0.09)
    zs = [z for (_, _, z, _) in blobs]
    low_z = min(zs) - 0.5
    top_z = max(zs) + 0.2
    for i, (x, y, z, r) in enumerate(blobs):
        m.ico(r, pos=(x * spread, y * spread, z), scl=(1.0, 1.0, 0.82), color=blob_col(z, low_z, top_z, i), subdiv=2,
              smooth=True, lumps=0.08, lump_scale=1.4, group="body_nl")
    # small rim clumps -> scalloped edge seen from above (dark teal underside of the cloud)
    for i in range(rim):
        a = i * math.tau / rim + rng.uniform(-0.15, 0.15)
        d = spread * rng.uniform(1.18, 1.34)
        r = rng.uniform(0.34, 0.44)
        z = height + 0.5 + rng.uniform(-0.05, 0.25)
        m.ico(r, pos=(math.cos(a) * d, math.sin(a) * d, z), scl=(1, 1, 0.82),
              color=shade("LEAF_MID" if i % 3 == 0 else "LEAF_LOW", 1.0 + 0.04 * (i % 2)), subdiv=2, smooth=True,
              lumps=0.08, group="body_nl")
    export(m)


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
    # D: old oak - thick trunk with big roots, one big dome of clumps (the concept's round cloud trees)
    broadleaf("tree_d", 4, [
        (0, 0, 2.9, 1.15), (0.85, 0.2, 2.55, 0.8), (-0.85, 0.25, 2.55, 0.8), (0.3, -0.85, 2.5, 0.78),
        (-0.4, -0.75, 2.6, 0.75), (0.2, 0.85, 2.6, 0.78), (-0.15, -0.2, 3.6, 0.78), (0.55, 0.3, 3.4, 0.62),
        (-0.6, 0.2, 3.35, 0.6)], height=1.8, spread=1.15, top=3.3, roots=6, rim=12, trunk_r=0.38)


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
    export(m)


def _drop_hidden(m, blobs, owned, margin=0.9):
    """(P1 perf pass 4) Faces no one can see: wholly under the ground (z < -0.05) or wholly inside another blob of the
    same bush (every vertex within margin x that blob's squashed sphere). The holes stay hidden inside the neighbour;
    the group is body_nl (no crease lines) so open edges draw nothing."""
    import bmesh
    bm = m.groups["body_nl"]

    def inside(co, j):
        x, y, z, r = blobs[j]
        return ((co.x - x) / r) ** 2 + ((co.y - y) / r) ** 2 + ((co.z - z) / (r * 0.85)) ** 2 < margin ** 2
    kill = []
    for own, faces in enumerate(owned):
        for f in faces:
            if all(v.co.z < -0.05 for v in f.verts) or any(
                    j != own and all(inside(v.co, j) for v in f.verts) for j in range(len(blobs))):
                kill.append(f)
    if kill:
        bmesh.ops.delete(bm, geom=kill, context="FACES")

def _bush(name, seed, blobs, flowers=0, fcols=("LOTUS", "PLASTER", "FLAME2")):
    m = Model(name, seed)
    zs = [z for (_, _, z, _) in blobs]
    lo, hi = min(zs) - 0.25, max(zs) + 0.05
    owned = []
    for i, (x, y, z, r) in enumerate(blobs):
        h = (z - lo) / (hi - lo)
        c = "BUSH_TOP" if h > 0.75 else ("BUSH" if h > 0.35 else mix("BUSH", "LEAF_LOW", 0.5))
        # (P1 perf pass 4) 48-tri lumpy UV blob (was an 80-tri icosphere) + hidden faces dropped below
        owned.append(m.sphere(r, pos=(x, y, z), scl=(1, 1, 0.85), color=shade(c, (1.0, 0.96, 1.04)[i % 3]), seg=8,
                              rings=4, smooth=True, lumps=0.1, group="body_nl"))
    _drop_hidden(m, blobs, owned)
    rng = m.rng
    for i in range(flowers):
        x, y, z, r = blobs[i % len(blobs)]
        a = rng.uniform(0, math.tau)
        el = rng.uniform(0.35, 1.1)
        p = Vector((x, y, z)) + Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el) * 0.85)) * r
        if p.z < 0.15:
            continue
        m.sphere(0.075, pos=p, scl=(1, 1, 0.7), color=fcols[i % len(fcols)], seg=4, rings=2, group="body_nl")
    export(m)


def build_bush():
    _bush("bush", 5, [(0, 0, 0.32, 0.42), (0.42, 0.15, 0.25, 0.33), (-0.36, 0.2, 0.24, 0.32), (0.1, -0.35, 0.22, 0.3),
                      (0.05, 0.1, 0.6, 0.28)])
    _bush("bush_b", 25, [(0, 0, 0.26, 0.34), (0.3, -0.1, 0.2, 0.26), (-0.28, 0.05, 0.22, 0.27), (0.02, 0.05, 0.5, 0.22)])


def build_bush_flower():
    _bush("bush_flower", 6, [(0, 0, 0.28, 0.36), (0.38, 0.1, 0.22, 0.3), (-0.3, 0.18, 0.22, 0.28), (0.05, 0.05, 0.5, 0.22)],
          flowers=10)
    _bush("bush_berry", 26, [(0, 0, 0.3, 0.36), (0.32, 0.2, 0.22, 0.28), (-0.3, -0.1, 0.22, 0.28)], flowers=9,
          fcols=("a8322c", "c94a3a", "a8322c"))


def build_flowers():
    """Wildflower patch: leafy tufts with round blossoms (pink / white / yellow / lilac)."""
    for name, seed, cols in (("flowers", 31, ("LOTUS", "PLASTER", "FLAME2")), ("flowers_b", 32, ("b8a6e0", "PLASTER", "8fc6e8"))):
        m = Model(name, seed)
        rng = m.rng
        for i in range(8):
            a = rng.uniform(0, math.tau)
            d = rng.uniform(0.05, 0.38)
            base = Vector((math.cos(a) * d, math.sin(a) * d, 0))
            h = rng.uniform(0.3, 0.5)
            tip = base + Vector((rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), h))
            m.blade(base, tip, 0.035, color=shade("TUFT", 0.9))
            m.sphere(0.095, pos=tip, scl=(1, 1, 0.6), color=cols[i % len(cols)], seg=6, rings=3, group="body_nl")
            m.sphere(0.04, pos=tip + Vector((0, 0, 0.05)), color="FLAME2" if cols[i % len(cols)] != "FLAME2" else "e09a16",
                     seg=4, rings=2, group="body_nl")
        for k in range(4):
            a = k * 1.7
            m.blade((math.cos(a) * 0.05, math.sin(a) * 0.05, 0), (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.2), 0.1,
                    color="TUFT" if k % 2 else shade("TUFT", 1.1))
        export(m)


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
    export(m)


def build_sapling():
    m = Model("sapling", 8)
    m.cyl(0.05, 0.035, 0.7, color="TRUNK", seg=5)
    col = canopy_col(1.1, 0.5)
    for (x, y, z, r) in ((0, 0, 0.85, 0.32), (0.2, 0.1, 0.7, 0.22), (-0.18, -0.08, 0.72, 0.22)):
        m.ico(r, pos=(x, y, z), color="LEAF_YOUNG", subdiv=1, smooth=True, colfn=col, lumps=0.15, group="body_nl")
    export(m)


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
    export(m)


def build_rocks():
    m = Model("rocks", 10)

    def mossy(f):
        return "MOSS" if f.normal.z > 0.72 else ("ROCK" if f.normal.z > -0.2 else "ROCK_DARK")
    m.ico(0.62, pos=(0, 0, 0.3), scl=(1.15, 1.0, 0.85), color="ROCK", subdiv=2, colfn=mossy, lumps=0.18, seed=1, smooth=True)
    m.ico(0.42, pos=(0.75, 0.3, 0.18), scl=(1.0, 1.0, 0.8), color="ROCK", subdiv=2, colfn=mossy, lumps=0.2, seed=2, smooth=True)
    m.ico(0.3, pos=(-0.62, 0.42, 0.1), scl=(1.0, 1.0, 0.75), color="ROCK", subdiv=2, colfn=mossy, lumps=0.2, seed=3, smooth=True)
    m.ico(0.18, pos=(0.35, -0.55, 0.05), color="ROCK_DARK", subdiv=2, lumps=0.2, seed=4, smooth=True)
    export(m)


def build_rocks_b():
    """Two tall rounded boulders leaning together + pebbles (the concept's grey boulder pairs)."""
    m = Model("rocks_b", 19)

    def mossy(f):
        return "MOSS" if f.normal.z > 0.8 else ("ROCK" if f.normal.z > -0.2 else "ROCK_DARK")
    m.ico(0.55, pos=(-0.2, 0.1, 0.42), scl=(0.95, 0.85, 1.25), rot=(0.12, -0.2, 0.3), color="ROCK", subdiv=2, colfn=mossy,
          lumps=0.12, seed=7, smooth=True)
    m.ico(0.42, pos=(0.45, -0.12, 0.28), scl=(1.0, 0.9, 1.05), rot=(0, 0.25, 0.8), color="ROCK", subdiv=2, colfn=mossy,
          lumps=0.14, seed=8, smooth=True)
    for (x, y, r) in ((0.85, 0.3, 0.13), (-0.7, -0.35, 0.11), (0.2, -0.6, 0.09)):
        m.ico(r, pos=(x, y, 0.03), scl=(1.2, 1, 0.7), color=shade("ROCK", 1.05), subdiv=1, smooth=True)
    export(m)


def build_rock_small():
    m = Model("rock_small", 11)

    def mossy(f):
        return "MOSS" if f.normal.z > 0.82 else "ROCK"
    m.ico(0.4, pos=(0, 0, 0.12), scl=(1.2, 1.0, 0.75), color="ROCK", subdiv=2, colfn=mossy, lumps=0.2, seed=5, smooth=True)
    export(m)


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
    export(m)


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
    export(m)


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
    export(m)


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
    export(m)


def build_lotus():
    m = Model("lotus", 16)
    m.cyl(0.32, 0.32, 0.02, color="LILY", seg=12)
    for ring, (n, rr, tilt, h, c) in enumerate(((6, 0.1, 0.75, 0.24, "LOTUS"), (5, 0.04, 0.35, 0.22, shade("LOTUS", 1.08)))):
        for i in range(n):
            a = i * math.tau / n + ring * 0.5
            m.sphere(0.075, pos=(math.cos(a) * rr, math.sin(a) * rr, 0.12), scl=(1, 0.6, h / 0.15),
                     rot=(0, tilt, a), color=c, seg=6, rings=4)
    m.sphere(0.05, pos=(0, 0, 0.2), color="FLAME2", seg=6, rings=3)
    export(m)


def build_log():
    m = Model("log", 17)
    L, r = 1.6, 0.2
    m.cyl(r, r * 0.9, L, pos=(-L / 2, 0, r), rot=(0, math.pi / 2, 0), color="TRUNK", seg=8, smooth=True,
          cap="STUMP_TOP", bottom_cap="STUMP_TOP")
    m.cyl(0.07, 0.04, 0.35, pos=(0.1, 0.1, r * 1.6), rot=(-0.6, 0.2, 0), color="TRUNK", seg=5)       # branch stub
    for (x, s) in ((-0.3, 1.0), (0.35, 0.8)):
        m.sphere(0.2 * s, pos=(x, 0, r * 1.75), scl=(1.4, 1.0, 0.45), color="MOSS", seg=8, rings=4)
    m.sphere(0.07, pos=(0.62, 0.15, 0.38), scl=(1, 1, 0.6), color="MUSHROOM_CAP", seg=6, rings=3)
    export(m)


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
    export(m)


if __name__ == "__main__":
    print("nature ->", OUT)
    build_trees()
    build_conifer()
    build_bush()
    build_bush_flower()
    build_flowers()
    build_stump()
    build_sapling()
    build_mushrooms()
    build_rocks()
    build_rock_small()
    build_rocks_b()
    build_fern()
    build_clover()
    build_tuft()
    build_lily()
    build_lotus()
    build_log()
    build_reeds()
