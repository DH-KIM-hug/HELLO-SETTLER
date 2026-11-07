"""Units: 1 = 1 cell = adult resident height (~5 cm in the world, art bible 8.13). Shared kit for build_creatures.py / build_puppy.py.

Rigid jointed critters with baked clips (E3-12 tiny creatures, E3-13 puppy):
  * a critter = a tree of joints (glTF nodes "j_<joint>", plain empties, origin = the joint pivot) + rigid mesh parts under them,
    each joint holding up to two LODs:  "<part>" (close) and "<part>__far" (far, art bible 8.3 / 8.9), plus the usual outline
    suffix groups ("<part>_body_nl" / "<part>_body_nh", lowpoly.py) -> Art.parts("critters/<key>") still works (flat, per part).
  * clips = Blender actions on the joint empties, one NLA track per clip name on every joint -> one glTF animation per clip
    (Godot: AnimationPlayer, animation names = clip names, tracks on "j_*" node transforms). Every joint is keyed in every clip
    so switching clips always resets the whole pose.
  * no skin, no materials, vertex colours only (linear in the glb - Godot side must convert like Art._Acc does).
Front = -Y in Blender (Godot +Z), Z up. Ground creatures: model origin = centre of the footprint on the ground.
Flyers (butterfly, bee): origin = body centre (the view sets the flying height). Cocoon: origin = the silk anchor on top.
"""
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

from lowpoly import Model, _lin, _triangulate

FPS = 30


class Critter:
    def __init__(self, name):
        self.name = name
        self.joints = {}            # joint -> {"parent", "pivot": Vector (rest, model space)}
        self.order = []
        self.parts = []             # (joint, part name, Model)
        self.clips = []             # (clip, frames, fn)

    def joint(self, name, pivot, parent=None):
        self.joints[name] = {"parent": parent, "pivot": Vector(pivot)}
        self.order.append(name)
        return name

    def part(self, joint, part_name=None, seed=1):
        """A new Model drawn in model-space rest coordinates, rigidly attached to `joint`."""
        m = Model(part_name or joint, seed)
        self.parts.append((joint, part_name or joint, m))
        return m

    def clip(self, name, frames, fn):
        """fn(t in [0, 1)) -> {joint: dict(r=(rx, ry, rz) rad, l=(x, y, z) offset in parent space, s=(sx, sy, sz))}."""
        self.clips.append((name, frames, fn))

    # ── export ──
    def export(self, path):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        sc = bpy.context.scene
        sc.render.fps = FPS
        objs = {}
        for j in self.order:
            d = self.joints[j]
            e = bpy.data.objects.new("j_" + j, None)
            e.empty_display_size = 0.05
            sc.collection.objects.link(e)
            par = d["parent"]
            e.location = d["pivot"] - (self.joints[par]["pivot"] if par else Vector())
            if par:
                e.parent = objs[par]
            e.rotation_mode = "XYZ"
            objs[j] = e
        tris = {"near": 0, "far": 0}
        per = {}
        for j, pn, m in self.parts:
            piv = self.joints[j]["pivot"]
            for g, bm in m.groups.items():
                _triangulate(bm)
                bmesh.ops.translate(bm, verts=bm.verts, vec=-piv)
                bm.normal_update()
                nm = pn if g == "body" else pn + "_" + g
                me = bpy.data.meshes.new(nm)
                bm.to_mesh(me)
                bm.free()
                n = len(me.polygons)
                lod = "far" if pn.endswith("__far") else "near"
                tris[lod] += n
                per[pn] = per.get(pn, 0) + n
                ob = bpy.data.objects.new(nm, me)
                sc.collection.objects.link(ob)
                ob.parent = objs[j]
            m.groups = {}
        for name, frames, fn in self.clips:
            self._bake(objs, name, frames, fn)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_vertex_color="ACTIVE",
                                  export_materials="NONE", export_yup=True, export_texcoords=False,
                                  export_normals=True, export_animations=True, export_animation_mode="NLA_TRACKS",
                                  export_skins=False, export_morph=False, export_extras=False,
                                  export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False,
                                  export_optimize_animation_keep_anim_object=True)
        print("  %-22s near %4d tris  far %3d tris  clips %s" % (os.path.basename(path), tris["near"], tris["far"],
                                                                  ",".join(c[0] for c in self.clips)))
        self.tris = tris
        return tris

    def _bake(self, objs, name, frames, fn):
        rest = {j: (o.location.copy()) for j, o in objs.items()}
        acts = {}
        for j, o in objs.items():
            o.animation_data_create()
            a = bpy.data.actions.new(name + "|" + j)
            a.use_fake_user = True
            o.animation_data.action = a
            acts[j] = a
        for f in range(frames + 1):
            t = (f / frames) % 1.0
            pose = fn(t)
            for j, o in objs.items():
                p = pose.get(j, {})
                o.rotation_euler = Euler(p.get("r", (0, 0, 0)), "XYZ")
                o.location = rest[j] + Vector(p.get("l", (0, 0, 0)))
                o.scale = Vector(p.get("s", (1, 1, 1)))
                for prop in ("rotation_euler", "location", "scale"):
                    o.keyframe_insert(prop, frame=f + 1)
        for j, o in objs.items():
            tr = o.animation_data.nla_tracks.new()
            tr.name = name
            st = tr.strips.new(name, 1, acts[j])
            st.name = name
            o.animation_data.action = None
            o.rotation_euler = Euler((0, 0, 0))
            o.location = rest[j]
            o.scale = Vector((1, 1, 1))


