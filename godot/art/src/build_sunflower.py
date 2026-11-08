"""The giant sunflower (design/gdd/flower-forest.md R3, ROADMAP F-2) + the cotton bush (R4) + a fallen sunflower seed.
Scale: 1 unit = one adult resident (the view scales the sunflower by SunflowerView.SCALE).

giant_sunflower.glb (PartSet, read with Art.parts):
  stalk        tapering green stalk with a gentle S-bend, mottled vertex colour, node bumps at the leaves; pivot at the foot
  leaves       heart leaves on short petioles, alternating, drooping/cupped/twisted, lighter midrib (pivot at the foot)
  head         curved neck + nodding head; pivot = the crook (0,0,H) on the stalk axis (the view yaws head + neck toward
               the lamp). The face looks along -Y (Blender) = +Z (Godot), raised only TILT deg (from behind the deep green calyx reads) (a nod, not a dish).
               Domed spiral seed disc (dark core -> lighter rim florets), two staggered rows of twisted petals,
               thick green calyx with two rows of bracts.
  head_dry     neck arched over, face hanging toward the ground (TILT_DRY, baked — the view only yaws), brown petals curled back
Every part also has "<part>__far" (art bible 8.7 landmark budget: near <= 6,000 body tris, far <= 1,200).
2026-11-08 shape pass (user: "거대해바라기는 별로다 — 모양 어색"): was a straight banded pipe + a flat dish facing the sky.
cotton_bush.glb: bush (leaf cushion) + boll (a white cotton puff bigger than a resident, autumn) as parts.
sunflower_seed.glb: one striped seed lying on the ground (~2.4 long), the thing children run to.
Run: blender -b --factory-startup --python build_sunflower.py -- [out_dir]
"""
import math
import os
import random
import sys

import bmesh
from mathutils import Quaternion

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, PartSet, Vector, shade, mix, out_dir_from_argv  # noqa: E402,F401
from flora_kit import V, bezier, leaf  # noqa: E402
from build_bonsai import stube  # noqa: E402

OUT = os.path.join(out_dir_from_argv(), "flora")
H = 76.0                      # stalk height to the crook (model units; x SunflowerView.SCALE 0.6 = ~46 residents). With the
                              # nodding head the plant tops out ~118 (~71 residents) — SunflowerView.CUT_OFF sits above that
HEAD_R = 36.0                 # seed disc + petals radius (x0.6 = ~21.6 -> head ~43 residents across, a village square; 1.5x on 2026-11-08)
STALK_R0 = 4.6                # stalk radius at the foot (x0.6 = 2.8 -> ~5.5 residents wide: thicker than anything in the village)
STALK_R1 = 2.7                # ... at the crook (tapers; the neck thins a little more then flares into the calyx)
TILT = 20.0                   # head face elevation (deg): a heavy nodding head on a curved neck (was 58 = a dish facing the sky)
TILT_DRY = -52.0              # autumn/winter: the neck arches over and the face hangs toward the ground
NECK = (0.0, -9.0, 8.0)       # crook -> back of the head (Blender; -Y = the way the face looks)
NECK_DRY = (0.0, -11.0, 3.0)
LEAF_SPEC = ((0.15, 0.5, 25.0, 10.0), (0.26, 3.1, 23.0, 9.4), (0.37, 5.6, 21.0, 8.6), (0.48, 1.9, 18.5, 7.6),
             (0.59, 4.4, 15.5, 6.4), (0.70, 0.9, 12.5, 5.2))
