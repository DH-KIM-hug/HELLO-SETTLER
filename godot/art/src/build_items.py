"""Village altar + giant-scale things that come from the sky (WORLD_EVENTS 4.4, 1.x, SHOP): nutrient ampoule tower,
vein-stone hills (iron / coal / gold / rock salt), sugar cube, a fallen giant wheat stalk.
Scale: 1 unit = 1 cell, an adult resident is about 1.0 tall. Front = -Y (towards the camera).
Run: blender -b --factory-startup --python build_items.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, out_dir_from_argv  # noqa: E402
import bmesh  # noqa: E402

OUT = out_dir_from_argv()
GLASS = "d6eef0"
GLASS_EDGE = "a9d3d8"
POTION = "7cc66a"


def build_altar():
    """Small stone altar beside the fire (GAME_DESIGN 11.1): two rough slabs, a carved top with a sun mark,
    moss at the foot, two little candles. Footprint ~0.8 x 0.55 like the old box altar; offerings sit at z ~0.42."""
    m = Model("altar", 501)

    def mossy(f):
        return "MOSS" if f.normal.z > 0.85 else None
    m.ico(0.5, pos=(0, 0, 0.1), scl=(0.95, 0.62, 0.32), color="STONE_DARK", subdiv=2, lumps=0.12, seed=3, smooth=True)
    m.box((0.66, 0.44, 0.16), pos=(0, 0, 0.18), rot=(0, 0, 0.04), color="STONE",
          colfn=lambda f: shade("STONE", 1.06) if f.normal.z > 0.7 else "STONE")
    m.box((0.72, 0.5, 0.06), pos=(0, 0, 0.34), color=shade("STONE", 1.08),
          colfn=lambda f: shade("STONE", 1.12) if f.normal.z > 0.7 else shade("STONE", 0.95))
    # sun mark carved on the front
    m.cyl(0.07, 0.07, 0.02, pos=(0, -0.235, 0.26), rot=(math.pi / 2, 0, 0), color="FLAME2", seg=10)
    for k in range(8):
        a = k * math.tau / 8
        m.box((0.02, 0.015, 0.05), pos=(math.cos(a) * 0.11, -0.24, 0.26 + math.sin(a) * 0.11 - 0.025),
              rot=(0, -a + math.pi / 2, 0), color="FLAME2")
    for (x, y, s) in ((-0.42, -0.2, 1.0), (0.4, 0.15, 0.8), (0.3, -0.27, 0.6)):
        m.sphere(0.12 * s, pos=(x, y, 0.02), scl=(1.4, 1.0, 0.45), color="MOSS", seg=7, rings=3, lumps=0.2, group="body_nl")
    for x in (-0.27, 0.27):
        m.cyl(0.035, 0.035, 0.12, pos=(x, 0.14, 0.4), color="PLASTER", seg=6)
        m.sphere(0.025, pos=(x, 0.14, 0.55), scl=(1, 1, 1.6), color="FLAME2", seg=5, rings=3, group="body_nl")
    m.export(OUT)


def build_ampoule():
    """Upside-down nutrient ampoule stuck in the ground: a clear tower ~20 residents tall, green potion inside.
    Toon look: the 'glass' is an opaque pale cyan shell with white highlight stripes; the potion shows as a green
    column through a wide window band. Origin = where it enters the ground."""
    m = Model("ampoule_tower", 502)
    H = 20.0
    prof = [(0.05, -0.3), (0.35, 0.0), (0.6, 1.2), (0.75, 2.4), (1.6, 4.0), (1.75, 5.0), (1.75, 15.5), (1.6, 16.6),
            (1.0, 17.2), (1.0, 19.0), (1.15, 19.2), (1.15, H), (0.0001, H)]
    seg = 20
    rings = [[Vector((math.cos(i * math.tau / seg) * r, math.sin(i * math.tau / seg) * r, z)) for i in range(seg)]
             for (r, z) in prof]
    fs = m.strip(rings, color=GLASS, close=True, smooth=True)
    bm = m._bm("body")
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    bm.normal_update()
    level = 12.5           # potion level (it slowly sinks - the view may scale this later)
    for f in fs:
        c = f.calc_center_median()
        a = math.atan2(c.y, c.x)
        stripe = abs(((a + 2.3) % math.tau) - 0.0) < 0.3 or abs(((a + 2.0) % math.tau) - 0.0) < 0.08
        if c.z > 17.1:
            col = "f2f2ea" if c.z < 19.1 else "e8e4d8"          # the cap (white plastic)
        elif c.z < level and c.z > 0.4:
            col = mix(POTION, GLASS, 0.25) if not stripe else mix(POTION, "ffffff", 0.55)
        else:
            col = GLASS if not stripe else "ffffff"
        m._finish(bm, [f], col, True)
    # potion surface ring + scale marks
    m.cyl(1.74, 1.74, 0.05, pos=(0, 0, level), color=mix(POTION, "ffffff", 0.3), seg=seg)
    for k in range(5):
        z = 6.0 + k * 2.0
        m.box((0.5 if k % 2 else 0.8, 0.04, 0.08), pos=(-0.3, -1.76, z), color=GLASS_EDGE)
    # label band
    m.cyl(1.78, 1.78, 2.2, pos=(0, 0, 13.6), color="f6f1e2", seg=seg, smooth=True,
          colfn=lambda f: "6fbf5f" if abs(f.calc_center_median().z - 14.7) < 0.35 else "f6f1e2")
    # soil heaved round the tip
    m.ico(1.6, pos=(0, 0, -0.35), scl=(1.0, 1.0, 0.35), color="FIELD_SOIL", subdiv=2, lumps=0.2, smooth=True)
    for k in range(6):
        a = k * math.tau / 6 + 0.3
        m.ico(0.32, pos=(math.cos(a) * 1.7, math.sin(a) * 1.7, 0.02), color=shade("FIELD_SOIL", 0.9), subdiv=1,
              lumps=0.2, smooth=True)
    m.export(OUT)


VEINS = {"iron": ("8a8f96", "b9bec4"), "coal": ("2f3033", "55575c"), "gold": ("e3b23c", "fff0a0"),
         "salt": ("f4f2ea", "ffffff")}


def build_vein_hills():
    """A rocky knoll with an exposed ore seam (GAME_DESIGN 4: veins). One per ore - same hill, different seam."""
    for kind, (c, hi) in VEINS.items():
        m = Model("vein_hill_" + kind, 510 + len(kind))

        def grass(f):
            return "GRASS_RIDGE" if f.normal.z > 0.75 else ("ROCK" if f.normal.z > -0.1 else "ROCK_DARK")
        m.ico(2.0, pos=(0, 0, -0.4), scl=(1.25, 1.0, 0.62), color="ROCK", subdiv=2, colfn=grass, lumps=0.14, seed=4,
              smooth=False)
        m.ico(1.0, pos=(1.4, 0.6, -0.2), scl=(1.0, 0.9, 0.7), color="ROCK", subdiv=2, colfn=grass, lumps=0.18, seed=5)
        # the seam: chunky crystals / lumps breaking out of the front face
        rng = m.rng
        for k in range(9):
            t = k / 8
            x = -1.6 + 2.6 * t + rng.uniform(-0.1, 0.1)
            z = 0.25 + 0.55 * math.sin(t * math.pi) + rng.uniform(-0.1, 0.1)
            y = -1.55 + 0.35 * math.sin(t * math.pi) + rng.uniform(-0.1, 0.05)
            s = rng.uniform(0.18, 0.3)
            if kind in ("gold", "salt"):
                m.cyl(s * 0.6, 0.0, s * 2.2, pos=(x, y, z - 0.1), rot=(rng.uniform(-0.6, -0.2), rng.uniform(-0.4, 0.4), 0),
                      color=c if k % 2 else hi, seg=5)
            else:
                m.ico(s, pos=(x, y, z), color=c if k % 3 else hi, subdiv=1, lumps=0.2)
        for k in range(4):          # loose chips at the foot
            m.ico(0.12, pos=(rng.uniform(-1.5, 1.5), rng.uniform(-2.3, -1.9), 0.04), color=c, subdiv=1)
        m.export(OUT)


def build_sugar_cube():
    """A giant sugar cube (house-sized white sweet rock): bevelled cube, sparkling grain facets, a few crumbs."""
    m = Model("sugar_cube", 520)
    S = 2.6
    bm = m._bm("body")
    r = bmesh.ops.create_cube(bm, size=S)
    bmesh.ops.bevel(bm, geom=r["verts"] + list({e for v in r["verts"] for e in v.link_edges}), offset=0.18, segments=2,
                    affect="EDGES", profile=0.5)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((0, 0, S / 2 - 0.05)))
    bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)),
                     matrix=__import__("mathutils").Matrix.Rotation(0.2, 3, "Z"))
    bm.normal_update()
    m._finish(bm, list(bm.faces), "f7f6f0", False, colfn=lambda f: "ffffff" if f.normal.z > 0.6 else
              ("eef0ee" if f.normal.y < -0.5 else "e6e9e8"))
    rng = m.rng
    for k in range(26):         # grain facets on the visible faces
        face = rng.choice(("top", "front", "side"))
        u, v = rng.uniform(-0.95, 0.95), rng.uniform(-0.95, 0.95)
        if face == "top":
            p = (u * S / 2.3, v * S / 2.3, S - 0.04)
        elif face == "front":
            p = (u * S / 2.3, -S / 2 - 0.02, S / 2 + v * S / 2.4)
        else:
            p = (S / 2 + 0.02, u * S / 2.3, S / 2 + v * S / 2.4)
        m.ico(rng.uniform(0.06, 0.12), pos=p, color="ffffff" if k % 3 else "dfeef2", subdiv=1, group="body_nl")
    for k in range(7):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(1.9, 2.6)
        m.box((0.22, 0.22, 0.2), pos=(math.cos(a) * d, math.sin(a) * d, 0), rot=(0.2, 0.1, a), color="f4f3ec")
    m.export(OUT)


def build_wheat_stalk():
    """A fallen giant wheat stalk (WORLD_EVENTS 1.x): a golden tree trunk of straw lying on the ground, the ear at one
    end with sack-sized kernels and long awns."""
    m = Model("wheat_stalk", 521)
    L = 11.0
    straw = "e8c46a"
    m.cyl(0.32, 0.26, L, pos=(-L / 2, 0, 0.3), rot=(0, math.pi / 2, 0.06), color=straw, seg=10, smooth=True,
          cap=shade(straw, 0.8), bottom_cap=shade(straw, 0.8))
    for k in range(3):               # nodes
        x = -L / 2 + 2.5 + k * 2.6
        m.cyl(0.36, 0.36, 0.22, pos=(x, 0.0 + 0.06 * (x + L / 2) * 0.06, 0.3), rot=(0, math.pi / 2, 0.06),
              color=shade(straw, 0.88), seg=10, smooth=True)
    # leaf blade flopping off the stalk
    m.blade((-1.5, 0.2, 0.55), (0.8, 1.9, 0.08), 0.7, color=shade(straw, 0.95), group="body_nh", bend=(0, 0.3, 0.4))
    # the ear: rows of plump kernels on both sides along +X past the end
    ex = L / 2 - 0.2
    for k in range(9):
        x = ex + 0.25 + k * 0.42
        s = 1.0 - 0.06 * k
        for side in (-1, 1):
            for lay in (0, 1):
                m.sphere(0.34 * s, pos=(x + 0.1 * lay, side * 0.24 * s, 0.32 + 0.3 * lay * s),
                         scl=(1.25, 0.85, 0.8), rot=(0, -0.35, side * 0.4), color=shade("CROP_RIPE", 1.0 if (k + lay) % 2 else 1.07),
                         seg=8, rings=5)
                # awn
                if lay == 1:
                    m.blade((x, side * 0.25 * s, 0.6 * s + 0.2), (x + 1.6, side * (0.8 + 0.1 * k), 0.9 + 0.1 * k), 0.06,
                            color=shade(straw, 1.05), group="body_nh")
    m.export(OUT)


# (Q32) 꾸미기 조약돌 (godot sim/jar_deco.gd · view/sky_drop_view.gd): a smooth flattened river pebble, four soft colours.
# radius ~0.38 cell (a resident can sit on it), top lighter, a faint pale band on two of them.
PEBBLES = [("d2c7b2", None), ("b0bdbb", "dfe6e2"), ("cbb59a", None), ("b5bea6", "e3e6d6")]


def build_deco_pebbles():
    for i, (col, band) in enumerate(PEBBLES):
        m = Model("deco_pebble_%d" % i, 560 + i)
        sx, sy = (1.0, 0.8 + 0.06 * (i % 3))

        def shade_f(f, col=col, band=band):
            c = f.calc_center_median()
            if band and abs(c.x * 0.6 + c.y * 0.8) < 0.05 and f.normal.z > -0.2:
                return band
            if f.normal.z > 0.75:
                return shade(col, 1.12)
            if f.normal.z < -0.1:
                return shade(col, 0.82)
            return col
        m.sphere(0.38, pos=(0, 0, 0.13), scl=(sx, sy, 0.62), rot=(0, 0, i * 0.9), color=col, seg=16, rings=9, colfn=shade_f)
        m.export(OUT)


if __name__ == "__main__":
    print("items ->", OUT)
    only = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []
    if only:
        for nm in only:
            globals()["build_" + nm]()
        sys.exit(0)
    build_altar()
    build_ampoule()
    build_vein_hills()
    build_sugar_cube()
    build_wheat_stalk()
    build_deco_pebbles()
