"""Low-poly model kit for 나의 작은 지구 (Blender 5.x, run headless).

Every model is built procedurally from a few primitives into bmesh groups and exported as one small .glb:
  * colours come from godot/data/style.gd (and Balance.LOOK_FIXED) -> per-face vertex colours (linear float),
    Godot's loader (godot/art/art.gd) turns them back into sRGB for the shared toon shader.
  * group "body"    : gets crease lines in Godot (edges sharper than ~42 deg + open borders) and the inverted hull.
  * group "body_nl" : hull only, no crease lines (lumpy canopies - their facets are not "lines").
  * group "body_nh" : no outline at all (thin double-sided blades: grass, fern leaflets, reeds).
  * faces are flat-shaded unless smooth=True (blobs, thatch, round things) -> one clean toon terminator.
Coordinates: Blender Z-up, 1 unit = 1 world cell. FRONT = -Y (exported as Godot +Z, the side that faces the
default camera after village_view's yaw). Model origin = centre of the footprint on the ground.
"""
import bpy
import bmesh
import math
import os
import random
import re
import sys
from mathutils import Matrix, Vector, Euler, noise

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(GODOT, "art", "models")


# ───────────── palette ─────────────
def _parse_palette():
    pal = {}
    with open(os.path.join(GODOT, "data", "style.gd"), encoding="utf-8") as f:
        for m in re.finditer(r'^const\s+([A-Z0-9_]+)\s*:=\s*Color\("([0-9a-fA-F]{6})"\)', f.read(), re.M):
            pal[m.group(1)] = m.group(2)
    with open(os.path.join(GODOT, "data", "balance.gd"), encoding="utf-8") as f:
        src = f.read()
    m = re.search(r"LOOK_FIXED\s*:=\s*\{(.*?)\}", src, re.S)
    if m:
        for k, v in re.findall(r'"(\w+)":\s*"([0-9a-fA-F]{6})"', m.group(1)):
            pal["LOOK_" + k.upper()] = v
    return pal


PALETTE = _parse_palette()


def _hex(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def srgb(c):
    """Palette name ('THATCH'), hex ('f0c886') or (r,g,b) sRGB tuple -> sRGB tuple."""
    if isinstance(c, str):
        return _hex(PALETTE[c]) if c in PALETTE else _hex(c)
    return tuple(c[:3])


def shade(c, k):
    """Multiply an sRGB colour (k < 1 darker, > 1 lighter, clamped)."""
    r, g, b = srgb(c)
    return (min(1, r * k), min(1, g * k), min(1, b * k))


def mix(a, b, t):
    a, b = srgb(a), srgb(b)
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def _lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in srgb(c))


# ───────────── model ─────────────
def _mat(pos=(0, 0, 0), rot=(0, 0, 0), scl=(1, 1, 1)):
    if isinstance(scl, (int, float)):
        scl = (scl, scl, scl)
    s = Matrix.Diagonal((scl[0], scl[1], scl[2], 1.0))
    return Matrix.Translation(Vector(pos)) @ Euler(rot, "XYZ").to_matrix().to_4x4() @ s


