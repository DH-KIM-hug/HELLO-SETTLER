"""The giant sunflower (design/gdd/flower-forest.md R3, ROADMAP F-2) + the cotton bush (R4) + a fallen sunflower seed.
Scale: 1 unit = one adult resident (the view scales the sunflower by SunflowerView.SCALE).

giant_sunflower.glb (PartSet, read with Art.parts):
  stalk        thick green column with fibre bands + leaf collars, pivot at the foot (0,0,0)
  leaves       big heart leaves hanging from the stalk (pivot at the foot)
  head         seed disc + double petal ring + green back; pivot = head centre (the view yaws it toward the lamp).
               The face looks along -Y (Blender) = +Z (Godot), tilted up TILT deg toward the lamp. Layered cupped petals (2 yellows, varied lengths), green sepal ring, spiral seed disc.
  head_dry     the same disc, brown petals curled back (autumn droop / winter)
Every part also has "<part>__far" (art bible 8.7 landmark budget: near <= 6,000 body tris, far <= 1,200).
cotton_bush.glb: bush (leaf cushion) + boll (a white cotton puff bigger than a resident, autumn) as parts.
sunflower_seed.glb: one striped seed lying on the ground (~2.4 long), the thing children run to.
Run: blender -b --factory-startup --python build_sunflower.py -- [out_dir]
"""
import math
import os
import sys

import bmesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, PartSet, Vector, shade, mix, out_dir_from_argv  # noqa: E402
from flora_kit import V, leaf  # noqa: E402
from build_bonsai import stube  # noqa: E402

OUT = os.path.join(out_dir_from_argv(), "flora")
H = 85.0                      # stalk height (model units; x SunflowerView.SCALE 0.6 = ~51 residents, GD 3.0 40-60x)
HEAD_R = 36.0                 # seed disc + petals radius (x0.6 = ~21.6 -> head ~43 residents across, a village square; 1.5x on 2026-11-08)
STALK_R0 = 4.6                # stalk radius at the foot (x0.6 = 2.8 -> ~5.5 residents wide: thicker than anything in the village)
STALK_R1 = 2.9                # ... under the head
TILT = 58.0                   # head face elevation (deg): toward the lamp above; low enough that turning to the lamp reads from the 48 deg camera
LEAF_SPEC = ((0.20, 0.4, 24.0, 9.0), (0.33, 2.6, 22.0, 8.4), (0.46, 4.6, 20.0, 7.6), (0.60, 1.4, 17.0, 6.6), (0.73, 3.6, 14.0, 5.4))
# (height fraction, azimuth rad (Blender XY), length, half width) -- mirrored in SunflowerView.LEAVES for the leaf shadows
STALK = ("6f9a48", "5a8240", "86b058")
LEAF = ("6aa04c", "4f8a40", "8cc062")
GOLD = "f2c23a"
YELLOW = "f7d65a"
DISC_DARK = "6e4426"
DISC_BROWN = "94622e"
DRY = "a8783e"


def stalk_pts(n):
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append(V(1.2 * math.sin(t * 2.2) * t, 0.6 * math.sin(t * 3.1) * t, H * t))
    return pts


def build_stalk(far):
    m = Model("sf_stalk" + ("_far" if far else ""), 11)
    n = 6 if far else 16
    pts = stalk_pts(n)
    radii = [STALK_R0 - (STALK_R0 - STALK_R1) * (i / n) ** 0.7 for i in range(n + 1)]
    radii[0] = STALK_R0 * 1.25                    # root flare

    def col(i, k, N):
        if far:
            return STALK[0] if k % 2 == 0 else STALK[1]
        if i % 4 == 3:
            return STALK[2] if k % 2 == 0 else mix(STALK[2], STALK[0], 0.5)   # leaf collar band
        return STALK[0] if k % 2 == 0 else STALK[1]                          # ridge / groove stripes
    # near: 14 ridges (alternate verts pulled in -> fluted column that reads as a plant stalk even when flat-lit)
    stube(m, pts, radii, seg=6 if far else 14, group="body_nl", colfn=col,
          wobble=None if far else (lambda i, k: 1.0 if k % 2 == 0 else 0.86))   # no crease lines: the near stalk fades/cuts with height
    return m


