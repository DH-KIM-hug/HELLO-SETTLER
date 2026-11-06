"""Animal part kit v2 (ROADMAP B3, docs/WILDLIFE.md 1 · 7): smooth rounded storybook animals that match the v4 residents.
One glb per species in art/models/animals/<key>.glb (load with Art.parts("animals/<key>")) + animals.json (manifest).
No rig: every species is a few separately pivoted parts (like the resident kit) so a view script can bob / swing them.

Species (key -> kind):
  wild      fish_a (silver) · fish_b (gold) · deer · fawn · rabbit · wolf · boar · wild_sheep · aurochs
  domestic  dog · puppy · pig · sheep · cow · chicken · donkey
Parts and pivots (object origin = joint):
  four-legged : body (ground centre) · head (neck root: nod = rotate about X) · leg_fl leg_fr leg_bl leg_br (hip /
                shoulder: swing about X) · tail (tail root)            l = the animal's left = +X, front = -Y
  chicken     : body · head · leg_l leg_r · wing_l wing_r (shoulder: flap about Y) · tail
  fish        : body (origin = fish centre, not the ground) · tail (tail root: wag about Z)
Scale: same model units as resident.glb (adult ~1.9 tall, shoulder 1.22) -> the view scales both by Style.RESIDENT_SCALE.
  rabbit ankle-to-shin high, deer back ~ an adult's chest/shoulder, aurochs taller than a person.
Look (v2): smooth-shaded soft bodies (UV-sphere blobs, tapered capsule legs with rounded feet), slightly big heads,
  gentle faces (small dark eyes with a white highlight, soft nose, a faint blush on the tame / baby ones).
  Flat species colours stay vertex colours; painted greyscale detail (fur / long shaggy fur / wool curls / feathers / fish
  scales / hide / horn ridges) comes from art/models/animal_fur.png (pack_animal_atlas.py): vertex colour alpha =
  (cell + 0.5) / 32, UV (TEXCOORD_0) = tile coords + (100, 0). render/toon.gdshader (Art.body_mat) multiplies the colour by it.
  Eyes / highlights / blush are "_body_nh" groups (no outline, so the white highlight is not ringed in ink).
Budget: ~400-900 tris per animal (fish <= 120).
Run: blender -b --factory-startup --python build_animals.py -- [out_dir]
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly  # noqa: E402
from lowpoly import Model, PartSet, Vector, shade, out_dir_from_argv  # noqa: E402

OUT = os.path.join(out_dir_from_argv(), "animals")

EYE = "2a2324"
NOSE = "3e302b"
HOOF = "5a4438"
CREAM = "f3e8d4"
PINK = "eaa79b"
BLUSH = "f0a89a"
WHITE = "ffffff"

# detail atlas cells (must match pack_animal_atlas.py)
FUR, SHAGGY, WOOL, FEATHER, SCALE, HIDE, HORN, FINE = range(8)
UVOFF = 100.0
UVL = "UVDetail"


def _export_glb_uv(path):
    """lowpoly's exporter but with texcoords (the detail tile coords)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_vertex_color="ACTIVE",
                              export_materials="NONE", export_yup=True, export_texcoords=True,
                              export_normals=True, export_animations=False, export_extras=False,
                              export_skins=False, export_morph=False)


lowpoly._export_glb = _export_glb_uv


def V(*a):
    return Vector(a)


# ───────────────────────── detail (painted atlas) ─────────────────────────
def set_det(m, f, cell, uvs, group="body"):
    bm = m._bm(group)
    uv = bm.loops.layers.uv.get(UVL) or bm.loops.layers.uv.new(UVL)
    cl = bm.loops.layers.float_color["Color"]
    a = (cell + 0.5) / 32.0
    for lo, (u, v) in zip(f.loops, uvs):
        lo[uv].uv = (u + UVOFF, 1.0 - v)          # the glTF exporter flips V
        c = lo[cl]
        lo[cl] = (c[0], c[1], c[2], a)


def det_wrap(m, faces, cell, o, axis, up, tile, r, flow="around", group="body"):
    """Detail around an axis: flow "around" = strokes run from the 'up' side down around the axis (bodies, heads:
    fur flows from the spine to the belly, mirrored at the spine), "along" = strokes run along the axis (legs, tails)."""
    a = Vector(axis).normalized()
    u0 = Vector(up)
    u0 = (u0 - a * u0.dot(a)).normalized()
    s = a.cross(u0)
    o = Vector(o)
    for f in faces:
        ce = cell(f) if callable(cell) else cell
        if ce is None:
            continue
        q = []
        for lo in f.loops:
            d = lo.vert.co - o
            x, y = d.dot(s), d.dot(u0)
            q.append((math.atan2(x, y) if x * x + y * y > 1e-10 else None, d.dot(a)))
        if flow == "around":
            q = [(None if g is None else abs(g), l) for g, l in q]
        else:
            known = [g for g, _ in q if g is not None]
            if known and max(known) - min(known) > math.pi:
                q = [(None if g is None else (g + 2 * math.pi if g < 0 else g), l) for g, l in q]
        known = [g for g, _ in q if g is not None]
        avg = sum(known) / len(known) if known else 0.0
        uvs = []
        for g, l in q:
            g = avg if g is None else g
            uvs.append((l / tile, g * r / tile) if flow == "around" else (g * r / tile, l / tile))
        set_det(m, f, ce, uvs, group)


# ───────────────────────── shapes ─────────────────────────
def blob(m, c, r3, color, seg=10, rings=7, rot=(0, 0, 0), colfn=None, deform=None, axis="z", group="body",
         det=None):
    """Smooth ellipsoid (UV sphere, poles on `axis`) of radii r3 centred at c. deform(p, n) -> p (local, before rot).
    det = (cell, tile, flow_axis, up) -> painted detail wrapped around flow_axis. Tris = seg * 2 * (rings - 1)."""
    bm = m._bm(group)
    res = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    R = Euler(rot, "XYZ").to_matrix()
    for v in res["verts"]:
        n = v.co.normalized()
        if axis == "y":                       # rotate the poles onto Y (front / back)
            n = Vector((n.x, -n.z, n.y))
        p = Vector((n.x * r3[0], n.y * r3[1], n.z * r3[2]))
        if deform:
            p = deform(p, n)
        v.co = Vector(c) + R @ p
    faces = m._faces_of(res["verts"])
    bm.normal_update()
    m._finish(bm, faces, color, True, colfn)
    if det is None and group == "body":
        det = (FINE, 0.07, (0, 0, 1), (0, -1, 0))
    if det:
        cell, tile, fax, fup = det
        det_wrap(m, faces, cell, c, R @ Vector(fax), R @ Vector(fup), tile, (r3[0] + r3[2]) / 2, "around", group)
    return faces


