#!/usr/bin/env python3
"""자람의 보상 장식 그림 (docs/PROGRESSION.md 4.5 — Q9 첫 묶음): 빵 간판 · 마을 이름 표지판.
Q9 ⑦ (2026-11-11): 문 앞 작은 바람개비 (첫걸음마) · 키 재는 기둥 (마을에서 난 첫 아이가 어른이 됨).
Q9 ⑭ (2026-11-11): 곳간 문 위 햇밀 다발 (첫 푸른 밀 고개를 넘김).
Q15 (2026-11-11): 잔치 소품 그림판 feast_props.png (잔칫상 · 등 · 손에 든 빵 · 손뼉 금 · 새 끈).

임시 그림 — 그림 서브에이전트(codex exec)의 정식 그림이 오기 전까지 쓰는, 같은 팔레트·같은 굵은 갈색 테두리의 손그림.
외부 그림을 쓰지 않는다 (도형만). 1칸 = 150점 (art/bld2d와 같은 촘촘함).

    python3 godot/tools/milestone_signs.py        →  godot/art/milestones/bread_sign.png · village_sign.png · pinwheel.png · height_post.png · wheat_sheaf.png
"""
import math
import os
import sys

from PIL import Image, ImageDraw

S = 4                                   # 크게 그려서 줄임 (가장자리 부드럽게)
LINE = "#563517"                        # 테두리 (art/bld2d/oven.png와 같은 갈색)
WOOD = "#b56933"
WOOD_L = "#d78544"
WOOD_D = "#925828"
BOARD = "#f3dcae"
BOARD_D = "#e2c388"
LOAF = "#e48a49"
LOAF_L = "#f6bd6e"
ROPE = "#cea579"
LEAF = "#b0a63c"
LEAF_L = "#c9b843"
LEAF_D = "#8a832e"
STONE = "#cea579"
ROOF = "#e4704a"
PETAL = "#fff6ea"
HEART = "#f0b33c"
WHEAT = "#efc04f"                       # 햇밀 이삭 (빵 속살 LOAF_L보다 노랗게)
WHEAT_L = "#fae08c"
STRAW = "#dba648"                       # 밀짚 줄기
OW = 5                                  # 테두리 굵기 (줄인 뒤 점)


def canvas(w, h):
    im = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def box(d, x0, y0, x1, y1, fill, r=6, ow=OW):
    d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=fill, outline=LINE, width=ow * S)


def plain(d, x0, y0, x1, y1, fill, r=2):
    d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=fill)


def oval(d, x0, y0, x1, y1, fill, ow=OW):
    d.ellipse([x0 * S, y0 * S, x1 * S, y1 * S], fill=fill, outline=LINE if ow > 0 else None, width=ow * S)


def line(d, pts, col=LINE, w=OW):
    d.line([(x * S, y * S) for x, y in pts], fill=col, width=w * S, joint="curve")
    for x, y in (pts[0], pts[-1]):
        r = w * S / 2.0
        d.ellipse([x * S - r, y * S - r, x * S + r, y * S + r], fill=col)


def poly(d, pts, fill, ow=OW):
    p = [(x * S, y * S) for x, y in pts]
    d.polygon(p, fill=fill)
    if ow > 0:
        line(d, pts + [pts[0]], LINE, ow)


def tuft(d, cx, by, n=4, h=16, flower=False):
    """발치의 풀 (그림이 땅에 앉게) — 아래 끝이 그림 바닥 by"""
    for i in range(n):
        x = cx + (i - (n - 1) / 2.0) * 7
        tip = (x + (i - (n - 1) / 2.0) * 2.5, by - h + abs(i - (n - 1) / 2.0) * 3)
        poly(d, [(x - 4, by), tip, (x + 4, by)], LEAF if i % 2 == 0 else LEAF_L, 3)
    if flower:
        fx, fy = cx + n * 4.5, by - h * 0.7
        line(d, [(fx, by - 2), (fx, fy)], LEAF_D, 3)
        for k in range(5):
            import math
            a = k * math.tau / 5
            oval(d, fx + math.cos(a) * 4.5 - 3.6, fy + math.sin(a) * 4.5 - 3.6, fx + math.cos(a) * 4.5 + 3.6, fy + math.sin(a) * 4.5 + 3.6, PETAL, 0)
        oval(d, fx - 3, fy - 3, fx + 3, fy + 3, HEART, 0)


