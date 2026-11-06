"""Animal part kit (ROADMAP B3, docs/WILDLIFE.md 1 · 7): soft rounded low-poly storybook animals, flat cel colours.
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
Budget: 150-400 tris per animal (fish <= 60). Colours are fixed vertex colours (shared toon material, no textures).
Run: blender -b --factory-startup --python build_animals.py -- [out_dir]
"""
import json
import math
import os
import sys

import bmesh
from mathutils import Euler, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, PartSet, Vector, shade, out_dir_from_argv  # noqa: E402

OUT = os.path.join(out_dir_from_argv(), "animals")

EYE = "2a2324"
NOSE = "3e302b"
HOOF = "5a4438"
CREAM = "f3e8d4"
PINK = "eaa79b"


def V(*a):
    return Vector(a)


def ell(m, c, r3, color, seg=8, rings=5, rot=(0, 0, 0), colfn=None, smooth=True, group="body"):
    """Ellipsoid (UV sphere) of radii r3 centred at c. Triangles = seg * (2 * rings - 2)."""
    return m.sphere(1.0, pos=tuple(c), scl=tuple(r3), rot=rot, color=color, seg=seg, rings=rings, colfn=colfn,
                    smooth=smooth, group=group)


def surf(c, r3, d):
    """Point on the (unrotated) ellipsoid surface in direction d."""
    d = Vector(d).normalized()
    return Vector(c) + Vector((d.x * r3[0], d.y * r3[1], d.z * r3[2]))


def tube(m, pts, radii, color, seg=5, colfn=None, smooth=True, group="body"):
    """Capped tube along a polyline (horns, tails, necks). Triangles = (len(pts) - 1) * 2 * seg + 2 * (seg - 2)."""
    pts = [Vector(p) for p in pts]
    rings = []
    u_prev = None
    for i, p in enumerate(pts):
        t = (pts[1] - pts[0]) if i == 0 else (pts[-1] - pts[-2]) if i == len(pts) - 1 else (pts[i + 1] - pts[i - 1])
        t.normalize()
        if u_prev is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            u = t.cross(ref).normalized()
        else:
            u = (u_prev - t * u_prev.dot(t)).normalized()
        v = t.cross(u)
        u_prev = u
        rings.append([p + (u * math.cos(k / seg * 2 * math.pi) + v * math.sin(k / seg * 2 * math.pi)) * radii[i]
                      for k in range(seg)])
    return m.strip(rings, color=color, smooth=smooth, close=True, colfn=colfn, caps=True, group=group)


def bumpy(m, c, r3, color, seg=10, rings=6, amt=0.12, colfn=None):
    """Ellipsoid with every other vertex pushed out (checkerboard) -> fluffy fleece / shaggy coat at no extra tris."""
    faces = ell(m, c, r3, color, seg=seg, rings=rings, colfn=colfn)
    c = Vector(c)
    vs = {}
    for f in faces:
        for v in f.verts:
            vs[v] = True
    for v in vs:
        d = v.co - c
        lx, ly, lz = d.x / r3[0], d.y / r3[1], d.z / r3[2]
        n = math.sqrt(lx * lx + ly * ly + lz * lz)
        if n < 1e-6:
            continue
        lat = round(math.acos(max(-1.0, min(1.0, lz / n))) / (math.pi / rings))
        lon = round((math.atan2(ly, lx) % (2 * math.pi)) / (2 * math.pi / seg))
        if 0 < lat < rings and (lat + lon) % 2 == 0:
            v.co = c + d * (1.0 + amt)
    m._bm("body").normal_update()
    return faces


def ear(m, base, rx, ry, length, width, color, thick=0.38, seg=4, colfn=None):
    """Soft leaf-shaped ear: a flattened ellipsoid from base along its length (flat side faces the front at rest).
    rx < 0 leans back, ry > 0 leans to +X."""
    d = Euler((rx, ry, 0), "XYZ").to_matrix() @ Vector((0, 0, 1))
    return ell(m, Vector(base) + d * length * 0.45, (width / 2, width / 2 * thick, length / 2), color, seg=seg, rings=3,
               rot=(rx, ry, 0), colfn=colfn)


def eyes(m, c, r3, d, er, color=EYE):
    for sx in (-1, 1):
        p = surf(c, r3, (d[0] * sx, d[1], d[2]))
        ell(m, p, (er, er * 0.8, er * 1.12), color, seg=4, rings=2)


