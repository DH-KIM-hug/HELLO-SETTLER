"""The five great trees of the small world (GAME_DESIGN 3.0, ROADMAP E3-2 / E3-11 / A27; art bible 3.4, 4.3, 6.4, 8)
+ the great fallen fruit. Bonsai-shaped: thick bent trunks, exposed roots, layered foliage. One of each per world, never cut.
Scale: 1 unit = one adult resident (the view scales trees by FloraLook.GREAT_SCALE 0.6).
Heights (model units): ginkgo ~90, pine ~57 (leaning), cherry ~55, maple ~45 (widest), fruit tree ~50 (broad).

Silhouettes (art bible 6.4 + ROADMAP Q41 2026-11-14 "큰 나무 모양 ... 달랐으면" - each must read on its own from the whole world):
  pine   = the only LEANING, windswept tree: S-bent craggy trunk, long thin dark blue-green pads streaming downwind,
           comb rims, roots gripping a mossy boulder
  fruit  = short stout trunk, one BROAD ROUND crown wider than tall, big fruits studded on it; CREAM-WHITE blossom in spring
  ginkgo = the only upright tree: tall straight bare trunk, crown opening upwards like a fan (narrow V, widest at the top)
  maple  = low and WIDE: a vase of smooth stems running out level, star-edged (five-lobed) layers (star edge = maple only)
  cherry = WEEPING: banded trunk, soft cloud dome with long drooping twig curtains strung with blossom tassels (spring),
           green + cherries (summer), orange (autumn), bare hanging twigs (winter)

Output: godot/art/models/flora/tree_<kind>.glb, one part set per tree (read with Art.parts). Every part pivots at the
trunk foot (0,0,0). Colour variants share the exact same geometry, so the view only picks which parts to show per season:
  tree_pine   trunk · foliage (summer/autumn) · foliage_spring (light-green new tips) · foliage_winter (frost on top)
  tree_fruit  trunk · foliage · foliage_bloom (cream-white) · foliage_autumn · fruit (ripe) · fruit_green · fruit_dry (one)
  tree_ginkgo trunk · foliage_spring · foliage · foliage_autumn (yellow)  (the fallen yellow carpet = ring_ginkgo ground decal)
  tree_maple  trunk · foliage_spring (red-tinged) · foliage · foliage_autumn (red hands) · seeds (winged, winter)
  tree_cherry trunk · blossom (pink clouds + drifting petals) · foliage · foliage_autumn (orange) · cherries (summer)
  Winter = trunk only (+ frost / seeds / one dried fruit) - the bare branches carry the silhouette.
Every part also has a far LOD node "<part>__far" (art bible 8.3/8.7: <= 1,200 tris for the shown set, no crease lines,
never hidden). Node names: "<part>" (group body - creases), "<part>_body_nl" (hull only), Art.parts merges them.
Budgets (art bible 8.7): near body <= 6,000 / crease lines <= 800 for any season set; far <= 1,200.
All big-nature surfaces are closed and smooth-shaded (no caps, no hard edges -> almost no crease lines; the inverted
hull draws the outline). The table printed at the end lists the worst season set per tree.
great_fruit / great_fruit_cut: a fallen fruit (~3.5 across) residents carry in teams / cut open (plain Model).
Run: blender -b --factory-startup --python build_bonsai.py -- [out_dir]
"""
import math
import os
import sys

import bmesh
from mathutils import Matrix, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, PartSet, Vector, shade, mix, out_dir_from_argv  # noqa: E402
from flora_kit import V, bezier, tube, leaf, fan_leaf, star_leaf, _frames  # noqa: E402

OUT = os.path.join(out_dir_from_argv(), "flora")
BUILT = []

# palettes: (top, flank, belly) - two tones + a belly shade (smooth toon terminator does the rest)
PAL = {
    "pine": ("467a70", "33625c", "244a47"),                  # dark blue-green (Q41: darkest, bluest crown of the five)
    "pine_spring": ("8fbf7c", "3a6a60", "244a47"),            # light-green new tips on top
    "pine_winter": ("e3eeea", "62887e", "244a47"),           # frost #E3EEEA (mint white, not pure white)
    "fruit": ("86cf86", "58ad78", "3a8a6c"),
    "fruit_bloom": ("f8f0dc", "ece0c2", "a9c48e"),           # cream-white blossom over leaf-green belly
    "fruit_autumn": ("c6cf6c", "9cb45a", "6f9050"),
    "ginkgo_spring": ("cfe68a", "a8d070", "7cae5c"),
    "ginkgo": ("a4cf64", "7fb456", "5a9248"),
    "ginkgo_autumn": ("f6d84a", "f1c93a", "c99a2c"),          # 은행 #F1C93A
    "maple_spring": ("d88a66", "a8a05e", "6f8a4e"),
    "maple": ("8ccc70", "62ad5c", "418a4e"),
    "maple_autumn": ("e0664a", "c9452e", "8e2c28"),           # 단풍 #C9452E
    "cherry": ("8cc878", "5fa66a", "3f8358"),
    "cherry_blossom": ("fad2dc", "f2b8c6", "d690a6"),         # 벚꽃 #F2B8C6
    "cherry_autumn": ("f4a654", "e27e3a", "b4582e"),
}
BARK = {"pine": "64463a", "fruit": "7a5e4a", "ginkgo": "8e8070", "maple": "8c7a6c", "cherry": "7a4a46"}
FRUIT = ("f39a5a", "f6c065", "e0703f")       # peach skin, blush light, blush dark
FRUIT_GREEN = ("a6cc62", "c4dc78", "86b452")
CHERRY_RED = "7e2232"
CHERRY_GREEN = "9cc860"


# ───────────── smooth closed shapes ─────────────
def stube(m, pts, radii, seg=8, group="body", colfn=None, color="7a5e4a", wobble=None, twist=0.0):
    """Closed smooth tube: rings + one apex vertex at each end (no flat caps -> no crease lines, one smooth normal
    field). colfn(i, k, n_rings) -> colour of the quad between ring i and i+1 at segment k."""
    bm = m._bm(group)
    fr = _frames(pts)
    N = len(pts)
    rings = []
    for i, (p, (t, n, b)) in enumerate(zip(pts, fr)):
        r = radii[i]
        ring = []
        for k in range(seg):
            a = k * math.tau / seg + twist * i
            w = wobble(i, k) if wobble else 1.0
            ring.append(bm.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * r * w))
        rings.append(ring)
    faces = []
    cols = []
    for i in range(N - 1):
        for k in range(seg):
            j = (k + 1) % seg
            faces.append(bm.faces.new((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k])))
            cols.append(colfn(i, k, N) if colfn else color)
    a0 = bm.verts.new(pts[0] - fr[0][0] * radii[0] * 0.35)
    a1 = bm.verts.new(pts[-1] + fr[-1][0] * radii[-1] * 0.6)
    for k in range(seg):
        j = (k + 1) % seg
        faces.append(bm.faces.new((a0, rings[0][j], rings[0][k])))
        cols.append(colfn(0, k, N) if colfn else color)
        faces.append(bm.faces.new((a1, rings[-1][k], rings[-1][j])))
        cols.append(colfn(N - 2, k, N) if colfn else color)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    bm.normal_update()
    lay = bm.loops.layers.float_color["Color"]
    from lowpoly import _lin
    for f, c in zip(faces, cols):
        lc = _lin(c) + (1.0,)
        for l in f.loops:
            l[lay] = lc
        f.smooth = True
    return faces