def finish(im, w, h, path):
    out = im.resize((w, h), Image.LANCZOS)
    out.save(path)
    print("wrote", path, out.size)


def bread_sign(path):
    """기둥 + 팔 + 줄에 걸린 나무판 (둥근 빵 그림)"""
    w, h = 132, 180
    im, d = canvas(w, h)
    # 기둥
    box(d, 20, 12, 38, h - 4, WOOD, 6)
    plain(d, 24, 18, 28, h - 12, WOOD_L)
    # 팔 + 버팀목
    box(d, 12, 20, 126, 36, WOOD, 6)
    plain(d, 18, 24, 118, 27, WOOD_L)
    line(d, [(38, 64), (62, 38)], LINE, 9)
    line(d, [(38, 64), (62, 38)], WOOD_D, 4)
    # 줄
    for x in (62, 112):
        line(d, [(x, 36), (x, 62)], LINE, 6)
        line(d, [(x, 37), (x, 61)], ROPE, 2)
    # 판
    box(d, 46, 58, 128, 128, BOARD, 12)
    plain(d, 52, 116, 122, 121, BOARD_D)
    # 둥근 빵
    oval(d, 56, 70, 118, 116, LOAF)
    d.pieslice([60 * S, 73 * S, 114 * S, 110 * S], 185, 355, fill=LOAF_L)
    oval(d, 60, 84, 114, 114, LOAF, 0)
    for k in range(3):
        x = 74 + k * 13
        line(d, [(x - 4, 78), (x + 4, 92)], WOOD_D, 4)
    # 발치
    oval(d, 34, h - 16, 54, h - 2, STONE, 4)
    tuft(d, 14, h - 1, 3, 15)
    tuft(d, 46, h - 1, 3, 12)
    finish(im, w, h, path)


def village_sign(path):
    """두 기둥 + 넓은 판 (작은 집 그림 + 글씨 줄) + 잎 지붕"""
    w, h = 180, 172
    im, d = canvas(w, h)
    # 기둥
    for x in (34, 146):
        box(d, x - 9, 40, x + 9, h - 4, WOOD, 6)
        plain(d, x - 5, 46, x - 1, h - 12, WOOD_L)
    # 판
    box(d, 10, 44, 170, 110, BOARD, 10)
    plain(d, 18, 99, 162, 103, BOARD_D)
    # 작은 집
    poly(d, [(26, 72), (48, 54), (70, 72)], ROOF, 4)
    box(d, 32, 71, 64, 96, BOARD_D, 3, 4)
    plain(d, 44, 80, 52, 94, WOOD_D, 2)
    # 글씨 줄 (이름 — 읽히지 않아도 글씨로 보이게)
    line(d, [(84, 66), (150, 66)], LINE, 7)
    line(d, [(84, 84), (132, 84)], WOOD_D, 6)
    # 잎 지붕 (화덕의 잎 지붕과 같은 풀빛)
    poly(d, [(4, 44), (36, 20), (90, 10), (144, 20), (176, 44), (150, 40), (90, 34), (30, 40)], LEAF, 5)
    line(d, [(40, 30), (90, 22), (140, 30)], LEAF_L, 4)
    line(d, [(90, 12), (90, 34)], LEAF_D, 3)
    # 발치
    tuft(d, 18, h - 1, 3, 15)
    tuft(d, 52, h - 1, 3, 12, True)
    tuft(d, 128, h - 1, 3, 13)
    tuft(d, 162, h - 1, 3, 15, True)
    finish(im, w, h, path)


PINWHEEL_FRAMES = 6                     # view/milestone_view.gd FRAMES와 같게


def pinwheel(path):
    """가는 막대 + 날개 넷 (두 빛깔이 번갈아) — 문 앞에 꽂은 작은 바람개비. 어른 허리께 높이.
    옆으로 이어 붙인 여섯 장면 (날개가 반 바퀴 — 빛깔이 번갈아라 반 바퀴가 한 주기): 화면이 차례로 넘겨 돌아가게 한다"""
    w, h = 84, 132
    sheet = Image.new("RGBA", (w * PINWHEEL_FRAMES, h), (0, 0, 0, 0))
    for f in range(PINWHEEL_FRAMES):
        sheet.alpha_composite(_pinwheel_frame(w, h, f * math.pi / PINWHEEL_FRAMES), (w * f, 0))
    sheet.save(path)
    print("wrote", path, sheet.size)