def under(top, low, k=-0.35):
    """colfn: downward faces get the belly colour."""
    return lambda f: low if f.normal.z < k else top


def dtri(m, pts, color, group="body_nh"):
    """Double-sided triangle / quad (fins)."""
    m.poly(pts, color=color, group=group)
    m.poly(list(reversed(pts)), color=color, group=group)


def legs4(ps, cz, x, yf, yb, r_top, r_bot, color, foot="hoof", foot_color=HOOF, seg=5, front_color=None):
    """Four legs, pivot at the hip (z = cz, hidden in the body). foot: hoof (short dark cylinder) or paw (soft blob)."""
    r_top, r_bot = r_top * 1.15, r_bot * 1.25          # a bit chunkier than life: reads at phone size, looks softer
    for nm, sx, sy in (("leg_fl", 1, yf), ("leg_fr", -1, yf), ("leg_bl", 1, yb), ("leg_br", -1, yb)):
        hip = V(sx * x, sy, cz)
        m = Model(nm)
        col = front_color if (front_color and sy < 0) else color
        if foot == "hoof":                    # one tube: hoof ring at the bottom, then the leg
            fh = min(0.09, cz * 0.14)
            tube(m, [V(hip.x, hip.y, 0), V(hip.x, hip.y, fh), hip], [r_bot * 1.1, r_bot, r_top], col, seg=seg,
                 colfn=lambda f, fh=fh, fc=foot_color, c=col: fc if f.calc_center_median().z < fh else c)
        else:
            tube(m, [V(hip.x, hip.y, r_bot * 0.6), hip], [r_bot, r_top], col, seg=seg)
            ell(m, (hip.x, hip.y - r_bot * 0.45, r_bot * 0.62), (r_bot * 1.18, r_bot * 1.55, r_bot * 0.68),
                foot_color or col, seg=4, rings=2)
        ps.add(nm, m, pivot=hip)


def scale_parts(ps, k):
    for _, model, pivot in ps.parts:
        for bm in model.groups.values():
            bmesh.ops.scale(bm, vec=(k, k, k), verts=bm.verts)
        pivot *= k


# ───────────────────────── wild ─────────────────────────
def fish(key, back, side, belly, fin):
    ps = PartSet(key)
    m = Model("body")
    r3 = (0.05, 0.16, 0.072)
    ell(m, (0, 0, 0), r3, side, seg=6, rings=4,
        colfn=lambda f: back if f.normal.z > 0.45 else belly if f.normal.z < -0.45 else side)        # 36
    for sx in (-1, 1):                                                                                   # eyes: 2 x 2
        p = surf((0, 0, 0), r3, (sx * 0.6, -0.75, 0.25)) + V(sx * 0.004, 0, 0)
        e = 0.014
        q = [(p.x, p.y - e, p.z - e), (p.x, p.y + e, p.z - e), (p.x, p.y + e, p.z + e), (p.x, p.y - e, p.z + e)]
        m.poly(q if sx > 0 else list(reversed(q)), color=EYE)
    dtri(m, [(0, -0.04, 0.06), (0, 0.06, 0.06), (0, 0.1, 0.11)], fin)                                 # dorsal: 2
    ps.add("body", m)
    t = Model("tail")
    dtri(t, [(0, 0.13, 0), (0, 0.25, 0.08), (0, 0.22, 0), (0, 0.25, -0.08)], fin)                      # 4
    ps.add("tail", t, pivot=(0, 0.14, 0))
    return ps


