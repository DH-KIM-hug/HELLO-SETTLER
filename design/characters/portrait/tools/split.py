"""Raw 512 layers -> game layers (256 px).
Tinted parts (skin, hair, beard, grey cloth, grey hats) become two files:
  <name>_fill.png  greyscale+alpha, main fill normalised to 0.6 — the game multiplies it by the gene / cloth colour / 0.6
  <name>.png       the dark-brown line art and any natural-coloured bits (cream lining, leather, ...), drawn on top untinted
Each pixel is split as  c = w*INK + (1-w)*grey(v)  (least squares along the ink chroma), so anti-aliased edges stay clean.
Natural layers (faces, straw/baker hats, sash, apron, strap, baby blanket) are kept as one RGBA file.
usage: split.py <raw_dir> <out_dir>"""
import os
import sys
import numpy as np
from PIL import Image

OUT_PX = 256
INK = np.array([74, 46, 31], float)
NATURAL = ("face_", "freckles", "age_wrinkles", "over_sash", "over_apron", "over_strap", "hat_straw", "hat_baker", "baby_blanket")


def down(rgba):
    pm = rgba.astype(float).copy()
    pm[..., :-1] *= pm[..., -1:] / 255
    mode = "RGBA" if rgba.shape[-1] == 4 else "LA"
    small = np.asarray(Image.fromarray(np.clip(pm, 0, 255).astype(np.uint8), mode).resize((OUT_PX, OUT_PX), Image.LANCZOS)).astype(float)
    al = small[..., -1:]
    small[..., :-1] = np.where(al > 0, small[..., :-1] * 255 / np.maximum(al, 1), 0)
    return Image.fromarray(np.clip(small, 0, 255).astype(np.uint8), mode)


def split(raw):
    c = raw[..., :3].astype(float)
    a = raw[..., 3].astype(float) / 255
    ci = INK - INK.mean()
    cc = c - c.mean(-1, keepdims=True)
    w = np.clip((cc @ ci) / (ci @ ci), 0, 1)
    resid = np.linalg.norm(cc - w[..., None] * ci, axis=-1)
    v = (c.mean(-1) - w * INK.mean()) / np.maximum(1 - w, 0.02)
    mx, mn = c.max(-1), c.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1)
    natural = ((resid > 14) | (v > 275) | (v < -15)) & (sat > 0.1) & (a > 0.5)
    v = np.clip(v, 0, 255)
    body = (~natural) & (a > 0.9) & (w < 0.15) & (v > 100) & (v < 215)
    med = np.median(v[body]) if np.count_nonzero(body) > 100 else 153
    v = np.clip(v * 153 / med, 0, 255)
    fill_a = np.where(natural, 0, a)
    fill = np.dstack([v, v, v, fill_a * 255])
    line_rgb = np.where(natural[..., None], c, INK)
    line_a = np.where(natural, a, a * w)
    line = np.dstack([line_rgb, line_a * 255])
    return fill, line


def soften_blush(raw):
    c = raw[..., :3].astype(float)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    pink = (r > 190) & (r - g > 45) & (r - b > 45) & (g > 90)
    out = raw.copy()
    out[..., 3] = np.where(pink, raw[..., 3] * 0.55, raw[..., 3]).astype(np.uint8)
    return out


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    for f in sorted(os.listdir(src)):
        if not f.endswith(".png"):
            continue
        name = f[:-4]
        raw = np.asarray(Image.open(os.path.join(src, f)).convert("RGBA"))
        if name.startswith(NATURAL):
            if name.startswith("face_"):
                raw = soften_blush(raw)
            down(raw).save(os.path.join(dst, f), optimize=True)
            continue
        fill, line = split(raw)
        down(fill).save(os.path.join(dst, name + "_fill.png"), optimize=True)
        down(line).save(os.path.join(dst, f), optimize=True)
