"""Resident part kit v2 (A20, design/characters/*.png): warm storybook villagers, ~3.5 heads tall, soft rounded low-poly.
One glb with separately pivoted parts; Godot (view/resident_model.gd) picks parts per resident and tints them in
render/resident.gdshader. Budget: an assembled resident (legs, torso, arms, head, face, hair, hat, tool) <= ~600 tris —
the table printed at the end lists the worst combinations.

Tint keys (vertex colour, sRGB) -> replaced per resident, the blue channel = brightness:
  (0, 0, b)   cloth      (1, 0, b)   skin      (0, 1, b)   hair      (0, .5, b) accent (headscarf / cap / shawl)
Everything else is a fixed colour from Balance.LOOK_FIXED (LOOK_*: shirt, boots, belt, apron, eyes, lashes, mouth...)
or Style (props). No textures: one material per resident.

Part pivots (object origin = joint): legs at the hip, arms at the shoulder (built at x = 0, Godot places them at
+-ARM_X), head things (head, face bits, hair, hats, beard) at the neck, torso overlays (apron, sash, shawl, bag) and the
baby basket at the ground centre, carried items at the carry point, tools at the right hand, the cane at the left hand.
Rest pose = standing, facing -Y (front).
Run: blender -b --factory-startup --python build_residents.py -- [out_dir]
"""
import math
import os
import sys

import bmesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, PartSet, Vector, shade, mix, out_dir_from_argv  # noqa: E402

OUT = out_dir_from_argv()

CLOTH = (0, 0, 1.0)
CLOTH_D = (0, 0, 0.84)
CLOTH_DD = (0, 0, 0.7)
SKIN = (1, 0, 1.0)
SKIN_D = (1, 0, 0.88)
HAIR = (0, 1, 1.0)
HAIR_D = (0, 1, 0.8)
ACCENT = (0, 0.5, 1.0)
ACCENT_D = (0, 0.5, 0.82)
SHIRT = "LOOK_SHIRT"
SHIRT_D = shade("LOOK_SHIRT", 0.86)

HIP = 0.6
SHOULDER = 1.22
NECK = 1.26
HEAD_R = 0.34                 # big head: ~0.66 tall on a ~1.9 body -> about 3 heads (reads at phone size)
HEAD_C = NECK + 0.3
HEAD_S = (1.03, 0.98, 0.98)               # round face (sheets): a touch wider than tall
ARM_X = 0.31
ITEM = Vector((0, -0.36, 0.92))
HAND_Z = SHOULDER - 0.56
HAND_R = Vector((ARM_X, -0.02, HAND_Z))
HAND_L = Vector((-ARM_X, -0.02, HAND_Z))


def part(name):
    return Model(name)


def zc(f):
    return f.calc_center_median().z


def lathe(m, prof, seg=8, sy=0.8, colfn=None, color=CLOTH, smooth=True, caps=False, y0=0.0):
    """Surface of revolution through [(radius, z), ...] (bottom -> top), squashed front-back by sy."""
    rings = []
    for r, z in prof:
        ring = []
        for i in range(seg):
            a = i / seg * 2 * math.pi
            ring.append(Vector((math.cos(a) * r, math.sin(a) * r * sy + y0, z)))
        rings.append(ring)
    return m.strip(rings, color=color, smooth=smooth, close=True, colfn=colfn, caps=caps)


def front_y(x, z, r=HEAD_R, s=HEAD_S, c=HEAD_C):
    """Front (-Y) surface of the head ellipsoid at (x, z)."""
    u = 1.0 - (x / (r * s[0])) ** 2 - ((z - c) / (r * s[2])) ** 2
    return -r * s[1] * math.sqrt(max(u, 0.0))