def heart(m, base, az, ln, w, droop, group):
    d = V(math.cos(az), math.sin(az), 0)
    pts = []
    widths = []
    n = 5
    for i in range(n + 1):
        t = i / n
        p = base + d * (ln * t) + V(0, 0, ln * (0.25 * t - droop * t * t))
        pts.append(p)
        widths.append(w * math.sin(math.pi * min(1.0, t * 1.15)) * (1.0 if t < 0.9 else 0.4))
    widths[-1] = 0.0
    nrm = [V(0, 0, 1) - d * (0.6 * droop * (i / n)) for i in range(n + 1)]
    leaf(m, pts, widths, nrm, thick=0.35, color=LEAF[0], color_under=LEAF[1], group=group)


def build_leaves(far):
    m = Model("sf_leaves" + ("_far" if far else ""), 12)
    pts = stalk_pts(16)
    spec = LEAF_SPEC[:3] if far else LEAF_SPEC
    for (z, az, ln, w) in spec:
        p = pts[int(round(z * 16))]
        d = V(math.cos(az), math.sin(az), 0)
        r = STALK_R0 - (STALK_R0 - STALK_R1) * z ** 0.7
        heart(m, p + d * (r * 0.8), az, ln, w, 0.55, "body_nl")
    return m


SEPAL = ("4f8a40", "6aa04c")
DISC_GREEN = "8c9a3e"          # green-ish heart of the seed disc (unopened florets)
DISC_OLIVE = "7a6a2c"


