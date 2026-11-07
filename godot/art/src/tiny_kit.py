"""Tiny-folk building kit (GAME_DESIGN 3.0 materials table, ROADMAP E3-5/E3-6): the residents are tiny people living
under giant flowers, so NOTHING here is a plank, a log or sawn timber. Frames are straight twigs / dry grass stalks /
hollow reed stems lashed with grass cord; walls are woven grass, bark scraps or clay daubed on woven twigs; roofs are
overlapping petals / leaves, tied dry-grass bundles or one big curled leaf; floors and decks are flat pebbles, dry
leaves and reed bundles; containers are acorn caps, seed shells and woven grass.
Shared by build_buildings.py, build_village.py, build_campfire.py (same look as build_pioneer.py's quern house/oven).
Coordinates as lowpoly.py: Blender Z-up, 1 unit = 1 cell (adult resident ~1.0 tall), FRONT = -Y.
"""
import math

import bmesh
from mathutils import Matrix, Vector

from lowpoly import shade, mix  # noqa: F401
from flora_kit import leaf, tube, cup  # noqa: F401

# ───────────── materials ─────────────
REED = "cdbb84"            # dry hollow reed stem
REED_NODE = "a8935e"
REED_GREEN = "9cbf6a"      # fresh reed / grass stalk
REED_GREEN_NODE = "7a9f52"
TWIG = "8a6b52"
TWIG_DARK = "6b5240"
TWIG_PALE = "d8c49a"       # cut end of a twig
WEAVE = "d6bd72"           # woven dry grass (two tones -> basket checker)
WEAVE_DARK = "b39a55"
WEAVE_GREEN = "a9c070"     # woven fresh grass
WEAVE_GREEN_DARK = "8aa65a"
CORD = "8a6a3f"            # grass twine
CORD_GREEN = "7f9f4f"
BARK = "8f6f56"            # bark scraps
BARK_DARK = "6f5442"
BARK_LIGHT = "a88a6c"
DAUB = "ecdcb8"            # clay daub (pale)
DAUB_SHADE = "d9c49c"
DAUB_OCHRE = "e7c48a"
DAUB_OCHRE_SHADE = "d3a96c"
DAUB_ROSE = "efcfc0"
DAUB_ROSE_SHADE = "dbb3a2"
DAUB_WHITE = "f4efe2"
DAUB_WHITE_SHADE = "dfd7c4"
CLAY = "d79a6a"
CLAY_DARK = "b07650"
PEBBLE = "b4b8ae"
PEBBLE_DARK = "959b92"
PEBBLE_WARM = "c4b8a2"
SLATE = "8e9a9c"
ACORN = "9a7448"
ACORN_DARK = "7a5838"
ACORN_IN = "c8a678"
SHELL = "b58650"           # seed shell husk
SHELL_IN = "ecdcb4"
LEAF_A = "7fb565"
LEAF_B = "5f9a52"
LEAF_C = "93c46e"
LEAF_VEIN = "4f8346"
LEAF_DRY = "c99a52"
LEAF_DRY_B = "b8783e"
LILY_PAD = "5aae6e"
LILY_VEIN = "8acb84"
DOOR_DARK = "4a3a32"       # doorway shadow
LIT = "WINDOW_LIT"
FLOUR = "f3e8cf"
DOWN = "f8f4ea"            # dandelion down (bedding)
SMOKE = "eeeae2"
WATER = "WATER"

# roof petals (soft storybook tones next to build_flora.py's PETAL)
PETALS = {
    "pink": ("f2a2b8", "d9849c"), "rose": ("e0607a", "b84a62"), "red": ("d9473c", "b03a32"),
    "orange": ("ef8a3a", "c86e2c"), "gold": ("f4c84c", "d4a536"), "white": ("f6f1e4", "d8d0bc"),
    "violet": ("9a7ad0", "7a5cb0"), "lilac": ("b49ce0", "9580c4"), "blue": ("7f9fdc", "6280c0"),
    "sky": ("8fb8ea", "6e98cc"), "cream": ("f3e6c0", "d6c69c"), "magenta": ("d2569a", "ac4280"),
}