def deer(baby=False):
    ps = PartSet("fawn" if baby else "deer")
    coat = "c98a55" if baby else "b77a4a"
    hk = 1.28 if baby else 1.0
    cz, L, W, Hb = 0.8, 0.9, 0.4, 0.44
    b = Model("body")
    ell(b, (0, 0, cz), (W / 2, L / 2, Hb / 2), coat,
        colfn=lambda f: CREAM if f.normal.z < -0.35 or f.normal.y > 0.75 else coat)          # pale belly + rump
    if baby:                                                                                  # fawn spots
        for x, y in ((0.07, -0.18), (-0.07, -0.1), (0.06, 0.03), (-0.07, 0.12), (0.04, 0.22)):
            p = surf((0, 0, cz), (W / 2, L / 2, Hb / 2), (x / (W / 2), y / (L / 2), 0.75))
            ell(b, p, (0.035, 0.035, 0.012), "f8eedb", seg=4, rings=2)
    ps.add("body", b)
    N = V(0, -0.3, cz + 0.1)
    H = N + V(0, -0.12, 0.42 if not baby else 0.36)
    h = Model("head")
    tube(h, [N, H + V(0, 0.03, -0.06)], [0.11, 0.08], coat, seg=6)
    hr = (0.15 * hk, 0.17 * hk, 0.14 * hk)
    ell(h, H, hr, rings=4, color=coat)
    ell(h, H + V(0, -0.15, -0.05) * hk, V(0.075, 0.1, 0.07) * hk, CREAM, seg=6, rings=3)
    ell(h, H + V(0, -0.245, -0.03) * hk, V(0.035, 0.025, 0.028) * hk, NOSE, seg=4, rings=2)
    eyes(h, H, hr, (0.7, -0.55, 0.3), 0.032 * hk)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.1, 0.05, 0.08) * hk, -0.35, sx * 1.05, 0.2 * hk, 0.11 * hk, coat,
            colfn=lambda f: "f2d6c2" if f.normal.y < -0.6 else coat)
        if not baby:                                                                          # small, friendly antlers
            a = H + V(sx * 0.06, 0.03, 0.12)
            tube(h, [a, a + V(sx * 0.05, 0.03, 0.12), a + V(sx * 0.11, 0.07, 0.22)], [0.022, 0.018, 0.01], "e6d2a8", seg=4)
            m_ = a + V(sx * 0.04, 0.025, 0.1)
            tube(h, [m_, m_ + V(0, -0.06, 0.08)], [0.015, 0.008], "e6d2a8", seg=4)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.11, -0.3, 0.3, 0.07, 0.042, coat)
    t = Model("tail")
    T = V(0, 0.44, cz + 0.12)
    ell(t, T + V(0, 0.03, -0.03), (0.045, 0.04, 0.075), coat, seg=5, rings=2, rot=(0.5, 0, 0),
        colfn=lambda f: CREAM if f.normal.y > 0.3 else coat)
    ps.add("tail", t, pivot=T)
    if baby:
        scale_parts(ps, 0.62)
    return ps


def rabbit():
    ps = PartSet("rabbit")
    coat, light, inner = "c2a07f", "f8f2e8", "eeb2a6"
    b = Model("body")
    ell(b, (0, 0.03, 0.15), (0.11, 0.15, 0.12), coat, rot=(-0.25, 0, 0), colfn=under(coat, light, -0.5))
    ps.add("body", b)
    N = V(0, -0.09, 0.22)
    H = V(0, -0.15, 0.29)
    h = Model("head")
    hr = (0.1, 0.1, 0.09)
    ell(h, H, hr, rings=4, color=coat, colfn=under(coat, light, -0.6))
    ell(h, H + V(0, -0.08, -0.03), (0.05, 0.04, 0.04), light, seg=6, rings=3)
    ell(h, H + V(0, -0.115, -0.01), (0.016, 0.01, 0.012), "d98a80", seg=4, rings=2)
    eyes(h, H, hr, (0.75, -0.45, 0.3), 0.022)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.04, 0.03, 0.06), -0.25, sx * 0.22, 0.2, 0.065, coat, thick=0.35,
            colfn=lambda f: inner if f.normal.y < -0.5 else coat)
    ps.add("head", h, pivot=N)
    for nm, sx in (("leg_fl", 1), ("leg_fr", -1)):
        m = Model(nm)
        hip = V(sx * 0.05, -0.08, 0.12)
        m.cyl(0.018, 0.022, 0.11, pos=(hip.x, hip.y, 0.015), color=coat, seg=4, smooth=True)
        ell(m, (hip.x, hip.y - 0.012, 0.016), (0.022, 0.032, 0.016), light, seg=5, rings=2)
        ps.add(nm, m, pivot=hip)
    for nm, sx in (("leg_bl", 1), ("leg_br", -1)):                                        # haunch + long foot
        m = Model(nm)
        hip = V(sx * 0.075, 0.07, 0.14)
        ell(m, (hip.x * 1.05, hip.y, 0.1), (0.045, 0.085, 0.075), coat, seg=6, rings=4)
        ell(m, (hip.x * 1.05, hip.y - 0.04, 0.018), (0.032, 0.075, 0.018), light, seg=5, rings=2)
        ps.add(nm, m, pivot=hip)
    t = Model("tail")
    T = V(0, 0.17, 0.17)
    ell(t, T + V(0, 0.015, 0), (0.042, 0.04, 0.042), light, seg=6, rings=3)
    ps.add("tail", t, pivot=T)
    return ps


