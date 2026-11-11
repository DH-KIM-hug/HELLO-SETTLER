#!/usr/bin/env python3
"""유모차 · 첫 심부름 · 첫 낚시 소품 그림판 (ROADMAP E2-2 · E2-3 — view/outing_view.gd).
코드로 그린 작은 2D 그림 — 요람(make_props.py)과 같은 먹선·짚 바구니·이불. 바깥 그림을 쓰지 않는다.
  python3 godot/tools/kids/make_outing.py  →  godot/art/kids2d/kids_outing.png  (+ 그림 표 · 바퀴 자리를 출력 — OutingView와 같아야 함)
그림: 나무 유모차 네 방향 (앞 · 앞 비스듬 · 뒤 비스듬 · 뒤 — 저마다 뒤 장·앞 장, 아기 인형을 사이에 끼움) · 단추 바퀴 ·
      아기 벙어리장갑 손 · 보퉁이 · 그릇 · 풀줄기 낚싯대 · 낚싯줄 · 조그만 물고기
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter
from make_props import SS, INK, STRAW, STRAW_D, STRAW_L, INSIDE, CREAM, BLANKET, ell, poly, line, arc_pts, cell

W, H = 512, 512
LINE = 5.0
WOOD = (0xc9, 0x9a, 0x5e, 255)
WOOD_D = (0x9a, 0x6f, 0x40, 255)
WOOD_L = (0xe6, 0xc2, 0x8a, 255)
FAR = (0x8a, 0x66, 0x40, 255)          # 건너편 바퀴 (그늘)
GRASS = (0x9c, 0xc2, 0x64, 255)
GRASS_D = (0x6f, 0x9a, 0x48, 255)
SEED = (0xe8, 0xcf, 0x8e, 255)
FISH = (0xa8, 0xd6, 0xe8, 255)
FISH_L = (0xe6, 0xf6, 0xfb, 255)
FLOAT = (0xf2, 0x9a, 0x3c, 255)
SOUP = (0xff, 0xe9, 0xb0, 255)

GROUND = 134                            # 바퀴가 닿는 줄 (칸 위에서부터 화소)
PICS = {
    "p1_back": (0, 0, 192, 144), "p1_front": (192, 0, 192, 144),
    "p2_back": (0, 144, 192, 144), "p2_front": (192, 144, 192, 144),
    "p0_back": (0, 288, 128, 144), "p0_front": (128, 288, 128, 144),
    "p3_back": (256, 288, 128, 144), "p3_front": (384, 288, 128, 144),
    "wheel": (384, 0, 52, 52), "hand": (440, 0, 36, 36), "bundle": (384, 56, 64, 64), "bowl": (448, 56, 64, 56),
    "rod": (384, 124, 128, 80), "line": (384, 208, 16, 76), "fish": (404, 208, 48, 60),
}
SIDE_TILT = {1: 5.0, 2: -5.0}           # 비스듬한 그림: 앞머리(왼쪽)가 내려감(+) · 올라감(−)
WHEEL_R = 19.0
NEAR = [(-44.0, 0.0), (36.0, 0.0)]      # 가까운 쪽 바퀴 (바구니 가운데에서 가로, 땅에서 — 기울이기 전)
FARW = [(-30.0, -9.0), (50.0, -9.0)]
PIVOT = (96.0, 100.0)


def basket(d, rim, bot, n_v=4):
    """짚 바구니 몸통 (요람과 같은 결) — 테두리 타원의 아랫호에서 바닥 타원의 아랫호까지"""
    top = arc_pts(rim[0], rim[1], rim[2], rim[3], 180, 0)
    bt = arc_pts(bot[0], bot[1], bot[2], bot[3], 0, 180)
    pts = top + bt
    poly(d, pts, INK)
    line(d, pts + [pts[0]], INK, LINE * 2)
    poly(d, pts, STRAW)
    for k in range(1, 4):
        t = k / 4.0
        cy = rim[1] + (bot[1] - rim[1]) * t
        rx = rim[2] + (bot[2] - rim[2]) * t
        ry = rim[3] + (bot[3] - rim[3]) * t
        line(d, arc_pts(rim[0], cy, rx - 3, ry, 12, 168), STRAW_D, 2.2)
    for k in range(-n_v, n_v + 1):
        dx0 = k * (rim[2] - 6) / n_v
        dx1 = k * (bot[2] - 6) / n_v
        y0 = rim[1] + rim[3] * math.sqrt(max(0.0, 1 - (dx0 / rim[2]) ** 2))
        y1 = bot[1] + bot[3] * math.sqrt(max(0.0, 1 - (dx1 / bot[2]) ** 2))
        line(d, [(rim[0] + dx0, y0 + 4), (bot[0] + dx1, y1 - 3)], STRAW_D, 1.8)


def inside(d, rim):
    ell(d, rim[0], rim[1], rim[2] + LINE, rim[3] + LINE, INK)
    ell(d, rim[0], rim[1], rim[2], rim[3], STRAW_L)
    ell(d, rim[0], rim[1], rim[2] - 7, rim[3] - 5, INK)
    ell(d, rim[0], rim[1] + 1, rim[2] - 10, rim[3] - 7, INSIDE)
    ell(d, rim[0], rim[1] + 4, rim[2] - 16, rim[3] - 9, CREAM)


def front_rim(d, rim, fold=True, fx=6.0):
    top = arc_pts(rim[0], rim[1], rim[2] - 3, rim[3], 6, 174)
    line(d, top, INK, 13)
    line(d, top, STRAW_L, 7)
    if fold:
        rx = rim[2] * 0.56
        f = arc_pts(rim[0] + fx, rim[1] + 3, rx, rim[3] - 3, 24, 156)
        line(d, f, INK, 15)
        line(d, f, BLANKET, 9)
        for k in range(4):
            a = 40 + k * 33.0
            ell(d, rim[0] + fx + rx * math.cos(math.radians(a)), rim[1] + 3 + (rim[3] - 3) * math.sin(math.radians(a)), 2.2, 2.2, CREAM)


def bar(d, a, b, w=7.0, col=WOOD):
    line(d, [a, b], INK, w + LINE * 1.7)
    line(d, [a, b], col, w)


def plank(d, x0, x1, y):
    line(d, [(x0, y), (x1, y)], INK, 9 + LINE * 1.6)
    line(d, [(x0, y), (x1, y)], WOOD_D, 9)
    line(d, [(x0 + 3, y - 2), (x1 - 3, y - 2)], WOOD, 3)


def button(d, cx, cy, r, col=WOOD, dark=WOOD_D, holes=True):
    ell(d, cx, cy, r + LINE * 0.8, r + LINE * 0.8, INK)
    ell(d, cx, cy, r, r, col)
    ell(d, cx, cy, r * 0.72, r * 0.72, dark)
    ell(d, cx, cy, r * 0.58, r * 0.58, col)
    if holes:
        for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            ell(d, cx + sx * r * 0.24, cy + sy * r * 0.24, r * 0.13, r * 0.13, INK)
        ell(d, cx - r * 0.42, cy - r * 0.46, r * 0.16, r * 0.1, WOOD_L)


def thin_wheel(d, cx, cy, rx, ry, col=WOOD, dark=WOOD_D):
    ell(d, cx, cy, rx + LINE * 0.8, ry + LINE * 0.8, INK)
    ell(d, cx, cy, rx, ry, col)
    ell(d, cx + rx * 0.25, cy, rx * 0.45, ry * 0.8, dark)


def tilt(im, deg):
    return im.rotate(deg, resample=Image.BICUBIC, center=(PIVOT[0] * SS, PIVOT[1] * SS)) if deg else im


def rot_pt(x, y, deg):
    """tilt와 같은 돌림 (그림 좌표 — y 아래로)"""
    a = math.radians(-deg)
    dx, dy = x - PIVOT[0], y - PIVOT[1]
    return PIVOT[0] + dx * math.cos(a) - dy * math.sin(a), PIVOT[1] + dx * math.sin(a) + dy * math.cos(a)


SRIM = (96, 66, 60, 17)
SBOT = (96, 100, 49, 12)


def side(view, front):
    """비스듬한 그림 (왼쪽이 앞머리, 오른쪽 위가 손잡이). view 1 = 앞 비스듬 (이쪽으로 옴) · 2 = 뒤 비스듬 (멀어짐)"""
    deg = SIDE_TILT[view]
    im, d = cell(192, 144)
    near_handle = view == 2            # 멀어질 때는 손잡이가 이쪽
    rail_n = [(150, 78), (182, 28)]
    rail_f = [(144, 60), (174, 18)]
    if not front:
        if not near_handle:
            bar(d, rail_f[0], rail_f[1], 6, WOOD_D)
            bar(d, rail_n[0], rail_n[1])
            bar(d, rail_n[1], rail_f[1], 8)
        else:
            bar(d, rail_f[0], rail_f[1], 6, WOOD_D)
        inside(d, SRIM)
        basket(d, SRIM, SBOT)
        inside(d, SRIM)
        im = tilt(im, deg)
        d = ImageDraw.Draw(im)
        for wx, wy in FARW:             # 건너편 바퀴: 뒤 장의 맨 뒤에 (바구니 밑으로 조금 보임)
            pass
        under = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ud = ImageDraw.Draw(under)
        for wx, wy in FARW:
            x, y = rot_pt(96 + wx, GROUND - WHEEL_R + wy + 2, deg)
            button(ud, x, y, WHEEL_R - 3, FAR, WOOD_D, False)
        under.alpha_composite(im)
        return under
    plank(d, 44, 150, 108)
    basket(d, SRIM, SBOT)
    front_rim(d, SRIM, view == 1, -10.0)
    if near_handle:
        bar(d, rail_n[0], rail_n[1])
        bar(d, rail_n[1], rail_f[1], 8)
    return tilt(im, deg)


ERIM = (64, 66, 52, 16)
EBOT = (64, 100, 43, 11)


def end(view, front):
    """정면 (0: 이쪽으로 옴) · 뒷면 (3: 멀어짐) — 바구니 머리 쪽에서 본 그림"""
    im, d = cell(128, 144)
    xs = (26, 102)
    if not front:
        for x in (13, 115):
            thin_wheel(d, x, GROUND - 17 - 5, 6, 15, FAR, WOOD_D)
        if view == 0:                   # 손잡이는 바구니 너머 (미는 사람 쪽)
            for x in xs:
                bar(d, (x, 64), (x, 24))
            bar(d, (xs[0] - 4, 22), (xs[1] + 4, 22), 8)
        inside(d, ERIM)
        basket(d, ERIM, EBOT, 3)
        inside(d, ERIM)
        return im
    for x in (11, 117):
        thin_wheel(d, x, GROUND - 17, 6.5, 17)
    plank(d, 16, 112, 110)
    basket(d, ERIM, EBOT, 3)
    front_rim(d, ERIM, view == 0, 0.0)
    if view == 3:
        for x in xs:
            bar(d, (x, 78), (x, 26))
        bar(d, (xs[0] - 4, 24), (xs[1] + 4, 24), 8)
    return im


def wheel():
    im, d = cell(52, 52)
    button(d, 26, 26, WHEEL_R)
    return im


def hand():
    im, d = cell(36, 36)
    ell(d, 18, 20, 12.5, 13.5, INK)
    ell(d, 28, 15, 7.5, 7.5, INK)
    ell(d, 18, 20, 8.5, 9.5, CREAM)
    ell(d, 27.5, 15.5, 4, 4, CREAM)
    line(d, [(12, 29), (24, 29)], BLANKET, 3)
    return im


def bundle():
    im, d = cell(64, 64)
    for col, g in ((INK, 4.5), (BLANKET, 0.0)):
        ell(d, 22, 17, 9 + g, 6 + g, col)      # 매듭 귀 둘
        ell(d, 42, 17, 9 + g, 6 + g, col)
        ell(d, 32, 41, 23 + g, 18 + g, col)
    ell(d, 32, 23, 7, 6, INK)
    ell(d, 32, 23, 3.8, 3, CREAM)
    for x, y in ((20, 41), (32, 48), (44, 41), (26, 34), (38, 34), (32, 40)):
        ell(d, x, y, 2.3, 2.3, CREAM)
    line(d, arc_pts(32, 41, 19, 14, 20, 110), (0xe2, 0xa8, 0x94, 255), 2.5)
    return im


def bowl():
    im, d = cell(64, 56)
    body = arc_pts(32, 30, 25, 20, 0, 180)
    poly(d, body, INK)
    line(d, body + [body[0]], INK, LINE * 2)
    ell(d, 32, 30, 25 + LINE, 8 + LINE, INK)
    poly(d, body, WOOD)
    line(d, arc_pts(32, 30, 19, 14, 30, 150), WOOD_D, 2.4)
    ell(d, 32, 30, 25, 8, WOOD_L)
    ell(d, 32, 30, 20, 5.5, INK)
    ell(d, 32, 31, 18.5, 4.5, SOUP)
    for x0 in (25, 38):                 # 김
        pts = [(x0 + 3 * math.sin(t * 2.2), 20 - t * 5.5) for t in [i / 6.0 for i in range(0, 19)]]
        line(d, pts, CREAM, 3)
    return im


def rod():
    """풀줄기 낚싯대: 손은 왼쪽 아래 (10, 70), 끝은 오른쪽 위 (118, 12)"""
    im, d = cell(128, 80)
    pts = [(10 + 108 * t, 70 - 58 * t - 9 * math.sin(t * math.pi)) for t in [i / 20.0 for i in range(21)]]
    line(d, pts, INK, 11.5)
    line(d, pts, GRASS, 6.5)
    line(d, pts[2:12], GRASS_D, 2.2)
    lx, ly = pts[9]
    leaf = [(lx, ly), (lx + 13, ly - 13)]
    line(d, leaf, INK, 9.5)
    line(d, leaf, GRASS, 5)
    ell(d, 118, 12, 7.5, 6, INK)
    ell(d, 118, 12, 4.5, 3.2, SEED)
    return im


def fline():
    im, d = cell(16, 76)
    line(d, [(8, 2), (8, 62)], INK, 3.6)
    ell(d, 8, 66, 6.5, 7.5, INK)
    ell(d, 8, 66, 3.6, 4.6, FLOAT)
    return im


def fish():
    im, d = cell(48, 60)
    line(d, [(24, 2), (24, 16)], INK, 2.6)
    tail = [(24, 44), (13, 57), (35, 57)]
    poly(d, tail, INK)
    line(d, tail + [tail[0]], INK, 6)
    ell(d, 24, 31, 13.5, 18.5, INK)
    poly(d, [(24, 46), (16, 55), (32, 55)], FISH)
    ell(d, 24, 31, 9.5, 14.5, FISH)
    ell(d, 21, 27, 4, 8, FISH_L)
    ell(d, 27.5, 23, 2.3, 2.3, INK)
    return im


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.normpath(os.path.join(here, "..", "..", "art", "kids2d", "kids_outing.png"))
    sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    made = {"wheel": wheel(), "hand": hand(), "bundle": bundle(), "bowl": bowl(), "rod": rod(), "line": fline(), "fish": fish()}
    for v in (1, 2):
        made["p%d_back" % v] = side(v, False)
        made["p%d_front" % v] = side(v, True)
    for v in (0, 3):
        made["p%d_back" % v] = end(v, False)
        made["p%d_front" % v] = end(v, True)
    for name, (x, y, w, h) in PICS.items():
        sheet.paste(made[name].resize((w, h), Image.LANCZOS), (x, y))
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
    final.save(out)
    print(out)
    print("const ATLAS := Vector2i(%d, %d)" % (W, H))
    print("const PICS := {" + ", ".join('"%s": Rect2i(%d, %d, %d, %d)' % (k, *v) for k, v in PICS.items()) + "}")
    # 바퀴 자리: 그림 가운데에서 가로 · 그림 밑변에서 위 (화소) — 비스듬한 두 그림
    for v in (1, 2):
        row = []
        for wx, wy in NEAR:
            x, y = rot_pt(96 + wx, GROUND - WHEEL_R + wy, SIDE_TILT[v])
            row.append("Vector2(%.1f, %.1f)" % (x - 96, 144 - y))
        print("view %d wheels: [%s]" % (v, ", ".join(row)))
    print("rim: side %.1f end %.1f px above the picture bottom, wheel r %.1f" % (144 - SRIM[1], 144 - ERIM[1], WHEEL_R))


if __name__ == "__main__":
    main()