# (height fraction, azimuth rad (Blender XY), length, half width) -- alternating ~140 deg up the stalk, big low / small high.
# Mirrored in SunflowerView.LEAVES for the leaf shadows.
STALK = ("6f9a48", "5f8a3e", "78a44f", "668f43")
LEAF = ("6aa04c", "4f8a40", "8cc062", "62984a")
VEIN = "a2cc74"
GOLD = "f2c23a"
YELLOW = "f7d65a"
AMBER = "e9a92c"
DISC_DARK = "6e4426"
DISC_BROWN = "94622e"
DISC_CORE = "4e2e18"           # dark brown heart
DISC_RIM = "b8842e"            # lighter rim florets
DISC_RIM2 = "cf9c36"
DRY = "a8783e"
SEPAL = ("4f8a40", "6aa04c", "5d9446")
SEPAL_DRY = ("7a6e34", "8a7a3c", "6e5e2e")    # autumn calyx: olive-brown, not a green urchin


def _h(*a):
    """Deterministic 0..1 hash (stable across Blender runs)."""
    x = 0
    for v in a:
        x = (x * 1103515245 + int(v) * 2654435761 + 12345) & 0x7FFFFFFF
    x ^= x >> 13
    x = (x * 1274126177) & 0x7FFFFFFF
    return (x % 10007) / 10007.0


def stalk_pts(n):
    """Gentle S-bend that leaves the foot and arrives at the crook vertically on the axis (so the head part can yaw
    about the crook without a kink)."""
    pts = []
    for i in range(n + 1):
        t = i / n
        sp = math.sin(math.pi * t)
        pts.append(V(2.6 * sp * sp, 1.5 * math.sin(math.tau * t) * sp, H * t))
    return pts


def stalk_r(t):
    return STALK_R0 - (STALK_R0 - STALK_R1) * t ** 0.8


def build_stalk(far):
    m = Model("sf_stalk" + ("_far" if far else ""), 11)
    n = 6 if far else 18
    seg = 6 if far else 10
    pts = stalk_pts(n)
    radii = [stalk_r(i / n) for i in range(n + 1)]
    radii[0] = STALK_R0 * 1.3                      # root flare
    if not far:
        radii[1] *= 1.06
        for (z, _az, _ln, _w) in LEAF_SPEC:        # node bumps where the leaves attach
            radii[int(round(z * n))] *= 1.16

    def col(i, k, N):
        if far:
            return STALK[0] if k % 2 == 0 else STALK[1]
        r = _h(i, k, 7)                           # mottled, no bands: a few greens scattered per face
        return STALK[0] if r < 0.45 else (STALK[1] if r < 0.7 else (STALK[3] if r < 0.88 else STALK[2]))

    stube(m, pts, radii, seg=seg, group="body_nl", colfn=col,
          wobble=None if far else (lambda i, k: 0.96 + 0.07 * _h(i, k, 3)), twist=0.0 if far else 0.06)
    return m


def _leaf_axis(pb, d, up, ln, droop, t):
    return pb + d * (ln * t * (1.0 - 0.25 * t)) + up * (ln * (0.16 * t - droop * t * t * 0.7))