def _pinwheel_frame(w, h, turn):
    im, d = canvas(w, h)
    cx, cy = 42, 42
    # 막대
    box(d, cx - 5, cy, cx + 5, h - 4, WOOD, 4, 4)
    plain(d, cx - 2, cy + 8, cx, h - 12, WOOD_L)
    # 날개 넷: 가운데에서 뻗은 끝 + 접어 온 모서리 (돌아가는 모양)
    cols = [ROOF, HEART, ROOF, HEART]
    for k in range(4):
        a = k * math.tau / 4 - 0.5 + turn
        tip = (cx + math.cos(a) * 34, cy + math.sin(a) * 34)
        fold = (cx + math.cos(a + 1.0) * 22, cy + math.sin(a + 1.0) * 22)
        back = (cx + math.cos(a + 0.45) * 13, cy + math.sin(a + 0.45) * 13)
        poly(d, [(cx, cy), tip, fold], cols[k], 4)
        line(d, [(cx, cy), back], PETAL, 3)
    oval(d, cx - 6, cy - 6, cx + 6, cy + 6, PETAL, 4)
    # 발치
    tuft(d, cx - 12, h - 1, 3, 13)
    tuft(d, cx + 12, h - 1, 3, 11, True)
    return im.resize((w, h), Image.LANCZOS)


def height_post(path):
    """굵은 나무 기둥 + 옆에 새긴 눈금 (아이들 키) + 눈금마다 묶은 작은 끈 — 모닥불 곁. 어른보다 조금 큼"""
    w, h = 96, 186
    im, d = canvas(w, h)
    px = 44
    # 기둥 (둥근 머리)
    box(d, px - 13, 10, px + 13, h - 4, WOOD, 11)
    plain(d, px - 8, 20, px - 4, h - 14, WOOD_L)
    plain(d, px + 6, 26, px + 9, h - 14, WOOD_D)
    # 눈금: 아래에서 위로 (아기 → 아이 → 어른) — 기둥 오른쪽으로 삐죽 나온 새김 + 이름 대신 빛깔 끈
    marks = [(150, HEART), (126, PETAL), (100, ROOF), (72, HEART), (42, ROOF)]
    for i, (y, col) in enumerate(marks):
        ln = 20 if i % 2 == 0 else 15
        line(d, [(px - 13, y), (px + 13, y)], LINE, 4)
        line(d, [(px + 13, y), (px + 13 + ln, y)], LINE, 7)
        line(d, [(px + 14, y), (px + 12 + ln, y)], BOARD, 3)
        oval(d, px + 10 + ln, y - 6, px + 22 + ln, y + 6, col, 3)
    # 맨 위 눈금 곁의 작은 잎 (다 자랐다)
    poly(d, [(px - 13, 40), (px - 34, 26), (px - 28, 46)], LEAF, 4)
    line(d, [(px - 14, 40), (px - 28, 34)], LEAF_D, 2)
    # 발치
    oval(d, px - 26, h - 15, px - 8, h - 2, STONE, 4)
    tuft(d, px + 20, h - 1, 3, 14, True)
    tuft(d, px - 27, h - 1, 3, 12)
    finish(im, w, h, path)


