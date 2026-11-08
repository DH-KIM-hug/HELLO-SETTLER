"""Assemble the cut parts with layout.json and compare against the AI's assembled figure.
usage: python3 compose.py <view> [scale]  -> parts/<view>/compose_check.png : figure | doll | 50% overlay
layout.json[<view>][part] = {"x","y","sx","sy"} top-left in figure.png pixel coords (sx/sy = scale; sy defaults to sx)
layer order from layers.json."""
import json, os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PARTS = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "woman_b", "parts"))


def doll(view, lay=None):
    d = os.path.join(PARTS, view)
    F = Image.open(os.path.join(d, "figure.png")).convert("RGBA")
    lay = lay or json.load(open(os.path.join(HERE, "layout.json")))[view]
    order = json.load(open(os.path.join(HERE, "layers.json")))[view]
    D = Image.new("RGBA", (F.width + 200, F.height + 100), (0, 0, 0, 0))
    for name in order:
        if name not in lay:
            continue
        L = lay[name]
        p = Image.open(os.path.join(d, name + ".png")).convert("RGBA")
        sx = L.get("sx", 1.0); sy = L.get("sy", sx)
        p = p.resize((max(1, round(p.width * sx)), max(1, round(p.height * sy))), Image.LANCZOS)
        if L.get("flip"):
            p = p.transpose(Image.FLIP_LEFT_RIGHT)
        if L.get("rot"):
            p = p.rotate(L["rot"], resample=Image.BICUBIC, expand=True)
        D.alpha_composite(p, (int(L["x"]) + 100, int(L["y"]) + 50))
    return F, D


def main(view):
    F, D = doll(view)
    W, H = D.size
    out = Image.new("RGBA", (W * 3, H), (190, 215, 160, 255))
    out.alpha_composite(F, (100, 50))
    out.alpha_composite(D, (W, 0))
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ov.alpha_composite(F, (100, 50))
    D2 = D.copy(); D2.putalpha(D.getchannel("A").point(lambda a: a // 2))
    ov.alpha_composite(D2)
    out.alpha_composite(ov, (W * 2, 0))
    out = out.resize((out.width // 2, out.height // 2), Image.LANCZOS)
    out.save(os.path.join(PARTS, "..", "raw", view + "_compose_check.png"))


if __name__ == "__main__":
    main(sys.argv[1])