def disc_face(m, c, f, up, r, rings, seg, colfn, group, dome=1.0):
    """Domed seed disc facing f (closed: front dome + green convex back). Ring radii are packed toward the rim
    (sqrt spacing) so the spiral pattern keeps roughly square cells."""
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
    # green back: one mid ring + apex (a shallow cup, the calyx)
    bseg = max(8, seg // 2)
    mid = [bm.verts.new(c - f * 1.3 + (s * math.cos(a) + u * math.sin(a)) * r * 0.72)
           for a in [k * math.tau / bseg for k in range(bseg)]]
    back = bm.verts.new(c - f * 2.4)
    backf = []
    step = seg // bseg
    for k in range(bseg):
        kk = (k + 1) % bseg
        rim = [ring_v[-1][(k * step + i) % seg] for i in range(step + 1)]
        backf.append(bm.faces.new([mid[k], mid[kk]] + list(reversed(rim))))
        backf.append(bm.faces.new((back, mid[kk], mid[k])))
    bmesh.ops.recalc_face_normals(bm, faces=faces + backf)
    bm.normal_update()
    m._finish(bm, faces, None, True, colfn)
    m._finish(bm, backf, SEPAL[0], True)
    return s, u


def petal_ring(m, c, f, s, u, n, r0, r1, w, colors, cup, group, rng, phase=0.0, pts_n=5, jitter=0.1, curl=0.0):
    """One layer of petals. Each petal: varied length (+-jitter), small angle jitter, rises toward f (cup) and the tip
    may roll back (curl). Pointed lanceolate outline; colour picked per petal from colors (weighted to the first)."""
    for i in range(n):
        a = (i + phase + rng.uniform(-0.12, 0.12)) * math.tau / n
        d = s * math.cos(a) + u * math.sin(a)
        ln = (r1 - r0) * (1.0 + rng.uniform(-jitter, jitter))
        cp = cup * (1.0 + rng.uniform(-0.35, 0.35))
        pts = []
        nrm = []
        for j in range(pts_n):
            t = j / (pts_n - 1)
            rise = cp * ln * (t ** 1.2) - curl * ln * (t ** 3)
            pts.append(c + d * (r0 + ln * t) + f * rise)
            slope = cp * 1.2 * t ** 0.2 - curl * 3.0 * t * t
            nrm.append((f - d * slope).normalized())
        if pts_n == 5:
            widths = [w * 0.35, w * 0.95, w, w * 0.62, 0.0]
        elif pts_n == 4:
            widths = [w * 0.4, w, w * 0.7, 0.0]
        else:
            widths = [w * 0.5, w, 0.0]
        col = colors[0] if rng.random() > 0.18 else colors[-1]
        leaf(m, pts, widths, nrm, thick=0.18, color=col, color_under=shade(col, 0.86), group=group)


def build_head(far, dry):
    m = Model("sf_head" + ("_dry" if dry else "") + ("_far" if far else ""), 13)
    import random
    rng = random.Random(1307 + (1 if dry else 0) + (2 if far else 0))
    c = V(0, 0, 0)
    tilt = math.radians(TILT)
    f = V(0, -math.cos(tilt), math.sin(tilt))          # faces -Y, tilted up toward the lamp
    up = V(0, 0, 1)
    disc_r = HEAD_R * 0.42
    s0 = f.cross(up).normalized()
    u0 = s0.cross(f).normalized()

    def seeds(fc):
        p = fc.calc_center_median() - c
        q = p - f * p.dot(f)
        rr = q.length / disc_r
        if dry:
            return DISC_DARK if rr > 0.86 or rr < 0.2 else (DISC_BROWN if (int(rr * 7) % 2) else DISC_DARK)
        if rr < 0.2:
            return DISC_GREEN
        if rr < 0.3:
            return DISC_OLIVE
        if rr > 0.9:
            return DISC_DARK
        if far:
            return DISC_BROWN if rr < 0.62 else DISC_DARK
        ang = math.atan2(q.dot(u0), q.dot(s0))
        lr = math.log(max(rr, 0.05))
        a1 = ang * 8 / math.tau + lr * 2.6          # two crossing log spirals (8 and 13 arms) -> florets in a lattice
        a2 = ang * 13 / math.tau - lr * 4.2
        dot = (int(math.floor(a1 * 2.0)) + int(math.floor(a2 * 2.0))) % 2 == 0
        return DISC_BROWN if dot else DISC_DARK
    group = "body_nl"
    s, u = disc_face(m, c, f, up, disc_r, 3 if far else 9, 12 if far else 32, seeds, group, dome=0.4 if far else 1.0)
    # sepal ring: green pointed bracts behind the petals, peeking out between them
    ns = 10 if far else 20
    for i in range(ns):
        a = (i + 0.25) * math.tau / ns
        d = s * math.cos(a) + u * math.sin(a)
        r0, r1 = disc_r * 0.75, disc_r * (1.5 if far else 1.55 + 0.12 * (i % 2))
        pts = [c - f * 1.0 + d * r0, c - f * 1.1 + d * (r0 + (r1 - r0) * 0.5), c - f * 1.6 + d * r1]
        col = SEPAL[i % 2]
        leaf(m, pts, [1.6, 1.4, 0.0], f, thick=0.25, color=col, color_under=shade(col, 0.85), group=group)
    if dry:
        petal_ring(m, c - f * 0.3, f, s, u, 14 if far else 22, disc_r * 0.88, HEAD_R * 0.8, 1.7, (DRY, "8a5e30"),
                   -0.25, group, rng, pts_n=3 if far else 4, jitter=0.2, curl=0.5)
    else:
        # back layer: long, gold; front layer: shorter, lighter yellow, offset half a petal
        petal_ring(m, c - f * 0.45, f, s, u, 15 if far else 24, disc_r * 0.86, HEAD_R * 1.0, 2.5, (GOLD, YELLOW),
                   0.16, group, rng, pts_n=3 if far else 5, jitter=0.1, curl=0.06)
        petal_ring(m, c - f * 0.1, f, s, u, 13 if far else 22, disc_r * 0.88, HEAD_R * 0.8, 2.2, (YELLOW, GOLD),
                   0.26, group, rng, phase=0.5, pts_n=3 if far else 5, jitter=0.12, curl=0.04)
    # the neck: a short bent stalk piece from the head back down to the column (pivot = head centre)
    neck = [c - f * 2.0, c - f * 3.4 - up * 1.4, c - f * 3.8 - up * 4.0]
    stube(m, neck, [STALK_R1 * 0.95, STALK_R1 * 0.95, STALK_R1], seg=6 if far else 10, group=group, color=STALK[0])
    return m


def build_sunflower():
    ps = PartSet("giant_sunflower")
    head_c = (stalk_pts(16)[-1] + V(0, 3.6 * math.cos(math.radians(TILT)), 4.0 - 3.6 * math.sin(math.radians(TILT))))
    ps.add("stalk", build_stalk(False))
    ps.add("stalk__far", build_stalk(True))
    ps.add("leaves", build_leaves(False))
    ps.add("leaves__far", build_leaves(True))
    for dry in (False, True):
        nm = "head_dry" if dry else "head"
        mm = build_head(False, dry)
        mf = build_head(True, dry)
        for mdl in (mm, mf):
            for bm in mdl.groups.values():
                bmesh.ops.translate(bm, verts=bm.verts, vec=head_c)
        ps.add(nm, mm, head_c)
        ps.add(nm + "__far", mf, head_c)
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