def wolf():
    ps = PartSet("wolf")
    coat, light, dark = "9aa0a2", "eee6d8", "767c80"
    cz, L, W, Hb = 0.6, 0.86, 0.34, 0.36
    b = Model("body")
    ell(b, (0, 0, cz), (W / 2, L / 2, Hb / 2), coat, colfn=lambda f: light if f.normal.z < -0.4 else dark if f.normal.z > 0.8 else coat)
    ell(b, (0, -0.3, cz + 0.02), (0.17, 0.13, 0.19), light, seg=6, rings=3)                 # soft chest ruff
    ps.add("body", b)
    N = V(0, -0.32, cz + 0.1)
    H = V(0, -0.45, cz + 0.33)
    h = Model("head")
    tube(h, [N, H + V(0, 0.05, -0.05)], [0.13, 0.11], coat, seg=6)
    hr = (0.15, 0.14, 0.13)
    ell(h, H, hr, rings=4, color=coat, colfn=lambda f: light if f.normal.z < -0.25 else coat)             # pale cheeks
    ell(h, H + V(0, -0.14, -0.045), (0.06, 0.1, 0.055), light, seg=6, rings=4)
    ell(h, H + V(0, -0.235, -0.025), (0.03, 0.022, 0.024), NOSE, seg=5, rings=2)
    eyes(h, H, hr, (0.55, -0.72, 0.38), 0.026)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.08, 0.03, 0.08), -0.12, sx * 0.32, 0.13, 0.095, coat, thick=0.42,
            colfn=lambda f: light if f.normal.y < -0.6 else coat)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.095, -0.28, 0.28, 0.058, 0.04, coat, foot="paw", foot_color=light)
    t = Model("tail")
    T = V(0, 0.4, cz + 0.08)
    tube(t, [T, T + V(0, 0.1, -0.06), T + V(0, 0.18, -0.2), T + V(0, 0.2, -0.3)], [0.045, 0.07, 0.06, 0.02], coat, seg=6,
         colfn=lambda f: light if f.calc_center_median().z < T.z - 0.24 else coat)
    ps.add("tail", t, pivot=T)
    return ps


def boar():
    ps = PartSet("boar")
    coat, mane, snout = "7b6150", "54423a", "c09a88"
    cz = 0.42
    b = Model("body")
    ell(b, (0, 0.05, cz + 0.02), (0.21, 0.4, 0.21), coat, colfn=under(coat, shade(coat, 1.15)))
    ell(b, (0, -0.16, cz + 0.08), (0.22, 0.24, 0.24), coat, seg=6, rings=4)                 # strong shoulders
    for k in range(3):                                                                      # bristly mane ridge
        y = -0.24 + k * 0.14
        z = cz + 0.3 - k * 0.025
        b.cyl(0.035, 0.006, 0.06, pos=(0, y, z - 0.03), rot=(-0.5, 0, 0), color=mane, seg=4, smooth=True)
    ps.add("body", b)
    N = V(0, -0.33, cz + 0.08)
    H = V(0, -0.45, cz + 0.04)
    h = Model("head")
    hr = (0.15, 0.17, 0.15)
    ell(h, H, hr, rings=4, color=coat)
    h.cyl(0.065, 0.06, 0.09, pos=tuple(H + V(0, -0.13, -0.04)), rot=(math.pi / 2, 0, 0), color=snout, seg=6,
          cap=shade(snout, 0.85), smooth=True)
    for sx in (-1, 1):
        h.cyl(0.014, 0.003, 0.055, pos=tuple(H + V(sx * 0.055, -0.19, -0.07)), rot=(-0.35, sx * 0.35, 0), color="f4ecd6", seg=3)
        ear(h, H + V(sx * 0.08, 0.04, 0.1), -0.25, sx * 0.4, 0.09, 0.07, mane, thick=0.45)
    eyes(h, H, hr, (0.62, -0.62, 0.42), 0.022)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.12, -0.24, 0.3, 0.06, 0.042, coat)
    t = Model("tail")
    T = V(0, 0.43, cz + 0.12)
    tube(t, [T, T + V(0, 0.06, -0.15)], [0.016, 0.01], coat, seg=4)
    ell(t, T + V(0, 0.065, -0.17), (0.022, 0.022, 0.035), mane, seg=4, rings=2)
    ps.add("tail", t, pivot=T)
    return ps


