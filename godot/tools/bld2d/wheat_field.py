"""The wheat field (GAME_DESIGN 104 · ROADMAP Q8): builds the field's pictures from the generated pieces.
usage: wheat_field.py <out_dir>          (then: pack.py <out_dir>)
       also writes <out_dir>/wheat_carry.png — what a villager carries from the field: ONE ear as big as a head, on its stalk
       (-> art/cutout/woman_a/parts/props/wheat.png, then tools/cutout_a/build_atlas.py; see CARRY_* below)

The same plants grow through three stages — sprouts (ankle to knee), green wheat (waist to head), and the ripe field: a small
dense golden FOREST of standing wheat, about one and a half villagers tall, every ear as big as a villager's head.
The field is drawn in layers:
  wheat_soil            the tilled oval, lying on the ground (mode "ground")
  wrow_<stage>_<i>      N_ROWS upright strips of plants, one per soil ridge, each its own card with its own `front`
                        (= that ridge's distance toward the camera).
                        sprout / green: villagers work INSIDE the field — the ordinary card depth rule covers their legs with the
                        rows in front of them (green rows also lean in depth, see LEAN_S).
                        ripe: nobody walks inside (the view stands the reapers at the front edge); the rows are pulled together
                        in depth at run time (Bld2D.wheat_pull) so the forest is one mass without inner outlines.
  wrow_stubble_<i>      the same ridge after reaping: short cut stalks (the harvest view swaps rows front to back).
  wheat_fence           the low twig fence along the front edge (upright)
  wheat_<stage>         the same layers flattened into one picture — thumbnails, the picture line-up, and the layout numbers
                        (bubble height, pile line, what the field hides) read this one.
Pieces (tools/bld2d/wheat_src/, keyed by key.py from the sheets wheat_rows (takes a and b), wheat_base, wheat_accent of
prompts.py): wrow_<stage>_<a|b>.png (one straight row), soil.png, fence.png, scarecrow.png, flowers.png.
The geometry below is the single source: table.py imports rows() / lean() / ... from here."""
import functools
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

T = Path(__file__).parent
SRC = T / "wheat_src"
INK = (58, 42, 34)
SIN = 0.743                 # sin(48 deg) — the camera pitch (BldEcon.APRON_SIN)

STAGES = ["sprout", "green", "ripe"]
SOIL_W = 3.6                # world units across (= 2 x the farm's size 1.8: the field fills its own footprint, no more)
# soil.png (672 x 328): the light ridges between the furrows, y px from the top. The plants stand on these.
SOIL_PX = (672, 328)
RIDGE_Y = [54, 94, 134, 176, 220, 262]          # the front ridge (302) stays bare: room before the fence
ROW_MARGIN = 0.14           # the row ends this far inside the oval's edge (world units)
# ... and the back and front rows end further inside still: seen from above the planting is a rounded patch, so the standing
# mass has round corners (not the corners of a box). Per row, back to front, world units per side.
ROW_INSET = [0.30, 0.10, 0.0, 0.0, 0.06, 0.20]
# source px per world unit of the plant strips. A villager stands ~0.83 with a big head (~0.36).
#   sprout  ~75 px  -> 0.23 units: ankle to knee
#   green  ~225 px  -> 0.56 units (clumps 0.49 .. 0.64): waist to head — his head stays above it when he works inside
#   ripe            -> the forest, FOREST_H; an ear of the strip (~110 px) -> 0.37 units = his head
PXU = {"sprout": 330.0, "green": 450.0, "ripe": 300.0, "stubble": 300.0}
PAD_X = {"sprout": 6, "green": 80, "ripe": 110, "stubble": 6}     # empty px left and right of the planting (the end clumps lean outward)
PAD_Y = 6                   # empty px under the foot line
JOIN = {"sprout": -14, "green": 34, "ripe": 34}       # overlap (px) where two strips are joined into the long ribbon
THICK = {"sprout": 1, "green": 0, "ripe": 0}          # outline growth (source px): the strips are shrunk, the ink must survive
# Six outlined rows stand one behind another: with the usual near-black ink the field turns into a dark scribble (and into dark
# speckles when zoomed out). So inside the plant strips the ink is tinted toward the stage's own line colour — the rows melt into
# one golden (green) mass and only the soil, the fence and the villagers keep the dark line. (line rgb, how much 0..1)
LINE = {"sprout": None, "green": ((60, 112, 44), 0.8), "ripe": ((176, 108, 24), 0.85)}
# ... and the screen's outline pass (render/outline_post.gdshader) draws a dark line wherever the depth jumps by more than its
# gap (0.22) — around every ear of every row, since the rows stand 0.3 apart. So the green rows LEAN IN DEPTH ONLY (the picture
# stays where it is on screen): the foot of a row is pulled toward the camera along the view ray, the top stays, so the rows
# together form one gently sloping roof = the top of the wheat. Neighbouring rows then differ by 0.45 * (1 - LEAN_S) in depth (no
# line), the order back-to-front is kept, and a villager anywhere inside is covered up to the wheat's top (not only by the row
# in front of him). The front row does not lean and no row leans past it — nobody in front of the field is ever covered.
# The ripe rows do not lean: the whole row is pulled toward the ripe row nearest the camera at run time (Bld2D.wheat_pull —
# that row changes while the field is reaped).
LEAN_S = {"sprout": 0.0, "green": 0.8, "ripe": 0.0, "stubble": 0.0}     # sprouts are small tufts: they keep the plain upright cards
LEAN_M = 0.9                # a row's foot comes at most this share of the way to the front row's plane
# The body of a row: between the plants one would look through to the stalks and the dark soil of the rows behind — dark specks
# all over the field. So every green / ripe row gets a solid mass behind its plants (top colour -> foot colour), its top edge
# following the plants' tops a little lower (the ear tips stand clear of it).
MASS = {"green": ((118, 170, 56), (80, 130, 44)), "ripe": ((246, 198, 60), (200, 134, 30))}
MASS_DROP = {"green": 0.11, "ripe": 0.1}        # units: the mass's top runs this far below the plants' tops
MASS_FOOT = {"green": 0.04, "ripe": 0.15}       # units: ... and it ends this far above the foot line, in a wavy edge — under it the
#                                                 stalk feet and leaves stand on the soil (the front row reads as standing plants)
MASS_END = (0.1, 0.32)       # units: the mass ends this far inside the row's outermost plants · rounds down over this length
MASS_REACH = 30             # px: gaps between plants narrower than twice this are bridged
MASS_COVER = 0.285          # units: the mass stands at least this tall, so it hides the foot of the row behind (row gap x sin + a little)
SWAY = {"sprout": 0.012, "green": 0.03, "ripe": 0.06, "stubble": 0.0}   # wind: how far the tips lean (world units)
FENCE_PXU = 470.0           # fence.png px per unit: posts ~0.28 tall (below a villager's knee-to-hip)
FENCE_GAP = 0.55            # the way in, between the two halves
FENCE_Y = 321               # soil.png y of the fence's foot line (just inside the front edge)
COMP_PXU = 200              # the flattened picture's px per unit
ACCENTS = {                 # name -> (piece, px per unit, soil x px of its centre, soil y px of its foot)
    # the scarecrow stands at the front left corner of the planting, before the front row and inside the fence — in full view
    # (inside the ripe forest only its hat would show)
    "wheat_scarecrow": ("scarecrow.png", 500.0, 92, 297),
    # poppies and cornflowers along the left half of the fence, just outside it (the sheaf pile stands at the right end)
    "wheat_flowers": ("flowers.png", 480.0, 187, 327),
}