def _ear(d, x, y, ang, ln=27.0, wd=7.5):
    """이삭 하나: (x, y)에서 ang 쪽(라디안, 위 = -pi/2)으로 뻗은 길쭉한 알 + 끝의 수염 + 낟알 금"""
    ux, uy = math.cos(ang), math.sin(ang)
    vx, vy = -uy, ux
    pts = []
    for i in range(14):
        t = i * math.tau / 14
        a, b = math.cos(t) * ln / 2.0 + ln / 2.0, math.sin(t) * wd
        pts.append((x + ux * a + vx * b, y + uy * a + vy * b))
    tip = (x + ux * ln, y + uy * ln)
    for k in (-0.32, 0.0, 0.32):
        line(d, [tip, (tip[0] + math.cos(ang + k) * 10, tip[1] + math.sin(ang + k) * 10)], LINE, 2)
    poly(d, pts, WHEAT, 4)
    for f in (0.3, 0.52, 0.74):
        cx, cy = x + ux * ln * f, y + uy * ln * f
        line(d, [(cx - vx * wd * 0.55, cy - vy * wd * 0.55), (cx + ux * 3.5, cy + uy * 3.5), (cx + vx * wd * 0.55, cy + vy * wd * 0.55)], STRAW, 2)
    line(d, [(x + ux * ln * 0.2 - vx * wd * 0.35, y + uy * ln * 0.2 - vy * wd * 0.35), (x + ux * ln * 0.75 - vx * wd * 0.35, y + uy * ln * 0.75 - vy * wd * 0.35)], WHEAT_L, 2)


def wheat_sheaf(path):
    """갓 거둔 햇밀 한 다발 — 가운데를 붉은 끈으로 묶고 이삭을 부채처럼 펴서 곳간 문 위에 건다. 걸이 끈 + 작은 나무못.
    발치 풀 없음 (땅에 서는 것이 아니라 벽에 걸린다)"""
    w, h = 108, 120
    im, d = canvas(w, h)
    cx, ty = 54, 74                     # 묶은 자리
    # 나무못 + 걸이 끈
    line(d, [(cx, 9), (cx, ty - 6)], LINE, 5)
    line(d, [(cx, 10), (cx, ty - 6)], ROPE, 2)
    oval(d, cx - 6, 3, cx + 6, 15, WOOD, 3)
    # 밑동 (잘린 짚 — 아래로 벌어짐)
    poly(d, [(cx - 9, ty), (cx + 9, ty), (cx + 24, h - 6), (cx + 8, h - 3), (cx - 8, h - 3), (cx - 24, h - 6)], STRAW, 4)
    for dx in (-13, -5, 4, 12):
        line(d, [(cx + dx * 0.4, ty + 8), (cx + dx, h - 8)], WHEAT_L if dx in (-5, 12) else WOOD_D, 2)
    # 줄기 + 이삭 (부채꼴 일곱 — 바깥 것부터 그려 가운데가 위에)
    fan = [-1.02, 1.02, -0.68, 0.68, -0.34, 0.34, 0.0]
    for a in fan:
        ang = -math.pi / 2 + a
        ln = 26 + (1.0 - abs(a)) * 6
        ex, ey = cx + math.cos(ang) * ln, ty - 4 + math.sin(ang) * ln
        line(d, [(cx + a * 5, ty - 2), (ex, ey)], LINE, 6)
        line(d, [(cx + a * 5, ty - 2), (ex, ey)], STRAW, 3)
    for a in fan:
        ang = -math.pi / 2 + a
        ln = 26 + (1.0 - abs(a)) * 6
        _ear(d, cx + math.cos(ang) * ln, ty - 4 + math.sin(ang) * ln, ang + a * 0.25, 27 - abs(a) * 3)
    # 묶은 끈 (붉은 띠 + 매듭 꼬리)
    poly(d, [(cx + 6, ty + 3), (cx + 22, ty + 16), (cx + 12, ty + 19)], ROOF, 3)
    poly(d, [(cx - 6, ty + 3), (cx - 20, ty + 17), (cx - 10, ty + 19)], ROOF, 3)
    box(d, cx - 13, ty - 7, cx + 13, ty + 7, ROOF, 5, 4)
    plain(d, cx - 8, ty - 3, cx + 4, ty - 1, PETAL)
    finish(im, w, h, path)


# ───────────────────────── Q15 잔치 소품 (그림판 한 장) ─────────────────────────
FEAST_ATLAS = (512, 160)                # view/milestone_view.gd FX_ATLAS · FX_PICS와 같게 (칸: x, y, 너비, 높이 — 점)
FEAST_CELLS = {"spread": (2, 2, 258, 108), "lantern": (264, 2, 60, 156), "loaf": (328, 2, 48, 40),
               "clap": (380, 2, 54, 54), "ribbon": (438, 2, 54, 46)}