def curl_horn(h, H, sx, R0, R1, color, seg=4, out=0.1):
    """Ram's horn: spiral from the top of the head back, down and forward around the ear."""
    c = H + V(sx * 0.11, 0.06, 0.0)
    pts = []
    n = 5
    for i in range(n):
        t = i / (n - 1)
        a = -0.2 + t * 4.4                      # 0 = top, + = backwards, then down and to the front
        r = R0 + (R1 - R0) * t
        pts.append(c + V(sx * out * t, math.sin(a) * r, math.cos(a) * r))
    rad = [0.05 - 0.035 * i / (n - 1) for i in range(n)]
    tube(h, pts, rad, color, seg=seg, colfn=lambda f: color if int(f.calc_center_median().y * 60) % 2 else shade(color, 0.9))


def wild_sheep():
    ps = PartSet("wild_sheep")
    coat, light = "ad6d42", "f0e4cd"
    cz = 0.58
    b = Model("body")
    bumpy(b, (0, 0, cz), (0.18, 0.38, 0.19), coat, seg=8, rings=5, amt=0.07,
          colfn=lambda f: light if f.normal.z < -0.4 or f.normal.y > 0.75 else coat)
    ps.add("body", b)
    N = V(0, -0.3, cz + 0.08)
    H = V(0, -0.42, cz + 0.33)
    h = Model("head")
    tube(h, [N, H + V(0, 0.04, -0.06)], [0.1, 0.08], coat, seg=6)
    hr = (0.11, 0.14, 0.11)
    ell(h, H, hr, rings=4, color=coat)
    ell(h, H + V(0, -0.12, -0.04), (0.065, 0.075, 0.06), light, seg=6, rings=3)
    ell(h, H + V(0, -0.19, -0.03), (0.025, 0.018, 0.02), NOSE, seg=4, rings=2)
    eyes(h, H, hr, (0.72, -0.5, 0.32), 0.022)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.1, 0.04, 0.02), 0.0, sx * 1.4, 0.09, 0.06, coat, seg=4)
        curl_horn(h, H, sx, 0.11, 0.06, "d2bf95")
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.09, -0.26, 0.26, 0.05, 0.034, coat, seg=4, front_color=None)
    t = Model("tail")
    T = V(0, 0.38, cz + 0.1)
    ell(t, T + V(0, 0.03, -0.03), (0.035, 0.03, 0.06), coat, seg=4, rings=2, rot=(0.4, 0, 0))
    ps.add("tail", t, pivot=T)
    return ps


def aurochs():
    ps = PartSet("aurochs")
    coat, light, horn = "4f3e36", "d9ccb6", "efe4c8"
    cz, L, W, Hb = 1.12, 1.55, 0.72, 0.9
    b = Model("body")
    ell(b, (0, 0.05, cz), (W / 2, L / 2, Hb / 2), coat, seg=8, rings=5, colfn=under(coat, shade(coat, 1.18), -0.5))
    ell(b, (0, -0.38, cz + 0.2), (0.34, 0.42, 0.36), coat, seg=6, rings=3)                  # shoulder hump
    ps.add("body", b)
    N = V(0, -0.62, cz + 0.2)
    H = V(0, -0.95, cz + 0.36)
    h = Model("head")
    tube(h, [N, H + V(0, 0.1, 0.0)], [0.27, 0.2], coat, seg=5)
    hr = (0.22, 0.24, 0.22)
    ell(h, H, hr, seg=7, rings=4, color=coat)
    ell(h, H + V(0, -0.2, -0.09), (0.15, 0.11, 0.12), light, seg=6, rings=3)               # pale muzzle
    eyes(h, H, hr, (0.72, -0.52, 0.32), 0.034)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.2, 0.02, 0.06), 0.15, sx * 1.6, 0.16, 0.12, coat)
        a = H + V(sx * 0.13, 0.04, 0.15)
        pts = [a, a + V(sx * 0.2, 0.0, 0.05), a + V(sx * 0.36, -0.1, 0.2), a + V(sx * 0.36, -0.22, 0.38)]

        def hcol(f, a=a):
            return "3e3430" if (f.calc_center_median() - a).length > 0.4 else horn
        tube(h, pts, [0.07, 0.058, 0.04, 0.012], horn, seg=4, colfn=hcol)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.2, -0.48, 0.5, 0.13, 0.085, coat, foot_color="2f2622")
    t = Model("tail")
    T = V(0, 0.8, cz + 0.22)
    tube(t, [T, T + V(0, 0.1, -0.62)], [0.035, 0.025], coat, seg=4)
    ell(t, T + V(0, 0.1, -0.69), (0.05, 0.05, 0.09), "2f2622", seg=4, rings=2)
    ps.add("tail", t, pivot=T)
    return ps


