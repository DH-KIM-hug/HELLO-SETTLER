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
    # (P1 perf pass 4) yard jars: lighter decimation + smooth-by-angle (soft facets drew a crease line on every edge)
    "pf_basket": dict(src="kete-reed-basket-6ca36c.glb", col=col_basket, scale=0.85, near=170, far=64, smooth_angle=50,
                      group="body_nl"),
    "pf_jug": dict(src="clay-wine-jug-b4ebd3.glb", col=col_jug, scale=1.3, near=140, far=56, smooth_angle=50, group="body_nl"),
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
        out.append((tmp, cols, ob.name))
    return out


def _bmesh_of(spec):
    """Imported model -> one bmesh with palette float colours ('Color'), scaled, origin = footprint centre on ground."""
    bm = bmesh.new()
    lay = bm.loops.layers.float_color.new("Color")
    fn = spec["col"]
    ext = getattr(fn, "ext", False)                  # 2차 묶음의 색 함수는 (색, 법선, 부품 이름)을 받음
    smooth = spec.get("smooth", False)
    rx, ry, rz = spec.get("rot", (0.0, 0.0, 0.0))
    R = (Matrix.Rotation(rz, 3, "Z") @ Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rx, 3, "X"))
    for me, cols, obn in _import(spec):
        for p, c in zip(me.polygons, cols):
            vs = [bm.verts.new(R @ me.vertices[i].co * spec["scale"]) for i in p.vertices]
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            lc = _lin(fn(c, R @ p.normal, obn) if ext else fn(c)) + (1.0,)
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


def _smooth_by_angle(bm, deg):
    """(P1 perf pass 4) Smooth shading, sharp only where faces meet at more than deg (the real corners): the toon
    terminator stays clean and Godot's crease lines (art.gd: hard normals + > 24 deg) appear only on those corners."""
    bm.normal_update()
    lim = math.radians(deg)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2:
            e.smooth = e.calc_face_angle(0.0) <= lim
        else:
            e.smooth = False


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
    if spec.get("smooth_angle"):
        _smooth_by_angle(bm, spec["smooth_angle"])
    if spec.get("extra"):
        spec["extra"](bm)
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
    for e in parts:
        part, (x, y), rz, s = e[:4]
        z = e[4] if len(e) > 4 else 0.0
        if callable(part):                           # 우리가 만든 부품 (잔가지 다리 등) — bmesh를 돌려줌
            bm, g = part(), "body"
        else:
            spec = SPECS[part]
            bm = build_one(part)
            g = spec.get("group", "body")
        bmesh.ops.transform(bm, verts=bm.verts[:],
                            matrix=Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Scale(s, 4))
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


# ───────────── 2차 묶음 (2026-11-08 — ROADMAP E3-16 떨어진 물건 · E3-17 Insect World 재료·빵 사슬·물가 풀) ─────────────
# Scales (src units -> cells; 1 cell = an adult resident = 5 cm real):
#   Insect World kit is built 100x real (src 1 m = 1 real cm)            -> IW  = 0.2
#   human-world crafts (quern, oven, racks ... built for a 1.7 m person)  -> MAN = 1 / 1.7  (our folk build their own)
#   real-size plants (1 m = 20 cells; FloraLook squeezes them at placement like art/models/flora)
IW = 0.2
MAN = 1.0 / 1.7
REAL = 20.0
PUDDLE = "78b9c2"                                     # style.gd PUDDLE — standing water in a basin / trough
CAP_GREY = "a89f8f"                                   # bottle cap: dull warm grey (no tin blue) + onggi rim
CAP_GREY_LIGHT = "c4b8a2"
CAP_LINER = "d9c49c"


def _hexs(c):
    return "%02x%02x%02x" % tuple(int(x * 255) for x in c[:3])


def natural(c, n=None, ob=""):
    """Generic snap of a source colour to our palette: greys / blue-greys -> warm stone, greens -> moss / fern,
    reds -> clay, straw yellows -> dry weave, browns -> twig / bark (no metal or modern colours)."""
    r, g, b = _rgb(c)
    L = _lum(c)
    sat = max(r, g, b) - min(r, g, b)
    if sat < 26 or b > r + 6:
        if L > 205:
            return "f4efe2"
        if L > 160:
            return STONE_LIGHT
        if L > 120:
            return STONE_MID
        if L > 80:
            return STONE_LOW
        return "5b4a40"
    if g > r + 8 and g >= b:
        if L > 150:
            return mix("MOSS", "f0f5c8", 0.18)
        if L > 105:
            return "MOSS"
        if L > 70:
            return mix("FERN", "MOSS", 0.4)
        return mix("FERN", "LEAF_MID", 0.6)
    if r > g + 55 and r > b + 55 and g < 120:
        return CLAY if L > 110 else CLAY_DARK
    if g > r * 0.74 and L > 140:
        return WEAVE if L > 175 else WEAVE_DARK
    if L > 175:
        return TWIG_PALE
    if L > 125:
        return BARK_LIGHT
    if L > 88:
        return TWIG
    if L > 58:
        return TWIG_DARK
    return "4f3c30"