# ── the dense golden wheat forest (GAME_DESIGN 104, 2026-11-11 "촘촘한 황금 밀 숲" · height B = 1.5 villagers) ──
# Not a hedge and not a bale: a thicket of standing plants. A row is built clump by clump (CLUMP_W wide):
#   · every clump has its own height (CLUMP_VAR around the row's height, a little taller toward the middle — CLUMP_DOME),
#     so the top line is uneven; a few single ears poke above it (FOREST_POKE);
#   · the two clumps at each end are shorter (CLUMP_END) and lean outward (CLUMP_TILT): the mass tapers into the soil;
#   · a clump = tiers of ears from the clump's top down, laid like shingles (the lower tier over the upper one), and in front of
#     them whole plants standing on the ground: stalks and leaves show at the foot.
#   · the back and front rows are a little shorter (ROW_K) and shorter in length (ROW_INSET): the field steps up from the front
#     row and rounds off at the back.
FOREST_H = 1.25             # world units on screen: the height of a middle row's clumps on average (a villager = 0.83)
ROW_K = {"green": [0.96, 1.0, 1.0, 0.98, 0.94, 0.88], "ripe": [0.95, 1.0, 1.0, 0.97, 0.92, 0.84]}     # row height, back to front
CLUMP_W = (0.38, 0.62)      # units
CLUMP_VAR = (0.05, 0.13)    # a clump stands this share above or below the row's height (mostly alternating)
CLUMP_DOME = 0.07           # ... and this share lower at the row's ends than in the middle
CLUMP_END = ((0.26, 0.62, (11.0, 15.0)), (0.34, 0.86, (5.0, 8.0)))    # outermost, next: (width units, height share, lean deg)
CLUMP_OV = 16               # px: a clump's pieces reach this far into its neighbours
FOREST_BAND = 0.62          # the ear band = this share of the strip's height, from the top
FOREST_STEP = 62            # px between tiers (about half an ear: every ear shows its upper half)
FOREST_PLAIN = 1.12         # a clump no taller than this x the strip is just the plants themselves (scaled), no extra tiers
FOREST_CLEAR = 0.4          # units: no tier of ears is cut off lower than this above the ground (the cut hides behind the plants' own ears)
FOREST_POKE = (0.06, 0.16)  # units: single ears stand this far above their clump
FOREST_FACE = (0.2, 0.5)    # under the bright crown the tiers are tinted toward FOREST_DEEP: just under the top .. at the foot
FOREST_DEEP = (240, 146, 24)                        # warm, not dark
FOREST_CROWN = ((255, 238, 132), 0.3)               # the crown (what shows of the rows behind = the top of the wheat) leans to this
STUBBLE_H = 0.13            # units: cut stalks left on a reaped ridge
STUBBLE_COLS = [(236, 204, 124), (222, 184, 104), (206, 164, 88)]      # dry straw


def _chord(a: np.ndarray, y: int):
    xs = np.where(a[y] > 128)[0]
    return int(xs.min()), int(xs.max()) + 1


def front_of(y_px: float) -> float:
    """soil.png row -> distance toward the camera from the field centre (ground units)."""
    return (y_px - SOIL_PX[1] / 2.0) / SOIL_PX[0] * SOIL_W / SIN


