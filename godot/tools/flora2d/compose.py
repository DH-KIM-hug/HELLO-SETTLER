"""Reference sheets + model measurements from ref_render.gd cells.
usage: compose.py <ref_dir>
-> <ref_dir>/sheet_<sheet>.png   the 3D models in their cells on pure magenta (4th image attached to the codex prompt)
-> tools/flora2d/measure.json    pic -> {w, h, dx, front} in world units at model scale 1, as the game camera sees the model:
     w, h  opaque silhouette size on screen · dx  silhouette centre minus model origin (camera right)
     front how far toward the camera (on the ground) the silhouette's lowest point lies from the origin = sinking the card's
           bottom edge there keeps the picture standing where the model stood (pack.py; flora2d card placement)"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

T = Path(__file__).parent
sys.path.insert(0, str(T))
from sheets import SHEETS  # noqa: E402

SIN_P = math.sin(math.radians(48.0))


def main() -> None:
    ref = Path(sys.argv[1])
    cells = ref / "cells"
    meas = {}
    mp = T / "measure.json"
    if mp.exists():
        meas = json.loads(mp.read_text())
    for s, d in SHEETS.items():
        W, H = (int(x) for x in d["size"].split("x"))
        cols, rows = d["grid"]
        cw, ch = W // cols, H // rows
        sheet = Image.new("RGB", (W, H), (255, 0, 255))
        for i, (pic, spec, _desc) in enumerate(d["cells"]):
            if spec is None:
                continue
            p = cells / f"{pic}.png"
            if not p.exists():
                print("missing render", pic)
                continue
            im = Image.open(p).convert("RGBA")
            a = np.asarray(im)[..., 3]
            m = json.loads((cells / f"{pic}.json").read_text())
            ys, xs = np.where(a > 128)
            if len(xs) == 0:
                print("empty render", pic)
                continue
            ppx = float(m["ppx"])
            x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            meas[pic] = {"w": round((x1 - x0) / ppx, 4), "h": round((y1 - y0) / ppx, 4),
                         "dx": round(((x0 + x1) * 0.5 - float(m["ox"])) / ppx, 4),
                         "cy": round((float(m["oy"]) - (y0 + y1) * 0.5) / ppx, 4),     # silhouette centre above the origin (screen)
                         "front": round(max(0.0, (y1 - float(m["oy"])) / ppx / SIN_P), 4)}
            sheet.paste(im, ((i % cols) * cw, (i // cols) * ch), im)
        sheet.save(ref / f"sheet_{s}.png")
    mp.write_text(json.dumps(meas, indent=1, ensure_ascii=False, sort_keys=True) + "\n")
    print(len(meas), "measured")


if __name__ == "__main__":
    main()
