"""Cut a generated flora / prop sheet into its pictures (tools/bld2d/key.py rules — magenta key, despill, blobs owned by the
grid cell holding their centre, stray marks < 3% dropped; series sheets share one crop box so animation frames register).
usage: key.py <raw_sheet.png> <sheet name> <cut_dir>   -> <cut_dir>/<pic>.png (full resolution RGBA) + <pic>.json"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

T = Path(__file__).parent
sys.path.insert(0, str(T))
from sheets import SHEETS  # noqa: E402
import importlib.util  # noqa: E402
_spec = importlib.util.spec_from_file_location("bld2d_key", T.parent / "bld2d" / "key.py")
bkey = importlib.util.module_from_spec(_spec)  # tools/bld2d/key.py (shared rules)
sys.path.insert(0, str(T.parent / "bld2d"))
_spec.loader.exec_module(bkey)
sys.path.pop(0)

PAD = 6


def main() -> None:
    src, sheet, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
    out.mkdir(parents=True, exist_ok=True)
    d = SHEETS[sheet]
    cols, rows = d["grid"]
    series = bool(d.get("series"))
    cells = [(p, desc) for p, _s, desc in d["cells"]]
    im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    H, W = im.shape[:2]
    cw, ch = W / cols, H / rows
    a = bkey.key_alpha(im)
    a[:3, :] = a[-3:, :] = 0.0
    a[:, :3] = a[:, -3:] = 0.0
    rgb = bkey.edge_despill(bkey.despill(im, a), a)
    K = bkey.K
    small = a[: H // K * K, : W // K * K].reshape(H // K, K, W // K, K).max(axis=(1, 3)) > 0.5
    lab, sizes, cents = bkey.label(small)
    owner = [-1] * len(sizes)
    for i in range(1, len(sizes)):
        cy, cx = cents[i]
        owner[i] = min(cols - 1, int(cx * K / cw)) + cols * min(rows - 1, int(cy * K / ch))
    picks = []
    for c in range(len(cells)):
        ids = [i for i in range(1, len(sizes)) if owner[i] == c]
        if not ids:
            raise SystemExit(f"{sheet}: cell {c} ({cells[c][0]}) is empty")
        big = max(sizes[i] for i in ids)
        keep = np.zeros(len(sizes), bool)
        for i in ids:
            keep[i] = sizes[i] >= big * 0.03
        m = bkey.upscale(keep[lab], H, W)
        picks.append(np.where(m, a, 0.0))
    if series:
        rel = []
        for c, al in enumerate(picks):
            y0, y1, x0, x1 = bkey.bbox(al)
            ox, oy = (c % cols) * cw, (c // cols) * ch
            rel.append((y0 - oy, y1 - oy, x0 - ox, x1 - ox))
        top = min(r[0] for r in rel)
        bottom = max(r[1] for r in rel)
        half = max(max(abs(r[2] - cw / 2), abs(r[3] - cw / 2)) for r in rel)
    for c, (name, _d) in enumerate(cells):
        al = picks[c]
        if series:
            ox, oy = (c % cols) * cw, (c // cols) * ch
            y0, y1 = int(oy + top) - PAD, int(oy + bottom) + PAD
            x0, x1 = int(ox + cw / 2 - half) - PAD, int(ox + cw / 2 + half) + PAD
        else:
            y0, y1, x0, x1 = bkey.bbox(al)
            y0, y1, x0, x1 = y0 - PAD, y1 + PAD, x0 - PAD, x1 + PAD
        y0, x0 = max(0, y0), max(0, x0)
        y1, x1 = min(H, y1), min(W, x1)
        cc, aa = rgb[y0:y1, x0:x1], al[y0:y1, x0:x1]
        cc = np.where(aa[..., None] > 0.02, cc, bkey.INK)
        Image.fromarray(np.dstack([cc, aa * 255]).clip(0, 255).astype(np.uint8), "RGBA").save(out / f"{name}.png")
        meta = {"w": int(x1 - x0), "h": int(y1 - y0), "sheet": sheet}
        (out / f"{name}.json").write_text(json.dumps(meta))
        print(name, meta)


if __name__ == "__main__":
    main()
