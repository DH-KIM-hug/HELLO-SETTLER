"""Cut a generated sheet into its pictures, key the magenta background, crop -> <cut_dir>/<name>.png (full resolution RGBA).
usage: key.py <raw_sheet.png> <sheet name> <cut_dir>
- the whole sheet is keyed, then split into connected blobs; each blob belongs to the grid cell (prompts.SHEETS[sheet] —
  cols x rows, order left-to-right, top-to-bottom) that holds its centre, so a drawing that pokes over the invisible cell
  divider is still cut whole. Stray marks are dropped: blobs < 3% of the biggest blob of their cell.
- series sheets (build stages): every picture is cropped with the SAME box relative to its cell, bottom-centre aligned on
  the union of the stage drawings, so stage pictures register (same scale, same base) when swapped in the game.
Writes <cut_dir>/<name>.json too: {"w","h"} of the crop and "base" = lowest opaque row from the top (0..1)."""
import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from prompts import SHEETS  # noqa: E402

INK = np.array([58, 42, 34], np.float32)
K = 4            # blob labelling on a K x downsampled mask
PAD = 6


def key_alpha(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mag = np.minimum(r, b) - g                     # pure #FF00FF = 255; dusty rose ~ < 40
    return np.clip((150.0 - mag) / 60.0, 0.0, 1.0)


def despill(rgb: np.ndarray, a: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mag = np.minimum(r, b) - g
    spill = np.clip(mag, 0, None) * (1.0 - a)
    return np.dstack([r - spill * 0.8, g, b - spill * 0.8]).clip(0, 255)


def edge_despill(rgb: np.ndarray, a: np.ndarray, reach: int = 4) -> np.ndarray:
    """Opaque pixels within `reach` px of the background that still lean magenta (r and b both above g — thin awns, net
    strings, rims) are pulled to neutral. Interior dusty pinks / lilacs (petal roofs) are left alone."""
    bg = a < 0.5
    near = bg.copy()
    for _ in range(reach):
        g = near.copy()
        g[1:, :] |= near[:-1, :]
        g[:-1, :] |= near[1:, :]
        g[:, 1:] |= near[:, :-1]
        g[:, :-1] |= near[:, 1:]
        near = g
    r, gg, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mag = np.minimum(r, b) - gg
    hit = near & ~bg & (mag > 18)
    out = rgb.copy()
    k = 0.15
    out[..., 0] = np.where(hit, gg + (r - gg) * k + np.maximum(0, (r - b)) * (1 - k), r)
    out[..., 2] = np.where(hit, gg + (b - gg) * k, b)
    return out.clip(0, 255)


def label(small: np.ndarray):
    """8-connected labels of a bool mask -> (labels, [size], [(cy, cx)]) — index 0 = background."""
    lab = np.zeros(small.shape, np.int32)
    sizes, cents = [0], [(0.0, 0.0)]
    H, W = small.shape
    cur = 0
    for y in range(H):
        for x in range(W):
            if small[y, x] and lab[y, x] == 0:
                cur += 1
                n, sy, sx = 0, 0, 0
                q = deque([(y, x)])
                lab[y, x] = cur
                while q:
                    cy, cx = q.popleft()
                    n += 1
                    sy += cy
                    sx += cx
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < H and 0 <= nx < W and small[ny, nx] and lab[ny, nx] == 0:
                                lab[ny, nx] = cur
                                q.append((ny, nx))
                sizes.append(n)
                cents.append((sy / n, sx / n))
    return lab, sizes, cents


def upscale(m: np.ndarray, h: int, w: int) -> np.ndarray:
    full = np.zeros((h, w), bool)
    H, W = m.shape
    full[: H * K, : W * K] = np.repeat(np.repeat(m, K, axis=0), K, axis=1)
    g = full.copy()                       # grow one block so anti-aliased rims survive
    g[1:, :] |= full[:-1, :]
    g[:-1, :] |= full[1:, :]
    g[:, 1:] |= full[:, :-1]
    g[:, :-1] |= full[:, 1:]
    return g


def bbox(a: np.ndarray):
    ys, xs = np.where(a > 0.5)
    return ys.min(), ys.max() + 1, xs.min(), xs.max() + 1


def main() -> None:
    src, sheet, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
    out.mkdir(parents=True, exist_ok=True)
    _size, (cols, rows), series, cells = SHEETS[sheet]
    im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    H, W = im.shape[:2]
    cw, ch = W / cols, H / rows
    a = key_alpha(im)
    a[:3, :] = a[-3:, :] = 0.0
    a[:, :3] = a[:, -3:] = 0.0
    rgb = edge_despill(despill(im, a), a)
    small = a[: H // K * K, : W // K * K].reshape(H // K, K, W // K, K).max(axis=(1, 3)) > 0.5
    lab, sizes, cents = label(small)
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
        m = upscale(keep[lab], H, W)
        picks.append(np.where(m, a, 0.0))
    if series:                            # one box (relative to each cell) for all stages
        rel = []
        for c, al in enumerate(picks):
            y0, y1, x0, x1 = bbox(al)
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
            y0, y1, x0, x1 = bbox(al)
            y0, y1, x0, x1 = y0 - PAD, y1 + PAD, x0 - PAD, x1 + PAD
        y0, x0 = max(0, y0), max(0, x0)
        y1, x1 = min(H, y1), min(W, x1)
        cc, aa = rgb[y0:y1, x0:x1], al[y0:y1, x0:x1]
        # transparent pixels carry the ink colour (mip / filter bleed reads as outline, not a magenta or pale halo)
        cc = np.where(aa[..., None] > 0.02, cc, INK)
        Image.fromarray(np.dstack([cc, aa * 255]).clip(0, 255).astype(np.uint8), "RGBA").save(out / f"{name}.png")
        ys = np.where(aa.max(axis=1) > 0.5)[0]
        meta = {"w": int(x1 - x0), "h": int(y1 - y0), "base": float((ys.max() + 1) / (y1 - y0)) if len(ys) else 1.0,
                "sheet": sheet, "series": bool(series)}
        (out / f"{name}.json").write_text(json.dumps(meta))
        print(name, meta)


if __name__ == "__main__":
    main()
