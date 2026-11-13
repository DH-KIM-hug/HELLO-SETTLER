#!/usr/bin/env python3
"""거인의 기념품 그림판 (docs/ROADMAP.md Q17 — sim/souvenirs.gd · view/souvenir_view.gd · view/room/giant_room.gd).

고비마다 하나씩 일곱 가지 기념품 + '더' 바구니 + 어귀의 납작한 돌(넓은 것·좁은 것) + 반짝임 별을 그림판 한 장에.
tools/milestone_signs.py와 같은 팔레트·같은 굵은 갈색 테두리의 손그림 (도형만 — 외부 그림을 쓰지 않는다).
아주 작게 보이는 그림이라 (병 안에서 24~40점) 덩어리를 크게, 테두리를 굵게, 밝은 점 하나씩.

칸 = 192점. 4칸 × 5줄 (768 × 960 — Q27에서 넷째 줄 · Q31에서 다섯째 줄) — 자리는 view/souvenir_view.gd PICS와 같게:
    첫 빵 한 조각 · 아기 발도장 잎 · 꽃목걸이 · 눈금 새긴 나뭇가지
    햇밀 이삭 하나 · 작은 등 · 마른 꽃다발 · '더' 바구니
    납작한 돌 (넓은 것 — 두 칸) · 납작한 돌 (좁은 것) · 반짝임 별
    (Q27) 세 가닥 땋은 끈 · 작은 나무 망치 · 새 집 문패 · 말린 열매 꾸러미
    (Q31) 말린 벚꽃 한 가지 (첫 이름 부르기) — 앞 네 줄은 그대로

    python3 godot/tools/souvenir_pics.py   →  godot/art/milestones/souvenirs.png
"""
import math
import os

from PIL import Image, ImageDraw

S = 4                                   # 크게 그려서 줄임
C = 192                                 # 한 칸
LINE = "#563517"
WOOD = "#b56933"
WOOD_L = "#d78544"
WOOD_D = "#925828"
BOARD = "#f3dcae"
BOARD_D = "#e2c388"
LOAF = "#e48a49"
LOAF_L = "#f6bd6e"
CRUMB = "#fdebbf"
CRUMB_D = "#f1cf8f"
ROPE = "#cea579"
LEAF = "#b0a63c"
LEAF_L = "#c9b843"
LEAF_D = "#8a832e"
PETAL = "#fff6ea"
HEART = "#f0b33c"
PINK = "#f6b3a8"
WHEAT = "#efc04f"
WHEAT_L = "#fae08c"
STRAW = "#dba648"
GLASS = "#ffe9a6"
FLAME = "#f59a3c"
ROSE = "#dfa093"                        # 마른 꽃 (바랜 빛)
LILAC = "#c3add6"
DRY = "#e9d28f"
STEM = "#a2954f"
ROCK = "#cbc1b0"                        # 납작한 돌 윗면 · 옆면 · 밝은 줄
ROCK_D = "#a2978a"
ROCK_L = "#e6dfd0"
WHITE = "#fffdf2"
OW = 8                                  # 테두리 굵기 (줄인 뒤 점 — 작게 보여도 남게 굵게)


def canvas(w=C, h=C):
    im = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def sc(pts):
    return [(x * S, y * S) for x, y in pts]


def oval(d, x0, y0, x1, y1, fill, ow=OW):
    if ow > 0:
        d.ellipse([(x0 - ow / 2) * S, (y0 - ow / 2) * S, (x1 + ow / 2) * S, (y1 + ow / 2) * S], fill=LINE)
    d.ellipse([x0 * S, y0 * S, x1 * S, y1 * S], fill=fill)


def dot(d, x, y, r, fill, ow=0):
    oval(d, x - r, y - r, x + r, y + r, fill, ow)


def line(d, pts, col=LINE, w=OW):
    d.line(sc(pts), fill=col, width=int(w * S), joint="curve")
    r = w * S / 2.0
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x * S - r, y * S - r, x * S + r, y * S + r], fill=col)


def stroke(d, pts, col, w, ow=OW):
    """테두리 있는 굵은 줄"""
    line(d, pts, LINE, w + ow)
    line(d, pts, col, w)


def poly(d, pts, fill, ow=OW):
    if ow > 0:
        line(d, pts + [pts[0], pts[1]], LINE, ow)
    d.polygon(sc(pts), fill=fill)