def shell(m, r, depth=0.0, front_cut=0.3, brow=0.22, color=HAIR, colfn=None, seg=10, scl=(1.02, 1.0, 0.95),
          lumps=0.0, lump_scale=2.6, seed=None, up=0.02, rings=6, zig=0.0, inner=None):
    """Head-hugging shell (hair cap / headscarf) trimmed at the brow and the nape.
    zig > 0 = every other vertex pushed out (checkerboard) -> bumpy curly silhouette at no extra triangles."""
    faces = m.sphere(r, pos=(0, 0.02, HEAD_C + up), scl=scl, color=color, seg=seg, rings=rings, colfn=colfn,
                     lumps=lumps, lump_scale=lump_scale, seed=seed)
    bm = m._bm("body")
    if zig > 0:
        ctr = Vector((0, 0.02, HEAD_C + up))
        vs = {}
        for f in faces:
            for v in f.verts:
                vs[v] = True
        for v in vs:
            d = v.co - ctr
            if d.length < 1e-6:
                continue
            lat = round(math.acos(max(-1.0, min(1.0, d.z / d.length))) / (math.pi / rings))
            lon = round((math.atan2(d.y, d.x) % (2 * math.pi)) / (2 * math.pi / seg))
            if 0 < lat < rings and (lat + lon) % 2 == 0:
                v.co = ctr + d * (1.0 + zig)
        bm.normal_update()
    kill = [f for f in faces if (f.calc_center_median().y < -HEAD_R * front_cut and zc(f) < HEAD_C + brow)
            or zc(f) < HEAD_C - 0.2 - depth]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    # inside of the lower rim (sides / back hanging below the brow): a flipped copy, so looking past the cheek
    # shows hair, not the dark outline hull through the open shell
    alive = set(bm.faces)
    rim = [f for f in faces if f in alive and zc(f) < HEAD_C + 0.15 and abs(f.calc_center_median().x) > 0.12] if inner else []
    if rim:                            # group body_nh: no outline hull / crease lines on the inside
        bi = m._bm("body_nh")
        new = []
        for f in rim:
            vs = [bi.verts.new(v.co.copy()) for v in reversed(f.verts)]
            new.append(bi.faces.new(vs))
        bi.normal_update()
        m._finish(bi, new, inner, True)


def bar(m, x, z, w, t, ang, color):
    """A flat little stroke (one quad) lying on the face, centred at (x, z), tilted by ang (+ = right end down)."""
    c, s = math.cos(ang) * w / 2, math.sin(ang) * w / 2
    pts = []
    for dx, dz in ((-c, s), (c, -s)):
        pts.append((x + dx, z + dz))
    (x0, z0), (x1, z1) = pts
    h = t / 2
    quad = [(x0, z0 - h), (x1, z1 - h), (x1, z1 + h), (x0, z0 + h)]
    m.poly([(px, front_y(px, pz) - 0.012, pz) for px, pz in quad], color=color)


def blobs(m, pts, r=0.14, seg=6):
    """Curl clusters: a few low-poly lumps sharing the hair mesh (alternating light / dark hair key)."""
    for k, p in enumerate(pts):
        rr = r * (1.0 + 0.12 * ((k * 5) % 3 - 1))
        m.sphere(rr, pos=(p[0] * 1.06, p[1] * 1.06, HEAD_C + p[2] * 1.06), color=HAIR if k % 3 else HAIR_D, seg=seg, rings=2)   # 12 tris


CURL_TOP = [(0.0, 0.04, 0.3), (-0.17, -0.12, 0.24), (0.17, -0.12, 0.24), (-0.25, 0.14, 0.18), (0.25, 0.14, 0.18),
            (0.0, 0.27, 0.12)]
CURL_SIDE = [(-0.31, 0.02, 0.0), (0.31, 0.02, 0.0)]
CURL_LOW = [(-0.29, 0.1, -0.2), (0.29, 0.1, -0.2), (-0.14, 0.27, -0.16), (0.14, 0.27, -0.16)]


def hair_col(f):
    return HAIR if zc(f) > HEAD_C - 0.04 or f.calc_center_median().y > 0.1 else HAIR_D