def _bun(d, x0, y0, x1, y1, slashes=3, ow=OW):
    """둥근 빵 하나 (빵 간판의 빵과 같은 빛깔): 윗면 밝게 + 칼집"""
    oval(d, x0, y0, x1, y1, LOAF, ow)
    m = ow * 0.8
    d.pieslice([(x0 + m) * S, (y0 + m) * S, (x1 - m) * S, (y1 - m - (y1 - y0) * 0.12) * S], 185, 355, fill=LOAF_L)
    oval(d, x0 + m, y0 + (y1 - y0) * 0.36, x1 - m, y1 - m, LOAF, 0)
    for k in range(slashes):
        x = x0 + (x1 - x0) * (0.32 + 0.18 * k)
        line(d, [(x - 2.5, y0 + (y1 - y0) * 0.2), (x + 2.5, y0 + (y1 - y0) * 0.46)], WOOD_D, max(2, ow - 2))


def _spread():
    """잔칫상: 통나무 다리 둘에 얹은 긴 널 + 흰 보 + 둥근 빵 셋 + 열매 그릇 + 물병. 모닥불 곁 (잔치 동안만)"""
    w, h = 258, 108
    im, d = canvas(w, h)
    # 다리 (통나무 토막)
    for x in (44, 214):
        box(d, x - 13, 66, x + 13, h - 5, WOOD_D, 5, 4)
        plain(d, x - 8, 72, x - 5, h - 11, WOOD)
    # 널
    box(d, 6, 54, w - 6, 74, WOOD, 6)
    plain(d, 14, 58, w - 14, 61, WOOD_L)
    # 보 (앞으로 드리운 자락 + 붉은 단)
    poly(d, [(62, 56), (196, 56), (190, 90), (179, 82), (168, 90), (157, 82), (146, 90), (135, 82), (124, 90), (113, 82), (102, 90), (91, 82), (80, 90), (68, 84)], PETAL, 4)
    line(d, [(70, 66), (188, 66)], ROOF, 3)
    box(d, 54, 49, 204, 61, PETAL, 5, 4)
    # 열매 그릇 (왼쪽)
    for bx, by in ((24, 37), (33, 33), (42, 37), (29, 42), (38, 42)):
        oval(d, bx - 6, by - 6, bx + 6, by + 6, ROOF, 3)
    poly(d, [(12, 40), (54, 40), (47, 55), (19, 55)], BOARD_D, 4)
    # 빵 셋 (가운데가 크다)
    _bun(d, 66, 24, 110, 55)
    _bun(d, 146, 25, 188, 55)
    _bun(d, 102, 14, 154, 54)
    # 물병 (오른쪽)
    line(d, [(236, 30), (246, 32), (246, 42), (236, 46)], LINE, 5)
    box(d, 214, 20, 238, 55, STONE, 9, 4)
    box(d, 218, 12, 234, 24, STONE, 4, 4)
    plain(d, 219, 28, 222, 48, BOARD)
    # 발치
    tuft(d, 14, h - 1, 3, 13)
    tuft(d, 128, h - 1, 3, 11, True)
    tuft(d, 244, h - 1, 3, 13)
    return im.resize((w, h), Image.LANCZOS)


def _lantern():
    """막대에 건 작은 등: 굽은 나무 팔 + 줄 + 둥근 등 (붉은 갓 · 밝은 속) + 술. 잔칫상 양옆 (잔치 동안만)"""
    w, h = 60, 156
    im, d = canvas(w, h)
    px = 16
    # 막대 + 굽은 팔
    line(d, [(px, 34), (px, 12), (40, 12)], LINE, 11)
    line(d, [(px, 34), (px, 12), (40, 12)], WOOD, 5)
    box(d, px - 5, 26, px + 5, h - 4, WOOD, 4, 4)
    plain(d, px - 2, 34, px, h - 12, WOOD_L)
    # 줄
    line(d, [(40, 12), (40, 26)], LINE, 4)
    # 등
    oval(d, 24, 28, 56, 70, WHEAT_L, 4)
    oval(d, 31, 36, 49, 60, PETAL, 0)
    for x in (33, 47):
        d.arc([(x - 9 if x < 40 else x - 5) * S, 30 * S, (x + 5 if x < 40 else x + 9) * S, 68 * S], 100 if x < 40 else 280, 260 if x < 40 else 80, fill=HEART, width=2 * S)
    box(d, 31, 23, 49, 32, ROOF, 3, 3)
    box(d, 33, 66, 47, 74, ROOF, 3, 3)
    line(d, [(40, 74), (40, 86)], ROOF, 3)
    # 발치
    oval(d, px + 4, h - 13, px + 18, h - 2, STONE, 3)
    tuft(d, px - 9, h - 1, 3, 11)
    return im.resize((w, h), Image.LANCZOS)