def bez(p0, p1, p2, n=14):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(((1 - t) ** 2 * p0[0] + 2 * t * (1 - t) * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * t * (1 - t) * p1[1] + t * t * p2[1]))
    return out


def arch(cx, cy, rx, ry, base, n=24, inset=8):
    """빵 조각 모양: 위는 둥글고 아래는 납작"""
    pts = [(cx + rx * math.cos(math.pi - i * math.pi / n), cy - ry * math.sin(math.pi - i * math.pi / n)) for i in range(n + 1)]
    return pts + [(cx + rx, base - inset), (cx + rx - inset, base), (cx - rx + inset, base), (cx - rx, base - inset)]


def flower(d, x, y, r, col, heart=HEART, n=5, turn=0.0):
    for k in range(n):
        a = turn + k * math.tau / n
        dot(d, x + math.cos(a) * r, y + math.sin(a) * r, r * 0.86, LINE)
    dot(d, x, y, r * 0.9, LINE)
    for k in range(n):
        a = turn + k * math.tau / n
        dot(d, x + math.cos(a) * r, y + math.sin(a) * r, r * 0.86 - 3.2, col)
    dot(d, x, y, r * 0.62, heart)


def tuft(d, cx, by, n=3, h=18):
    for i in range(n):
        x = cx + (i - (n - 1) / 2.0) * 9
        tip = (x + (i - (n - 1) / 2.0) * 3.0, by - h + abs(i - (n - 1) / 2.0) * 4)
        poly(d, [(x - 5, by), tip, (x + 5, by)], LEAF if i % 2 == 0 else LEAF_L, 4)


# ───────────────────────── 기념품 일곱 ─────────────────────────
def bread():
    """첫 빵 한 조각 — 둥근 빵을 썬 한 쪽 (껍질 + 속살 + 숨구멍)"""
    im, d = canvas()
    poly(d, arch(96, 104, 66, 66, 160), LOAF)
    d.polygon(sc(arch(96, 108, 49, 49, 147, inset=5)), fill=CRUMB)
    for x, y, r in ((78, 96, 7), (112, 86, 5.5), (104, 122, 7.5), (76, 128, 4.5), (124, 114, 4)):
        dot(d, x, y, r, CRUMB_D)
    line(d, bez((44, 92), (52, 56), (86, 46)), LOAF_L, 7)          # 껍질의 밝은 줄
    dot(d, 58, 70, 5.5, WHITE)
    return im


def steps():
    """아기 발도장 잎 — 넓은 잎에 찍힌 작은 발도장"""
    im, d = canvas()
    stroke(d, [(96, 150), (100, 184)], LEAF_D, 7)                 # 잎자루
    left = bez((96, 168), (-24, 124), (96, 14), 20)
    right = bez((96, 14), (216, 124), (96, 168), 20)
    poly(d, left + right[1:-1], LEAF_L)
    d.polygon(sc(bez((96, 163), (192, 122), (97, 22), 20) + [(96, 163)]), fill=LEAF)     # 오른쪽 반은 한 톤 짙게
    line(d, [(96, 30), (96, 160)], LEAF_D, 4)
    oval(d, 78, 100, 112, 146, PETAL, 0)                          # 발바닥 (뒤꿈치)
    oval(d, 72, 76, 120, 118, PETAL, 0)                           # 발볼
    for i, (x, y, r) in enumerate(((66, 66, 9), (82, 54, 8), (98, 50, 7.5), (113, 54, 7), (126, 64, 6.5))):
        dot(d, x, y, r, PETAL)
    dot(d, 50, 104, 5, WHITE)
    return im


def necklace():
    """꽃목걸이 — 끈에 꿴 들꽃 둥근 고리"""
    im, d = canvas()
    ring = [(96 + 56 * math.cos(i * math.tau / 40), 100 + 60 * math.sin(i * math.tau / 40)) for i in range(41)]
    line(d, ring, LINE, 11)
    line(d, ring, LEAF, 5)
    n = 8
    for k in range(n):
        a = -math.pi / 2 + (k + 0.5) * math.tau / n
        dot(d, 96 + 56 * math.cos(a), 100 + 60 * math.sin(a), 8, LEAF_L, 5)
    for k in range(n):
        a = -math.pi / 2 + k * math.tau / n
        flower(d, 96 + 56 * math.cos(a), 100 + 60 * math.sin(a), 13.5, PETAL if k % 2 == 0 else PINK, turn=k * 0.5)
    dot(d, 88, 30, 3.5, WHITE)
    return im


