"""Resident kit v3 (A20 v3, design/characters/*.png): soft, round storybook villagers (~3.2 heads tall, jobs_a / expressions_a).

Two glbs:
  resident.glb        one armature ("rig") + every body part as a smooth SKINNED mesh, each in two LODs
                      ("<part>" close ~2-3.5k tris per assembled resident, "<part>__far" ~0.5-0.7k) + all animations
                      (Blender actions -> Godot AnimationPlayer). Godot (view/resident_model.gd) picks the parts per
                      resident, merges them into one skinned mesh per LOD and plays the animations.
  resident_props.glb  rigid props (carried items, tools, the elder's cane) - pivots at the carry point / hands,
                      attached in Godot to the chest / hand bones (art.gd Art.parts).

Tint keys (vertex colour, stored as sRGB numbers = what Godot reads) -> replaced per resident, the blue channel = brightness:
  (0, 0, b) cloth   (1, 0, b) skin   (0, 1, b) hair   (0, .5, b) accent (headscarf / cap / shawl)
Everything else is a fixed colour from Balance.LOOK_FIXED (LOOK_*). Soft painted shading is baked into the brightness
channel of the key colours (folds, under-chin, hair locks). The face is a texture atlas (art/models/resident_face.png,
paint_face_atlas.py) projected from the front onto the head (UV); render/resident.gdshader picks the expression cell.
Front = -Y (Godot +Z). Rest pose = standing, arms slightly out.
Run: blender -b --factory-startup --python build_residents.py -- [out_dir] [--render <png_prefix> <scratch.blend>]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, PartSet, PALETTE, shade, mix, srgb, out_dir_from_argv  # noqa: E402

OUT = out_dir_from_argv()

# ───────── proportions (chibi storybook, jobs_a: head ~1/3 of the height) ─────────
HIP = 0.56
WAIST = 0.66
SHOULDER = 1.1
NECK = 1.17
HEAD_R = 0.315
HEAD_C = 1.49
HEAD_S = (1.04, 0.97, 0.97)
ARM_X = 0.285
LEG_X = 0.105
ITEM = Vector((0, -0.42, 0.9))

CLOTH = (0, 0, 1.0)
CLOTH_D = (0, 0, 0.84)
SKIN = (1, 0, 1.0)
HAIR = (0, 1, 1.0)
HAIR_D = (0, 1, 0.82)
ACCENT = (0, 0.5, 1.0)
ACCENT_D = (0, 0.5, 0.84)
SHAWL = (0, 0.25, 1.0)        # elder's shawl has its own colour (Godot: shawl)
SHAWL_D = (0, 0.25, 0.84)
KEYS = (CLOTH, SKIN, HAIR, ACCENT)

LOD = 0          # 0 close, 1 far (set while building)


def Q(close, far):
    return close if LOD == 0 else far


def sm(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a))) if b != a else (1.0 if x >= a else 0.0)
    return t * t * (3 - 2 * t)


def col(c):
    """Key tuple (already 'sRGB numbers') or palette name -> sRGB tuple."""
    if isinstance(c, tuple) and len(c) == 3 and c[:2] in ((0, 0), (1, 0), (0, 1), (0, 0.5), (0, 0.25)):
        return c
    return srgb(c)


def is_key(c):
    r, g = c[0], c[1]
    return (r < 0.002 and (g < 0.002 or g > 0.998 or abs(g - 0.5) < 0.002 or abs(g - 0.25) < 0.002)) or (r > 0.998 and g < 0.002)


def catmull(pts, n):
    """Smooth a control polyline [(r, z), ...] into n points (Catmull-Rom through every control point)."""
    if n <= len(pts):
        idx = [round(i * (len(pts) - 1) / (n - 1)) for i in range(n)]
        return [pts[i] for i in idx]
    out = []
    segs = len(pts) - 1
    for i in range(n):
        t = i / (n - 1) * segs
        k = min(int(t), segs - 1)
        u = t - k
        p0 = pts[max(k - 1, 0)]
        p1, p2 = pts[k], pts[k + 1]
        p3 = pts[min(k + 2, segs)]
        o = []
        for d in range(2):
            a0, a1, a2, a3 = p0[d], p1[d], p2[d], p3[d]
            o.append(0.5 * ((2 * a1) + (-a0 + a2) * u + (2 * a0 - 5 * a1 + 4 * a2 - a3) * u * u + (-a0 + 3 * a1 - 3 * a2 + a3) * u ** 3))
        out.append(tuple(o))
    return out


# ───────── soft part: one bmesh with colours, face UVs and per-vertex skin weights ─────────
class Part:
    def __init__(self, name, weights, head=False):
        self.name = name
        self.bm = bmesh.new()
        self.cl = self.bm.loops.layers.float_color.new("Color")
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.uv2 = self.bm.loops.layers.uv.new("UVDetail")     # A20 v4: painted detail atlas tile coords (TEXCOORD_1)
        self.weights = weights          # fn(co) -> {bone: w}
        self.head = head                # head parts: face UV + CUSTOM data in Godot
        self.uvfn = face_uv if head else None
        self.shade = None               # fn(co, normal) -> brightness multiplier for key colours

    def grid(self, rows, closed=True, colfn=None, color=CLOTH, cap0=None, cap1=None, flip=False, out=None, det=None):
        """rows = list of rings (lists of Vector). Quads between consecutive rings. cap0/cap1 = close the first / last
        ring with a fan to its centre. Faces are oriented away from their ring's centre (or along out(centre) -> Vector);
        flip = the other way (inside / back faces)."""
        bm = self.bm
        vr = [[bm.verts.new(p) for p in r] for r in rows]
        cen = [sum(r, Vector()) / len(r) for r in rows]
        faces = []
        n = len(rows[0])
        nat = []                        # det = (cell, tiles around, tiles along): natural ring/row tile coords
        for k, (a, b) in enumerate(zip(vr[:-1], vr[1:])):
            rc = (cen[k] + cen[k + 1]) / 2
            for i in range(n if closed else n - 1):
                j = (i + 1) % n
                f = bm.faces.new((a[i], a[j], b[j], b[i]))
                f.normal_update()
                fc = f.calc_center_median()
                want = out(fc) if out else (fc - rc)
                if (f.normal.dot(want) < 0) != flip:
                    f.normal_flip()
                faces.append(f)
                if det:
                    nu = n if closed else n - 1
                    m = len(rows) - 1
                    tab = {a[i]: (i, k), a[j]: (i + 1, k), b[j]: (i + 1, k + 1), b[i]: (i, k + 1)}
                    nat.append((f, {v: (uu / nu * det[1], kk / m * det[2]) for v, (uu, kk) in tab.items()}))
        for cap, k, nxt in ((cap0, 0, 1), (cap1, len(vr) - 1, len(vr) - 2)):
            if cap is None:
                continue
            ring = vr[k]
            c = bm.verts.new(cen[k])
            want = cen[k] - cen[nxt]
            for i in range(n):
                j = (i + 1) % n
                f = bm.faces.new((ring[i], ring[j], c))
                f.normal_update()
                if (f.normal.dot(want) < 0) != flip:
                    f.normal_flip()
                faces.append(f)
        bm.normal_update()
        self.paint(faces, colfn, color)
        for f, tab in nat:
            self._set_det(f, det[0], [tab.get(lo.vert, (0.0, 0.0)) for lo in f.loops])
        return faces

    def _set_det(self, f, cell, uvs):
        a = (cell + 0.5) / 32.0
        for lo, (u, v) in zip(f.loops, uvs):
            lo[self.uv2].uv = (u, 1.0 - v)                 # glTF flips V (as the face UV)
            c = lo[self.cl]
            lo[self.cl] = (c[0], c[1], c[2], a)

    def detail(self, faces, cell, fn):
        """Painted detail on these faces: cell = atlas cell (int or fn(face)), fn(co) -> (u, v, period_u); u None = on the
        axis (pole) -> the face's other u. A face crossing the u wrap gets one period added on its small side."""
        for f in faces:
            ce = cell(f) if callable(cell) else cell
            if ce is None:
                continue
            q = [fn(lo.vert.co) for lo in f.loops]
            P = q[0][2]
            us = [x[0] for x in q]
            known = [u for u in us if u is not None]
            if P and known and max(known) - min(known) > P / 2:
                us = [None if u is None else (u + P if u < P / 2 else u) for u in us]
                known = [u for u in us if u is not None]
            avg = sum(known) / len(known) if known else 0.0
            self._set_det(f, ce, [(avg if u is None else u, x[1]) for u, x in zip(us, q)])

    def sphere(self, c, r, seg, rings, color=SKIN, colfn=None, deform=None):
        bm = self.bm
        res = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
        vs = res["verts"]
        for v in vs:
            p = Vector((v.co.x * r[0], v.co.y * r[1], v.co.z * r[2]))
            if deform:
                p = deform(p)
            v.co = Vector(c) + p
        faces = list({f: 1 for v in vs for f in v.link_faces})
        bm.normal_update()
        self.paint(faces, colfn, color)
        return faces

    def paint(self, faces, colfn, color):
        for f in faces:
            c = col(colfn(f) if colfn else color)
            for lo in f.loops:
                lo[self.cl] = tuple(c) + (1.0,)
            f.smooth = True

    def finish(self):
        """Bake soft shading into the key colours' brightness, face UVs (head), triangulate."""
        bm = self.bm
        bm.normal_update()
        for f in bm.faces:
            for lo in f.loops:
                c = lo[self.cl]
                if self.shade and is_key(c):
                    k = self.shade(lo.vert.co, lo.vert.normal)
                    lo[self.cl] = (c[0], c[1], max(0.0, min(1.0, c[2] * k)), c[3])
                u, v = self.uvfn(lo.vert.co) if self.uvfn else (-1.0, -1.0)
                lo[self.uv].uv = (u, 1.0 - v)          # the glTF exporter flips V; Godot then reads v as written
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
        return bm


# face atlas projection (front, -Y): must match paint_face_atlas.py
FACE_W = 0.5
FACE_TOP = HEAD_C + 0.17
FACE_H = 0.3


def face_uv(co):
    return ((co.x + FACE_W / 2) / FACE_W, (FACE_TOP - co.z) / FACE_H) if co.y < -0.05 else (-1.0, -1.0)


# ───────── painted detail atlases (A20 v4): cells must match pack_detail_atlas.py ─────────
# vertex colour alpha = (cell + 0.5) / 32 (1.0 = no detail), UV2 = tile coords; render/resident.gdshader multiplies tint x detail
H_STRAIGHT, H_WAVY, H_CURLS, H_BRAID, H_BEARD, H_BUN, _H_TIPS, H_FINE = range(8)   # 6 = lock tips (spare)
C_LINEN, C_FOLDS, C_APRON, C_CUFF, C_LEATHER, C_POUCH, C_HOOD, C_KNIT, C_STRAW, C_WOOL = range(16, 26)


def m_cyl(cx=0.0, cy=0.0, tiles=4.0, vs=0.25, z0=0.0):
    """Cylinder around a vertical axis: u around (seam at the back), v down from z0 (tile height vs)."""
    def fn(co):
        dx, dy = co.x - cx, co.y - cy
        v = (z0 - co.z) / vs
        if dx * dx + dy * dy < 1e-7:
            return (None, v, tiles)
        return ((math.atan2(dx, -dy) / (2 * math.pi) + 0.5) * tiles, v, tiles)
    return fn


def m_crown(ctr=None, tiles=6.0, vs=0.22, R=None):
    """Hair: strands radiate from the crown (spherical above the head centre), then fall straight down."""
    c = ctr or Vector((0, 0.015, HEAD_C))
    R = R or HEAD_R

    def fn(co):
        d = co - c
        rh = math.hypot(d.x, d.y)
        ph = math.atan2(rh, d.z)
        v = (ph * R if ph <= math.pi / 2 else math.pi / 2 * R + (c.z - co.z)) / vs
        if rh < 1e-4:
            return (None, v, tiles)
        return ((math.atan2(d.x, -d.y) / (2 * math.pi) + 0.5) * tiles, v, tiles)
    return fn