def remap(table=None, fallback=natural, by_obj=None):
    """-> colour fn(c, n, ob): object-name rules first, then the exact source hex, then fallback."""
    table = table or {}
    by_obj = by_obj or {}

    def fn(c, n=None, ob=""):
        for sub, col in by_obj.items():
            if sub in ob:
                return col(c, n, ob) if callable(col) else col
        v = table.get(_hexs(c))
        if v is not None:
            return v(c, n, ob) if callable(v) else v
        return fallback(c, n, ob)
    fn.ext = True
    return fn


def two_tone(top, side, k=0.55):
    """Up-facing faces one colour, the rest another (a one-colour source reads flat in the toon shader)."""
    def fn(c, n=None, ob=""):
        return top if (n is not None and n.z > k) else side
    return fn


def _fern_ext(c, n=None, ob=""):
    return col_fern(c)


def _disc(z, r, col, seg=14):
    """extra(bm): a flat water disc at height z (after scale + origin) — standing water in a basin."""
    def fn(bm):
        lay = bm.loops.layers.float_color["Color"]
        vs = [bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)) for a in (k * math.tau / seg for k in range(seg))]
        f = bm.faces.new(vs)
        lc = _lin(col) + (1.0,)
        for lo in f.loops:
            lo[lay] = lc
    return fn


def _twig_legs():
    """Three lashed twig legs (0.31 high) under the found button -> the village table (GD 3.0)."""
    m = Model("legs", 71)
    for k in range(3):
        a = k * math.tau / 3 + 0.3
        x, y = math.cos(a) * 0.12, math.sin(a) * 0.12
        knobby(m, [(x * 1.25, y * 1.25, -0.02), (x * 1.08, y * 1.08, 0.16), (x * 0.92, y * 0.92, 0.31)], 0.026, 0.021,
               TB_DARK if k else TB, seg=4, knob=(1,), seed=71 + k)
        band(m, (x * 0.94, y * 0.94, 0.27), (0, 0, 1), 0.022, 1)
    return m.groups["body"]


def _marble_glass(c, n=None, ob=""):
    """Opaque toon glass hides the inner vane -> paint a muted swirl band on the shell (cream glass, sage + honey streaks)."""
    if n is None:
        return "CREAM"
    s = math.sin(2.0 * math.atan2(n.y, n.x) + 3.0 * n.z)
    if s > 0.78:
        return "a9c9b8"
    if s < -0.88:
        return "e6c98e"
    return "CREAM" if n.z > 0.15 else "e8dcc0"


def _stump_col(c, n=None, ob=""):
    """Moss on the stump: muted (a bright faceted cap read as a green crystal in pf2_lineup)."""
    return mix("MOSS", "FERN", 0.35) if _lum(c) > 95 else mix("FERN", "LEAF_MID", 0.45)