def heart_leaf(m, base, az, ln, w, group, far, seed):
    """Heart-shaped leaf on a short petiole: lobes at the base reach back past the petiole, pointed tip; the blade
    droops, cups (edges up) and twists a little. Midrib in a lighter vertex colour (near)."""
    rng = random.Random(seed)
    d = V(math.cos(az), math.sin(az), 0)
    up = V(0, 0, 1)
    side0 = d.cross(up)
    pet_l = ln * 0.2                               # petiole: short, rising, thin
    pb = base + d * pet_l + up * (pet_l * 0.45)
    stube(m, [base - d * 0.6, base + d * (pet_l * 0.5) + up * (pet_l * 0.3), pb], [1.05, 0.8, 0.6],
          seg=4 if far else 5, group=group, color=STALK[1])
    n = 3 if far else 6
    droop = 0.62 + rng.uniform(-0.08, 0.08)
    twist = rng.uniform(-0.45, 0.45)
    cup = 0.22
    tab = ((0.0, 0.55), (0.14, 0.9), (0.32, 1.0), (0.52, 0.86), (0.7, 0.6), (0.86, 0.3), (1.0, 0.0))

    def width(t):
        for (a, wa), (b, wb) in zip(tab[:-1], tab[1:]):
            if a <= t <= b:
                return wa + (wb - wa) * (t - a) / (b - a)
        return 0.0

    rings = []
    for i in range(n + 1):
        t = i / n
        p = _leaf_axis(pb, d, up, ln, droop, t)
        T = (_leaf_axis(pb, d, up, ln, droop, min(1.0, t + 0.02)) - _leaf_axis(pb, d, up, ln, droop, max(0.0, t - 0.02))).normalized()
        S = Quaternion(T, twist * t) @ side0
        S = (S - T * S.dot(T)).normalized()
        N = S.cross(T).normalized()
        if N.z < 0:
            N = -N
        ww = max(w * width(t), 0.05)
        back = T * (w * 0.3) if i == 0 else V(0, 0, 0)    # heart lobes reach back past the petiole
        c = N * (cup * ww)
        th = 0.45
        if far:
            rings.append([p - S * ww + c - back, p + N * th, p + S * ww + c - back, p - N * th * 0.4])
        else:
            rings.append([p - S * ww + c - back, p - S * ww * 0.12 + N * th * 0.9, p + N * th * 1.25,
                          p + S * ww * 0.12 + N * th * 0.9, p + S * ww + c - back, p - N * th * 0.4])
    tone = LEAF[0] if seed % 2 else LEAF[3]
    fs = m.strip(rings, color=tone, group=group, smooth=False, close=True, caps=True)
    bm = m._bm(group)
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    bm.normal_update()
    k = len(rings[0])
    for idx, f in enumerate(fs):
        if idx >= len(fs) - 2:
            col = tone
        elif far:
            col = tone if idx % k < 2 else LEAF[1]
        else:
            j = idx % k
            col = VEIN if j in (1, 2) else (tone if j in (0, 3) else LEAF[1])
        m._finish(bm, [f], col, False)


def build_leaves(far):
    m = Model("sf_leaves" + ("_far" if far else ""), 12)
    pts = stalk_pts(18)
    spec = LEAF_SPEC[::2] if far else LEAF_SPEC
    for li, (z, az, ln, w) in enumerate(spec):
        p = pts[int(round(z * 18))]
        d = V(math.cos(az), math.sin(az), 0)
        heart_leaf(m, p + d * (stalk_r(z) * 0.7), az, ln, w, "body_nl", far, 41 + li)
    return m


def disc_face(m, c, f, up, r, rings, seg, colfn, group, dome, depth, far, sepal=SEPAL):
    """Domed seed disc facing f + a thick convex green calyx behind it (where the neck plugs in). Ring radii are packed
    toward the rim (sqrt spacing) so the spiral pattern keeps roughly square cells."""
    s = f.cross(up).normalized()
    u = s.cross(f).normalized()
    bm = m._bm(group)
    ring_v = []
    for j in range(1, rings + 1):
        rr = r * math.sqrt(j / rings)
        dome_k = dome * (1.0 - (rr / r) ** 2)
        tw = 0.5 * (j % 2)                            # stagger alternate rings -> diamond cells, reads as seeds
        ring_v.append([bm.verts.new(c + f * dome_k + (s * math.cos(a) + u * math.sin(a)) * rr)
                       for a in [(k + tw) * math.tau / seg for k in range(seg)]])
    tip = bm.verts.new(c + f * (dome + 0.1))
    faces = []
    for k in range(seg):
        faces.append(bm.faces.new((tip, ring_v[0][k], ring_v[0][(k + 1) % seg])))
    for j in range(rings - 1):
        for k in range(seg):
            kk = (k + 1) % seg
            faces.append(bm.faces.new((ring_v[j][k], ring_v[j + 1][k], ring_v[j + 1][kk], ring_v[j][kk])))
    # calyx: rim -> profile rings -> apex (the neck plugs in here)
    bseg = seg if far else seg // 2
    step = seg // bseg
    prof = [(0.7, 0.75)] if far else [(0.97, 0.38), (0.64, 0.82)]
    backs = [[bm.verts.new(c - f * (depth * dz) + (s * math.cos(a) + u * math.sin(a)) * r * rk)
              for a in [k * math.tau / bseg for k in range(bseg)]] for (rk, dz) in prof]
    apex = bm.verts.new(c - f * depth)
    backf = []
    for k in range(bseg):
        kk = (k + 1) % bseg
        rim = [ring_v[-1][(k * step + i) % seg] for i in range(step + 1)]
        backf.append(bm.faces.new([backs[0][k], backs[0][kk]] + list(reversed(rim))))
        for j in range(len(backs) - 1):
            backf.append(bm.faces.new((backs[j + 1][k], backs[j + 1][kk], backs[j][kk], backs[j][k])))
        backf.append(bm.faces.new((apex, backs[-1][kk], backs[-1][k])))
    bmesh.ops.recalc_face_normals(bm, faces=faces + backf)
    bm.normal_update()
    m._finish(bm, faces, None, True, colfn)
    m._finish(bm, backf, sepal[0], True)
    return s, u