@functools.lru_cache(maxsize=None)
def rows(kind: str = ""):
    """[{w, front, dx, plant}] per ridge, back to front (needs soil.png). plant = the planting's length; w = the card's width
    (= plant + the empty margin of that kind's picture, PAD_X; kind "" = no margin)."""
    a = np.asarray(Image.open(SRC / "soil.png").convert("RGBA"))[..., 3]
    out = []
    for i, y in enumerate(RIDGE_Y):
        x0, x1 = _chord(a, y)
        plant = (x1 - x0) / SOIL_PX[0] * SOIL_W - 2 * (ROW_MARGIN + ROW_INSET[i])
        dx = ((x0 + x1) / 2.0 - SOIL_PX[0] / 2.0) / SOIL_PX[0] * SOIL_W
        w = row_px(kind, plant) / PXU[kind] if kind else plant
        out.append(dict(w=round(w, 3), front=round(front_of(y), 3), dx=round(dx, 3), plant=round(plant, 3)))
    return out


def row_px(kind: str, plant: float) -> int:
    """a row picture's width in px."""
    return round(plant * PXU[kind]) + 2 * PAD_X[kind]


@functools.lru_cache(maxsize=None)
def row_h(stage: str) -> float:
    """a row's nominal height in world units on screen (the leaning rows: how far the foot may come forward)."""
    return (ribbon(stage).height + 2 * PAD_Y) / PXU[stage]


def lean(stage: str, i: int) -> float:
    """how far row i's foot is pulled toward the camera along the view ray (world units, depth only) — see LEAN_S."""
    if LEAN_S[stage] <= 0.0:
        return 0.0
    cos = (1.0 - SIN * SIN) ** 0.5
    g = rows()
    full = LEAN_S[stage] * (row_h(stage) / cos) / SIN            # the card stands row_h / cos tall in the world
    lim = LEAN_M * (g[-1]["front"] - g[i]["front"]) / cos
    return round(max(0.0, min(full, lim)), 3)


def fence_front() -> float:
    return round(front_of(FENCE_Y), 3)


def fence_w() -> float:
    return round(build_fence().width / FENCE_PXU, 3)


def field_front() -> float:
    """the flattened picture's bottom edge = the soil's front edge."""
    return round(front_of(SOIL_PX[1]), 3)


def accent_place(name: str):
    piece, pxu, cx, fy = ACCENTS[name]
    im = Image.open(SRC / piece)
    return dict(w=round(im.width / pxu, 3), front=round(front_of(fy), 3), dx=round((cx - SOIL_PX[0] / 2.0) / SOIL_PX[0] * SOIL_W, 3))


# ───────────────────────── picture building ─────────────────────────
def trim(im: Image.Image) -> Image.Image:
    a = np.asarray(im)[..., 3]
    ys, xs = np.where(a > 128)
    return im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def thicken(im: Image.Image, r: int) -> Image.Image:
    """Grow the dark outline by r px on each side (and the silhouette by r) so it survives the shrink to game size."""
    if r <= 0:
        return im
    a = np.asarray(im).astype(np.uint8)
    rgb = a[..., :3].copy()
    rgb[a[..., 3] < 128] = 255
    k = 2 * r + 1
    dark = np.asarray(Image.fromarray(rgb, "RGB").filter(ImageFilter.MinFilter(k)))
    al = np.asarray(Image.fromarray(a[..., 3]).filter(ImageFilter.MaxFilter(k)))
    # only the INK grows: a pixel takes the darkened colour when that colour is outline-dark, else keeps its own
    lum = dark.astype(np.float32).mean(axis=2)
    own = a[..., :3].astype(np.float32)
    use = (lum < 110)[..., None] | (a[..., 3:4] < 128)
    out = np.where(use, dark, own)
    return Image.fromarray(np.dstack([out, al]).astype(np.uint8), "RGBA")


def soften(im: Image.Image, line) -> Image.Image:
    """Tint the dark outline toward a line colour (see LINE): the darker the pixel, the more it takes."""
    if line is None:
        return im
    rgb, amt = line
    a = np.asarray(im).astype(np.float32)
    lum = a[..., :3].mean(axis=2)
    t = (np.clip((112.0 - lum) / 52.0, 0.0, 1.0) * amt)[..., None]
    a[..., :3] = a[..., :3] * (1.0 - t) + np.array(rgb, np.float32) * t
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def line_ink(stage: str):
    """the colour the strip's cut ends are closed with (= fully dark ink after soften)."""
    line = LINE.get(stage)
    if line is None:
        return INK
    return tuple(round(INK[c] * (1.0 - line[1]) + line[0][c] * line[1]) for c in range(3))


def ribbon(stage: str) -> Image.Image:
    """a, mirrored b, b, mirrored a joined end to end on one foot line -> a long strip to cut the rows from."""
    parts = []
    for tag, flip in (("a", False), ("b", True), ("b", False), ("a", True)):
        im = trim(Image.open(SRC / f"wrow_{stage}_{tag}.png").convert("RGBA"))
        parts.append(im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im)
    h = max(p.height for p in parts)
    step = [p.width - JOIN[stage] for p in parts]
    out = Image.new("RGBA", (sum(step) + JOIN[stage], h), INK + (0,))
    x = 0
    for p, s in zip(parts, step):
        out.alpha_composite(p, (x, h - p.height))
        x += s
    return out


def _gap_near(col: np.ndarray, x: int, reach: int) -> int:
    """the emptiest column near x (between two plants) — rows are cut there, not through an ear."""
    lo, hi = max(0, x - reach), min(len(col) - 1, x + reach)
    return lo + int(np.argmin(col[lo:hi + 1]))


