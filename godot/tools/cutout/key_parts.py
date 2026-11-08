"""Cut a cutout part sheet (flat chroma-green background) into transparent part PNGs.
usage:
  python3 key_parts.py label <view>          -> raw/<view>_labels.png (numbered boxes) + prints components
  python3 key_parts.py cut <view>            -> parts/<view>/<name>.png using map.json[<view>] (index -> name)
map.json: {"front": {"0": "figure", "1": "head", ...}, ...}  (index from the label step; "-" = drop)
Also writes parts/<view>/sheet.json (bbox of each part in sheet pixels).
Only PIL + numpy (no scipy)."""
import json, sys, os
from collections import deque
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "woman_b"))
RAW = os.path.join(ART, "raw")
PARTS = os.path.join(ART, "parts")


def key(path):
    im = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    green = g - np.maximum(r, b)                  # >0 on chroma green, <=0 on the character (no green in her)
    a = np.clip((150.0 - green) / 90.0, 0.0, 1.0)  # green>=150 -> 0, green<=60 -> 1
    g2 = np.minimum(g, np.maximum(r, b))           # despill (safe: no green colour in the character)
    rgba = np.dstack([r, g2, b, a * 255.0]).astype(np.uint8)
    return rgba


def components(alpha, step=4, min_px=60):
    h, w = alpha.shape
    small = alpha[: h - h % step, : w - w % step].reshape(h // step, step, w // step, step).max(axis=(1, 3)) > 128
    # dilate 1 cell so thin outline gaps join
    d = small.copy()
    d[1:, :] |= small[:-1, :]; d[:-1, :] |= small[1:, :]; d[:, 1:] |= small[:, :-1]; d[:, :-1] |= small[:, 1:]
    lab = np.full(d.shape, -1, np.int32)
    comps = []
    H, W = d.shape
    for y in range(H):
        for x in range(W):
            if d[y, x] and lab[y, x] < 0:
                q = deque([(y, x)]); lab[y, x] = len(comps); n = 0
                y0 = y1 = y; x0 = x1 = x
                while q:
                    cy, cx = q.popleft(); n += 1
                    y0 = min(y0, cy); y1 = max(y1, cy); x0 = min(x0, cx); x1 = max(x1, cx)
                    for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                        if 0 <= ny < H and 0 <= nx < W and d[ny, nx] and lab[ny, nx] < 0:
                            lab[ny, nx] = len(comps); q.append((ny, nx))
                comps.append({"n": n, "box": [x0 * step, y0 * step, (x1 + 1) * step, (y1 + 1) * step]})
    keep = [i for i, c in enumerate(comps) if c["n"] * step * step >= min_px * 16]
    return lab, comps, keep, step


def label(view):
    rgba = key(os.path.join(RAW, view + ".png"))
    lab, comps, keep, step = components(rgba[..., 3])
    keep.sort(key=lambda i: (comps[i]["box"][1] // 200, comps[i]["box"][0]))
    img = Image.fromarray(rgba).convert("RGBA")
    bg = Image.new("RGBA", img.size, (255, 255, 255, 255)); bg.alpha_composite(img)
    dr = ImageDraw.Draw(bg)
    out = {}
    for k, i in enumerate(keep):
        x0, y0, x1, y1 = comps[i]["box"]
        dr.rectangle([x0, y0, x1, y1], outline=(255, 0, 0), width=2)
        dr.text((x0 + 3, y0 + 3), str(k), fill=(255, 0, 0))
        out[k] = comps[i]["box"]
        print(k, comps[i]["box"], comps[i]["n"])
    bg.save(os.path.join(RAW, view + "_labels.png"))
    json.dump({str(k): v for k, v in out.items()}, open(os.path.join(RAW, view + "_comps.json"), "w"))


def cut(view):
    rgba = key(os.path.join(RAW, view + ".png"))
    lab, comps, keep, step = components(rgba[..., 3])
    keep.sort(key=lambda i: (comps[i]["box"][1] // 200, comps[i]["box"][0]))
    m = json.load(open(os.path.join(HERE, "map.json")))[view]
    od = os.path.join(PARTS, view); os.makedirs(od, exist_ok=True)
    sheet = {}
    merged = {}
    for k, i in enumerate(keep):
        name = m.get(str(k), "-")
        if name == "-":
            continue
        merged.setdefault(name, []).append(i)
    for name, ids in merged.items():
        sel = np.isin(lab, ids)
        full = np.kron(sel, np.ones((step, step), bool))
        mask = np.zeros(rgba.shape[:2], bool); mask[: full.shape[0], : full.shape[1]] = full
        ys, xs = np.where(mask & (rgba[..., 3] > 0))
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        part = rgba[y0:y1, x0:x1].copy()
        part[..., 3] = np.where(mask[y0:y1, x0:x1], part[..., 3], 0)
        Image.fromarray(part).save(os.path.join(od, name + ".png"))
        sheet[name] = [int(x0), int(y0), int(x1), int(y1)]
        print(view, name, sheet[name])
    json.dump(sheet, open(os.path.join(od, "sheet.json"), "w"), indent=1)


if __name__ == "__main__":
    {"label": label, "cut": cut}[sys.argv[1]](sys.argv[2])