def tube(m, pts, radii, color, seg=7, colfn=None, smooth=True, group="body", det=None, end=0.0, start=0.0):
    """Capped smooth tube along a polyline. end / start > 0 = rounded dome at that end (fraction of its radius).
    det = (cell, tile): painted detail, strokes along the tube."""
    pts = [Vector(p) for p in pts]
    radii = list(radii)
    if end > 0:
        t = (pts[-1] - pts[-2]).normalized()
        r = radii[-1]
        pts += [pts[-1] + t * r * end * 0.6, pts[-1] + t * r * end * 0.95]
        radii += [r * 0.8, r * 0.35]
    if start > 0:
        t = (pts[0] - pts[1]).normalized()
        r = radii[0]
        pts = [pts[0] + t * r * start * 0.95, pts[0] + t * r * start * 0.6] + pts
        radii = [r * 0.35, r * 0.8] + radii
    rings = []
    u_prev = None
    for i, p in enumerate(pts):
        t = (pts[1] - pts[0]) if i == 0 else (pts[-1] - pts[-2]) if i == len(pts) - 1 else (pts[i + 1] - pts[i - 1])
        t.normalize()
        if u_prev is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((0, -1, 0))
            u = t.cross(ref).normalized()
        else:
            u = (u_prev - t * u_prev.dot(t)).normalized()
        v = t.cross(u)
        u_prev = u
        rings.append([p + (u * math.cos(k / seg * 2 * math.pi) + v * math.sin(k / seg * 2 * math.pi)) * radii[i]
                      for k in range(seg)])
    faces = m.strip(rings, color=color, smooth=smooth, close=True, colfn=colfn, caps=True, group=group)
    if det is None and group == "body":
        det = (FINE, 0.07)
    if det:
        cell, tile = det
        cum = [0.0]
        for a, b in zip(pts[:-1], pts[1:]):
            cum.append(cum[-1] + (b - a).length)
        circ = 2 * math.pi * (sum(radii) / len(radii))
        for fi, f in enumerate(faces[:(len(pts) - 1) * seg]):
            ri, i = fi // seg, fi % seg
            uvs = [(i, ri), (i + 1, ri), (i + 1, ri + 1), (i, ri + 1)]
            set_det(m, f, cell, [(k / seg * circ / tile, cum[rr] / tile) for k, rr in uvs], group)
    return faces


def bean(front=1.08, back=0.97, belly=0.0):
    """Body deform: chest a bit fuller than the rump, belly sagging a touch."""
    def fn(p, n):
        k = 1 + (front - 1) * max(0.0, -n.y) + (back - 1) * max(0.0, n.y)
        z = p.z * k
        if belly and n.z < 0:
            z *= 1 + belly * (-n.z) * (1 - abs(n.y))
        return Vector((p.x * k, p.y, z))
    return fn


def fib_dirs(n, seed=0.0):
    out = []
    ga = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - z * z))
        a = ga * i + seed
        out.append(Vector((r * math.cos(a), r * math.sin(a), z)))
    return out


def puffs(n=26, amt=0.16, width=0.45, seed=0.7, below=-0.55):
    """Cloud / wool deform: the surface swells into round puffs (union-of-spheres look, smooth creases between)."""
    dirs = fib_dirs(n, seed)
    c0 = math.cos(width)

    def fn(p, n_):
        best = 0.0
        for d in dirs:
            t = n_.dot(d)
            if t > c0:
                best = max(best, math.sqrt((t - c0) / (1 - c0)))
        k = 1 + amt * (best - 0.5) * (0.4 if n_.z < below else 1.0)
        return p * k
    return fn


def shag(amt=0.1, hang=0.12, freq=3.0, seed=2.0):
    """Shaggy coat deform: lumpy locks + the lower half hangs down in a scalloped fringe."""
    def fn(p, n):
        q = p * (1 + amt * noise.noise(n * freq + Vector((seed, seed * 2, 0))))
        if n.z < 0.1:
            lobe = 0.5 + 0.5 * math.cos(math.atan2(n.y, n.x) * 9)
            q.z -= hang * (0.1 - n.z) * (0.6 + 0.4 * lobe) * max(0.0, 1 - abs(n.y) * 0.8)
        return q
    return fn


def surf(c, r3, d):
    d = Vector(d).normalized()
    return Vector(c) + Vector((d.x * r3[0], d.y * r3[1], d.z * r3[2]))


def snrm(r3, d):
    d = Vector(d).normalized()
    return Vector((d.x / r3[0], d.y / r3[1], d.z / r3[2])).normalized()


def face(h, c, r3, d, er, blush=False, hl=True):
    """Gentle face: two small dark eyes, each with a white highlight (up-front), optional soft blush below."""
    er *= 1.15
    for sx in (-1, 1):
        dd = Vector((d[0] * sx, d[1], d[2]))
        p = surf(c, r3, dd)
        n = snrm(r3, dd)
        ec = p - n * er * 0.35
        blob(h, ec, (er, er, er * 1.15), EYE, seg=6, rings=3, group="body_nh")
        if hl:
            hd = (n * 0.75 + V(0, -0.25, 0.5) + V(-sx * 0.15, 0, 0)).normalized()
            blob(h, ec + hd * er * 0.82, (er * 0.36, er * 0.36, er * 0.36), WHITE, seg=4, rings=2, group="body_nh")
        if blush:
            bd = (dd + V(sx * 0.05, -0.15, -0.45)).normalized()
            bp = surf(c, r3, bd)
            bn = snrm(r3, bd)
            blob(h, bp - bn * er * 0.2, (er * 1.2, er * 1.2, er * 0.75), BLUSH, seg=5, rings=2, group="body_nh",
                 rot=(0, 0, 0))


def ear(m, base, rx, ry, length, width, color, thick=0.4, inner=None, seg=6, rings=3, cell=FINE, tile=0.1, rz=0.0):
    """Soft leaf ear: a flattened ellipsoid from base along its length. rx < 0 leans back, ry > 0 leans to +X.
    inner = colour of the front (-Y) face."""
    R = Euler((rx, ry, rz), "XYZ").to_matrix()
    d = R @ Vector((0, 0, 1))
    c = Vector(base) + d * length * 0.45
    fwd = R @ Vector((0, -1, 0))
    colfn = (lambda f: inner if f.normal.dot(fwd) > 0.55 else color) if inner else None

    def pinch(p, n):                    # pointed-ish tip, round base
        k = 1 - 0.35 * max(0.0, n.z)
        return Vector((p.x * k, p.y * k, p.z))
    return blob(m, c, (width / 2, width / 2 * thick, length / 2), color, seg=seg, rings=rings, rot=(rx, ry, rz),
                colfn=colfn, deform=pinch, det=(cell, tile, (0, 0, 1), (0, -1, 0)) if cell is not None else None)