# ───────────────────────── domestic ─────────────────────────
def dog(baby=False):
    ps = PartSet("puppy" if baby else "dog")
    coat, light, ear_c = "d6a160", "f8eedc", "a8703f"
    hk = 1.3 if baby else 1.0
    cz = 0.4 if not baby else 0.36
    b = Model("body")
    ell(b, (0, 0, cz), (0.14, 0.3, 0.14), coat, colfn=lambda f: light if f.normal.z < -0.4 or f.normal.y < -0.75 else coat)
    ps.add("body", b)
    N = V(0, -0.22, cz + 0.06)
    H = N + V(0, -0.1, 0.22 if not baby else 0.2)
    h = Model("head")
    tube(h, [N, H + V(0, 0.04, -0.06)], [0.09, 0.075], coat, seg=6)
    hr = V(0.13, 0.13, 0.12) * hk
    ell(h, H, hr, rings=4, color=coat)
    ell(h, H + V(0, -0.115, -0.04) * hk, V(0.06, 0.07, 0.05) * hk, light, seg=6, rings=4)
    ell(h, H + V(0, -0.185, -0.02) * hk, V(0.03, 0.02, 0.022) * hk, NOSE, seg=5, rings=2)
    eyes(h, H, hr, (0.5, -0.75, 0.35), 0.026 * hk)
    for sx in (-1, 1):                                                                   # soft floppy ears
        ear(h, H + V(sx * 0.1, 0.0, 0.07) * hk, 0.25, sx * 2.35, 0.13 * hk, 0.085 * hk, ear_c, thick=0.4)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.075, -0.19, 0.19, 0.045, 0.035, coat, foot="paw", foot_color=light)
    t = Model("tail")
    T = V(0, 0.28, cz + 0.06)
    tube(t, [T, T + V(0, 0.07, 0.08), T + V(0, 0.06, 0.18)], [0.032, 0.03, 0.012], coat)
    ps.add("tail", t, pivot=T)
    if baby:
        scale_parts(ps, 0.6)
    return ps


def pig():
    ps = PartSet("pig")
    coat, snout = "f2b5a6", "e4968b"
    cz = 0.34
    b = Model("body")
    ell(b, (0, 0.02, cz + 0.04), (0.23, 0.36, 0.22), coat, seg=9, rings=5)
    ps.add("body", b)
    N = V(0, -0.28, cz + 0.1)
    H = V(0, -0.38, cz + 0.12)
    h = Model("head")
    hr = (0.17, 0.15, 0.16)
    ell(h, H, hr, rings=4, color=coat)
    h.cyl(0.07, 0.068, 0.07, pos=tuple(H + V(0, -0.12, -0.03)), rot=(math.pi / 2, 0, 0), color=snout, seg=6,
          cap=shade(snout, 0.95), smooth=True)
    for sx in (-1, 1):
        ell(h, H + V(sx * 0.025, -0.193, -0.03), (0.012, 0.006, 0.018), "a8655e", seg=4, rings=2)
        ear(h, H + V(sx * 0.09, -0.02, 0.12), 0.95, sx * 0.45, 0.11, 0.1, coat, thick=0.35)
    eyes(h, H, hr, (0.55, -0.7, 0.42), 0.024)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.12, -0.22, 0.24, 0.055, 0.045, coat, foot_color="c47f74")
    t = Model("tail")
    T = V(0, 0.37, cz + 0.12)
    pts = [T + V(0.04 * math.sin(a), 0.03 + 0.012 * a, 0.04 * math.cos(a) - 0.04) for a in (0.0, 1.6, 3.2, 4.8, 6.0)]
    tube(t, [T] + pts, [0.018, 0.016, 0.015, 0.013, 0.011, 0.008], coat, seg=4)
    ps.add("tail", t, pivot=T)
    return ps


