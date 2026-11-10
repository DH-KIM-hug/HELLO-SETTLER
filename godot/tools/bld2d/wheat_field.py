"""The low golden wheat field (GAME_DESIGN 104 · ROADMAP Q8): builds the field's pictures from the generated pieces.
usage: wheat_field.py <out_dir>          (then: pack.py <out_dir>)

Why layers: the field is LOW (ripe ears reach a villager's chest), and the farmer works INSIDE it. One upright picture would hide
him; one flat picture would let him stand on top of the ears. So the field is drawn as
  wheat_soil            the tilled oval, lying on the ground (mode "ground")
  wrow_<stage>_<i>      N_ROWS upright strips of plants, one per soil ridge, each its own card with its own `front`
                        (= that ridge's distance toward the camera). The ordinary card depth rule then does the rest: rows in
                        front of a villager cover his legs, rows behind him are covered by him -> waist-deep, any camera turn.
                        (green / ripe rows also lean in depth — see LEAN_S — so he is covered up to the top of the wheat.)
  wheat_fence           the low twig fence along the front edge (upright)
  wheat_<stage>         the same layers flattened into one picture — thumbnails, the picture line-up, and the layout numbers
                        (bubble height, pile line, what the field hides) read this one.
Pieces (tools/bld2d/wheat_src/, keyed by key.py from the sheets wheat_rows (takes a and b), wheat_base, wheat_accent of
prompts.py): wrow_<stage>_<a|b>.png (one straight row), soil.png, fence.png, scarecrow.png, flowers.png.
The geometry below is the single source: table.py imports rows() / FIELD from here."""
import functools
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

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
# source px per world unit of the plant strips: ripe plants (~260 px) -> 0.47 units. A villager stands ~0.85 with a big head
# (his shoulders are at ~0.45), so the ripe ears reach his shoulders and the head and shoulders stay above them.
PXU = {"sprout": 330.0, "green": 570.0, "ripe": 570.0}
JOIN = {"sprout": -14, "green": 34, "ripe": 34}       # overlap (px) where two strips are joined into the long ribbon
THICK = {"sprout": 1, "green": 0, "ripe": 0}          # outline growth (source px): the strips are shrunk ~3x, the ink must survive
# Six outlined rows stand one behind another: with the usual near-black ink the field turns into a dark scribble (and into dark
# speckles when zoomed out). So inside the plant strips the ink is tinted toward the stage's own line colour — the rows melt into
# one golden (green) mass and only the soil, the fence and the villagers keep the dark line. (line rgb, how much 0..1)
LINE = {"sprout": None, "green": ((60, 112, 44), 0.8), "ripe": ((176, 108, 24), 0.85)}
# ... and the screen's outline pass (render/outline_post.gdshader) draws a dark line wherever the depth jumps by more than its
# gap (0.22) — around every ear of every row, since the rows stand 0.3 apart. So the green / ripe rows LEAN IN DEPTH ONLY (the
# picture stays where it is on screen): the foot of a row is pulled toward the camera along the view ray, the top stays, so the
# rows together form one gently sloping roof = the top of the wheat. Neighbouring rows then differ by 0.45 * (1 - LEAN_S) in
# depth (no line), the order back-to-front is kept, and a villager anywhere inside is covered up to the wheat's top (not only by
# the row in front of him). The front row does not lean and no row leans past it — nobody in front of the field is ever covered.
LEAN_S = {"sprout": 0.0, "green": 0.8, "ripe": 0.8}     # sprouts are small tufts: they keep the plain upright cards
LEAN_M = 0.9                # a row's foot comes at most this share of the way to the front row's plane
# The body of a row: between the plants one would look through to the stalks and the dark soil of the rows behind — dark specks
# all over the field. So every green / ripe row gets a solid mass behind its plants (top colour -> foot colour), its top edge
# following the plants' tops a little lower (the ear tips stand clear of it), rounded off at the row's two ends.
MASS = {"sprout": None, "green": ((118, 170, 56), (80, 130, 44)), "ripe": ((243, 194, 56), (204, 140, 30))}
MASS_DROP = 0.2             # the mass's top runs this share of the row height below the plants' tops
MASS_FOOT = 0.07            # ... and it ends about this share above the foot line, in a wavy edge (the stalk feet stand on the soil)
MASS_REACH = 30             # px: gaps between plants narrower than twice this are bridged
MASS_COVER = 0.285          # units: the mass stands at least this tall, so it hides the foot of the row behind (row gap x sin + a little)
MASS_END = 84               # px: the mass rounds down to the foot over this length at each end of the row
SWAY = {"sprout": 0.012, "green": 0.03, "ripe": 0.035}   # wind: how far the tips lean (world units)
FENCE_PXU = 470.0           # fence.png px per unit: posts ~0.28 tall (below a villager's knee-to-hip)
FENCE_GAP = 0.55            # the way in, between the two halves
FENCE_Y = 321               # soil.png y of the fence's foot line (just inside the front edge)
COMP_PXU = 200              # the flattened picture's px per unit
ACCENTS = {                 # name -> (piece, px per unit, soil x px of its centre, soil y px of its foot)
    # the scarecrow stands in the wheat on a tall pole: hat, head and arms stay above the ripe ears
    "wheat_scarecrow": ("scarecrow.png", 500.0, 520, 96),
    # poppies and cornflowers along the left half of the fence, just outside it (the sheaf pile stands at the right end)
    "wheat_flowers": ("flowers.png", 480.0, 187, 327),
}