def under(top, low, k=-0.35):
    return lambda f: low if f.normal.z < k else top


def dtri(m, pts, color, group="body_nh"):
    m.poly(pts, color=color, group=group)
    m.poly(list(reversed(pts)), color=color, group=group)


def legs4(ps, cz, x, yf, yb, r_top, r_bot, color, foot="hoof", foot_color=HOOF, seg=7, front_color=None, cell=FUR,
          tile=0.12, knee=0.0, seg_=6):
    """Four tapered legs with rounded feet, pivot at the hip (z = cz, hidden in the body).
    foot: hoof (dark lower band, short dome) or paw (soft round paw blob). knee > 0 = hind legs bend back a little."""
    r_top, r_bot = r_top * 1.3, r_bot * 1.35          # storybook-chunky legs (match the round residents)
    for nm, sx, sy in (("leg_fl", 1, yf), ("leg_fr", -1, yf), ("leg_bl", 1, yb), ("leg_br", -1, yb)):
        hip = V(sx * x, sy, cz)
        m = Model(nm)
        col = front_color if (front_color and sy < 0) else color
        back = sy > 0
        kb = knee if back else 0.0
        bot = r_bot
        if foot == "hoof":
            fh = min(0.1, cz * 0.13)
            pts = [hip, V(hip.x, hip.y + kb, cz * 0.48), V(hip.x, hip.y - bot * 0.1, bot * 0.55)]
            rad = [r_top, (r_top + bot) * 0.52, bot * 1.06]
            tube(m, pts, rad, col, seg=seg_, end=0.45, det=(cell, tile),
                 colfn=lambda f, fh=fh, fc=foot_color, c=col: fc if f.calc_center_median().z < fh else c)
        else:
            pts = [hip, V(hip.x, hip.y + kb, cz * 0.5), V(hip.x, hip.y, bot * 1.4)]
            rad = [r_top, (r_top + bot) * 0.5, bot]
            tube(m, pts, rad, col, seg=seg_, det=(cell, tile))
            blob(m, (hip.x, hip.y - bot * 0.35, bot * 0.75), (bot * 1.2, bot * 1.45, bot * 0.8), foot_color or col,
                 seg=6, rings=3)
        ps.add(nm, m, pivot=hip)


def grow(m, c, k):
    """Scale a whole part about c (bigger storybook heads)."""
    for bm in m.groups.values():
        bmesh.ops.scale(bm, vec=(k, k, k), verts=bm.verts, space=Matrix.Translation(-Vector(c)))


def scale_parts(ps, k):
    for _, model, pivot in ps.parts:
        for bm in model.groups.values():
            bmesh.ops.scale(bm, vec=(k, k, k), verts=bm.verts)
        pivot *= k


def body(m, c, r3, color, seg=10, rings=9, colfn=None, deform=None, cell=FUR, tile=0.16):
    r3 = (r3[0] * 1.12, r3[1], r3[2] * 1.08)          # a little rounder than life
    return blob(m, c, r3, color, seg=seg, rings=rings, axis="y", colfn=colfn, deform=deform,
                det=(cell, tile, (0, 1, 0), (0, 0, 1)) if cell is not None else None)


def head(m, c, r3, color, seg=10, rings=6, colfn=None, deform=None, cell=FINE, tile=0.1):
    return blob(m, c, r3, color, seg=seg, rings=rings, axis="y", colfn=colfn, deform=deform,
                det=(cell, tile, (0, 1, 0), (0, 0, 1)) if cell is not None else None)


# ───────────────────────── wild ─────────────────────────
def fish(key, back, side, belly, fin):
    ps = PartSet(key)
    m = Model("body")
    r3 = (0.055, 0.16, 0.08)

    def plump(p, n):                      # rounder head, slimmer towards the tail
        k = 1 + 0.12 * max(0.0, -n.y) - 0.2 * max(0.0, n.y)
        return Vector((p.x * k, p.y, p.z * k))
    blob(m, (0, 0, 0), r3, side, seg=8, rings=5, axis="y", deform=plump,
         colfn=lambda f: back if f.normal.z > 0.45 else belly if f.normal.z < -0.45 else side,
         det=(SCALE, 0.07, (0, 1, 0), (0, 0, 1)))                                                         # 64
    for sx in (-1, 1):                                                                                    # eyes 2 x 12
        p = surf((0, 0, 0), r3, (sx * 0.62, -0.72, 0.28))
        blob(m, p, (0.016, 0.016, 0.018), EYE, seg=4, rings=3, group="body_nh")
    dtri(m, [(0, -0.05, 0.065), (0, 0.06, 0.06), (0, 0.09, 0.115)], fin)                                 # dorsal 2
    for sx in (-1, 1):                                                                                    # pectoral 2 x 2
        dtri(m, [(sx * 0.045, -0.06, -0.03), (sx * 0.05, -0.02, -0.04), (sx * 0.085, 0.01, -0.06)], fin)
    ps.add("body", m)
    t = Model("tail")
    dtri(t, [(0, 0.12, 0), (0, 0.25, 0.09), (0, 0.21, 0), (0, 0.25, -0.09)], fin)                         # 4
    ps.add("tail", t, pivot=(0, 0.14, 0))
    return ps