def twig():
    """눈금 새긴 나뭇가지 — 아이 키를 새기던 가지 한 토막"""
    im, d = canvas()
    a, b = (58, 168), (126, 30)
    stroke(d, [(110, 72), (150, 56)], WOOD, 11)                    # 곁가지
    poly(d, bez((146, 58), (158, 26), (182, 30), 10) + bez((182, 30), (176, 60), (146, 58), 10)[1:-1], LEAF_L, 6)
    line(d, [(152, 54), (174, 36)], LEAF_D, 3)
    stroke(d, [a, b], WOOD, 32)
    ux, uy = (b[0] - a[0]), (b[1] - a[1])
    ln = math.hypot(ux, uy)
    ux, uy = ux / ln, uy / ln
    nx, ny = -uy, ux
    line(d, [(a[0] + ux * 10 - nx * 9, a[1] + uy * 10 - ny * 9), (b[0] - ux * 10 - nx * 9, b[1] - uy * 10 - ny * 9)], WOOD_L, 7)
    for t in (0.2, 0.4, 0.6, 0.8):                                 # 눈금
        cx, cy = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        line(d, [(cx - nx * 3, cy - ny * 3), (cx + nx * 14, cy + ny * 14)], LINE, 9)
        line(d, [(cx - nx * 2, cy - ny * 2), (cx + nx * 13, cy + ny * 13)], BOARD, 4.5)
    dot(d, b[0], b[1], 11, BOARD_D)                                # 잘린 끝 (나이테)
    dot(d, b[0], b[1], 4.5, WOOD_D)
    return im


def wheat():
    """햇밀 이삭 하나"""
    im, d = canvas()
    stroke(d, [(96, 184), (96, 112)], STRAW, 8)
    poly(d, bez((96, 160), (126, 150), (140, 122), 10) + bez((140, 122), (112, 132), (96, 160), 10)[1:-1], LEAF_L, 6)
    for k in range(5):                                             # 까끄라기
        y = 104 - k * 17
        for sx in (-1, 1):
            line(d, [(96 + sx * 20, y - 6), (96 + sx * 40, y - 34)], LINE, 5)
            line(d, [(96 + sx * 20, y - 6), (96 + sx * 39, y - 33)], WHEAT_L, 2)
    line(d, [(96, 34), (96, 8)], LINE, 5)
    line(d, [(96, 34), (96, 9)], WHEAT_L, 2)
    for k in range(5):                                             # 낟알 (아래에서 위로 — 좌우 한 쌍씩)
        y = 110 - k * 17
        for sx in (-1, 1):
            g = Image.new("RGBA", im.size, (0, 0, 0, 0))
            gd = ImageDraw.Draw(g)
            oval(gd, 96 - 10, y - 16, 96 + 10, y + 16, WHEAT if (k + (sx > 0)) % 2 == 0 else WHEAT_L, 7)
            g = g.rotate(-sx * 32, center=(96 * S, (y + 10) * S), resample=Image.BICUBIC)
            g2 = Image.new("RGBA", im.size, (0, 0, 0, 0))
            g2.paste(g, (int(sx * 12 * S), 0), g)
            im.alpha_composite(g2)
    d = ImageDraw.Draw(im)
    oval(d, 86, 20, 106, 54, WHEAT_L, 7)                           # 맨 위 낟알
    dot(d, 84, 80, 4, WHITE)
    return im.rotate(-10, center=(96 * S, 150 * S), resample=Image.BICUBIC)


def lamp():
    """작은 등 — 손에 드는 작은 등 (따뜻한 불빛)"""
    im, d = canvas()
    arc = [(96 + 30 * math.cos(math.pi + i * math.pi / 16), 54 + 34 * math.sin(math.pi + i * math.pi / 16)) for i in range(17)]
    line(d, arc, LINE, 11)                                         # 손잡이
    line(d, arc, WOOD_L, 4.5)
    poly(d, [(58, 74), (72, 48), (120, 48), (134, 74)], WOOD)      # 지붕
    line(d, [(74, 58), (116, 58)], WOOD_L, 5)
    d.rounded_rectangle([58 * S, 70 * S, 134 * S, 156 * S], radius=14 * S, fill=LINE)
    d.rounded_rectangle([66 * S, 76 * S, 126 * S, 150 * S], radius=9 * S, fill=GLASS)
    poly(d, bez((96, 92), (74, 126), (96, 138), 10) + bez((96, 138), (118, 126), (96, 92), 10)[1:-1], FLAME, 0)     # 불꽃
    poly(d, bez((96, 108), (86, 128), (96, 134), 8) + bez((96, 134), (106, 128), (96, 108), 8)[1:-1], WHEAT_L, 0)
    line(d, [(96, 76), (96, 90)], LINE, 4)
    d.rounded_rectangle([48 * S, 150 * S, 144 * S, 176 * S], radius=9 * S, fill=LINE)       # 받침
    d.rounded_rectangle([56 * S, 156 * S, 136 * S, 169 * S], radius=5 * S, fill=WOOD)
    line(d, [(62, 160), (112, 160)], WOOD_L, 4)
    dot(d, 76, 88, 4.5, WHITE)
    return im


