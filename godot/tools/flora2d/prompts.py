"""codex image-gen prompt for one flora / prop sheet (tools/flora2d/sheets.py). gen.sh feeds it to `codex exec`.
usage: prompts.py <sheet> <out_path> <has_ref 0|1>
Attached images (gen.sh): 1) design/concept/residents/res_A.png (approved villager style)
                          2) tools/bld2d/refs/ref_buildings.png (approved 2D buildings — the style every picture matches)
                          3) the reference sheet (compose.py): the game's own 3D models of these things in the same cells,
                             seen from our game camera (48 deg down, orthographic) — shape, proportions, colours to keep"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sheets import SHEETS  # noqa: E402

COMMON = """Use your built-in image generation tool to create ONE image, exactly {size}, then save it (copy the generated PNG) to {out} and print the path.

The FIRST attached image is the APPROVED CHARACTER STYLE: soft, rounded, cosy picture-book villagers. The SECOND attached image shows APPROVED BUILDINGS already drawn for this game: match them EXACTLY in drawing style, line weight, colour mood and level of detail. Thin dark-brown ink outline (#3A2A22) of even, fairly thin weight around every shape; flat cel colour with ONE soft shade step; warm muted colours; light from the UPPER-LEFT (left and top faces lit, right faces in the one shade step); soft rounded, slightly wobbly hand-made shapes; cute and cosy. NO gradients, NO texture noise, NO hatching, NO photo detail, NO glow halos.
The villagers are tiny people (about 5 cm tall) living in a small world inside a glass jar: plants and found things are drawn as the REAL things, just seen by tiny people — a flower is a real flower (huge for them), a pebble is a boulder.
{ref}
CAMERA: a high three-quarter TOP-DOWN view, the viewer looks DOWN at about 48 degrees from above. ORTHOGRAPHIC: no perspective, vertical stems stay vertical. The ground footprint reads as a flattened ellipse, round tops are open ellipses.

Background: one flat, uniform pure MAGENTA #FF00FF everywhere around the drawings (it will be keyed out). NO ground, NO grass patch, NO soil disc, NO cast shadow on the ground, NO text, NO letters, NO numbers, NO labels, NO frames or borders, NO divider lines. Nothing drawn uses magenta or bright pink (dusty muted pinks and deep rose are fine).

LAYOUT: {layout}
Each drawing stays well inside its own cell: at least 30 px of empty magenta between the drawing and every cell edge, so the drawings never touch or overlap each other.
{series}
THE DRAWINGS:
{what}
"""

REF_NOTE = """The THIRD attached image shows the game's 3D MODELS of exactly these things, in exactly the same cells, seen from our game camera. REDRAW each of them in the approved storybook style: keep its silhouette, proportions, pose, the direction it leans or faces, its colours and its parts, and draw it at the SAME SIZE and the SAME POSITION inside its cell as in that image — only the drawing style changes (clean ink outline, flat cel colour, one shade step, rounded hand-made shapes; never copy the faceted low-poly look or the triangle lines). Cells that are plain magenta in the third image have no model — draw those from the description alone, centred in the cell."""

NO_REF = """There is no model reference for these: draw them from the descriptions, each centred in its cell."""

SERIES_NOTE = """SERIES: all cells show the SAME thing as animation frames, drawn at EXACTLY the same scale and the same position inside its cell (the same base at the same place, same width). Only what is described changes between cells.
"""

ORD = ["TOP", "BOTTOM"]


def layout(cols: int, rows: int) -> tuple[str, list]:
    if cols == 1 and rows == 1:
        return "one drawing centred in the image.", ["the image"]
    names = []
    for r in range(rows):
        for c in range(cols):
            col = {1: [""], 2: ["LEFT", "RIGHT"], 3: ["LEFT", "MIDDLE", "RIGHT"]}[cols][c]
            row = "" if rows == 1 else (["TOP", "BOTTOM"] if rows == 2 else ["TOP", "MIDDLE", "BOTTOM"])[r]
            names.append(f"{row}-{col} cell".strip("- ").replace("- cell", " cell") if row and col else f"{row or col} cell")
    txt = (f"the image is split into {cols * rows} equal cells, {cols} column(s) x {rows} row(s), with invisible dividers. "
           "One drawing per cell, in this order: " + ", ".join(names) + ".")
    return txt, names


def prompt(sheet: str, out: str, has_ref: bool) -> str:
    d = SHEETS[sheet]
    cols, rows = d["grid"]
    lay, names = layout(cols, rows)
    what = "\n".join(f"- {names[i]}: {desc}" for i, (_p, _s, desc) in enumerate(d["cells"]))
    return COMMON.format(size=d["size"], out=out, ref=REF_NOTE if has_ref else NO_REF, layout=lay,
                         series=SERIES_NOTE if d.get("series") else "", what=what)


if __name__ == "__main__":
    print(prompt(sys.argv[1], sys.argv[2], sys.argv[3] == "1"))
