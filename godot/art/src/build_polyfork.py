"""polyfork.dev low-poly props, reworked for 나의 작은 지구 (CLAUDE.md 1장 예외 — 2026-11-08 사용자 "폴리포크 고").

Source models (CC BY 4.0, https://polyfork.dev — credits in godot/art/CREDITS.md) live untouched in
art/src/ext/polyfork/ (a .gdignore keeps Godot from importing / exporting the originals). This script:
  * imports each glb, drops extras (animations, rig empties, the moss cushion's grass tufts),
  * joins every mesh into one, welds, optionally collapse-decimates (triangle budget for clutter that is placed many times),
  * snaps the per-face vertex colours to our palette (lowpoly.PALETTE / tiny_kit: twig browns, reed / weave tan, onggi clay,
    warm grey stone, our fern greens) — the original colours are only used to tell the parts apart,
  * rescales to our units (1 unit = 1 cell = an adult resident's height) and puts the origin at the footprint centre on
    the ground (FRONT = -Y as lowpoly.py),
  * adds a decimated "body__far" node (flora_far — no crease lines, no hull; FloraBatch / the building far bake use it),
  * exports art/models/props/pf_<name>.glb (export settings = lowpoly._export_glb: vertex colours, no materials).

Fence, bench and cordwood (pf_fence / pf_bench / pf_cordwood) are NOT imported any more (2026-11-08): they are built
from our own knobby twig pieces (TWIG_PROPS below), because the tiny folk have no trees to saw.

Run:  blender -b --factory-startup --python build_polyfork.py -- <models dir>      (or build_all.sh polyfork)
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, srgb, shade, mix, _lin, _export_glb, out_dir_from_argv  # noqa: E402
from tiny_kit import (TWIG, TWIG_DARK, TWIG_PALE, BARK, WEAVE, WEAVE_DARK, CORD, CLAY, CLAY_DARK, ACORN_IN,  # noqa: E402
                      BARK_LIGHT)
import flora_far  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "ext", "polyfork")


def _lum(c):
    r, g, b = (x * 255.0 for x in c)
    return 0.299 * r + 0.587 * g + 0.114 * b


def _rgb(c):
    return tuple(x * 255.0 for x in c)


# ───────────── palette snaps: source sRGB (0..1) -> our colour (palette name / hex / tuple) ─────────────
def col_basket(c):
    L = _lum(c)
    if L > 185:
        return WEAVE
    if L > 140:
        return WEAVE_DARK                            # weave shade + handles
    return shade(WEAVE_DARK, 0.8)                    # dark weave stripe


ONGGI = "a8673f"                                     # 옹기 — warm clay brown (between CLAY_DARK and TWIG)
ONGGI_DARK = "7c4a32"


def col_jug(c):
    L = _lum(c)
    if L > 110:
        return CLAY_DARK                             # lip highlight
    if L > 75:
        return ONGGI                                 # body
    return ONGGI_DARK                                # rim / handle shadow band


STONE_LIGHT = "e2d7c0"                               # warm grey (not the blue-grey ROCK of mossy boulders)
STONE_MID = "cbbb9d"
STONE_LOW = "b2a083"


def col_cairn(c):
    r, g, b = _rgb(c)
    if g > r + 8 and g > b + 30:
        return "MOSS"
    L = _lum(c)
    if L > 200:
        return STONE_LIGHT
    if L > 128:
        return STONE_MID
    return STONE_LOW


def col_moss(c):
    r, g, b = _rgb(c)
    if g > r + 25:
        return mix("MOSS", "f0f5c8", 0.22) if _lum(c) > 150 else "MOSS"
    return "7a6048"                                  # soil under the cushion


def col_fern(c):
    r, g, b = _rgb(c)
    L = _lum(c)
    if g > r + 25:                                   # fronds: our fern teal-greens (build_nature fern)
        if L > 160:
            return mix("FERN", "LEAF_TOP", 0.5)
        if L > 140:
            return mix("FERN", "LEAF_TOP", 0.25)
        if L > 110:
            return "FERN"
        return mix("FERN", "LEAF_MID", 0.6)
    if L > 95:
        return mix("FERN", "TRUNK", 0.55)            # rachis / stems -> olive, not brown
    return "TRUNK_DARK"


# ───────────── specs ─────────────
# name: src file, colour fn, scale (src units -> cells), group, smooth, drop (object-name substrings),
#       near (triangle budget, 0 = keep), far (far LOD triangles), rotz (radians, so the long side faces the camera)
SPECS = {
    # (2026-11-08) fence / bench / cordwood are no longer imported: polyfork's sawn rails, plank seat and ring-cut logs read
    # as human-world timber. They are built below from knobby twig pieces (TWIG_PROPS) with the same footprint.
    "pf_basket": dict(src="kete-reed-basket-6ca36c.glb", col=col_basket, scale=0.85, near=280, far=64),
    "pf_jug": dict(src="clay-wine-jug-b4ebd3.glb", col=col_jug, scale=1.3, near=220, far=56),
    "pf_cairn": dict(src="stone-cairn-a9bf48.glb", col=col_cairn, scale=0.5, near=300, far=140),
    # Plants are exported at REAL size like art/models/flora/*.glb (1 unit = a 5 cm resident; GAME_DESIGN 3.0) and
    # squeezed on screen by FloraLook.base_scale (K * sqrt(h)) at placement — not hand-sized here (2026-11-08):
    #   moss cushion: real ~3.5 cm tall x ~9.5 cm wide -> 0.7 x 1.9 (knee-to-chest mound, two residents wide)
    #   fern: real ~45 cm (30-60 cm) -> 9 tall x ~12 wide; FloraLook draws it ~6.9 tall (a giant arching plant)
    "pf_moss": dict(src="moss-cushion-2eabef.glb", col=col_moss, scale=0.38, group="body_nl",
                    drop=("tuft",), far=64),
    "pf_fern": dict(src="fern-plant-1559b8.glb", col=col_fern, scale=15.4, group="body_nh", near=220, far=110,
                    double=True),
}
# composites (one glb = one MultiMesh kind in the village yard): [(part, (x, y), rotz, scale)]
SETS = {
    "pf_yard_jars": [("pf_jug", (-0.16, 0.02), 0.4, 1.0), ("pf_basket", (0.2, -0.04), -0.35, 1.0)],
}


def _import(spec):
    """-> list of (world-space Mesh copy without colour attributes, [face colour sRGB tuple])."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, spec["src"]))
    out = []
    for ob in list(bpy.data.objects):
        if ob.type != "MESH" or any(d in ob.name for d in spec.get("drop", ())):
            continue
        me = ob.data
        ca = me.color_attributes[0] if me.color_attributes else None
        cols = []
        for p in me.polygons:
            if ca is None:
                cols.append((0.5, 0.5, 0.5))
            elif ca.domain == "CORNER":
                cols.append(tuple(ca.data[p.loop_start].color_srgb[:3]))
            else:
                cols.append(tuple(ca.data[me.loops[p.loop_start].vertex_index].color_srgb[:3]))
        tmp = me.copy()
        tmp.transform(ob.matrix_world)
        out.append((tmp, cols))
    return out