def bouquet():
    """마른 꽃다발 — 겨울을 난 바랜 꽃 한 묶음"""
    im, d = canvas()
    tie = (96, 128)
    for x in (72, 86, 106, 120):                                   # 아래로 벌어진 줄기 끝
        stroke(d, [tie, (x, 178)], STEM, 6)
    heads = [((44, 62), ROSE), ((150, 66), LILAC), ((70, 36), DRY), ((124, 38), ROSE), ((96, 58), LILAC)]
    for (x, y), _col in heads:
        stroke(d, [tie, (x, y)], STEM, 5)
    for i, ((x, y), col) in enumerate(heads):
        flower(d, x, y, 14.5, col, heart=STRAW, n=6, turn=i * 0.4)
    for x, y in ((60, 96), (132, 98)):                             # 잎
        poly(d, bez((96, 124), (x, y - 18), (x - (96 - x) * 0.35, y), 8) + bez((x - (96 - x) * 0.35, y), (x, y + 14), (96, 124), 8)[1:-1], LEAF, 6)
    stroke(d, [(80, 128), (112, 128)], ROPE, 9)                    # 묶은 끈
    stroke(d, [(110, 128), (128, 142)], ROPE, 5)
    stroke(d, [(110, 128), (130, 120)], ROPE, 5)
    dot(d, 88, 50, 4, WHITE)
    return im


def sprig():
    """(Q31) 말린 벚꽃 한 가지 — 벚꽃잎이 지는 저녁, 처음 이름을 부르던 날 꺾어 말린 작은 가지 (흰 끈으로 묶음)"""
    im, d = canvas()
    stroke(d, [(48, 170), (96, 104), (150, 40)], WOOD_D, 13)        # 가지 (휘어 오름)
    stroke(d, [(96, 104), (140, 112)], WOOD_D, 8)                  # 곁가지
    stroke(d, [(118, 76), (98, 44)], WOOD_D, 7)
    line(d, [(56, 160), (92, 110)], WOOD, 4)
    for x, y, a in ((128, 70, -0.5), (162, 104, 0.9)):             # 잎 둘 (바랜 연두)
        tx, ty = x + math.cos(a) * 26, y + math.sin(a) * 26
        mx, my = (x + tx) / 2, (y + ty) / 2
        nx, ny = -math.sin(a) * 10, math.cos(a) * 10
        poly(d, bez((x, y), (mx + nx, my + ny), (tx, ty), 8) + bez((tx, ty), (mx - nx, my - ny), (x, y), 8)[1:-1], LEAF_L, 6)
    blossom = "#f9d3dc"
    for x, y, r, t in ((150, 36, 17, 0.3), (98, 42, 15, 1.1), (142, 116, 15, 0.7), (74, 118, 12, 0.2)):
        flower(d, x, y, r, blossom, heart=HEART, n=5, turn=t)
    for x, y in ((44, 70), (172, 160), (30, 128)):                 # 떨어지는 꽃잎 셋
        poly(d, bez((x, y - 9), (x + 11, y - 2), (x, y + 9), 6) + bez((x, y + 9), (x - 11, y - 2), (x, y - 9), 6)[1:-1], blossom, 5)
    stroke(d, [(64, 134), (82, 148)], WHITE, 8)                    # 흰 끈
    stroke(d, [(70, 142), (58, 166)], WHITE, 5)
    dot(d, 146, 30, 4, WHITE)
    return im