def deer(baby=False):
    ps = PartSet("fawn" if baby else "deer")
    coat = "c98a55" if baby else "b77a4a"
    hk = 1.35 if baby else 1.15
    cz, L, W, Hb = 0.8, 0.88, 0.4, 0.42
    b = Model("body")
    body(b, (0, 0, cz), (W / 2, L / 2, Hb / 2), coat, deform=bean(1.08, 0.98, 0.05), tile=0.17,
         colfn=lambda f: CREAM if f.normal.z < -0.45 or f.normal.y > 0.8 else coat)
    if baby:                                                                                  # fawn spots
        for x, y in ((0.08, -0.16), (-0.08, -0.1), (0.07, 0.04), (-0.07, 0.13), (0.05, 0.24), (-0.03, -0.25)):
            p = surf((0, 0, cz), (W / 2, L / 2, Hb / 2), (x / (W / 2), y / (L / 2), 0.75))
            blob(b, p, (0.034, 0.034, 0.014), "f8eedb", seg=5, rings=2)
    ps.add("body", b)
    N = V(0, -0.3, cz + 0.1)
    H = N + V(0, -0.12, 0.42 if not baby else 0.36)
    h = Model("head")
    tube(h, [N, N + V(0, -0.05, 0.2), H + V(0, 0.04, -0.07)], [0.12, 0.1, 0.085], coat, seg=7, det=(FUR, 0.12))
    hr = (0.14 * hk, 0.15 * hk, 0.13 * hk)
    head(h, H, hr, coat)
    blob(h, H + V(0, -0.14, -0.05) * hk, V(0.075, 0.09, 0.07) * hk, CREAM, seg=7, rings=4)                # muzzle
    blob(h, H + V(0, -0.225, -0.035) * hk, V(0.032, 0.022, 0.025) * hk, NOSE, seg=5, rings=3)
    face(h, H, hr, (0.55, -0.68, 0.3), 0.027 * hk, blush=baby)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.09, 0.04, 0.07) * hk, -0.3, sx * 0.95, 0.19 * hk, 0.11 * hk, coat, inner="f2d6c2", tile=0.08)
        if not baby:                                                                          # small, friendly antlers
            a = H + V(sx * 0.055, 0.03, 0.12) * hk
            tube(h, [a, a + V(sx * 0.05, 0.03, 0.12), a + V(sx * 0.1, 0.07, 0.22)], [0.022, 0.018, 0.012], "e6d2a8",
                 seg=4, end=0.8, det=(HORN, 0.06))
            m_ = a + V(sx * 0.04, 0.025, 0.1)
            tube(h, [m_, m_ + V(0, -0.06, 0.08)], [0.015, 0.01], "e6d2a8", seg=4, end=0.8)
    grow(h, H, 1.0 if baby else 1.12)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.11, -0.28, 0.28, 0.08, 0.038, coat, tile=0.1, knee=0.05)
    t = Model("tail")
    T = V(0, 0.44, cz + 0.12)
    blob(t, T + V(0, 0.03, -0.03), (0.045, 0.04, 0.075), coat, seg=7, rings=4, rot=(0.5, 0, 0),
         colfn=lambda f: CREAM if f.normal.y > 0.3 else coat)
    ps.add("tail", t, pivot=T)
    if baby:
        scale_parts(ps, 0.62)
    return ps


def rabbit():
    ps = PartSet("rabbit")
    coat, light, inner = "c2a07f", "f8f2e8", "eeb2a6"
    b = Model("body")
    blob(b, (0, 0.03, 0.15), (0.115, 0.15, 0.125), coat, seg=10, rings=7, rot=(-0.25, 0, 0), axis="y",
         colfn=under(coat, light, -0.5), det=(FUR, 0.08, (0, 1, 0), (0, 0, 1)))
    ps.add("body", b)
    N = V(0, -0.09, 0.22)
    H = V(0, -0.14, 0.3)
    h = Model("head")
    hr = (0.105, 0.1, 0.095)
    head(h, H, hr, coat, colfn=under(coat, light, -0.6), tile=0.07)
    blob(h, H + V(0, -0.075, -0.035), (0.055, 0.04, 0.04), light, seg=7, rings=4)
    blob(h, H + V(0, -0.11, -0.015), (0.016, 0.01, 0.012), "d98a80", seg=5, rings=3)
    face(h, H, hr, (0.62, -0.62, 0.3), 0.019, blush=True)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.04, 0.03, 0.06), -0.22, sx * 0.2, 0.2, 0.068, coat, thick=0.35, inner=inner, tile=0.06)
    grow(h, H, 1.1)
    ps.add("head", h, pivot=N)
    for nm, sx in (("leg_fl", 1), ("leg_fr", -1)):
        m = Model(nm)
        hip = V(sx * 0.05, -0.08, 0.12)
        tube(m, [hip, V(hip.x, hip.y - 0.01, 0.03)], [0.022, 0.018], coat, seg=6, det=(FINE, 0.06))
        blob(m, (hip.x, hip.y - 0.012, 0.018), (0.024, 0.032, 0.018), light, seg=6, rings=4)
        ps.add(nm, m, pivot=hip)
    for nm, sx in (("leg_bl", 1), ("leg_br", -1)):                                        # haunch + long foot
        m = Model(nm)
        hip = V(sx * 0.075, 0.07, 0.14)
        blob(m, (hip.x * 1.05, hip.y, 0.1), (0.05, 0.085, 0.078), coat, seg=8, rings=5, axis="y",
             det=(FUR, 0.08, (0, 1, 0), (0, 0, 1)))
        blob(m, (hip.x * 1.05, hip.y - 0.04, 0.018), (0.032, 0.075, 0.02), light, seg=7, rings=4, axis="y")
        ps.add(nm, m, pivot=hip)
    t = Model("tail")
    T = V(0, 0.17, 0.17)
    blob(t, T + V(0, 0.015, 0), (0.045, 0.042, 0.045), light, seg=8, rings=5, deform=puffs(8, 0.15, 0.7),
         det=(WOOL, 0.05, (0, 1, 0), (0, 0, 1)))
    ps.add("tail", t, pivot=T)
    return ps


def wolf():
    ps = PartSet("wolf")
    coat, light, dark = "9aa0a2", "eee6d8", "7c8286"
    cz, L, W, Hb = 0.6, 0.84, 0.34, 0.36
    b = Model("body")
    body(b, (0, 0, cz), (W / 2, L / 2, Hb / 2), coat, deform=bean(1.1, 0.95), tile=0.15,
         colfn=lambda f: light if f.normal.z < -0.45 else dark if f.normal.z > 0.85 else coat)
    blob(b, (0, -0.3, cz + 0.04), (0.19, 0.15, 0.21), light, seg=8, rings=6, deform=shag(0.08, 0.06, 4.0, 5.0),
         det=(SHAGGY, 0.12, (0, 1, 0), (0, 0, 1)))                                            # soft chest ruff
    ps.add("body", b)
    N = V(0, -0.32, cz + 0.1)
    H = V(0, -0.45, cz + 0.33)
    h = Model("head")
    tube(h, [N, H + V(0, 0.05, -0.05)], [0.13, 0.11], coat, seg=7, det=(FUR, 0.12))
    hr = (0.16, 0.145, 0.14)
    head(h, H, hr, coat, colfn=lambda f: light if f.normal.z < -0.3 else coat, cell=FUR, tile=0.11, seg=9)
    for sx in (-1, 1):                                                                         # fluffy cheek tufts
        blob(h, H + V(sx * 0.12, 0.0, -0.05), (0.06, 0.07, 0.06), light, seg=6, rings=3,
             deform=shag(0.12, 0.0, 5.0, sx * 3.0), det=(SHAGGY, 0.08, (0, 1, 0), (0, 0, 1)))
    blob(h, H + V(0, -0.135, -0.045), (0.065, 0.09, 0.055), light, seg=8, rings=5, axis="y")
    blob(h, H + V(0, -0.22, -0.025), (0.032, 0.022, 0.024), NOSE, seg=5, rings=3)
    face(h, H, hr, (0.48, -0.75, 0.35), 0.023)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.08, 0.03, 0.09), -0.1, sx * 0.3, 0.13, 0.1, coat, thick=0.42, inner=light, tile=0.07)
    grow(h, H, 1.12)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.095, -0.27, 0.27, 0.065, 0.038, coat, foot="paw", foot_color=light, tile=0.1, knee=0.04)
    t = Model("tail")
    T = V(0, 0.4, cz + 0.08)
    tube(t, [T, T + V(0, 0.1, -0.06), T + V(0, 0.18, -0.2), T + V(0, 0.2, -0.3)], [0.045, 0.075, 0.065, 0.04], coat,
         seg=6, end=0.9, det=(SHAGGY, 0.1),
         colfn=lambda f: light if f.calc_center_median().z < T.z - 0.28 else coat)
    ps.add("tail", t, pivot=T)
    return ps


