"""Animal detail atlas (animals v2): hand-painted fur / feather / scale swatches -> one small greyscale tiling atlas.

Sources: design/animals/textures/src/*.png (painted with `codex exec` image generation, neutral greys, the resident
swatches as style reference; prompts in design/animals/textures/log.csv). Same treatment as the resident atlases
(pack_detail_atlas.py: seamless cross-fade, brightness MULTIPLIER around 1.0, 120 px tile + 4 px wrapped gutter) but
packed 4 x 2 cells of 128 px -> 512 x 256 L8.
render/toon.gdshader (Art.body_mat) multiplies the species tint by this detail: the cell index is in the vertex colour
alpha ((cell + 0.5) / 32), the tile coords in UV (offset by +100 in u = "this vertex has detail").
Cells must match build_animals.py (FUR, SHAGGY, WOOL, FEATHER, SCALE, HIDE, HORN).

Run with system python3 (Pillow + numpy): python3 pack_animal_atlas.py [models_out_dir]  -> animal_fur.png
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pack_detail_atlas as pda  # noqa: E402

pda.SRC = os.path.normpath(os.path.join(HERE, "..", "..", "..", "design", "animals", "textures", "src"))

# cell -> (source name, contrast, flip_v, seamless, zoom)
CELLS = {
    0: ("fur_short", 1.7, False, True, 0.6),
    1: ("fur_long", 1.0, False, True, 0.8),
    2: ("wool_curls", 1.1, False, True, 0.6),
    3: ("feathers", 0.9, False, True, 0.8),
    4: ("scales", 0.8, False, True, 0.4),
    5: ("hide_patches", 0.8, False, True, 0.8),
    6: ("horn_ridges", 0.9, False, True, 0.8),
    7: ("fur_short", 1.0, False, True, 0.35),      # very fine fur (faces, small animals)
}


def main(out_dir):
    C = pda.CELL
    atlas = np.full((C * 2, C * 4), int(255 / pda.GAIN), np.uint8)
    for k, spec in CELLS.items():
        x, y = k % 4, k // 4
        atlas[y * C:(y + 1) * C, x * C:(x + 1) * C] = pda.cell_img(spec)
    out = os.path.join(out_dir, "animal_fur.png")
    Image.fromarray(atlas, "L").save(out, optimize=True)
    print("animal detail atlas ->", out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.normpath(os.path.join(HERE, "..", "models")))