def build():
    ps = PartSet("resident")

    # ───────── legs (pivot = hip) ─────────
    m = part("leg_trousers")
    m.cyl(0.105, 0.115, HIP - 0.12, pos=(0, 0, 0.1), color="LOOK_TROUSER", seg=5, smooth=True)
    m.sphere(0.12, pos=(0, -0.04, 0.07), scl=(1.0, 1.4, 0.75), color="LOOK_BOOT", seg=6, rings=3)
    ps.add("leg_trousers", m, pivot=(0, 0, HIP))
    m = part("leg_stocking")
    m.cyl(0.09, 0.1, HIP - 0.12, pos=(0, 0, 0.1), color="LOOK_STOCKING", seg=5, smooth=True)
    m.sphere(0.11, pos=(0, -0.04, 0.06), scl=(1.0, 1.45, 0.7), color="LOOK_BOOT", seg=6, rings=3)
    ps.add("leg_stocking", m, pivot=(0, 0, HIP))

    # ───────── torsos (pivot = ground centre) ─────────
    # tunic: knee-length tunic/vest over the cream shirt, belt + buckle + pouch (base_c man, variety sheets)
    m = part("torso_tunic")
    belt = (HIP + 0.04, HIP + 0.12)

    def tunic_col(f):
        z = zc(f)
        if belt[0] <= z <= belt[1]:
            return "LOOK_BELT"
        if z < HIP - 0.1:
            return CLOTH_D
        return CLOTH
    lathe(m, [(0.33, HIP - 0.26), (0.3, HIP - 0.06), (0.275, belt[0]), (0.275, belt[1]),
              (0.275, SHOULDER - 0.12), (0.2, SHOULDER + 0.01), (0.1, SHOULDER + 0.05)], seg=8, sy=0.78, colfn=tunic_col)
    m.box((0.09, 0.03, 0.07), pos=(0, -0.222, belt[0] + 0.005), color="WINDOW_LIT")                        # buckle
    m.poly([(-0.075, -0.205, SHOULDER - 0.03), (0.0, -0.215, SHOULDER - 0.17), (0.075, -0.205, SHOULDER - 0.03)], color=SHIRT)  # v-neck
    ps.add("torso_tunic", m)

    # dress: bodice + bell skirt + cream apron (base_c woman)
    m = part("torso_dress")

    def dress_col(f):
        z = zc(f)
        c = f.calc_center_median()
        if z < HIP + 0.02 and c.y < -0.12 and abs(c.x) < 0.2:          # apron = the two front skirt faces
            return "LOOK_APRON"
        if z < HIP - 0.05:
            return CLOTH_D
        return CLOTH
    lathe(m, [(0.42, 0.06), (0.36, HIP - 0.2), (0.25, HIP + 0.06), (0.25, SHOULDER - 0.12), (0.19, SHOULDER + 0.01), (0.1, SHOULDER + 0.05)], seg=8, sy=0.82, colfn=dress_col)
    m.cyl(0.25, 0.25, 0.05, pos=(0, 0, HIP + 0.09), color="LOOK_APRON", seg=8, scl=(1, 0.82, 1))               # apron tie
    m.poly([(-0.075, -0.2, SHOULDER - 0.03), (0.0, -0.21, SHOULDER - 0.16), (0.075, -0.2, SHOULDER - 0.03)], color=SHIRT)
    ps.add("torso_dress", m)

    # robe: long robe to the ground with a rope belt and a hood at the back (chapel keeper)
    m = part("torso_robe")

    def robe_col(f):
        z = zc(f)
        if HIP + 0.05 <= z <= HIP + 0.11:
            return "LOOK_STRAW_DARK"
        return CLOTH_D if z < HIP - 0.1 else CLOTH
    lathe(m, [(0.37, 0.02), (0.29, HIP - 0.05), (0.27, HIP + 0.05), (0.27, HIP + 0.11),
              (0.26, SHOULDER - 0.12), (0.2, SHOULDER + 0.01), (0.1, SHOULDER + 0.05)], seg=8, sy=0.8, colfn=robe_col)
    m.sphere(0.2, pos=(0, 0.2, SHOULDER - 0.02), scl=(1.1, 0.6, 0.65), color=CLOTH_D, seg=6, rings=4)         # hood
    ps.add("torso_robe", m)

    # ───────── arms (pivot = shoulder, built at x = 0) ─────────
    m = part("arm")                    # cream shirt sleeve rolled at the elbow, bare forearm, hand
    lathe(m, [(0.065, SHOULDER - 0.5), (0.1, SHOULDER - 0.28), (0.095, SHOULDER + 0.03)], seg=6, sy=1.0, caps=True,
          colfn=lambda f: SKIN if zc(f) < SHOULDER - 0.28 else SHIRT)
    m.sphere(0.078, pos=(0, -0.005, HAND_Z + 0.01), color=SKIN, seg=5, rings=3)
    ps.add("arm", m, pivot=(0, 0, SHOULDER))
    m = part("arm_robe")               # wide cloth sleeve (robe)
    lathe(m, [(0.14, SHOULDER - 0.48), (0.09, SHOULDER + 0.03)], seg=6, sy=1.0, color=CLOTH_D, caps=True)
    m.sphere(0.078, pos=(0, -0.005, HAND_Z + 0.01), color=SKIN, seg=5, rings=3)
    ps.add("arm_robe", m, pivot=(0, 0, SHOULDER))

    # ───────── head (pivot = neck) — face shape variety = node scale in Godot ─────────
    m = part("head")
    m.sphere(HEAD_R, pos=(0, 0, HEAD_C), scl=HEAD_S, color=SKIN, seg=10, rings=6)
    ps.add("head", m, pivot=(0, 0, NECK))

    # ───────── face bits (pivot = neck; swapped for expressions) ─────────
    EY = HEAD_C - 0.06
    EX = 0.125

    def on_face(x, z, d=0.006):
        return front_y(x, z) - d

    m = part("eyes_open")              # dot eyes (tinted per eye in the shader)
    for sx in (-1, 1):
        m.sphere(0.04, pos=(sx * EX, on_face(sx * EX, EY, 0.0), EY), scl=(0.85, 0.5, 1.15), color="LOOK_EYE", seg=5, rings=3)  # small dark dots
    ps.add("eyes_open", m, pivot=(0, 0, NECK))

    def arc(m, cx, cz, w, h, color, up=True, t=0.022):
        """Two short bars forming ^ (up) or u (down)."""
        for s in (-1, 1):
            x = cx + s * w * 0.25
            ang = (s if up else -s) * math.atan2(h, w * 0.5)
            bar(m, x, cz, w * 0.55, t, ang, color)

    m = part("eyes_happy")             # ^ ^
    for sx in (-1, 1):
        arc(m, sx * EX, EY + 0.01, 0.09, 0.04, "LOOK_LASH", up=True)
    ps.add("eyes_happy", m, pivot=(0, 0, NECK))
    m = part("eyes_closed")            # u u (sleep, sick)
    for sx in (-1, 1):
        arc(m, sx * EX, EY - 0.005, 0.09, 0.03, "LOOK_LASH", up=False)
    ps.add("eyes_closed", m, pivot=(0, 0, NECK))
    m = part("brows_sad")              # / \ worried brows
    for sx in (-1, 1):
        x = sx * (EX + 0.005)
        bar(m, x, EY + 0.085, 0.085, 0.022, sx * 0.4, "LOOK_LASH")
    ps.add("brows_sad", m, pivot=(0, 0, NECK))
    MZ = HEAD_C - 0.17
    m = part("mouth_smile")
    arc(m, 0, MZ, 0.1, 0.03, "LOOK_MOUTH", up=False, t=0.02)
    ps.add("mouth_smile", m, pivot=(0, 0, NECK))
    m = part("mouth_grin")             # open happy mouth
    m.sphere(0.045, pos=(0, on_face(0, MZ, 0.0), MZ - 0.005), scl=(1.3, 0.4, 0.75), color="LOOK_MOUTH", seg=5, rings=3)
    ps.add("mouth_grin", m, pivot=(0, 0, NECK))
    m = part("mouth_sad")
    arc(m, 0, MZ - 0.01, 0.09, 0.025, "LOOK_MOUTH", up=True, t=0.02)
    ps.add("mouth_sad", m, pivot=(0, 0, NECK))
    m = part("mouth_flat")
    bar(m, 0, MZ, 0.06, 0.018, 0.0, "LOOK_MOUTH")
    ps.add("mouth_flat", m, pivot=(0, 0, NECK))

    # ───────── hair (pivot = neck) ─────────
    R = HEAD_R * 1.04
    m = part("hair_short")
    shell(m, R, colfn=hair_col)
    m.sphere(0.12, pos=(-0.07, -0.22, HEAD_C + 0.26), scl=(1.5, 0.7, 0.5), rot=(0, 0, 0.3), color=HAIR, seg=6, rings=3)   # fringe
    ps.add("hair_short", m, pivot=(0, 0, NECK))

    m = part("hair_long")
    shell(m, R, depth=0.1, colfn=hair_col)
    m.sphere(0.3, pos=(0, 0.17, HEAD_C - 0.32), scl=(1.0, 0.45, 1.05), color=HAIR_D, seg=6, rings=4)                    # back fall
    m.sphere(0.11, pos=(-0.08, -0.22, HEAD_C + 0.26), scl=(1.5, 0.7, 0.5), rot=(0, 0, 0.3), color=HAIR, seg=6, rings=3)
    ps.add("hair_long", m, pivot=(0, 0, NECK))

    m = part("hair_braids")
    shell(m, R, depth=0.04, colfn=hair_col)
    for sx in (-1, 1):
        m.cyl(0.075, 0.05, 0.36, pos=(sx * 0.27, 0.1, HEAD_C - 0.6), rot=(0, sx * -0.12, 0), color=HAIR_D, seg=5, smooth=True)
        m.sphere(0.045, pos=(sx * 0.31, 0.1, HEAD_C - 0.62), color="LOOK_SCARF_B", seg=4, rings=3)
    ps.add("hair_braids", m, pivot=(0, 0, NECK))

    m = part("hair_bun")
    shell(m, R, colfn=hair_col)
    m.sphere(0.15, pos=(0, 0.2, HEAD_C + 0.3), color=HAIR, seg=6, rings=4)                                              # top bun
    ps.add("hair_bun", m, pivot=(0, 0, NECK))

    # curly: a low cap + clustered lumps (variety_a curly heads). "_under" = only the curls that show below a cap/scarf
    m = part("hair_curly")
    shell(m, R, colfn=hair_col, seg=8)
    blobs(m, CURL_TOP + CURL_SIDE)
    ps.add("hair_curly", m, pivot=(0, 0, NECK))
    m = part("hair_curly_under")
    shell(m, R, colfn=hair_col, seg=8)
    blobs(m, CURL_SIDE + CURL_TOP[3:])
    ps.add("hair_curly_under", m, pivot=(0, 0, NECK))

    m = part("hair_curly_long")        # big curly volume to the shoulders (base_c woman, elder)
    shell(m, R, depth=0.14, colfn=hair_col, seg=8)
    blobs(m, CURL_TOP[:3] + CURL_TOP[5:] + CURL_SIDE + CURL_LOW, r=0.15)
    ps.add("hair_curly_long", m, pivot=(0, 0, NECK))
    m = part("hair_curly_long_under")
    shell(m, R, depth=0.14, colfn=hair_col, seg=8)
    blobs(m, CURL_SIDE + CURL_LOW + CURL_TOP[5:], r=0.15)
    ps.add("hair_curly_long_under", m, pivot=(0, 0, NECK))

    m = part("hair_wave")
    shell(m, R, colfn=hair_col)
    m.sphere(0.13, pos=(-0.08, -0.2, HEAD_C + 0.27), scl=(1.6, 0.75, 0.55), rot=(0, 0.25, 0.35), color=HAIR, seg=6, rings=3)
    m.sphere(0.12, pos=(0, 0.28, HEAD_C - 0.12), scl=(1.7, 0.6, 0.8), color=HAIR_D, seg=6, rings=3)                    # nape wave
    ps.add("hair_wave", m, pivot=(0, 0, NECK))

    m = part("hair_wave_long")
    shell(m, R, depth=0.1, colfn=hair_col)
    m.sphere(0.13, pos=(-0.08, -0.2, HEAD_C + 0.27), scl=(1.6, 0.75, 0.55), rot=(0, 0.25, 0.35), color=HAIR, seg=6, rings=3)
    m.sphere(0.3, pos=(0, 0.18, HEAD_C - 0.34), scl=(1.05, 0.48, 1.1), color=HAIR_D, seg=6, rings=4, lumps=0.08, seed=3)
    ps.add("hair_wave_long", m, pivot=(0, 0, NECK))

    m = part("beard")
    m.sphere(0.21, pos=(0, -0.16, HEAD_C - 0.19), scl=(1.25, 0.72, 0.85), color=HAIR, seg=6, rings=3)
    m.sphere(0.06, pos=(0, on_face(0, HEAD_C - 0.09, 0.0) + 0.01, HEAD_C - 0.09), scl=(2.2, 0.6, 0.6), color=HAIR_D, seg=4, rings=3)
    ps.add("beard", m, pivot=(0, 0, NECK))

    # ───────── hats (pivot = neck) ─────────
    m = part("hat_straw")              # farmer: wide brim
    m.cyl(0.56, 0.52, 0.04, pos=(0, 0, HEAD_C + 0.17), color="LOOK_STRAW", seg=10)
    m.cyl(0.29, 0.22, 0.24, pos=(0, 0, HEAD_C + 0.19), color="LOOK_STRAW", seg=8, smooth=True, cap="LOOK_STRAW",
          colfn=lambda f: "LOOK_STRAW_DARK" if zc(f) < HEAD_C + 0.26 else "LOOK_STRAW")
    ps.add("hat_straw", m, pivot=(0, 0, NECK))

    m = part("hat_scarf")              # headscarf, knot at the back (base_c woman)
    shell(m, HEAD_R * 1.2, depth=-0.08, front_cut=0.5, brow=0.2, color=ACCENT,
          colfn=lambda f: ACCENT if zc(f) > HEAD_C else ACCENT_D, up=0.05)
    m.sphere(0.09, pos=(0, 0.35, HEAD_C - 0.04), color=ACCENT_D, seg=5, rings=3)                                       # knot
    m.box((0.09, 0.04, 0.2), pos=(0.05, 0.37, HEAD_C - 0.3), rot=(0.25, 0.25, 0), color=ACCENT_D)                    # tail
    ps.add("hat_scarf", m, pivot=(0, 0, NECK))

    m = part("hat_cap")                # flat cap
    m.sphere(HEAD_R * 1.22, pos=(0, 0.02, HEAD_C + 0.14), scl=(1.06, 1.06, 0.55), color=ACCENT, seg=8, rings=4)
    m.box((0.36, 0.16, 0.03), pos=(0, -0.36, HEAD_C + 0.13), color=ACCENT_D)                                      # peak
    ps.add("hat_cap", m, pivot=(0, 0, NECK))

    m = part("hat_baker")              # puffy white cap
    m.cyl(0.33, 0.34, 0.1, pos=(0, 0.01, HEAD_C + 0.16), color=shade("LOOK_BAKER", 0.9), seg=8)
    m.sphere(0.36, pos=(0, 0.02, HEAD_C + 0.32), scl=(1.05, 1.05, 0.55), color="LOOK_BAKER", seg=8, rings=4)
    ps.add("hat_baker", m, pivot=(0, 0, NECK))

    m = part("hat_fisher")             # knit cap with a rolled band
    m.sphere(HEAD_R * 1.2, pos=(0, 0.02, HEAD_C + 0.1), scl=(1.04, 1.04, 0.85), color=ACCENT, seg=8, rings=4)
    bm = m._bm("body")
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if zc(f) < HEAD_C + 0.08], context="FACES")
    m.cyl(0.42, 0.415, 0.1, pos=(0, 0.02, HEAD_C + 0.06), color=ACCENT_D, seg=8)
    ps.add("hat_fisher", m, pivot=(0, 0, NECK))

    # ───────── outfit overlays (pivot = ground centre, on the body) ─────────
    m = part("apron_job")              # baker / miller / healer: big white apron over the tunic
    m.box((0.4, 0.03, 0.52), pos=(0, -0.265, HIP - 0.26), rot=(0.06, 0, 0), color="LOOK_APRON")
    m.box((0.28, 0.03, 0.3), pos=(0, -0.235, HIP + 0.24), color="LOOK_APRON")
    ps.add("apron_job", m)
    m = part("sash")                   # chief: red waist sash with knot and tails
    m.cyl(0.29, 0.29, 0.1, pos=(0, 0, HIP + 0.07), color="LOOK_SASH", seg=8, scl=(1, 0.8, 1))
    m.box((0.07, 0.03, 0.22), pos=(0.22, -0.2, HIP - 0.16), rot=(0, -0.15, 0), color="LOOK_SASH")       # tail
    ps.add("sash", m)
    m = part("herb_bag")               # herbalist: shoulder bag with leaves sticking out
    m.box((0.06, 0.03, 0.6), pos=(-0.02, -0.235, HIP + 0.02), rot=(0, 0.72, 0), color="LOOK_BELT")
    m.box((0.22, 0.12, 0.2), pos=(-0.29, -0.06, HIP - 0.2), color=shade("LOOK_TROUSER", 1.25))
    for k in range(2):
        m.box((0.06, 0.04, 0.16), pos=(-0.36 + k * 0.1, -0.06, HIP - 0.02), rot=(0, -0.4 + k * 0.4, 0), color="LOOK_HERB")
    ps.add("herb_bag", m)
    m = part("shawl")                  # elder: capelet over the shoulders, knot in front
    m.cyl(0.36, 0.16, 0.34, pos=(0, 0, SHOULDER - 0.3), scl=(1, 0.86, 1), color=ACCENT, seg=8, smooth=True,
          colfn=lambda f: ACCENT_D if zc(f) < SHOULDER - 0.2 else ACCENT)
    ps.add("shawl", m)

    # ───────── baby: swaddled bundle in a basket (pivot = ground centre) ─────────
    m = part("baby_basket")
    lathe(m, [(0.27, 0.0), (0.34, 0.16), (0.36, 0.2)], seg=8, sy=0.7, color="LOOK_STRAW_DARK", caps=True,
          colfn=lambda f: "LOOK_STRAW" if zc(f) > 0.16 else "LOOK_STRAW_DARK")
    m.sphere(0.21, pos=(0, 0.06, 0.21), scl=(1.0, 1.25, 0.55), color="LOOK_APRON", seg=6, rings=4)
    m.sphere(0.13, pos=(0, -0.15, 0.27), color=SKIN, seg=7, rings=5)
    for sx in (-1, 1):
        m.box((0.045, 0.02, 0.015), pos=(sx * 0.045, -0.272, 0.27), color="LOOK_LASH")
    m.sphere(0.06, pos=(0, -0.12, 0.38), color=HAIR, seg=5, rings=3)
    ps.add("baby_basket", m)

    # ───────── carried items (pivot = carry point in front of the chest) ─────────
    o = ITEM
    m = part("item_log")
    m.cyl(0.12, 0.12, 0.95, pos=o + Vector((-0.475, 0, 0)), rot=(0, math.pi / 2, 0.12), color="TRUNK", seg=6, smooth=True,
          cap="STUMP_TOP", bottom_cap="STUMP_TOP")
    ps.add("item_log", m, pivot=o)
    m = part("item_plank")
    for k in range(3):
        m.box((0.95, 0.3, 0.06), pos=o + Vector((0.02 * k, 0, -0.1 + k * 0.065)), color=shade("PLANK", (0.92, 1.0, 1.06)[k]))
    ps.add("item_plank", m, pivot=o)
    m = part("item_stone")
    m.ico(0.2, pos=o + Vector((0, 0, 0.02)), scl=(1.1, 1, 0.85), color="ROCK", subdiv=1, smooth=True, lumps=0.2, seed=3)
    ps.add("item_stone", m, pivot=o)
    m = part("item_sack")
    m.sphere(0.22, pos=o + Vector((0, 0, 0.02)), scl=(1, 0.8, 1.1), color=mix("THATCH", "PLASTER", 0.55), seg=7, rings=5, lumps=0.1)
    m.cyl(0.07, 0.03, 0.12, pos=o + Vector((0, 0, 0.22)), color=shade(mix("THATCH", "PLASTER", 0.55), 0.85), seg=5)
    ps.add("item_sack", m, pivot=o)
    m = part("item_basket")
    m.cyl(0.24, 0.3, 0.2, pos=o + Vector((0, 0, -0.1)), color="LOOK_STRAW_DARK", seg=8, smooth=True, cap="LOOK_STRAW")
    for k in range(3):
        m.sphere(0.1, pos=o + Vector((-0.12 + k * 0.12, 0.02 * k, 0.12)), scl=(1.2, 1, 0.75), color="BREAD", seg=5, rings=3)
    ps.add("item_basket", m, pivot=o)
    m = part("item_crate")
    m.box((0.4, 0.34, 0.32), pos=o + Vector((0, 0, -0.14)), color=shade("WOOD", 1.2))
    m.box((0.42, 0.36, 0.05), pos=o + Vector((0, 0, 0.13)), color="WOOD")
    ps.add("item_crate", m, pivot=o)
    m = part("item_water")
    m.cyl(0.17, 0.15, 0.3, pos=o + Vector((0, 0, -0.14)), color="WOOD", seg=8, smooth=True, cap="WATER")
    m.cyl(0.18, 0.18, 0.04, pos=o + Vector((0, 0, 0.02)), color="WOOD_DARK", seg=8)
    ps.add("item_water", m, pivot=o)

    # ───────── tools (pivot = right hand; the handle runs forward (-Y) from the fist) ─────────
    h = HAND_R
    fwd = (math.pi / 2 - 0.1, 0, 0)

    def handle(m, length, back=0.1, r=0.03):
        m.cyl(r, r, length, pos=h + Vector((0, back, -0.01)), rot=fwd, color="WOOD", seg=5)

    m = part("tool_axe")
    handle(m, 0.72)
    m.box((0.05, 0.2, 0.2), pos=h + Vector((0, -0.6, -0.16)), color="ROCK_DARK")
    ps.add("tool_axe", m, pivot=h)
    m = part("tool_hammer")
    handle(m, 0.55)
    m.box((0.22, 0.12, 0.12), pos=h + Vector((0, -0.48, -0.11)), color="ROCK_DARK")
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
    m = part("tool_rod")               # fisher (placeholder until fish exist): long thin rod
    m.cyl(0.025, 0.012, 1.5, pos=h + Vector((0, 0.1, 0.0)), rot=(math.pi / 2 - 0.55, 0, 0), color="WOOD", seg=4)
    ps.add("tool_rod", m, pivot=h)
    m = part("tool_peel")              # baker's bread peel
    handle(m, 0.6, back=0.05)
    m.box((0.24, 0.26, 0.03), pos=h + Vector((0, -0.66, -0.07)), rot=(0.1, 0, 0), color=shade("WOOD", 1.25))
    ps.add("tool_peel", m, pivot=h)
    m = part("tool_herbs")             # herbalist: a bunch of herbs
    m.cyl(0.03, 0.03, 0.22, pos=h + Vector((0, 0.04, -0.02)), rot=fwd, color="LOOK_HERB", seg=4)
    for k in range(2):
        m.box((0.08, 0.05, 0.14), pos=h + Vector((-0.04 + k * 0.08, -0.22 - 0.02 * k, -0.08)), rot=(1.2, (k - 1) * 0.5, 0),
              color=shade("LOOK_HERB", (0.9, 1.1, 1.0)[k]))
    ps.add("tool_herbs", m, pivot=h)

    # ───────── elder's cane (pivot = left hand) ─────────
    m = part("cane")
    m.cyl(0.028, 0.028, HAND_Z + 0.06, pos=HAND_L + Vector((0, -0.03, -HAND_Z)), color="LOOK_CANE", seg=5)
    m.box((0.06, 0.12, 0.05), pos=HAND_L + Vector((0, -0.07, 0.05)), color="LOOK_CANE")
    ps.add("cane", m, pivot=HAND_L)

    tris = ps.export(OUT)
    budget(tris)