def boar():
    ps = PartSet("boar")
    coat, mane, snout = "7b6150", "54423a", "c09a88"
    cz = 0.42
    b = Model("body")
    body(b, (0, 0.03, cz + 0.04), (0.22, 0.42, 0.23), coat, deform=bean(1.15, 0.95, 0.06), tile=0.13, cell=SHAGGY,
         colfn=under(coat, shade(coat, 1.15)))
    for k in range(4):                                                                       # soft bristly mane ridge
        y = -0.26 + k * 0.11
        z = cz + 0.3 - k * 0.03
        blob(b, (0, y, z - 0.02), (0.035, 0.06, 0.05), mane, seg=5, rings=3, rot=(-0.4, 0, 0),
             det=(SHAGGY, 0.06, (0, 1, 0), (0, 0, 1)))
    ps.add("body", b)
    N = V(0, -0.33, cz + 0.08)
    H = V(0, -0.45, cz + 0.06)
    h = Model("head")
    hr = (0.16, 0.17, 0.16)
    head(h, H, hr, coat, cell=FUR, tile=0.1)
    tube(h, [H + V(0, -0.08, -0.04), H + V(0, -0.19, -0.05)], [0.075, 0.068], snout, seg=7)
    blob(h, H + V(0, -0.19, -0.05), (0.068, 0.02, 0.06), shade(snout, 0.92), seg=7, rings=3)
    for sx in (-1, 1):
        blob(h, H + V(sx * 0.024, -0.205, -0.05), (0.012, 0.006, 0.016), "8a6058", seg=5, rings=3, group="body_nh")
        tube(h, [H + V(sx * 0.055, -0.17, -0.08), H + V(sx * 0.07, -0.2, -0.03)], [0.013, 0.005], "f4ecd6", seg=4,
             end=0.5)
        ear(h, H + V(sx * 0.09, 0.04, 0.1), -0.25, sx * 0.45, 0.1, 0.08, mane, thick=0.45, inner="9a7a6a", tile=0.06)
    face(h, H, hr, (0.55, -0.68, 0.42), 0.02)
    grow(h, H, 1.1)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.12, -0.24, 0.3, 0.07, 0.042, coat, tile=0.09)
    t = Model("tail")
    T = V(0, 0.44, cz + 0.12)
    tube(t, [T, T + V(0, 0.06, -0.15)], [0.016, 0.011], coat, seg=5)
    blob(t, T + V(0, 0.065, -0.17), (0.024, 0.024, 0.038), mane, seg=6, rings=4)
    ps.add("tail", t, pivot=T)
    return ps


def curl_horn(h, H, sx, R0, R1, color, out=0.1, n=6, r0=0.05):
    """Ram's horn: spiral from the top of the head back, down and forward around the ear (ridged)."""
    c = H + V(sx * 0.11, 0.06, 0.0)
    pts = []
    for i in range(n):
        t = i / (n - 1)
        a = -0.2 + t * 4.6
        r = R0 + (R1 - R0) * t
        pts.append(c + V(sx * out * t, math.sin(a) * r, math.cos(a) * r))
    rad = [r0 - (r0 - 0.012) * i / (n - 1) for i in range(n)]
    tube(h, pts, rad, color, seg=5, end=0.6, det=(HORN, 0.06))


def wild_sheep():
    ps = PartSet("wild_sheep")
    coat, light = "ad6d42", "f0e4cd"
    cz = 0.58
    b = Model("body")
    body(b, (0, 0, cz), (0.19, 0.38, 0.2), coat, seg=12, rings=9, deform=shag(0.09, 0.14, 3.0, 2.0), cell=SHAGGY,
         tile=0.16, colfn=lambda f: light if f.normal.z < -0.45 or f.normal.y > 0.8 else coat)
    ps.add("body", b)
    N = V(0, -0.3, cz + 0.08)
    H = V(0, -0.42, cz + 0.33)
    h = Model("head")
    tube(h, [N, H + V(0, 0.04, -0.06)], [0.11, 0.085], coat, seg=7, det=(SHAGGY, 0.1))
    hr = (0.12, 0.14, 0.12)
    head(h, H, hr, coat, tile=0.08)
    blob(h, H + V(0, -0.12, -0.04), (0.068, 0.078, 0.062), light, seg=7, rings=4)
    blob(h, H + V(0, -0.19, -0.03), (0.026, 0.018, 0.02), NOSE, seg=5, rings=3)
    face(h, H, hr, (0.6, -0.62, 0.3), 0.02)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.1, 0.04, 0.02), 0.0, sx * 1.4, 0.09, 0.06, coat, inner="e8c8b0", tile=0.06)
        curl_horn(h, H, sx, 0.11, 0.055, "d2bf95")
    grow(h, H, 1.12)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.09, -0.25, 0.25, 0.06, 0.032, coat, tile=0.09)
    t = Model("tail")
    T = V(0, 0.38, cz + 0.1)
    blob(t, T + V(0, 0.03, -0.03), (0.036, 0.032, 0.062), coat, seg=5, rings=3, rot=(0.4, 0, 0))
    ps.add("tail", t, pivot=T)
    return ps