def _clean(a: np.ndarray, ink) -> np.ndarray:
    """hard alpha + no key-colour leftovers (thin magenta strokes between the ears show once the strip is drawn this big);
    the empty pixels take the line colour too (no dark rim when the piece is turned). The cut ends stay open: a clump's pieces
    lie over their neighbours, and a closed end would draw a ruler line down through the leaves."""
    a = a.copy()
    r, g, b = (a[..., c].astype(np.int32) for c in range(3))
    spill = (r > g + 25) & (b * 4 > g * 3)                # the keyed rim is left reddish
    a[..., :3][spill] = ink
    a[..., 3] = np.where(a[..., 3] > 128, 255, 0)
    a[..., :3][a[..., 3] == 0] = ink
    return a


EAR_ROWS = 100              # px from the strip's top: the ears (the gaps between them are looked for here)


def _seam(al: np.ndarray, x: int, reach: int) -> np.ndarray:
    """the top-to-bottom path near column x that crosses the fewest opaque pixels (at most 1 px sideways per row) -> x per row.
    A piece cut along two such paths ends between two ears and around the leaves, not on a ruler line."""
    lo, hi = max(0, x - reach), min(al.shape[1], x + reach + 1)
    cost = al[:, lo:hi].astype(np.float32) + 0.03 * np.abs(np.arange(hi - lo) - (x - lo)) / max(1, reach)
    h, n = cost.shape
    dp = cost.copy()
    back = np.zeros((h, n), np.int8)
    inf = np.float32(1e9)
    for y in range(1, h):
        prev = dp[y - 1]
        st = np.stack([np.concatenate(([inf], prev[:-1])), prev, np.concatenate((prev[1:], [inf]))])
        k = st.argmin(axis=0)
        dp[y] += st.min(axis=0)
        back[y] = k - 1
    out = np.zeros(h, np.int32)
    j = int(dp[-1].argmin())
    for y in range(h - 1, -1, -1):
        out[y] = lo + j
        j += int(back[y, j])
    return out


@functools.lru_cache(maxsize=None)
def _ear_gaps(key: int, rows_px: int):
    al = _ALPHA[key]
    return np.convolve(al[:rows_px].sum(axis=0).astype(np.float32), np.ones(9) / 9.0, mode="same")


_ALPHA = {}