def cushion(m, c, rx, ry, rz, pal, seg=16, rings=6, rot=0.0, tilt=None, lumps=0.1, seed=0, flat=0.4, rim=None,
            group="body_nl", tip=None):
    """Closed smooth foliage cushion (lat-long sphere, flattened belly, noise lumps). rim(phi, a) -> radial factor
    (comb teeth, hand lobes). tilt = 3x3 Matrix applied before rot/translate. pal = (top, flank, belly);
    tip = optional colour for the outermost rim faces (new shoots, frost edge)."""
    bm = m._bm(group)
    cs, sn = math.cos(rot), math.sin(rot)
    off = Vector((seed * 3.1 + 0.37, seed * 7.3 + 0.11, seed * 1.7 + 0.53))

    def place(d, rf):
        n = noise.noise(d * 1.3 + off) if lumps > 0 else 0.0
        d = d * (1.0 + lumps * n)
        x, y, z = d.x * rf, d.y * rf, d.z
        if z < -flat:
            z = -flat - (z + flat) * 0.2
        p = Vector((x * rx, y * ry, z * rz))
        if tilt is not None:
            p = tilt @ p
        return Vector((c[0] + p.x * cs - p.y * sn, c[1] + p.x * sn + p.y * cs, c[2] + p.z))

    top = bm.verts.new(place(Vector((0, 0, 1)), 1.0))
    bot = bm.verts.new(place(Vector((0, 0, -1)), 1.0))
    ring_v = []
    hs = []
    for j in range(1, rings):
        phi = math.pi * j / rings
        row = []
        for k in range(seg):
            a = k * math.tau / seg
            d = Vector((math.sin(phi) * math.cos(a), math.sin(phi) * math.sin(a), math.cos(phi)))
            row.append(bm.verts.new(place(d, rim(phi, a) if rim else 1.0)))
        ring_v.append(row)
        hs.append(math.cos(phi))
    faces = []
    info = []                        # (height of the band centre, is rim band)
    for k in range(seg):
        j = (k + 1) % seg
        faces.append(bm.faces.new((top, ring_v[0][k], ring_v[0][j])))
        info.append((1.0, False, k))
        faces.append(bm.faces.new((bot, ring_v[-1][j], ring_v[-1][k])))
        info.append((-1.0, False, k))
    for r in range(len(ring_v) - 1):
        for k in range(seg):
            j = (k + 1) % seg
            faces.append(bm.faces.new((ring_v[r][k], ring_v[r + 1][k], ring_v[r + 1][j], ring_v[r][j])))
            hm = (hs[r] + hs[r + 1]) * 0.5
            info.append((hm, abs(hm) < 0.3, k))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    bm.normal_update()
    lay = bm.loops.layers.float_color["Color"]
    from lowpoly import _lin
    for f, (h, is_rim, k) in zip(faces, info):
        if h > 0.35:
            col = pal[0]
        elif h < -0.2:
            col = pal[2]
        else:
            col = pal[1]
        if tip is not None and is_rim and h >= 0.0:
            col = tip
        lc = _lin(col) + (1.0,)
        for l in f.loops:
            l[lay] = lc
        f.smooth = True
    return faces


def comb(seg, amp=0.18):
    """Pine cushion rim: every other rim vertex pushed out = seg/2 fine needle teeth round the equator
    (small, many, even - no star points). seg must be the cushion's own segment count."""
    def f(phi, a):
        w = max(0.0, 1.0 - abs(phi - math.pi / 2) / 0.8)
        k = int(round(a / math.tau * seg))
        return 1.0 + amp * w * (1.0 if k % 2 == 0 else -0.45)
    return f


def lobes(n=5, amp=0.42, sharp=2.2):
    """Maple cushion rim: five big pointed hand lobes."""
    def f(phi, a):
        w = max(0.0, 1.0 - abs(phi - math.pi / 2) / 1.1) ** 0.8
        u = (a * n / math.tau) % 1.0
        peak = (1.0 - abs(2 * u - 1)) ** sharp          # 1 at the lobe tip, 0 in the notch
        return 1.0 + amp * w * (peak - 0.35)
    return f