def aurochs():
    ps = PartSet("aurochs")
    coat, light, horn = "4f3e36", "d9ccb6", "efe4c8"
    cz, L, W, Hb = 1.12, 1.55, 0.72, 0.9
    b = Model("body")
    body(b, (0, 0.05, cz), (W / 2, L / 2, Hb / 2), coat, deform=bean(1.1, 0.95, 0.05), cell=HIDE, tile=0.35,
         colfn=under(coat, shade(coat, 1.18), -0.5))
    blob(b, (0, -0.38, cz + 0.22), (0.34, 0.42, 0.36), coat, seg=8, rings=5, axis="y", deform=shag(0.05, 0.0, 3, 1),
         det=(SHAGGY, 0.25, (0, 1, 0), (0, 0, 1)))                                          # shaggy shoulder hump
    ps.add("body", b)
    N = V(0, -0.62, cz + 0.2)
    H = V(0, -0.95, cz + 0.36)
    h = Model("head")
    tube(h, [N, H + V(0, 0.1, 0.0)], [0.28, 0.21], coat, seg=7, det=(SHAGGY, 0.22))
    hr = (0.23, 0.25, 0.23)
    head(h, H, hr, coat, cell=FUR, tile=0.16, seg=9)
    blob(h, H + V(0, -0.2, -0.09), (0.16, 0.12, 0.13), light, seg=7, rings=4)                # pale muzzle
    for sx in (-1, 1):
        blob(h, H + V(sx * 0.05, -0.31, -0.09), (0.018, 0.01, 0.022), NOSE, seg=4, rings=2, group="body_nh")
    face(h, H, hr, (0.62, -0.62, 0.32), 0.032)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.2, 0.02, 0.06), 0.15, sx * 1.6, 0.16, 0.12, coat, inner="8a6a5a", tile=0.1)
        a = H + V(sx * 0.13, 0.04, 0.15)
        pts = [a, a + V(sx * 0.2, 0.0, 0.05), a + V(sx * 0.34, -0.1, 0.2), a + V(sx * 0.35, -0.22, 0.37)]

        def hcol(f, a=a):
            return "3e3430" if (f.calc_center_median() - a).length > 0.42 else horn
        tube(h, pts, [0.07, 0.058, 0.04, 0.016], horn, seg=5, end=0.7, colfn=hcol, det=(HORN, 0.1))
    grow(h, H, 1.08)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.2, -0.48, 0.5, 0.15, 0.085, coat, foot_color="2f2622", tile=0.18, knee=0.06)
    t = Model("tail")
    T = V(0, 0.8, cz + 0.22)
    tube(t, [T, T + V(0, 0.1, -0.62)], [0.035, 0.025], coat, seg=6)
    blob(t, T + V(0, 0.1, -0.69), (0.05, 0.05, 0.09), "2f2622", seg=5, rings=3, det=(SHAGGY, 0.06, (0, 0, 1), (0, -1, 0)))
    ps.add("tail", t, pivot=T)
    return ps


# ───────────────────────── domestic ─────────────────────────
def dog(baby=False):
    ps = PartSet("puppy" if baby else "dog")
    coat, light, ear_c = "d6a160", "f8eedc", "a8703f"
    hk = 1.38 if baby else 1.15
    cz = 0.4 if not baby else 0.36
    b = Model("body")
    body(b, (0, 0, cz), (0.15, 0.3, 0.15), coat, deform=bean(1.1, 0.97), tile=0.12,
         colfn=lambda f: light if f.normal.z < -0.45 or f.normal.y < -0.8 else coat)
    ps.add("body", b)
    N = V(0, -0.22, cz + 0.06)
    H = N + V(0, -0.1, 0.22 if not baby else 0.2)
    h = Model("head")
    tube(h, [N, H + V(0, 0.04, -0.06)], [0.095, 0.08], coat, seg=7, det=(FUR, 0.1))
    hr = V(0.13, 0.125, 0.12) * hk
    head(h, H, hr, coat, tile=0.08)
    blob(h, H + V(0, -0.11, -0.045) * hk, V(0.065, 0.07, 0.05) * hk, light, seg=8, rings=5, axis="y")
    blob(h, H + V(0, -0.175, -0.022) * hk, V(0.032, 0.022, 0.024) * hk, NOSE, seg=5, rings=3)
    face(h, H, hr, (0.45, -0.78, 0.35), 0.022 * hk, blush=True)
    for sx in (-1, 1):                                                                   # soft floppy ears
        ear(h, H + V(sx * 0.1, 0.0, 0.07) * hk, 0.25, sx * 2.35, 0.14 * hk, 0.09 * hk, ear_c, thick=0.4, tile=0.07,
            cell=SHAGGY)
    grow(h, H, 1.0 if baby else 1.12)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.075, -0.18, 0.18, 0.05, 0.032, coat, foot="paw", foot_color=light, tile=0.08)
    t = Model("tail")
    T = V(0, 0.28, cz + 0.06)
    tube(t, [T, T + V(0, 0.07, 0.08), T + V(0, 0.06, 0.18)], [0.032, 0.032, 0.02], coat, seg=7, end=0.9,
         det=(FUR, 0.08))
    ps.add("tail", t, pivot=T)
    if baby:
        scale_parts(ps, 0.6)
    return ps


def pig():
    ps = PartSet("pig")
    coat, snout = "f2b5a6", "e4968b"
    cz = 0.34
    b = Model("body")
    body(b, (0, 0.02, cz + 0.04), (0.24, 0.37, 0.23), coat, deform=bean(1.03, 1.0, 0.08), cell=HIDE, tile=0.2)
    ps.add("body", b)
    N = V(0, -0.28, cz + 0.1)
    H = V(0, -0.39, cz + 0.13)
    h = Model("head")
    hr = (0.18, 0.15, 0.165)
    head(h, H, hr, coat, cell=HIDE, tile=0.14)
    tube(h, [H + V(0, -0.08, -0.03), H + V(0, -0.175, -0.03)], [0.075, 0.072], snout, seg=8)
    blob(h, H + V(0, -0.175, -0.03), (0.072, 0.018, 0.07), shade(snout, 0.95), seg=8, rings=4)
    for sx in (-1, 1):
        blob(h, H + V(sx * 0.026, -0.19, -0.03), (0.012, 0.006, 0.019), "a8655e", seg=5, rings=3, group="body_nh")
        ear(h, H + V(sx * 0.09, -0.02, 0.12), 0.95, sx * 0.45, 0.12, 0.11, coat, thick=0.35, inner=shade(coat, 0.93),
            cell=HIDE, tile=0.08)
    face(h, H, hr, (0.5, -0.72, 0.4), 0.022, blush=True)
    grow(h, H, 1.08)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.12, -0.22, 0.24, 0.062, 0.045, coat, foot_color="c47f74", cell=HIDE, tile=0.1)
    t = Model("tail")
    T = V(0, 0.38, cz + 0.12)
    pts = [T + V(0.04 * math.sin(a), 0.03 + 0.012 * a, 0.04 * math.cos(a) - 0.04) for a in (0.0, 1.2, 2.4, 3.6, 4.8, 6.0)]
    tube(t, [T] + pts, [0.018, 0.016, 0.015, 0.014, 0.013, 0.011, 0.009], coat, seg=5, end=0.8)
    ps.add("tail", t, pivot=T)
    return ps


