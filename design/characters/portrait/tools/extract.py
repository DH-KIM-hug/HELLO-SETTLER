"""Cut the generated 3x2 sheets into registered portrait layers.
For each cell: find how the model moved/scaled the green guide bust (search against the canonical template),
warp the cell back onto the canonical 512 canvas, key out magenta + green (with colour decontamination),
drop stray guide outlines,
and save the canonical 512 RGBA (split.py then makes the game layers).
usage: extract.py <sheet.png> <name1,name2,...(6)> <out_dir> [debug_dir]"""
import sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
import geom

OUT_PX = 256
FILL_GREY = 0.6
MAG = np.array([255, 0, 255], float)
GRN = np.array([0, 220, 70], float)


def template_mask(size=geom.CELL):
    im = Image.new("L", (geom.CELL, geom.CELL), 0)
    geom.draw_template(ImageDraw.Draw(im), col=255)
    if size != geom.CELL:
        im = im.resize((size, size), Image.BILINEAR)
    return np.asarray(im) > 127


def keys(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mk = np.clip((np.minimum(r, b) - g) / 200.0, 0, 1)
    gk = np.clip((g - np.maximum(r, b)) / 130.0, 0, 1)
    return mk, gk


def warp(arr_img, s, tx, ty, resample=Image.BICUBIC):
    """canonical(p) = observed(s*(p-c) + c + t)"""
    c = geom.CELL / 2
    data = (s, 0, (1 - s) * c + tx, 0, s, (1 - s) * c + ty)
    return arr_img.transform((geom.CELL, geom.CELL), Image.AFFINE, data, resample=resample, fillcolor=geom.MAGENTA)


def register(cell_rgb):
    """search scale/shift so the template matches the observed green bust (layer pixels are 'unknown')."""
    best = None
    for f, scales, shifts in ((4, np.arange(0.9, 1.101, 0.01), range(-8, 9)), (1, None, None)):
        n = geom.CELL // f
        small = np.asarray(Image.fromarray(cell_rgb).resize((n, n), Image.BILINEAR)).astype(float)
        mk, gk = keys(small)
        M, G = mk > 0.6, gk > 0.6
        if f == 1:
            s0, tx0, ty0 = best[1:]
            scales = np.arange(s0 - 0.012, s0 + 0.0121, 0.003)
            cands = [(s, tx, ty) for s in scales for tx in range(int(tx0) - 4, int(tx0) + 5) for ty in range(int(ty0) - 4, int(ty0) + 5)]
        else:
            cands = [(s, dx * f, dy * f) for s in scales for dx in shifts for dy in shifts]
        tm_img = Image.fromarray((template_mask() * 255).astype(np.uint8))
        cache = {}
        for s, tx, ty in cands:
            # observed template = template placed at s*(p-c)+c+t  -> inverse warp of template image
            key = round(s, 4)
            if key not in cache:
                c = geom.CELL / 2
                inv = 1 / s
                t = tm_img.transform((geom.CELL, geom.CELL), Image.AFFINE, (inv, 0, c - inv * c, 0, inv, c - inv * c), resample=Image.BILINEAR)
                cache[key] = np.asarray(t.resize((n, n), Image.BILINEAR)) > 127
            T = np.roll(np.roll(cache[key], int(round(ty / f)), 0), int(round(tx / f)), 1)
            cost = (np.count_nonzero(T & M) + np.count_nonzero(~T & G)) * f * f + 1500 * abs(s - 1) + 2 * (abs(tx) + abs(ty))   # prior: the model keeps the guide in place
            if best is None or cost < best[0]:
                best = (cost, s, tx, ty)
    return best


def extract_cell(cell_rgb, debug=None):
    cost, s, tx, ty = register(cell_rgb)
    canon = np.asarray(warp(Image.fromarray(cell_rgb), s, tx, ty)).astype(float)
    mk, gk = keys(canon)
    k = np.maximum(mk, gk)
    # pixels on the green|magenta seam are a mix of the two keys -> background too
    d = GRN - MAG
    t = np.clip(((canon - MAG) @ d) / (d @ d), 0, 1)
    near_m = ndi.binary_dilation(mk > 0.8, iterations=3)
    near_g = ndi.binary_dilation(gk > 0.8, iterations=3)
    seam = (np.linalg.norm(canon - (MAG + t[..., None] * d), axis=-1) < 60) & near_m & near_g
    k = np.where(seam, 1.0, k)
    a = 1.0 - k
    key = np.where((mk >= gk)[..., None], MAG, GRN)
    col = (canon - (1 - a)[..., None] * key) / np.maximum(a, 0.05)[..., None]
    col = np.clip(col, 0, 255)
    a = np.clip((a - 0.12) / 0.88, 0, 1)
    solid = a > 0.5
    # drop specks
    lab, n = ndi.label(solid)
    if n:
        sizes = ndi.sum(solid, lab, range(1, n + 1))
        keep = np.isin(lab, 1 + np.nonzero(sizes >= 30)[0])
        keep = ndi.binary_dilation(keep, iterations=2)
        a = a * keep
    # stray outlines that only trace the guide silhouette (dark, near the guide edge, no fill near)
    lum = col @ np.array([0.299, 0.587, 0.114])
    dark = (lum < 95) & (a > 0.2)
    fill = (lum >= 95) & (a > 0.5)
    tm = template_mask()
    edge = ndi.binary_dilation(tm, iterations=7) & ~ndi.binary_erosion(tm, iterations=7)
    near_fill = ndi.binary_dilation(fill, iterations=6)
    stray = dark & edge & ~near_fill
    stray = ndi.binary_dilation(stray, iterations=1) & ~fill
    a = a * ~stray
    out = Image.fromarray(np.dstack([col, a * 255]).astype(np.uint8), "RGBA")
    return out, (cost, s, tx, ty)


def main():
    sheet, names, out = sys.argv[1], sys.argv[2].split(","), sys.argv[3]
    im = Image.open(sheet).convert("RGB")
    if im.size != (1536, 1024):
        im = im.resize((1536, 1024), Image.LANCZOS)
    arr = np.asarray(im)
    for i, name in enumerate(names):
        if name in ("", "-"):
            continue
        r, c = divmod(i, 3)
        cell = np.ascontiguousarray(arr[r * 512:(r + 1) * 512, c * 512:(c + 1) * 512])
        layer, reg = extract_cell(cell)
        layer.save(f"{out}/{name}.png")
        print(f"{name}: cost={reg[0]} s={reg[1]:.3f} t=({reg[2]},{reg[3]})")


if __name__ == "__main__":
    main()
