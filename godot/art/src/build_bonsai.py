"""The five great trees of the small world (GAME_DESIGN 3.0, ROADMAP E3-2 / E3-11 / A27; art bible 3.4, 4.3, 6.4, 8)
+ the great fallen fruit. Bonsai-shaped: thick bent trunks, exposed roots, layered foliage. One of each per world, never cut.
Scale: 1 unit = one adult resident (the view scales trees by FloraLook.GREAT_SCALE 0.6).
Heights: ginkgo ~90, cherry ~76, pine ~68, maple ~68, fruit tree ~62.

Silhouettes (art bible 6.4 - each must read on its own from the whole-world view):
  pine   = flat horizontal needle cushions in tiers, fine comb teeth round every cushion rim (no star points)
  fruit  = one round crown + hanging fruit dots; CREAM-WHITE blossom in spring (pink belongs to the cherry)
  ginkgo = the only upright tree: straight trunk, branches and crown open upwards like a fan
  maple  = wide dome of hand-shaped cushions: five big pointed lobes on every rim (star edge = maple only)
  cherry = bent, leaning trunk with horizontal bark bands, puffy blossom clouds (spring), green + cherries (summer),
           orange (autumn), bare banded trunk (winter)

Output: godot/art/models/flora/tree_<kind>.glb, one part set per tree (read with Art.parts). Every part pivots at the
trunk foot (0,0,0). Colour variants share the exact same geometry, so the view only picks which parts to show per season:
  tree_pine   trunk · foliage (summer/autumn) · foliage_spring (light-green new tips) · foliage_winter (frost on top)
  tree_fruit  trunk · foliage · foliage_bloom (cream-white) · foliage_autumn · fruit (ripe) · fruit_green · fruit_dry (one)
  tree_ginkgo trunk · foliage_spring · foliage · foliage_autumn (yellow) · carpet (fallen yellow fans, autumn)
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
    "pine": ("4f8f74", "3a755f", "2a5a4c"),
    "pine_spring": ("9cc87a", "3f7a62", "2a5a4c"),            # light-green new tips on top
    "pine_winter": ("e3eeea", "6f968a", "2c5a4c"),           # frost #E3EEEA (mint white, not pure white)
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
BARK = {"pine": "6e5240", "fruit": "7a5e4a", "ginkgo": "8e8070", "maple": "8c7a6c", "cherry": "7a4a46"}
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


# ───────────── pine: flat tiered needle cushions with comb rims ─────────────
def build_pine():
    t = Tree("tree_pine", "pine", 311)
    t.trunk([(0, 0, 0), (10, 0, 12), (-12, 2, 22), (-5, 0, 32), (3, -1, 40), (10, 0, 48), (5, 0, 58)], 6.2, 1.5, n=9, seg=11,
            flare=0.5)
    t.roots(6, 8, 0.6, r_k=0.5)
    tiers = ((0.30, 3.0, 26, -1, 15.0, 3.0), (0.42, 0.2, 24, 1, 14.0, 2.9), (0.55, 2.0, 19, 2, 12.0, 2.7),
             (0.66, -1.0, 18, 2, 11.5, 2.6), (0.78, 4.0, 14, 3, 10.0, 2.5), (0.5, -2.6, 16, 0, 10.5, 2.6))
    for (tt, az, ln, rise, rx, rz) in tiers:
        e, d, _, _ = t.branch(tt, az, ln, rise, r_k=0.42, droop=0.18, seg=7)
        t.lump(e + V(0, 0, 0.8), rx, rx * 0.86, rz, rot=az, seg=56, rings=5, rim=comb(56), rim_far=comb(16),
               flat=0.3, lumps=0.07, far_seg=16, far_rings=4)
        # a smaller step-pad beside the main one (layered look)
        a2 = az + 1.1
        c2 = e + V(math.cos(a2), math.sin(a2), 0) * rx * 0.8 + V(0, 0, -0.6)
        t.lump(c2, rx * 0.55, rx * 0.5, rz * 0.85, rot=a2, seg=26, rings=4, rim=comb(26), flat=0.3, lumps=0.07,
               far=False)
    top, _ = t.at(1.0)
    t.lump(top + V(0, 0, 2.2), 10.5, 9.0, 3.0, seg=48, rings=5, rim=comb(48), rim_far=comb(14), flat=0.3,
           far_seg=14, far_rings=4)
    # jin: a dead silver-white branch stub (classic pine bonsai deadwood)
    p, r = t.at(0.86)
    t.tube(bezier(p, p + V(-5, 0, 3), p + V(-8, 1, 8), p + V(-10, 2, 10), 4), [r * 0.5, r * 0.4, r * 0.3, r * 0.2, r * 0.1],
           seg=6, minor=True, colfn=lambda i, k, N: "e2dccd" if k % 2 else "bcb3a3")
    parts = [
        ("foliage", lambda: t.render_crown(PAL["pine"]), lambda: t.render_crown(PAL["pine"], far=True)),
        ("foliage_spring", lambda: t.render_crown(PAL["pine_spring"], name="foliage_spring"),
         lambda: t.render_crown(PAL["pine_spring"], far=True, name="foliage_spring")),
        ("foliage_winter", lambda: t.render_crown(PAL["pine_winter"], name="foliage_winter"),
         lambda: t.render_crown(PAL["pine_winter"], far=True, name="foliage_winter")),
    ]
    t.export(parts, {"봄": ["foliage_spring"], "여름": ["foliage"], "가을": ["foliage"], "겨울": ["foliage_winter"]},
             style="scales")


# ───────────── fruit tree: round crown + hanging fruit dots ─────────────
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
    t.trunk([(0, 0, 0), (3, 0, 7), (-3, 0, 13), (0, 0, 19)], 6.8, 4.2, n=8, seg=12, flare=0.5)
    t.roots(6, 7, 0.5, r_k=0.6)
    # thick, short trunk splitting wide into four limbs
    top, rt = t.at(1.0)
    limb_ends = []
    for i, (az, ln, rise) in enumerate(((0.3, 15, 16), (1.9, 14, 18), (3.5, 15, 15), (5.0, 13, 19))):
        e, d, pts, rr = t.branch(1.0, az, ln, rise, r_k=0.72, droop=-0.1, seg=9, tip_k=0.4, base=(top - V(0, 0, 1.5), rt))
        limb_ends.append((e, az))
        p, r = t.at(0.6, pts, rr)
        t.branch(0, az + 0.8, 9, 6, r_k=0.6, seg=6, base=(p, r), minor=True)
    # round crown: a big central dome + a ring of lumps (round, not flat pads)
    cz = 40.0
    t.lump((0, 0, cz + 1), 22, 21, 13, seg=18, rings=8, flat=0.55, lumps=0.12, far_seg=12, far_rings=6)
    for i in range(8):
        a = i * math.tau / 8 + 0.2
        rr = 18.5
        z = cz - 3 + (i % 2) * 4
        t.lump((math.cos(a) * rr, math.sin(a) * rr, z), 11.5, 10.5, 9, rot=a, seg=14, rings=7, flat=0.5, lumps=0.14,
               far_seg=8, far_rings=5)
    for i in range(3):
        a = i * math.tau / 3 + 0.9
        t.lump((math.cos(a) * 8, math.sin(a) * 8, cz + 9), 11, 10, 8, rot=a, seg=14, rings=7, flat=0.5, lumps=0.14,
               far=False)
    # hanging fruit (lower rim of the crown, all round so they read from every side)
    spots = []
    for i in range(12):
        a = i * math.tau / 12 + (0.13 if i % 2 else -0.1)
        rr = 23.5 + (i % 3) * 1.5
        spots.append(V(math.cos(a) * rr, math.sin(a) * rr, cz - 9.5 - (i % 2) * 2.5))

    def fruits(cols, far=False, only=None):
        m = Model("fruit_" + ("far" if far else "near"), 10)
        for i, p in enumerate(spots):
            if only is not None and i not in only:
                continue
            if far and i % 6 == 5:
                continue
            if far:
                m.sphere(3.4, pos=p - V(0, 0, 3.6), color=cols[1], seg=5, rings=3, group="body_nl")
                continue
            tube(m, [p + V(0, 0, 0.8), p - V(0, 0, 1.4)], [0.2, 0.16], seg=4, color="6a4a32", group="body_nl")
            fruit_ball(m, p - V(0, 0, 4.0), 3.1, seg=8, rings=6, cols=cols, leaf_on=False, group="body_nl")
        return m

    def dry():
        m = Model("fruit_dry", 11)
        p = spots[1] + V(-4, 0, 3)
        tube(m, [p + V(0, 0, 0.8), p - V(0, 0, 1.4)], [0.2, 0.16], seg=4, color="6a4a32", group="body_nl")
        m.sphere(2.0, pos=p - V(0, 0, 3.2), scl=(1, 0.9, 1.1), color="9a6a44", seg=8, rings=6, group="body_nl",
                 lumps=0.25, seed=3, colfn=lambda f: "a87850" if f.normal.z > 0 else "7a5034")
        return m

    parts = [
        ("foliage", lambda: t.render_crown(PAL["fruit"]), lambda: t.render_crown(PAL["fruit"], far=True)),
        ("foliage_bloom", lambda: t.render_crown(PAL["fruit_bloom"], name="foliage_bloom"),
         lambda: t.render_crown(PAL["fruit_bloom"], far=True, name="foliage_bloom")),
        ("foliage_autumn", lambda: t.render_crown(PAL["fruit_autumn"], name="foliage_autumn"),
         lambda: t.render_crown(PAL["fruit_autumn"], far=True, name="foliage_autumn")),
        ("fruit", lambda: fruits(FRUIT), lambda: fruits(FRUIT, far=True)),
        ("fruit_green", lambda: fruits(FRUIT_GREEN), lambda: fruits(FRUIT_GREEN, far=True)),
        ("fruit_dry", dry, None),
    ]
    t.export(parts, {"봄": ["foliage_bloom"], "여름": ["foliage", "fruit_green"], "가을": ["foliage_autumn", "fruit"],
                     "겨울": ["fruit_dry"]})


# ───────────── ginkgo: straight trunk, crown opening upwards like a fan ─────────────
def build_ginkgo():
    t = Tree("tree_ginkgo", "ginkgo", 331)
    t.trunk([(0, 0, 0), (2, 0, 18), (-2, 0, 36), (0, 0, 48), (1, 0, 56), (0, 0, 62), (0, 0, 68)], 6.0, 2.0, n=8, seg=11,
            flare=0.5)
    t.roots(7, 7, 0.5, r_k=0.55)
    # the only upright tree: limbs leave the straight trunk high up and splay upwards and outwards like the ribs of an
    # open fan (narrow at the bottom, widest at the top). The bare winter tree keeps the same fan.
    ends = []
    n = 9
    for i in range(n):
        u = i / (n - 1)
        az = i * 2.39996 + 0.4
        th = 0.4 + 0.55 * (0.5 + 0.5 * math.sin(i * 1.7))       # angle from vertical 23..55 deg
        L = 34 - 6 * abs(math.cos(i * 1.3))
        tt = 0.55 + 0.4 * ((i * 0.37) % 1.0)
        p0, r = t.at(tt)
        e, d, pts, rr = t.branch(tt, az, L * math.sin(th), L * math.cos(th), r_k=0.5, droop=-0.04, seg=7, tip_k=0.3)
        ends.append((e, az, th, pts, rr))
        # a twig rising from the limb (fills the fan when bare; minor -> not in the far LOD)
        q, qr = t.at(0.55, pts, rr)
        t.branch(0, az + 0.6, 4 + 4 * math.sin(th), 9, r_k=0.6, seg=5, tip_k=0.3, base=(q, qr), minor=True)
    # crown: one long upright lump per limb end, leaning out along its limb (the fan's ribs), + a lower filler on the
    # limb and a low dome over the trunk top
    for (e, az, th, pts, rr) in ends:
        t.lump(e + V(math.sin(th) * math.cos(az), math.sin(th) * math.sin(az), math.cos(th)) * 3.0, 7.4, 6.6, 12.5,
               rot=az, tilt=tilt_out(0.0, th + 0.12), seg=12, rings=6, flat=0.8, lumps=0.14, far_seg=8, far_rings=4)
        q, _ = t.at(0.5, pts, rr)
        t.lump(q + V(0, 0, 2), 6.0, 5.4, 8.0, rot=az, tilt=tilt_out(0.0, th), seg=10, rings=5, flat=0.8, lumps=0.14,
               far=False)
    top, _ = t.at(1.0)
    t.lump(top + V(0, 0, 4), 9, 8.5, 8, seg=12, rings=6, flat=0.6, lumps=0.12, far_seg=8, far_rings=4)


    def carpet(far=False):                  # the whole crown drops at once: a yellow carpet round the foot
        m = Model("carpet", 12)
        if far:
            for i, (rr, n) in enumerate(((12, 2), (25, 4))):
                for k in range(n):
                    a = k * math.tau / n + i * 0.8
                    m.sphere(11.0, pos=(math.cos(a) * rr, math.sin(a) * rr, -0.6), scl=(1, 1, 0.12),
                             color=PAL["ginkgo_autumn"][1], seg=6, rings=3, group="body_nl")
            return m
        import random
        rng = random.Random(5)
        for k in range(30):
            a = k * 2.39996
            rr = 8 + 26 * math.sqrt((k + 0.5) / 30)
            p = V(math.cos(a) * rr, math.sin(a) * rr, 0.15)
            fan_leaf(m, p, V(0.1 * math.sin(k), 0.1 * math.cos(k), 1), V(math.cos(k), math.sin(k), 0), 2.6,
                     color=PAL["ginkgo_autumn"][0] if k % 3 else PAL["ginkgo_autumn"][1], thick=0.12, seg=5)
        for i, (rr, n) in enumerate(((15, 6), (27, 9))):     # thin flat drifts under the single leaves
            for k in range(n):
                a = k * math.tau / n + i * 0.3 + rng.uniform(-0.2, 0.2)
                m.sphere(7.0, pos=(math.cos(a) * rr, math.sin(a) * rr, -0.55), scl=(1, 1, 0.11),
                         color=PAL["ginkgo_autumn"][1], seg=8, rings=3, group="body_nl")
        return m

    parts = [
        ("foliage_spring", lambda: t.render_crown(PAL["ginkgo_spring"], name="foliage_spring"),
         lambda: t.render_crown(PAL["ginkgo_spring"], far=True, name="foliage_spring")),
        ("foliage", lambda: t.render_crown(PAL["ginkgo"]), lambda: t.render_crown(PAL["ginkgo"], far=True)),
        ("foliage_autumn", lambda: t.render_crown(PAL["ginkgo_autumn"], name="foliage_autumn"),
         lambda: t.render_crown(PAL["ginkgo_autumn"], far=True, name="foliage_autumn")),
        ("carpet", lambda: carpet(), lambda: carpet(True)),
    ]
    t.export(parts, {"봄": ["foliage_spring"], "여름": ["foliage"], "가을": ["foliage_autumn", "carpet"], "겨울": []},
             style="streak")


# ───────────── maple: dome of hand-shaped cushions (star edge) ─────────────
def build_maple():
    t = Tree("tree_maple", "maple", 341)
    # several smooth grey-brown stems from one foot
    t.trunk([(0, 0, 0), (-3, 0, 14), (-9, 0, 26), (-7, 0, 38), (-5, 0, 46), (-2, 0, 52), (0, 0, 56)], 5.6, 1.5, n=8, seg=9,
            flare=0.5)
    main_pts, main_rad = t.tpts, t.trad
    t.roots(7, 7, 0.5, r_k=0.6, minor_from=2)
    stems = []
    for (az, lean, h) in ((0.2, 14, 40), (2.4, 12, 36)):
        p0, r = t.at(0.12)
        d = V(math.cos(az), math.sin(az), 0)
        pts = bezier(p0, p0 + d * lean * 0.4 + V(0, 0, h * 0.3), p0 + d * lean + V(0, 0, h * 0.65), p0 + d * lean * 1.1 + V(0, 0, h), 9)
        rr = [r * 0.72 * (1 - 0.7 * j / 9) for j in range(10)]
        t.tube(pts, rr, seg=8, wobble=0.06, wseed=az)
        stems.append((pts, rr))
    pads = []
    for (tt, az, ln, rise) in ((0.55, 2.8, 18, 3), (0.7, 1.3, 14, 5), (0.82, -1.3, 13, 5), (0.92, 3.9, 11, 6)):
        e, d, _, _ = t.branch(tt, az, ln, rise, r_k=0.45, droop=0.1, seg=7)
        pads.append((e, az))
    for (pts, rr), brs in zip(stems, (((0.7, 0.1, 15, 3), (0.9, -0.9, 10, 5)), ((0.7, 2.2, 14, 3), (0.92, 1.4, 9, 5)))):
        for (tt, az, ln, rise) in brs:
            e, d, _, _ = t.branch(tt, az, ln, rise, r_k=0.5, droop=0.1, seg=7, base=t.at(tt, pts, rr), minor=True)
            pads.append((e, az))
        pads.append((pts[-1], 0.0))
    top, _ = t.at(1.0)
    pads.append((top, 1.0))
    for i, (e, az) in enumerate(pads):
        big = i in (0, 4, 6)
        rx = 12.5 if big else 10.5
        t.lump(e + V(0, 0, 2.5), rx, rx * 0.92, 4.6, rot=az + i * 0.4, seg=30, rings=6, rim=lobes(5, 0.42),
               rim_far=lobes(5, 0.42), flat=0.35, lumps=0.07, far_seg=15, far_rings=3)

    def leaves(m, pal):                     # big hand leaves standing out of the rims (star edge, near only)
        import random
        rng = random.Random(41)
        for (p, d) in rim_pts(t.lumps, 3, rng, z_lo=-0.1, z_hi=0.5, out=1.05):
            up = (V(0, 0, 1) + d * 0.9).normalized()
            star_leaf(m, p, up, d, 2.8, points=5, inner=0.4, color=shade(pal[0], 1.0 if rng.random() > 0.35 else 0.88),
                      thick=0.18, cup_k=0.15)
    t.leaves = leaves

    def seeds():                            # winter: winged seed pairs left on the bare twigs
        m = Model("seeds", 13)
        import random
        rng = random.Random(9)
        for (e, az) in pads:
            for k in range(2):
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


# ───────────── cherry: bent leaning banded trunk, puffy blossom clouds ─────────────
def build_cherry():
    t = Tree("tree_cherry", "cherry", 361)
    # curved trunk leaning far to one side, then lifting again at the end (bonsai "slanting" style)
    t.trunk([(0, 0, 0), (4, 0, 12), (10, 0, 20), (19, 1, 27), (28, 2, 33), (36, 0, 40), (40, -1, 50)], 6.0, 2.0, n=10, seg=12,
            flare=0.4)
    t.roots(6, 10, 0.4, r_k=0.42)
    bands = t.bark_fn(t.bark, "bands")
    clouds = []
    # wide horizontal limbs (the cherry spreads like an umbrella) + a leader going back over the foot (balance)
    for (tt, az, ln, rise, sz) in ((0.4, 2.6, 26, 12, 1.0), (0.55, -1.7, 18, 10, 0.85), (0.62, 1.4, 18, 12, 0.9),
                                     (0.75, 0.0, 20, 6, 1.0), (0.85, -0.8, 14, 8, 0.8), (0.9, 2.2, 14, 9, 0.8)):
        e, d, _, _ = t.branch(tt, az, ln, rise, r_k=0.48, droop=0.12, seg=8, colfn=bands)
        clouds.append((e, az, sz))
    top, _ = t.at(1.0)
    clouds.append((top + V(0, 0, 2), 0.5, 1.1))
    for i, (c, az, sz) in enumerate(clouds):
        # a puffy cloud = one big round puff + two smaller ones bulging off it
        t.lump(c + V(0, 0, 3), 11 * sz, 10 * sz, 8.5 * sz, rot=az, seg=14, rings=8, flat=0.65, lumps=0.2, far_seg=10,
               far_rings=5, far_k=1.25)
        for s in (-1, 1):
            a = az + s * 1.4 + i * 0.2
            off = V(math.cos(a), math.sin(a), 0) * 9 * sz + V(0, 0, (1.5 if s > 0 else -1.0) * sz)
            t.lump(c + V(0, 0, 3) + off, 7.5 * sz, 7 * sz, 6.2 * sz, rot=a, seg=10, rings=6, flat=0.65, lumps=0.18,
                   far=False)

    def petals(m):                          # drifting petals under the clouds + a few on the ground
        import random
        rng = random.Random(23)
        for k in range(36):
            c, az, sz = clouds[k % len(clouds)]
            ground = k % 3 == 0
            p = c + V(rng.uniform(-14, 14), rng.uniform(-14, 14), 0)
            p.z = rng.uniform(0.1, 0.3) if ground else max(4.0, c.z - rng.uniform(6, 26))
            up = V(rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 1).normalized()
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
        import random
        rng = random.Random(31)
        for i in range(10):
            c, az, sz = clouds[i % len(clouds)]
            a = rng.uniform(0, math.tau)
            p = c + V(math.cos(a) * 10 * sz, math.sin(a) * 10 * sz, -3.5 * sz)
            for s in (-1, 1):
                q = p + V(s * 0.9, 0, -2.4)
                tube(m, [p, p + V(s * 0.5, 0, -1.3), q + V(0, 0, 0.6)], [0.09, 0.08, 0.07], seg=3, color="5a7a3a",
                     group="body_nl")
                m.sphere(0.9, pos=q, color=CHERRY_RED if (i + (s > 0)) % 3 else CHERRY_GREEN, seg=5, rings=4,
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


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("bonsai ->", OUT)
    only = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else []
    for nm, fn in (("pine", build_pine), ("fruit", build_fruit), ("ginkgo", build_ginkgo), ("maple", build_maple),
                   ("cherry", build_cherry), ("great_fruit", build_fallen_fruit)):
        if not only or nm in only:
            fn()
    print("  budget (art bible 8.7: near <= 6000 body, far <= 1200):")
    for (nm, se, near, far, tris) in BUILT:
        print("  %-18s worst %s near %5d  far %5d  %s" % (nm, se, near, far,
                                                          " ".join("%s=%d" % kv for kv in sorted(tris.items()))))