def sheep():
    ps = PartSet("sheep")
    wool, face_c, leg = "f7f3ea", "efdfc5", "8b7466"
    cz = 0.5
    b = Model("body")
    body(b, (0, 0.02, cz + 0.06), (0.27, 0.36, 0.25), wool, seg=14, rings=10, deform=puffs(30, 0.2, 0.42), cell=WOOL,
         tile=0.13)
    ps.add("body", b)
    N = V(0, -0.3, cz + 0.12)
    H = V(0, -0.43, cz + 0.21)
    h = Model("head")
    hr = (0.12, 0.14, 0.125)
    head(h, H, hr, face_c, tile=0.08)
    blob(h, H + V(0, 0.01, 0.1), (0.11, 0.1, 0.07), wool, seg=9, rings=6, deform=puffs(9, 0.25, 0.7),
         det=(WOOL, 0.08, (0, 1, 0), (0, 0, 1)))                                             # woolly fringe
    blob(h, H + V(0, -0.13, -0.02), (0.024, 0.014, 0.019), "c48f84", seg=6, rings=4)
    face(h, H, hr, (0.6, -0.62, 0.25), 0.02, blush=True)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.105, 0.03, 0.03), 0.1, sx * 1.6, 0.1, 0.066, face_c, inner="f2c8bc", tile=0.06)
    grow(h, H, 1.15)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.11, -0.2, 0.22, 0.045, 0.036, leg, foot_color="5d4c44", cell=FINE, tile=0.08)
    t = Model("tail")
    T = V(0, 0.4, cz + 0.12)
    blob(t, T + V(0, 0.03, -0.02), (0.055, 0.05, 0.065), wool, seg=8, rings=5, deform=puffs(6, 0.2, 0.8),
         det=(WOOL, 0.08, (0, 1, 0), (0, 0, 1)))
    ps.add("tail", t, pivot=T)
    return ps


def cow():
    ps = PartSet("cow")
    coat, patch, muzzle, horn = "f6f1e8", "7a5442", "f0b4a8", "ece2c6"
    cz = 0.92

    b = Model("body")
    bc, br = V(0, 0.02, cz), (0.29 * 1.12, 0.6, 0.31 * 1.08)
    body(b, bc, (0.29, 0.6, 0.31), coat, seg=10, rings=8, deform=bean(1.05, 1.0, 0.06), cell=HIDE, tile=0.3)
    for d, rr in (((0.75, -0.35, 0.55), 0.15), ((-0.6, 0.35, 0.7), 0.17), ((0.55, 0.6, 0.5), 0.12),
                  ((-0.8, -0.45, 0.25), 0.11)):          # soft round patches on the hide
        n = snrm(br, d)
        blob(b, surf(bc, br, d) - n * 0.016, (rr, rr * 0.85, 0.035), patch, seg=6, rings=3,
             rot=n.to_track_quat("Z", "Y").to_euler(), group="body_nh", det=(HIDE, 0.2, (0, 0, 1), (0, 1, 0)))
    ps.add("body", b)
    N = V(0, -0.48, cz + 0.12)
    H = V(0, -0.72, cz + 0.25)
    h = Model("head")
    tube(h, [N, H + V(0, 0.08, -0.02)], [0.19, 0.15], coat, seg=8, det=(HIDE, 0.2))
    hr = (0.18, 0.19, 0.17)
    head(h, H, hr, coat, colfn=lambda f: patch if f.normal.x > 0.5 and f.normal.z > 0.05 else coat, cell=HIDE,
         tile=0.16, seg=9)                                                                         # one brown eye patch
    blob(h, H + V(0, -0.16, -0.075), (0.14, 0.1, 0.105), muzzle, seg=7, rings=4)
    for sx in (-1, 1):
        blob(h, H + V(sx * 0.045, -0.255, -0.07), (0.018, 0.01, 0.022), "b0706a", seg=4, rings=2, group="body_nh")
    face(h, H, hr, (0.6, -0.64, 0.32), 0.027, blush=True)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.16, 0.03, 0.06), 0.15, sx * 1.6, 0.14, 0.1, coat, inner="f2c4b8", cell=HIDE, tile=0.1)
        a = H + V(sx * 0.09, 0.03, 0.13)
        tube(h, [a, a + V(sx * 0.07, 0.0, 0.04), a + V(sx * 0.1, -0.02, 0.1)], [0.032, 0.025, 0.014], horn, seg=4,
             end=0.8, det=(HORN, 0.05))
    grow(h, H, 1.1)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.16, -0.38, 0.4, 0.1, 0.065, coat, foot_color="6b5246", cell=HIDE, tile=0.16)
    t = Model("tail")
    T = V(0, 0.6, cz + 0.16)
    tube(t, [T, T + V(0, 0.08, -0.48)], [0.025, 0.018], coat, seg=5)
    blob(t, T + V(0, 0.08, -0.54), (0.042, 0.042, 0.075), patch, seg=6, rings=4, det=(SHAGGY, 0.05, (0, 0, 1), (0, -1, 0)))
    ps.add("tail", t, pivot=T)
    return ps


