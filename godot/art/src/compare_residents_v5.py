"""A20 v5 compare sheet: concept-sheet crops (same 8 people as tools/shot_residents_v5.gd) above the Godot captures
(front, back, 48-degree game camera at three zooms, resident-detail portraits) -> one png.
Run with system python3 (Pillow): python3 compare_residents_v5.py <suffix> <out.png>
  reads godot_shots/residents_v5_{sheet,back,game,mid,far,ui}<suffix>.png (missing ones are skipped)"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
SHEETS = os.path.join(ROOT, "design", "characters")
SHOTS = os.path.join(ROOT, "godot_shots")

# the 8 people of shot_residents_v5.gd _specs(), in order: sheet, crop box (original px)
CROPS = [
    ("base_c.png", (40, 145, 250, 680)),        # woman: curly long + headscarf
    ("base_c.png", (525, 118, 725, 680)),       # man: wavy + hood
    ("base_c.png", (1045, 275, 1190, 680)),     # child: curly
    ("base_c.png", (1420, 165, 1600, 680)),     # elder: white curls + shawl + cane
    ("jobs_a.png", (35, 90, 220, 445)),         # farmer: straw hat
    ("jobs_a.png", (245, 90, 465, 435)),        # woodcutter: cap + beard
    ("variety_c.png", (325, 55, 485, 510)),     # braids
    ("variety_c.png", (545, 515, 705, 1020)),   # bun
]
BG = (250, 246, 238)
W = 3200
ROWS = (("sheet", "Godot: front 3/4 (close LOD)", 1), ("back", "Godot: back (close LOD)", 1),
        ("hair", "Godot: every hair style, front 3/4 (short, long, braids, bun, curly, curly long, wave, wave long)", 1),
        ("game", "Godot: 48 deg game camera, inspection zoom ppu 330 (close LOD)", 1),
        ("mid", "Godot: 48 deg game camera, max in-game zoom ppu 60 (close LOD), x3", 3),
        ("far", "Godot: 48 deg game camera, default zoom ppu 16 (far LOD), x6 nearest", 6),
        ("ui", "Godot: resident detail portrait", 1))


def fit_w(im, w):
    return im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)


def main(suffix, out):
    H = 560
    refs = []
    for sheet, box in CROPS:
        im = Image.open(os.path.join(SHEETS, sheet)).convert("RGB").crop(box)
        refs.append(im.resize((int(im.width * H / im.height), H), Image.LANCZOS))
    cell = W // len(refs)
    row = Image.new("RGB", (W, H), BG)
    for i, im in enumerate(refs):
        row.paste(im, (i * cell + (cell - im.width) // 2, 0))
    rows = [("concept sheets", row)]
    for name, label, up in ROWS:
        p = os.path.join(SHOTS, "residents_v5_%s%s.png" % (name, suffix))
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB")
        if up > 1:
            im = im.resize((im.width * up, im.height * up), Image.NEAREST)
            if im.width < W:                     # keep the pixels readable: pad instead of stretching
                pad = Image.new("RGB", (W, im.height), BG)
                pad.paste(im, ((W - im.width) // 2, 0))
                im = pad
        rows.append((label, fit_w(im, W)))
    img = Image.new("RGB", (W, sum(r.height + 40 for _, r in rows)), BG)
    d = ImageDraw.Draw(img)
    y = 0
    for label, r in rows:
        d.text((10, y + 12), label, fill=(80, 60, 40))
        img.paste(r, (0, y + 40))
        y += r.height + 40
    img.save(out)
    print("compare ->", out, img.size)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