def budget(t):
    """Worst assembled residents (2 legs, torso, 2 arms, head, eyes + mouth, hair, beard?, hat, overlays, tool)."""
    def g(*names):
        return sum(t.get(n, 0) for n in names)
    face = g("eyes_open", "mouth_smile")
    base_t = 2 * t["leg_trousers"] + t["torso_tunic"] + 2 * t["arm"] + t["head"] + face
    base_d = 2 * t["leg_stocking"] + t["torso_dress"] + 2 * t["arm"] + t["head"] + face
    hair = max(t[n] for n in t if n.startswith("hair_"))
    rows = [
        ("tunic + short hair + cap", base_t + g("hair_short", "hat_cap")),
        ("tunic + curly + beard", base_t + g("hair_curly", "beard")),
        ("dress + curly long", base_d + g("hair_curly_long")),
        ("dress + braids + scarf", base_d + g("hair_braids", "hat_scarf")),
        ("farmer: tunic+short+straw+hoe", base_t + g("hair_short", "hat_straw", "tool_hoe")),
        ("woodcutter: tunic+curly+beard+cap+axe", base_t + g("hair_curly_under", "beard", "hat_cap", "tool_axe")),
        ("baker: tunic+wave+baker+apron+peel", base_t + g("hair_wave", "hat_baker", "apron_job", "tool_peel")),
        ("herbalist: dress+wave long+bag+herbs", base_d + g("hair_wave_long", "herb_bag", "tool_herbs")),
        ("elder chief: tunic+curly long+beard+shawl+cane+sash",
         base_t + g("hair_curly_long", "beard", "shawl", "cane", "sash")),
        ("priest: robe+short+beard", 2 * t["leg_trousers"] + t["torso_robe"] + 2 * t["arm_robe"] + t["head"] + face + g("hair_short", "beard")),
        ("baby basket", t["baby_basket"]),
        ("(max hair alone)", hair),
    ]
    print("  parts:", " ".join("%s=%d" % kv for kv in sorted(t.items())))
    print("  -- assembled resident triangles --")
    for nm, n in rows:
        print("  %-55s %4d" % (nm, n))


if __name__ == "__main__":
    print("residents ->", OUT)
    build()