def chicken():
    ps = PartSet("chicken")
    white, wing, red, yellow = "fbf6ea", "efe4cf", "e05a45", "f2b440"
    b = Model("body")

    def egg(p, n):                     # plump breast, tapering up to the tail
        k = 1 + 0.12 * max(0.0, -n.y) - 0.12 * max(0.0, n.y) * max(0.0, -n.z + 0.3)
        return Vector((p.x * k, p.y, p.z * k))
    blob(b, (0, 0.0, 0.3), (0.145, 0.18, 0.145), white, seg=12, rings=8, rot=(-0.25, 0, 0), axis="y", deform=egg,
         det=(FEATHER, 0.08, (0, 1, 0), (0, 0, 1)))
    ps.add("body", b)
    N = V(0, -0.1, 0.38)
    H = V(0, -0.14, 0.51)
    h = Model("head")
    tube(h, [N, H + V(0, 0.01, -0.03)], [0.075, 0.062], white, seg=7, det=(FEATHER, 0.06))
    hr = (0.085, 0.085, 0.09)
    head(h, H, hr, white, cell=FEATHER, tile=0.05)
    tube(h, [H + V(0, -0.06, -0.01), H + V(0, -0.115, -0.02)], [0.026, 0.006], yellow, seg=6)           # beak
    for k in range(3):                                                                    # comb
        blob(h, H + V(0, -0.04 + k * 0.035, 0.088 - abs(k - 1) * 0.012), (0.016, 0.022, 0.032), red, seg=6, rings=4)
    blob(h, H + V(0, -0.08, -0.055), (0.016, 0.014, 0.026), red, seg=6, rings=4)            # wattle
    face(h, H, hr, (0.72, -0.5, 0.28), 0.016, blush=True)
    grow(h, H, 1.1)
    ps.add("head", h, pivot=N)

    def scallop(p, n):                 # soft feather-tip scallops along the wing's lower / back edge
        if n.z < 0.2:
            p = Vector((p.x, p.y, p.z - 0.012 * (0.5 + 0.5 * math.cos(n.y * 14))))
        return p
    for nm, sx in (("wing_l", 1), ("wing_r", -1)):
        m = Model(nm)
        sh = V(sx * 0.12, -0.06, 0.34)
        blob(m, sh + V(sx * 0.018, 0.08, -0.03), (0.036, 0.115, 0.078), wing, seg=9, rings=6, rot=(-0.35, 0, 0),
             axis="y", deform=scallop, det=(FEATHER, 0.06, (0, 1, 0), (0, 0, 1)))
        ps.add(nm, m, pivot=sh)
    for nm, sx in (("leg_l", 1), ("leg_r", -1)):
        m = Model(nm)
        hip = V(sx * 0.055, 0.01, 0.18)
        tube(m, [hip, V(hip.x, hip.y, 0.015)], [0.016, 0.013], yellow, seg=5)
        for a in (-0.5, 0.0, 0.5):                                                        # three toes
            tube(m, [V(hip.x, hip.y, 0.012), V(hip.x + math.sin(a) * 0.045, hip.y - math.cos(a) * 0.045, 0.008)],
                 [0.009, 0.007], yellow, seg=3)
        ps.add(nm, m, pivot=hip)
    t = Model("tail")
    T = V(0, 0.15, 0.34)
    for k, ry in enumerate((-0.35, 0.0, 0.35)):                                          # rounded tail feathers
        ln = 0.13 - abs(k - 1) * 0.02
        d = Euler((-0.55, ry, 0), "XYZ").to_matrix() @ Vector((0, 0, 1))
        blob(t, T + V(ry * 0.08, 0, -0.02) + d * ln * 0.5, (0.035, 0.014, ln * 0.55), wing, seg=6, rings=3,
             rot=(-0.55, ry, 0), det=(FEATHER, 0.05, (0, 0, 1), (0, -1, 0)))
    ps.add("tail", t, pivot=T)
    return ps


def donkey():
    ps = PartSet("donkey")
    coat, light, dark = "a39d96", "efe9df", "514a46"
    cz, L, W, Hb = 0.76, 0.92, 0.4, 0.44
    b = Model("body")
    body(b, (0, 0, cz), (W / 2, L / 2, Hb / 2), coat, deform=bean(1.06, 1.0, 0.06), tile=0.17,
         colfn=under(coat, light, -0.5))
    ps.add("body", b)
    N = V(0, -0.33, cz + 0.12)
    H = V(0, -0.5, cz + 0.5)
    h = Model("head")
    tube(h, [N, H + V(0, 0.06, -0.06)], [0.13, 0.095], coat, seg=7, det=(FUR, 0.12))
    blob(h, N + V(0, 0.07, 0.24), (0.035, 0.1, 0.2), dark, seg=6, rings=4, rot=(0.35, 0, 0), deform=shag(0.15, 0, 6, 3),
         det=(SHAGGY, 0.06, (0, 0, 1), (0, 1, 0)))                                           # short upright mane
    hr = (0.14, 0.17, 0.135)
    head(h, H, hr, coat, tile=0.1)
    blob(h, H + V(0, -0.165, -0.06), (0.105, 0.11, 0.095), light, seg=8, rings=5)           # pale muzzle
    for sx in (-1, 1):
        blob(h, H + V(sx * 0.04, -0.265, -0.05), (0.016, 0.01, 0.014), NOSE, seg=5, rings=3, group="body_nh")
    face(h, H, hr, (0.6, -0.62, 0.35), 0.025, blush=True)
    for sx in (-1, 1):                                                                       # long ears, dark tips
        a = H + V(sx * 0.07, 0.05, 0.1)
        ear(h, a, -0.25, sx * 0.3, 0.28, 0.095, coat, inner="e8d8cc", tile=0.08)
        blob(h, a + Euler((-0.25, sx * 0.3, 0), "XYZ").to_matrix() @ V(0, 0.0, 0.25), (0.03, 0.016, 0.04), dark,
             seg=5, rings=3, rot=(-0.25, sx * 0.3, 0))
    grow(h, H, 1.1)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.11, -0.3, 0.3, 0.075, 0.042, coat, foot_color="3f3936", tile=0.12, knee=0.04)
    t = Model("tail")
    T = V(0, 0.45, cz + 0.12)
    tube(t, [T, T + V(0, 0.06, -0.15), T + V(0, 0.07, -0.33)], [0.02, 0.018, 0.015], coat, seg=5)
    blob(t, T + V(0, 0.07, -0.38), (0.034, 0.034, 0.065), dark, seg=6, rings=4, det=(SHAGGY, 0.05, (0, 0, 1), (0, -1, 0)))
    ps.add("tail", t, pivot=T)
    return ps


SPECIES = [
    ("fish_a", "wild", lambda: fish("fish_a", "5f8ea0", "a3c3cc", "eef3f2", "7ea6b4")),
    ("fish_b", "wild", lambda: fish("fish_b", "d27a35", "eea050", "f8dca0", "e88a3c")),
    ("deer", "wild", deer), ("fawn", "wild", lambda: deer(True)), ("rabbit", "wild", rabbit), ("wolf", "wild", wolf),
    ("boar", "wild", boar), ("wild_sheep", "wild", wild_sheep), ("aurochs", "wild", aurochs),
    ("dog", "domestic", dog), ("puppy", "domestic", lambda: dog(True)), ("pig", "domestic", pig), ("sheep", "domestic", sheep),
    ("cow", "domestic", cow), ("chicken", "domestic", chicken), ("donkey", "domestic", donkey),
]


def build():
    os.makedirs(OUT, exist_ok=True)
    manifest = {}
    for key, kind, fn in SPECIES:
        ps = fn()
        top = 0.0
        for _, model, _ in ps.parts:
            for bm in model.groups.values():
                top = max(top, max(v.co.z for v in bm.verts))
        tris = ps.export(OUT)
        print("    " + " ".join("%s=%d" % kv for kv in tris.items()))
        manifest[key] = {"kind": kind, "parts": list(dict.fromkeys(p[0] for p in ps.parts)), "tris": sum(tris.values()),
                         "top": round(top, 3)}
    with open(os.path.join(OUT, "animals.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
        f.write("\n")
    print("  -- animal triangles (budget 400-900, fish <= 120) --")
    for key, d in manifest.items():
        print("  %-12s %4d tris  top %.2f" % (key, d["tris"], d["top"]))


if __name__ == "__main__":
    print("animals ->", OUT)
    build()
