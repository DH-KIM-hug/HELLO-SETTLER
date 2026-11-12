"""Q22 5 second woman outfit: stack the strip captures of tools/shot_woman2_c.gd into labelled sheets.
usage: python3 compose_woman2.py   (reads godot_shots/looks/l7_tmp/strip_ppu<P>_<clip>_<view>.png, live_ppu<P>_<n>.png)
 -> godot_shots/looks/l7_<clip>_ppu<P>.png (views stacked: woman_c top / woman2_c apron middle / woman2_c no apron bottom),
    l7_live_ppu<P>.png (village captures side by side), l7_sheet.png (contact sheet, 5 columns)"""
import glob, os, re
from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
SH = os.path.join(ROOT, "godot_shots", "looks")
TMP = os.path.join(SH, "l7_tmp")
VIEWS = ["front", "3/4 front", "3/4 back", "back"]


def label(im, text):
    out = Image.new("RGB", (im.width, im.height + 26), (30, 30, 30))
    out.paste(im, (0, 26))
    ImageDraw.Draw(out).text((8, 6), text, fill=(240, 240, 240))
    return out


def main():
    made = []
    strips = {}
    for p in glob.glob(os.path.join(TMP, "strip_ppu*_*.png")):
        m = re.match(r"strip_ppu(\d+)_(\w+)_(\d)\.png", os.path.basename(p))
        strips.setdefault((int(m.group(1)), m.group(2)), []).append((int(m.group(3)), p))
    for (ppu, clip), lst in sorted(strips.items()):
        ims = [label(Image.open(p).convert("RGB"), f"{clip} - {VIEWS[v]} - ppu {ppu} - top: woman_c, middle: woman2_c apron, bottom: woman2_c no apron") for v, p in sorted(lst)]
        w = max(i.width for i in ims)
        out = Image.new("RGB", (w, sum(i.height for i in ims)), (30, 30, 30))
        y = 0
        for i in ims:
            out.paste(i, (0, y))
            y += i.height
        if ppu == 20:
            out = out.resize((out.width * 2, out.height * 2), Image.NEAREST)
        f = os.path.join(SH, f"l7_{clip}_ppu{ppu}.png")
        out.save(f)
        made.append(f)
    for ppu in (44, 20):
        lv = sorted(glob.glob(os.path.join(TMP, f"live_ppu{ppu}_*.png")))
        if lv:
            ims = [Image.open(p).convert("RGB") for p in lv[:3]]
            out = Image.new("RGB", (sum(i.width for i in ims), max(i.height for i in ims)), (30, 30, 30))
            x = 0
            for i in ims:
                out.paste(i, (x, 0))
                x += i.width
            f = os.path.join(SH, f"l7_live_ppu{ppu}.png")
            label(out, f"village, method C on: women a (woman_c) + b (woman2_c, apron / none) + men walking diagonally - ppu {ppu}").save(f)
            made.append(f)
    # contact sheet: ppu 44 sheets + the two live shots, 5 columns of 380 px
    pick = [f for f in made if "ppu44" in f] + [f for f in made if "live_ppu20" in f]
    tw = 380
    th = []
    tiles = []
    for f in pick:
        im = Image.open(f).convert("RGB")
        k = tw / im.width
        im = im.resize((tw, int(im.height * k)))
        tiles.append(label(im, os.path.basename(f)))
    cols = 5
    rows = [tiles[i:i + cols] for i in range(0, len(tiles), cols)]
    H = sum(max(t.height for t in r) for r in rows)
    sheet = Image.new("RGB", (cols * tw, H), (30, 30, 30))
    y = 0
    for r in rows:
        for c, t in enumerate(r):
            sheet.paste(t, (c * tw, y))
        y += max(t.height for t in r)
    sheet.save(os.path.join(SH, "l7_sheet.png"))
    print("\n".join(made + [os.path.join(SH, "l7_sheet.png")]))


if __name__ == "__main__":
    main()