def m_radial(cx=0.0, cy=0.0, tiles=8.0, vs=0.08):
    """Flat ring (hat brim): u around, v outward with the radius (straw rows run around the brim)."""
    def fn(co):
        dx, dy = co.x - cx, co.y - cy
        rr = math.hypot(dx, dy)
        if rr < 1e-4:
            return (None, 0.0, tiles)
        return ((math.atan2(dx, -dy) / (2 * math.pi) + 0.5) * tiles, rr / vs, tiles)
    return fn


def m_plane(o, right, down, w, h):
    """Planar: u along `right` (w = one tile), v along `down` (h = one tile), from the corner o."""
    o, right, down = Vector(o), Vector(right).normalized(), Vector(down).normalized()

    def fn(co):
        d = co - o
        return (d.dot(right) / w, d.dot(down) / h, 0)
    return fn


def lathe_rows(prof, seg, sy=0.82, wob=None, y0=0.0):
    """Rings through a profile [(radius, z), ...]; wob(theta, z) -> radius multiplier (folds)."""
    rows = []
    for r, z in prof:
        ring = []
        for i in range(seg):
            a = -math.pi / 2 + i / seg * 2 * math.pi           # start at the front (-Y)
            k = wob(a, z) if wob else 1.0
            ring.append(Vector((math.cos(a) * r * k, math.sin(a) * r * k * sy + y0, z)))
        rows.append(ring)
    return rows


def front_dist(f):
    c = f.calc_center_median()
    return c


# ───────── skin weights ─────────
def W(**kw):
    s = sum(kw.values())
    return {k.replace("_L", ".L").replace("_R", ".R"): v / s for k, v in kw.items() if v > 1e-4}


def w_head(co):
    t = sm(NECK - 0.06, NECK + 0.04, co.z)
    return W(skull=t + 1e-3, chest=1 - t)


def w_torso(skirt_thigh=0.45):
    def fn(co):
        up = sm(WAIST - 0.06, WAIST + 0.12, co.z)
        out = {"chest": up, "skirt": 1 - up}
        if co.z < HIP + 0.02:
            side = "thigh_L" if co.x > 0 else "thigh_R"
            k = skirt_thigh * sm(0.02, 0.16, abs(co.x)) * sm(HIP + 0.02, HIP - 0.2, co.z)
            out = {"skirt": 1 - k, side: k}
        if co.z > SHOULDER - 0.12 and abs(co.x) > 0.17:
            side = "upper_arm_L" if co.x > 0 else "upper_arm_R"
            k = 0.35 * sm(0.17, 0.27, abs(co.x)) * sm(SHOULDER - 0.12, SHOULDER, co.z)
            out = {k2: v * (1 - k) for k2, v in out.items()}
            out[side] = k
        return W(**out)
    return fn


ARM_TOP = Vector((ARM_X, 0.0, SHOULDER - 0.03))
ELBOW = Vector((ARM_X + 0.045, 0.0, SHOULDER - 0.27))
WRIST = Vector((ARM_X + 0.07, -0.01, SHOULDER - 0.47))
HAND = Vector((ARM_X + 0.075, -0.015, SHOULDER - 0.53))


def w_arm(side):
    s = 1 if side == "L" else -1

    def fn(co):
        p = Vector((co.x * s, co.y, co.z))
        z = p.z
        e = sm(ELBOW.z + 0.05, ELBOW.z - 0.05, z)
        h = sm(WRIST.z + 0.01, WRIST.z - 0.04, z)
        return W(**{"upper_arm_" + side: (1 - e), "forearm_" + side: e * (1 - h), "hand_" + side: h})
    return fn


KNEE = 0.3
ANKLE = 0.09


def w_leg(side):
    def fn(co):
        k = sm(KNEE + 0.05, KNEE - 0.05, co.z)
        f = sm(ANKLE + 0.02, ANKLE - 0.03, co.z)
        top = sm(HIP + 0.04, HIP - 0.06, co.z)
        return W(**{"skirt": 1 - top, "thigh_" + side: top * (1 - k), "shin_" + side: k * (1 - f), "foot_" + side: f})
    return fn


def w_fixed(bone):
    return lambda co: {bone: 1.0}


# ───────── the parts ─────────
def ao_body(co, n):
    k = 1.0
    k *= 1.0 - 0.12 * sm(-0.2, -0.9, n.z)                   # undersides darker
    return k


def build_head(parts):
    p = Part("head", w_head, head=True)
    seg, rings = Q(18, 10), Q(10, 5)

    def deform(v):
        # chubby cheeks + soft chin, flat-ish back of the skull
        x, y, z = v
        if z < 0:
            x *= 1.0 + 0.05 * (-z / HEAD_R)
            y *= 1.0 - 0.04 * (-z / HEAD_R)
        if y > 0:
            y *= 0.96
        return Vector((x * HEAD_S[0], y * HEAD_S[1], z * HEAD_S[2]))
    p.sphere((0, 0, HEAD_C), (HEAD_R, HEAD_R, HEAD_R), seg, rings, color=SKIN, deform=deform)
    # neck
    p.grid(lathe_rows([(0.085, NECK - 0.09), (0.088, NECK + 0.03), (0.1, NECK + 0.13)], Q(10, 5), sy=0.9), color=SKIN)
    # ears
    for sx in ((-1, 1) if LOD == 0 else ()):
        p.sphere((sx * HEAD_R * 1.0, 0.03, HEAD_C - 0.04), (0.04, 0.06, 0.075), Q(8, 4), Q(5, 3), color=SKIN)
    p.shade = lambda co, n: 1.0 - 0.13 * sm(HEAD_C - 0.2, NECK, co.z) if co.z < HEAD_C - 0.16 else 1.0
    parts.append(p)


def dress_torso(name, prof, sy, colfn, thigh, extra=None, seg=(14, 7), folds=0.0):
    p = Part(name, w_torso(thigh))
    n = Q(len(prof) + 4, max(5, len(prof) - 2))
    pr = catmull(prof, n)
    hem = prof[0][1]

    def wob(a, z):
        return 1.0 + folds * sm(WAIST - 0.05, hem, z) * math.sin(a * 7.0) if folds else 1.0
    rows = lathe_rows(pr, Q(*seg), sy=sy, wob=wob)
    fs = p.grid(rows, colfn=colfn, cap0=True)
    p.detail(fs, lambda f: C_FOLDS if f.calc_center_median().z < WAIST - 0.03 else C_LINEN, m_cyl(tiles=3.0, vs=0.55, z0=SHOULDER))
    if extra:
        extra(p)
    if LOD == 0:                      # cream shirt v-neck (a little patch lying on the chest)
        vneck_patch(p, pr, sy)

    def sh(co, nn):
        k = ao_body(co, nn)
        if co.z < HIP and folds:                            # fold valleys
            a = math.atan2(co.y / sy, co.x)
            k *= 1.0 - 0.1 * (0.5 - 0.5 * math.sin(a * 7.0)) * sm(WAIST, hem, co.z)
        k *= 1.0 - 0.1 * sm(WAIST + 0.08, WAIST - 0.02, co.z) * sm(WAIST - 0.12, WAIST - 0.02, co.z)   # under the belt
        return k
    p.shade = sh
    return p


