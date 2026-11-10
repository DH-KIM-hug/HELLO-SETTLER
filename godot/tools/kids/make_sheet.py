#!/usr/bin/env python3
"""godot_shots/kids/ 의 장면 캡처(tools/shot_kids.gd)를 장면마다 한 장으로 모음 → sheet_<장면>.png (칸 4개씩)
  python3 godot/tools/kids/make_sheet.py"""
import glob
import os
import re
from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.normpath(os.path.join(here, "..", "..", "..", "godot_shots", "kids"))
groups = {}
for p in sorted(glob.glob(os.path.join(out, "*.png"))):
    name = os.path.basename(p)[:-4]
    if name.startswith(("audit_", "sheet_", "kids_sheet")):
        continue
    key = name.split("_")[0]
    m = re.search(r"_(\d+)$", name)
    groups.setdefault(key, []).append((("far" in name, "fall" in name, "wobble" not in name and "fall" not in name and False, int(m.group(1)) if m else 0), p))
for key, items in groups.items():
    order = {"": 0, "wobble": 1, "fall": 2, "far": 3}
    def rank(it):
        n = os.path.basename(it[1])[:-4]
        kind = "far" if "_far" in n else ("fall" if "_fall" in n else ("wobble" if "_wobble" in n else ""))
        return (order[kind], it[0][3])
    items.sort(key=rank)
    ims = [Image.open(p).convert("RGB") for _, p in items]
    w = max(i.width for i in ims) // 2
    h = max(i.height for i in ims) // 2
    cols = 4
    rows = (len(ims) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (w + 6) + 6, rows * (h + 6) + 6), (40, 36, 34))
    for k, im in enumerate(ims):
        sheet.paste(im.resize((im.width // 2, im.height // 2), Image.LANCZOS), (6 + (k % cols) * (w + 6), 6 + (k // cols) * (h + 6)))
    sheet.save(os.path.join(out, "sheet_%s.png" % key))
    print("sheet_%s.png" % key, len(ims))