# ───────────── placement ─────────────
def placed(m, fn, pos=(0, 0, 0), rz=0.0, scale=1.0):
    """Run fn() (which builds at the origin, front = -Y) and move what it added to pos, turned rz round Z."""
    before = {g: set(bm.verts) for g, bm in m.groups.items()}      # (bmesh ops may reorder the vert sequence)
    fn()
    mat = Matrix.Translation(Vector(pos)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Scale(scale, 4)
    for g, bm in m.groups.items():
        old = before.get(g, ())
        vs = [v for v in bm.verts if v not in old]
        if vs:
            bmesh.ops.transform(bm, matrix=mat, verts=list(vs))
            bm.normal_update()


def lift(m, dz):
    for bm in m.groups.values():
        bmesh.ops.translate(bm, verts=bm.verts[:], vec=Vector((0, 0, dz)))
        bm.normal_update()


def on_ring(cx, cy, R, a):
    """Point on a round wall (angle a, 0 = +X, -pi/2 = front) and the rotation that turns a front(-Y) feature outward."""
    return (cx + math.cos(a) * R, cy + math.sin(a) * R, 0.0), a + math.pi / 2


# ───────────── sticks & cords ─────────────
def stem(m, a, b, r, col=REED, node=REED_NODE, nodes=2, seg=6, group="body"):
    """Straight reed / grass stalk / twig from a to b with darker node rings (joints)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = d.to_track_quat("Z", "Y").to_euler()
    m.cyl(r, r * 0.9, d.length, pos=a, rot=rot, color=col, seg=seg, smooth=True, cap=shade(col, 1.15),
          bottom_cap=shade(col, 1.15), group=group)
    for k in range(nodes):
        t = (k + 1) / (nodes + 1)
        m.cyl(r * 1.18, r * 1.18, min(0.03, d.length * 0.05), pos=a + d * t, rot=rot, color=node, seg=max(4, seg - 1),
              smooth=True, group=group)


def twig(m, a, b, r, col=TWIG, fork=0.0, seg=5, group="body"):
    """Thin straight twig with pale cut ends; fork > 0 adds a little side shoot near the top."""
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = d.to_track_quat("Z", "Y").to_euler()
    m.cyl(r, r * 0.75, d.length, pos=a, rot=rot, color=col, seg=seg, cap=TWIG_PALE, bottom_cap=TWIG_PALE, group=group)
    if fork:
        p = a + d * 0.72
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-4:
            side = Vector((1, 0, 0))
        q = p + d.normalized() * fork * 0.8 + side.normalized() * fork * 0.6
        dd = q - p
        m.cyl(r * 0.6, r * 0.4, dd.length, pos=p, rot=dd.to_track_quat("Z", "Y").to_euler(), color=col, seg=4,
              cap=TWIG_PALE, group=group)


def lash(m, p, r=0.06, col=CORD):
    """Grass-twine lashing knot where stems meet."""
    m.sphere(r, pos=p, scl=(1, 1, 0.7), color=col, seg=6, rings=3)


def cord(m, a, b, sag=0.0, r=0.012, col=CORD, n=4, group="body_nh"):
    """Grass cord from a to b sagging by sag (thin, no outline)."""
    a, b = Vector(a), Vector(b)
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append(a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t))))
    for p, q in zip(pts[:-1], pts[1:]):
        d = q - p
        m.cyl(r, r, d.length, pos=p, rot=d.to_track_quat("Z", "Y").to_euler(), color=col, seg=4, group=group)
    return pts


def forked_post(m, x, y, h, r=0.04, col=TWIG):
    """Forked twig stuck in the ground: a Y at the top to rest a rail on."""
    twig(m, (x, y, -0.02), (x, y, h - 0.08), r, col)
    for s in (-1, 1):
        twig(m, (x, y, h - 0.1), (x + s * 0.09, y, h + 0.06), r * 0.7, col)


def twig_fence(m, x0, y0, x1, y1, h=0.42, step=0.32, gap=None, col=TWIG, cord_col=CORD, seed=0):
    """Fence of twigs and grass stalks stuck in the ground, two sagging grass cords woven through.
    gap = (t0, t1) along the run left open (gate)."""
    L = math.hypot(x1 - x0, y1 - y0)
    n = max(1, int(L / step))
    tops = []
    for k in range(n + 1):
        t = k / n
        if gap and gap[0] < t < gap[1]:
            tops.append(None)
            continue
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        hh = h * (0.86 + 0.14 * ((k * 7 + seed) % 3) / 2)
        lean = 0.04 * (((k + seed) % 3) - 1)
        if (k + seed) % 3 == 1:
            stem(m, (x, y, -0.02), (x + lean, y, hh), 0.03, REED_GREEN, REED_GREEN_NODE, 1, 4)
        else:
            twig(m, (x, y, -0.02), (x + lean, y, hh), 0.03, col if k % 2 else TWIG_DARK, fork=0.08 if k % 4 == 0 else 0,
                 seg=4)
        tops.append((x, y))
    for z in (h * 0.42, h * 0.8):
        run = []
        for p in tops + [None]:
            if p is None:
                if len(run) >= 2:
                    cord(m, (run[0][0], run[0][1], z), (run[-1][0], run[-1][1], z), sag=0.03, r=0.013, col=cord_col,
                         n=max(2, len(run) // 2))
                run = []
            else:
                run.append(p)


# ───────────── bundles, piles ─────────────
def reed_bundle(m, a, b, r, col=REED, node=REED_NODE, ties=2, n=5, seg=5, group="body"):
    """A tied bundle of reeds/grass stalks from a to b (round section of n stems + a core) with cord ties."""
    a, b = Vector(a), Vector(b)
    d = b - a
    q = d.to_track_quat("Z", "Y")
    rot = q.to_euler()
    m.cyl(r * 0.8, r * 0.8, d.length, pos=a, rot=rot, color=shade(col, 0.9), seg=seg, smooth=True, group=group)
    for k in range(n):
        ang = k * math.tau / n
        off = q @ Vector((math.cos(ang) * r * 0.55, math.sin(ang) * r * 0.55, 0))
        sh = (1.0, 0.92, 1.06)[k % 3]
        m.cyl(r * 0.42, r * 0.4, d.length * (0.97 + 0.03 * (k % 2)), pos=a + off, rot=rot, color=shade(col, sh), seg=5,
              smooth=True, cap=TWIG_PALE if col == REED else shade(col, 1.2), bottom_cap=shade(col, 1.2), group=group)
    for t in [(i + 1) / (ties + 1) for i in range(ties)]:
        m.cyl(r * 1.05, r * 1.05, min(0.06, d.length * 0.06), pos=a + d * t, rot=rot, color=CORD, seg=seg + 1, group=group)


def twig_stack(m, x, y, z, L, rows=3, per=5, r=0.045, rz=0.0, cord_col=CORD):
    """Neat stack of straight twigs lying along local X (pale cut ends showing), tied round the middle."""
    def _b():
        for row in range(rows):
            n = per - row
            for i in range(n):
                yy = -((n - 1) * 2 * r) / 2 + i * 2 * r
                zz = z + r + row * r * 1.7
                ln = L * (0.9 + 0.1 * ((i + row) % 3) / 2)
                col = (TWIG, TWIG_DARK, "9a7a5c")[(i + row) % 3]
                m.cyl(r, r, ln, pos=(-ln / 2, yy, zz), rot=(0, math.pi / 2, 0), color=col, seg=6, cap=TWIG_PALE,
                      bottom_cap=TWIG_PALE)
        hh = r * 1.7 * rows + 0.03
        for xx in (-L * 0.28, L * 0.28):
            m.box((0.05, per * 2 * r + 0.04, 0.03), pos=(xx, 0, z + hh), color=cord_col)
    placed(m, _b, (x, y, 0), rz)


def split_reeds(m, x, y, z, L, n=5, rz=0.0):
    """Stack of split reed strips (the tiny folk's '판자'): flat pale half-stems with a green rind edge."""
    def _b():
        for k in range(n):
            zz = z + k * 0.05
            yy = (k % 2 - 0.5) * 0.04
            m.box((L, 0.16, 0.035), pos=(0, yy, zz), rot=(0, 0, (k % 3 - 1) * 0.05), color=("e6d6a6", "dccb98")[k % 2])
            m.box((L * 1.0, 0.03, 0.04), pos=(0, yy - 0.08, zz), rot=(0, 0, (k % 3 - 1) * 0.05), color=REED_GREEN)
        m.box((0.04, 0.22, n * 0.05 + 0.02), pos=(L * 0.25, 0, z - 0.01), color=CORD)
    placed(m, _b, (x, y, 0), rz)


# ───────────── stones ─────────────
def pebble(m, x, y, z, rx, ry, rz_, col=PEBBLE, rot=0.0, seed=0, group="body"):
    m.sphere(1.0, pos=(x, y, z), scl=(rx, ry, rz_), rot=(0, 0, rot), color=col, seg=7, rings=3, lumps=0.06,
             seed=seed, group=group)


def pebble_path(m, pts, s=0.13, col=PEBBLE):
    for k, (x, y) in enumerate(pts):
        pebble(m, x, y, 0.0, s * (1.1 if k % 2 else 0.9), s * 0.8, 0.035, shade(col, 0.95 + 0.07 * (k % 2)), k * 0.7, k)


def pebble_floor(m, cx, cy, rx, ry, n=10, col=PEBBLE, z=0.02, seed=0):
    for k in range(n):
        a = k * 2.399 + seed
        rr = math.sqrt((k + 0.5) / n)
        pebble(m, cx + math.cos(a) * rr * rx, cy + math.sin(a) * rr * ry, z, 0.13, 0.1, 0.03,
               shade(col, 0.94 + 0.08 * (k % 3) / 2), a, k + seed)


# ───────────── walls ─────────────
def lathe(m, cx, cy, z0, prof, seg=14, color=WEAVE, colfn=None, group="body", smooth=True, top=None):
    """Surface of revolution through prof [(r, z)] (outward faces). colfn(face, i_ring, i_seg) -> colour.
    top = colour of a flat cap on the last ring (None = open)."""
    bm = m._bm(group)
    rings = [[Vector((cx + math.cos(i * math.tau / seg) * r, cy + math.sin(i * math.tau / seg) * r, z0 + z))
              for i in range(seg)] for r, z in prof]
    fs = m.strip(rings, color=color, group=group, smooth=smooth, close=True)
    c0 = Vector((cx, cy, 0))
    for idx, f in enumerate(fs):
        f.normal_update()
        c = f.calc_center_median()
        radial = Vector((c.x - cx, c.y - cy, 0))
        if radial.length > 1e-5 and radial.dot(f.normal) < 0:
            f.normal_flip()
        if colfn:
            m._finish(bm, [f], colfn(f, idx // seg, idx % seg), smooth)
    if top is not None:
        tf = bm.faces.new([bm.verts.new(p) for p in rings[-1]])
        tf.normal_update()
        if tf.normal.z < 0:
            tf.normal_flip()
        m._finish(bm, [tf], top, False)
        fs.append(tf)
    bm.normal_update()
    _ = c0
    return fs


def weave_fn(a=WEAVE, b=WEAVE_DARK):
    """Basket checker: alternate shade per (ring + segment)."""
    return lambda f, i, j: a if (i + j) % 2 else b


def woven_round(m, cx, cy, R, H, z0=0.0, cols=(WEAVE, WEAVE_DARK), rows=6, seg=16, stakes=True, bulge=0.0, top_r=None):
    """Round woven-grass wall (basket checker), twig stakes poking out of the rim."""
    top_r = R * 0.97 if top_r is None else top_r
    prof = []
    for i in range(rows + 1):
        t = i / rows
        prof.append((R + (top_r - R) * t + bulge * math.sin(math.pi * t), H * t))
    lathe(m, cx, cy, z0, prof, seg=seg, colfn=weave_fn(*cols))
    m.cyl(top_r + 0.03, top_r + 0.03, 0.06, pos=(cx, cy, z0 + H - 0.03), color=CORD, seg=seg, smooth=True)
    if stakes:
        for k in range(seg // 2):
            a = k * math.tau / (seg // 2) + 0.2
            x, y = cx + math.cos(a) * (top_r + 0.01), cy + math.sin(a) * (top_r + 0.01)
            twig(m, (x, y, z0 + H - 0.12), (x, y, z0 + H + 0.09), 0.022, TWIG_DARK)


def daub_round(m, cx, cy, R, H, z0=0.0, col=DAUB, dark=DAUB_SHADE, seg=16, ribs=True, top_r=None):
    """Round wall of clay daubed on woven twigs: mottled clay, a few twig ribs showing where the clay wore off."""
    top_r = R * 0.96 if top_r is None else top_r
    prof = [(R + 0.03, 0.0), (R, H * 0.12), (R * 0.99 + top_r * 0.01, H * 0.6), (top_r, H)]

    def cf(f, i, j):
        return dark if i == 0 or (j * 5 + i * 3) % 7 == 0 else col
    lathe(m, cx, cy, z0, prof, seg=seg, colfn=cf)
    if ribs:
        for k in range(3):
            a = -math.pi / 2 + (k - 1) * 1.15 + 0.4
            for j in range(3):
                z = z0 + H * (0.3 + 0.12 * j)
                rr = R * 0.995 + 0.012
                p = (cx + math.cos(a) * rr, cy + math.sin(a) * rr, z)
                d = Vector((-math.sin(a), math.cos(a), 0)) * 0.12
                stem(m, Vector(p) - d, Vector(p) + d, 0.016, TWIG, TWIG_DARK, 0, 4)


def pebble_round(m, cx, cy, R, H, z0=0.0, col=PEBBLE, dark=PEBBLE_DARK, seg=16, courses=5, knobs=8, seed=0):
    """Round wall of stacked pebbles: offset courses of light/dark stones + a few pebbles bulging out."""
    prof = [(R * (1.0 - 0.04 * i / courses), H * i / courses) for i in range(courses + 1)]

    def cf(f, i, j):
        k = (j + (i % 2)) // 2
        return (col, dark, shade(col, 1.06), PEBBLE_WARM)[(k * 3 + i * 5 + seed) % 4]
    lathe(m, cx, cy, z0, prof, seg=seg, colfn=cf, smooth=False)
    for k in range(knobs):
        a = k * math.tau / knobs + 0.3 + seed
        z = H * (0.15 + 0.7 * ((k * 3) % 5) / 4)
        rr = R * (1.0 - 0.04 * z / H)
        pebble(m, cx + math.cos(a) * rr, cy + math.sin(a) * rr, z0 + z, 0.13, 0.13, 0.08, shade(col, 0.92 + 0.1 * (k % 2)),
               a + math.pi / 2, k + seed)


def woven_panel(m, x0, x1, y, z0, h, rows=5, cols=(WEAVE, WEAVE_DARK), stakes=True, th=0.05):
    """Flat woven-grass screen along X at y: offset bands (basket checker) between twig stakes."""
    w = x1 - x0
    nc = max(2, int(w / 0.22))
    for r in range(rows):
        for c in range(nc):
            m.box((w / nc + 0.002, th, h / rows + 0.002), pos=(x0 + (c + 0.5) * w / nc, y + (0.01 if (r + c) % 2 else -0.01),
                  z0 + r * h / rows), color=cols[(r + c) % 2])
    if stakes:
        for k in range(nc + 1):
            stem(m, (x0 + k * w / nc, y, z0 - 0.02), (x0 + k * w / nc, y, z0 + h + 0.06), 0.02, TWIG, TWIG_DARK, 1, 4)


def daub_box(m, W, D, H, col=DAUB, dark=DAUB_SHADE, posts=REED, z0=0.0, post_r=0.06, mid_posts=0):
    """Box walls of clay daub with reed corner posts (node rings) lashed at the top, a darker clay foot."""
    m.box((W, D, H), pos=(0, 0, z0), color=col,
          colfn=lambda f: dark if f.calc_center_median().z < z0 + 0.1 else col)
    m.box((W + 0.04, D + 0.04, 0.12), pos=(0, 0, z0), color=dark)
    xs = [-W / 2, W / 2] + [(-W / 2 + W * (k + 1) / (mid_posts + 1)) for k in range(mid_posts)]
    for x in xs:
        for y in (-D / 2, D / 2):
            if abs(x) < W / 2 - 1e-3 and y > 0:
                continue
            stem(m, (x, y, z0 - 0.02), (x, y, z0 + H + 0.05), post_r, posts, REED_NODE if posts == REED else shade(posts, 0.8), 2)
            lash(m, (x, y, z0 + H - 0.05), post_r * 1.2)
    stem(m, (-W / 2 - 0.08, -D / 2 - 0.01, z0 + H - 0.04), (W / 2 + 0.08, -D / 2 - 0.01, z0 + H - 0.04), post_r * 0.75, posts, REED_NODE, 1)


def woven_box(m, W, D, H, cols=(WEAVE, WEAVE_DARK), z0=0.0, posts=REED, post_r=0.06):
    """Box walls: woven-grass panels on all four sides in a reed frame."""
    m.box((W - 0.04, D - 0.04, H), pos=(0, 0, z0), color=cols[1])          # backing so the panels read solid
    woven_panel(m, -W / 2, W / 2, -D / 2, z0, H, rows=max(3, int(H / 0.2)), cols=cols, stakes=False)
    for sx in (-1, 1):
        def _side(sx=sx):
            woven_panel(m, -D / 2, D / 2, 0, z0, H, rows=max(3, int(H / 0.2)), cols=cols, stakes=False)
        placed(m, _side, (sx * W / 2, 0, 0), math.pi / 2)
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            stem(m, (x, y, z0 - 0.02), (x, y, z0 + H + 0.06), post_r, posts, REED_NODE, 2)
            lash(m, (x, y, z0 + H - 0.04), post_r * 1.2)
    stem(m, (-W / 2 - 0.08, -D / 2 - 0.02, z0 + H), (W / 2 + 0.08, -D / 2 - 0.02, z0 + H), post_r * 0.75, posts, REED_NODE, 1)


def pebble_box(m, W, D, H, col=PEBBLE, dark=PEBBLE_DARK, z0=0.0, courses=5, seed=0):
    """Box walls of stacked flat pebbles in offset courses (light/dark/warm stones), rounded corner stones."""
    ch = H / courses
    for c in range(courses):
        z = z0 + c * ch
        for (w, d, y0, x0, along) in ((W, D, -D / 2, 0, "x"), (W, D, D / 2, 0, "x"), (D, W, 0, -W / 2, "y"), (D, W, 0, W / 2, "y")):
            n = max(2, int(w / 0.34))
            off = 0.5 if c % 2 else 0.0
            for k in range(n):
                t0 = -w / 2 + (k + off) * w / n
                t1 = min(w / 2, t0 + w / n)
                if t1 - t0 < 0.05:
                    continue
                cc = (col, dark, shade(col, 1.06), PEBBLE_WARM)[(k * 3 + c * 5 + seed + (0 if along == "x" else 1)) % 4]
                if along == "x":
                    m.box((t1 - t0 - 0.015, 0.06, ch - 0.012), pos=((t0 + t1) / 2, y0, z), color=cc)
                else:
                    m.box((0.06, t1 - t0 - 0.015, ch - 0.012), pos=(x0, (t0 + t1) / 2, z), color=cc)
    m.box((W - 0.04, D - 0.04, H), pos=(0, 0, z0), color=dark)
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            for c in range(0, courses, 2):
                pebble(m, x, y, z0 + (c + 0.5) * ch, 0.12, 0.12, ch * 0.7, shade(col, 0.95 + 0.06 * (c % 3)), c, c + seed)


# ───────────── roofs ─────────────
def _petal_solid(m, base, d, ln, w, nrm, col, under, curl=0.08, segs=3, group="body_nl"):
    """One petal as a thin closed solid from base along d: narrow at the base, round-tipped."""
    d = d.normalized()
    pts = [base + d * ln * (i / segs) + nrm * (curl * ln * (i / segs) ** 2) for i in range(segs + 1)]
    shape = {2: (0.45, 1.0, 0.5), 3: (0.35, 0.92, 0.9, 0.42), 4: (0.3, 0.82, 1.0, 0.86, 0.36)}[segs]
    leaf(m, pts, [w * s for s in shape], nrm, thick=max(0.03, w * 0.14), color=col, color_under=under, group=group)


def petal_cone(m, cx, cy, z0, R, rise, col="pink", courses=4, per=11, over=0.28, flare=0.12, tip=True, seed=0,
               alt=None):
    """Cone roof of overlapping petal shingles (courses from the eave up, each overlapping the one below).
    col = PETALS key; alt = second PETALS key mixed in every other petal."""
    c0, cu = PETALS[col]
    a0, au = PETALS[alt] if alt else (c0, cu)
    Re = R + over
    # solid core cone in the under colour so nothing shows through between petals
    m.cyl(Re * 0.93, 0.05, rise * 1.02, pos=(cx, cy, z0 + 0.02), color=cu, seg=14, smooth=True, group="body_nl")
    slope = math.atan2(rise, Re)
    for c in range(courses):
        t = c / courses                      # 0 = eave course
        r = Re * (1 - t)
        z = z0 + rise * t
        n = max(5, int(round(per * (1 - t * 0.55))))
        ln = (Re / courses) * 1.75 / math.cos(slope) * (1.0 if c else 1.08)
        w = math.tau * r / n * 0.68 + 0.06
        for k in range(n):
            a = k * math.tau / n + (0.5 * math.tau / n if c % 2 else 0) + seed
            out = Vector((math.cos(a), math.sin(a), 0))
            down = (out * math.cos(slope) - Vector((0, 0, 1)) * math.sin(slope)).normalized()
            nrm = (out * math.sin(slope) + Vector((0, 0, 1)) * math.cos(slope)).normalized()
            tip_p = Vector((cx, cy, z)) + out * r + nrm * 0.03 + down * (flare * (1 - t) if c == 0 else 0)
            base = tip_p - down * ln
            use_alt = alt and (k + c) % 2
            v = 0.94 + 0.06 * ((k * 5 + c * 3) % 3)
            _petal_solid(m, base, down, ln, w, nrm, shade(a0 if use_alt else c0, v), au if use_alt else cu,
                         curl=-0.12 if c == 0 else 0.05)
    if tip:
        zt = z0 + rise
        for k in range(5):                    # little closed bud on top
            a = k * math.tau / 5 + seed
            out = Vector((math.cos(a), math.sin(a), 0))
            base = Vector((cx, cy, zt - 0.12)) + out * 0.04
            _petal_solid(m, base, (out * 0.35 + Vector((0, 0, 1))), 0.34, 0.11, out, c0, cu, curl=-0.25, segs=2)
        tube(m, [Vector((cx, cy, zt + 0.15)), Vector((cx + 0.05, cy, zt + 0.32)), Vector((cx + 0.14, cy, zt + 0.38))],
             [0.035, 0.03, 0.02], seg=5, color=LEAF_B)


def petal_gable(m, W, D, H, rise, col="violet", rows=3, per=None, over=0.24, alt=None, ridge=LEAF_B, z_ridge=None):
    """Gable roof (ridge along X) shingled with overlapping petals, rounded petal tips along the eaves,
    a rolled leaf along the ridge. Solid slab underneath in the under colour."""
    c0, cu = PETALS[col]
    a0, au = PETALS[alt] if alt else (c0, cu)
    half = D / 2 + over
    ang = math.atan2(rise, half)
    ln_s = math.hypot(half, rise)
    per = per or max(4, int((W + 2 * over) / 0.42))
    for sy in (-1, 1):
        # under slab
        prof = [(0, H + rise + 0.0), (sy * half, H - 0.02), (sy * half, H - 0.08), (0, H + rise - 0.08)]
        m.prism([(y, z) for y, z in prof] if sy < 0 else [(y, z) for y, z in reversed(prof)], W + over * 1.4,
                color=cu, group="body_nl")
        down = Vector((0, sy * math.cos(ang), -math.sin(ang)))
        nrm = Vector((0, sy * math.sin(ang), math.cos(ang)))
        for r in range(rows):                 # r = 0 = eave row (drawn first, upper rows overlap it)
            t = r / rows
            n = per if r % 2 == 0 else per - 1
            ln = ln_s / rows * 1.7
            w = (W + over * 1.4) / per * 0.72 + 0.03
            for k in range(n):
                x = -(W + over * 1.2) / 2 + (k + (0.5 if r % 2 == 0 else 1.0)) * (W + over * 1.2) / per
                tip = Vector((x, sy * half * (1 - t), H + rise * t)) + nrm * (0.04 + 0.01 * r)
                base = tip - down * ln
                use_alt = alt and (k + r) % 2
                v = 0.94 + 0.06 * ((k * 5 + r * 3) % 3)
                _petal_solid(m, base, down, ln, w, nrm, shade(a0 if use_alt else c0, v), au if use_alt else cu,
                             curl=-0.1 if r == 0 else 0.04)
    zr = H + rise + 0.05 if z_ridge is None else z_ridge
    m.cyl(0.08, 0.08, W + over * 1.6, pos=(-(W + over * 1.6) / 2, 0, zr), rot=(0, math.pi / 2, 0),
          color=ridge, seg=8, smooth=True, cap=LEAF_VEIN, bottom_cap=LEAF_VEIN, group="body_nl")


def leaf_gable(m, W, D, H, rise, n=3, over=0.22, seed=0, cols=(LEAF_A, LEAF_B, LEAF_C)):
    """Gable roof (ridge along X) shingled with big pointed leaves in two rows per slope (the upper row overlapping
    the lower), each with a pale midrib; a rolled leaf along the ridge."""
    half = D / 2 + over
    ang = math.atan2(rise, half)
    ln = math.hypot(half, rise)
    Wt = W + over * 1.2
    for sy in (-1, 1):
        prof = [(0, H + rise), (sy * half, H - 0.02), (sy * half, H - 0.08), (0, H + rise - 0.08)]
        m.prism(prof if sy < 0 else list(reversed(prof)), Wt, color=LEAF_VEIN, group="body_nl")
        down = Vector((0, sy * math.cos(ang), -math.sin(ang)))
        nrm = Vector((0, sy * math.sin(ang), math.cos(ang)))
        for row in (0, 1):                     # 0 = eave row (under), 1 = ridge row (over)
            nn = n + 1 if row == 0 else n
            t0, L = (0.42, ln * 0.58 + 0.16) if row == 0 else (0.0, ln * 0.62)
            for k in range(nn):
                x = -Wt / 2 + (k + (0.0 if row == 0 else 0.5)) * Wt / n
                x = max(-Wt / 2 + 0.1, min(Wt / 2 - 0.1, x))
                base = Vector((x, 0, H + rise)) + down * (ln * t0) + nrm * (0.035 + 0.035 * row)
                pts = [base + down * L * (i / 5) + nrm * (0.05 * math.sin(math.pi * i / 5)) for i in range(6)]
                wd = Wt / n * (0.62 if row == 0 else 0.7)
                c = cols[(k * 2 + row + seed) % len(cols)]
                leaf(m, pts, [wd * s for s in (0.3, 0.85, 1.0, 0.85, 0.45, 0.02)], nrm, thick=0.05, color=c,
                     color_under=shade(c, 0.8))
                tube(m, [p + nrm * 0.045 for p in pts[:5]], [0.02, 0.018, 0.015, 0.012, 0.008], seg=3,
                     color=shade(c, 1.25), group="body_nh")
    m.cyl(0.08, 0.08, W + over * 1.6, pos=(-(W + over * 1.6) / 2, 0, H + rise + 0.04), rot=(0, math.pi / 2, 0),
          color=cols[1], seg=8, smooth=True, cap=LEAF_VEIN, bottom_cap=LEAF_VEIN, group="body_nl")


def bundle_gable(m, W, D, H, rise, col=WEAVE, dark=WEAVE_DARK, over=0.24, spacing=0.2):
    """Gable roof (ridge along X) thatched with tied dry-grass bundles in two overlapping courses per slope: each
    bundle flares to a pale cut end, so the eave and the mid-slope show a row of round bundle ends; dark cord ties
    across each course; a fat ridge bundle."""
    half = D / 2 + over
    ang = math.atan2(rise, half)
    ln = math.hypot(half, rise) + 0.05
    Wt = W + over * 1.4
    n = max(4, int(Wt / spacing))
    for sy in (-1, 1):
        prof = [(0, H + rise), (sy * half, H - 0.02), (sy * half, H - 0.07), (0, H + rise - 0.07)]
        m.prism(prof if sy < 0 else list(reversed(prof)), Wt, color=dark, group="body_nl")
        down = Vector((0, sy * math.cos(ang), -math.sin(ang)))
        nrm = Vector((0, sy * math.sin(ang), math.cos(ang)))
        for course, (t0, t1, lift_) in enumerate(((0.45, 1.0, 0.05), (0.0, 0.58, 0.11))):
            for k in range(n):
                x = -Wt / 2 + (k + 0.5 + 0.5 * course) * Wt / n
                if x > Wt / 2 - 0.05:
                    continue
                a = Vector((x, 0, H + rise)) + down * (ln * t0) + nrm * lift_
                b = Vector((x, 0, H + rise)) + down * (ln * t1) + nrm * (lift_ + 0.03)
                d = b - a
                r = Wt / n * 0.55
                c = col if (k + course) % 2 else shade(col, 0.92)
                m.cyl(r * 0.8, r * 1.2, d.length, pos=a, rot=d.to_track_quat("Z", "Y").to_euler(), color=c, seg=6,
                      smooth=True, cap=TWIG_PALE, group="body_nl")
            p = Vector((0, 0, H + rise)) + down * (ln * (t0 + (t1 - t0) * 0.35)) + nrm * (lift_ + Wt / n * 0.55)
            m.box((Wt + 0.02, 0.05, 0.05), pos=p, rot=(-sy * ang, 0, 0), color="6f5430", group="body_nl")
    reed_bundle(m, (-(W + over * 1.8) / 2, 0, H + rise + 0.08), ((W + over * 1.8) / 2, 0, H + rise + 0.08), 0.12, col,
                dark, ties=3, n=6, group="body_nl")


def grass_cone(m, cx, cy, z0, R, rise, col=WEAVE, dark=WEAVE_DARK, over=0.28, ties=2, seg=18, knot=True):
    """Cone roof of tied dry-grass bundles: ridged lathe (one ridge per bundle), cord tie bands, splayed top knot."""
    Re = R + over
    prof = [(Re + 0.02, -0.06), (Re, 0.0)]
    for i in range(1, 6):
        t = i / 6
        prof.append((Re * (1 - t) ** 1.05, rise * t))
    prof.append((0.06, rise))
    bm = m._bm("body_nl")
    rings = []
    for j, (r, z) in enumerate(prof):
        ring = []
        for i in range(seg * 2):
            a = i * math.tau / (seg * 2)
            rr = r * (1.0 + (0.045 if i % 2 == 0 else -0.02))
            ring.append(Vector((cx + math.cos(a) * rr, cy + math.sin(a) * rr, z0 + z)))
        rings.append(ring)
    fs = m.strip(rings, color=col, group="body_nl", smooth=True, close=True)
    for idx, f in enumerate(fs):
        f.normal_update()
        c = f.calc_center_median()
        if Vector((c.x - cx, c.y - cy, 0)).dot(f.normal) < 0 and f.normal.z < 0.99:
            f.normal_flip()
        j = idx // (seg * 2)
        m._finish(bm, [f], dark if j == 0 else (col if (idx // 2) % 2 else shade(col, 0.92)), True)
    bm.normal_update()
    for t in [0.32 + 0.3 * i for i in range(ties)][:ties]:
        r = Re * (1 - t) + 0.03
        m.cyl(r, r * 0.97, 0.06, pos=(cx, cy, z0 + rise * t - 0.03), color=CORD, seg=seg, smooth=True, group="body_nl")
    if knot:
        m.cyl(0.1, 0.09, 0.12, pos=(cx, cy, z0 + rise - 0.06), color=CORD, seg=8, group="body_nl")
        for k in range(7):
            a = k * math.tau / 7
            m.blade((cx, cy, z0 + rise + 0.04), (cx + math.cos(a) * 0.22, cy + math.sin(a) * 0.22, z0 + rise + 0.3),
                    0.07, color=col if k % 2 else dark)


def curled_leaf_roof(m, L, W, H, col=LEAF_A, dark=LEAF_B, vein="b8dc98", z0=0.0, K=10, J=10, tip_curl=0.45,
                     stalk=True, x0=0.0):
    """One big leaf bent over as an arched roof: midrib along X on top, the two halves curving down to z0 at the
    sides (half-width W/2), pointed at both ends (tip at +X curling up, stalk at -X). Two-tone halves, pale veins."""
    outer, inner = [], []
    for k in range(K + 1):
        t = k / K
        x = x0 - L / 2 + L * t
        wf = math.sin(math.pi * min(1.0, 0.02 + 0.98 * t)) ** 0.7
        hw = W / 2 * wf + 0.015
        top = z0 + H * (0.55 + 0.45 * wf) + tip_curl * max(0.0, t - 0.8) ** 2 * 6
        ring_o, ring_i = [], []
        for j in range(J + 1):
            a = math.pi * j / J
            y = -math.cos(a) * hw
            zz = z0 + (top - z0) * (math.sin(a) ** 0.6) * (0.4 + 0.6 * wf) + (top - z0) * 0.6 * (1 - wf) * math.sin(a)
            ring_o.append(Vector((x, y, zz)))
            ring_i.append(Vector((x, y * 0.94, zz - 0.05)))
        outer.append(ring_o)
        inner.append(ring_i)
    fo = m.strip(outer, color=col, group="body_nl", smooth=True)
    fi = m.strip(inner, color=dark, group="body_nl", smooth=True)
    fe = m.strip([[r[0] for r in outer], [r[0] for r in inner]], color=dark, group="body_nl")
    fe += m.strip([[r[-1] for r in outer], [r[-1] for r in inner]], color=dark, group="body_nl")
    bm = m._bm("body_nl")
    mid = Vector((x0, 0, z0))
    for f in fo:
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(Vector((0, c.y, c.z - z0 + 0.3))) < 0:
            f.normal_flip()
        m._finish(bm, [f], col if c.y < 0 else shade(col, 0.9), True)
    for f in fi:
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(Vector((0, c.y, c.z - z0 + 0.3))) > 0:
            f.normal_flip()
    for f in fe:
        f.normal_update()
        if f.normal.z > 0.2:
            f.normal_flip()
    bm.normal_update()
    _ = mid
    # midrib + side veins following the surface out to the edges
    rib = [r[J // 2] + Vector((0, 0, 0.03)) for r in outer]
    tube(m, rib, [0.07 - 0.055 * i / K for i in range(K + 1)], seg=5, color=vein, group="body")
    for k in range(1, K - 1, 2):
        for side in (-1, 1):
            path = []
            for s_ in range(0, J // 2 + 1, 1):
                j = J // 2 + side * s_
                kk = min(K, k + round(s_ * 0.35))
                p = outer[kk][j]
                off = Vector((0, p.y, p.z - z0 + 0.2)).normalized() * 0.025
                path.append(p + off)
            if len(path) > 1:
                tube(m, path[:-1], [0.022 - 0.012 * i / len(path) for i in range(len(path) - 1)], seg=3, color=vein,
                     group="body_nh")
    if stalk:
        a = outer[0][J // 2]
        tube(m, [a, a + Vector((-0.25, 0, 0.05)), a + Vector((-0.45, 0, -0.08))], [0.06, 0.05, 0.04], seg=5,
             color=dark, cap=shade(dark, 1.3))
    return outer


def bell_roof(m, cx, cy, z0, R, rise, col="blue", n=6, over=0.32, flare=0.22):
    """Upside-down bell-flower roof: n broad petals from the top down over the eaves, flaring out and curling
    up at the tips (scalloped rim). A stalk curls up from the top."""
    c0, cu = PETALS[col]
    Re = R + over
    m.cyl(Re * 0.86, 0.08, rise * 0.98, pos=(cx, cy, z0 + 0.04), color=cu, seg=14, smooth=True, group="body_nl")
    for k in range(n):
        a = k * math.tau / n
        out = Vector((math.cos(a), math.sin(a), 0))
        pts = []
        J = 5
        for j in range(J + 1):
            t = j / J
            rr = Re * math.sin(t * math.pi / 2) ** 0.8 + flare * max(0.0, t - 0.75) * 4
            z = z0 + rise * (1 - t ** 1.6) + flare * 0.9 * max(0.0, t - 0.8) * 5
            pts.append(Vector((cx, cy, 0)) + out * rr + Vector((0, 0, z)))
        ws = [0.06, Re * 0.42, Re * 0.6, Re * 0.66, Re * 0.6, Re * 0.4]
        nrm = []
        for j in range(J + 1):
            tng = (pts[min(J, j + 1)] - pts[max(0, j - 1)]).normalized()
            side = out.cross(Vector((0, 0, 1)))
            nn = side.cross(tng).normalized()
            if nn.dot(out) < 0:
                nn = -nn
            nrm.append(nn)
        leaf(m, pts, ws, nrm, thick=0.06, color=c0 if k % 2 else shade(c0, 0.95), color_under=cu)
        tube(m, [p + nn * 0.05 for p, nn in zip(pts[1:5], nrm[1:5])], [0.02, 0.02, 0.016, 0.01], seg=3,
             color=shade(c0, 0.8), group="body_nh")
    zt = z0 + rise
    tube(m, [Vector((cx, cy, zt - 0.05)), Vector((cx, cy, zt + 0.22)), Vector((cx + 0.12, cy, zt + 0.4)),
             Vector((cx + 0.3, cy, zt + 0.42))], [0.07, 0.06, 0.05, 0.035], seg=6, color=LEAF_B, cap=LEAF_VEIN)
    for k in range(5):                         # green sepals at the top
        a = k * math.tau / 5 + 0.3
        out = Vector((math.cos(a), math.sin(a), 0))
        _petal_solid(m, Vector((cx, cy, zt + 0.02)), out + Vector((0, 0, -0.3)), 0.28, 0.08, Vector((0, 0, 1)), LEAF_A,
                     LEAF_B, curl=0.0, segs=2)


def bark_roof(m, W, D, H, rise, over=0.2, seed=0, sides=(-1, 1)):
    """Gable (or lean-to with sides=(1,) / (-1,)) of long curled bark strips laid down the slope side by side,
    irregular widths, three bark tones, a dark groove down each strip; a twig ridge pole."""
    half = D / 2 + over
    ang = math.atan2(rise, half)
    ln = math.hypot(half, rise) + 0.04
    Wt = W + over
    for sy in sides:
        prof = [(0, H + rise), (sy * half, H - 0.02), (sy * half, H - 0.07), (0, H + rise - 0.07)]
        m.prism(prof if sy < 0 else list(reversed(prof)), Wt, color=BARK_DARK, group="body_nl")
        down = Vector((0, sy * math.cos(ang), -math.sin(ang)))
        nrm = Vector((0, sy * math.sin(ang), math.cos(ang)))
        n = max(4, int(Wt / 0.26))
        for k in range(n):
            x = -Wt / 2 + (k + 0.5) * Wt / n
            j = (k * 7 + seed * 3) % 5
            base = Vector((x, 0, H + rise)) + nrm * (0.03 + 0.02 * (k % 2)) - down * 0.04
            L = ln * (0.96 + 0.05 * (j % 3))
            pts = [base + down * L * (i / 3) + nrm * (0.03 * math.sin(math.pi * i / 3)) for i in range(4)]
            wd = Wt / n * (0.6 + 0.06 * (j % 3))
            col = (BARK, BARK_LIGHT, BARK_DARK, BARK, BARK_LIGHT)[j]
            leaf(m, pts, [wd * s for s in (0.85, 1.0, 0.9, 0.95)], nrm, thick=0.04, color=col, color_under=BARK_DARK,
                 group="body", ridge=0.4)
            tube(m, [p + nrm * 0.04 for p in pts[:3]], 0.012, seg=3, color=BARK_DARK, group="body_nh")
    m.cyl(0.06, 0.06, W + over * 1.3, pos=(-(W + over * 1.3) / 2, 0, H + rise + 0.03), rot=(0, math.pi / 2, 0),
          color=TWIG, seg=6, cap=TWIG_PALE, bottom_cap=TWIG_PALE)


def clover_roof(m, cx, cy, z, r, col=("7cc173", "6ab063"), lift_=0.18):
    """Three heart-shaped clover leaflets spread over a hut, with a pale chevron band on each."""
    for k in range(3):
        a = k * math.tau / 3 - math.pi / 2 + 0.3
        d = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-d.y, d.x, 0))
        for s in (-1, 1):                    # each leaflet = two lobes (heart)
            base = Vector((cx, cy, z + lift_))
            pts = [base + d * r * t + side * s * r * 0.22 * math.sin(math.pi * t) + Vector((0, 0, -lift_ * t * t))
                   for t in (0, 0.33, 0.66, 1.0)]
            leaf(m, pts, [0.05, r * 0.36, r * 0.38, r * 0.2], Vector((0, 0, 1)), thick=0.05, color=col[k % 2],
                 color_under=shade(col[k % 2], 0.8))
        m.box((0.05, r * 0.5, 0.02), pos=Vector((cx, cy, z + lift_ * 0.7)) + d * r * 0.55, rot=(0, 0, a + math.pi / 2),
              color="d6ecc0", group="body_nh")
    tube(m, [Vector((cx, cy, z + lift_ + 0.02)), Vector((cx, cy, z + lift_ + 0.25)), Vector((cx + 0.1, cy, z + lift_ + 0.35))],
         [0.04, 0.035, 0.03], seg=5, color=LEAF_B)


# ───────────── doors, windows ─────────────
def round_door(m, x, y, w=0.4, h=0.72, kind="leaf", col=LEAF_A, face=-1):
    """Round-topped doorway on the wall plane y (front = face -1): dark opening, an arched twig frame, and either
    a leaf curtain half drawn ('leaf'), a bark-scrap door ('bark') or a petal curtain ('petal' with col = hex)."""
    fy = face * 0.03
    m.box((w, 0.04, h - w / 2), pos=(x, y + fy * 0.5, 0.0), color=DOOR_DARK)
    m.cyl(w / 2, w / 2, 0.04, pos=(x, y + fy * 0.5 - face * 0.02, h - w / 2), rot=(math.pi / 2, 0, 0), color=DOOR_DARK, seg=10)
    # twig arch frame
    pts = [Vector((x - w / 2 - 0.03, y + fy, 0.0)), Vector((x - w / 2 - 0.03, y + fy, h - w / 2))]
    for k in range(1, 6):
        a = math.pi - k * math.pi / 6
        pts.append(Vector((x + math.cos(a) * (w / 2 + 0.03), y + fy, h - w / 2 + math.sin(a) * (w / 2 + 0.03))))
    pts += [Vector((x + w / 2 + 0.03, y + fy, h - w / 2)), Vector((x + w / 2 + 0.03, y + fy, 0.0))]
    tube(m, pts, 0.03, seg=5, color=TWIG, cap=TWIG_PALE)
    if kind == "bark":
        m.box((w * 0.92, 0.05, h - w / 2), pos=(x, y + fy * 1.4, 0.0), color=BARK,
              colfn=lambda f: BARK_LIGHT if f.normal.y * face > 0.5 else BARK)
        m.cyl(w * 0.46, w * 0.46, 0.05, pos=(x, y + fy * 1.4 - face * 0.025, h - w / 2), rot=(math.pi / 2, 0, 0),
              color=BARK_LIGHT, seg=10)
        for k in range(3):
            m.box((0.025, 0.02, h * 0.7), pos=(x - w * 0.25 + k * w * 0.25, y + fy * 2.2, 0.08), color=BARK_DARK)
        m.sphere(0.035, pos=(x + w * 0.3, y + fy * 2.5, h * 0.45), color=PEBBLE, seg=6, rings=3)
    else:
        c = col if kind == "leaf" else col
        top = Vector((x - w * 0.1, y + fy * 1.6, h - 0.04))
        pts = [top + Vector((-w * 0.05 * t, 0, -(h - 0.12) * t)) for t in (0, 0.33, 0.66, 1.0)]
        leaf(m, pts, [w * 0.12, w * 0.42, w * 0.4, w * 0.18], Vector((0, face, 0)), thick=0.03, color=c,
             color_under=shade(c, 0.8))
        m.box((0.02, 0.02, h * 0.62), pos=(x - w * 0.12, y + fy * 2.2, 0.16), color=shade(c, 0.75), group="body_nh")
        lash(m, (x - w * 0.36, y + fy * 1.8, h * 0.45), 0.04)          # tie-back


def round_window(m, x, y, z, r=0.15, face=-1, lit=True, cross=True):
    """Round window: twig ring, warm-lit pane, a twig cross."""
    fy = face * 0.03
    m.cyl(r + 0.035, r + 0.035, 0.04, pos=(x, y + fy * 0.3, z), rot=(math.pi / 2, 0, 0), color=TWIG, seg=10)
    m.cyl(r, r, 0.05, pos=(x, y + fy * 0.6, z), rot=(math.pi / 2, 0, 0), color=LIT if lit else DOOR_DARK, seg=10)
    if cross:
        m.box((0.025, 0.03, 2 * r), pos=(x, y + fy * 1.4, z - r), color=TWIG_DARK)
        m.box((2 * r, 0.03, 0.025), pos=(x, y + fy * 1.4, z - 0.012), color=TWIG_DARK)


def door_on_ring(m, cx, cy, R, a, w=0.4, h=0.72, kind="leaf", col=LEAF_A):
    p, rz = on_ring(cx, cy, R - 0.02, a)
    placed(m, lambda: round_door(m, 0, 0, w, h, kind, col), p, rz)


def window_on_ring(m, cx, cy, R, a, z, r=0.14):
    p, rz = on_ring(cx, cy, R - 0.01, a)
    placed(m, lambda: round_window(m, 0, 0, z, r), p, rz)


def clay_chimney(m, x, y, z0, top, r=0.11, smoke_=True):
    """Clay pipe chimney (pinched rim, soot top) with a puff of smoke."""
    m.cyl(r * 1.15, r, top - z0, pos=(x, y, z0), color=CLAY, seg=8, smooth=True, cap="4e423c")
    m.cyl(r * 1.3, r * 1.2, 0.07, pos=(x, y, top - 0.05), color=CLAY_DARK, seg=8, smooth=True, cap="4e423c")
    if smoke_:
        smoke(m, x, y, top + 0.05, 2)


def smoke(m, x, y, z, n=3):
    """Static soft smoke puffs rising from a chimney."""
    for k in range(n):
        m.sphere(0.11 + 0.05 * k, pos=(x + 0.08 * k, y + 0.04 * k, z + 0.12 + k * 0.24), scl=(1, 1, 0.8), color=SMOKE,
                 seg=7, rings=4, lumps=0.2, group="body_nl")


def seed_lantern(m, x, y, z, hang=0.18):
    """Glowing seed-husk lantern hanging on a grass cord."""
    cord(m, (x, y, z), (x, y, z - hang), r=0.01, n=1)
    m.sphere(0.07, pos=(x, y, z - hang - 0.06), scl=(1, 1, 1.25), color=LIT, seg=7, rings=4)
    m.cyl(0.05, 0.03, 0.05, pos=(x, y, z - hang - 0.0), color=SHELL, seg=6)


# ───────────── containers & small props ─────────────
def acorn_cup(m, x, y, z=0.0, r=0.16, fill=None, rz=0.0):
    """Acorn cap used as a tub / bucket / pot: scaly cup + a pale inner rim (+ fill)."""
    def cf(f):
        c = f.calc_center_median()
        if f.normal.z > 0.8 and c.z > z + r * 0.8:
            return ACORN_IN
        return ACORN_DARK if int((c.z - z) / r * 4.5) % 2 else ACORN
    m.cyl(r * 0.7, r, r * 1.05, pos=(x, y, z), color=ACORN, seg=10, smooth=True, colfn=cf)
    m.cyl(r * 1.06, r * 1.06, r * 0.18, pos=(x, y, z + r * 0.92), color=ACORN_DARK, seg=10, smooth=True, cap=ACORN_IN)
    if fill:
        m.sphere(r * 0.9, pos=(x, y, z + r * 1.08), scl=(1, 1, 0.3), color=fill, seg=8, rings=3)
    m.cyl(r * 0.12, r * 0.08, r * 0.3, pos=(x, y, z - r * 0.15), color=ACORN_DARK, seg=5)


def flower_pot(m, x, y, z=0.0, col="f2a2b8", s=1.0):
    """Acorn-cap pot with a little round flower (petals + centre) on a stalk."""
    acorn_cup(m, x, y, z, 0.12 * s, fill="8a6a4a")
    m.cyl(0.015 * s, 0.015 * s, 0.22 * s, pos=(x, y, z + 0.12 * s), color=LEAF_B, seg=4)
    for k in range(5):
        a = k * math.tau / 5
        m.sphere(0.05 * s, pos=(x + math.cos(a) * 0.05 * s, y + math.sin(a) * 0.05 * s, z + 0.36 * s),
                 scl=(1, 1, 0.45), color=col, seg=6, rings=3, group="body_nl")
    m.sphere(0.03 * s, pos=(x, y, z + 0.38 * s), color="f2c230", seg=5, rings=3, group="body_nl")
    m.blade((x, y, z + 0.14 * s), (x + 0.1 * s, y - 0.04 * s, z + 0.24 * s), 0.06 * s, color=LEAF_A)


def grass_pouch(m, x, y, z=0.0, s=1.0, rz=0.0, top=FLOUR):
    """Woven-grass pouch tied at the neck (the tiny folk's sack)."""
    m.sphere(0.2 * s, pos=(x, y, z + 0.17 * s), scl=(1.0, 0.85, 0.95), rot=(0, 0, rz), color=WEAVE, seg=9, rings=6,
             colfn=lambda f: WEAVE_DARK if int((f.calc_center_median().z - z) * 40 / s) % 2 else WEAVE)
    m.cyl(0.07 * s, 0.05 * s, 0.08 * s, pos=(x, y, z + 0.32 * s), color=CORD, seg=6)
    if top:
        m.sphere(0.07 * s, pos=(x, y, z + 0.41 * s), scl=(1.2, 1.2, 0.6), color=top, seg=7, rings=3)


def woven_basket(m, x, y, z=0.0, r=0.18, h=0.2, fill=None, cols=(WEAVE, WEAVE_DARK)):
    lathe(m, x, y, z, [(r * 0.75, 0), (r * 0.95, h * 0.35), (r, h * 0.75), (r * 1.02, h)], seg=10,
          colfn=weave_fn(*cols), top=None)
    m.cyl(r * 0.98, r * 0.98, 0.02, pos=(x, y, z + 0.01), color=cols[1], seg=10)
    m.cyl(r * 1.06, r * 1.06, 0.04, pos=(x, y, z + h - 0.02), color=CORD, seg=10, smooth=True, cap=cols[1])
    if fill:
        m.sphere(r * 0.9, pos=(x, y, z + h), scl=(1, 1, 0.35), color=fill, seg=8, rings=3)


def seed_shell(m, x, y, z=0.0, L=0.9, W=0.4, H=0.22, rz=0.0, fill=None, col=SHELL, inner=SHELL_IN):
    """Half seed husk lying open side up (trough, boat, cradle): striped outside, pale inside."""
    def _b():
        K, J = 7, 5
        outer, inn = [], []
        for k in range(K + 1):
            t = k / K
            xx = -L / 2 + L * t
            w = W / 2 * math.sin(math.pi * t) ** 0.7 + 0.01
            ro, ri = [], []
            for j in range(J + 1):
                a = math.pi * j / J
                ro.append(Vector((xx, -math.cos(a) * w, H - math.sin(a) * H * math.sin(math.pi * t) ** 0.5)))
                ri.append(Vector((xx * 0.97, -math.cos(a) * w * 0.82, H - math.sin(a) * H * 0.75 * math.sin(math.pi * t) ** 0.5 + 0.02)))
            outer.append(ro)
            inn.append(ri)
        fo = m.strip(outer, color=col, smooth=True)
        fi = m.strip(inn, color=inner, smooth=True)
        rim = m.strip([[r[0] for r in outer], [r[0] for r in inn]], color=shade(col, 1.15))
        rim += m.strip([[r[-1] for r in outer], [r[-1] for r in inn]], color=shade(col, 1.15))
        bm = m._bm("body")
        for f in fo:
            f.normal_update()
            if f.normal.z > 0.05 and f.calc_center_median().z < H * 0.95:
                f.normal_flip()
            c = f.calc_center_median()
            m._finish(bm, [f], shade(col, 0.88) if int((c.y / (W + 1e-6) + 1) * 5) % 2 else col, True)
        for f in fi:
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
        for f in rim:
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
        bm.normal_update()
        if fill:
            m.sphere(1.0, pos=(0, 0, H * 0.8), scl=(L * 0.38, W * 0.36, H * 0.25), color=fill, seg=8, rings=3)
    placed(m, _b, (x, y, z), rz)


def petal_flower(m, x, y, z, r=0.08, col="f2a2b8", center="f2c230", n=5, group="body_nl"):
    for k in range(n):
        a = k * math.tau / n
        m.sphere(r, pos=(x + math.cos(a) * r, y + math.sin(a) * r, z), scl=(1, 0.8, 0.35), rot=(0, 0, a),
                 color=col, seg=6, rings=3, group=group)
    m.sphere(r * 0.6, pos=(x, y, z + 0.02), scl=(1, 1, 0.6), color=center, seg=6, rings=3, group=group)


def sprout(m, x, y, h=0.25, s=1.0, col=LEAF_C):
    """Seedling: a green stalk with two round seed leaves."""
    m.cyl(0.018 * s, 0.014 * s, h, pos=(x, y, 0), color=LEAF_B, seg=4, group="body_nh")
    for sx in (-1, 1):
        base = Vector((x, y, h))
        d = Vector((sx, 0, 0.45)).normalized()
        leaf(m, [base, base + d * 0.08 * s, base + d * 0.16 * s], [0.02, 0.06 * s, 0.01], Vector((0, 0, 1)), thick=0.02,
             color=col, color_under=shade(col, 0.8), group="body_nh")


def tuft(m, x, y, h=0.3, n=4, col="TUFT", seed=0):
    for k in range(n):
        a = k * math.tau / n + seed
        m.blade((x, y, 0), (x + math.cos(a) * h * 0.35, y + math.sin(a) * h * 0.35, h * (0.8 + 0.2 * (k % 2))), 0.06,
                color=col)


def lily_pad(m, x, y, z, r=0.5, rz=0.0, col=LILY_PAD, group="body"):
    """Flat lily pad with its notch (a float / a mooring 'buoy' / a platform)."""
    def _b():
        seg = 14
        bm = m._bm(group)
        ring_t, ring_b = [], []
        for i in range(seg + 1):
            a = 0.25 + (math.tau - 0.5) * i / seg
            rr = r * (1.0 + 0.04 * math.sin(a * 5))
            ring_t.append(Vector((math.cos(a) * rr, math.sin(a) * rr, 0.035 + 0.02 * (rr / r))))
            ring_b.append(Vector((math.cos(a) * rr, math.sin(a) * rr, 0.0)))
        c_t = bm.verts.new((0, 0, 0.05))
        c_b = bm.verts.new((0, 0, 0.0))
        vt = [bm.verts.new(p) for p in ring_t]
        vb = [bm.verts.new(p) for p in ring_b]
        fs = []
        for i in range(seg):
            fs.append(bm.faces.new((c_t, vt[i], vt[i + 1])))
            fs.append(bm.faces.new((c_b, vb[i + 1], vb[i])))
            fs.append(bm.faces.new((vt[i], vb[i], vb[i + 1], vt[i + 1])))
        fs.append(bm.faces.new((c_t, c_b, vb[0], vt[0])))
        fs.append(bm.faces.new((c_t, vt[-1], vb[-1], c_b)))
        bmesh.ops.recalc_face_normals(bm, faces=fs)
        bm.normal_update()
        for f in fs:
            m._finish(bm, [f], col if f.normal.z > 0.5 else shade(col, 0.8), False)
        for k in range(5):
            a = 0.7 + k * 1.1
            m.box((r * 0.8, 0.025, 0.012), pos=(math.cos(a) * r * 0.42, math.sin(a) * r * 0.42, 0.05), rot=(0, 0, a),
                  color=LILY_VEIN, group="body_nh")
    placed(m, _b, (x, y, z), rz)


def leaf_boat(m, x, y, z, L=1.2, W=0.42, rz=0.0, col=LEAF_A, dark=LEAF_B, sail=None):
    """A big leaf dried and curled into a boat: both ends rolled up into points, midrib keel, a grass-stalk thwart.
    sail = petal colour hex -> a grass-stalk mast with a petal sail."""
    def _b():
        K, J = 8, 6
        outer, inn = [], []
        for k in range(K + 1):
            t = k / K
            xx = -L / 2 + L * t
            w = W / 2 * math.sin(math.pi * t) ** 0.8 + 0.01
            lift_ = 0.22 * (abs(t - 0.5) * 2) ** 3
            ro, ri = [], []
            for j in range(J + 1):
                a = math.pi * j / J
                ro.append(Vector((xx, -math.cos(a) * w, 0.2 + lift_ - math.sin(a) * 0.18 * math.sin(math.pi * t) ** 0.4)))
                ri.append(Vector((xx * 0.98, -math.cos(a) * w * 0.86, 0.2 + lift_ - math.sin(a) * 0.14 * math.sin(math.pi * t) ** 0.4 + 0.015)))
            outer.append(ro)
            inn.append(ri)
        fo = m.strip(outer, color=col, smooth=True)
        fi = m.strip(inn, color=shade(col, 1.08), smooth=True)
        rim = m.strip([[r[0] for r in outer], [r[0] for r in inn]], color=dark)
        rim += m.strip([[r[-1] for r in outer], [r[-1] for r in inn]], color=dark)
        bm = m._bm("body")
        for f in fo:
            f.normal_update()
            if f.normal.z > 0.05 and f.calc_center_median().z < 0.19:
                f.normal_flip()
            m._finish(bm, [f], dark if f.calc_center_median().z < 0.08 else col, True)
        for f in fi:
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
        for f in rim:
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
        bm.normal_update()
        tube(m, [r[J // 2] + Vector((0, 0, 0.02)) for r in inn][1:-1], 0.02, seg=4, color=LEAF_VEIN, group="body_nh")
        stem(m, (-0.05, -W * 0.4, 0.17), (-0.05, W * 0.4, 0.17), 0.025, REED, REED_NODE, 0, 5)
        if sail:
            stem(m, (0.08, 0, 0.06), (0.08, 0, 0.95), 0.022, REED_GREEN, REED_GREEN_NODE, 2, 5)
            pts = [Vector((0.1, 0, 0.92)), Vector((0.2, -0.04, 0.72)), Vector((0.22, -0.04, 0.5)), Vector((0.12, 0, 0.32))]
            leaf(m, pts, [0.03, 0.2, 0.22, 0.06], Vector((0, -1, 0)), thick=0.03, color=sail, color_under=shade(sail, 0.85),
                 group="body_nl")
    placed(m, _b, (x, y, z), rz)


def hanging_bundle(m, x, y, z, col="7fb565", s=1.0):
    """Herb / grass bundle hanging head-down from a cord."""
    m.box((0.012, 0.012, 0.1 * s), pos=(x, y, z - 0.1 * s), color=CORD, group="body_nh")
    m.cyl(0.03 * s, 0.07 * s, 0.22 * s, pos=(x, y, z - 0.32 * s), color=col, seg=6, smooth=True)
    m.cyl(0.035 * s, 0.035 * s, 0.03 * s, pos=(x, y, z - 0.12 * s), color=CORD, seg=6)


def bunting(m, a, b, z, sag=0.18, cols=("f2a2b8", "f4c84c", "8fb8ea", "a9c070", "f6f1e4"), n=7):
    """Petal flags on a grass cord."""
    a, b = Vector((a[0], a[1], z)), Vector((b[0], b[1], z))
    pts = cord(m, a, b, sag=sag, r=0.012, n=n + 1)
    d = (b - a).normalized()
    for i in range(1, n + 1):
        p = pts[i]
        m.poly([p - d * 0.07, p + d * 0.07, p + Vector((0, 0, -0.2))], color=cols[i % len(cols)], group="body_nh")
        m.poly([p + d * 0.07, p - d * 0.07, p + Vector((0, 0, -0.2))], color=shade(cols[i % len(cols)], 0.9), group="body_nh")


def pebble_steps(m, x, y, n=2, face=-1):
    for k in range(n):
        pebble(m, x + (0.06 if k % 2 else -0.05), y + face * (0.12 + k * 0.26), 0.0, 0.17, 0.12, 0.04,
               shade(PEBBLE, 1.0 + 0.05 * (k % 2)), 0.3 * k, k)


def mossy_tufts(m, pts):
    for k, (x, y, s) in enumerate(pts):
        m.sphere(0.13 * s, pos=(x, y, 0.02), scl=(1.4, 1.0, 0.45), color="MOSS", seg=7, rings=3, lumps=0.2,
                 group="body_nl", seed=k)


def reed_ladder(m, a, b, w=0.28, rungs=5):
    """Ladder: two reed rails with lashed twig rungs."""
    a, b = Vector(a), Vector(b)
    d = b - a
    side = d.cross(Vector((0, 0, 1)))
    side = side.normalized() * w / 2 if side.length > 1e-4 else Vector((w / 2, 0, 0))
    for s in (-1, 1):
        stem(m, a + side * s, b + side * s, 0.025, REED, REED_NODE, 2, 5)
    for k in range(rungs):
        p = a + d * ((k + 0.7) / (rungs + 0.4))
        twig(m, p - side * 1.15, p + side * 1.15, 0.018, TWIG)