SPECS.update({
    # ── Insect World 재료 (IW) — fallen litter; part=True: only inside the pf_litter_* sets ──
    "iw_twig": dict(src="fallen-twig-4c64de.glb", scale=IW, near=260, part=True,
                    col=remap({"5e4835": TB, "4b372b": TB_DARK, "d6b793": CUT, "c3a172": TB_LIGHT})),
    "iw_oak_leaf": dict(src="fallen-oak-leaf-5b15fe.glb", scale=IW, near=220, part=True, double=True,
                        col=remap({"b76d43": "c99a52", "a4323f": mix("LEAF_RED", "c99a52", 0.35), "c3a172": "DRIED",
                                   "777d4d": "9a8f5a"})),
    "iw_petal": dict(src="fallen-rose-petal-8b0c24.glb", scale=IW, near=130, part=True, double=True,
                     col=remap({"a4323f": mix("LOTUS", "ROOF_RED", 0.45), "ce5f6a": "LOTUS", "d6b793": "CREAM"})),
    "iw_sunseed": dict(src="sunflower-seed-b4fbbd.glb", scale=IW, near=120, part=True,
                       col=remap({"2c252a": "4a3e36", "edebe7": "d9cfb8"})),
    "iw_sycamore": dict(src="sycamore-seed-24e5a2.glb", scale=IW, near=140, part=True, double=True,
                        col=remap({"938c4c": "a89a5e", "b76d43": "c99a52", "c3a172": "DRIED"})),
    "pf_eggshell": dict(src="eggshell-half-d30a1c.glb", scale=IW, near=320, far=90,
                        col=remap({"2c252a": "9c7a58", "f9f6ef": "f4efe2", "aac9c2": "e6dcc4"})),
    "pf_acorn_basin": dict(src="acorn-cup-0ed13c.glb", scale=IW, near=520, far=120,
                           col=remap({"938c4c": "9a7448", "c3a172": ACORN_IN, "d6b793": "ecdcb4", "8a5930": "7a5838",
                                      "5e4835": TWIG_DARK}),
                           extra=_disc(0.29, 0.17, PUDDLE)),
    "pf_pot_house": dict(src="upturned-clay-flowerpot-de9221.glb", scale=IW, far=320,
                         col=remap({"b76d43": "b97a55", "78a751": "MOSS", "4b372b": "DOOR", "5e4835": TWIG_DARK,
                                    "2c252a": "WINDOW", "c3a172": "d9c49c"})),
    # ── 떨어진 물건 (E3-16, GD 3.0) — residents know what they are; only the size is strange ──
    "iw_button": dict(src="lost-button-46f22a.glb", scale=IW, near=420, part=True,
                      col=remap(fallback=two_tone("cfa766", "a8834c"))),
    "pf_found_marble": dict(src="glass-marble-4772bb.glb", scale=IW, near=420, far=90,
                            col=remap({"5b82b0": "8fb9b4", "efcc4f": "e3c27a", "698435": "9cbf6a", "2c252a": "6b5a50"},
                                      by_obj={"glass": _marble_glass})),
    "pf_found_cap": dict(src="bottle-cap-cd96db.glb", scale=IW, rot=(math.pi, 0.0, 0.0), near=520, far=110,
                         col=remap({"5b82b0": CAP_GREY, "8a5930": ONGGI, "c3a172": CAP_GREY_LIGHT, "e3dfdb": CAP_LINER}),
                         extra=_disc(0.1, 0.27, PUDDLE)),
    "pf_found_sugar": dict(src="sugar-cube-4a50a5.glb", scale=IW, near=300, far=40,
                           col=remap({"f9f6ef": "f4efe2", "edebe7": "CREAM"})),
    "pf_found_match": dict(src="matchstick-b3147f.glb", scale=IW, near=360, far=60,
                           col=remap({"d6b793": TWIG_PALE, "c3a172": "d9c49c", "a4323f": "b5523f", "2c252a": "5a4136",
                                      "8a5930": TWIG})),
    "pf_matchbox_house": dict(src="matchbox-house-2d2689.glb", scale=IW, far=360,       # import only (special house later)
                              col=remap({"4b372b": "b5523f", "c3a172": "d9c49c", "d6b793": TWIG_PALE,
                                         "b28961": BARK_LIGHT, "f9f6ef": "CREAM", "a4323f": "ROOF_RED"})),
    # ── 빵 사슬·실 일 마당 소품 (MAN — our folk build these themselves) ──
    "pf_quern": dict(src="saddle-quern-food-mill-8e3657.glb", scale=MAN, near=520, far=110,
                     col=remap({"788f8a": STONE_MID, "88a89d": STONE_LIGHT, "d8b067": "GRAIN"})),
    "pf_oven": dict(src="clay-bread-oven-860b06.glb", scale=MAN, far=140,
                    col=remap({"9a9897": "d3a96c", "bdbbba": "e7c48a", "a55c4f": CLAY_DARK, "dbcfb2": "ecdcb8",
                               "bdaa93": "d9c49c", "856850": TWIG, "251d19": "3e2c24", "7b3730": "a0482f"})),
    "pf_granary": dict(src="stilted-granary-3e7d7d.glb", scale=MAN, near=560, far=220, smooth_angle=50, group="body_nl",   # (P1 pass 4) hull only
                       col=remap({"473427": TB_DARK, "bdbbba": "THATCH", "31333b": "THATCH_DARK"})),
    "pf_retting": dict(src="plant-fibre-retting-trough-0e8969.glb", scale=MAN, near=640, far=120,
                       col=remap({"d8b067": "cdbb84", "a78952": "a8935e"}, by_obj={"water": PUDDLE})),
    "pf_weave_jig": dict(src="wattle-panel-weaving-jig-d1aa1c.glb", scale=MAN, near=600, far=120,
                         col=remap({"d8b067": WEAVE, "c99163": WEAVE_DARK})),
    "pf_rack_hasa": dict(src="hasa-rice-drying-rack-d545bc.glb", scale=MAN, near=600, far=110,
                         col=remap({"d9a441": WEAVE, "d9c89a": "DRIED", "544537": TB_DARK, "9c825c": TB, "8c6a2f": CORD})),
    "pf_rack_net": dict(src="drying-net-rack-93ec3b.glb", scale=MAN, near=520, far=110,
                        col=remap({"dccba6": "d9c49c", "6b4526": TB_DARK, "4a2e1b": TB_DARK, "c9975c": WEAVE_DARK,
                                   "9c6b3c": TB})),
    # ── 숲 가장자리·물가 풀 ──
    # moss stump: a small broken-stem base ~1.6 cells (2026-11-08 main: not a 24-cell real stump), bark in twig tones
    "pf_stump": dict(src="moss-covered-stump-7253ab.glb", scale=1.6 / 1.15, near=420, far=110, smooth=True,
                     col=remap({"8c5a32": TWIG, "5e4431": TWIG_DARK, "c7a56c": TWIG_PALE, "553a28": TWIG_DARK,
                                "62422c": TWIG_DARK, "4f3726": TWIG_DARK, "5b3d2a": TWIG_DARK, "483224": TWIG_DARK},
                               by_obj={"fern": _fern_ext}, fallback=_stump_col)),
    # mushroom cluster: real ~5 cm (about one resident tall) — replaces build_nature "mushrooms" in the clutter tables;
    # the soil pad is dropped (a dark disc under the caps read as a bread dome in pf2_lineup)
    "pf_mushrooms": dict(src="mushroom-cluster-f2e3ba.glb", scale=4.4, near=300, far=80, drop=("soil",),
                         col=remap({"c25d44": "MUSHROOM_CAP", "dedad7": "MUSHROOM_STEM", "a59e89": "MUSHROOM_DOT",
                                    "593c2a": "SOIL_DARK", "cea772": "STUMP_TOP"})),
    # giant horsetail: real ~50 cm -> 10 cells; FloraLook draws it ~7 tall (forest edge only, like the fern)
    "pf_horsetail": dict(src="giant-horsetail-stand-3a4f94.glb", scale=2.0, group="body_nl", near=640, far=160,
                         col=remap(fallback=_fern_ext)),
    # shore: reed bed + cattails (parts of pf_reeds) at half real size (shore reeds trodden / cut near the village)
    "iw_reed_bed": dict(src="reed-bed-bbbefb.glb", scale=REAL * 0.5, near=260, part=True, group="body_nh", double=True,
                        col=remap({"767c49": mix("REED", "DRIED", 0.3), "4e573c": "7a9f52", "988b74": "DRIED",
                                   "9f8a47": "cdbb84"})),
    "iw_cattail": dict(src="cattail-reed-6abbb3.glb", scale=REAL * 0.5, near=200, part=True, group="body_nh",
                       col=remap({"75563b": "REED_HEAD", "3d6b34": mix("REED", "FERN", 0.5), "4c8140": "REED",
                                  "93c46a": "9cbf6a"})),
})
SETS.update({
    "pf_litter_a": [("iw_twig", (0.0, 0.0), 0.25, 1.0), ("iw_oak_leaf", (0.9, 0.95), -0.6, 1.0)],
    "pf_litter_b": [("iw_petal", (0.0, 0.0), 0.4, 1.0), ("iw_sunseed", (0.55, -0.2), 1.1, 1.0),
                    ("iw_sunseed", (0.62, 0.12), 2.3, 0.9), ("iw_sycamore", (-0.6, 0.45), -0.9, 1.0)],
    "pf_reeds": [("iw_reed_bed", (0.0, 0.0), 0.0, 1.0), ("iw_cattail", (0.35, 0.1), 0.4, 1.0),
                 ("iw_cattail", (-0.5, -0.05), 1.7, 0.85)],
    "pf_found_table": [("iw_button", (0.0, 0.0), 0.0, 1.0, 0.3), (_twig_legs, (0.0, 0.0), 0.0, 1.0)],
})
SET_FAR = {"pf_litter_a": 120, "pf_litter_b": 110, "pf_reeds": 160, "pf_found_table": 110}


def main():
    out_dir = out_dir_from_argv()
    os.makedirs(os.path.join(out_dir, "props"), exist_ok=True)
    only = [a for a in sys.argv[sys.argv.index("--") + 1:] if not os.path.isdir(a)] if "--" in sys.argv else []
    for name, spec in SPECS.items():
        if spec.get("part"):                         # only used inside SETS
            continue
        if not only or name in only:
            _export(name, {spec.get("group", "body"): build_one(name)}, spec["far"], out_dir)
    for name, (fn, far) in TWIG_PROPS.items():
        if not only or name in only:
            fn().export(out_dir=os.path.join(out_dir, "props"), far=flora_far.decimated(target=far))
    for name, parts in SETS.items():
        if not only or name in only:
            _export(name, build_set(name, parts), SET_FAR.get(name, 96), out_dir)


main()