def petal_ring(m, c, f, s, u, n, r0, r1, w, colors, cup, group, rng, phase=0.0, pts_n=5, jitter=0.12, curl=0.0,
               twist=0.0, bend=0.0, back=0.0):
    """One row of ray petals: elongated, pointed, varied length (+-jitter), small angle jitter, a sideways bend and a
    twist along the length; rises toward f (cup) and the tip may roll back (curl)."""
    for i in range(n):
        a = (i + phase + rng.uniform(-0.14, 0.14)) * math.tau / n
        d = s * math.cos(a) + u * math.sin(a)
        side = f.cross(d).normalized()
        ln = (r1 - r0) * (1.0 + rng.uniform(-jitter, jitter))
        cp = cup * (1.0 + rng.uniform(-0.4, 0.4))
        tw = twist * rng.uniform(-1.0, 1.0)
        bd = bend * rng.uniform(-1.0, 1.0)
        pts = []
        nrm = []
        for j in range(pts_n):
            t = j / (pts_n - 1)
            rise = cp * ln * (t ** 1.2) - curl * ln * (t ** 3)
            pts.append(c - f * back + d * (r0 + ln * t) + f * rise + side * (bd * ln * t * t))
            slope = cp * 1.2 * t ** 0.2 - curl * 3.0 * t * t
            nrm.append(Quaternion(d, tw * t) @ (f - d * slope).normalized())
        if pts_n == 5:
            widths = [w * 0.3, w * 0.86, w, w * 0.66, 0.0]
        elif pts_n == 4:
            widths = [w * 0.4, w, w * 0.7, 0.0]
        else:
            widths = [w * 0.5, w, 0.0]
        col = colors[0] if rng.random() > 0.22 else colors[-1]
        leaf(m, pts, widths, nrm, thick=0.2, color=col, color_under=shade(col, 0.84), group=group)


def bract_ring(m, c, f, s, u, n, r0, r1, z0, z1, w, group, phase, rng, sepal=SEPAL):
    """Green pointed bracts on the back of the head, spreading outward and backward."""
    for i in range(n):
        a = (i + phase + rng.uniform(-0.1, 0.1)) * math.tau / n
        d = s * math.cos(a) + u * math.sin(a)
        rr = r1 * (1.0 + rng.uniform(-0.08, 0.1))
        pts = [c - f * z0 + d * r0, c - f * (z0 + (z1 - z0) * 0.6) + d * (r0 + (rr - r0) * 0.55), c - f * z1 + d * rr + f * 0.6]
        col = sepal[i % 3]
        leaf(m, pts, [w, w * 0.75, 0.0], -f, thick=0.25, color=col, color_under=shade(col, 0.85), group=group)