# ───────────── tree assembly ─────────────
class Tree:
    """Trunk tubes and crown lumps are recorded once, then rendered near (full detail) and far (low detail),
    and the crown once per colour variant (identical geometry)."""

    def __init__(self, name, kind, seed):
        self.name = name
        self.kind = kind
        self.seed = seed
        self.bark = BARK[kind]
        self.tubes = []          # (pts, radii, seg, minor, colfn)
        self.lumps = []          # dict(c, rx, ry, rz, rot, tilt, seed, seg, rings, rim_n, flat, lumps, far, rim_fn_far)
        self.extra = {}          # part name -> (near Model builder, far builder or None)
        self.leaves = None       # near-only leaf sprinkling: fn(model, pal)
        self.trunk_extra = None  # fn(model, far) - extra always-shown geometry in the trunk part (pine boulder)
        import random
        self.rng = random.Random(seed)

    # -- trunk --
    def tube(self, pts, radii, seg=8, minor=False, colfn=None, wobble=0.1, wseed=0.0):
        self.tubes.append((pts, radii, seg, minor, colfn, wobble, wseed))

    def path(self, ctrl, n=10):
        pts = []
        for a, b, c, d in [ctrl[i:i + 4] for i in range(0, len(ctrl) - 3, 3)]:
            seg_pts = bezier(V(*a), V(*b), V(*c), V(*d), n)
            pts += seg_pts if not pts else seg_pts[1:]
        return pts

    def trunk(self, ctrl, r0, r1, n=10, seg=12, colfn=None, flare=0.5):
        pts = self.path(ctrl, n)
        N = len(pts)
        radii = []
        for i in range(N):
            t = i / (N - 1)
            r = r0 + (r1 - r0) * t ** 0.8
            r *= 1.0 + flare * max(0.0, 1 - t * 6) ** 2
            radii.append(r)
        pts[0] = pts[0] - V(0, 0, 1.5)             # foot sunk into the ground
        self.tube(pts, radii, seg=seg, colfn=colfn, wobble=0.12, wseed=self.seed)
        self.tpts, self.trad = pts, radii
        return pts

    def at(self, t, pts=None, rad=None):
        pts = pts or self.tpts
        rad = rad or self.trad
        f = t * (len(pts) - 1)
        i = min(len(pts) - 2, int(f))
        return pts[i].lerp(pts[i + 1], f - i), rad[i] + (rad[i + 1] - rad[i]) * (f - i)

    def roots(self, n, spread, arch, r_k=0.5, seg=7, minor_from=3):
        r0 = self.trad[0]
        for i in range(n):
            a = i * math.tau / n + self.rng.uniform(-0.3, 0.3)
            d = V(math.cos(a), math.sin(a), 0)
            k = self.rng.uniform(0.5, 1.0) if i % 2 else self.rng.uniform(0.8, 1.1)
            ln = spread * k
            p0 = d * r0 * 0.3 + V(0, 0, r0 * 0.55)
            p3 = d * (r0 + ln) + V(0, 0, -1.2)
            side = V(-d.y, d.x, 0) * self.rng.choice((-1, 1)) * self.rng.uniform(0.2, 0.4) * ln
            pts = bezier(p0, p0 + d * r0 * 0.9 + V(0, 0, arch * k * 0.2), p0 + d * (r0 + ln * 0.5) + side + V(0, 0, arch * k),
                         p3 + side * 0.6, 5)
            rr = [r0 * r_k * k ** 0.5 * (1 - 0.8 * (j / 5) ** 0.8) + 0.25 for j in range(6)]
            self.tube(pts, rr, seg=seg, minor=i >= minor_from, wobble=0.08, wseed=i + self.seed)

    def branch(self, t, az, ln, rise, r_k=0.42, droop=0.15, seg=7, tip_k=0.35, minor=False, base=None, n=5, colfn=None):
        p0, r = self.at(t) if base is None else base
        d = V(math.cos(az), math.sin(az), 0)
        p3 = p0 + d * ln + V(0, 0, rise)
        pts = bezier(p0, p0 + d * ln * 0.35 + V(0, 0, rise * 0.55 + ln * 0.06), p0 + d * ln * 0.7 + V(0, 0, rise * 0.9 - ln * droop),
                     p3, n)
        rb = r * r_k
        self.tube(pts, [rb * (1 - (1 - tip_k) * j / n) for j in range(n + 1)], seg=seg, minor=minor, colfn=colfn,
                  wobble=0.07, wseed=az * 3 + self.seed)
        return p3, d, pts, [rb * (1 - (1 - tip_k) * j / n) for j in range(n + 1)]

    def lump(self, c, rx, ry, rz, rot=0.0, tilt=None, seg=16, rings=6, rim=None, rim_far=None, flat=0.4, lumps=0.1,
             far=True, far_seg=8, far_rings=4, far_k=1.0):
        self.lumps.append(dict(c=Vector(c), rx=rx, ry=ry, rz=rz, rot=rot, tilt=tilt, seed=len(self.lumps) + self.seed % 7,
                               seg=seg, rings=rings, rim=rim, rim_far=rim_far, flat=flat, lumps=lumps, far=far,
                               far_seg=far_seg, far_rings=far_rings, far_k=far_k))

    # -- render --
    def bark_fn(self, base, style):
        def f(i, k, N):
            if style == "bands":                    # cherry: horizontal lenticel bands
                if i % 3 == 0:
                    return shade(base, 0.72)
                return shade(base, 1.1 if i % 3 == 1 else 1.0)
            if style == "scales":                   # pine: rough plates
                return shade(base, 0.86 if (i + k) % 2 == 0 else (1.06 if (i * 3 + k) % 5 == 0 else 1.0))
            if style == "streak":                   # ginkgo: vertical furrows
                return shade(base, 0.88 if k % 3 == 0 else 1.0)
            return shade(base, 0.95 if (i // 2 + k) % 4 == 0 else 1.0)    # smooth (maple, fruit)
        return f

    def render_trunk(self, far=False, style="smooth"):
        m = Model(self.name + ("_trunk_far" if far else "_trunk"), self.seed)
        grp = "body_nl" if far else "body"
        base_fn = self.bark_fn(self.bark, style)
        for (pts, radii, seg, minor, colfn, wob, ws) in self.tubes:
            if far and minor:
                continue
            fn = colfn or base_fn
            if far:
                idx = list(range(0, len(pts), 2))
                if idx[-1] != len(pts) - 1:
                    idx.append(len(pts) - 1)
                p2 = [pts[i] for i in idx]
                r2 = [radii[i] * 1.08 for i in idx]
                s2 = max(5, seg // 2)
                stube(m, p2, r2, seg=s2, group=grp, colfn=lambda i, k, N, fn=fn, idx=idx: fn(idx[i], k, len(pts)))
            else:
                w = (lambda i, k, ws=ws, wob=wob: 1.0 + wob * math.sin(k * 2.0 + i * 0.9 + ws) + wob * 0.6 * math.sin(k * 5.0 - i * 1.7 + ws * 2))
                stube(m, pts, radii, seg=seg, group=grp, colfn=fn, wobble=w, twist=0.05)
        if self.trunk_extra is not None:
            self.trunk_extra(m, far)
        return m

    def render_crown(self, pal, far=False, tip=None, name="foliage"):
        m = Model(self.name + "_" + name + ("_far" if far else ""), self.seed + 1)
        for L in self.lumps:
            if far and not L["far"]:
                continue
            k = L["far_k"] if far else 1.0
            cushion(m, L["c"], L["rx"] * k, L["ry"] * k, L["rz"] * k, pal,
                    seg=L["far_seg"] if far else L["seg"], rings=L["far_rings"] if far else L["rings"],
                    rot=L["rot"], tilt=L["tilt"], lumps=L["lumps"] * (0.6 if far else 1.0), seed=L["seed"], flat=L["flat"],
                    rim=(L["rim_far"] if far else L["rim"]), tip=tip)
        if not far and self.leaves is not None:
            self.leaves(m, pal)
        return m

    def export(self, parts, sets, style="smooth"):
        """parts: list of (name, near_model_fn, far_model_fn or None). sets: season name -> part names shown."""
        ps = PartSet(self.name)
        ps.add("trunk", self.render_trunk(False, style))
        ps.add("trunk__far", self.render_trunk(True, style))
        for (pn, near_fn, far_fn) in parts:
            ps.add(pn, near_fn())
            if far_fn is not None:
                ps.add(pn + "__far", far_fn())
        tris = ps.export(OUT)
        worst = None
        for se, shown in sets.items():
            near = sum(tris.get(p, 0) for p in ["trunk"] + shown)
            farn = sum(tris.get(p + "__far", 0) for p in ["trunk"] + shown)
            if worst is None or near > worst[1]:
                worst = (se, near, farn)
        far_worst = max(sum(tris.get(p + "__far", 0) for p in ["trunk"] + shown) for shown in sets.values())
        BUILT.append((self.name, worst[0], worst[1], far_worst, tris))


def rim_pts(lumps, n_per, rng, z_lo=-0.1, z_hi=0.45, out=0.95):
    out_l = []
    for L in lumps:
        for i in range(n_per):
            a = i * math.tau / n_per + rng.uniform(-0.25, 0.25)
            d = V(math.cos(a + L["rot"]), math.sin(a + L["rot"]), 0)
            p = L["c"] + V(d.x * L["rx"] * out, d.y * L["ry"] * out, L["rz"] * rng.uniform(z_lo, z_hi))
            out_l.append((p, d))
    return out_l


def tilt_out(az, ang):
    """Rotation tipping local +Z outwards (towards azimuth az) by ang radians."""
    axis = Vector((-math.sin(az), math.cos(az), 0))
    return Matrix.Rotation(ang, 3, axis)


# ───────────── pine: windswept, leaning, flat dark blue-green pads streaming downwind, roots gripping a boulder ─────────────
# (Q41 2026-11-14: each great tree must read on its own - the pine is the only LEANING, ASYMMETRIC tree: wind from -x)
def build_pine():
    t = Tree("tree_pine", "pine", 311)
    t.trunk([(-2, 0, 0), (-6, 0, 9), (2, 0, 16), (8, 0, 22), (14, 0, 28), (13, 0, 36), (22, 0, 42), (30, 1, 46), (36, 1, 50),
             (40, 1, 53)], 6.4, 1.6, n=8, seg=11, flare=0.45)
    t.roots(5, 7, 0.9, r_k=0.55)
    # pads: long thin horizontal clouds, most on the lee (+x) side, a few short stubs to windward; stacked in tiers
    tiers = ((0.28, 0.25, 22, 0, 15.5, 2.4, 1.0), (0.38, 2.75, 9, 1, 8.0, 2.2, 0.6), (0.47, -0.35, 20, 1, 14.0, 2.3, 0.9),
             (0.58, 0.55, 17, 2, 12.5, 2.2, 0.9), (0.66, 3.3, 8, 2, 7.0, 2.0, 0.6), (0.76, -0.45, 15, 2, 11.0, 2.1, 0.85),
             (0.86, 0.6, 12, 2, 10.0, 2.0, 0.8))
    for (tt, az, ln, rise, rx, rz, stream) in tiers:
        e, d, _, _ = t.branch(tt, az, ln, rise, r_k=0.42, droop=0.22, seg=7)
        # a pad is stretched along the wind (+x) and sits a little downwind of its branch end
        c = e + V(rx * 0.3 * stream, 0, 0.6)
        t.lump(c, rx * (1.0 + 0.35 * stream), rx * 0.62, rz, rot=0.0, seg=48, rings=5, rim=comb(48), rim_far=comb(12),
               flat=0.3, lumps=0.06, far_seg=12, far_rings=4)
        if rx > 9:      # a step-pad tucked under the lee end (layered look)
            c2 = c + V(rx * 0.75, (1 if az > 0 else -1) * rx * 0.25, -1.4)
            t.lump(c2, rx * 0.5, rx * 0.36, rz * 0.8, seg=24, rings=4, rim=comb(24), flat=0.3, lumps=0.06, far=False)
    top, _ = t.at(1.0)
    t.lump(top + V(3, 0, 1.6), 11.5, 7.0, 2.4, seg=44, rings=5, rim=comb(44), rim_far=comb(14), flat=0.3,
           far_seg=14, far_rings=4)
    # jin: a dead silver-white stub on the windward side (wind-stripped)
    p, r = t.at(0.62)
    t.tube(bezier(p, p + V(-4, 0, 2), p + V(-8, 1, 5), p + V(-11, 1, 6), 4), [r * 0.5, r * 0.4, r * 0.3, r * 0.2, r * 0.1],
           seg=6, minor=True, colfn=lambda i, k, N: "e2dccd" if k % 2 else "bcb3a3")

    def boulder(m, far):                    # the roots grip a mossy grey boulder (pine = rock + wind)
        g = "body_nl" if far else "body"
        s = 0.6 if far else 1.0
        sub = 1
        m.ico(9.5, pos=(-6, -10, 1.0), scl=(1.3, 1.0, 0.62), color="9a968c", subdiv=sub, group=g, lumps=0.22 * s, seed=4,
              colfn=lambda f: "7f9a62" if f.normal.z > 0.75 else ("aaa69a" if f.normal.x < 0 else "86827a"))
        m.ico(5.0, pos=(6, -12, 0.2), scl=(1.2, 1.0, 0.7), color="9a968c", subdiv=sub, group=g, lumps=0.25 * s, seed=7,
              colfn=lambda f: "7f9a62" if f.normal.z > 0.8 else ("aaa69a" if f.normal.x < 0 else "86827a"))
    t.trunk_extra = boulder
    parts = [
        ("foliage", lambda: t.render_crown(PAL["pine"]), lambda: t.render_crown(PAL["pine"], far=True)),
        ("foliage_spring", lambda: t.render_crown(PAL["pine_spring"], name="foliage_spring"),
         lambda: t.render_crown(PAL["pine_spring"], far=True, name="foliage_spring")),
        ("foliage_winter", lambda: t.render_crown(PAL["pine_winter"], name="foliage_winter"),
         lambda: t.render_crown(PAL["pine_winter"], far=True, name="foliage_winter")),
    ]
    t.export(parts, {"봄": ["foliage_spring"], "여름": ["foliage"], "가을": ["foliage"], "겨울": ["foliage_winter"]},
             style="scales")


# ───────────── fruit tree: short stout trunk, one BROAD ROUND crown (wider than tall), big fruits on it ─────────────
def fruit_ball(m, c, r, group="body", seg=14, rings=9, cols=FRUIT, leaf_on=True):
    """Round peach-like fruit with a blush (shared by the tree and the fallen prop)."""
    def col(f):
        n = f.normal
        blush = 0.5 + 0.5 * (n.x * 0.6 - n.y * 0.5 + n.z * 0.3)
        return mix(cols[1], cols[2], max(0.0, min(1.0, blush)))
    m.sphere(r, pos=c, scl=(1.0, 0.96, 0.92), color=cols[0], seg=seg, rings=rings, group=group, colfn=col)
    if leaf_on:
        tube(m, [c + V(0, 0, r * 0.85), c + V(0.15 * r, 0, r * 1.25)], [r * 0.08, r * 0.06], seg=5, color="6a4a32", group=group)
        leaf(m, [c + V(0.1 * r, 0, r * 1.1), c + V(0.6 * r, -0.2 * r, r * 1.3), c + V(1.1 * r, -0.3 * r, r * 1.15)],
             [0.05 * r, 0.3 * r, 0.0], V(0, 0, 1), thick=0.05 * r, color="5fae6a", group="body_nl")


def build_fruit():
    t = Tree("tree_fruit", "fruit", 321)
    t.trunk([(0, 0, 0), (1.5, 0, 5), (-1.5, 0, 10), (0, 0, 14)], 7.2, 5.0, n=6, seg=12, flare=0.35)
    t.roots(5, 3.5, 0.25, r_k=0.55, minor_from=5)          # no claw roots: a stout foot that just flares
    top, rt = t.at(1.0)
    for i, (az, ln, rise) in enumerate(((0.3, 17, 11), (1.55, 16, 12), (2.8, 17, 10), (4.0, 16, 12), (5.2, 17, 11))):
        e, d, pts, rr = t.branch(1.0, az, ln, rise, r_k=0.66, droop=-0.08, seg=8, tip_k=0.4, base=(top - V(0, 0, 1.0), rt))
        p, r = t.at(0.6, pts, rr)
        t.branch(0, az + 0.7, 8, 4, r_k=0.55, seg=6, base=(p, r), minor=True)
        for da, ln2, up in ((-0.5, 7, 6), (0.45, 6, 7)):          # thin twigs off the limb tip (bare winter crown, not stumps)
            t.branch(0, az + da, ln2, up, r_k=0.5, seg=5, tip_k=0.2, base=(e, rr[-1] * 1.6), minor=True)
    # one broad, smooth, round crown: wide low dome + a ring of rounded shoulders (reads as a single ball from afar)
    cz = 31.0
    t.lump((0, 0, cz + 2), 29, 28, 15, seg=20, rings=8, flat=0.55, lumps=0.06, far_seg=14, far_rings=6)
    for i in range(9):
        a = i * math.tau / 9 + 0.2
        t.lump((math.cos(a) * 24, math.sin(a) * 24, cz - 1 + (i % 2) * 2), 11, 10.5, 8.5, rot=a, seg=12, rings=6,
               flat=0.5, lumps=0.07, far=i % 3 == 0, far_seg=8, far_rings=4)
    # fruits: big and many - studded over the crown's top and front (the camera looks down) + a few hanging under the rim
    spots = []
    for i in range(13):
        a = i * 2.39996 + 0.5
        u = (i + 0.5) / 13
        rr = 26 * math.sqrt(u)
        h = 15 * math.sqrt(max(0.0, 1 - (rr / 30) ** 2))
        spots.append((V(math.cos(a) * rr, math.sin(a) * rr, cz + 2 + h * 0.98), False))
    for i in range(7):
        a = i * math.tau / 7 + 0.35
        spots.append((V(math.cos(a) * 31, math.sin(a) * 31, cz - 7), True))

    def fruits(cols, far=False, scale=1.0, name="fruit"):
        m = Model(name + ("_far" if far else ""), 10)
        for i, (p, hang) in enumerate(spots):
            r = 3.6 * scale
            if far:
                if i % 2:
                    continue
                m.sphere(r * 1.15, pos=p - V(0, 0, 3.6 if hang else 0.6), color=cols[1], seg=5, rings=3, group="body_nl")
                continue
            if hang:
                tube(m, [p + V(0, 0, 0.8), p - V(0, 0, 1.4)], [0.25, 0.2], seg=4, color="6a4a32", group="body_nl")
                fruit_ball(m, p - V(0, 0, 1.4 + r), r, seg=8, rings=6, cols=cols, leaf_on=False, group="body_nl")
            else:
                fruit_ball(m, p, r, seg=8, rings=6, cols=cols, leaf_on=False, group="body_nl")
        return m

    def blossom_dots(far=False):            # spring: cream blossom crown with soft pink-blush flower dots (still cream)
        m = t.render_crown(PAL["fruit_bloom"], far=far, name="foliage_bloom")
        if far:
            return m
        import random
        rng = random.Random(77)
        for i in range(40):
            a = i * 2.39996
            rr = 28 * math.sqrt((i + 0.5) / 40)
            h = 15 * math.sqrt(max(0.0, 1 - (rr / 30) ** 2))
            p = V(math.cos(a) * rr, math.sin(a) * rr, cz + 2.4 + h)
            star_leaf(m, p, V(0, 0, 1), V(math.cos(a), math.sin(a), 0), 1.6, points=5, inner=0.7,
                      color="fffaf0" if i % 3 else "f4dcc8", thick=0.25)
        return m

    def dry():
        m = Model("fruit_dry", 11)
        p = V(20, -8, cz - 6)
        tube(m, [p + V(0, 0, 0.8), p - V(0, 0, 1.4)], [0.2, 0.16], seg=4, color="6a4a32", group="body_nl")
        m.sphere(2.4, pos=p - V(0, 0, 3.6), scl=(1, 0.9, 1.1), color="9a6a44", seg=8, rings=6, group="body_nl",
                 lumps=0.25, seed=3, colfn=lambda f: "a87850" if f.normal.z > 0 else "7a5034")
        return m

    parts = [
        ("foliage", lambda: t.render_crown(PAL["fruit"]), lambda: t.render_crown(PAL["fruit"], far=True)),
        ("foliage_bloom", lambda: blossom_dots(), lambda: blossom_dots(True)),
        ("foliage_autumn", lambda: t.render_crown(PAL["fruit_autumn"], name="foliage_autumn"),
         lambda: t.render_crown(PAL["fruit_autumn"], far=True, name="foliage_autumn")),
        ("fruit", lambda: fruits(FRUIT), lambda: fruits(FRUIT, far=True)),
        ("fruit_green", lambda: fruits(FRUIT_GREEN, scale=0.75, name="fruit_green"),
         lambda: fruits(FRUIT_GREEN, far=True, scale=0.75, name="fruit_green")),
        ("fruit_dry", dry, None),
    ]
    t.export(parts, {"봄": ["foliage_bloom"], "여름": ["foliage", "fruit_green"], "가을": ["foliage_autumn", "fruit"],
                     "겨울": ["fruit_dry"]})


# ───────────── ginkgo: the only upright tree - tall straight trunk, crown opening upwards like a fan ─────────────
def build_ginkgo():
    t = Tree("tree_ginkgo", "ginkgo", 331)
    t.trunk([(0, 0, 0), (1, 0, 20), (-1, 0, 40), (0, 0, 55), (0, 0, 64), (0, 0, 70)], 5.4, 1.8, n=8, seg=11, flare=0.6)
    t.roots(5, 3.0, 0.25, r_k=0.55, minor_from=5)          # buttress flare only (no claw roots)
    ends = []
    n = 10
    for i in range(n):
        az = i * 2.39996 + 0.4
        th = 0.22 + 0.5 * ((i * 0.618) % 1.0)                # 13..41 deg from vertical: a narrow V opening upward
        L = 30 + 6 * ((i * 0.37) % 1.0)
        tt = 0.42 + 0.45 * ((i * 0.53) % 1.0)
        e, d, pts, rr = t.branch(tt, az, L * math.sin(th), L * math.cos(th), r_k=0.48, droop=-0.04, seg=7, tip_k=0.3)
        ends.append((e, az, th, pts, rr))
        q, qr = t.at(0.55, pts, rr)
        t.branch(0, az + 0.6, 3 + 4 * math.sin(th), 8, r_k=0.6, seg=5, tip_k=0.3, base=(q, qr), minor=True)
    # the fan: tall upright lumps along each limb, widest at the top; the lowest third of the trunk stays bare
    for (e, az, th, pts, rr) in ends:
        t.lump(e + V(math.sin(th) * math.cos(az), math.sin(th) * math.sin(az), math.cos(th)) * 2.0, 6.8, 6.0, 12.5,
               rot=az, tilt=tilt_out(0.0, th + 0.1), seg=12, rings=6, flat=0.8, lumps=0.12, far_seg=7, far_rings=3)
        q, _ = t.at(0.55, pts, rr)
        t.lump(q + V(0, 0, 2), 5.0, 4.6, 7.5, rot=az, tilt=tilt_out(0.0, th), seg=10, rings=5, flat=0.8, lumps=0.12,
               far=False)
    top, _ = t.at(1.0)
    t.lump(top + V(0, 0, 6), 7.5, 7.0, 10, seg=12, rings=6, flat=0.6, lumps=0.1, far_seg=8, far_rings=4)

    def leaves(m, pal):                     # fan leaves standing out of the rims (near only)
        import random
        rng = random.Random(51)
        for (p, d) in rim_pts(t.lumps, 2, rng, z_lo=0.0, z_hi=0.6, out=1.0):
            up = (V(0, 0, 1) + d * 0.7).normalized()
            fan_leaf(m, p, up, d, 2.2, color=shade(pal[0], 1.0 if rng.random() > 0.4 else 0.9), thick=0.15, seg=4)
    t.leaves = leaves

    parts = [
        ("foliage_spring", lambda: t.render_crown(PAL["ginkgo_spring"], name="foliage_spring"),
         lambda: t.render_crown(PAL["ginkgo_spring"], far=True, name="foliage_spring")),
        ("foliage", lambda: t.render_crown(PAL["ginkgo"]), lambda: t.render_crown(PAL["ginkgo"], far=True)),
        ("foliage_autumn", lambda: t.render_crown(PAL["ginkgo_autumn"], name="foliage_autumn"),
         lambda: t.render_crown(PAL["ginkgo_autumn"], far=True, name="foliage_autumn")),
    ]
    t.export(parts, {"봄": ["foliage_spring"], "여름": ["foliage"], "가을": ["foliage_autumn"], "겨울": []},
             style="streak")


# ───────────── maple: low, WIDE spreading umbrella of star-edged layers on a vase of smooth stems ─────────────
def build_maple():
    t = Tree("tree_maple", "maple", 341)
    t.trunk([(0, 0, 0), (-1, 0, 8), (-3, 0, 16), (-4, 0, 22), (-3, 0, 28), (-1, 0, 32), (0, 0, 36)], 5.2, 1.6, n=7, seg=9,
            flare=0.4)
    t.roots(4, 4.5, 0.3, r_k=0.55, minor_from=2)
    pads = []
    # three more stems splay out from the foot like a vase, then run out nearly level (spreading crown)
    for (az, lean, h) in ((0.3, 20, 28), (2.4, 19, 26), (4.3, 18, 27)):
        p0, r = t.at(0.1)
        d = V(math.cos(az), math.sin(az), 0)
        pts = bezier(p0, p0 + d * lean * 0.25 + V(0, 0, h * 0.45), p0 + d * lean * 0.7 + V(0, 0, h * 0.9), p0 + d * lean * 1.3 + V(0, 0, h), 8)
        rr = [r * 0.66 * (1 - 0.7 * j / 8) for j in range(9)]
        t.tube(pts, rr, seg=8, wobble=0.06, wseed=az)
        for (tt, da, ln, rise) in ((0.75, 0.9, 13, 3), (0.75, -0.9, 12, 3)):
            e, _, _, _ = t.branch(tt, az + da, ln, rise, r_k=0.5, droop=0.12, seg=6, base=t.at(tt, pts, rr), minor=True)
            pads.append((e, az + da, False))
        pads.append((pts[-1], az, True))
    for (tt, az, ln, rise) in ((0.75, 1.35, 16, 4), (0.8, 3.35, 15, 4), (0.85, 5.3, 15, 4)):
        e, d, _, _ = t.branch(tt, az, ln, rise, r_k=0.45, droop=0.1, seg=7)
        pads.append((e, az, True))
    top, _ = t.at(1.0)
    pads.append((top + V(0, 0, 2), 1.0, True))
    # wide, thin, star-rimmed layers: lower ring wide out, the top one smaller - an umbrella seen from above
    for i, (e, az, big) in enumerate(pads):
        rx = 13.5 if big else 10.5
        t.lump(e + V(0, 0, 2.0), rx, rx * 0.92, 4.0, rot=az + i * 0.4, seg=30, rings=5, rim=lobes(5, 0.48),
               rim_far=lobes(5, 0.48), flat=0.35, lumps=0.06, far=big, far_seg=15, far_rings=3)

    def leaves(m, pal):                     # big hand leaves standing out of the rims and lying on top (star edge, near only)
        import random
        rng = random.Random(41)
        for (p, d) in rim_pts(t.lumps, 3, rng, z_lo=0.0, z_hi=0.5, out=1.05):
            up = (V(0, 0, 1) + d * 0.9).normalized()
            star_leaf(m, p, up, d, 3.0, points=5, inner=0.4, color=shade(pal[0], 1.0 if rng.random() > 0.35 else 0.88),
                      thick=0.18, cup_k=0.15)
    t.leaves = leaves

    def seeds():                            # winter: winged seed pairs left on the bare twigs
        m = Model("seeds", 13)
        import random
        rng = random.Random(9)
        for (e, az, _b) in pads:
            p = e + V(rng.uniform(-3, 3), rng.uniform(-3, 3), rng.uniform(-1, 1))
            for s in (-1, 1):
                d = V(math.cos(az + s * 0.9), math.sin(az + s * 0.9), -0.6).normalized()
                leaf(m, [p, p + d * 1.2, p + d * 2.6], [0.15, 0.5, 0.0], V(0, 0, 1), thick=0.08, color="c4a070",
                     group="body_nl")
        return m

    parts = [
        ("foliage_spring", lambda: t.render_crown(PAL["maple_spring"], name="foliage_spring"),
         lambda: t.render_crown(PAL["maple_spring"], far=True, name="foliage_spring")),
        ("foliage", lambda: t.render_crown(PAL["maple"]), lambda: t.render_crown(PAL["maple"], far=True)),
        ("foliage_autumn", lambda: t.render_crown(PAL["maple_autumn"], name="foliage_autumn"),
         lambda: t.render_crown(PAL["maple_autumn"], far=True, name="foliage_autumn")),
        ("seeds", seeds, None),
    ]
    t.export(parts, {"봄": ["foliage_spring"], "여름": ["foliage"], "가을": ["foliage_autumn"], "겨울": ["seeds"]})


# ───────────── cherry: WEEPING - soft cloud dome with long drooping branch curtains, banded bark ─────────────
def build_cherry():
    t = Tree("tree_cherry", "cherry", 361)
    t.trunk([(0, 0, 0), (3, 0, 10), (8, 0, 18), (11, 0, 26), (12, 0, 34), (10, 0, 42), (8, 0, 48)], 6.0, 2.0, n=8, seg=12,
            flare=0.4)
    t.roots(5, 6, 0.4, r_k=0.45)
    bands = t.bark_fn(t.bark, "bands")
    arch = []
    # limbs arch up and out, then droop: the classic weeping umbrella
    for (tt, az, ln, rise) in ((0.55, 2.7, 22, 9), (0.62, -1.6, 20, 9), (0.7, 1.2, 20, 10), (0.78, 0.0, 22, 7),
                               (0.85, -0.6, 17, 9), (0.9, 3.9, 18, 8), (0.95, 2.0, 14, 10)):
        e, d, _, _ = t.branch(tt, az, ln, rise, r_k=0.46, droop=0.25, seg=7, colfn=bands)
        arch.append((e, az))
    top, _ = t.at(1.0)
    arch.append((top + V(0, 0, 1), 0.5))
    for i, (c, az) in enumerate(arch):      # soft clouds sitting on the arches
        t.lump(c + V(0, 0, 2.5), 10, 9.5, 6.5, rot=az, seg=14, rings=7, flat=0.6, lumps=0.16, far_seg=8, far_rings=4,
               far_k=1.15)
    # weeping curtains: from each arch end hang 3 long thin twigs, blossom tassels strung down them
    import random
    rng = random.Random(17)
    strands = []
    for i, (c, az) in enumerate(arch[:-1]):
        for k in range(2):
            a = az + (k - 0.5) * 0.8 + rng.uniform(-0.15, 0.15)
            o = c + V(math.cos(a), math.sin(a), 0) * rng.uniform(6.5, 9.5) + V(0, 0, 1)
            ln = rng.uniform(17, 25)
            out = V(math.cos(a), math.sin(a), 0)
            t.tube(bezier(c, c + (o - c) * 0.35 + V(0, 0, 1.8), c + (o - c) * 0.75 + V(0, 0, 1.6), o, 3), [0.75, 0.68, 0.6, 0.55],
                   seg=4, minor=True, colfn=lambda i, k, N: "6a4440", wobble=0.0)     # the twig the curtain hangs from
            pts = bezier(o, o + out * 3 + V(0, 0, 1.5), o + out * 4.5 - V(0, 0, ln * 0.5), o + out * 4.2 - V(0, 0, ln), 5)
            t.tube(pts, [0.55, 0.45, 0.38, 0.3, 0.24, 0.18], seg=4, minor=True, colfn=lambda i, k, N: "6a4440",
                   wobble=0.0)
            strands.append(pts)
            for j, u in enumerate((0.3, 0.6, 0.9)):
                f = u * (len(pts) - 1)
                q = pts[int(f)].lerp(pts[min(len(pts) - 1, int(f) + 1)], f - int(f))
                t.lump(q + out * 0.6, 2.6 - j * 0.4, 2.4 - j * 0.4, 5.2, rot=a, seg=6, rings=4, flat=1.0, lumps=0.15,
                       far=(j == 0 and k == 0), far_seg=5, far_rings=3, far_k=1.3)

    def petals(m):                          # drifting petals under the dome + a few on the ground
        rng2 = random.Random(23)
        for k in range(22):
            c, az = arch[k % len(arch)]
            ground = k % 3 == 0
            p = c + V(rng2.uniform(-16, 16), rng2.uniform(-16, 16), 0)
            p.z = rng2.uniform(0.1, 0.3) if ground else max(4.0, c.z - rng2.uniform(6, 28))
            up = V(rng2.uniform(-0.6, 0.6), rng2.uniform(-0.6, 0.6), 1).normalized()
            fwd = V(math.cos(k * 1.7), math.sin(k * 1.7), 0)
            leaf(m, [p, p + fwd * 0.6, p + fwd * 1.3], [0.2, 0.55, 0.05], up, thick=0.08,
                 color=PAL["cherry_blossom"][0 if k % 2 else 1], group="body_nl")

    def blossom(far=False):
        m = t.render_crown(PAL["cherry_blossom"], far=far, name="blossom")
        if not far:
            petals(m)
        return m

    def cherries():
        m = Model("cherries", 14)
        rng3 = random.Random(31)
        for i in range(6):
            pts = strands[(i * 2 + 1) % len(strands)]
            q = pts[2] + V(rng3.uniform(-1, 1), rng3.uniform(-1, 1), 0)
            for s in (-1, 1):
                p2 = q + V(s * 0.9, 0, -2.4)
                tube(m, [q, q + V(s * 0.5, 0, -1.3), p2 + V(0, 0, 0.6)], [0.09, 0.08, 0.07], seg=3, color="5a7a3a",
                     group="body_nl")
                m.sphere(0.9, pos=p2, color=CHERRY_RED if (i + (s > 0)) % 3 else CHERRY_GREEN, seg=5, rings=4,
                         group="body_nl")
        return m

    parts = [
        ("blossom", lambda: blossom(), lambda: blossom(True)),
        ("foliage", lambda: t.render_crown(PAL["cherry"]), lambda: t.render_crown(PAL["cherry"], far=True)),
        ("foliage_autumn", lambda: t.render_crown(PAL["cherry_autumn"], name="foliage_autumn"),
         lambda: t.render_crown(PAL["cherry_autumn"], far=True, name="foliage_autumn")),
        ("cherries", cherries, None),
    ]
    t.export(parts, {"봄": ["blossom"], "여름": ["foliage", "cherries"], "가을": ["foliage_autumn"], "겨울": []},
             style="bands")

# ───────────── the great fallen fruit ─────────────
def build_fallen_fruit():
    m = Model("great_fruit", 351)
    fruit_ball(m, V(0, 0, 1.6), 1.75)
    # a little bruise / dent where it hit the ground
    m.sphere(0.5, pos=(0.9, -1.2, 0.9), scl=(1, 0.4, 1), color="c46a3a", seg=6, rings=3, group="body_nl")
    n = m.export(OUT)
    BUILT.append(("great_fruit", "-", n, 0, {}))
    # cut open: a half fruit standing on its rounded back, the cut face (juicy flesh + the stone) towards the camera,
    # and a peeled-off quarter lying beside it
    m = Model("great_fruit_cut", 352)
    r = 1.75
    c = V(0, 0, r * 0.88)
    half = m.sphere(r, pos=(0, 0, 0), scl=(1, 0.96, 0.92), color=FRUIT[1], seg=14, rings=9, group="body")
    bm = m._bm("body")
    for v in {v: True for f in half for v in f.verts}:
        if v.co.y < 0:
            v.co.y = 0.0
        v.co += c
    bm.normal_update()
    for f in half:
        nn = f.normal
        if nn.y < -0.9:
            rr = (f.calc_center_median() - c).length
            col = "f6dc8a" if rr > r * 0.62 else "f2c262"
        else:
            col = mix(FRUIT[1], FRUIT[2], max(0.0, min(1.0, 0.5 + 0.5 * (nn.x * 0.6 + nn.z * 0.3))))
        m._finish(bm, [f], col, nn.y >= -0.9)
    m.sphere(0.62, pos=c + V(0, -0.12, 0), scl=(0.8, 0.45, 1.0), color="a0603a", seg=8, rings=5, smooth=False,
             colfn=lambda f: "b87448" if f.normal.y < -0.4 else "86502e")
    q = m.sphere(r * 0.8, pos=(0, 0, 0), color=FRUIT[1], seg=10, rings=7, group="body")
    for v in {v: True for f in q for v in f.verts}:
        if v.co.x < 0:
            v.co.x = 0.0
        if v.co.z > 0:
            v.co.z = 0.0
        v.co = V(v.co.x, v.co.y, v.co.z + r * 0.8) + V(2.6, -1.4, 0)
    bm.normal_update()
    for f in q:
        flat = f.normal.z > 0.9 or f.normal.x < -0.9
        m._finish(bm, [f], "f6dc8a" if flat else mix(FRUIT[1], FRUIT[2], 0.6), not flat)
    n = m.export(OUT)
    BUILT.append(("great_fruit_cut", "-", n, 0, {}))


# ───────────── Q41: ground round each great tree (view-only decals, GreatTreeView scatters them round the trunk) ─────────────
# flat patches ~10 across at scale 1 (origin = patch centre on the ground), no outline (body_nh) like the gc_* ground cover.
#   ring_needles  rust needle bed + cones (pine, all year)      ring_clover   clover carpet + white clover heads (fruit)
#   ring_cream    cream blossom petals on the grass (fruit, spring)    ring_ginkgo   golden fan-leaf carpet (ginkgo, autumn)
#   ring_maple    red hand-leaf litter (maple, autumn)          ring_litter   brown dry leaf litter (maple, other seasons)
#   ring_petals   pink petal carpet (cherry, spring)            ring_softgrass lush soft grass with tiny flowers (cherry, summer/autumn)
def _blob(m, r, n=12, z=0.03, wob=0.25, seed=0, col="7a9a5a", rim=None, ox=0.0, oy=0.0, sx=1.0, sy=1.0, group="body_nh"):
    import random
    rnd = random.Random(seed)
    bm = m._bm(group)
    radii = [r * (1 + rnd.uniform(-wob, wob)) for _ in range(n)]
    radii = [(radii[i - 1] + 2 * radii[i] + radii[(i + 1) % n]) / 4 for i in range(n)]
    c = bm.verts.new((ox, oy, z + 0.03))
    mid = [bm.verts.new((ox + math.cos(i / n * math.tau) * radii[i] * 0.62 * sx,
                         oy + math.sin(i / n * math.tau) * radii[i] * 0.62 * sy, z + 0.015)) for i in range(n)]
    out = [bm.verts.new((ox + math.cos(i / n * math.tau) * radii[i] * sx,
                         oy + math.sin(i / n * math.tau) * radii[i] * sy, z)) for i in range(n)]
    inner = [bm.faces.new((c, mid[i], mid[(i + 1) % n])) for i in range(n)]
    outer = [bm.faces.new((mid[i], out[i], out[(i + 1) % n], mid[(i + 1) % n])) for i in range(n)]
    bm.normal_update()
    m._finish(bm, inner, col, False)
    m._finish(bm, outer, rim or col, False)


def _flat(m, cx, cy, z, rz, pts, col, group="body_nh"):
    """One flat polygon (local pts, rotated rz) lying on the ground at height z."""
    bm = m._bm(group)
    c, s = math.cos(rz), math.sin(rz)
    vs = [bm.verts.new((cx + px * c - py * s, cy + px * s + py * c, z)) for px, py in pts]
    f = bm.faces.new(vs)
    if f.normal.z < 0:
        f.normal_flip()
    m._finish(bm, [f], col, False)


def _scatter(rnd, n, r):
    for k in range(n):
        a = rnd.uniform(0, math.tau)
        d = r * rnd.uniform(0.0, 1.0) ** 0.7
        yield k, math.cos(a) * d, math.sin(a) * d, rnd.uniform(0, math.tau)


def _star_pts(r, points=5, inner=0.45):
    return [((r if i % 2 == 0 else r * inner) * math.cos(i * math.pi / points),
             (r if i % 2 == 0 else r * inner) * math.sin(i * math.pi / points)) for i in range(points * 2)]


def _fan_pts(r):
    pts = [(0.0, 0.0)]
    for i in range(6):
        a = -0.95 + 1.9 * i / 5
        rr = r * (0.8 if i in (2, 3) else 1.0)
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    return pts


def _petal_pts(ln, w):
    return [(-ln, 0), (-ln * 0.2, -w), (ln * 0.7, -w * 0.6), (ln, 0), (ln * 0.7, w * 0.6), (-ln * 0.2, w)]


def build_rings():
    import random
    GRASS = "93b27a"
    out = []

    m = Model("ring_needles", 401)                     # pine: rust needle bed
    rnd = random.Random(401)
    for q, (ox, oy, rr) in enumerate(((-1.4, 0.6, 2.6), (1.5, -0.8, 2.3), (0.2, 1.9, 1.8))):     # loose bed, not one disc
        _blob(m, rr, 9, seed=401 + q, wob=0.4, col=mix("a27a52", GRASS, 0.25), rim=mix("a27a52", GRASS, 0.6), ox=ox, oy=oy)
    for k, x, y, rz in _scatter(rnd, 110, 4.8):
        ln = rnd.uniform(0.5, 0.8)
        _flat(m, x, y, 0.09 + 0.0005 * k, rz, [(-ln, -0.04), (ln, -0.04), (ln, 0.04), (-ln, 0.04)],
              ("c09468", "7a5238", "b08458", "6b4a34")[k % 4])
    for k in range(4):                                  # cones
        a = k * 1.9 + 0.4
        cc = (math.cos(a) * 3.0, math.sin(a) * 2.6, 0.32)
        m.sphere(0.45, pos=cc, scl=(1.5, 0.95, 0.75), rot=(0, 0, a), color="7a5238", seg=6, rings=4, group="body_nl",
                 colfn=lambda f: "9a6c48" if f.normal.z > 0.3 else "5e3e2a")
    out.append(("ring_needles", m))

    m = Model("ring_clover", 411)                      # fruit: clover carpet
    rnd = random.Random(411)
    for k, x, y, rz in _scatter(rnd, 30, 4.8):
        col = ("7fb064", "5f9150", "8cbc6c")[k % 3]
        for j in range(3):
            a = rz + j * math.tau / 3
            _flat(m, x + math.cos(a) * 0.36, y + math.sin(a) * 0.36, 0.08 + 0.001 * k, a,
                  [(math.cos(q * math.tau / 5) * 0.42, math.sin(q * math.tau / 5) * 0.34) for q in range(5)], col)
    for k, x, y, rz in _scatter(rnd, 7, 4.0):           # white clover heads
        m.sphere(0.32, pos=(x, y, 0.35), scl=(1, 1, 0.8), color="f4f0e2", seg=6, rings=4, group="body_nl",
                 colfn=lambda f: "f8f6ec" if f.normal.z > 0.2 else "e2d8c8")
    out.append(("ring_clover", m))

    m = Model("ring_cream", 421)                       # fruit spring: cream blossom petals
    rnd = random.Random(421)
    for k, x, y, rz in _scatter(rnd, 60, 5.0):
        _flat(m, x, y, 0.08 + 0.0005 * k, rz, _petal_pts(0.34, 0.22), ("fbf4e2", "efe2c4", "f8ecd6")[k % 3])
    out.append(("ring_cream", m))

    m = Model("ring_ginkgo", 431)                      # ginkgo autumn: golden fan carpet
    rnd = random.Random(431)
    for k, x, y, rz in _scatter(rnd, 80, 5.2):
        _flat(m, x, y, 0.08 + 0.0006 * k, rz, _fan_pts(rnd.uniform(0.7, 1.0)), ("f6d84a", "f1c93a", "e8b42e", "f9e27a")[k % 4])
    out.append(("ring_ginkgo", m))

    m = Model("ring_maple", 441)                       # maple autumn: red hand-leaf litter
    rnd = random.Random(441)
    for k, x, y, rz in _scatter(rnd, 58, 5.0):
        _flat(m, x, y, 0.08 + 0.0006 * k, rz, _star_pts(rnd.uniform(0.7, 1.0)), ("e0664a", "c9452e", "d8823a", "b23a2c")[k % 4])
    out.append(("ring_maple", m))

    m = Model("ring_litter", 451)                      # maple other seasons: brown dry litter
    rnd = random.Random(451)
    for k, x, y, rz in _scatter(rnd, 30, 4.6):
        _flat(m, x, y, 0.08 + 0.0006 * k, rz, _star_pts(rnd.uniform(0.6, 0.85)), ("b08a5e", "9a7650", "c49c66")[k % 3])
    out.append(("ring_litter", m))

    m = Model("ring_petals", 461)                      # cherry spring: pink petal carpet
    rnd = random.Random(461)
    for k, x, y, rz in _scatter(rnd, 95, 5.2):
        _flat(m, x, y, 0.08 + 0.0005 * k, rz, _petal_pts(0.36, 0.24), ("fad2dc", "f2b8c6", "fde6ea", "e8a4b6")[k % 4])
    out.append(("ring_petals", m))

    m = Model("ring_softgrass", 471)                   # cherry summer/autumn: soft lush grass, tiny flowers
    rnd = random.Random(471)
    for k, x, y, rz in _scatter(rnd, 40, 4.8):                  # soft fresh leaves lying in the grass
        _flat(m, x, y, 0.06 + 0.0005 * k, rz, _petal_pts(0.6, 0.3), ("a8d088", "b8dc96", "94c27a")[k % 3])
    for k, x, y, rz in _scatter(rnd, 12, 4.2):
        m.sphere(0.22, pos=(x, y, 0.22), scl=(1, 1, 0.7), color="fbf2f0" if k % 3 else "f2c8d2", seg=5, rings=3,
                 group="body_nl")
    out.append(("ring_softgrass", m))

    for nm, m in out:
        n = m.export(OUT)
        BUILT.append((nm, "-", n, 0, {}))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("bonsai ->", OUT)
    only = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else []
    for nm, fn in (("pine", build_pine), ("fruit", build_fruit), ("ginkgo", build_ginkgo), ("maple", build_maple),
                   ("cherry", build_cherry), ("great_fruit", build_fallen_fruit), ("rings", build_rings)):
        if not only or nm in only:
            fn()
    print("  budget (art bible 8.7: near <= 6000 body, far <= 1200):")
    for (nm, se, near, far, tris) in BUILT:
        print("  %-18s worst %s near %5d  far %5d  %s" % (nm, se, near, far,
                                                          " ".join("%s=%d" % kv for kv in sorted(tris.items()))))
