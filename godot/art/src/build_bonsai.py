"""The five great trees of the small world (GAME_DESIGN 3.0, ROADMAP E3-2) + the giant fallen fruit.
Bonsai-shaped: thick twisted trunks, exposed roots, flat layered foliage pads. One of each per world, never cut.
Scale: 1 unit = one adult resident. Heights: world tree ~115, ginkgo ~88, pine ~76, maple ~72, fruit tree ~66.

Output: godot/art/models/flora/tree_<name>.glb as a part set (Art.parts / Art.model both work), parts:
  "trunk"     trunk, branches, roots (+ moss, deadwood)    nodes: trunk, trunk_body_nl
  "foliage"   leaf pads + rim leaves                       node:  foliage_body_nl
  "blossom"   flowers (fruit tree only)                    node:  blossom_body_nl
  "fruit"     hanging fruit (fruit tree only)              node:  fruit
All parts pivot at the trunk foot (0,0,0). Seasons: the same tree is exported again with other foliage colours and
identical geometry, so code can swap just the "foliage" part:
  tree_ginkgo (green) / tree_ginkgo_autumn (yellow) · tree_maple (red, autumn look - its identity) / tree_maple_green ·
  tree_fruit (blossom + fruit) / tree_fruit_bloom (spring: blossom only, no fruit) · tree_world · tree_pine (evergreen)
giant_fruit / giant_fruit_cut: a fallen fruit (~3.5 across) residents carry in teams / cut open (plain Model).
Run: blender -b --factory-startup --python build_bonsai.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, PartSet, Vector, shade, mix, out_dir_from_argv  # noqa: E402
from flora_kit import V, bezier, tube, pad, star_leaf, fan_leaf, leaf, cup  # noqa: E402

OUT = os.path.join(out_dir_from_argv(), "flora")
BUILT = []

FOLIAGE = {
    "world": ("9ad9a6", "62b88e", "3e8c7a"),
    "pine": ("5f9a6e", "3f7a5a", "2b5b4a"),
    "fruit": ("7ccf8c", "4caa82", "2f8574"),
    "ginkgo": ("bcd86c", "96c05a", "6a9a4a"),
    "ginkgo_autumn": ("fae25a", "eec236", "c8962a"),
    "maple": ("ee6a4e", "cf4632", "9a2e2a"),
    "maple_green": ("94d276", "66b05c", "418c4e"),
}
BARK = {"world": "8f8270", "pine": "755643", "fruit": "7a5e4a", "ginkgo": "8e8070", "maple": "6f5a54"}
BLOSSOM = ("fbe0e8", "f4b6c8")
FRUIT = ("f39a5a", "f6c065", "e0703f")       # peach skin, blush light, blush dark
MOSS = "7fbf6a"


def bark_col(base):
    def f(face):
        c = face.calc_center_median()
        streak = int((math.atan2(c.y, c.x) + math.pi) * 5.0 + c.z * 0.15) % 3
        k = 1.06 if face.normal.z > 0.45 else (0.8 if face.normal.z < -0.3 else 1.0)
        return shade(base, k * (0.92 if streak == 0 else 1.0))
    return f


def gnarl(seed, amt=0.14):
    def w(i, k):
        return 1.0 + amt * math.sin(k * 2.0 + i * 0.9 + seed) + amt * 0.6 * math.sin(k * 5.0 - i * 1.7 + seed * 2)
    return w


class Tree:
    def __init__(self, name, kind, seed):
        self.name = name
        self.kind = kind
        self.trunk = Model(name + "_trunk", seed)
        self.fol = Model(name + "_fol", seed + 1)
        self.blossom = None
        self.fruit = None
        self.rng = self.trunk.rng
        self.seed = seed
        self.bark = BARK[kind.split("_")[0]]

    def trunk_path(self, ctrl, r0, r1, n=14, seg=12):
        pts = []
        for a, b, c, d in [ctrl[i:i + 4] for i in range(0, len(ctrl) - 3, 3)]:
            seg_pts = bezier(V(*a), V(*b), V(*c), V(*d), n)
            pts += seg_pts if not pts else seg_pts[1:]
        N = len(pts)
        radii = []
        for i in range(N):
            t = i / (N - 1)
            r = r0 + (r1 - r0) * t ** 0.8
            r *= 1.0 + 0.45 * max(0.0, 1 - t * 6) ** 2                 # flared foot
            radii.append(r)
        tube(self.trunk, pts, radii, seg=seg, color=self.bark, colfn=bark_col(self.bark), wobble=gnarl(self.seed),
             twist=0.06, cap=shade(self.bark, 1.2))
        self.tpts = pts
        self.trad = radii
        return pts

    def at(self, t):
        pts = self.tpts
        f = t * (len(pts) - 1)
        i = min(len(pts) - 2, int(f))
        return pts[i].lerp(pts[i + 1], f - i), self.trad[i]

    def roots(self, n, spread, arch, r_k=0.5):
        """Nebari: thick surface roots melting out of the flared foot, uneven lengths, gripping the ground."""
        r0 = self.trad[0]
        for i in range(n):
            a = i * math.tau / n + self.rng.uniform(-0.3, 0.3)
            d = V(math.cos(a), math.sin(a), 0)
            k = self.rng.uniform(0.45, 1.0) if i % 2 else self.rng.uniform(0.8, 1.1)
            ln = spread * k
            p0 = d * r0 * 0.35 + V(0, 0, r0 * (1.1 if arch > 3 else 0.75))
            p3 = d * (r0 + ln) + V(0, 0, -0.8)
            side = V(-d.y, d.x, 0) * self.rng.choice((-1, 1)) * self.rng.uniform(0.25, 0.5) * ln
            pts = bezier(p0, p0 + d * r0 * 0.9 + V(0, 0, arch * k * 0.3), p0 + d * (r0 + ln * 0.55) + side + V(0, 0, arch * k), p3 + side * 0.6, 6)
            rr = [r0 * r_k * k ** 0.5 * (1 - 0.85 * (j / 6) ** 0.8) + 0.2 for j in range(7)]
            tube(self.trunk, pts, rr, seg=8, color=self.bark, colfn=bark_col(self.bark), wobble=gnarl(i + self.seed, 0.1))

    def branch(self, t, az, ln, rise, r_k=0.42, droop=0.15, seg=8):
        """Branch from the trunk at t, going out along azimuth az; returns its end point."""
        p0, r = self.at(t)
        d = V(math.cos(az), math.sin(az), 0)
        p3 = p0 + d * ln + V(0, 0, rise)
        pts = bezier(p0, p0 + d * ln * 0.35 + V(0, 0, rise * 0.6 + ln * 0.08), p0 + d * ln * 0.7 - V(0, 0, ln * droop),
                     p3, 6)
        rb = r * r_k
        tube(self.trunk, pts, [rb * (1 - 0.6 * j / 6) for j in range(7)], seg=seg, color=self.bark,
             colfn=bark_col(self.bark), wobble=gnarl(az * 3 + self.seed, 0.08))
        return p3, d

    def pads(self, c, rx, rz, cols, d=None, sub=2, rot=0.0):
        """Main pad + sub pads stepping out, sideways. Returns the list of (centre, rx, rz)."""
        out = [(Vector(c), rx, rz)]
        rng = self.rng
        pad(self.fol, c, rx, rx * 0.82, rz, cols[0], cols[1], cols[2], seg=14, rings=7, lumps=0.14, seed=int(c.x * 7 + c.y * 3) % 97,
            group="body_nl", flat=0.35, rot=rot)
        for k in range(sub):
            a = (math.atan2(d.y, d.x) if d is not None else rng.uniform(0, math.tau)) + (k - (sub - 1) / 2) * 1.5 + rng.uniform(-0.3, 0.3)
            off = V(math.cos(a), math.sin(a), 0) * rx * 0.7 + V(0, 0, rz * rng.uniform(-0.45, 0.35))
            r2 = rx * rng.uniform(0.5, 0.65)
            pad(self.fol, c + off, r2, r2 * 0.85, rz * 0.8, cols[0], cols[1], cols[2], seg=10, rings=6, lumps=0.16,
                seed=k + int(c.z), group="body_nl", flat=0.35, rot=a)
            out.append((c + off, r2, rz * 0.8))
        return out

    def export(self):
        ps = PartSet(self.name)
        ps.add("trunk", self.trunk, pivot=(0, 0, 0))
        ps.add("foliage", self.fol, pivot=(0, 0, 0))
        if self.blossom is not None:
            ps.add("blossom", self.blossom, pivot=(0, 0, 0))
        if self.fruit is not None:
            ps.add("fruit", self.fruit, pivot=(0, 0, 0))
        tris = ps.export(OUT)
        BUILT.append((self.name, sum(tris.values())))


def rim_points(pads, n_per, rng, up_bias=0.2):
    """Points on the top rim of pads: (point, outward dir)."""
    out = []
    for (c, rx, rz) in pads:
        for i in range(n_per):
            a = i * math.tau / n_per + rng.uniform(-0.2, 0.2)
            d = V(math.cos(a), math.sin(a), 0)
            p = c + V(d.x * rx * 0.92, d.y * rx * 0.78, rz * rng.uniform(-0.05, 0.35 + up_bias))
            out.append((p, d))
    return out


# ───────────── the five trees ─────────────
def build_world(kind="world"):
    t = Tree("tree_world", kind, 301)
    cols = FOLIAGE["world"]
    t.trunk_path([(0, 0, 0), (8, 2, 22), (-10, -2, 42), (-2, 0, 60), (6, 1, 76), (10, 0, 88), (4, 2, 96)], 10.5, 3.2)
    t.roots(5, 30, 9.0, r_k=0.6)                    # five great arches residents walk under
    t.rng.seed(7)
    t.roots(9, 12, 0.6, r_k=0.45)                   # and a skirt of low gripping roots between them                    # sprawling arched roots - residents walk under them
    pads = []
    for (tt, az, ln, rise, rx, rz) in ((0.38, 0.2, 42, 4, 21, 7.5), (0.45, 2.9, 40, 2, 20, 7), (0.55, 1.6, 30, 8, 17, 6.5),
                                        (0.62, -1.2, 26, 10, 15, 6), (0.7, 4.2, 30, 10, 17, 6.5), (0.8, 0.9, 24, 12, 15, 6),
                                        (0.86, 3.6, 22, 12, 14, 5.5), (0.5, -2.4, 30, 4, 16, 6)):
        e, d = t.branch(tt, az, ln, rise, r_k=0.42)
        pads += t.pads(e + V(0, 0, rz * 0.4), rx, rz, cols, d=d, sub=2, rot=az)
    top, _ = t.at(1.0)
    pads += t.pads(top + V(0, 0, 7), 20, 8, cols, sub=3)
    # small rounded leaves studding the pad tops (ancient leafy texture)
    for (p, d) in rim_points(pads, 6, t.rng):
        t.fol.sphere(1.6, pos=p, scl=(1.3, 1.0, 0.45), rot=(0, 0, math.atan2(d.y, d.x)), color=shade(cols[0], 1.04), seg=6,
                     rings=3, group="body_nl")
    # hanging moss strands under the old pads
    for (c, rx, rz) in pads[::3]:
        for s in (-1, 1):
            p = c + V(rx * 0.5 * s, -rx * 0.4, -rz * 0.3)
            leaf(t.trunk, [p, p - V(0, 0.2, 5), p - V(0, 0, 9)], [0.6, 0.45, 0.0], V(0, -1, 0), thick=0.3,
                 color=shade(MOSS, 0.9), group="body_nl")
    t.export()


def build_pine():
    t = Tree("tree_pine", "pine", 311)
    cols = FOLIAGE["pine"]
    # dramatic S-curve trunk, leaning
    t.trunk_path([(0, 0, 0), (14, 0, 14), (-16, 2, 28), (-4, 0, 42), (8, -1, 52), (16, 0, 60), (6, 0, 70)], 6.0, 1.6)
    t.roots(8, 7, 0.4, r_k=0.6)
    pads = []
    for (tt, az, ln, rise, rx, rz) in ((0.32, 3.0, 28, -2, 15, 3.6), (0.45, 0.1, 24, 2, 14, 3.4), (0.58, 2.2, 20, 3, 12, 3.2),
                                        (0.7, -0.8, 18, 3, 11, 3.0), (0.8, 3.8, 16, 3, 10, 2.8), (0.52, -2.6, 18, 0, 10, 3.0)):
        e, d = t.branch(tt, az, ln, rise, r_k=0.4, droop=0.2)
        pads += t.pads(e + V(0, 0, 1.5), rx, rz, cols, d=d, sub=2, rot=az)
    top, _ = t.at(1.0)
    pads += t.pads(top + V(0, 0, 3), 12, 3.6, cols, sub=2)
    # needle tufts: little spiky cones fanning up and out from the pad tops
    for (p, d) in rim_points(pads, 9, t.rng, up_bias=0.3):
        dirn = (d * 0.7 + V(0, 0, 0.8)).normalized()
        rot = dirn.to_track_quat("Z", "Y").to_euler()
        t.fol.cyl(1.0, 0.05, 3.2, pos=p, rot=tuple(rot), color=shade(cols[0], 1.08), seg=4, group="body_nl")
    # jin: a dead silver-white branch stub (classic pine bonsai deadwood)
    p, r = t.at(0.86)
    tube(t.trunk, bezier(p, p + V(-6, 0, 4), p + V(-10, 1, 10), p + V(-12, 2, 12), 5), [r * 0.5, r * 0.4, r * 0.3, r * 0.2, r * 0.12, r * 0.05],
         seg=6, color="d8d2c4", colfn=lambda f: "e6e0d2" if f.normal.z > 0 else "b8b0a2")
    # pine cones hanging under the pads
    for (c, rx, rz) in pads[::2]:
        p = c + V(rx * 0.3, -rx * 0.35, -rz * 0.8)
        t.trunk.sphere(1.0, pos=p, scl=(0.85, 0.85, 1.3), color="9a6a40", seg=6, rings=5, smooth=False,
                       colfn=lambda f: "b07c4a" if f.normal.z > -0.2 else "7a5232")
    t.export()


def build_fruit(bloom_only=False):
    name = "tree_fruit_bloom" if bloom_only else "tree_fruit"
    t = Tree(name, "fruit", 321)
    cols = FOLIAGE["fruit"]
    t.trunk_path([(0, 0, 0), (6, 0, 12), (-6, 0, 24), (-1, 0, 36), (4, 0, 44), (5, 0, 50), (2, 0, 56)], 5.0, 1.8)
    t.roots(8, 6, 0.4, r_k=0.6)
    pads = []
    for (tt, az, ln, rise, rx, rz) in ((0.42, 0.0, 22, 4, 12, 5.5), (0.5, 2.8, 20, 4, 12, 5.5), (0.62, 1.5, 16, 6, 10, 5),
                                        (0.72, -1.3, 14, 8, 10, 5), (0.82, 4.0, 15, 7, 10, 5)):
        e, d = t.branch(tt, az, ln, rise, r_k=0.42)
        pads += t.pads(e + V(0, 0, 3), rx, rz, cols, d=d, sub=2, rot=az)
    top, _ = t.at(1.0)
    pads += t.pads(top + V(0, 0, 5), 13, 6, cols, sub=2)
    t.blossom = Model(name + "_bl", 9)
    for (p, d) in rim_points(pads, 7, t.rng, up_bias=0.4):     # five-petal blossoms on the pads
        up = (V(0, 0, 1) + d * 0.4).normalized()
        star_leaf(t.blossom, p + V(0, 0, 0.3), up, d, 1.5, points=5, inner=0.72, color=BLOSSOM[0], thick=0.2)
        t.blossom.sphere(0.4, pos=p + up * 0.45, scl=(1, 1, 0.5), color="f2c84a", seg=4, rings=2, group="body_nl")
    if not bloom_only:
        t.fruit = Model(name + "_fr", 10)
        for i, (c, rx, rz) in enumerate(pads):                  # big fruit hanging under the pads, camera side
            a = -1.57 + t.rng.uniform(-0.9, 0.9)
            p = c + V(math.cos(a) * rx * 0.55, math.sin(a) * rx * 0.55, -rz * 0.55)
            hang = p - V(0, 0, 2.2)
            tube(t.fruit, [p, hang], [0.18, 0.15], seg=4, color="6a4a32", group="body")
            fruit_ball(t.fruit, hang - V(0, 0, 2.3), 2.3, seg=9, rings=6)
    t.export()


def build_ginkgo(autumn=False):
    name = "tree_ginkgo_autumn" if autumn else "tree_ginkgo"
    t = Tree(name, "ginkgo_autumn" if autumn else "ginkgo", 331)
    cols = FOLIAGE[t.kind]
    # upright, tall and columnar, branches rising
    t.trunk_path([(0, 0, 0), (3, 0, 20), (-4, 0, 40), (0, 0, 55), (2, 0, 66), (1, 0, 74), (0, 0, 80)], 6.0, 1.6)
    t.roots(9, 7, 0.4, r_k=0.6)
    pads = []
    for (tt, az, ln, rise, rx, rz) in ((0.3, 0.3, 18, 4, 10, 4.5), (0.38, 3.3, 17, 5, 10, 4.5), (0.5, 1.9, 13, 7, 9, 4.2),
                                        (0.58, -1.1, 13, 7, 9, 4.2), (0.68, 4.3, 11, 8, 8, 4.0), (0.76, 0.8, 10, 8, 8, 4.0),
                                        (0.86, 2.6, 8, 8, 7, 3.6)):
        e, d = t.branch(tt, az, ln, rise, r_k=0.38, droop=0.05)
        pads += t.pads(e + V(0, 0, 2), rx, rz, cols, d=d, sub=1, rot=az)
    top, _ = t.at(1.0)
    pads += t.pads(top + V(0, 0, 4), 8, 4.5, cols, sub=2)
    for (p, d) in rim_points(pads, 9, t.rng):                   # fan leaves round the pads
        up = (V(0, 0, 1) + d * 0.6).normalized()
        fan_leaf(t.fol, p, up, d, 2.6, color=shade(cols[0], 1.02 if t.rng.random() > 0.4 else 0.94), thick=0.15)
    if autumn:                                                  # yellow carpet of fallen fan leaves at the foot
        for k in range(26):
            a = k * 2.39996
            rr = 6 + 22 * math.sqrt((k + 0.5) / 26)
            p = V(math.cos(a) * rr, math.sin(a) * rr, 0.12)
            fan_leaf(t.fol, p, V(0.1 * math.sin(k), 0.1 * math.cos(k), 1), V(math.cos(k), math.sin(k), 0), 2.2,
                     color=cols[0] if k % 3 else cols[1], thick=0.1)
    t.export()


def build_maple(green=False):
    name = "tree_maple_green" if green else "tree_maple"
    t = Tree(name, "maple_green" if green else "maple", 341)
    cols = FOLIAGE[t.kind]
    # twin trunk: a main stem and a second one splitting low, wide dome of flat pads
    t.trunk_path([(0, 0, 0), (-4, 0, 14), (-10, 0, 28), (-8, 0, 42), (-6, 0, 50), (-2, 0, 56), (0, 0, 60)], 5.6, 1.6)
    main_pts, main_rad = t.tpts, t.trad
    t.roots(8, 7, 0.4, r_k=0.6)
    p0, r = t.at(0.12)
    sec = bezier(p0, p0 + V(8, 0, 8), p0 + V(14, -2, 22), p0 + V(12, 0, 38), 10)
    tube(t.trunk, sec, [r * 0.7 * (1 - 0.65 * j / 10) for j in range(11)], seg=10, color=t.bark, colfn=bark_col(t.bark),
         wobble=gnarl(5))
    pads = []
    for (tt, az, ln, rise, rx, rz) in ((0.5, 2.7, 20, 2, 12, 4.0), (0.62, 1.4, 14, 5, 11, 3.8), (0.72, -1.4, 12, 6, 10, 3.6),
                                        (0.86, 3.9, 12, 6, 10, 3.6)):
        e, d = t.branch(tt, az, ln, rise, r_k=0.42, droop=0.12)
        pads += t.pads(e + V(0, 0, 2), rx, rz, cols, d=d, sub=2, rot=az)
    t.tpts, t.trad = sec, [r * 0.7 * (1 - 0.65 * j / 10) for j in range(11)]
    for (tt, az, ln, rise, rx, rz) in ((0.6, 0.0, 16, 3, 12, 4.0), (0.8, -0.9, 10, 5, 10, 3.6), (0.9, 1.2, 9, 5, 9, 3.4)):
        e, d = t.branch(tt, az, ln, rise, r_k=0.5, droop=0.1)
        pads += t.pads(e + V(0, 0, 2), rx, rz, cols, d=d, sub=2, rot=az)
    t.tpts, t.trad = main_pts, main_rad
    top, _ = t.at(1.0)
    pads += t.pads(top + V(0, 0, 4), 13, 4.5, cols, sub=2)
    for (p, d) in rim_points(pads, 9, t.rng):                   # five-pointed hand leaves round the pads
        up = (V(0, 0, 1) + d * 0.5).normalized()
        star_leaf(t.fol, p, up, d, 2.5, points=5, inner=0.42, color=shade(cols[0], 1.0 if t.rng.random() > 0.35 else 0.9),
                  thick=0.15, cup_k=0.15)
    t.export()


# ───────────── the giant fallen fruit ─────────────
def fruit_ball(m, c, r, group="body", seg=14, rings=9):
    """Round peach-like fruit with a seam and a blush (shared by the tree and the fallen prop)."""
    def col(f):
        n = f.normal
        p = f.calc_center_median() - c
        blush = 0.5 + 0.5 * (n.x * 0.6 - n.y * 0.5 + n.z * 0.3)
        return mix(FRUIT[1], FRUIT[2], max(0.0, min(1.0, blush)))
    m.sphere(r, pos=c, scl=(1.0, 0.96, 0.92), color=FRUIT[0], seg=seg, rings=rings, group=group, colfn=col)
    tube(m, [c + V(0, 0, r * 0.85), c + V(0.15 * r, 0, r * 1.25)], [r * 0.08, r * 0.06], seg=5, color="6a4a32", group=group)
    leaf(m, [c + V(0.1 * r, 0, r * 1.1), c + V(0.6 * r, -0.2 * r, r * 1.3), c + V(1.1 * r, -0.3 * r, r * 1.15)],
         [0.05 * r, 0.3 * r, 0.0], V(0, 0, 1), thick=0.05 * r, color="5fae6a", group="body_nl")


def build_fallen_fruit():
    m = Model("giant_fruit", 351)
    fruit_ball(m, V(0, 0, 1.6), 1.75)
    # a little bruise / dent where it hit the ground
    m.sphere(0.5, pos=(0.9, -1.2, 0.9), scl=(1, 0.4, 1), color="c46a3a", seg=6, rings=3, group="body_nl")
    t = m.export(OUT)
    BUILT.append(("giant_fruit", t))
    # cut open: a half fruit standing on its rounded back, the cut face (juicy flesh + the stone) towards the camera,
    # and a peeled-off quarter lying beside it
    m = Model("giant_fruit_cut", 352)
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
        n = f.normal
        if n.y < -0.9:
            rr = (f.calc_center_median() - c).length
            col = "f6dc8a" if rr > r * 0.62 else "f2c262"
        else:
            col = mix(FRUIT[1], FRUIT[2], max(0.0, min(1.0, 0.5 + 0.5 * (n.x * 0.6 + n.z * 0.3))))
        m._finish(bm, [f], col, n.y >= -0.9)
    m.sphere(0.62, pos=c + V(0, -0.12, 0), scl=(0.8, 0.45, 1.0), color="a0603a", seg=8, rings=5, smooth=False,
             colfn=lambda f: "b87448" if f.normal.y < -0.4 else "86502e")
    # a quarter wedge lying beside it (cut faces up)
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
    t = m.export(OUT)
    BUILT.append(("giant_fruit_cut", t))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("bonsai ->", OUT)
    build_world()
    build_pine()
    build_fruit()
    build_fruit(bloom_only=True)
    build_ginkgo()
    build_ginkgo(autumn=True)
    build_maple()
    build_maple(green=True)
    build_fallen_fruit()