def head_frame(dry):
    """(face dir f, neck points from the crook (0,0,H) to the back of the head, head centre, calyx depth)."""
    e = math.radians(TILT_DRY if dry else TILT)
    f = V(0, -math.cos(e), math.sin(e))
    p0 = V(0, 0, H)
    a = p0 + V(*(NECK_DRY if dry else NECK))
    depth = 4.6 if dry else 6.5
    neck = bezier(p0, p0 + V(0, 0, 7.0), a - f * 7.0, a, 6)
    return f, neck, a + f * depth, depth


def build_head(far, dry):
    m = Model("sf_head" + ("_dry" if dry else "") + ("_far" if far else ""), 13)
    rng = random.Random(1307 + (1 if dry else 0) + (2 if far else 0))
    f, neck, c, depth = head_frame(dry)
    up = V(0, 0, 1)
    disc_r = HEAD_R * 0.42
    s0 = f.cross(up).normalized()
    u0 = s0.cross(f).normalized()

    def seeds(fc):
        p = fc.calc_center_median() - c
        q = p - f * p.dot(f)
        rr = q.length / disc_r
        if dry:
            return DISC_CORE if rr < 0.25 else (DISC_DARK if rr > 0.86 else (DISC_BROWN if (int(rr * 7) % 2) else DISC_DARK))
        if rr < 0.2:
            return DISC_CORE
        if rr > 0.9:
            return DISC_RIM2
        if rr > 0.8:
            return DISC_RIM
        if far:
            return DISC_BROWN if rr < 0.55 else DISC_DARK
        ang = math.atan2(q.dot(u0), q.dot(s0))
        lr = math.log(max(rr, 0.05))
        a1 = ang * 8 / math.tau + lr * 2.6          # two crossing log spirals (8 and 13 arms) -> florets in a lattice
        a2 = ang * 13 / math.tau - lr * 4.2
        dot = (int(math.floor(a1 * 2.0)) + int(math.floor(a2 * 2.0))) % 2 == 0
        if rr < 0.36:
            return DISC_DARK if dot else DISC_CORE
        return DISC_BROWN if dot else DISC_DARK
    sp = SEPAL_DRY if dry else SEPAL
    group = "body_nl"
    s, u = disc_face(m, c, f, up, disc_r, 3 if far else 9, 12 if far else 32, seeds, group,
                     dome=1.0 if far else 2.0, depth=depth, far=far, sepal=sp)
    # bracts: a row at the rim peeking between the petals + a row lower on the calyx (seen from behind)
    bract_ring(m, c, f, s, u, 10 if far else 18, disc_r * 0.8, disc_r * (1.3 if dry else 1.5), 0.6, 2.2, 1.7, group, 0.25, rng, sp)
    if not far:
        bract_ring(m, c, f, s, u, 14, disc_r * 0.6, disc_r * 1.18, 2.8, 4.6, 1.5, group, 0.0, rng, sp)
    if dry:
        petal_ring(m, c, f, s, u, 12 if far else 18, disc_r * 0.9, HEAD_R * 0.64, 2.7, (DRY, "8a5e30"),
                   -0.15, group, rng, pts_n=3 if far else 4, jitter=0.25, curl=0.9, twist=0.0 if far else 0.9,
                   bend=0.0 if far else 0.12, back=0.3)
    else:
        # back row: long, gold; front row: shorter, lighter yellow, offset half a petal. Wider + fewer than before
        # so the ring reads as soft petals instead of a spiky dish.
        petal_ring(m, c, f, s, u, 13 if far else 20, disc_r * 0.84, HEAD_R * 1.0, 3.5 if far else 3.4, (GOLD, AMBER),
                   0.14, group, rng, pts_n=3 if far else 5, jitter=0.14, curl=0.1, twist=0.0 if far else 0.55,
                   bend=0.0 if far else 0.1, back=0.5)
        petal_ring(m, c, f, s, u, 11 if far else 20, disc_r * 0.88, HEAD_R * 0.84, 3.1 if far else 3.0, (YELLOW, GOLD),
                   0.22, group, rng, phase=0.5, pts_n=3 if far else 5, jitter=0.14, curl=0.06,
                   twist=0.0 if far else 0.45, bend=0.0 if far else 0.08, back=0.1)
    # the neck: from the crook (pivot, on the stalk axis) curving into the calyx; tapers, then flares into the head
    nr = [STALK_R1, STALK_R1 * 0.95, STALK_R1 * 0.9, STALK_R1 * 0.88, STALK_R1 * 0.9, STALK_R1 * 1.05, STALK_R1 * 1.35]
    stube(m, neck, nr, seg=5 if far else 9, group=group, color=STALK[0])
    return m