def _chord(a: np.ndarray, y: int):
    xs = np.where(a[y] > 128)[0]
    return int(xs.min()), int(xs.max()) + 1


def front_of(y_px: float) -> float:
    """soil.png row -> distance toward the camera from the field centre (ground units)."""
    return (y_px - SOIL_PX[1] / 2.0) / SOIL_PX[0] * SOIL_W / SIN


def rows():
    """[{w, front, dx}] per ridge, back to front (needs soil.png)."""
    a = np.asarray(Image.open(SRC / "soil.png").convert("RGBA"))[..., 3]
    out = []
    for y in RIDGE_Y:
        x0, x1 = _chord(a, y)
        w = (x1 - x0) / SOIL_PX[0] * SOIL_W - 2 * ROW_MARGIN
        dx = ((x0 + x1) / 2.0 - SOIL_PX[0] / 2.0) / SOIL_PX[0] * SOIL_W
        out.append(dict(w=round(w, 3), front=round(front_of(y), 3), dx=round(dx, 3)))
    return out


@functools.lru_cache(maxsize=None)
def row_h(stage: str) -> float:
    """a row picture's height in world units on screen (cut_row pads 6 px above and below)."""
    return (ribbon(stage).height + 12) / PXU[stage]


def lean(stage: str, i: int) -> float:
    """how far row i's foot is pulled toward the camera along the view ray (world units, depth only) — see LEAN_S."""
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
    line = LINE[stage]
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


def cut_row(rib: Image.Image, want_px: int, rng: random.Random, ink=INK, mass=None, pxu: float = 480.0, pad: int = 6) -> Image.Image:
    a = np.asarray(rib)[..., 3]
    col = (a > 128).sum(axis=0).astype(np.float32)
    col = np.convolve(col, np.ones(9) / 9.0, mode="same")
    x0 = _gap_near(col, rng.randint(40, max(41, rib.width - want_px - 40)), 45)
    x1 = _gap_near(col, x0 + want_px, 45)
    piece = np.asarray(rib.crop((x0, 0, x1, rib.height))).copy()
    for xs in (slice(0, 3), slice(-3, None)):        # close the cut ends with the strip's line colour
        m = piece[:, xs, 3] > 128
        piece[:, xs, :3][m] = ink
    out = Image.new("RGBA", (x1 - x0 + 2 * pad, rib.height + 2 * pad), INK + (0,))
    if mass is not None:
        out.alpha_composite(row_mass(piece, mass, pxu), (pad, pad))
    out.alpha_composite(Image.fromarray(piece, "RGBA"), (pad, pad))
    return out