def _piece(rib: Image.Image, want: int, rng: random.Random, rows_px: int) -> np.ndarray:
    """a stretch of the strip about want px long and rows_px tall (from the top), cut between two ears along seams -> rgba."""
    key = id(rib)
    if key not in _ALPHA:
        _ALPHA[key] = np.asarray(rib)[..., 3] > 128
    al = _ALPHA[key]
    col = _ear_gaps(key, min(EAR_ROWS, rib.height))
    reach = min(45, max(12, want // 3))
    x0 = _gap_near(col, rng.randint(60, max(61, rib.width - want - 60)), reach)
    x1 = max(x0 + 30, _gap_near(col, x0 + want, reach))
    sl = _seam(al[:rows_px], x0, 26)
    sr = _seam(al[:rows_px], x1, 26)
    lo, hi = int(sl.min()), int(sr.max()) + 1
    a = np.asarray(rib.crop((lo, 0, hi, rows_px))).copy()
    xx = np.arange(lo, hi)[None, :]
    a[..., 3] = np.where((xx >= sl[:, None]) & (xx < sr[:, None]), a[..., 3], 0)
    return a[:, ::-1].copy() if rng.random() < 0.5 else a


def _over(dst: Image.Image, im: Image.Image, x: int, y: int) -> None:
    """alpha_composite that may hang over the edges."""
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(dst.width, x + im.width), min(dst.height, y + im.height)
    if x1 > x0 and y1 > y0:
        dst.alpha_composite(im.crop((x0 - x, y0 - y, x1 - x, y1 - y)), (x0, y0))


def _stand(im: Image.Image, deg: float, k: float, ink):
    """scale by k and lean by deg (to the right) about the middle of the bottom edge -> (picture, x, y of that foot point in it)."""
    if abs(k - 1.0) > 0.01:
        im = im.resize((max(2, round(im.width * k)), max(2, round(im.height * k))), Image.LANCZOS)
    if abs(deg) < 0.4:
        return im, im.width / 2.0, float(im.height)
    w, h = im.size
    side = 2 * int(math.hypot(w / 2.0, h)) + 6
    big = Image.new("RGBA", (side, side), tuple(ink) + (0,))
    big.paste(im, ((side - w) // 2, side // 2 - h))
    return big.rotate(-deg, resample=Image.BICUBIC), side / 2.0, side / 2.0


def _shade(a: np.ndarray, f0: float, f1: float, crown: bool) -> Image.Image:
    """the forest's light: the crown (the top of a clump) is sunlit, lighter than the strip's gold; the face under it turns deeper
    and warmer toward the foot (f0 at the piece's top .. f1 at its bottom) — the eye reads 'top of the wheat' and 'wall of ears'
    apart, i.e. how tall the wheat stands."""
    b = a.astype(np.float32)
    t = np.linspace(0.0, 1.0, b.shape[0], dtype=np.float32)[:, None, None]
    lum = b[..., :3].mean(axis=2, keepdims=True)
    rgb = b[..., :3]
    if crown:
        g = FOREST_CROWN[1] * ((lum - 110.0) / 60.0).clip(0.0, 1.0) * (1.0 - 1.6 * t).clip(0.0, 1.0)      # the line colour stays
        rgb = rgb * (1.0 - g) + np.array(FOREST_CROWN[0], np.float32) * g
    f = f0 + (f1 - f0) * t
    rgb = rgb * (1.0 - f) + np.array(FOREST_DEEP, np.float32) * (lum / 190.0).clip(0.0, 1.15) * f
    b[..., :3] = rgb
    return Image.fromarray(b.clip(0, 255).astype(np.uint8), "RGBA")


def _clumps(w_px: int, T: float, P: float, rng: random.Random):
    """the clumps of one row, left to right: [{x0, x1, top (px above the foot, along the clump), deg (lean to the right), d
    (0 = outermost)}]. T = the row's height in px."""
    ends = [e[0] * P for e in CLUMP_END]
    inner = w_px - 2.0 * sum(ends)
    n = max(1, round(inner / (0.5 * (CLUMP_W[0] + CLUMP_W[1]) * P)))
    ws = [rng.uniform(*CLUMP_W) for _ in range(n)]
    ws = [w * inner / sum(ws) for w in ws]
    widths = ends + ws + ends[::-1]
    out = []
    x = 0.0
    s = rng.choice((-1.0, 1.0))
    m = len(widths)
    for j, cw in enumerate(widths):
        u = (x + cw / 2.0 - w_px / 2.0) / (w_px / 2.0)
        side = -1.0 if u < 0.0 else 1.0
        d = min(j, m - 1 - j)
        if d < len(CLUMP_END):
            f = CLUMP_END[d][1] + rng.uniform(-0.03, 0.03)
            deg = side * rng.uniform(*CLUMP_END[d][2])
        else:
            f = (1.0 - CLUMP_DOME * u * u) * (1.0 + s * rng.uniform(*CLUMP_VAR))
            if rng.random() < 0.8:
                s = -s
            deg = rng.uniform(-3.0, 3.0) + 2.0 * u
        out.append(dict(x0=x, x1=x + cw, top=T * f, deg=deg, d=d))
        x += cw
    return out


def _mass(al: np.ndarray, stage: str, foot_y: int) -> Image.Image:
    """the solid body behind one row's plants (see MASS): under the plants' top line (gaps bridged), never above it."""
    P = PXU[stage]
    h, w = al.shape
    top = np.where(al.any(axis=0), al.argmax(axis=0), h).astype(np.float32)
    r = MASS_REACH
    k = 2 * r + 1
    lo = np.lib.stride_tricks.sliding_window_view(np.pad(top, r, mode="constant", constant_values=h), k).min(axis=1)
    closed = np.lib.stride_tricks.sliding_window_view(np.pad(lo, r, mode="constant", constant_values=h), k).max(axis=1)
    has = closed < h - 1
    xs = np.where(has)[0]
    x = np.arange(w, dtype=np.float32)
    if len(xs):                                   # the body ends inside the row's ends, under a round shoulder — the outermost
        d = np.minimum(x - xs.min(), xs.max() - x) - MASS_END[0] * P      # plants hang over it (the side reads as plants, not a slab)
        has &= d >= 0.0
        end = np.clip(1.0 - d / (MASS_END[1] * P), 0.0, 1.0)
        closed = closed + (h - closed) * 0.6 * (1.0 - np.sqrt(1.0 - end * end))
    smooth = np.convolve(np.pad(closed, 12, mode="edge"), np.ones(25) / 25.0, mode="valid")
    line = np.maximum(smooth, closed) + MASS_DROP[stage] * P
    foot = foot_y - MASS_FOOT[stage] * P - 0.03 * P * np.abs(np.sin(x * (np.pi / 41.0)))
    line = np.minimum(line, np.maximum(closed + 4.0, foot - MASS_COVER * P))      # ... but tall enough to hide the row behind
    yy = np.arange(h, dtype=np.float32)[:, None]
    fill = (yy >= line[None, :]) & (yy < foot[None, :]) & has[None, :]
    t = ((yy - line[None, :]) / np.maximum(foot[None, :] - line[None, :], 1.0)).clip(0.0, 1.0)[..., None]
    if stage == "green":
        t = t * t                                              # the upper half stays the bright top colour
    cols = MASS[stage]
    rgb = np.array(cols[0], np.float32) * (1.0 - t) + np.array(cols[1], np.float32) * t
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255).astype(np.uint8)
    out[..., 3] = np.where(fill, 255, 0)
    return Image.fromarray(out, "RGBA")


def clump_row(stage: str, rib: Image.Image, plant_px: int, T: float, rng: random.Random) -> Image.Image:
    """one green or ripe row, built clump by clump (see the forest notes above). T = the row's height in px."""
    P = PXU[stage]
    ink = line_ink(stage)
    forest = stage == "ripe"
    ph = rib.height
    band = int(ph * FOREST_BAND)
    pad = PAD_X[stage]
    cl = _clumps(plant_px, T, P, rng)
    poke = FOREST_POKE[1] * P if forest else 0.0
    H = int(math.ceil(max(c["top"] for c in cl) + poke)) + 2 * PAD_Y + 4
    W = plant_px + 2 * pad
    foot_y = H - PAD_Y
    jobs = []                                     # (order: tops, then the plants; picture, lean deg, scale, x of the clump's foot, px above the foot)
    for c in cl:
        cw = c["x1"] - c["x0"]
        cx = pad + (c["x0"] + c["x1"]) / 2.0
        top = c["top"]
        if not forest or top < ph * FOREST_PLAIN:
            k = top / ph
            a = _clean(_piece(rib, round((cw + 2 * CLUMP_OV) / k), rng, ph), ink)
            im = _shade(a, 0.0, FOREST_FACE[1], True) if forest else Image.fromarray(a, "RGBA")
            jobs.append((top - 10000.0, im, c["deg"], k, cx + rng.uniform(-6, 6), 0.0))
            continue
        tops = [top]
        while tops[-1] - FOREST_STEP - band >= FOREST_CLEAR * P + FOREST_STEP:
            tops.append(tops[-1] - FOREST_STEP)
        for j, tp in enumerate(tops):
            a = _clean(_piece(rib, round(cw + 2 * CLUMP_OV), rng, band), ink)
            if j == 0:
                im = _shade(a, 0.0, FOREST_FACE[0] * 0.6, True)
            else:
                f = FOREST_FACE[0] + (FOREST_FACE[1] - FOREST_FACE[0]) * (1.0 - tp / top)
                im = _shade(a, f, f, False)
            jobs.append((tp, im, c["deg"], 1.0, cx + rng.uniform(-9, 9), tp - band))
        a = _clean(_piece(rib, round(cw + 2 * CLUMP_OV), rng, ph), ink)
        jobs.append((ph - 10000.0, _shade(a, FOREST_FACE[1] * 0.7, FOREST_FACE[1] + 0.1, False), c["deg"], 1.0, cx + rng.uniform(-6, 6), 0.0))
    front = Image.new("RGBA", (W, H), tuple(ink) + (0,))
    rng.shuffle(jobs)
    for top, im, deg, k, cx, yb in sorted(jobs, key=lambda j: -j[0]):          # the lower tier over the upper one · the plants last
        st, fx, fy = _stand(im, deg, k, ink)
        rad = math.radians(deg)
        _over(front, st, round(cx + yb * math.sin(rad) - fx), round(foot_y - yb * math.cos(rad) - fy))
    out = Image.new("RGBA", (W, H), tuple(ink) + (0,))
    if forest:                                    # single ears above the top line, behind everything
        inner = [c for c in cl if c["d"] >= 1]
        for _ in range(max(2, round(plant_px / (0.7 * P)))):
            c = rng.choice(inner)
            a = _clean(_piece(rib, 84, rng, band), ink)
            deg = c["deg"] + rng.uniform(-9.0, 9.0)
            st, fx, fy = _stand(_shade(a, 0.0, 0.0, True), deg, 1.0, ink)
            yb = c["top"] + rng.uniform(*FOREST_POKE) * P - band
            cx = pad + rng.uniform(c["x0"] + 0.2 * (c["x1"] - c["x0"]), c["x1"] - 0.2 * (c["x1"] - c["x0"]))
            rad = math.radians(deg)
            _over(out, st, round(cx + yb * math.sin(rad) - fx), round(foot_y - yb * math.cos(rad) - fy))
    out.alpha_composite(_mass(np.asarray(front)[..., 3] > 128, stage, foot_y))
    out.alpha_composite(front)
    a = np.asarray(out).copy()
    a[..., 3] = np.where(a[..., 3] > 128, 255, 0)
    a[foot_y + 2:, :, 3] = 0
    return Image.fromarray(a, "RGBA")


def sprout_row(rib: Image.Image, plant_px: int, rng: random.Random) -> Image.Image:
    """one row of sprouts: a straight stretch of the strip (small tufts on the ridge)."""
    a = np.asarray(rib)[..., 3]
    col = (a > 128).sum(axis=0).astype(np.float32)
    col = np.convolve(col, np.ones(9) / 9.0, mode="same")
    x0 = _gap_near(col, rng.randint(40, max(41, rib.width - plant_px - 40)), 30)
    x1 = min(_gap_near(col, x0 + plant_px, 30), x0 + plant_px)
    piece = np.asarray(rib.crop((x0, 0, x1, rib.height))).copy()
    for xs in (slice(0, 3), slice(-3, None)):        # close the cut ends with the strip's line colour
        m = piece[:, xs, 3] > 128
        piece[:, xs, :3][m] = INK
    pad = PAD_X["sprout"]
    out = Image.new("RGBA", (plant_px + 2 * pad, rib.height + 2 * PAD_Y), INK + (0,))
    out.alpha_composite(Image.fromarray(piece, "RGBA"), (pad + (plant_px - (x1 - x0)) // 2, PAD_Y))
    return out


# ───────────────────────── the carried ear ─────────────────────────
CARRY_EAR = 350.0           # px = the doll's rig units (build_atlas.py takes wheat.png 1 : 1): the ear's length. A doll is 920 tall
                            # and its head about 390 (rig units), so the ear is a little smaller than the head it is carried beside
CARRY_CUT = [(15, 0), (128, 0), (128, 62), (103, 80), (100, 100), (99, 134), (15, 134)]    # wrow_ripe_a.png px: its first ear alone
CARRY_FOOT = (67, 130)      # ... where that ear sits on its stalk
CARRY_STALK = (94, 12, 9)   # source px: the stalk's length under the ear, its width at the ear, at the cut end
CARRY_HOLD = 74             # source px under the ear: where the hands hold it (the grip point; hand to shoulder = about 150 rig units)
CARRY_TILT = 54.0           # deg: the stalk lies on the shoulder, the ear stands out behind / beside the head (not hidden by it)
CARRY_STRAW = ((252, 222, 122), (236, 190, 92))     # the stalk: lit side, shaded side
CARRY_INK = (118, 44, 18)   # the source ears' own outline (dark red-brown)


def carry_ear():
    """-> (picture, the grip point as a share of the picture: x from the left, y from the top, the ear's length px)."""
    src = Image.open(SRC / "wrow_ripe_a.png").convert("RGBA")
    m = Image.new("L", src.size, 0)
    ImageDraw.Draw(m).polygon(CARRY_CUT, fill=255)
    a = np.asarray(src).copy()
    a[..., 3] = np.minimum(a[..., 3], np.asarray(m))
    solid = Image.fromarray(np.where(a[..., 3] > 40, 255, 0).astype(np.uint8)).copy()      # only the ear itself: no cut-off bits of its neighbour
    ImageDraw.floodfill(solid, (CARRY_FOOT[0], CARRY_FOOT[1] - 40), 128)
    a[..., 3] = np.where(np.asarray(solid) == 128, a[..., 3], 0)
    x0, y0 = min(p[0] for p in CARRY_CUT), min(p[1] for p in CARRY_CUT)
    x1, y1 = max(p[0] for p in CARRY_CUT), max(p[1] for p in CARRY_CUT)
    ear = Image.fromarray(a, "RGBA").crop((x0, y0, x1, y1))
    S = 3                                           # work scale
    L, w0, w1 = CARRY_STALK
    fx, fy = (CARRY_FOOT[0] - x0) * S, (CARRY_FOOT[1] - y0) * S
    plant = Image.new("RGBA", ((x1 - x0) * S, (y1 - y0 + L) * S + 12), CARRY_INK + (0,))
    d = ImageDraw.Draw(plant)

    def stalk(grow: float, col) -> None:
        pts_l, pts_r = [], []
        for k in range(13):
            t = k / 12.0
            cx = fx + 5.0 * S * math.sin(t * math.pi) * 0.5      # a slight bow
            hw = (w0 + (w1 - w0) * t) * S / 2.0 + grow
            y = fy + t * L * S + (grow if k == 12 else 0.0)
            pts_l.append((cx - hw, y))
            pts_r.append((cx + hw, y))
        d.polygon(pts_l + pts_r[::-1], fill=col + (255,))

    stalk(1.5 * S, CARRY_INK)
    stalk(0.0, CARRY_STRAW[1])
    for k in range(12):                             # the lit left half
        t0, t1 = k / 12.0, (k + 1) / 12.0
        c0 = fx + 5.0 * S * math.sin(t0 * math.pi) * 0.5
        c1 = fx + 5.0 * S * math.sin(t1 * math.pi) * 0.5
        h0, h1 = (w0 + (w1 - w0) * t0) * S / 2.0, (w0 + (w1 - w0) * t1) * S / 2.0
        d.polygon([(c0 - h0, fy + t0 * L * S), (c0 + 0.15 * h0, fy + t0 * L * S), (c1 + 0.15 * h1, fy + t1 * L * S), (c1 - h1, fy + t1 * L * S)],
                  fill=CARRY_STRAW[0] + (255,))
    plant.alpha_composite(thicken(ear, 1).resize((ear.width * S, ear.height * S), Image.LANCZOS))
    # the grip point, then lean the whole thing about it
    gx, gy = fx + 5.0 * S * math.sin(CARRY_HOLD / L * math.pi) * 0.5, fy + CARRY_HOLD * S
    side = 2 * int(math.hypot(plant.width, plant.height)) + 8
    big = Image.new("RGBA", (side, side), CARRY_INK + (0,))
    big.alpha_composite(plant, (round(side / 2.0 - gx), round(side / 2.0 - gy)))
    big = big.rotate(CARRY_TILT, resample=Image.BICUBIC)             # counter-clockwise: the ear leans to the picture's left
    bx0, by0, bx1, by1 = big.getbbox()
    k = CARRY_EAR / ((y1 - y0) * S)
    cut = big.crop((bx0, by0, bx1, by1))
    cut = scaled_to(cut, max(2, round(cut.width * k)), max(2, round(cut.height * k)))
    ox = oy = 6
    out = Image.new("RGBA", (cut.width + 2 * ox, cut.height + 2 * oy), CARRY_INK + (0,))
    out.alpha_composite(cut, (ox, oy))
    grip = ((ox + (side / 2.0 - bx0) * k) / out.width, (oy + (side / 2.0 - by0) * k) / out.height)
    return out, grip, (y1 - y0) * S * k


def stubble_row(plant_px: int, rng: random.Random) -> Image.Image:
    """a reaped ridge: tufts of short cut stalks, dry straw colour, lower toward the row's ends."""
    P = PXU["stubble"]
    ink = line_ink("ripe")
    hs = round(STUBBLE_H * P)
    pad = PAD_X["stubble"]
    out = Image.new("RGBA", (plant_px + 2 * pad, hs + 2 * PAD_Y), tuple(ink) + (0,))
    d = ImageDraw.Draw(out)
    fy = out.height - PAD_Y
    x = 8.0
    while x < plant_px - 8:
        e = min(1.0, min(x, plant_px - x) / (0.25 * P))
        for _ in range(rng.randint(2, 4)):
            bx = pad + x + rng.uniform(-10, 10)
            w = rng.uniform(5.0, 8.0)
            hgt = hs * rng.uniform(0.4, 1.0) * (0.5 + 0.5 * e)
            tx = bx + rng.uniform(-0.3, 0.3) * hgt
            col = STUBBLE_COLS[rng.randrange(len(STUBBLE_COLS))]
            d.polygon([(bx - w / 2, fy), (bx + w / 2, fy), (tx + w / 2, fy - hgt), (tx - w / 2, fy - hgt)], fill=col + (255,), outline=tuple(ink) + (255,))
            d.line([(tx - w / 2, fy - hgt), (tx + w / 2, fy - hgt)], fill=tuple(ink) + (255,), width=2)
        x += rng.uniform(20, 36)
    return out


def build_row(kind: str, i: int, rib: Image.Image, rng: random.Random) -> Image.Image:
    plant_px = round(rows()[i]["plant"] * PXU[kind])
    if kind == "sprout":
        row = sprout_row(rib, plant_px, rng)
    elif kind == "stubble":
        row = stubble_row(plant_px, rng)
    else:
        row = clump_row(kind, rib, plant_px, (FOREST_H * PXU[kind] if kind == "ripe" else rib.height) * ROW_K[kind][i], rng)
    assert row.width == row_px(kind, rows()[i]["plant"]), (kind, i, row.size)
    return row.transpose(Image.FLIP_LEFT_RIGHT) if i % 2 == 1 else row


def build_fence() -> Image.Image:
    """fence.png = two short halves (3 posts each). Each half is doubled (5 posts: the copy's first post sits on the last
    one), with the way in between them."""
    im = trim(Image.open(SRC / "fence.png").convert("RGBA"))
    a = np.asarray(im)[..., 3]
    col = (a > 128).any(axis=0)
    empty = np.where(~col)[0]
    g0, g1 = int(empty.min()), int(empty.max()) + 1
    halves = [trim(im.crop((0, 0, g0, im.height))), trim(im.crop((g1, 0, im.width, im.height)))]
    out_halves = []
    for hf in halves:
        band = (np.asarray(hf)[hf.height // 10: hf.height // 4, :, 3] > 128).any(axis=0)      # posts only (above the rail)
        xs = np.where(band)[0]
        first = int(xs.min())
        last = int(np.where(~band[: int(xs.max())])[0].max()) + 1                              # where the last post begins
        step = last - first                                                                     # the copy's first post lands on the last one
        long = Image.new("RGBA", (hf.width + step, hf.height), INK + (0,))
        long.alpha_composite(hf, (0, 0))
        long.alpha_composite(hf, (step, 0))
        out_halves.append(long)
    gap = round(FENCE_GAP * FENCE_PXU)
    h = max(x.height for x in out_halves)
    out = Image.new("RGBA", (out_halves[0].width + gap + out_halves[1].width + 12, h + 12), INK + (0,))
    out.alpha_composite(out_halves[0], (6, 6 + h - out_halves[0].height))
    out.alpha_composite(out_halves[1], (6 + out_halves[0].width + gap, 6 + h - out_halves[1].height))
    return thicken(out, 1)


def scaled(im: Image.Image, pxu: float) -> Image.Image:
    """-> COMP_PXU px per unit (premultiplied, so no dark fringes)."""
    return scaled_to(im, max(2, round(im.width * COMP_PXU / pxu)), max(2, round(im.height * COMP_PXU / pxu)))


def scaled_to(im: Image.Image, w: int, h: int) -> Image.Image:
    a = np.asarray(im).astype(np.float32)
    al = a[..., 3:4] / 255.0
    P = np.asarray(Image.fromarray((a[..., :3] * al).clip(0, 255).astype(np.uint8)).resize((w, h), Image.LANCZOS)).astype(np.float32)
    A = np.asarray(Image.fromarray(a[..., 3].astype(np.uint8)).resize((w, h), Image.LANCZOS)).astype(np.float32) / 255.0
    C = P / np.maximum(A[..., None], 1e-3)
    return Image.fromarray(np.dstack([C.clip(0, 255), (A * 255).clip(0, 255)]).astype(np.uint8), "RGBA")


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    soil = Image.open(SRC / "soil.png").convert("RGBA")
    assert soil.size == SOIL_PX, soil.size
    soil.save(out / "wheat_soil.png")
    fence = build_fence()
    fence.save(out / "wheat_fence.png")
    for name, (piece, _pxu, _cx, _fy) in ACCENTS.items():
        Image.open(SRC / piece).convert("RGBA").save(out / f"{name}.png")
    geo = rows()
    s = COMP_PXU * SOIL_W / SOIL_PX[0]               # soil px -> composite px
    soil_c = scaled(soil, SOIL_PX[0] / SOIL_W)
    ribs = {stage: soften(thicken(ribbon(stage), THICK[stage]), LINE[stage]) for stage in STAGES}
    for stage in STAGES:
        rng = random.Random(f"wheat-{stage}")
        pics = []
        for i in range(len(geo)):
            row = build_row(stage, i, ribs[stage], rng)
            row.save(out / f"wrow_{stage}_{i}.png")
            pics.append(row)
        # flattened: soil, rows back to front, fence — same places as the cards
        foot = PAD_Y * COMP_PXU / PXU[stage]
        top = max(0, round(max(p.height * COMP_PXU / PXU[stage] - y * s for p, y in zip(pics, RIDGE_Y))) + 8)
        comp = Image.new("RGBA", (soil_c.width, soil_c.height + top), INK + (0,))
        comp.alpha_composite(soil_c, (0, top))
        for g, y, row in zip(geo, RIDGE_Y, pics):
            r = scaled(row, PXU[stage])
            cx = soil_c.width / 2.0 + g["dx"] * COMP_PXU
            _over(comp, r, round(cx - r.width / 2.0), round(top + y * s - r.height + foot))
        f = scaled(fence, FENCE_PXU)
        comp.alpha_composite(f, (round(soil_c.width / 2.0 - f.width / 2.0), round(top + FENCE_Y * s - f.height)))
        comp.save(out / f"wheat_{stage}.png")
        print(stage, "rows", [p.size for p in pics], "flattened", comp.size)
    rng = random.Random("wheat-stubble")
    for i in range(len(geo)):
        build_row("stubble", i, ribs["ripe"], rng).save(out / f"wrow_stubble_{i}.png")
    ear, grip, ear_px = carry_ear()
    ear.save(out / "wheat_carry.png")
    print("rows", geo, "fence front", fence_front(), "field front", field_front())
    print("carried ear", ear.size, "grip (share of the picture)", [round(g, 3) for g in grip], "ear length px", round(ear_px))


if __name__ == "__main__":
    main()