def _loaf():
    """손에 든 빵 한 덩이 (한 입 베어 문 자국) — 잔치에서 먹는 사람의 입가에"""
    w, h = 48, 40
    im, d = canvas(w, h)
    _bun(d, 3, 6, 45, 38, 2, 4)
    d.ellipse([31 * S, 0 * S, 51 * S, 19 * S], fill=(0, 0, 0, 0))           # 베어 문 자리
    d.arc([31 * S, 0 * S, 51 * S, 19 * S], 95, 215, fill=LINE, width=4 * S)
    return im.resize((w, h), Image.LANCZOS)


def _clap():
    """손뼉 '짝' — 사방으로 튀는 짧은 금 여섯 + 가운데 작은 별"""
    w, h = 54, 54
    im, d = canvas(w, h)
    cx, cy = 27, 27
    for k in range(6):
        a = k * math.tau / 6 - math.pi / 2
        r0, r1 = (11, 23) if k % 2 == 0 else (12, 20)
        p0 = (cx + math.cos(a) * r0, cy + math.sin(a) * r0)
        p1 = (cx + math.cos(a) * r1, cy + math.sin(a) * r1)
        line(d, [p0, p1], LINE, 8)
        line(d, [p0, p1], HEART if k % 2 == 0 else PETAL, 4)
    pts = []
    for i in range(8):
        a = i * math.tau / 8 - math.pi / 2
        r = 8 if i % 2 == 0 else 3.6
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    poly(d, pts, PETAL, 3)
    return im.resize((w, h), Image.LANCZOS)


def _ribbon():
    """새로 묶은 붉은 끈 (나비매듭) — 키 재는 기둥의 새 눈금"""
    w, h = 54, 46
    im, d = canvas(w, h)
    cx, cy = 27, 18
    poly(d, [(cx - 3, cy + 4), (cx - 15, cy + 25), (cx - 5, cy + 22)], ROOF, 3)
    poly(d, [(cx + 3, cy + 4), (cx + 15, cy + 25), (cx + 5, cy + 22)], ROOF, 3)
    poly(d, [(cx, cy), (cx - 23, cy - 13), (cx - 23, cy + 12)], ROOF, 4)
    poly(d, [(cx, cy), (cx + 23, cy - 13), (cx + 23, cy + 12)], ROOF, 4)
    line(d, [(cx - 17, cy - 4), (cx - 9, cy - 1)], PETAL, 3)
    line(d, [(cx + 17, cy - 4), (cx + 9, cy - 1)], PETAL, 3)
    box(d, cx - 7, cy - 7, cx + 7, cy + 7, HEART, 4, 4)
    return im.resize((w, h), Image.LANCZOS)


def feast_props(path):
    """잔치 소품 그림판 (Q15): 잔칫상 · 등 · 손에 든 빵 · 손뼉 금 · 새 끈 — 칸 자리는 FEAST_CELLS"""
    sheet = Image.new("RGBA", FEAST_ATLAS, (0, 0, 0, 0))
    for name, fn in (("spread", _spread), ("lantern", _lantern), ("loaf", _loaf), ("clap", _clap), ("ribbon", _ribbon)):
        x, y, w, h = FEAST_CELLS[name]
        im = fn()
        assert im.size == (w, h), (name, im.size)
        sheet.alpha_composite(im, (x, y))
    sheet.save(path)
    print("wrote", path, sheet.size)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "art", "milestones")
    os.makedirs(out, exist_ok=True)
    bread_sign(os.path.join(out, "bread_sign.png"))
    village_sign(os.path.join(out, "village_sign.png"))
    pinwheel(os.path.join(out, "pinwheel.png"))
    height_post(os.path.join(out, "height_post.png"))
    wheat_sheaf(os.path.join(out, "wheat_sheaf.png"))
    feast_props(os.path.join(out, "feast_props.png"))