def more():
    """'더' — 작은 바구니에 담긴 나머지 (빵 꼭지 · 꽃 · 이삭이 삐죽)"""
    im, d = canvas()
    stroke(d, [(118, 96), (132, 50)], STRAW, 6)                    # 이삭
    oval(d, 122, 26, 142, 62, WHEAT, 7)
    oval(d, 44, 56, 104, 112, LOAF, OW)                            # 빵 꼭지
    line(d, bez((56, 78), (66, 62), (84, 62)), LOAF_L, 6)
    flower(d, 104, 78, 13, PETAL, turn=0.3)
    poly(d, [(30, 100), (162, 100), (146, 168), (46, 168)], BOARD_D)     # 바구니
    for y in (120, 138, 154):
        line(d, [(40 + (y - 100) * 0.2, y), (152 - (y - 100) * 0.2, y)], WOOD_L, 4)
    for x in (62, 96, 130):
        line(d, [(x, 108), (x + (96 - x) * 0.12, 164)], WOOD_D, 3.5)
    d.rounded_rectangle([22 * S, 90 * S, 170 * S, 112 * S], radius=10 * S, fill=LINE)
    d.rounded_rectangle([29 * S, 96 * S, 163 * S, 106 * S], radius=5 * S, fill=BOARD)
    return im


