"""Concept-A cast vs the game (2026-11-08): godot_shots/cutcast_vs_concept.png
rows: 1) res_A.png game-scale INSET (the in-game target, upscaled)  2) res_A.png close-ups (outfits)
      3) game ppu 60 (stand, walk)  4) game ppu 32 (stand, walk) — the crops from tools/shot_cutcast.gd, all scaled to one height.
usage: python3 cast_compare.py"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
SHOTS = os.path.join(ROOT, "godot_shots")
CON = Image.open(os.path.join(ROOT, "design", "concept", "residents", "res_A.png")).convert("RGB")
ROW_H = 300
W = 1600


def fit(im, h):
    return im.resize((max(1, int(im.width * h / im.height)), h), Image.LANCZOS)


def row(ims, label, gap=20):
    r = Image.new("RGB", (W, ROW_H + 30), (246, 240, 228))
    d = ImageDraw.Draw(r)
    d.text((10, 6), label, fill=(60, 40, 30))
    x = 10
    for im in ims:
        im = fit(im, ROW_H)
        if x + im.width > W:
            im = im.crop((0, 0, W - x, ROW_H))
        r.paste(im, (x, 30))
        x += im.width + gap
    return r


def main():
    # inset figures in a line (woman, man, child, elder), same scale
    boxes = [(980, 650, 1055, 765), (1090, 630, 1162, 730), (1012, 765, 1082, 872), (1125, 768, 1202, 866)]
    base = 872
    strip = Image.new("RGB", (4 * 80, 125), CON.getpixel((1000, 700)))
    for i, b in enumerate(boxes):
        c = CON.crop(b)
        strip.paste(c, (i * 80, 125 - c.height))
    inset = CON.crop((890, 572, 1296, 966))
    close = CON.crop((200, 10, 1345, 495))
    rows = [row([strip, inset], "concept res_A.png - game-scale inset (target look): lined up | as drawn"),
            row([close], "concept res_A.png - close-ups (outfits / colours)")]
    for ppu in (60, 32):
        ims = []
        for tag in ("stand", "walk"):
            p = os.path.join(SHOTS, "cutcast_%s_ppu%d_crop.png" % (tag, ppu))
            if os.path.exists(p):
                ims.append(Image.open(p).convert("RGB"))
        rows.append(row(ims, "game (world.tscn, day) ppu %d - stand | walk" % ppu))
    out = Image.new("RGB", (W, sum(r.height for r in rows)), (255, 255, 255))
    y = 0
    for r in rows:
        out.paste(r, (0, y))
        y += r.height
    out.save(os.path.join(SHOTS, "cutcast_vs_concept.png"))
    print("ok", out.size)


if __name__ == "__main__":
    main()