def _bmesh_of(spec):
    """Imported model -> one bmesh with palette float colours ('Color'), scaled, origin = footprint centre on ground."""
    bm = bmesh.new()
    lay = bm.loops.layers.float_color.new("Color")
    fn = spec["col"]
    smooth = spec.get("smooth", False)
    for me, cols in _import(spec):
        for p, c in zip(me.polygons, cols):
            vs = [bm.verts.new(me.vertices[i].co * spec["scale"]) for i in p.vertices]
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            lc = _lin(fn(c)) + (1.0,)
            for lo in f.loops:
                lo[lay] = lc
            f.smooth = smooth
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    # origin: footprint centre, lowest point on the ground
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    off = Vector((-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, -min(zs)))
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=off)
    return bm


def _decimate(bm, target):
    n0 = sum(len(f.verts) - 2 for f in bm.faces)
    if not target or n0 <= target:
        return bm
    me = bpy.data.meshes.new("dec")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("dec", me)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = float(target) / n0
    mod.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    out = bmesh.new()
    out.from_mesh(me2)
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    bpy.data.meshes.remove(me2)
    return out


def _double(bm):
    """Back faces for thin fronds (the toon shader culls back faces): a flipped copy of every face."""
    lay = bm.loops.layers.float_color["Color"]
    for f in list(bm.faces):
        vs = [bm.verts.new(v.co) for v in reversed(f.verts)]
        cs = [lo[lay][:] for lo in reversed(f.loops)]
        g = bm.faces.new(vs)
        for lo, c in zip(g.loops, cs):
            lo[lay] = c
        g.smooth = f.smooth


def _tris(bm):
    return sum(len(f.verts) - 2 for f in bm.faces)


def build_one(name):
    spec = SPECS[name]
    bm = _bmesh_of(spec)
    bm = _decimate(bm, spec.get("near", 0))
    if spec.get("double"):
        _double(bm)
    return bm