class Model:
    """A model under construction: named bmesh groups -> one glb (one node per group)."""

    def __init__(self, name, seed=1):
        self.name = name
        self.groups = {}
        self.rng = random.Random(seed)

    # -- internals --
    def _bm(self, group):
        if group not in self.groups:
            bm = bmesh.new()
            bm.loops.layers.float_color.new("Color")
            self.groups[group] = bm
        return self.groups[group]

    def _finish(self, bm, faces, color, smooth, colfn=None):
        lay = bm.loops.layers.float_color["Color"]
        if colfn:
            bm.normal_update()
        for f in faces:
            c = colfn(f) if colfn else color
            lc = _lin(c) + (1.0,)
            for l in f.loops:
                l[lay] = lc
            f.smooth = smooth
        return faces

    @staticmethod
    def _faces_of(verts):
        fs = {}                      # ordered (a set would make the export order - and the glb bytes - vary per run)
        for v in verts:
            for f in v.link_faces:
                fs[f] = True
        return list(fs)

    # -- primitives (all return their faces) --
    def box(self, size, pos=(0, 0, 0), rot=(0, 0, 0), color="WOOD", group="body", smooth=False, colfn=None):
        """Box of size (x, y, z); pos = centre of the bottom face."""
        bm = self._bm(group)
        m = _mat(pos, rot) @ Matrix.Translation((0, 0, size[2] / 2)) @ Matrix.Diagonal((size[0], size[1], size[2], 1))
        r = bmesh.ops.create_cube(bm, size=1.0, matrix=m)
        return self._finish(bm, self._faces_of(r["verts"]), color, smooth, colfn)

    def cyl(self, r_bot, r_top, h, pos=(0, 0, 0), rot=(0, 0, 0), color="WOOD", seg=8, group="body", smooth=False,
            cap=None, colfn=None, scl=(1, 1, 1), bottom_cap=None):
        """Cylinder / cone along local Z, base centre at pos. cap = colour of the top face (None = same)."""
        bm = self._bm(group)
        m = _mat(pos, rot, scl) @ Matrix.Translation((0, 0, h / 2))
        r = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r_bot,
                                  radius2=max(r_top, 0.0001), depth=h, matrix=m)
        faces = self._faces_of(r["verts"])
        self._finish(bm, faces, color, smooth, colfn)
        if cap is not None or smooth or bottom_cap is not None:
            bm.normal_update()
            up = (m.to_3x3() @ Vector((0, 0, 1))).normalized()
            for f in faces:
                if len(f.verts) == seg:     # the two caps stay flat even on a smooth cylinder
                    f.smooth = False
                    if cap is not None and f.normal.dot(up) > 0.5:
                        self._finish(bm, [f], cap, False)
                    elif bottom_cap is not None and f.normal.dot(up) < -0.5:
                        self._finish(bm, [f], bottom_cap, False)
        return faces

    def sphere(self, r, pos=(0, 0, 0), scl=(1, 1, 1), rot=(0, 0, 0), color="LEAF_MID", seg=10, rings=6,
               group="body", smooth=True, colfn=None, lumps=0.0, lump_scale=1.6, seed=None):
        """UV sphere (centre at pos). lumps > 0 = noise displacement (lumpy foliage, rocks)."""
        bm = self._bm(group)
        r_ = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r, matrix=Matrix.Identity(4))
        self._lump(r_["verts"], r, lumps, lump_scale, seed)
        bmesh.ops.transform(bm, matrix=_mat(pos, rot, scl), verts=r_["verts"])
        bm.normal_update()
        return self._finish(bm, self._faces_of(r_["verts"]), color, smooth, colfn)

    def ico(self, r, pos=(0, 0, 0), scl=(1, 1, 1), rot=(0, 0, 0), color="ROCK", subdiv=1, group="body",
            smooth=False, colfn=None, lumps=0.0, lump_scale=1.6, seed=None):
        bm = self._bm(group)
        r_ = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r, matrix=Matrix.Identity(4))
        self._lump(r_["verts"], r, lumps, lump_scale, seed)
        bmesh.ops.transform(bm, matrix=_mat(pos, rot, scl), verts=r_["verts"])
        bm.normal_update()
        return self._finish(bm, self._faces_of(r_["verts"]), color, smooth, colfn)

    def _lump(self, verts, r, amt, scale, seed):
        if amt <= 0:
            return
        off = Vector((self.rng.random() * 50, self.rng.random() * 50, self.rng.random() * 50)) if seed is None else \
            Vector((seed * 3.1, seed * 7.3, seed * 1.7))
        for v in verts:
            n = noise.noise(v.co / r * scale + off)
            v.co *= 1.0 + amt * n

    def strip(self, ring_list, color="THATCH", group="body", smooth=False, close=False, colfn=None, caps=False):
        """Loft through rings of equal length (list of lists of Vector). close = ring is a closed loop."""
        bm = self._bm(group)
        rings = [[bm.verts.new(p) for p in ring] for ring in ring_list]
        faces = []
        n = len(ring_list[0])
        for a, b in zip(rings[:-1], rings[1:]):
            for i in range(n if close else n - 1):
                j = (i + 1) % n
                faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
        if caps:
            for ring, rev in ((rings[0], True), (rings[-1], False)):
                faces.append(bm.faces.new(list(reversed(ring)) if rev else ring))
        bm.normal_update()
        return self._finish(bm, faces, color, smooth, colfn)

    def poly(self, pts, color="WOOD", group="body", smooth=False):
        """One polygon from world points."""
        bm = self._bm(group)
        f = bm.faces.new([bm.verts.new(p) for p in pts])
        bm.normal_update()
        return self._finish(bm, [f], color, smooth)

    def prism(self, profile, length, pos=(0, 0, 0), rot=(0, 0, 0), color="WOOD", group="body", smooth=False,
              cap_color=None):
        """Extrude a closed 2D profile [(y, z), ...] (counter-clockwise seen from +X) along X, centred."""
        m = _mat(pos, rot)
        a = [m @ Vector((-length / 2, y, z)) for y, z in profile]
        b = [m @ Vector((length / 2, y, z)) for y, z in profile]
        bm = self._bm(group)
        va = [bm.verts.new(p) for p in a]
        vb = [bm.verts.new(p) for p in b]
        n = len(profile)
        faces = [bm.faces.new((va[i], va[(i + 1) % n], vb[(i + 1) % n], vb[i])) for i in range(n)]
        caps = [bm.faces.new(list(reversed(va))), bm.faces.new(vb)]
        bmesh.ops.recalc_face_normals(bm, faces=faces + caps)
        bm.normal_update()
        self._finish(bm, faces, color, smooth)
        self._finish(bm, caps, cap_color or color, False)
        return faces + caps

    def blade(self, base, tip, width, color="TUFT", group="body_nh", bend=(0, 0, 0)):
        """A thin double-sided leaf/grass blade (two triangles each side)."""
        base, tip = Vector(base), Vector(tip)
        d = (tip - base)
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-6:
            side = Vector((1, 0, 0))
        side = side.normalized() * width / 2
        mid = base + d * 0.45 + Vector(bend)
        bm = self._bm(group)
        v = [bm.verts.new(p) for p in (base - side, base + side, mid + side, mid - side)]
        t = bm.verts.new(tip)
        faces = [bm.faces.new((v[0], v[1], v[2], v[3])), bm.faces.new((v[3], v[2], t))]
        # back side (the toon shader culls back faces)
        v2 = [bm.verts.new(p.co) for p in v]
        t2 = bm.verts.new(t.co)
        faces += [bm.faces.new((v2[3], v2[2], v2[1], v2[0])), bm.faces.new((t2, v2[2], v2[3]))]
        bm.normal_update()
        return self._finish(bm, faces, color, False)

    # -- output --
    def export(self, out_dir=OUT_DIR, name=None):
        name = name or self.name
        bpy.ops.wm.read_factory_settings(use_empty=True)
        objs = []
        tris = 0
        for g, bm in self.groups.items():
            _triangulate(bm)
            bm.normal_update()
            me = bpy.data.meshes.new(g)
            bm.to_mesh(me)
            bm.free()
            tris += sum(len(p.vertices) - 2 for p in me.polygons)
            ob = bpy.data.objects.new(g, me)
            bpy.context.scene.collection.objects.link(ob)
            objs.append(ob)
        self.groups = {}
        _export_glb(os.path.join(out_dir, name + ".glb"))
        print("  %-18s %5d tris" % (name, tris))
        return tris


