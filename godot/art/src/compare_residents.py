"""Side-by-side: concept sheet crop | Blender turnaround render (render_residents.py) -> one comparison png.
Run with system python3 (PIL): python3 compare_residents.py <render_prefix> <out.png>"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SHEETS = os.path.normpath(os.path.join(HERE, "..", "..", "..", "design", "characters"))

# preset -> (sheet, crop box in original pixels)
CROPS = {
    "woman": ("base_c.png", (40, 140, 500, 680)),
    "man": ("base_c.png", (530, 110, 1030, 680)),
    "child": ("base_c.png", (1050, 250, 1410, 680)),
    "elder": ("base_c.png", (1420, 150, 1960, 680)),
    "farmer": ("jobs_a.png", (30, 80, 230, 440)),
    "baker": ("jobs_a.png", (40, 505, 230, 880)),
}


def main(prefix, out):
    rows = []
    H = 420
    for name, (sheet, box) in CROPS.items():
        p = "%s_%s.png" % (prefix, name)
        if not os.path.exists(p):
            continue
        ref = Image.open(os.path.join(SHEETS, sheet)).convert("RGB").crop(box)
        ref = ref.resize((int(ref.width * H / ref.height), H))
        ren = Image.open(p).convert("RGB")
        ren = ren.resize((int(ren.width * H / ren.height), H))
        row = Image.new("RGB", (ref.width + ren.width + 20, H), (250, 246, 238))
        row.paste(ref, (0, 0))
        row.paste(ren, (ref.width + 20, 0))
        ImageDraw.Draw(row).text((6, 4), name, fill=(80, 60, 40))
        rows.append(row)
    W = max(r.width for r in rows)
    img = Image.new("RGB", (W, sum(r.height + 8 for r in rows)), (250, 246, 238))
    y = 0
    for r in rows:
        img.paste(r, (0, y))
        y += r.height + 8
    img.save(out)
    print("compare ->", out, img.size)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