def _export(name, groups, far, out_dir):
    """groups: {group name: bmesh}. Same as lowpoly.Model.export (fixed triangulation) + flora_far far node."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = []
    tris = 0
    for g, bm in groups.items():
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
        bm.normal_update()
        me = bpy.data.meshes.new(g)
        bm.to_mesh(me)
        bm.free()
        tris += sum(len(p.vertices) - 2 for p in me.polygons)
        ob = bpy.data.objects.new(g, me)
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)
    nf = flora_far.decimated(target=far)(objs)
    _export_glb(os.path.join(out_dir, "props", name + ".glb"))
    print("  %-18s %5d tris  far %d" % (name, tris, nf))


def build_set(name, parts):
    groups = {}
    for part, (x, y), rz, s in parts:
        spec = SPECS[part]
        bm = build_one(part)
        bmesh.ops.transform(bm, verts=bm.verts[:],
                            matrix=Matrix.Translation((x, y, 0)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Scale(s, 4))
        g = spec.get("group", "body")
        if g in groups:
            me = bpy.data.meshes.new("tmp")
            bm.to_mesh(me)
            bm.free()
            groups[g].from_mesh(me)
            bpy.data.meshes.remove(me)
        else:
            groups[g] = bm
    return groups


# ───────────── twig props (2026-11-08): our world has no trees to saw — "logs" are twig pieces (GD 3.0, E3-4) ─────────────
# Same names / footprints as the polyfork pieces they replace (fence run 1.0 x 0.6 high, bench 0.95 long seat ~0.28 high,
# cordwood pile 1.0 long ~0.5 high), but: thin knobby twigs with a slight bend, bud stubs and cut side-twig stubs,
# grey-green-brown bark with lichen flecks, small plain pale discs at the cut ends (no ring pattern), joints wrapped with
# dry-grass bands instead of nailed, and the bench seat is one split twig half (flat pale face up, bark underneath).
TB = "857a5e"            # twig bark, grey-green-brown
TB_DARK = "6c6450"
TB_LIGHT = "9d9576"
LICHEN = "a3a97c"
CUT = "dccfa6"           # small pale cut disc
SPLIT = "c9b588"         # split face of the bench twig
BAND = "b8a25e"          # dry-grass lashing band
BAND_DARK = "9c8a4e"


def _perp(d):
    d = d.normalized()
    u = d.cross(Vector((0, 0, 1)))
    if u.length < 1e-4:
        u = d.cross(Vector((1, 0, 0)))
    u.normalize()
    return u, d.cross(u).normalized()


def knobby(m, pts, r0, r1, col=TB, seg=5, knob=(), buds=(), stubs=(), seed=0, end_cut=(True, True)):
    """Twig through centreline pts (3-4 points, small bends), radius r0 -> r1, a fatter ring at each index in knob,
    bud stubs (small cones) and cut side-twig stubs (pale tip) at fractions t along the twig."""
    rng = __import__("random").Random(seed)
    pts = [Vector(p) for p in pts]
    n = len(pts)
    u, v = _perp(pts[-1] - pts[0])
    rings = []
    for i, p in enumerate(pts):
        r = r0 + (r1 - r0) * i / (n - 1)
        if i in knob:
            r *= 1.28
        ph = rng.random() * 0.6
        rings.append([p + (u * math.cos(a) + v * math.sin(a)) * r * (0.92 + 0.16 * rng.random())
                      for a in (ph + k * math.tau / seg for k in range(seg))])
    flecks = [rng.random() for _ in range(seg * (n - 1))]
    it = iter(flecks)
    faces = m.strip(rings, color=col, close=True, caps=True, smooth=True,
                    colfn=lambda f: LICHEN if next(it, 0.0) > 0.86 else col)
    bm = m._bm("body")
    for k, f in enumerate(faces[-2:]):
        if end_cut[k]:
            m._finish(bm, [f], CUT, False)
        else:
            m._finish(bm, [f], shade(col, 0.9), False)

    def at(t):
        x = t * (n - 1)
        i = min(n - 2, int(x))
        return pts[i].lerp(pts[i + 1], x - i), (pts[i + 1] - pts[i]).normalized(), r0 + (r1 - r0) * t

    for k, t in enumerate(buds):
        p, d, r = at(t)
        a = rng.random() * math.tau
        out = (u * math.cos(a) + v * math.sin(a))
        q = out * 0.8 + d * 0.6
        m.cyl(r * 0.55, 0.0, r * 1.6, pos=p + out * r * 0.6, rot=q.to_track_quat("Z", "Y").to_euler(), color=TB_DARK,
              seg=3)
    for k, t in enumerate(stubs):
        p, d, r = at(t)
        a = rng.random() * math.tau
        out = (u * math.cos(a) + v * math.sin(a))
        q = out * 0.75 + d * 0.65
        m.cyl(r * 0.6, r * 0.5, r * 2.6, pos=p + out * r * 0.4, rot=q.to_track_quat("Z", "Y").to_euler(), color=col,
              seg=4, cap=CUT)


def band(m, p, d, r, wraps=2):
    """Dry-grass lashing: thin bands wrapped round axis d at p (twig radius r)."""
    d = Vector(d).normalized()
    rot = d.to_track_quat("Z", "Y").to_euler()
    for k in range(wraps):
        q = Vector(p) + d * (k - (wraps - 1) / 2) * 0.034 - d * 0.012
        m.cyl(r * 1.3, r * 1.3, 0.024, pos=q, rot=rot, color=(BAND, BAND_DARK)[k % 2], seg=6)


def twig_fence():
    m = Model("pf_fence", 61)
    posts = []
    for k, x in enumerate((-0.42, 0.42)):
        lean = (0.03, -0.025)[k]
        top = Vector((x + lean, 0.0, 0.6))
        knobby(m, [(x, 0, -0.03), (x + lean * 0.3 + 0.012, 0.006, 0.26), top], 0.048, 0.036, TB_DARK if k else TB,
               knob=(1,), buds=(0.78,), stubs=(0.55,), seed=11 + k)
        knobby(m, [top - Vector((0, 0, 0.1)), top + Vector(((-0.05, 0.05)[k], 0.0, 0.03))], 0.024, 0.018, TB, seg=4,
               seed=13 + k)                                       # forked top
        posts.append((x, lean))
    for z, sag, sd in ((0.24, 0.012, 21), (0.47, 0.018, 22)):
        y = -0.052
        xs = (-0.53, -0.15, 0.2, 0.53)
        knobby(m, [(x, y + 0.006 * ((i * 7 + sd) % 3 - 1), z - sag * (1 if 0 < i < 3 else 0) + 0.006 * i)
                   for i, x in enumerate(xs)], 0.034, 0.027, TB_LIGHT if sd == 21 else TB, knob=(2,),
               buds=(0.33, 0.7), seed=sd)
        for x, lean in posts:
            band(m, (x + lean * z / 0.6, -0.012, z + 0.01), (0, 0, 1), 0.05)
    return m


def twig_bench():
    m = Model("pf_bench", 62)
    L, R, top = 0.94, 0.088, 0.285
    # one twig split lengthwise: a bit more than half its round left (bark shows at the sides from above), the pale split
    # face up — lofted through 5 stations with a slight bend and a knot swelling so it is not a plank
    a0 = 0.55
    N = 7
    angs = [-(math.pi + a0) + k * (math.pi + 2 * a0) / N for k in range(N + 1)]          # under the twig, increasing
    zc = top - R * math.sin(a0)                                                         # twig centre (split face at top)
    rings = []
    for i, (t, dy, dz, rs) in enumerate(((0.0, 0.0, -0.004, 0.96), (0.25, 0.012, 0.0, 1.0), (0.5, 0.018, 0.006, 1.12),
                                         (0.75, 0.01, 0.002, 1.0), (1.0, -0.004, -0.006, 0.94))):
        x = -L / 2 + L * t
        rings.append([Vector((x, dy + R * rs * math.cos(a), zc + dz + R * rs * math.sin(a))) for a in angs])
    flecks = iter([0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0] * 6)

    def seat_col(f):
        if abs(f.normal.x) > 0.85:
            return CUT
        if f.normal.z > 0.8:
            return SPLIT
        return LICHEN if next(flecks, 0.0) > 0.5 else TB

    faces = m.strip(rings, color=TB, close=True, caps=True, smooth=False, colfn=seat_col)
    for f in faces:
        f.smooth = abs(f.normal.x) < 0.85 and f.normal.z < 0.8
    for x in (-0.18, 0.24):                                                             # dark knots on the split face
        m.cyl(0.022, 0.018, 0.008, pos=(x, 0.01, top - 0.003), color=TB_DARK, seg=5)
    # bark knobs, bud stubs and a cut side twig on the seat's round side
    for x, a in ((-0.22, -1.1), (0.27, -2.2)):
        m.sphere(0.035, pos=(x, math.cos(a) * R * 0.95, top + math.sin(a) * R * 0.95), color=TB_DARK, seg=5, rings=3)
    m.cyl(0.03, 0.024, 0.07, pos=(0.08, -R * 0.7, top - R * 0.6), rot=(1.9, 0, 0.3), color=TB, seg=4, cap=CUT)
    for x in (-0.33, 0.12, 0.38):
        m.cyl(0.018, 0.0, 0.04, pos=(x, R * 0.75, top - R * 0.55), rot=(-1.6, 0, 0), color=TB_DARK, seg=3)
    # legs: forked twig stubs cradling the seat, lashed with grass under the fork
    for k, x in enumerate((-0.33, 0.33)):
        knobby(m, [(x, 0, -0.02), (x + 0.01, 0.005, 0.08), (x, 0, 0.16)], 0.032, 0.027, TB_DARK, seg=5, knob=(1,),
               seed=31 + k, end_cut=(True, False))
        for s in (-1, 1):
            knobby(m, [(x, 0, 0.14), (x, s * 0.045, 0.19), (x, s * 0.065, top - 0.06)], 0.02, 0.016, TB, seg=4,
                   seed=33 + k + s)
        band(m, (x, 0, 0.12), (0, 0, 1), 0.032)
    return m


def twig_cordwood():
    m = Model("pf_cordwood", 63)
    r = 0.052
    rows = (4, 3, 2)
    rng = __import__("random").Random(63)
    for row, n in enumerate(rows):
        for i in range(n):
            y = -((n - 1) * 2.3 * r) / 2 + i * 2.3 * r + (rng.random() - 0.5) * 0.02
            z = r + row * r * 1.9
            sd = 40 + row * 5 + i
            rr = r * (0.8 + 0.35 * rng.random())                       # thin and thick pieces mixed
            ln = 0.72 + 0.26 * rng.random()
            off = (rng.random() - 0.5) * 0.12
            sk = (rng.random() - 0.5) * 0.08                           # a little crooked in the pile
            col = (TB, TB_DARK, TB_LIGHT)[(i + row) % 3]
            bend = (rng.random() - 0.5) * 0.04
            knobby(m, [(-ln / 2 + off, y - sk, z), (off + bend, y + bend, z + 0.006), (ln / 2 + off, y + sk, z)],
                   rr, rr * 0.86, col, seg=5, knob=(1,) if sd % 2 else (),
                   buds=(0.3, 0.8) if sd % 3 == 0 else (0.55,), stubs=(0.65,) if sd % 4 == 1 else (), seed=sd)
    hh = r * 1.9 * (len(rows) - 1) + 2 * r
    for k, x in enumerate((-0.5, 0.5)):
        for j, y in enumerate((-0.25, 0.25)):
            knobby(m, [(x, y, -0.03), (x + 0.008, y * 0.95, 0.22), (x - 0.01 * (j - 0.5), y * 0.88, hh + 0.12)], 0.034,
                   0.026, TB_DARK if j else TB, knob=(1,), buds=(0.75,) if (k + j) % 2 else (), seed=60 + 2 * k + j)
        # the stake pair tied together over the pile with a grass cord, wrapped at both stakes
        p0 = Vector((x - 0.01 * -0.5, -0.25 * 0.88, hh + 0.07))
        p1 = Vector((x - 0.01 * 0.5, 0.25 * 0.88, hh + 0.07))
        d = p1 - p0
        m.cyl(0.016, 0.016, d.length, pos=p0, rot=d.to_track_quat("Z", "Y").to_euler(), color=BAND, seg=4)
        band(m, p0, (0, 0, 1), 0.03, 1)
        band(m, p1, (0, 0, 1), 0.03, 1)
    return m


TWIG_PROPS = {"pf_fence": (twig_fence, 72), "pf_bench": (twig_bench, 96), "pf_cordwood": (twig_cordwood, 150)}


def main():
    out_dir = out_dir_from_argv()
    os.makedirs(os.path.join(out_dir, "props"), exist_ok=True)
    only = [a for a in sys.argv[sys.argv.index("--") + 1:] if not os.path.isdir(a)] if "--" in sys.argv else []
    for name, spec in SPECS.items():
        if not only or name in only:
            _export(name, {spec.get("group", "body"): build_one(name)}, spec["far"], out_dir)
    for name, (fn, far) in TWIG_PROPS.items():
        if not only or name in only:
            fn().export(out_dir=os.path.join(out_dir, "props"), far=flora_far.decimated(target=far))
    for name, parts in SETS.items():
        if not only or name in only:
            _export(name, build_set(name, parts), 96, out_dir)


main()
