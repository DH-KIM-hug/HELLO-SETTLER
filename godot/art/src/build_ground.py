"""Ground-cover decals (ROADMAP A13 prep): very low-poly patches laid on the terrain by ground type.
  gc_moss_a/b/c        moss cushions (damp shade, forest floor)
  gc_shore_a/b/c       sand + pebble shore patches (lake / river banks)
  gc_mud_a/b           mud with a wet puddle (marsh, trampled ground)
  gc_leaves_a/b/c      leaf litter (forest floor, autumn)
  gc_pathstones_a/b/c  flat stepping stones for dirt paths
Origin = patch centre on the ground; flat parts sit 0.01-0.03 above it (no z-fighting with the terrain).
Flat patches are "body_nh" (no outline, they would look like stickers), raised bits (pebbles, stones) get outlines.
Run: blender -b --factory-startup --python build_ground.py -- [out_dir]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, out_dir_from_argv  # noqa: E402

OUT = out_dir_from_argv()
SAND = "e9dcae"
SAND_WET = "cdbf8f"
MUD = "9a7654"
MUD_WET = "6e5642"
LEAF_COLS = ("e3a24f", "c97a3f", "d9b25a", "a9b05a", "b8794e")


def blob(m, r, n=10, z=0.015, wob=0.28, seed=0, col="MOSS", ox=0.0, oy=0.0, sx=1.0, sy=1.0, rim=None,
         group="body_nh"):
    """Irregular flat patch: centre vertex + a noisy ring (slightly lower) -> a soft low mound. rim = colour of
    the outer ring of faces (two-tone edge)."""
    rnd = random.Random(seed)
    bm = m._bm(group)
    radii = [r * (1 + rnd.uniform(-wob, wob)) for _ in range(n)]
    radii = [(radii[i - 1] + 2 * radii[i] + radii[(i + 1) % n]) / 4 for i in range(n)]
    c = bm.verts.new((ox, oy, z + 0.012))
    mid = [bm.verts.new((ox + math.cos(i / n * math.tau) * radii[i] * 0.62 * sx,
                         oy + math.sin(i / n * math.tau) * radii[i] * 0.62 * sy, z + 0.006)) for i in range(n)]
    out = [bm.verts.new((ox + math.cos(i / n * math.tau) * radii[i] * sx,
                         oy + math.sin(i / n * math.tau) * radii[i] * sy, z)) for i in range(n)]
    inner = [bm.faces.new((c, mid[i], mid[(i + 1) % n])) for i in range(n)]
    outer = [bm.faces.new((mid[i], out[i], out[(i + 1) % n], mid[(i + 1) % n])) for i in range(n)]
    bm.normal_update()
    m._finish(bm, inner, col, False)
    m._finish(bm, outer, rim or col, False)
    return inner + outer


def pebble(m, x, y, s, col, seed):
    m.ico(s, pos=(x, y, s * 0.3), scl=(1.3, 1.0, 0.65), color=col, subdiv=1, smooth=True, lumps=0.15, seed=seed)


def build_moss(name, seed, cushions):
    m = Model(name, seed)
    rnd = random.Random(seed)
    blob(m, 0.65, 11, seed=seed, col=shade("MOSS", 0.88), rim=mix("MOSS", "b9d687", 0.55))
    for k in range(cushions):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(0.0, 0.38)
        r = rnd.uniform(0.1, 0.18)
        m.sphere(r, pos=(math.cos(a) * d, math.sin(a) * d, 0.0), scl=(1.2, 1.0, 0.6),
                 color=mix("MOSS", "LEAF_TOP", (0.0, 0.3, 0.55)[k % 3]), seg=6, rings=3, lumps=0.2, group="body_nl")
    m.export(OUT)


def build_shore(name, seed, pebbles, stretch=1.0):
    m = Model(name, seed)
    rnd = random.Random(seed)
    blob(m, 0.7, 12, seed=seed, col=SAND, rim=mix(SAND, "b9d687", 0.45), sx=stretch, sy=1.0 / stretch ** 0.5)
    blob(m, 0.32, 8, z=0.02, seed=seed + 1, col=SAND_WET, oy=-0.22, ox=0.1, sx=stretch * 1.3)
    cols = ("ROCK", shade("ROCK", 1.1), "ROCK_DARK", mix("ROCK", SAND, 0.4))
    for k in range(pebbles):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(0.1, 0.55)
        pebble(m, math.cos(a) * d * stretch, math.sin(a) * d * 0.8, rnd.uniform(0.06, 0.12), cols[k % 4], seed + k)
    m.export(OUT)


def build_mud(name, seed, prints):
    m = Model(name, seed)
    rnd = random.Random(seed)
    blob(m, 0.7, 11, seed=seed, col=MUD, rim=mix(MUD, "93b27a", 0.6), sx=1.2)
    blob(m, 0.28, 8, z=0.022, seed=seed + 2, col=mix(MUD_WET, "6cc6d0", 0.5), rim=mix(MUD_WET, "6cc6d0", 0.25),
         ox=-0.15, oy=0.08, sx=1.4)
    blob(m, 0.12, 6, z=0.026, seed=seed + 3, col=mix(MUD_WET, "e2f6f5", 0.35), ox=-0.22, oy=0.12, sx=1.3)  # sky glint
    for k in range(prints):      # little footprints / hoof dents (darker ovals)
        x = 0.15 + k * 0.17
        y = -0.15 + (0.08 if k % 2 else -0.05)
        blob(m, 0.05, 5, z=0.024, seed=seed + 10 + k, wob=0.1, col=shade(MUD, 0.78), ox=x, oy=y, sx=0.7)
    for k in range(3):
        a = rnd.uniform(0, math.tau)
        pebble(m, math.cos(a) * 0.55, math.sin(a) * 0.4, 0.05, "ROCK_DARK", seed + k)
    m.export(OUT)


def build_leaves(name, seed, n, twig=True):
    m = Model(name, seed)
    rnd = random.Random(seed)
    blob(m, 0.6, 10, z=0.01, seed=seed, col=mix("8a6a4a", "b9d687", 0.55), rim=mix("8a6a4a", "b9d687", 0.75))
    bm = m._bm("body_nh")
    for k in range(n):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(0.0, 0.55) ** 0.8
        cx, cy = math.cos(a) * d, math.sin(a) * d
        rz = rnd.uniform(0, math.tau)
        ln, w = rnd.uniform(0.09, 0.14), rnd.uniform(0.045, 0.07)
        z = 0.025 + 0.003 * k / n
        c, s = math.cos(rz), math.sin(rz)
        pts = [(-ln, 0, 0.0), (0, -w, 0.01), (ln, 0, 0.02), (0, w, 0.01)]
        vs = [bm.verts.new((cx + px * c - py * s, cy + px * s + py * c, z + pz)) for px, py, pz in pts]
        f = bm.faces.new(vs)
        if f.normal.z < 0:
            f.normal_flip()
        m._finish(bm, [f], LEAF_COLS[rnd.randrange(len(LEAF_COLS))], False)
    if twig:
        m.cyl(0.015, 0.01, 0.45, pos=(-0.2, -0.1, 0.03), rot=(0, math.pi / 2, 0.5), color="TRUNK", seg=4)
        m.cyl(0.01, 0.006, 0.15, pos=(-0.05, 0.0, 0.03), rot=(0, math.pi / 2, 1.3), color="TRUNK", seg=4)
    m.export(OUT)


def build_pathstones(name, seed, stones):
    m = Model(name, seed)
    stone = mix("e0cf9c", "b9c0bd", 0.45)
    for k, (x, y, r, rz) in enumerate(stones):
        m.cyl(r, r * 0.92, 0.045, pos=(x, y, 0.0), rot=(0, 0, rz), color=shade(stone, 0.86), seg=7,
              cap=shade(stone, (1.0, 1.06, 0.95)[k % 3]), scl=(1.25, 1.0, 1.0))
        if k % 2 == 0:
            m.blade((x + r * 1.1, y, 0.0), (x + r * 1.2, y + 0.03, 0.12), 0.05, color="TUFT")
    m.export(OUT)


if __name__ == "__main__":
    print("ground cover ->", OUT)
    build_moss("gc_moss_a", 301, 4)
    build_moss("gc_moss_b", 302, 2)
    build_moss("gc_moss_c", 303, 6)
    build_shore("gc_shore_a", 311, 6)
    build_shore("gc_shore_b", 312, 3, 1.4)
    build_shore("gc_shore_c", 313, 9, 0.85)
    build_mud("gc_mud_a", 321, 3)
    build_mud("gc_mud_b", 322, 0)
    build_leaves("gc_leaves_a", 331, 14)
    build_leaves("gc_leaves_b", 332, 9, False)
    build_leaves("gc_leaves_c", 333, 20)
    build_pathstones("gc_pathstones_a", 341, ((-0.3, -0.2, 0.17, 0.2), (0.15, 0.1, 0.15, 1.0), (0.55, 0.3, 0.13, 0.5)))
    build_pathstones("gc_pathstones_b", 342, ((-0.4, 0.0, 0.14, 0.4), (0.0, -0.05, 0.18, 1.3), (0.4, 0.05, 0.13, 2.0),
                                              (0.15, 0.32, 0.09, 0.0)))
    build_pathstones("gc_pathstones_c", 343, ((0.0, 0.0, 0.2, 0.7), (-0.32, 0.22, 0.1, 0.1)))
