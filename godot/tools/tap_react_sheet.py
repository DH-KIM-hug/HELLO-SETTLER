#!/usr/bin/env python3
"""톡 반응 연속 사진을 한 장으로 (tools/shot_tap_react.gd가 찍은 godot_shots/tap_react/ppu*/…).

실행: python3 godot/tools/tap_react_sheet.py  →  godot_shots/tap_react/sheet_ppu16_{1,2,3}.png · sheet_ppu48_{1,2,3}.png · sheet_live.png
줄 = 경우 (왼쪽에 이름), 칸 = 시간 순서 사진 9장.
"""
import glob
import os
import re
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "godot_shots", "tap_react"))
CELL = (125, 150)
LABEL_W = 150
PAD = 4


def sheet(folder: str, dest: str, rows_per=0) -> None:
    files = sorted(glob.glob(os.path.join(folder, "*_[0-9].png")))
    cases = {}
    order = []
    for f in files:
        name, idx = os.path.basename(f)[:-4].rsplit("_", 1)
        if name not in cases:
            cases[name] = {}
            order.append(name)
        cases[name][int(idx)] = f
    if not order:
        return
    # 줄 순서 = 캡처 도구의 CASES 순서 (일부만 다시 찍어도 순서가 바뀌지 않게)
    listed = re.findall(r'\["([a-z0-9_]+)", "[a-z]+", (?:true|false), "', open(os.path.join(HERE, "shot_tap_react.gd"), encoding="utf-8").read())
    order.sort(key=lambda n: listed.index(n) if n in listed else len(listed))
    chunks = [order] if rows_per <= 0 else [order[i:i + rows_per] for i in range(0, len(order), rows_per)]
    for ci, chunk in enumerate(chunks):
        cols = max(len(cases[n]) for n in chunk)
        w = LABEL_W + cols * (CELL[0] + PAD) + PAD
        h = len(chunk) * (CELL[1] + PAD) + PAD
        im = Image.new("RGB", (w, h), (32, 30, 34))
        dr = ImageDraw.Draw(im)
        for ri, name in enumerate(chunk):
            y = PAD + ri * (CELL[1] + PAD)
            dr.text((6, y + CELL[1] // 2 - 12), name.replace("_", "\n", 1), fill=(240, 236, 220))
            for k in sorted(cases[name]):
                c = Image.open(cases[name][k]).convert("RGB")
                c = c.resize(CELL, Image.LANCZOS if c.width > CELL[0] else Image.NEAREST)
                im.paste(c, (LABEL_W + k * (CELL[0] + PAD), y))
        out = dest if len(chunks) == 1 else dest.replace(".png", "_%d.png" % (ci + 1))
        im.save(out)
        print("saved", out, im.size)


def live() -> None:
    files = sorted(glob.glob(os.path.join(OUT, "live_[0-9].png")))  # 8장
    if not files:
        return
    ims = [Image.open(f).convert("RGB") for f in files]
    cw, ch = 210, 210
    im = Image.new("RGB", (len(ims) * (cw + PAD) + PAD, ch + 2 * PAD), (32, 30, 34))
    for i, c in enumerate(ims):
        im.paste(c.resize((cw, ch), Image.LANCZOS), (PAD + i * (cw + PAD), PAD))
    im.save(os.path.join(OUT, "sheet_live.png"))
    print("saved", os.path.join(OUT, "sheet_live.png"), im.size)


if __name__ == "__main__":
    rows = int(sys.argv[1]) if len(sys.argv) > 1 else 8
    for z in (16, 48):
        sheet(os.path.join(OUT, "ppu%d" % z), os.path.join(OUT, "sheet_ppu%d.png" % z), rows)
    live()
