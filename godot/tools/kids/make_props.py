#!/usr/bin/env python3
"""아이·아기 소품 그림판 (Q2-b 귀여움 묶음 ② — view/kids_view.gd).
코드로 그린 작은 2D 그림 (먹선 252122 + 우리 팔레트) — 바깥 그림을 쓰지 않는다.
  python3 godot/tools/kids/make_props.py  →  godot/art/kids2d/kids_props.png  (+ 그림 표를 출력 — KidsView.PICS와 같아야 함)
그림: 요람(뒤·앞 — 아기 인형을 사이에 끼움) · 돌 셋 · 나비 · 먼지 뭉치
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

SS = 4                      # 크게 그려 줄임 (부드러운 선)
W, H = 512, 256
INK = (0x25, 0x21, 0x22, 255)
STRAW = (0xdd, 0xba, 0x7c, 255)
STRAW_D = (0xb8, 0x8e, 0x54, 255)
STRAW_L = (0xf0, 0xd7, 0xa0, 255)
INSIDE = (0x7c, 0x5b, 0x38, 255)
CREAM = (0xff, 0xfb, 0xea, 255)
BLANKET = (0xf6, 0xc9, 0xb6, 255)
STONE = [((0xcb, 0xc4, 0xb6, 255), (0xa6, 0x9e, 0x90, 255), (0xea, 0xe5, 0xda, 255)),
         ((0xb9, 0xb7, 0xb0, 255), (0x94, 0x92, 0x8c, 255), (0xdc, 0xda, 0xd4, 255)),
         ((0xd3, 0xc3, 0xa8, 255), (0xae, 0x9c, 0x80, 255), (0xee, 0xe2, 0xcc, 255))]
WING = (0xff, 0xdf, 0x6b, 255)
WING_L = (0xff, 0xf3, 0xb8, 255)
WING_D = (0xf2, 0x9a, 0x3c, 255)
PUFF = (0xf3, 0xea, 0xd3, 255)
PUFF_D = (0xb9, 0xab, 0x8e, 255)

# 이름 → (x, y, w, h) 그림판의 칸 (화소)
PICS = {
    "cradle_back": (0, 0, 176, 112),
    "cradle_front": (176, 0, 176, 112),
    "stone_a": (0, 128, 72, 56),
    "stone_b": (72, 128, 72, 56),
    "stone_c": (144, 128, 72, 56),
    "butterfly": (352, 0, 96, 80),
    "puff": (216, 128, 72, 56),
}


def ell(d, cx, cy, rx, ry, fill):
    d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=fill)


def poly(d, pts, fill):
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=fill)


def line(d, pts, fill, width):
    d.line([(x * SS, y * SS) for x, y in pts], fill=fill, width=int(width * SS), joint="curve")
    r = width * 0.5
    for x, y in (pts[0], pts[-1]):
        ell(d, x, y, r, r, fill)


def arc_pts(cx, cy, rx, ry, a0, a1, n=28):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def cell(w, h):
    im = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


# 요람: 낮고 넓은 짚 바구니. 위 테두리 타원 (rx 76, ry 20) 가운데 (88, 44), 바닥 타원 (rx 58, ry 14) 가운데 (88, 86)
RIM = (88, 44, 76, 20)
BOT = (88, 86, 58, 14)
LINE = 5.0


def body_pts():
    """바구니 몸통: 테두리 타원의 아랫호(앞) — 바닥 타원의 아랫호"""
    top = arc_pts(RIM[0], RIM[1], RIM[2], RIM[3], 180, 0)
    bot = arc_pts(BOT[0], BOT[1], BOT[2], BOT[3], 0, 180)
    return top + bot


def weave(d):
    for k in range(1, 4):
        t = k / 4.0
        cy = RIM[1] + (BOT[1] - RIM[1]) * t
        rx = RIM[2] + (BOT[2] - RIM[2]) * t
        ry = RIM[3] + (BOT[3] - RIM[3]) * t
        line(d, arc_pts(RIM[0], cy, rx - 3, ry, 12, 168), STRAW_D, 2.2)
    for k in range(-4, 5):
        dx0 = k * 15.5
        dx1 = k * 12.0
        y0 = RIM[1] + RIM[3] * math.sqrt(max(0.0, 1 - (dx0 / RIM[2]) ** 2))
        y1 = BOT[1] + BOT[3] * math.sqrt(max(0.0, 1 - (dx1 / BOT[2]) ** 2))
        line(d, [(RIM[0] + dx0, y0 + 4), (BOT[0] + dx1, y1 - 3)], STRAW_D, 1.8)


def body(d):
    pts = body_pts()
    poly(d, pts, INK)
    line(d, pts + [pts[0]], INK, LINE * 2)
    poly(d, pts, STRAW)
    weave(d)


def cradle_back():
    im, d = cell(176, 112)
    ell(d, RIM[0], RIM[1], RIM[2] + LINE, RIM[3] + LINE, INK)
    body(d)
    # 테두리 고리 + 안쪽 + 포근한 바닥 (아기 인형 뒤로 보임)
    ell(d, RIM[0], RIM[1], RIM[2], RIM[3], STRAW_L)
    ell(d, RIM[0], RIM[1], RIM[2] - 7, RIM[3] - 5, INK)
    ell(d, RIM[0], RIM[1] + 1, RIM[2] - 10, RIM[3] - 7, INSIDE)
    ell(d, RIM[0], RIM[1] + 4, RIM[2] - 16, RIM[3] - 9, CREAM)
    return im


def cradle_front():
    im, d = cell(176, 112)
    # 앞 몸통 (테두리 아랫호 아래) — 아기 인형의 아랫도리를 가림
    body(d)
    top = arc_pts(RIM[0], RIM[1], RIM[2] - 3, RIM[3], 6, 174)
    line(d, top, INK, 13)
    line(d, top, STRAW_L, 7)
    # 앞 테두리 너머로 넘어온 이불 자락 (물방울 무늬)
    fold = arc_pts(RIM[0] + 6, RIM[1] + 3, 44, 17, 22, 158)
    line(d, fold, INK, 16)
    line(d, fold, BLANKET, 10)
    for k in range(5):
        a = 35 + k * 27.5
        ell(d, RIM[0] + 6 + 44 * math.cos(math.radians(a)), RIM[1] + 3 + 17 * math.sin(math.radians(a)), 2.3, 2.3, CREAM)
    return im


def stone(i):
    im, _ = cell(72, 56)
    base, shade, light = STONE[i]
    cx, cy, rx, ry, rot = [(36, 30, 28, 18, 0.0), (36, 31, 30, 15, -4.0), (36, 30, 25, 19, 5.0)][i]
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ell(ld, cx, cy, rx + 4.5, ry + 4.5, INK)
    ell(ld, cx, cy, rx, ry, base)
    mask = Image.new("L", im.size, 0)
    ell(ImageDraw.Draw(mask), cx, cy, rx, ry, 255)
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    ell(sd, cx + 4, cy + ry * 0.8, rx * 1.1, ry * 0.62, shade)          # 아래쪽 그늘
    ell(sd, cx - rx * 0.3, cy - ry * 0.45, rx * 0.42, ry * 0.26, light)   # 위쪽 빛
    if i == 1:
        line(sd, [(cx - 6, cy + 2), (cx + 4, cy), (cx + 12, cy + 4)], shade, 2.0)
    inside = Image.new("L", im.size, 0)
    inside.paste(sh.split()[3], (0, 0), mask)
    layer.paste(sh, (0, 0), inside)
    layer = layer.rotate(rot, resample=Image.BICUBIC, center=(cx * SS, cy * SS))
    im.alpha_composite(layer)
    return im


def butterfly():
    im, d = cell(96, 80)
    cx, cy = 48, 42
    for s in (-1, 1):
        ell(d, cx + s * 22, cy - 12, 26, 23, INK)
        ell(d, cx + s * 16, cy + 16, 19, 18, INK)
    for s in (-1, 1):
        ell(d, cx + s * 22, cy - 12, 22, 19, WING)
        ell(d, cx + s * 16, cy + 16, 15, 14, WING_L)
        ell(d, cx + s * 28, cy - 15, 8, 7, WING_D)
        ell(d, cx + s * 18, cy + 18, 5, 5, WING_D)
        ell(d, cx + s * 14, cy - 8, 5, 4.5, CREAM)
    ell(d, cx, cy, 5.5, 22, INK)
    line(d, [(cx - 2, cy - 20), (cx - 9, cy - 34)], INK, 3)
    line(d, [(cx + 2, cy - 20), (cx + 9, cy - 34)], INK, 3)
    return im


def puff():
    im, d = cell(72, 56)
    blobs = [(24, 32, 15), (40, 26, 17), (52, 34, 12), (34, 38, 13)]
    for x, y, r in blobs:
        ell(d, x, y, r + 3.5, r + 3.5, PUFF_D)
    for x, y, r in blobs:
        ell(d, x, y, r, r, PUFF)
    ell(d, 38, 22, 7, 5, CREAM)
    return im


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.normpath(os.path.join(here, "..", "..", "art", "kids2d", "kids_props.png"))
    sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    made = {"cradle_back": cradle_back(), "cradle_front": cradle_front(), "stone_a": stone(0), "stone_b": stone(1), "stone_c": stone(2),
            "butterfly": butterfly(), "puff": puff()}
    for name, (x, y, w, h) in PICS.items():
        sheet.paste(made[name].resize((w, h), Image.LANCZOS), (x, y))
    # 투명한 곳의 색을 가까운 칠 색으로 번지게 (밉맵·가장자리에 검은 테가 끼지 않게)
    rgb = sheet.convert("RGB")
    a = sheet.split()[3]
    solid = a.point(lambda p: 255 if p > 8 else 0)
    bleed = Image.new("RGB", sheet.size, (0x40, 0x3a, 0x38))
    bleed.paste(rgb, (0, 0), solid)
    for _ in range(8):
        blur = bleed.filter(ImageFilter.BoxBlur(2))
        blur.paste(rgb, (0, 0), solid)
        bleed = blur
    final = Image.merge("RGBA", (*bleed.split(), a))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    final.save(out)
    print(out)
    print("const ATLAS := Vector2i(%d, %d)" % (W, H))
    print("const PICS := {" + ", ".join('"%s": Rect2i(%d, %d, %d, %d)' % (k, *v) for k, v in PICS.items()) + "}")


if __name__ == "__main__":
    main()