def surf_r(pr, z):
    for (r0, z0), (r1, z1) in zip(pr[:-1], pr[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / max(z1 - z0, 1e-6)
    return pr[-1][0]


def vneck_patch(p, pr, sy, top=SHOULDER - 0.015, depth=0.14, w=0.075):
    rows = []
    for j in range(4):
        t = j / 3
        z = top - t * depth
        hw = w * (1 - t) + 0.004
        ring = []
        for i in range(5):
            x = -hw + 2 * hw * i / 4
            r = surf_r(pr, z) + 0.006
            a = math.asin(max(-0.99, min(0.99, x / r)))
            ring.append(Vector((x, -math.cos(a) * r * sy, z)))
        rows.append(ring)
    fs = p.grid(rows, closed=False, color="LOOK_SHIRT", out=lambda c: Vector((0, -1, 0)))
    p.detail(fs, C_LINEN, m_plane((-w, 0, top), (1, 0, 0), (0, 0, -1), 0.3, 0.3))


def make_belt(p, r, sy, color="LOOK_BELT"):
    fs = p.grid(lathe_rows([(r, WAIST - 0.035), (r + 0.007, WAIST), (r, WAIST + 0.035)], Q(18, 8), sy=sy), color=color)
    p.detail(fs, C_LEATHER, m_cyl(tiles=Q(7.0, 4.0), vs=0.075, z0=WAIST + 0.037))


def pouch(p, c, yaw, color="LOOK_BELT"):
    """Leather belt pouch (base_c / jobs_a): soft rounded bag + a flap, painted stitches (cloth atlas pouch cell)."""
    if LOD == 1:                                        # too small to see from afar
        return
    rot = Matrix.Rotation(yaw, 3, "Z")
    fwd = rot @ Vector((0, -1, 0))
    right = rot @ Vector((1, 0, 0))

    def bag(v):
        x, y, z = v
        y *= 1.0 - 0.35 * max(0.0, z / 0.07)            # flatter toward the top (hangs from the belt)
        return rot @ Vector((x * (1.0 + 0.15 * max(0.0, -z / 0.07)), y, z))
    fs = p.sphere(c, (0.062, 0.038, 0.07), 9, 5, color=shade(color, 1.3), deform=bag)
    o = c - right * 0.068 + Vector((0, 0, 0.075))
    p.detail(fs, C_POUCH, m_plane(o, right, (0, 0, -1), 0.136, 0.15))
    if LOD == 0:                                        # flap over the top half
        fl = p.sphere(c + fwd * 0.008 + Vector((0, 0, 0.03)), (0.066, 0.042, 0.042), 7, 3, color=shade("LOOK_BELT", 0.85),
                      deform=lambda v: rot @ Vector((v.x, v.y, max(v.z, -0.012))))
        p.detail(fl, C_LEATHER, m_plane(o, right, (0, 0, -1), 0.14, 0.14))


def build_torsos(parts):
    belt = (WAIST - 0.035, WAIST + 0.035)

    def vneck(c, depth=0.15):
        return c.y < -0.1 and c.z > SHOULDER - depth and abs(c.x) < (c.z - (SHOULDER - depth)) * 0.7 + 0.025

    # tunic / vest (jobs_a men: vest over the cream shirt, belt, to mid-thigh)
    def tunic_col(f):
        c = f.calc_center_median()
        return CLOTH_D if c.z < HIP - 0.08 else CLOTH

    def tunic_extra(p):
        # belt + buckle + pouch
        make_belt(p, 0.295, 0.8)   # outside the tunic polygon corners (14 sides)
        if LOD == 0:
            p.sphere((0, -0.248, WAIST), (0.04, 0.02, 0.032), Q(8, 4), Q(4, 2), color="WINDOW_LIT")
        pouch(p, Vector((0.17, -0.2, WAIST - 0.1)), -0.55)
    parts.append(dress_torso("torso_tunic", [(0.32, HIP - 0.2), (0.31, HIP - 0.06), (0.28, WAIST), (0.295, WAIST + 0.18),
                                             (0.29, SHOULDER - 0.12), (0.23, SHOULDER - 0.02), (0.1, NECK - 0.02)],
                             0.8, tunic_col, 0.5, tunic_extra, folds=0.02))

    # dress: bodice + full bell skirt to the shin (expressions_a)
    def dress_col(f):
        c = f.calc_center_median()
        return CLOTH_D if c.z < 0.25 else CLOTH

    def apron(p):
        # cream apron panel in front of the skirt (soft folds), waist band + bow at the back
        rows = []
        nu, nv = Q(9, 3), Q(8, 3)
        for j in range(nv + 1):
            t = j / nv
            z = WAIST - 0.02 - t * (WAIST - 0.2)
            r = skirt_r(z) * 1.035 + 0.01
            ring = []
            for i in range(nu + 1):
                u = i / nu
                a = -math.pi / 2 + (u - 0.5) * 1.5
                rr = r * (1.0 + 0.025 * t * math.sin(u * math.pi * 4))
                ring.append(Vector((math.cos(a) * rr, math.sin(a) * rr * 0.86, z)))
            rows.append(ring)
        fs = p.grid(rows, closed=False, color="LOOK_APRON", det=(C_APRON, 1.6, 1.0))
        # back side (so it is not see-through from below)
        p.grid(rows, closed=False, color="LOOK_APRON", flip=True)
        fs = p.grid(lathe_rows([(0.282, WAIST - 0.03), (0.282, WAIST + 0.03)], Q(18, 6), sy=0.86), color="LOOK_APRON")
        p.detail(fs, C_LINEN, m_cyl(tiles=6.0, vs=0.3, z0=WAIST))
        pouch(p, Vector((-0.19, -0.2, WAIST - 0.11)), 0.6)
        for sx in ((-1, 1) if LOD == 0 else ()):
            p.sphere((sx * 0.06, 0.25, WAIST), (0.06, 0.03, 0.04), Q(8, 4), Q(4, 2), color="LOOK_APRON")
        p.sphere((0.04, 0.25, WAIST - 0.12), (0.025, 0.02, 0.09), Q(6, 3), Q(4, 2), color="LOOK_APRON")

    skirt = [(0.43, 0.2), (0.41, 0.3), (0.37, HIP - 0.04), (0.31, WAIST - 0.06), (0.275, WAIST), (0.285, WAIST + 0.16),
             (0.28, SHOULDER - 0.12), (0.22, SHOULDER - 0.02), (0.1, NECK - 0.02)]
    sk_pr = catmull(skirt, 40)

    def skirt_r(z):
        best = min(sk_pr, key=lambda rz: abs(rz[1] - z))
        return best[0]
    parts.append(dress_torso("torso_dress", skirt, 0.86, dress_col, 0.3, apron, folds=0.03))

    # robe: to the ground, rope belt (chapel keeper)
    def robe_col(f):
        c = f.calc_center_median()
        return CLOTH_D if c.z < HIP - 0.1 else CLOTH

    def robe_extra(p):
        fs = p.sphere((0, 0.13, SHOULDER - 0.02), (0.2, 0.12, 0.1), Q(12, 5), Q(6, 3), color=CLOTH_D)       # hood
        p.detail(fs, C_HOOD, m_cyl(tiles=2.0, vs=0.2, z0=SHOULDER + 0.08))
        fs = p.grid(lathe_rows([(0.29, WAIST - 0.025), (0.295, WAIST), (0.29, WAIST + 0.025)], Q(16, 6), sy=0.82), color="LOOK_STRAW_DARK")
        p.detail(fs, C_STRAW, m_cyl(tiles=8.0, vs=0.06, z0=WAIST + 0.03))
        p.sphere((0.1, -0.2, WAIST - 0.15), (0.02, 0.02, 0.12), Q(6, 3), Q(4, 2), color="LOOK_STRAW_DARK")
    parts.append(dress_torso("torso_robe", [(0.4, 0.05), (0.36, 0.25), (0.31, HIP), (0.285, WAIST), (0.29, WAIST + 0.16),
                                            (0.285, SHOULDER - 0.12), (0.225, SHOULDER - 0.02), (0.1, NECK - 0.02)],
                             0.82, robe_col, 0.25, robe_extra, folds=0.03))


def arm_rows(prof, side, seg):
    """Tube along the arm polyline (shoulder -> hand), prof = [(t, r), ...] t along the path."""
    s = 1 if side == "L" else -1
    path = [ARM_TOP, ELBOW, WRIST]
    L1 = (ELBOW - ARM_TOP).length
    L2 = (WRIST - ELBOW).length
    rows = []
    for t, r in prof:
        d = t * (L1 + L2)
        if d <= L1:
            a, b, u = path[0], path[1], d / L1
        else:
            a, b, u = path[1], path[2], (d - L1) / L2
        c = a.lerp(b, u)
        ax = (b - a).normalized()
        side_v = ax.cross(Vector((0, 1, 0))).normalized()
        fwd = side_v.cross(ax).normalized()
        ring = []
        for i in range(seg):
            ang = i / seg * 2 * math.pi
            p = c + (side_v * math.cos(ang) + fwd * math.sin(ang)) * r
            ring.append(Vector((p.x * s, p.y, p.z)))
        if s < 0:
            ring.reverse()
        rows.append(ring)
    return rows


def hand(p, side, color=SKIN):
    """Soft paddle hand (fingers together, slightly cupped) + a separate thumb at close LOD (jobs_a)."""
    s = 1 if side == "L" else -1
    c = Vector((HAND.x * s, HAND.y, HAND.z))

    def palm(v):
        x, y, z = v
        if z < 0:                                       # fingers taper a little and curl inward
            x *= 1.0 - 0.18 * (-z / 0.085)
            y += 0.012 * (-z / 0.085) ** 2
        return Vector((x, y, z))
    p.sphere(c, (0.05, Q(0.064, 0.06), 0.085), Q(10, 5), Q(7, 3), color=color, deform=palm)
    if LOD == 0:                                        # thumb: a small capsule pointing forward-down, inner side
        rot = Matrix.Rotation(-0.55, 3, "X") @ Matrix.Rotation(0.35 * s, 3, "Y")
        p.sphere(c + Vector((-0.032 * s, -0.05, 0.012)), (0.021, 0.021, 0.042), 7, 4, color=color,
                 deform=lambda v: rot @ v)


def build_arms(parts):
    for side in ("L", "R"):
        # cream shirt sleeve, puffy, rolled cuff above the elbow, bare forearm (jobs_a)
        p = Part("arm_" + side, w_arm(side))
        prof = [(0.0, 0.07), (0.06, 0.092), (0.25, 0.098), (0.48, 0.09), (0.55, 0.086)]
        cuff = [(0.55, 0.086), (0.57, 0.101), (0.61, 0.106), (0.655, 0.102), (0.685, 0.09), (0.7, 0.063)]   # thick rolled cuff
        fore = [(0.7, 0.063), (0.85, 0.055), (1.0, 0.048)]
        for pr, c, det in ((catmull(prof, Q(5, 2)), "LOOK_SHIRT", (C_LINEN, 1.5, 1.6)),
                           (cuff if LOD == 0 else [cuff[0], cuff[2], cuff[-1]], shade("LOOK_SHIRT", 0.95), (C_CUFF, 1.5, 1.0)),
                           (catmull(fore, Q(3, 2)), SKIN, None)):
            p.grid(arm_rows(pr, side, Q(9, 4)), color=c, cap0=True if pr is not fore and pr[0][0] == 0.0 else None, det=det)
        hand(p, side)
        p.shade = lambda co, n: 1.0 - 0.1 * sm(-0.3, -0.9, n.z)
        parts.append(p)
        # robe: wide bell sleeve to the wrist
        p = Part("arm_robe_" + side, w_arm(side))
        prof = [(0.0, 0.08), (0.08, 0.1), (0.5, 0.11), (0.9, 0.15), (1.0, 0.15), (1.0, 0.07)]
        p.grid(arm_rows(catmull(prof[:-1], Q(7, 3)) + [prof[-1]], side, Q(10, 5)), color=CLOTH_D, cap0=True, det=(C_FOLDS, 1.5, 1.2))
        hand(p, side)
        parts.append(p)


def build_legs(parts):
    for side in ("L", "R"):
        s = 1 if side == "L" else -1
        for name, color, r0, cuffc in (("leg_trousers", "LOOK_TROUSER", 0.1, "LOOK_TROUSER"),
                                       ("leg_stocking", "LOOK_STOCKING", 0.085, "LOOK_STOCKING")):
            p = Part(name + "_" + side, w_leg(side))
            prof = [(r0 * 0.9, 0.1), (r0 * 0.95, KNEE - 0.05), (r0 * 1.02, KNEE + 0.05), (r0 * 1.1, HIP - 0.02), (r0 * 0.6, HIP + 0.08)]
            rows = lathe_rows(catmull(prof, Q(5, 3)), Q(8, 5), sy=1.0)
            rows = [[v + Vector((s * LEG_X, 0, 0)) for v in r] for r in rows]
            p.grid(rows, color=color, cap1=True, det=(C_LINEN if name == "leg_trousers" else C_KNIT, 1.0, 1.3))
            # boot: rounded, toe forward (-Y), cuff
            c = Vector((s * LEG_X, -0.04, 0.055))
            p.sphere(c, (0.085, 0.13, 0.065), Q(10, 6), Q(6, 3), color="LOOK_BOOT",
                     deform=lambda v: Vector((v.x, v.y, max(v.z, -0.05))))
            if LOD == 0:
                p.grid([[v + Vector((s * LEG_X, 0, 0)) for v in r]
                        for r in lathe_rows([(0.083, 0.06), (0.09, 0.15), (0.085, 0.17)], Q(8, 5), sy=1.0)],
                       color="LOOK_BOOT", cap1=True)
            p.shade = lambda co, n: 1.0
            parts.append(p)


# ───────── hair: a shell from the crown to a hairline that can fall on as a curtain ─────────
def hair_surface(p, edge, drop=None, vol=None, bumps=None, seg=(30, 8), rows=(10, 4), color=HAIR, r0=1.06,
                 tuck=0.09, inner=False, locks=12.0, cell=H_STRAIGHT, tiles=6.0, vs=0.24, wave=0.0):
    """edge(theta) = polar angle (from the top) of the hairline, theta 0 = front, + = toward the character's left.
    drop(theta) = extra length falling straight down from the hairline (long hair). vol(theta, phi) = radius multiplier.
    bumps(Vector) = outward bump (curls)."""
    ns = Q(*seg)
    nr = Q(*rows)
    R = HEAD_R
    ctr = Vector((0, 0.015, HEAD_C))
    rings = []
    for j in range(1, nr + 1):
        t = j / nr
        ring = []
        for i in range(ns):
            th = i / ns * 2 * math.pi
            pe = edge(th)
            L = drop(th) if drop else 0.0
            tot = R * pe + L
            d = t * tot
            v = vol(th, min(d / R, pe)) if vol else 1.0
            rr = R * r0 * v
            if d <= R * pe:
                ph = d / R
                if L <= 0.0:                     # tuck the edge in toward the head (soft thick edge)
                    rr -= R * max(0.0, r0 * v - 0.985) * sm(0.8, 1.0, t) * (tuck / 0.09)
                dirv = Vector((-math.sin(th) * math.sin(ph), -math.cos(th) * math.sin(ph), math.cos(ph)))
                pt = ctr + Vector((dirv.x * rr * HEAD_S[0], dirv.y * rr * HEAD_S[1], dirv.z * rr * HEAD_S[2]))
            else:
                ph = pe
                dirv = Vector((-math.sin(th) * math.sin(ph), -math.cos(th) * math.sin(ph), math.cos(ph)))
                base = ctr + Vector((dirv.x * rr * HEAD_S[0], dirv.y * rr * HEAD_S[1], dirv.z * rr * HEAD_S[2]))
                k = (d - R * pe) / max(L, 1e-4)
                out = Vector((dirv.x, dirv.y, 0))
                flare = 0.06 * math.sin(k * math.pi) - 0.05 * k * k + wave * math.sin(k * math.pi * 2.5 + th * 3.0) * k
                pt = base + Vector((0, 0, -(d - R * pe))) + out * flare
            if bumps:
                nrm = (pt - ctr).normalized()
                pt = pt + nrm * bumps(pt)
            ring.append(pt)
        rings.append(ring)
    top = ctr + Vector((0, 0, R * r0 * HEAD_S[2] * (vol(0, 0) if vol else 1.0)))
    if bumps:
        top = top + Vector((0, 0, bumps(top)))
    bm = p.bm

    def face(vs, inward=False):
        f = bm.faces.new(vs)
        f.normal_update()
        c = f.calc_center_median()
        want = c - ctr
        if inward:
            want = -Vector((c.x, c.y - 0.01, 0))
        if f.normal.dot(want) < 0:
            f.normal_flip()
        faces.append(f)
    pole = bm.verts.new(top)
    vr = [[bm.verts.new(q) for q in r] for r in rings]
    faces = []
    for i in range(ns):
        face((pole, vr[0][(i + 1) % ns], vr[0][i]))
    for a, b in zip(vr[:-1], vr[1:]):
        for i in range(ns):
            j = (i + 1) % ns
            face((a[i], a[j], b[j], b[i]))
    if inner:
        # inside of the hanging part, so looking past the cheek / from below shows hair, not a hole
        start = max(1, int(nr * 0.45)) if LOD == 0 else nr - 1
        iv = []
        for r in rings[start:]:
            iv.append([bm.verts.new(Vector((q.x * 0.9, q.y * 0.9 + 0.01, q.z))) for q in r])
        for a, b in zip(iv[:-1], iv[1:]):
            for i in range(ns):
                j = (i + 1) % ns
                face((a[i], a[j], b[j], b[i]), inward=True)
        a, b = vr[-1], iv[-1]
        for i in range(ns):
            j = (i + 1) % ns
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.normal_update()
            if f.normal.z > 0:
                f.normal_flip()
            faces.append(f)
    bm.normal_update()
    p.paint(faces, None, color)
    if cell is not None:
        p.detail(faces, cell, m_crown(ctr, Q(tiles, max(2.0, tiles / 2)), vs))

    def sh(co, n):
        d = co - ctr
        th = math.atan2(-d.x, -d.y)
        k = 1.0 - 0.05 * (0.5 + 0.5 * math.sin(th * locks + d.z * 6.0))      # painted locks (the atlas carries the strands)
        k *= 1.0 - 0.18 * sm(HEAD_C + 0.05, HEAD_C - 0.45, co.z)             # darker toward the ends / under
        k *= 1.0 + 0.08 * sm(0.4, 0.95, n.z)                                 # sheen on top
        return k
    p.shade = sh
    return faces


FRONT = 0.0


def ang_d(th, c):
    """Smallest angle between th and c."""
    return abs((th - c + math.pi) % (2 * math.pi) - math.pi)


def fringe(base, side, back, scallop=0.12, n=5, part=0.0):
    """Hairline polar angle: base at the forehead, side at the ears, back at the nape; scalloped fringe locks."""
    def fn(th):
        f = ang_d(th, FRONT) / math.pi                 # 0 front .. 1 back
        e = base + (side - base) * sm(0.06, 0.3, f) + (back - side) * sm(0.5, 0.9, f)
        if f < 0.18:
            e += scallop * (abs(math.sin((th + part) * n)) - 0.5) * (1 - f / 0.18)
        return e
    return fn


def curls(seed, n, amp, sigma, zmin=None, gap=0.0):
    pts = []
    rnd = __import__("random").Random(seed)
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - (i + 0.5) / n * 1.6
        r = math.sqrt(max(0.0, 1 - z * z))
        th = golden * i + rnd.random() * 0.3
        pts.append(Vector((HEAD_R * 1.12 * r * math.cos(th), HEAD_R * 1.12 * r * math.sin(th), HEAD_C + HEAD_R * 1.12 * z)))

    def fn(p):
        b = 0.0
        for c in pts:
            d2 = (p - c).length_squared
            b = max(b, math.exp(-d2 / (sigma * sigma)))
        return amp * (b - gap)                      # gap > 0: dips between the curls
    return fn


def bez(ctrl, n):
    """Cubic Bezier through 4 control points -> n points."""
    out = []
    for i in range(n):
        t = i / (n - 1)
        a = [(1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3]
        out.append(tuple(sum(a[k] * ctrl[k][d] for k in range(4)) for d in range(3)))
    return out


def w_braid(co):
    """Braids: head at the top, then the chest carries them (so they lie on the chest when the head tilts)."""
    t = sm(HEAD_C - 0.3, HEAD_C - 0.5, co.z)
    return W(skull=1 - t + 1e-3, chest=t)


def build_hair(parts):
    def H(name, **kw):
        p = Part(name, kw.pop("weights", w_fixed("skull")), head=False)
        extra = kw.pop("extra", None)
        hair_surface(p, **kw)
        if extra:
            extra(p)
        parts.append(p)

    side_vol = lambda th, ph: 1.0 + 0.04 * sm(0.6, 1.6, ph)
    H("hair_short", edge=fringe(0.64, 1.72, 2.15, scallop=0.16, n=4, part=0.3), vol=side_vol)
    H("hair_long", edge=fringe(0.7, 1.65, 2.05, scallop=0.12, n=4), inner=True,
      drop=lambda th: 0.4 * sm(0.25, 0.6, ang_d(th, FRONT) / math.pi), vol=side_vol, rows=(9, 4))

    def braids(p):
        # two plaits hanging over the shoulders to the chest (variety_c): a lumpy tapered tube, braid weave painted
        for sx in (-1, 1):
            ctrl = [(sx * 0.2, 0.05, HEAD_C - 0.12), (sx * 0.245, -0.1, HEAD_C - 0.36), (sx * 0.235, -0.235, 0.93),
                    (sx * 0.215, -0.265, 0.76)]
            path = [Vector(q) for q in bez(ctrl, Q(11, 3))]
            rows = []
            for k, c in enumerate(path):
                t = k / (len(path) - 1)
                tan = (path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]).normalized()
                back = Vector((0, 1, 0))
                n1 = tan.cross(back).normalized()
                n2 = n1.cross(tan).normalized()
                if n2.y < 0:
                    n2 = -n2
                r = 0.056 * (1 - 0.35 * t) * (1 + Q(0.13, 0.0) * abs(math.sin(t * math.pi * 6.5)))
                ns = Q(8, 3)
                rows.append([c + (n1 * math.sin(a) + n2 * math.cos(a)) * r * (1.0 if abs(n1.x) > 0.5 else 1.0)
                             for a in [i / ns * 2 * math.pi for i in range(ns)]])
            p.grid(rows, color=HAIR, cap1=True, det=(H_BRAID, 1.0, 4.5))
            end = path[-1]
            if LOD == 0:
                p.sphere(end + Vector((0, 0, -0.005)), (0.034, 0.034, 0.026), 6, 3, color="LOOK_SCARF_B")
            if LOD == 0:
                tf = p.sphere(end + Vector((0, 0, -0.07)), (0.04, 0.035, 0.06), 7, 4, color=HAIR,
                              deform=lambda v: Vector((v.x * (1 + max(0.0, -v.z) * 4), v.y, v.z)))
                p.detail(tf, H_STRAIGHT, m_cyl(cx=end.x, cy=end.y, tiles=2.0, vs=0.15, z0=end.z))
    H("hair_braids", edge=fringe(0.68, 1.75, 2.15, scallop=0.05, n=2), vol=side_vol, extra=braids, rows=(9, 4), seg=(30, 7),
      weights=w_braid)

    def bun(p):
        c = Vector((0, 0.07, HEAD_C + 0.33))
        fs = p.sphere(c, (0.13, 0.12, 0.115), Q(14, 6), Q(7, 3), color=HAIR)
        nrm = Vector((0, 0.45, 0.89)).normalized()
        right = Vector((1, 0, 0))
        down = nrm.cross(right).normalized()
        if down.z > 0:
            down = -down
        p.detail(fs, H_BUN, m_plane(c - right * 0.14 - down * 0.14, right, down, 0.28, 0.28))
    H("hair_bun", edge=fringe(0.62, 1.75, 2.15, scallop=0.04, n=2), vol=side_vol, extra=bun, locks=16.0)

    def under(fn):                    # curls only below a cap / scarf
        return lambda q: fn(q) * sm(HEAD_C - 0.02, HEAD_C - 0.14, q.z)
    # curly: separate curl clusters with gaps between them (base_c / variety_c), not a smooth helmet
    cu = curls(7, Q(30, 14), Q(0.065, 0.05), Q(0.075, 0.08), gap=Q(0.12, 0.05))
    H("hair_curly", edge=fringe(0.66, 1.9, 2.25, scallop=0.12, n=7), vol=lambda th, ph: 1.05, bumps=cu,
      seg=(32, 8), rows=(11, 4), locks=0, cell=H_CURLS, tiles=8.0, vs=0.13)
    H("hair_curly_under", edge=fringe(1.05, 1.9, 2.25, scallop=0.03, n=7), vol=lambda th, ph: 0.99, bumps=under(cu),
      seg=(32, 8), rows=(9, 4), locks=0, cell=H_CURLS, tiles=8.0, vs=0.13)
    cl = curls(11, Q(34, 16), Q(0.065, 0.05), Q(0.08, 0.08), gap=Q(0.12, 0.05))
    long_drop = lambda th: 0.36 * sm(0.22, 0.55, ang_d(th, FRONT) / math.pi)
    H("hair_curly_long", edge=fringe(0.75, 1.62, 2.0, scallop=0.12, n=7), drop=long_drop,
      vol=lambda th, ph: 1.06 + 0.06 * sm(0.8, 1.6, ph), bumps=cl, seg=(28, 8), rows=(10, 3), inner=True, locks=0,
      cell=H_CURLS, tiles=8.0, vs=0.13)
    H("hair_curly_long_under", edge=fringe(1.1, 1.62, 2.0, scallop=0.03, n=7), drop=long_drop,
      vol=lambda th, ph: 1.0 + 0.06 * sm(0.8, 1.6, ph), bumps=under(cl), seg=(28, 8), rows=(10, 3), inner=True, locks=0,
      cell=H_CURLS, tiles=8.0, vs=0.13)
    wv = lambda p: 0.012 * math.sin(p.z * 18.0 + math.atan2(p.x, p.y) * 2)
    H("hair_wave", edge=fringe(0.64, 1.75, 2.2, scallop=0.18, n=3, part=0.5), vol=lambda th, ph: 1.04, bumps=wv, cell=H_WAVY)
    H("hair_wave_long", edge=fringe(0.7, 1.62, 2.0, scallop=0.14, n=3, part=0.5),
      drop=lambda th: 0.46 * sm(0.22, 0.55, ang_d(th, FRONT) / math.pi), vol=lambda th, ph: 1.05 + 0.06 * sm(0.8, 1.6, ph),
      bumps=wv, rows=(11, 4), inner=True, cell=H_WAVY, wave=0.035)

    # beard: a full soft beard around the jaw with a tufted lower edge + moustache, beard hair painted (jobs_a woodcutter)
    p = Part("beard", w_fixed("skull"))
    ns, nr = Q(16, 6), Q(7, 2)
    rows = []
    for j in range(nr + 1):
        t = j / nr
        ring = []
        for i in range(ns + 1):
            u = i / ns
            th = (u - 0.5) * math.pi * 1.0
            side = abs(u - 0.5) * 2
            ph0 = math.radians(116 - 26 * side ** 1.4)              # sideburns climb to the ears
            ph = ph0 + (math.radians(172) - ph0) * t
            bulge = (0.27 - 0.13 * side) * math.sin(min(1.0, t * 1.25) * math.pi * 0.5) * (1 - 0.45 * t * t)
            tuft = Q(0.05, 0.0) * abs(math.sin(u * math.pi * 6)) * sm(0.5, 1.0, t) * (1 - side)
            r = HEAD_R * (1.0 + bulge + tuft)
            dirv = Vector((-math.sin(th) * math.sin(ph), -math.cos(th) * math.sin(ph), math.cos(ph)))
            q = Vector((0, 0.0, HEAD_C)) + Vector((dirv.x * r * HEAD_S[0], dirv.y * r, dirv.z * r))
            q.z -= 0.05 * t * t * (1 - side) ** 2                     # a slightly pointed chin
            ring.append(q)
        rows.append(ring)
    beard_map = m_cyl(cy=0.0, tiles=Q(5.0, 3.0), vs=0.12, z0=HEAD_C)
    p.detail(p.grid(rows, closed=False, color=HAIR, cap0=None), H_BEARD, beard_map)
    if LOD == 0:
        p.detail(p.grid(rows, closed=False, color=HAIR_D, flip=True), H_BEARD, beard_map)
    # moustache: two soft drooping lobes
    for sx in ((-1, 1) if LOD == 0 else ()):
        fs = p.sphere(Vector((sx * 0.05, -HEAD_R * 0.99, HEAD_C - 0.04)), (0.058, 0.03, 0.026), 8, 4, color=HAIR,
                      deform=lambda v, sx=sx: Vector((v.x, v.y, v.z - (v.x * sx) * 0.35 - 0.6 * (v.x * sx) ** 2 / 0.058)))
        p.detail(fs, H_BEARD, beard_map)
    p.shade = lambda co, n: 1.0 - 0.12 * sm(HEAD_C - 0.1, HEAD_C - 0.4, co.z) * 0.5
    parts.append(p)


def build_hats(parts):
    def P(name):
        p = Part(name, w_fixed("skull"))
        parts.append(p)
        return p
    top = HEAD_C + HEAD_R * HEAD_S[2]
    # farmer straw hat: wide soft brim + round crown with a band
    p = P("hat_straw")
    seg = Q(22, 8)
    rows = lathe_rows([(0.6, HEAD_C + 0.06), (0.5, HEAD_C + 0.14), (0.3, HEAD_C + 0.19)], seg, sy=1.0, y0=0.02)
    brim = m_radial(cy=0.02, tiles=Q(9.0, 5.0), vs=0.085)
    p.detail(p.grid(rows, color="LOOK_STRAW"), C_STRAW, brim)
    if LOD == 0:
        p.detail(p.grid(lathe_rows([(0.6, HEAD_C + 0.05), (0.5, HEAD_C + 0.125), (0.3, HEAD_C + 0.17)], seg, sy=1.0, y0=0.02),
                        color="LOOK_STRAW_DARK", flip=True), C_STRAW, brim)
    fs = p.grid(lathe_rows(catmull([(0.3, HEAD_C + 0.17), (0.3, HEAD_C + 0.24), (0.27, HEAD_C + 0.36), (0.12, HEAD_C + 0.44)], Q(6, 3)),
                           Q(16, 7), sy=1.0, y0=0.02), cap1=True,
                colfn=lambda f: "LOOK_STRAW_DARK" if f.calc_center_median().z < HEAD_C + 0.24 else "LOOK_STRAW")
    p.detail(fs, C_STRAW, m_crown(Vector((0, 0.02, HEAD_C + 0.17)), Q(6.0, 3.0), 0.085, R=0.3))
    p.shade = lambda co, n: 1.0
    # headscarf (expressions_a): covers the crown, knot + two tails at the nape
    p = Part("hat_scarf", w_fixed("skull"))
    hair_surface(p, edge=fringe(0.52, 1.72, 2.0, scallop=0.0), vol=lambda th, ph: 1.15, r0=1.04, color=ACCENT, locks=0, seg=(24, 7),
                 rows=(8, 4), tuck=0.0, cell=C_LINEN, tiles=4.0, vs=0.3)
    # knot at the nape + two flared tails (base_c back view)
    lin = m_plane((-0.2, 0.4, HEAD_C), (1, 0, 0), (0, 0, -1), 0.2, 0.2)
    p.detail(p.sphere(Vector((0, 0.36, HEAD_C - 0.11)), (0.08, 0.065, 0.065), Q(10, 5), Q(5, 3), color=ACCENT_D), C_FOLDS, lin)
    for sx in (-1, 1):
        fs = p.sphere(Vector((sx * 0.075, 0.37, HEAD_C - 0.25)), (0.06, 0.022, 0.12), Q(8, 4), Q(4, 2), color=ACCENT,
                      deform=lambda v, sx=sx: Vector((v.x * (1 + 0.8 * max(0.0, -v.z) / 0.12) + sx * 0.35 * (-v.z), v.y, v.z)))
        p.detail(fs, C_FOLDS, lin)
    p.shade = lambda co, n: 1.0 - 0.12 * sm(0.3, -0.6, n.z) - 0.05 * (0.5 + 0.5 * math.sin(co.x * 40 + co.z * 20))
    parts.append(p)
    # flat cap (woodcutter): soft dome + peak
    p = P("hat_cap")
    fs = p.sphere(Vector((0, 0.02, HEAD_C + 0.17)), (HEAD_R * 1.18, HEAD_R * 1.2, HEAD_R * 0.62), Q(16, 7), Q(8, 4), color=ACCENT,
                  deform=lambda v: Vector((v.x, v.y, max(v.z, -0.02))))
    p.detail(fs, C_WOOL, m_crown(Vector((0, 0.02, HEAD_C + 0.1)), Q(5.0, 3.0), 0.15))
    fs = p.sphere(Vector((0, -0.33, HEAD_C + 0.14)), (0.19, 0.11, 0.025), Q(12, 6), Q(5, 3), color=ACCENT_D)
    p.detail(fs, C_WOOL, m_plane((-0.2, -0.4, HEAD_C), (1, 0, 0), (0, 1, 0), 0.2, 0.2))
    p.shade = lambda co, n: 1.0 - 0.15 * sm(0.0, -0.8, n.z)
    # baker cap: band + puffy top
    p = P("hat_baker")
    p.grid(lathe_rows([(0.34, HEAD_C + 0.14), (0.35, HEAD_C + 0.24)], Q(18, 8), sy=1.0, y0=0.01), color=shade("LOOK_BAKER", 0.92),
           det=(C_LINEN, 5.0, 0.4))
    fs = p.sphere(Vector((0, 0.02, HEAD_C + 0.33)), (0.38, 0.37, 0.18), Q(14, 7), Q(7, 4), color="LOOK_BAKER",
                  deform=lambda v: v * (1.0 + 0.06 * math.sin(math.atan2(v.y, v.x) * 5)))
    p.detail(fs, C_FOLDS, m_crown(Vector((0, 0.02, HEAD_C + 0.3)), 5.0, 0.3))
    p.shade = lambda co, n: 1.0
    # fisher knit cap with a rolled band
    p = P("hat_fisher")
    fs = p.sphere(Vector((0, 0.02, HEAD_C + 0.1)), (HEAD_R * 1.14, HEAD_R * 1.14, HEAD_R * 1.05), Q(14, 7), Q(8, 4), color=ACCENT,
                  deform=lambda v: Vector((v.x, v.y, max(v.z, 0.0))))
    p.detail(fs, C_KNIT, m_crown(Vector((0, 0.02, HEAD_C + 0.1)), Q(8.0, 4.0), 0.16))
    p.grid(lathe_rows(catmull([(0.375, HEAD_C + 0.06), (0.4, HEAD_C + 0.1), (0.385, HEAD_C + 0.16)], Q(4, 2)), Q(18, 8),
                      sy=1.0, y0=0.02), color=ACCENT_D, det=(C_KNIT, 9.0, 0.6))
    p.shade = lambda co, n: 1.0 - 0.06 * (0.5 + 0.5 * math.sin(math.atan2(co.y, co.x) * 14))


def build_overlays(parts):
    # big work apron with a bib (baker / miller / healer)
    p = Part("apron_job", w_torso(0.4))
    nu, nv = Q(8, 3), Q(9, 3)
    rows = []
    for j in range(nv + 1):
        t = j / nv
        z = SHOULDER - 0.1 - t * (SHOULDER - 0.1 - (HIP - 0.24))
        r = (0.262 if z > WAIST else 0.262 + 0.08 * sm(WAIST, HIP - 0.2, z)) + 0.012
        w = 0.6 if z > WAIST + 0.04 else 1.25
        ring = []
        for i in range(nu + 1):
            u = i / nu
            a = -math.pi / 2 + (u - 0.5) * w
            ring.append(Vector((math.cos(a) * r, math.sin(a) * r * 0.82, z)))
        rows.append(ring)
    p.grid(rows, closed=False, color="LOOK_APRON", det=(C_APRON, 1.4, 1.0))
    p.grid(rows, closed=False, color="LOOK_APRON", flip=True)
    p.shade = lambda co, n: 1.0
    parts.append(p)
    # chief: red waist sash, knot + tails
    p = Part("sash", w_torso(0.3))
    sm_ = m_cyl(tiles=5.0, vs=0.2, z0=WAIST + 0.05)
    p.detail(p.grid(lathe_rows([(0.298, WAIST - 0.05), (0.304, WAIST), (0.298, WAIST + 0.05)], Q(18, 8), sy=0.82), color="LOOK_SASH"),
             C_FOLDS, sm_)
    p.detail(p.sphere(Vector((0.2, -0.14, WAIST)), (0.05, 0.04, 0.045), Q(8, 4), Q(4, 2), color="LOOK_SASH"), C_FOLDS, sm_)
    p.detail(p.sphere(Vector((0.22, -0.15, WAIST - 0.15)), (0.035, 0.02, 0.12), Q(8, 4), Q(4, 2), color="LOOK_SASH"), C_FOLDS, sm_)
    parts.append(p)
    # herbalist bag
    p = Part("herb_bag", w_torso(0.2))
    p.grid([[Vector((math.cos(a) * 0.272, math.sin(a) * 0.272 * 0.82, SHOULDER - 0.05 - (math.cos(a) + 1) * 0.28))
             for a in [i / Q(16, 8) * 2 * math.pi for i in range(Q(16, 8))]],
            [Vector((math.cos(a) * 0.272, math.sin(a) * 0.272 * 0.82, SHOULDER - 0.0 - (math.cos(a) + 1) * 0.28))
             for a in [i / Q(16, 8) * 2 * math.pi for i in range(Q(16, 8))]]], color="LOOK_BELT", det=(C_LEATHER, 8.0, 1.0))
    p.detail(p.sphere(Vector((-0.27, -0.06, HIP - 0.05)), (0.08, 0.1, 0.1), Q(10, 5), Q(5, 3), color=shade("LOOK_TROUSER", 1.25)),
             C_LINEN, m_cyl(cx=-0.27, cy=-0.06, tiles=2.0, vs=0.2, z0=HIP + 0.05))
    for k in range(2):
        p.sphere(Vector((-0.3 + k * 0.06, -0.08, HIP + 0.07)), (0.03, 0.02, 0.07), Q(6, 3), Q(3, 2), color="LOOK_HERB")
    parts.append(p)
    # tunic hood folded down around the neck and on the upper back (base_c man) - a cowl ring, thick at the back
    p = Part("hood", w_torso(0.0))
    nu, nv = Q(20, 8), Q(5, 2)
    rows = []
    for j in range(nv + 1):
        t = j / nv
        ring = []
        for i in range(nu):
            a = -math.pi / 2 + i / nu * 2 * math.pi
            back = 0.5 + 0.5 * math.sin(a)                   # 0 front .. 1 back
            z = NECK + 0.0 - t * (0.1 + 0.08 * back + 0.3 * back ** 6) + 0.03 * math.sin(t * math.pi) * back   # pointed tip at the back
            r = 0.135 + 0.11 * math.sin(min(1.0, t * 1.4) * math.pi / 2) + 0.05 * back * math.sin(t * math.pi)
            r *= 1.0 + 0.04 * math.sin(a * 5) * t                # soft folds
            ring.append(Vector((math.cos(a) * r * 1.08, math.sin(a) * r * 0.9 + 0.01 + 0.04 * back * t, z)))
        rows.append(ring)
    hood_map = m_cyl(tiles=Q(3.0, 2.0), vs=0.22, z0=NECK + 0.02)
    p.detail(p.grid(rows, color=CLOTH_D), C_HOOD, hood_map)
    if LOD == 0:
        p.detail(p.grid(rows[1:], color=(0, 0, 0.7), flip=True), C_HOOD, hood_map)
    p.shade = lambda co, n: 1.0 - 0.12 * sm(0.2, -0.6, n.z)
    parts.append(p)
    # elder shawl: soft cape over the shoulders, point at the back (base_c elder)
    p = Part("shawl", w_torso(0.0))
    nu, nv = Q(18, 8), Q(5, 2)
    rows = []
    for j in range(nv + 1):
        t = j / nv
        ring = []
        for i in range(nu):
            a = -math.pi / 2 + i / nu * 2 * math.pi
            back = 0.5 + 0.5 * math.sin(a)                   # 0 front .. 1 back
            z = NECK - 0.01 - t * (0.24 + 0.36 * back ** 2 + 0.08 * (1 - back))
            r = 0.13 + 0.22 * math.sin(min(1.0, t * 1.6) * math.pi / 2) + 0.03 * math.sin(t * math.pi)
            ring.append(Vector((math.cos(a) * r * 1.05, math.sin(a) * r * 0.9, z)))
        rows.append(ring)
    wool = m_cyl(tiles=Q(5.0, 3.0), vs=0.35, z0=NECK)
    p.detail(p.grid(rows, color=SHAWL), C_WOOL, wool)
    if LOD == 0:
        p.detail(p.grid(rows[1:], color=SHAWL_D, flip=True), C_WOOL, wool)
        p.detail(p.sphere(Vector((0, -0.26, SHOULDER - 0.1)), (0.05, 0.035, 0.04), Q(8, 4), Q(4, 2), color=SHAWL_D), C_WOOL, wool)
    p.shade = lambda co, n: 1.0 - 0.1 * (0.5 + 0.5 * math.sin(math.atan2(co.y, co.x) * 9)) * sm(SHOULDER, SHOULDER - 0.3, co.z)
    parts.append(p)
    # swaddled baby in a basket (base_c)
    p = Part("baby_basket", w_fixed("hips"), head=False)
    rows = lathe_rows(catmull([(0.24, 0.0), (0.3, 0.08), (0.34, 0.17), (0.35, 0.2)], Q(5, 3)), Q(20, 8), sy=0.72)
    p.detail(p.grid(rows, cap0=True, colfn=lambda f: "LOOK_STRAW" if (int(f.calc_center_median().z * 40) % 2) else "LOOK_STRAW_DARK"),
             C_STRAW, m_cyl(tiles=Q(6.0, 3.0), vs=0.09, z0=0.2))
    inner = [[Vector((v.x * 0.92, v.y * 0.92, v.z + 0.02)) for v in r] for r in rows]
    p.grid(inner, cap0=True, color=shade("LOOK_STRAW_DARK", 0.8), flip=True)      # inside wall + floor seen from above
    p.grid([rows[-1], inner[-1]], color="LOOK_STRAW", out=lambda c: Vector((0, 0, 1)))
    bs = 0.12 / HEAD_R                                       # the baby's face: the atlas (sleep cell), projected on its head
    p.uvfn = lambda co: (((co.x / bs) + FACE_W / 2) / FACE_W, (FACE_TOP - HEAD_C - (co.z - 0.24) / bs) / FACE_H) \
        if co.y < -0.2 and abs(co.z - 0.24) < 0.12 and abs(co.x) < 0.12 else (-1.0, -1.0)
    p.sphere(Vector((0, 0.05, 0.2)), (0.2, 0.25, 0.1), Q(14, 6), Q(7, 3), color="LOOK_APRON")
    p.sphere(Vector((0, -0.15, 0.24)), (0.12, 0.12, 0.115), Q(14, 6), Q(9, 4), color=SKIN)
    p.sphere(Vector((0, -0.12, 0.33)), (0.08, 0.07, 0.04), Q(8, 4), Q(4, 2), color=HAIR)
    p.sphere(Vector((0, -0.08, 0.24)), (0.14, 0.13, 0.14), Q(12, 6), Q(6, 3), color="LOOK_APRON",
             deform=lambda v: Vector((v.x, v.y, v.z)) if v.y > -0.04 else Vector((v.x, -0.04 + (v.y + 0.04) * 0.2, v.z)))
    p.shade = lambda co, n: 1.0
    parts.append(p)


# ───────── armature ─────────
BONES = [
    # name, head, tail, parent
    ("hips", (0, 0, HIP), (0, 0, WAIST + 0.05), None),
    ("skirt", (0, 0, WAIST), (0, 0, HIP - 0.15), "hips"),        # volume leaf (body shape scale)
    ("spine", (0, 0, WAIST + 0.05), (0, 0, SHOULDER - 0.1), "hips"),
    ("chest", (0, 0, SHOULDER - 0.25), (0, 0, SHOULDER), "spine"),   # volume leaf
    ("skull", (0, 0, NECK - 0.03), (0, 0, HEAD_C + 0.2), "spine"),
    ("upper_arm.L", tuple(ARM_TOP), tuple(ELBOW), "spine"),
    ("forearm.L", tuple(ELBOW), tuple(WRIST), "upper_arm.L"),
    ("hand.L", tuple(WRIST), tuple(HAND + Vector((0, 0, -0.06))), "forearm.L"),
    ("thigh.L", (LEG_X, 0, HIP), (LEG_X, 0, KNEE), "hips"),
    ("shin.L", (LEG_X, 0, KNEE), (LEG_X, 0, ANKLE), "thigh.L"),
    ("foot.L", (LEG_X, 0, ANKLE), (LEG_X, -0.12, 0.03), "shin.L"),
]


def mirror_bones():
    out = list(BONES)
    for n, h, t, par in BONES:
        if n.endswith(".L"):
            out.append((n[:-2] + ".R", (-h[0], h[1], h[2]), (-t[0], t[1], t[2]), par[:-2] + ".R" if par.endswith(".L") else par))
    return out


def make_armature():
    arm = bpy.data.armatures.new("rig")
    ob = bpy.data.objects.new("rig", arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for n, h, t, par in mirror_bones():
        b = arm.edit_bones.new(n)
        b.head, b.tail = Vector(h), Vector(t)
        b.roll = 0.0
        if par:
            b.parent = eb[par]
        eb[n] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def to_object(part, rig, name):
    bm = part.finish()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    me.color_attributes.active_color_name = "Color"
    me.color_attributes.render_color_index = 0
    tris = len(me.polygons)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    # weights
    groups = {}
    for v in bm.verts:
        ws = sorted(part.weights(v.co).items(), key=lambda kv: -kv[1])[:4]
        s = sum(w for _, w in ws) or 1.0
        for bn, w in ws:
            if bn not in groups:
                groups[bn] = ob.vertex_groups.new(name=bn)
            groups[bn].add([v.index], w / s, "REPLACE")
    bm.free()
    ob.parent = rig
    mod = ob.modifiers.new("rig", "ARMATURE")
    mod.object = rig
    return ob, tris


# ───────── animations (rotations in the armature's rest frame, radians; X- = forward swing) ─────────
FPS = 30


def bone_rest(rig, name):
    return rig.data.bones[name].matrix_local.to_3x3()


def key(rig, act_frames, frame, pose, loc=None):
    """pose = {bone: (rx, ry, rz)} as armature-space XYZ euler around the bone's rest frame."""
    for pb in rig.pose.bones:
        e = pose.get(pb.name, (0, 0, 0))
        B = bone_rest(rig, pb.name)
        Rw = Euler(e, "YXZ").to_matrix()     # (pitch X, roll Y = front axis, yaw Z): roll first, then pitch, then yaw
        Rl = B.inverted() @ Rw @ B
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Rl.to_quaternion()
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        if pb.name == "hips":
            l = loc or (0, 0, 0)
            # location is in the bone's local rest frame: convert armature-space offset
            pb.location = B.inverted() @ Vector(l)
            pb.keyframe_insert("location", frame=frame)


def anim(rig, name, frames, fn, cyclic=True):
    """fn(t in [0,1)) -> (pose dict, hips location offset). Sampled every few frames."""
    act = bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = act
    step = 2 if frames > 8 else 1
    fs = list(range(0, frames + 1, step))
    if fs[-1] != frames:
        fs.append(frames)
    for f in fs:
        t = (f / frames) % 1.0 if cyclic else f / frames
        pose, loc = fn(t)
        key(rig, act, f + 1, pose, loc)
    act.use_fake_user = True
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, act)
    strip.name = name
    rig.animation_data.action = None
    return act


def S(t, k=1.0, ph=0.0):
    return math.sin((t * k + ph) * 2 * math.pi)


def C(t, k=1.0, ph=0.0):
    return math.cos((t * k + ph) * 2 * math.pi)


def legs_walk(t, a=0.5, knee=0.6):
    sw = S(t)
    p = {}
    for side, sg in (("L", 1), ("R", -1)):
        s = sw * sg
        p["thigh." + side] = (-s * a, 0, 0)
        back = max(0.0, S(t, 1, 0.25 if sg > 0 else 0.75))     # knee bends while the leg swings forward
        p["shin." + side] = (back * knee, 0, 0)
        p["foot." + side] = (-back * 0.3 + max(0, s) * 0.2, 0, 0)
    return p


def build_anims(rig):
    A_OUT = 0.12                     # arms rest slightly away from the body (z rot, + for .L)

    def arms(lx=0.0, rx=0.0, lz=0.0, rz=0.0, lf=0.0, rf=0.0):
        return {"upper_arm.L": (lx, -(A_OUT + lz), 0), "upper_arm.R": (rx, A_OUT + rz, 0),
                "forearm.L": (lf, 0, 0), "forearm.R": (rf, 0, 0)}

    def idle(t):
        p = arms(S(t) * 0.04, -S(t) * 0.04, lf=-0.12, rf=-0.12)
        p["spine"] = (S(t) * 0.025, 0, 0)
        p["skull"] = (-S(t, 1, 0.2) * 0.03, 0, S(t, 0.5) * 0.06)
        return p, (0, 0, S(t) * 0.006)
    anim(rig, "idle", 60, idle)

    def walk(t):
        p = legs_walk(t)
        p.update(arms(S(t) * 0.5, -S(t) * 0.5, lf=-0.25 - max(0, -S(t)) * 0.3, rf=-0.25 - max(0, S(t)) * 0.3))
        p["spine"] = (-0.04, 0, -S(t) * 0.1)
        p["hips"] = (0, S(t) * 0.03, S(t) * 0.08)
        p["skull"] = (0.02, 0, S(t) * 0.04)
        return p, (0, 0, abs(C(t)) * 0.035)
    anim(rig, "walk", 20, walk)

    def walk_elder(t):
        p = legs_walk(t, 0.32, 0.4)
        p.update(arms(-0.55 - S(t) * 0.15, -S(t) * 0.2, lz=0.1, lf=-0.35, rf=-0.3))
        p["spine"] = (0.18, 0, S(t) * 0.04)
        p["skull"] = (-0.12, 0, 0)
        return p, (0, 0, abs(C(t)) * 0.015)
    anim(rig, "walk_elder", 30, walk_elder)

    def run(t):                      # child: bouncy skip
        p = legs_walk(t, 0.75, 1.1)
        p.update(arms(S(t) * 0.8, -S(t) * 0.8, lz=0.2, rz=0.2, lf=-0.9, rf=-0.9))
        p["spine"] = (0.12, 0, -S(t) * 0.12)
        p["skull"] = (-0.1, 0, 0)
        return p, (0, 0, abs(C(t)) * 0.08)
    anim(rig, "run", 16, run)

    def carry(t):
        p = legs_walk(t, 0.42, 0.5)
        p.update(arms(-1.05, -1.05, lz=-0.05, rz=-0.05, lf=-0.5, rf=-0.5))
        p["spine"] = (-0.08, 0, S(t) * 0.04)
        return p, (0, 0, abs(C(t)) * 0.025)
    anim(rig, "carry", 20, carry)

    def hold(t):
        p = arms(-1.05, -1.05, lz=-0.05, rz=-0.05, lf=-0.5, rf=-0.5)
        p["spine"] = (-0.06 + S(t) * 0.02, 0, 0)
        return p, (0, 0, 0)
    anim(rig, "hold", 60, hold)

    def chop(t, high=2.6, low=0.45, bend=0.25, two=True):
        # slow lift, fast strike, small rebound
        sw = sm(0.0, 0.7, t) if t < 0.7 else 1.0 - sm(0.7, 0.84, t)
        r = -low - (high - low) * sw
        p = arms(r * (0.85 if two else 0.2) - (0 if two else 0.2), r, lz=-0.25 if two else 0.0, rz=-0.1, lf=-0.4, rf=-0.35)
        p["spine"] = (bend * (1 - sw) - 0.06 * sw, 0, 0)
        p["skull"] = (0.1 * (1 - sw), 0, 0)
        p["thigh.L"] = (-0.22, -0.06, 0)
        p["thigh.R"] = (0.18, 0.06, 0)
        p["shin.R"] = (0.12, 0, 0)
        return p, (0, 0, -0.02 * (1 - sw))
    anim(rig, "work_axe", 27, lambda t: chop(t))
    anim(rig, "work_hoe", 30, lambda t: chop(t, high=1.6, low=0.7, bend=0.4))
    anim(rig, "work_hammer", 16, lambda t: chop(t, high=1.9, low=0.8, bend=0.15, two=False))

    def hands(t):                    # gathering / kneading: bent over, hands working in front
        p = arms(-0.9 + S(t, 2) * 0.2, -0.9 - S(t, 2) * 0.2, lz=-0.1, rz=-0.1, lf=-0.7, rf=-0.7)
        p["spine"] = (0.4, 0, 0)
        p["skull"] = (0.05, 0, 0)
        p["thigh.L"] = (-0.15, 0, 0)
        p["shin.L"] = (0.25, 0, 0)
        return p, (0, 0.03, -0.03)
    anim(rig, "work_hands", 30, hands)

    def pray(t):                     # kneel, hands together, head bowed (expressions_a)
        p = {"thigh.L": (0.05, 0, 0), "thigh.R": (0.05, 0, 0), "shin.L": (1.55, 0, 0), "shin.R": (1.55, 0, 0),
             "foot.L": (0.6, 0, 0), "foot.R": (0.6, 0, 0)}
        p.update(arms(-0.45, -0.45, lz=-0.45, rz=-0.45, lf=-1.55, rf=-1.55))
        p["spine"] = (0.12, 0, 0)
        p["skull"] = (0.3 + S(t) * 0.05, 0, 0)
        return p, (0, 0.06, -(KNEE - ANKLE) + 0.0)
    anim(rig, "pray", 60, pray)

    def sit(t, eat=False):           # sitting on the ground, legs forward
        p = {"thigh.L": (-1.45, -0.1, 0), "thigh.R": (-1.45, 0.1, 0), "shin.L": (0.25, 0, 0), "shin.R": (0.25, 0, 0)}
        if eat:
            k = 0.5 + 0.5 * S(t, 2)
            p.update(arms(-0.4, -0.5 - 0.5 * k, rz=-0.15, lf=-0.6, rf=-1.2 - 0.6 * k))
            p["skull"] = (0.05 - 0.05 * k, 0, 0)
        else:
            p.update(arms(-0.25, -0.25, lz=0.1, rz=0.1, lf=-0.3, rf=-0.3))
            p["skull"] = (0, 0, S(t, 0.5) * 0.3)
        p["spine"] = (-0.05 + S(t) * 0.02, 0, 0)
        return p, (0, 0.05, -(HIP - 0.13))
    anim(rig, "sit", 60, sit)
    anim(rig, "eat", 40, lambda t: sit(t, True))

    def sleep(t):                    # lying on the back (face up for the top-down camera)
        p = {"hips": (-math.pi / 2, 0, 0)}
        p.update(arms(0, 0, lz=0.1, rz=0.1, lf=-0.2, rf=-0.2))
        p["spine"] = (S(t) * 0.02, 0, 0)
        p["skull"] = (-0.2, 0, 0)
        p["thigh.L"] = (-0.05, 0, 0)
        return p, (0, -0.4, 0.22 - HIP)
    anim(rig, "sleep", 60, sleep)

    def wave(t):
        p = arms(0.02, -2.5, rz=0.45, rf=-0.4 + S(t, 2) * 0.45)
        p["skull"] = (-0.05, 0.06, -0.1)
        p["spine"] = (0, 0, -0.08)
        return p, (0, 0, 0)
    anim(rig, "wave", 30, wave)

    def play(t):                     # child hop, arms up
        hop = abs(S(t, 1))
        p = arms(-0.4 - 2.0 * hop, -0.4 - 2.0 * hop, lz=0.3, rz=0.3, lf=-0.3, rf=-0.3)
        p["thigh.L"] = (-0.5 * (1 - hop), 0, 0)
        p["thigh.R"] = (-0.5 * (1 - hop), 0, 0)
        p["shin.L"] = (0.9 * (1 - hop), 0, 0)
        p["shin.R"] = (0.9 * (1 - hop), 0, 0)
        return p, (0, 0, hop * 0.28 - (1 - hop) * 0.08)
    anim(rig, "play", 24, play)

    def fly(t):                      # hanging from a dandelion seed
        p = arms(-2.95, -2.95, lz=-0.15, rz=-0.15, lf=-0.1, rf=-0.1)
        p["thigh.L"] = (S(t) * 0.35, 0, 0)
        p["thigh.R"] = (-S(t, 1, 0.1) * 0.35, 0, 0)
        p["shin.L"] = (0.3, 0, 0)
        p["shin.R"] = (0.3, 0, 0)
        p["hips"] = (0, S(t, 0.5) * 0.08, 0)
        return p, (0, 0, 0)
    anim(rig, "fly", 60, fly)

    # ── idle variety + social (v5: residents read differently from the top camera, not all the same sway) ──
    def env(t, a=0.15, b=0.4, c=0.62, d=0.88):     # 0 → 1 → 0 hold envelope (one gesture per loop)
        return sm(a, b, t) * (1.0 - sm(c, d, t))

    def look(t):                     # look around: head + chest turn left, then right
        turn = S(t) * 0.6
        p = arms(0.02, -0.02, lf=-0.12, rf=-0.12)
        p["spine"] = (0.0, 0, turn * 0.25)
        p["skull"] = (-0.06, 0, turn)
        return p, (0, 0, 0)
    anim(rig, "look", 90, look)

    def stretch(t):                  # arms up over the head, lean back, then relax
        e = env(t, 0.1, 0.38, 0.6, 0.9)
        p = arms(-0.15 - 2.65 * e, -0.15 - 2.65 * e, lz=-0.1 * e, rz=-0.1 * e, lf=-0.5 * e, rf=-0.5 * e)
        p["spine"] = (-0.2 * e, 0, 0)
        p["skull"] = (-0.25 * e, 0, 0)
        return p, (0, 0, 0.02 * e)
    anim(rig, "stretch", 75, stretch)

    def scratch(t):                  # right hand scratches the back of the head, head tilted
        e = env(t, 0.1, 0.3, 0.72, 0.92)
        p = arms(0.02, -0.1 - 1.9 * e, rz=0.55 * e, lf=-0.12, rf=-0.2 - (1.7 + S(t, 6) * 0.2) * e)
        p["skull"] = (0.08 * e, 0.18 * e, -0.1 * e)
        p["spine"] = (0, 0.04 * e, 0)
        return p, (0, 0, 0)
    anim(rig, "scratch", 60, scratch)

    def shift(t):                    # weight shift from foot to foot, hand on the hip
        s = S(t)
        p = arms(0.05, -0.05, lz=0.55, lf=-1.6, rf=-0.15)
        p["hips"] = (0, s * 0.06, 0)
        p["spine"] = (0, -s * 0.08, 0)
        p["skull"] = (0, s * 0.05, S(t, 0.5) * 0.15)
        p["thigh.L"] = (-0.05, 0, -0.04 * max(0.0, s))
        p["thigh.R"] = (-0.05, 0, 0.04 * max(0.0, -s))
        p["shin.L"] = (0.15 * max(0.0, -s), 0, 0)
        p["shin.R"] = (0.15 * max(0.0, s), 0, 0)
        return p, (s * 0.035, 0, -0.01)
    anim(rig, "shift", 80, shift)

    def chat(t):                     # standing talk: right hand gestures, head nods, body leans in
        g = S(t, 2)
        p = arms(-0.25 + S(t) * 0.1, -0.75 + g * 0.3, lz=0.05, rz=0.25 + S(t, 1, 0.3) * 0.15, lf=-0.5, rf=-1.2 + g * 0.35)
        p["spine"] = (0.06, 0, S(t) * 0.08)
        p["skull"] = (0.06 + S(t, 3) * 0.08, 0, S(t) * 0.12)
        return p, (0, 0, 0)
    anim(rig, "chat", 48, chat)

    def sit_talk(t):                 # sitting by the fire, talking with both hands, turning to neighbours
        p = {"thigh.L": (-1.45, -0.1, 0), "thigh.R": (-1.45, 0.1, 0), "shin.L": (0.25, 0, 0), "shin.R": (0.25, 0, 0)}
        g = S(t, 2)
        p.update(arms(-0.6 - S(t, 2, 0.25) * 0.2, -0.8 + g * 0.3, lz=0.1, rz=0.25, lf=-0.9, rf=-1.2 + g * 0.4))
        p["spine"] = (0.04, 0, S(t) * 0.15)
        p["skull"] = (S(t, 3) * 0.07, 0, S(t) * 0.35)
        return p, (0, 0.05, -(HIP - 0.13))
    anim(rig, "sit_talk", 60, sit_talk)

    def fish(t):                     # holding the rod out over the water, small bobs and a tug
        tug = env(t, 0.72, 0.8, 0.84, 0.96)
        p = arms(-0.85, -0.95 + tug * 0.55 + S(t, 2) * 0.04, lz=-0.3, rz=-0.1, lf=-0.5, rf=-0.45)
        p["spine"] = (0.1 - tug * 0.15, 0, 0)
        p["skull"] = (0.15, 0, 0)
        p["thigh.L"] = (-0.2, 0, 0)
        p["thigh.R"] = (0.12, 0, 0)
        return p, (0, 0, 0)
    anim(rig, "fish", 60, fish)

    def crouch(t):                   # hunter stalking: low crouch, peering left / right
        p = {"thigh.L": (-1.0, 0, 0), "thigh.R": (-0.7, 0, 0), "shin.L": (1.4, 0, 0), "shin.R": (1.5, 0, 0),
             "foot.L": (-0.4, 0, 0), "foot.R": (-0.3, 0, 0)}
        p.update(arms(-0.7, -0.9, lz=-0.1, lf=-0.6, rf=-0.9))
        p["spine"] = (0.45, 0, S(t) * 0.1)
        p["skull"] = (-0.35, 0, S(t) * 0.45)
        return p, (0, -0.04, -0.22)
    anim(rig, "crouch", 60, crouch)

    def clap(t):                     # child: bouncing and clapping
        k = abs(S(t, 2))
        p = arms(-1.15, -1.15, lz=-0.55 + 0.45 * k, rz=-0.55 + 0.45 * k, lf=-0.7, rf=-0.7)
        b = abs(S(t))
        p["thigh.L"] = (-0.3 * (1 - b), 0, 0)
        p["thigh.R"] = (-0.3 * (1 - b), 0, 0)
        p["shin.L"] = (0.55 * (1 - b), 0, 0)
        p["shin.R"] = (0.55 * (1 - b), 0, 0)
        p["skull"] = (-0.1, 0, S(t) * 0.2)
        return p, (0, 0, b * 0.1 - (1 - b) * 0.05)
    anim(rig, "clap", 32, clap)

    def pray_stand(t):               # standing prayer: hands together at the chest, head bowed, gentle sway
        p = arms(-0.45, -0.45, lz=-0.45, rz=-0.45, lf=-1.55, rf=-1.55)
        p["spine"] = (0.1 + S(t) * 0.03, 0, 0)
        p["skull"] = (0.35 + S(t, 1, 0.2) * 0.06, 0, 0)
        p["hips"] = (0, S(t, 0.5) * 0.03, 0)
        return p, (0, 0, 0)
    anim(rig, "pray_stand", 60, pray_stand)

    def bow(t):                      # deep bow towards the altar, hands together
        e = env(t, 0.1, 0.4, 0.6, 0.9)
        p = arms(-0.45 - 0.3 * e, -0.45 - 0.3 * e, lz=-0.45, rz=-0.45, lf=-1.55, rf=-1.55)
        p["spine"] = (0.15 + 0.55 * e, 0, 0)
        p["skull"] = (0.3 + 0.2 * e, 0, 0)
        p["thigh.L"] = (0.25 * e, 0, 0)
        p["thigh.R"] = (0.25 * e, 0, 0)
        return p, (0, 0.05 * e, 0)
    anim(rig, "bow", 60, bow)


# ───────── whole kit ─────────
def build_parts():
    parts = []
    build_head(parts)
    build_torsos(parts)
    build_arms(parts)
    build_legs(parts)
    build_hair(parts)
    build_hats(parts)
    build_overlays(parts)
    return parts


def build(render=None):
    global LOD
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    rig = make_armature()
    tris = {}
    for lod in (0, 1):
        LOD = lod
        for p in build_parts():
            nm = p.name + ("" if lod == 0 else "__far")
            _, n = to_object(p, rig, nm)
            tris[nm] = n
    LOD = 0
    build_anims(rig)
    if render:
        import render_residents
        render_residents.run(rig, render)
    path = os.path.join(OUT, "resident.glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_vertex_color="ACTIVE",
                              export_materials="NONE", export_yup=True, export_texcoords=True, export_normals=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True,
                              export_morph=False, export_extras=False, export_def_bones=False,
                              export_optimize_animation_size=False, export_force_sampling=True,
                              export_frame_step=1, export_bake_animation=False)
    print("residents ->", path)
    budget(tris)
    return tris


def budget(t):
    def g(*names, far=False):
        tot = 0
        for n in names:
            for s in ("_L", "_R") if n in ("arm", "leg_trousers", "leg_stocking", "arm_robe") else ("",):
                tot += t.get(n + s + ("__far" if far else ""), 0)
        return tot
    rows = [
        ("tunic + short hair + cap", ("leg_trousers", "torso_tunic", "arm", "head", "hair_short", "hat_cap")),
        ("tunic + curly + beard + hood", ("leg_trousers", "torso_tunic", "arm", "head", "hair_curly", "beard", "hood")),
        ("dress + curly long", ("leg_stocking", "torso_dress", "arm", "head", "hair_curly_long")),
        ("dress + braids + scarf", ("leg_stocking", "torso_dress", "arm", "head", "hair_braids", "hat_scarf")),
        ("farmer: straw", ("leg_trousers", "torso_tunic", "arm", "head", "hair_short", "hat_straw")),
        ("baker: wave+baker+apron", ("leg_trousers", "torso_tunic", "arm", "head", "hair_wave", "hat_baker", "apron_job", "beard")),
        ("herbalist: dress+wave long+bag", ("leg_stocking", "torso_dress", "arm", "head", "hair_wave_long", "herb_bag")),
        ("elder chief: curly long+beard+shawl+sash", ("leg_trousers", "torso_tunic", "arm", "head", "hair_curly_long", "beard", "shawl", "sash")),
        ("priest: robe", ("leg_trousers", "torso_robe", "arm_robe", "head", "hair_short", "beard")),
        ("baby basket", ("baby_basket",)),
    ]
    print("  parts:", " ".join("%s=%d" % kv for kv in sorted(t.items()) if not kv[0].endswith("__far")))
    print("  far:", " ".join("%s=%d" % (k[:-5], v) for k, v in sorted(t.items()) if k.endswith("__far")))
    print("  -- assembled resident triangles (close / far) --")
    for nm, ps in rows:
        print("  %-48s %5d / %4d" % (nm, g(*ps), g(*ps, far=True)))


# ───────── rigid props (Art.parts) ─────────
HAND_R = Vector((-HAND.x, HAND.y, HAND.z))
HAND_L = Vector((HAND.x, HAND.y, HAND.z))


def build_props():
    ps = PartSet("resident_props")

    def part(n):
        return Model(n)
    o = ITEM
    m = part("item_log")
    m.cyl(0.12, 0.12, 0.95, pos=o + Vector((-0.475, 0, 0)), rot=(0, math.pi / 2, 0.12), color="TRUNK", seg=8, smooth=True,
          cap="STUMP_TOP", bottom_cap="STUMP_TOP")
    ps.add("item_log", m, pivot=o)
    m = part("item_plank")
    for k in range(3):
        m.box((0.95, 0.3, 0.06), pos=o + Vector((0.02 * k, 0, -0.1 + k * 0.065)), color=shade("PLANK", (0.92, 1.0, 1.06)[k]))
    ps.add("item_plank", m, pivot=o)
    m = part("item_stone")
    m.ico(0.2, pos=o + Vector((0, 0, 0.02)), scl=(1.1, 1, 0.85), color="ROCK", subdiv=2, smooth=True, lumps=0.15, seed=3)
    ps.add("item_stone", m, pivot=o)
    m = part("item_sack")
    m.sphere(0.22, pos=o + Vector((0, 0, 0.02)), scl=(1, 0.8, 1.1), color=mix("THATCH", "PLASTER", 0.55), seg=12, rings=8, lumps=0.08)
    m.cyl(0.07, 0.03, 0.12, pos=o + Vector((0, 0, 0.22)), color=shade(mix("THATCH", "PLASTER", 0.55), 0.85), seg=8, smooth=True)
    ps.add("item_sack", m, pivot=o)
    m = part("item_basket")
    m.cyl(0.24, 0.3, 0.2, pos=o + Vector((0, 0, -0.1)), color="LOOK_STRAW_DARK", seg=12, smooth=True, cap="LOOK_STRAW")
    for k in range(3):
        m.sphere(0.1, pos=o + Vector((-0.12 + k * 0.12, 0.02 * k, 0.12)), scl=(1.2, 1, 0.75), color="BREAD", seg=8, rings=5)
    ps.add("item_basket", m, pivot=o)
    m = part("item_crate")
    m.box((0.4, 0.34, 0.32), pos=o + Vector((0, 0, -0.14)), color=shade("WOOD", 1.2))
    m.box((0.42, 0.36, 0.05), pos=o + Vector((0, 0, 0.13)), color="WOOD")
    ps.add("item_crate", m, pivot=o)
    m = part("item_water")
    m.cyl(0.17, 0.15, 0.3, pos=o + Vector((0, 0, -0.14)), color="WOOD", seg=12, smooth=True, cap="WATER")
    m.cyl(0.18, 0.18, 0.04, pos=o + Vector((0, 0, 0.02)), color="WOOD_DARK", seg=12)
    ps.add("item_water", m, pivot=o)

    h = HAND_R
    fwd = (math.pi / 2 - 0.1, 0, 0)

    def handle(m, length, back=0.1, r=0.026):
        m.cyl(r, r, length, pos=h + Vector((0, back, -0.01)), rot=fwd, color="WOOD", seg=6, smooth=True)

    m = part("tool_axe")
    handle(m, 0.72)
    m.box((0.04, 0.2, 0.2), pos=h + Vector((0, -0.6, -0.16)), color="ROCK_DARK")
    ps.add("tool_axe", m, pivot=h)
    m = part("tool_hammer")
    handle(m, 0.5)
    m.box((0.2, 0.12, 0.12), pos=h + Vector((0, -0.44, -0.11)), color="ROCK_DARK")
    ps.add("tool_hammer", m, pivot=h)
    m = part("tool_pick")
    handle(m, 0.65)
    m.box((0.05, 0.08, 0.5), pos=h + Vector((0, -0.6, -0.33)), rot=(0.15, 0, 0), color="ROCK_DARK")
    ps.add("tool_pick", m, pivot=h)
    m = part("tool_hoe")
    handle(m, 1.05, back=0.25)
    m.box((0.2, 0.05, 0.16), pos=h + Vector((0, -0.84, -0.26)), rot=(0.2, 0, 0), color="ROCK")
    ps.add("tool_hoe", m, pivot=h)
    m = part("tool_sickle")
    handle(m, 0.3, back=0.0)
    for k in range(3):
        a = k / 2 * math.pi * 0.85
        m.box((0.05, 0.08, 0.035), pos=h + Vector((math.sin(a) * 0.14, -0.33 - math.sin(a) * 0.05, -0.12 + math.cos(a) * 0.12)),
              rot=(0, -a, 0), color="ROCK")
    ps.add("tool_sickle", m, pivot=h)
    m = part("tool_rod")
    m.cyl(0.022, 0.01, 1.5, pos=h + Vector((0, 0.1, 0.0)), rot=(math.pi / 2 - 0.55, 0, 0), color="WOOD", seg=5)
    ps.add("tool_rod", m, pivot=h)
    m = part("tool_peel")
    handle(m, 0.6, back=0.05)
    m.box((0.24, 0.26, 0.03), pos=h + Vector((0, -0.66, -0.07)), rot=(0.1, 0, 0), color=shade("WOOD", 1.25))
    ps.add("tool_peel", m, pivot=h)
    m = part("tool_herbs")
    m.cyl(0.025, 0.025, 0.22, pos=h + Vector((0, 0.04, -0.02)), rot=fwd, color="LOOK_HERB", seg=5)
    for k in range(3):
        m.sphere(0.06, pos=h + Vector((-0.05 + k * 0.05, -0.22 - 0.02 * k, -0.06 + 0.03 * (k % 2))), scl=(0.8, 1.2, 0.5),
                 color=shade("LOOK_HERB", (0.9, 1.1, 1.0)[k]), seg=6, rings=4)
    ps.add("tool_herbs", m, pivot=h)
    m = part("cane")                   # elder's cane, crook on top (base_c)
    m.cyl(0.026, 0.026, HAND.z + 0.04, pos=HAND_L + Vector((0, -0.03, -HAND.z)), color="LOOK_CANE", seg=6, smooth=True)
    m.sphere(0.045, pos=HAND_L + Vector((0, -0.05, 0.06)), scl=(0.8, 1.4, 0.8), color="LOOK_CANE", seg=8, rings=5)
    ps.add("cane", m, pivot=HAND_L)
    ps.export(OUT)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    render = None
    if "--render" in args:
        i = args.index("--render")
        render = args[i + 1:i + 3]
    if "--no-props" not in args:
        build_props()
    build(render)
