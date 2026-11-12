"""Q22 step 3-0 (2026-11-12): pack method C's two dye masks (raw/frames_mask0/1.png — build_frames.py writes them there; in the game
they were 2 x RGBA8 at full size = 47 MB of GPU memory with mipmaps) into a small set the shader reads instead (frame_doll.gdshader masks()):

  frames_mcode.png  L8, full atlas size, NOT mipmapped, nearest: one byte per texel = a row of the code table below
  frames_mlut.png   256 x 2 RGBA8: code -> (mask0 RGBA, mask1 RGBA) as the old masks had them
  frames_mq0.png    the old mask0 at a quarter of the size (= its mip level 2, box filtered like Godot's own mipmaps), mipmapped
  frames_mq1.png    the same for mask1

The shader filters the masks itself near the camera (lod < 2: bilinear on level 0 and on level 1 = 2x2 boxes of level 0, from the
codes, mixed like trilinear filtering) and lets the GPU filter the quarter-size pair further away (lod >= 2) — the same numbers the old
mipmapped masks gave, as long as each texel's code holds its exact mask values.

The code table (one byte = 256 codes): a texel of the old masks is (6 dye weights, hands-over-load, far leg). 99.8% of the texels have
at most one dye weight > 0, so a code = (dye slot, its weight, far leg on/off, hands-over-load on/off) — 181 codes. Weights snap to the
15 levels the mask builder writes (k/36 steps from 2x2 / 3x3 supersampling; only the baby / eyelid pictures used other levels). The spare
codes hold the most frequent exact texels the structural code misses (two dye slots meeting, a half-covered far-leg edge); the rest
(0.15% of the texels, 2026-11-12) keep the larger slot with the summed weight. Hands-over-load is only compared with 0.5 in the shader,
so on/off loses nothing; the far leg's half-covered edge texels darken fully or not at all (1 texel wide).
Measured (2026-11-12, shading emulated per mip level with random dyes): level 0 mean 0.07/255, 99.9th percentile 24/255, level 1 mean
0.07/255; levels 2+ exact.

usage: python3 pack_masks.py [--check]   (build_frames.py calls pack() after it writes the masks)
"""
import os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "woman_c"))
LEVELS = np.array([0, 28, 42, 56, 63, 85, 113, 127, 141, 170, 191, 198, 212, 226, 255])
HAND, FAR = 6, 7          # channel index in the 8-channel texel (mask0 RGBA, mask1 RGBA)
DYE = [0, 1, 2, 3, 4, 5]  # mask0 RGBA + mask1 RG


def snap(x):
    return LEVELS[np.abs(x[..., None].astype(np.int32) - LEVELS).argmin(-1)]


def box(x):
    """one mip step like Godot's Image.generate_mipmaps for 8-bit channels (2x2 average, rounded) — sizes here are even"""
    x = x.astype(np.int32)
    return ((x[0::2, 0::2] + x[1::2, 0::2] + x[0::2, 1::2] + x[1::2, 1::2] + 2) >> 2).astype(np.uint8)


def encode(t, far_bin=True):
    """t: (N, 8) uint8 texels -> (codes (N,) uint8, lut (256, 8) uint8, stats)"""
    t = t.astype(np.int32)
    d6 = t[:, DYE]
    w = np.minimum(d6.sum(1), 255)
    k = d6.argmax(1)
    # structural code per texel: dominant dye slot + snapped total weight, snapped far leg, hand on/off
    s = np.zeros_like(t)
    has = w > 0
    s[np.arange(len(t))[has], k[has]] = snap(w[has])
    s[:, FAR] = np.where(t[:, FAR] >= 128, 255, 0) if far_bin else snap(t[:, FAR])
    s[:, HAND] = np.where(t[:, HAND] >= 128, 255, 0)
    su, s_inv = np.unique(s, axis=0, return_inverse=True)
    s_inv = s_inv.reshape(-1)
    if len(su) > 256:
        raise SystemExit(f"pack_masks: {len(su)} structural codes > 256 — the masks use more levels than this packer knows")
    # spare codes: the most frequent exact texels that the structural code does not give back exactly
    exact = np.all(s == t, 1)
    lut = [tuple(r) for r in su]
    index = {r: i for i, r in enumerate(lut)}
    codes = s_inv.astype(np.int32)
    miss = ~exact
    if miss.any():
        mu, m_inv, mc = np.unique(t[miss], axis=0, return_inverse=True, return_counts=True)
        # most frequent first (2026-11-12: putting the half-covered hand texels first moved fewer hand edges but blurred more dye
        # meeting points — renders were worse overall: mean 0.11 vs 0.09/255 at ppu 60)
        order = np.argsort(-mc, kind="stable")
        take = {}
        for j in order:
            if len(lut) >= 256:
                break
            r = tuple(int(v) for v in mu[j])
            if r not in index:
                index[r] = len(lut)
                lut.append(r)
            take[j] = index[r]
        # the rest (rare meeting points of two or three dye slots) keep the structural code: the larger slot, summed weight
        mi = np.nonzero(miss)[0]
        m_inv = m_inv.reshape(-1)
        for j, ci in take.items():
            codes[mi[m_inv == j]] = ci
    lut_a = np.zeros((256, 8), np.uint8)
    lut_a[:len(lut)] = np.array(lut, np.uint8)
    back = lut_a[codes]
    stats = dict(codes=len(lut), texels=len(t), inexact=int(np.any(back != t, 1).sum()),
                 inexact_dyed=int((np.any(back != t, 1) & (d6.sum(1) > 0)).sum()), max_err=int(np.abs(back.astype(int) - t).max()))
    return codes.astype(np.uint8), lut_a, stats


def pack(m0, m1, out=ART, quiet=False):
    """m0, m1: (H, W, 4) arrays (0..255) of the two masks as build_frames.py makes them"""
    m0 = np.clip(m0, 0, 255).astype(np.uint8)
    m1 = np.clip(m1, 0, 255).astype(np.uint8)
    h, w = m0.shape[:2]
    assert h % 4 == 0 and w % 4 == 0, "atlas size must be a multiple of 4 (quarter-size masks = exact mip level 2)"
    t = np.concatenate([m0, m1], -1).reshape(-1, 8)
    codes, lut, st = encode(t)
    Image.fromarray(codes.reshape(h, w), "L").save(os.path.join(out, "frames_mcode.png"), optimize=True)
    Image.fromarray(np.stack([lut[:, :4], lut[:, 4:]], 0), "RGBA").save(os.path.join(out, "frames_mlut.png"), optimize=True)
    Image.fromarray(box(box(m0)), "RGBA").save(os.path.join(out, "frames_mq0.png"), optimize=True)
    Image.fromarray(box(box(m1)), "RGBA").save(os.path.join(out, "frames_mq1.png"), optimize=True)
    if not quiet:
        print(f"pack_masks: {st['codes']} codes · {st['inexact']} of {st['texels']} texels not exact ({st['inexact_dyed']} dyed, "
              f"largest channel error {st['max_err']}/255) · quarter masks {w // 4}x{h // 4}")
    return st


def main():
    m0 = np.array(Image.open(os.path.join(ART, "raw", "frames_mask0.png")).convert("RGBA"))
    m1 = np.array(Image.open(os.path.join(ART, "raw", "frames_mask1.png")).convert("RGBA"))
    pack(m0, m1)


if __name__ == "__main__":
    main()
