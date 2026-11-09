"""Proportion check sheet (2026-11-09 user: "아니 아직도 긴데요?"): old cutout vs method C at the SAME scale (ppu 44 strips),
3/4 front: idle frame 1 + walk frames 1, 3, 5, 7. For each figure: top of head, skirt hem, sole -> ruler lines + ratios
(visible leg = hem->sole / total height). Also measures the res_A in-game inset woman.
usage (after shot_cutC_compare + compose_compare): python3 compose_props.py -> godot_shots/cutC/props_q_front_ppu44.png"""
import os
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "godot_shots", "cutC"))
INSET = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "woman_c", "raw", "ref_inset_woman.png"))


def masks(a):
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    fg = ~((g > r + 12) & (g > b + 5))                       # not grass / shadow
    L = 0.299 * r + 0.587 * g + 0.114 * b
    rose = (r - g > 40) & (np.abs(g - b) < 35) & (r > 160) & (L > 115)
    return fg, rose


def measure(a):
    """on the flat backdrop plate (shot_cutC_compare): figure = the biggest blob of non-backdrop pixels in the box;
    top / sole = its extent, hem = its lowest dress-colour row"""
    import sys as _s
    _s.path.insert(0, HERE)
    from build_frames import blobs
    bg = np.median(np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]), 0)
    fg = np.abs(a.astype(int) - bg[None, None]).sum(-1) > 45
    bl = blobs(fg, 30)
    m = bl[0][4]
    _, rose = masks(a)
    rose &= m
    rows = np.nonzero(m.any(1))[0]
    top, sole = int(rows.min()), int(rows.max())
    rr = np.nonzero(rose.sum(1) >= 3)[0]
    hem = int(rr.max())
    return dict(top=top, hem=hem, sole=sole, H=sole - top, leg=round((sole - hem) / (sole - top), 3))


SP_PX = 0.7 * 44 * 3        # strip column spacing (shot_cutC_compare SP x ppu x 3)


def figures(img, y0, y1):
    """x spans of the 8 strip columns (shot_cutC_compare: crop = columns +-0.42 + 12 px, pasted at x 92)"""
    return [(round(92 + 12 + (0.42 + i * 0.7) * 132 - 46), round(92 + 12 + (0.42 + i * 0.7) * 132 + 46)) for i in range(8)]


def block(img, view_i):
    h = (img.height - 26) // 4
    y0 = 26 + view_i * h
    mid = y0 + h // 2
    return (y0, mid - 5), (mid - 25, y0 + h)


def main():
    idle = Image.open(os.path.join(OUT, "cmp_ppu44_idle.png"))
    walk = Image.open(os.path.join(OUT, "cmp_ppu44_walk.png"))
    picks = []   # (label, img, box)
    for row_i, tag in ((0, "old"), (1, "new C")):
        for src, frames, name in ((idle, [0], "idle"), (walk, [0, 2, 4, 6], "walk")):
            band = block(src, 1)[row_i]
            sp = figures(src, *band)
            for f in frames:
                if f < len(sp):
                    picks.append((f"{tag} {name} {f + 1}", src, (sp[f][0], band[0], sp[f][1], band[1])))
    tiles, res = [], []
    for label, src, box in picks:
        c = src.convert("RGB").crop(box)
        m = measure(np.asarray(c))
        res.append((label, m))
        t = c.resize((c.width * 2, c.height * 2), Image.NEAREST)
        d = ImageDraw.Draw(t)
        for y, colr in ((m["top"], (255, 255, 255)), (m["hem"], (255, 60, 60)), (m["sole"], (40, 40, 255))):
            d.line((0, y * 2, t.width, y * 2), fill=colr, width=1)
        d.text((3, 3), label, fill=(0, 0, 0))
        d.text((3, t.height - 24), f"H {m['H']}  leg {m['leg']:.2f}", fill=(0, 0, 0))
        tiles.append(t)
    W = max(t.width for t in tiles)
    Hh = max(t.height for t in tiles)
    n = len(tiles) // 2
    sheet = Image.new("RGB", (W * n, Hh * 2 + 24), (40, 40, 40))
    d = ImageDraw.Draw(sheet)
    d.text((6, 6), "ppu 44, 3/4 front, same scale (x2 nearest). white = head top, red = skirt hem, blue = sole. leg = hem->sole / height", fill=(255, 255, 255))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % n) * W, 24 + (i // n) * Hh))
    sheet.save(os.path.join(OUT, "props_q_front_ppu44.png"))
    ins = measure(np.asarray(Image.open(INSET).convert("RGB")))
    for label, m in res:
        print(f"{label:14s} H {m['H']:4d}px  hem->sole {m['sole'] - m['hem']:3d}px  leg ratio {m['leg']:.3f}")
    print(f"res_A inset    leg ratio {ins['leg']:.3f}")


if __name__ == "__main__":
    main()