def row_mass(piece: np.ndarray, cols, pxu: float) -> Image.Image:
    """the solid body behind one cut row (see MASS)."""
    al = piece[..., 3] > 128
    h, w = al.shape
    top = np.where(al.any(axis=0), al.argmax(axis=0), h).astype(np.float32)
    r = MASS_REACH
    win = np.lib.stride_tricks.sliding_window_view(np.pad(top, r, mode="constant", constant_values=h), 2 * r + 1)
    line = np.convolve(np.pad(win.min(axis=1), r, mode="edge"), np.ones(2 * r + 1) / (2 * r + 1), mode="valid")
    line = np.minimum(line + MASS_DROP * h, h - MASS_COVER * pxu)
    x = np.arange(w, dtype=np.float32)
    end = np.clip(1.0 - np.minimum(x, w - 1 - x) / MASS_END, 0.0, 1.0)
    foot = h * (1.0 - MASS_FOOT) - h * 0.045 * np.abs(np.sin(x * (np.pi / 41.0)))
    line = line + (foot - line).clip(0.0, None) * (1.0 - np.sqrt(1.0 - end * end))        # a round shoulder
    yy = np.arange(h, dtype=np.float32)[:, None]
    fill = (yy >= line[None, :]) & (yy < foot[None, :])
    t = ((yy - line[None, :]) / np.maximum(foot[None, :] - line[None, :], 1.0)).clip(0.0, 1.0)[..., None]
    t = t * t                                                  # the upper half stays the bright top colour
    rgb = np.array(cols[0], np.float32) * (1.0 - t) + np.array(cols[1], np.float32) * t
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255).astype(np.uint8)
    out[..., 3] = np.where(fill, 255, 0)
    return Image.fromarray(out, "RGBA")


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
    w = max(2, round(im.width * COMP_PXU / pxu))
    h = max(2, round(im.height * COMP_PXU / pxu))
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
    for stage in STAGES:
        rib = soften(thicken(ribbon(stage), THICK[stage]), LINE[stage])
        rng = random.Random(f"wheat-{stage}")
        pics = []
        for i, g in enumerate(geo):
            row = cut_row(rib, round(g["w"] * PXU[stage]), rng, line_ink(stage), MASS[stage], PXU[stage])
            if i % 2 == 1:
                row = row.transpose(Image.FLIP_LEFT_RIGHT)
            row.save(out / f"wrow_{stage}_{i}.png")
            pics.append(row)
        # flattened: soil, rows back to front, fence — same places as the cards
        top = max(0, round(max(p.height * COMP_PXU / PXU[stage] for p in pics) - RIDGE_Y[0] * s) + 8)
        comp = Image.new("RGBA", (soil_c.width, soil_c.height + top), INK + (0,))
        comp.alpha_composite(soil_c, (0, top))
        for g, y, row in zip(geo, RIDGE_Y, pics):
            r = scaled(row, PXU[stage])
            cx = soil_c.width / 2.0 + g["dx"] * COMP_PXU
            comp.alpha_composite(r, (round(cx - r.width / 2.0), round(top + y * s - r.height)))
        f = scaled(fence, FENCE_PXU)
        comp.alpha_composite(f, (round(soil_c.width / 2.0 - f.width / 2.0), round(top + FENCE_Y * s - f.height)))
        comp.save(out / f"wheat_{stage}.png")
        print(stage, "rows", [p.size for p in pics], "flattened", comp.size)
    print("rows", geo, "fence front", fence_front(), "field front", field_front())


if __name__ == "__main__":
    main()