# ───────── shape helpers (all in model space, return faces) ─────────
def S(t, k=1.0, ph=0.0):
    return math.sin((t * k + ph) * 2 * math.pi)


def C(t, k=1.0, ph=0.0):
    return math.cos((t * k + ph) * 2 * math.pi)


def ellipsoid(m, c, r3, color, seg=8, rings=5, rot=(0, 0, 0), group="body", colfn=None, deform=None):
    """Smooth ellipsoid. Tris = 2 * seg * (rings - 1)."""
    bm = m._bm(group)
    res = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    R = Euler(rot, "XYZ").to_matrix()
    for v in res["verts"]:
        n = v.co.normalized()
        p = Vector((n.x * r3[0], n.y * r3[1], n.z * r3[2]))
        if deform:
            p = deform(p, n)
        v.co = Vector(c) + R @ p
    faces = m._faces_of(res["verts"])
    bm.normal_update()
    m._finish(bm, faces, color, True, colfn)
    return faces


def dome(m, c, r3, color, seg=10, rings=4, rot=(0, 0, 0), group="body", colfn=None, bottom=None):
    """Upper half ellipsoid with a flat underside (shells). Tris ~ seg * (2 * rings - 1) + seg - 2."""
    bm = m._bm(group)
    R = Euler(rot, "XYZ").to_matrix()
    rows = []
    for i in range(rings + 1):
        ph = (math.pi / 2) * i / rings
        if i == rings:
            rows.append([bm.verts.new(Vector(c) + R @ Vector((0, 0, r3[2])))])
            break
        row = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            p = Vector((math.cos(a) * math.cos(ph) * r3[0], math.sin(a) * math.cos(ph) * r3[1], math.sin(ph) * r3[2]))
            row.append(bm.verts.new(Vector(c) + R @ p))
        rows.append(row)
    faces = []
    for i in range(rings):
        a, b = rows[i], rows[i + 1]
        for k in range(seg):
            k2 = (k + 1) % seg
            if len(b) == 1:
                faces.append(bm.faces.new((a[k], a[k2], b[0])))
            else:
                faces.append(bm.faces.new((a[k], a[k2], b[k2], b[k])))
    base = bm.faces.new(list(reversed(rows[0])))
    bm.normal_update()
    m._finish(bm, faces, color, True, colfn)
    m._finish(bm, [base], bottom or color, False)
    return faces + [base]


def limb(m, a, b, r0, r1, color, seg=4, group="body", cap=True, smooth=True):
    """Tapered tube a -> b (open at a, closed tip at b if cap). Tris = 2 * seg (+ seg - 2 if cap)."""
    a, b = Vector(a), Vector(b)
    d = (b - a)
    L = d.length
    z = d.normalized()
    x = z.cross(Vector((0, 0, 1)))
    if x.length < 1e-4:
        x = Vector((1, 0, 0))
    x.normalize()
    y = z.cross(x)
    bm = m._bm(group)
    ra, rb = [], []
    for k in range(seg):
        ang = 2 * math.pi * k / seg
        o = x * math.cos(ang) + y * math.sin(ang)
        ra.append(bm.verts.new(a + o * r0))
        rb.append(bm.verts.new(b + o * r1))
    faces = [bm.faces.new((ra[k], ra[(k + 1) % seg], rb[(k + 1) % seg], rb[k])) for k in range(seg)]
    if cap:
        faces.append(bm.faces.new(rb))
    bm.normal_update()
    m._finish(bm, faces, color, smooth)
    if cap:
        faces[-1].smooth = False
    return faces


def polyline_leg(m, pts, r, color, seg=3, group="body"):
    """A jointed thin leg through pts (insect legs: hip -> knee -> foot). Tris ~ 2 * seg * (n - 1)."""
    out = []
    for i in range(len(pts) - 1):
        out += limb(m, pts[i], pts[i + 1], r, r * 0.85, color, seg=seg, group=group, cap=(i == len(pts) - 2), smooth=False)
    return out


def flat(m, pts, color, group="body_nl", z_up=True, double=True):
    """A flat polygon (wings), double-sided (the toon shader culls back faces)."""
    bm = m._bm(group)
    vs = [bm.verts.new(Vector(p)) for p in pts]
    faces = [bm.faces.new(vs)]
    if double:
        vs2 = [bm.verts.new(Vector(p)) for p in pts]
        faces.append(bm.faces.new(list(reversed(vs2))))
    bm.normal_update()
    m._finish(bm, faces, color, False)
    return faces


def dot_eye(m, c, r, color="1e1612", seg=5, rings=3, group="body_nh"):
    return ellipsoid(m, c, (r, r, r), color, seg=seg, rings=rings, group=group)
