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

Run:  blender -b --factory-startup --python build_polyfork.py -- <models dir>      (or build_all.sh polyfork)
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import srgb, shade, mix, _lin, _export_glb, out_dir_from_argv  # noqa: E402
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
def col_fence(c):
    r, g, b = _rgb(c)
    if r - b > 75:                                   # split rails (warm brown) -> pale bark / twig
        return BARK_LIGHT if _lum(c) > 125 else shade(BARK_LIGHT, 0.9)
    return TWIG                                      # posts


def col_bench(c):
    L = _lum(c)
    if L > 170:
        return TWIG_PALE                             # adzed seat top
    if L > 145:
        return ACORN_IN                              # cut ends
    if L > 120:
        return BARK
    if L > 90:
        return TWIG
    return TWIG_DARK


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


def col_cordwood(c):
    L = _lum(c)
    if L > 140:
        return TWIG_PALE                             # cut ends
    if L > 100:
        return shade(BARK_LIGHT, 0.92)
    if L > 82:
        return TWIG
    return TWIG_DARK


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
    "pf_fence": dict(src="split-rail-fence-run-87da39.glb", col=col_fence, scale=0.5, far=72),
    "pf_bench": dict(src="hearth-log-bench-c3c5ec.glb", col=col_bench, scale=0.65, far=96),
    "pf_basket": dict(src="kete-reed-basket-6ca36c.glb", col=col_basket, scale=0.85, near=280, far=64),
    "pf_jug": dict(src="clay-wine-jug-b4ebd3.glb", col=col_jug, scale=1.3, near=220, far=56),
    "pf_cordwood": dict(src="cordwood-pile-b5229b.glb", col=col_cordwood, scale=0.5, far=160),
    "pf_cairn": dict(src="stone-cairn-a9bf48.glb", col=col_cairn, scale=0.5, near=300, far=140),
    "pf_moss": dict(src="moss-cushion-2eabef.glb", col=col_moss, scale=0.18, group="body_nl",
                    drop=("tuft",), far=64),
    "pf_fern": dict(src="fern-plant-1559b8.glb", col=col_fern, scale=1.4, group="body_nh", near=220, far=90,
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


def main():
    out_dir = out_dir_from_argv()
    os.makedirs(os.path.join(out_dir, "props"), exist_ok=True)
    for name, spec in SPECS.items():
        _export(name, {spec.get("group", "body"): build_one(name)}, spec["far"], out_dir)
    for name, parts in SETS.items():
        _export(name, build_set(name, parts), 96, out_dir)


main()