def sheep():
    ps = PartSet("sheep")
    wool, face, leg = "f7f3ea", "efdfc5", "8b7466"
    cz = 0.5
    b = Model("body")
    bumpy(b, (0, 0.02, cz + 0.06), (0.27, 0.36, 0.25), wool, seg=10, rings=6, amt=0.13)
    ps.add("body", b)
    N = V(0, -0.3, cz + 0.12)
    H = V(0, -0.43, cz + 0.2)
    h = Model("head")
    hr = (0.11, 0.135, 0.115)
    ell(h, H, hr, rings=4, color=face)
    ell(h, H + V(0, 0.01, 0.1), (0.1, 0.09, 0.06), wool, seg=6, rings=3)                    # woolly fringe
    ell(h, H + V(0, -0.125, -0.015), (0.022, 0.014, 0.018), "c48f84", seg=4, rings=2)
    eyes(h, H, hr, (0.72, -0.5, 0.28), 0.022)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.1, 0.03, 0.03), 0.1, sx * 1.6, 0.1, 0.065, face, seg=4)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.11, -0.2, 0.22, 0.045, 0.036, leg, seg=4, foot_color="5d4c44")
    t = Model("tail")
    T = V(0, 0.4, cz + 0.12)
    ell(t, T + V(0, 0.03, -0.02), (0.05, 0.045, 0.06), wool, seg=5, rings=3)
    ps.add("tail", t, pivot=T)
    return ps


def cow():
    ps = PartSet("cow")
    coat, patch, muzzle, horn = "f6f1e8", "7a5442", "f0b4a8", "ece2c6"
    cz = 0.92

    def spots(f):
        c = f.calc_center_median()
        return patch if noise.noise(c * 3.2 + Vector((4.1, 1.3, 7.7))) > 0.12 and f.normal.z > -0.5 else coat
    b = Model("body")
    ell(b, (0, 0.02, cz), (0.28, 0.6, 0.3), coat, seg=9, rings=6, colfn=spots)
    ps.add("body", b)
    N = V(0, -0.48, cz + 0.12)
    H = V(0, -0.72, cz + 0.24)
    h = Model("head")
    tube(h, [N, H + V(0, 0.08, -0.02)], [0.18, 0.14], coat, seg=6)
    hr = (0.17, 0.19, 0.17)
    ell(h, H, hr, rings=4, color=coat, colfn=lambda f: patch if f.normal.x > 0.55 and f.normal.z > 0.0 else coat)   # one brown eye patch
    ell(h, H + V(0, -0.16, -0.07), (0.13, 0.09, 0.1), muzzle, seg=6, rings=3)
    eyes(h, H, hr, (0.72, -0.52, 0.32), 0.03)
    for sx in (-1, 1):
        ear(h, H + V(sx * 0.15, 0.03, 0.06), 0.15, sx * 1.6, 0.13, 0.1, coat)
        a = H + V(sx * 0.09, 0.03, 0.13)
        tube(h, [a, a + V(sx * 0.07, 0.0, 0.04), a + V(sx * 0.1, -0.02, 0.1)], [0.03, 0.024, 0.01], horn, seg=4)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.16, -0.38, 0.4, 0.09, 0.065, coat, foot_color="6b5246")
    t = Model("tail")
    T = V(0, 0.6, cz + 0.16)
    tube(t, [T, T + V(0, 0.08, -0.48)], [0.025, 0.018], coat, seg=4)
    ell(t, T + V(0, 0.08, -0.54), (0.04, 0.04, 0.07), patch, seg=4, rings=2)
    ps.add("tail", t, pivot=T)
    return ps