# ───────────────────────── (Q27) 4~7일차 고비의 기념품 ─────────────────────────
def braid():
    """세 가닥 땋은 끈 — 할머니 · 어머니 · 아이의 실을 한데 땋은 끈 (고리 + 술)"""
    im, d = canvas()
    cols = [ROSE, WHEAT_L, LEAF_L]
    pts = [(96 + 46 * math.cos(math.pi * 0.75 + i * math.tau * 0.8 / 48), 92 + 50 * math.sin(math.pi * 0.75 + i * math.tau * 0.8 / 48)) for i in range(49)]
    line(d, pts, LINE, 22)
    for k in range(48):                                            # 땋은 마디 — 세 빛깔이 번갈아
        a, b = pts[k], pts[k + 1]
        line(d, [a, b], cols[(k // 2) % 3], 13)
        if k % 2 == 0:
            mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            dot(d, mx, my, 2.2, LINE)
    kx, ky = 96, 150
    stroke(d, [pts[0], (kx - 4, ky)], cols[0], 10)
    stroke(d, [pts[-1], (kx + 4, ky)], cols[1], 10)
    dot(d, kx, ky, 11, ROPE, 6)
    for j, c in enumerate(cols):
        x = kx - 12 + j * 12
        stroke(d, [(kx, ky + 6), (x, 182)], c, 6, 5)
    dot(d, 64, 54, 4.5, WHITE)
    return im


def mallet():
    """작은 나무 망치 — 일터마다 손때 묻은 망치 하나 (손잡이에 감은 끈)"""
    im, d = canvas()
    a, b = (58, 166), (118, 76)
    stroke(d, [a, b], WOOD_L, 16)
    for t in (0.14, 0.24):                                         # 손잡이에 감은 끈
        cx, cy = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        line(d, [(cx - 10, cy - 5), (cx + 10, cy + 5)], LINE, 8)
        line(d, [(cx - 9, cy - 4.5), (cx + 9, cy + 4.5)], ROPE, 4)
    g = Image.new("RGBA", im.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    gd.rounded_rectangle([60 * S, 30 * S, 172 * S, 86 * S], radius=14 * S, fill=LINE)       # 망치 머리
    gd.rounded_rectangle([68 * S, 37 * S, 164 * S, 79 * S], radius=9 * S, fill=WOOD)
    gd.rounded_rectangle([68 * S, 37 * S, 82 * S, 79 * S], radius=6 * S, fill=WOOD_D)
    gd.rounded_rectangle([150 * S, 37 * S, 164 * S, 79 * S], radius=6 * S, fill=WOOD_D)
    line(gd, [(88, 46), (142, 46)], WOOD_L, 5)
    g = g.rotate(34, center=(116 * S, 58 * S), resample=Image.BICUBIC)
    im.alpha_composite(g)
    d = ImageDraw.Draw(im)
    dot(d, 108, 40, 4.5, WHITE)
    return im


def plaque():
    """새 집 문패 — 새 살림을 차린 집 문에 거는 작은 나무 판 (끈 + 꽃 한 송이)"""
    im, d = canvas()
    line(d, [(64, 70), (96, 26), (128, 70)], LINE, 8)              # 거는 끈
    line(d, [(64, 70), (96, 27), (128, 70)], ROPE, 3.5)
    dot(d, 96, 26, 7, WOOD_D, 5)
    d.rounded_rectangle([30 * S, 64 * S, 162 * S, 150 * S], radius=16 * S, fill=LINE)
    d.rounded_rectangle([38 * S, 71 * S, 154 * S, 143 * S], radius=11 * S, fill=WOOD_L)
    line(d, [(48, 82), (144, 82)], BOARD, 5)
    for y in (104, 124):                                           # 새긴 줄 (글이 아니라 무늬)
        line(d, [(58, y), (134, y)], WOOD_D, 5)
    flower(d, 146, 146, 13, PINK, turn=0.4)
    dot(d, 50, 90, 4.5, WHITE)
    return im


def pouch():
    """말린 열매 꾸러미 — 곳간을 채운 해에 묶은 작은 자루 (열매가 삐죽)"""
    im, d = canvas()
    for (x, y), c in (((80, 52), ROSE), ((104, 46), WHEAT), ((122, 58), LOAF)):
        dot(d, x, y, 15, c, 6)
    poly(d, bez((70, 74), (24, 110), (54, 168), 12) + [(138, 168)] + bez((138, 168), (168, 110), (122, 74), 12)[1:], BOARD_D)
    stroke(d, [(64, 84), (128, 84)], ROPE, 10)                    # 묶은 끈
    stroke(d, [(110, 84), (132, 104)], ROPE, 5)
    for x0, x1 in ((80, 72), (112, 120)):                        # 자루 주름
        line(d, [(x0, 96), (x1, 156)], WOOD_L, 4)
    dot(d, 74, 108, 4.5, WHITE)
    return im


# ───────────────────────── 납작한 돌 · 반짝임 ─────────────────────────
def stone(w):
    """어귀의 납작한 돌 — 윗면 가운데가 그림 바닥에서 38점쯤 (view/souvenir_view.gd STONE_TOP)"""
    im, d = canvas(w, C)
    x0, x1 = 16, w - 16
    d.rounded_rectangle([(x0 - 4) * S, 140 * S, (x1 + 4) * S, 188 * S], radius=24 * S, fill=LINE)
    d.rounded_rectangle([(x0 + 4) * S, 146 * S, (x1 - 4) * S, 181 * S], radius=18 * S, fill=ROCK_D)
    oval(d, x0, 118, x1, 172, ROCK)
    hi = [(x0 + 26 + i * (x1 - x0 - 52) / 12.0 * 0.5, 138 - math.sin(i / 12.0 * math.pi * 0.5) * 8) for i in range(13)]
    line(d, hi, ROCK_L, 5)
    for x in ((x0 + x1) * 0.5 + (x1 - x0) * 0.22, (x0 + x1) * 0.5 - (x1 - x0) * 0.1):
        line(d, [(x, 162), (x + 12, 164)], ROCK_D, 3)             # 작은 금
    tuft(d, x0 + 6, 190, 3, 20)
    tuft(d, x1 - 8, 190, 3, 16)
    return im


def spark():
    """반짝임 별 (테두리 없음 — 빛나는 판으로 그린다)"""
    im, d = canvas()

    def star(r_long, r_short, col, turn=0.0):
        pts = []
        for i in range(8):
            r = r_long if i % 2 == 0 else r_short
            a = turn + i * math.tau / 8 - math.pi / 2
            pts.append((96 + r * math.cos(a), 96 + r * math.sin(a)))
        d.polygon(sc(pts), fill=col)

    star(90, 24, "#ffe08a")
    star(50, 15, "#ffe08a", math.tau / 16)
    star(78, 15, "#fffbe8")
    star(40, 9, "#fffbe8", math.tau / 16)
    return im


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "art", "milestones", "souvenirs.png")
    sheet = Image.new("RGBA", (C * 4, C * 5), (0, 0, 0, 0))
    cells = [(bread(), 0, 0), (steps(), 1, 0), (necklace(), 2, 0), (twig(), 3, 0),
             (wheat(), 0, 1), (lamp(), 1, 1), (bouquet(), 2, 1), (more(), 3, 1),
             (stone(C * 2), 0, 2), (stone(C), 2, 2), (spark(), 3, 2),
             (braid(), 0, 3), (mallet(), 1, 3), (plaque(), 2, 3), (pouch(), 3, 3),
             (sprig(), 0, 4)]
    for im, cx, cy in cells:
        small = im.resize((im.size[0] // S, im.size[1] // S), Image.LANCZOS)
        sheet.alpha_composite(small, (cx * C, cy * C))
    sheet.save(out)
    print("wrote", os.path.normpath(out), sheet.size)


if __name__ == "__main__":
    main()