def build_sunflower():
    ps = PartSet("giant_sunflower")
    pivot = V(0, 0, H)                    # the head part pivots at the crook: the view yaws head + neck about the stalk
    ps.add("stalk", build_stalk(False))
    ps.add("stalk__far", build_stalk(True))
    ps.add("leaves", build_leaves(False))
    ps.add("leaves__far", build_leaves(True))
    for dry in (False, True):
        nm = "head_dry" if dry else "head"
        ps.add(nm, build_head(False, dry), pivot)
        ps.add(nm + "__far", build_head(True, dry), pivot)
    tris = ps.export(OUT)
    near = tris.get("stalk", 0) + tris.get("leaves", 0) + max(tris.get("head", 0), tris.get("head_dry", 0))
    far = tris.get("stalk__far", 0) + tris.get("leaves__far", 0) + max(tris.get("head__far", 0), tris.get("head_dry__far", 0))
    print("  giant_sunflower near %d (<= 6000) far %d (<= 1200) %s" % (near, far, tris))
    assert near <= 6000 and far <= 1200, "landmark budget"


def build_cotton():
    ps = PartSet("cotton_bush")
    m = Model("cotton_bush", 21)
    for (x, y, z, r) in ((0, 0, 1.8, 2.2), (1.6, 0.6, 1.4, 1.6), (-1.5, 0.4, 1.3, 1.5), (0.2, -1.4, 1.2, 1.4)):
        m.sphere(r, pos=(x, y, z), scl=(1, 1, 0.8), color=LEAF[0], seg=8, rings=5, group="body",
                 colfn=lambda fc: LEAF[2] if fc.normal.z > 0.5 else (LEAF[0] if fc.normal.z > -0.2 else LEAF[1]), lumps=0.12, seed=x)
    ps.add("bush", m)
    b = Model("cotton_boll", 22)
    for (x, y, z, r) in ((0, 0, 3.9, 1.5), (1.0, 0.4, 3.6, 1.1), (-0.9, 0.5, 3.6, 1.1), (0.1, -0.9, 3.7, 1.0)):
        b.sphere(r, pos=(x, y, z), color="f6f1e4", seg=8, rings=5, group="body",
                 colfn=lambda fc: "fbf7ec" if fc.normal.z > 0.3 else "e6dfcc", lumps=0.15, seed=int(x * 10))
    b.cyl(0.9, 1.3, 0.6, pos=(0, 0, 2.6), color="8a6a3a", seg=6, group="body")
    ps.add("boll", b)
    ps.export(OUT)


def build_seed():
    m = Model("sunflower_seed", 31)
    faces = m.sphere(1.0, pos=(0, 0, 0.55), scl=(1.25, 0.6, 0.45), color="3a3430", seg=12, rings=6, group="body",
                     colfn=lambda fc: ("e8e0cc" if int((fc.calc_center_median().y + 0.6) * 4.0) % 2 else "3a3430"))
    # pointed tip
    bm = m._bm("body")
    for v in {v: True for f in faces for v in f.verts}:
        if v.co.x > 0.3:
            v.co.x += (v.co.x - 0.3) * 0.6
            v.co.y *= 0.8
    bm.normal_update()
    n = m.export(OUT)
    print("  sunflower_seed %d tris" % n)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("sunflower ->", OUT)
    build_sunflower()
    build_cotton()
    build_seed()
