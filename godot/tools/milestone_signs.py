#!/usr/bin/env python3
"""자람의 보상 장식 그림 (docs/PROGRESSION.md 4.5 — Q9 첫 묶음): 빵 간판 · 마을 이름 표지판.
Q9 ⑦ (2026-11-11): 문 앞 작은 바람개비 (첫걸음마) · 키 재는 기둥 (마을에서 난 첫 아이가 어른이 됨).

임시 그림 — 그림 서브에이전트(codex exec)의 정식 그림이 오기 전까지 쓰는, 같은 팔레트·같은 굵은 갈색 테두리의 손그림.
외부 그림을 쓰지 않는다 (도형만). 1칸 = 150점 (art/bld2d와 같은 촘촘함).

    python3 godot/tools/milestone_signs.py        →  godot/art/milestones/bread_sign.png · village_sign.png · pinwheel.png · height_post.png
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


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "art", "milestones")
    os.makedirs(out, exist_ok=True)
    bread_sign(os.path.join(out, "bread_sign.png"))
    village_sign(os.path.join(out, "village_sign.png"))
    pinwheel(os.path.join(out, "pinwheel.png"))
    height_post(os.path.join(out, "height_post.png"))