def _triangulate(bm):
    """Fixed triangulation before export: the exporter's own n-gon split is not stable between runs
    (same geometry, different index order) -> glb bytes would change on every rebuild."""
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")


def _export_glb(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_vertex_color="ACTIVE",
                              export_materials="NONE", export_yup=True, export_texcoords=False,
                              export_normals=True, export_animations=False, export_extras=False,
                              export_skins=False, export_morph=False)


class PartSet:
    """Several separately-pivoted parts in one glb (resident parts). Each part = one Model-like group set,
    exported as an object whose origin is the joint pivot."""

    def __init__(self, name):
        self.name = name
        self.parts = []          # (part_name, Model, pivot)

    def add(self, part_name, model, pivot=(0, 0, 0)):
        self.parts.append((part_name, model, Vector(pivot)))

    def export(self, out_dir=OUT_DIR):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        total = 0
        for pname, model, pivot in self.parts:
            for g, bm in model.groups.items():
                _triangulate(bm)
                bmesh.ops.translate(bm, verts=bm.verts, vec=-pivot)
                bm.normal_update()
                me = bpy.data.meshes.new(pname)
                bm.to_mesh(me)
                bm.free()
                total += sum(len(p.vertices) - 2 for p in me.polygons)
                ob = bpy.data.objects.new(pname if g == "body" else pname + "_" + g, me)
                ob.location = pivot
                bpy.context.scene.collection.objects.link(ob)
            model.groups = {}
        _export_glb(os.path.join(out_dir, self.name + ".glb"))
        print("  %-18s %5d tris (%d parts)" % (self.name, total, len(self.parts)))


def out_dir_from_argv():
    if "--" in sys.argv:
        args = sys.argv[sys.argv.index("--") + 1:]
        if args:
            return args[0]
    return OUT_DIR