def chicken():
    ps = PartSet("chicken")
    white, wing, red, yellow = "fbf6ea", "efe4cf", "e05a45", "f2b440"
    b = Model("body")
    ell(b, (0, 0.0, 0.3), (0.14, 0.18, 0.14), white, rot=(-0.25, 0, 0))
    ps.add("body", b)
    N = V(0, -0.1, 0.38)
    H = V(0, -0.14, 0.5)
    h = Model("head")
    tube(h, [N, H + V(0, 0.01, -0.03)], [0.07, 0.06], white, seg=5)
    hr = (0.08, 0.08, 0.085)
    ell(h, H, hr, rings=4, color=white)
    h.cyl(0.03, 0.004, 0.06, pos=tuple(H + V(0, -0.07, -0.01)), rot=(math.pi / 2, 0, 0), color=yellow, seg=4)
    for k in range(3):                                                                    # comb
        ell(h, H + V(0, -0.04 + k * 0.035, 0.085 - abs(k - 1) * 0.012), (0.014, 0.022, 0.03), red, seg=5, rings=2)
    ell(h, H + V(0, -0.075, -0.05), (0.014, 0.014, 0.024), red, seg=5, rings=2)            # wattle
    eyes(h, H, hr, (0.8, -0.4, 0.3), 0.016)
    ps.add("head", h, pivot=N)
    for nm, sx in (("wing_l", 1), ("wing_r", -1)):
        m = Model(nm)
        sh = V(sx * 0.12, -0.06, 0.34)
        ell(m, sh + V(sx * 0.015, 0.08, -0.03), (0.035, 0.11, 0.075), wing, seg=6, rings=3, rot=(-0.35, 0, 0))
        ps.add(nm, m, pivot=sh)
    for nm, sx in (("leg_l", 1), ("leg_r", -1)):
        m = Model(nm)
        hip = V(sx * 0.055, 0.01, 0.18)
        m.cyl(0.014, 0.016, 0.17, pos=(hip.x, hip.y, 0.012), color=yellow, seg=4)
        m.box((0.07, 0.07, 0.016), pos=(hip.x, hip.y - 0.02, 0.0), color=yellow)
        ps.add(nm, m, pivot=hip)
    t = Model("tail")
    T = V(0, 0.15, 0.34)
    for k, ry in enumerate((-0.3, 0.0, 0.3)):
        t.cyl(0.04, 0.006, 0.13 - abs(k - 1) * 0.02, pos=tuple(T + V(ry * 0.08, 0, -0.02)), rot=(-0.55, ry, 0),
              scl=(1, 0.35, 1), color=wing, seg=4, smooth=True)
    ps.add("tail", t, pivot=T)
    return ps


def donkey():
    ps = PartSet("donkey")
    coat, light, dark = "a39d96", "efe9df", "514a46"
    cz, L, W, Hb = 0.76, 0.92, 0.4, 0.44
    b = Model("body")
    ell(b, (0, 0, cz), (W / 2, L / 2, Hb / 2), coat, colfn=under(coat, light, -0.45))
    ps.add("body", b)
    N = V(0, -0.33, cz + 0.12)
    H = V(0, -0.5, cz + 0.5)
    h = Model("head")
    tube(h, [N, H + V(0, 0.06, -0.06)], [0.12, 0.09], coat, seg=6)
    ell(h, N + V(0, 0.07, 0.24), (0.03, 0.1, 0.2), dark, seg=4, rings=2, rot=(0.35, 0, 0))   # short upright mane
    hr = (0.13, 0.17, 0.13)
    ell(h, H, hr, rings=4, color=coat)
    ell(h, H + V(0, -0.17, -0.06), (0.1, 0.11, 0.095), light, seg=7, rings=4)               # pale muzzle
    for sx in (-1, 1):
        ell(h, H + V(sx * 0.04, -0.27, -0.05), (0.016, 0.01, 0.014), NOSE, seg=4, rings=2)
    eyes(h, H, hr, (0.7, -0.5, 0.35), 0.028)
    for sx in (-1, 1):                                                                       # long ears, dark tips
        a = H + V(sx * 0.07, 0.05, 0.1)
        ear(h, a, -0.25, sx * 0.3, 0.27, 0.09, coat, colfn=lambda f, a=a: dark if f.calc_center_median().z > a.z + 0.2 else coat)
    ps.add("head", h, pivot=N)
    legs4(ps, cz, 0.11, -0.3, 0.3, 0.065, 0.045, coat, foot_color="3f3936")
    t = Model("tail")
    T = V(0, 0.45, cz + 0.12)
    tube(t, [T, T + V(0, 0.06, -0.15), T + V(0, 0.07, -0.33)], [0.02, 0.018, 0.015], coat, seg=4)
    ell(t, T + V(0, 0.07, -0.38), (0.032, 0.032, 0.06), dark, seg=5, rings=3)
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
        manifest[key] = {"kind": kind, "parts": [p[0] for p in ps.parts], "tris": sum(tris.values()),
                         "top": round(top, 3)}
    with open(os.path.join(OUT, "animals.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
        f.write("\n")
    print("  -- animal triangles (budget 150-400, fish <= 60) --")
    for key, d in manifest.items():
        print("  %-12s %4d tris  top %.2f" % (key, d["tris"], d["top"]))


if __name__ == "__main__":
    print("animals ->", OUT)
    build()
