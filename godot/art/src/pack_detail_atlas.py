"""Resident detail atlases (A20 v4): hand-painted hair / cloth swatches -> two small greyscale tiling atlases.

Sources: design/characters/textures/src/*.png (painted with `codex exec` image generation in the concept-sheet style,
neutral warm greys, prompts and model in design/characters/textures/log.csv). Each swatch is made seamless (half-offset cross-fade),
turned into a brightness MULTIPLIER (texel / 255 * GAIN; the swatch mean maps to 1.0, contrast per cell below) and packed
into a 4 x 4 grid of 128 px cells: a 120 px tile + 4 px wrapped gutter (so bilinear / small mips do not bleed).
render/resident.gdshader multiplies the tint (gene / outfit colour) by this detail. The cell index is in the vertex
colour alpha (build_residents.py: alpha = (cell + 0.5) / 32, cells 0-15 = hair atlas, 16-31 = cloth atlas), the tile
coordinates in UV2.

Run with system python3 (Pillow + numpy): python3 pack_detail_atlas.py <models_out_dir>
  -> resident_hair.png, resident_cloth.png (512 x 512, L8)
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "..", "..", "..", "design", "characters", "textures", "src"))
CELL = 128
TILE = 120
PAD = (CELL - TILE) // 2
GAIN = 1.4                       # shader: factor = texel * GAIN (mean 1.0 -> texel 182)

# cell -> (source name, contrast, flip_v, seamless, swatch crop fraction (zoom))
# must match build_residents.py (H_* / C_* cell numbers)
HAIR = {
    0: ("hair_straight", 1.0, False, True, 1.0),
    1: ("hair_wavy", 1.0, False, True, 1.0),
    2: ("hair_curls", 1.1, False, True, 1.0),
    3: ("hair_braid", 1.0, False, True, 1.0),
    4: ("hair_beard", 1.0, True, True, 1.0),       # tufts point down on the chin
    5: ("hair_bun", 0.9, False, False, 1.0),
    # 6: hair_tips (painted, not used yet - transparent background)
    7: ("hair_straight", 0.8, False, True, 0.5),   # fine strands (short hair, far)
}
CLOTH = {
    0: ("cloth_linen", 1.0, False, True, 0.5),
    1: ("cloth_folds", 1.0, False, True, 1.0),
    2: ("cloth_apron", 0.9, False, "x", 1.0),
    3: ("cloth_cuff", 1.0, False, "x", 1.0),
    4: ("cloth_leather", 1.0, False, "x", 1.0),
    5: ("cloth_pouch", 1.0, False, False, 1.0),
    6: ("cloth_hood", 1.0, False, True, 1.0),
    7: ("cloth_knit", 1.0, False, True, 0.6),
    8: ("cloth_straw", 1.0, False, True, 0.6),
    9: ("cloth_wool", 1.0, False, True, 0.6),
}


def seamless(a, axes="xy"):
    """Half-offset cross-fade: edges come from the swatch centre, so the tile wraps without a seam.
    axes "x" = only left-right (strips whose top / bottom edge is part of the drawing: belt, cuff, apron gathers)."""
    n = a.shape[0]
    o = np.roll(a, n // 2, 1)
    if "y" in axes:
        o = np.roll(o, n // 2, 0)
    t = np.abs(np.linspace(-1, 1, n))
    w1 = np.clip((1 - t) / 0.35, 0, 1)
    w = np.minimum.outer(w1 if "y" in axes else np.ones(n), w1)
    w = w * w * (3 - 2 * w)
    return a * w + o * (1 - w)


def fallback(name, n=512):
    """Quiet procedural stand-in if a painted swatch is missing (keeps the build working)."""
    rng = np.random.default_rng(abs(hash(name)) % 2 ** 31)
    a = rng.normal(0.0, 1.0, (n // 16, n // 16))
    img = Image.fromarray(((a - a.min()) / (np.ptp(a) + 1e-6) * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
    return np.asarray(img, np.float32) / 255.0 * 0.3 + 0.55


def cell_img(spec):
    name, contrast, flip, seam, zoom = spec
    p = os.path.join(SRC, name + ".png")
    if os.path.exists(p):
        im = Image.open(p).convert("L")
        s = min(im.size)
        c = int(s * zoom)
        im = im.crop(((im.width - c) // 2, (im.height - c) // 2, (im.width - c) // 2 + c, (im.height - c) // 2 + c))
        im = im.resize((512, 512), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
        a = np.asarray(im, np.float32) / 255.0
    else:
        print("  (missing swatch %s - procedural stand-in)" % name)
        a = fallback(name)
    if flip:
        a = a[::-1]
    if seam:
        a = seamless(a, seam if isinstance(seam, str) else "xy")
    # brightness multiplier around 1.0 (mean), contrast per cell, soft clamp
    m = float(a.mean())
    f = 1.0 + (a / max(m, 1e-3) - 1.0) * contrast
    f = np.clip(f, 0.45, GAIN)
    t = Image.fromarray(np.clip(f / GAIN * 255.0, 0, 255).astype(np.uint8)).resize((TILE, TILE), Image.LANCZOS)
    t = np.asarray(t)
    if seam == "x":
        t = np.pad(np.pad(t, ((0, 0), (PAD, PAD)), mode="wrap"), ((PAD, PAD), (0, 0)), mode="edge")
    elif seam:
        t = np.pad(t, PAD, mode="wrap")
    else:
        t = np.pad(t, PAD, mode="edge")
    return t


def pack(table, out):
    atlas = np.full((CELL * 4, CELL * 4), int(255 / GAIN), np.uint8)
    for k, spec in table.items():
        x, y = k % 4, k // 4
        atlas[y * CELL:(y + 1) * CELL, x * CELL:(x + 1) * CELL] = cell_img(spec)
    Image.fromarray(atlas, "L").save(out, optimize=True)
    print("detail atlas ->", out)


def main(out_dir):
    pack(HAIR, os.path.join(out_dir, "resident_hair.png"))
    pack(CLOTH, os.path.join(out_dir, "resident_cloth.png"))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.normpath(os.path.join(HERE, "..", "models")))
