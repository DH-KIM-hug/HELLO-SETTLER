"""Pose reference sheets for the method-C walk / carry cycles (2026-11-09 user: "한 발로만 걷는 것 같아요" — text alone could not
make the image model draw a proper two-leg cycle). Programmatic puppets in the exact frame-sheet layout (2x4 cells 384x512,
ground line y 470) with the chibi proportions, a classic 8-frame cycle and colour-coded legs:
  her RIGHT leg = tan stocking + brown shoe, her LEFT leg = CYAN stocking + NAVY shoe (3/4 views: right = near leg, left = far).
  frame 1 contact R (right heel forward) -> 2 down -> 3 passing (left swings, lifted) -> 4 up -> 5 contact L -> 6 down -> 7 passing -> 8 up.
  The planted foot moves backward at a constant speed (no sliding); the swinging foot lifts and reaches forward; arms opposite.
usage: python3 pose_ref.py   -> art/cutout/woman_c/raw/pose_<clip>_<view>.png  (+ feet() used by check_pose.py)"""
import math, os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "woman_c", "raw"))
CW, CH, GROUND = 384, 512, 470
VIEWS = ["front", "q_front", "q_back", "back"]
INK = (58, 42, 34)
TAN, BROWN = (232, 172, 112), (112, 66, 42)
CYAN, NAVY = (32, 168, 255), (32, 48, 112)
SKIN = (240, 170, 112)
DRESS = (200, 112, 106)
SACK, STRIPE = (217, 214, 205), (90, 127, 176)
HIP_Y, CHIN_Y, HEAD_R = 385, 212, 74     # v6 (2026-11-09 "아직도 긴데요"): long skirt to mid-shin, only short boots show
HEM_Y = 430                              # skirt hem: hem->sole = 40 px ~ 0.10 of the figure (old cutout 0.08-0.10)
GAIT = {"walk": dict(S=36.0, H=16.0, bob=6.0), "carry": dict(S=30.0, H=13.0, bob=5.0)}


def smooth(u):
    return u * u * (3 - 2 * u)


def leg_phase(p, S, H):
    """p 0..1 for one leg: stance [0, .5) planted foot from +S to -S at constant speed, swing [.5, 1) lift + reach"""
    p %= 1.0
    if p < 0.5:
        return S * (1 - 4 * p), 0.0
    u = (p - 0.5) * 2
    return -S + 2 * S * smooth(u), H * math.sin(math.pi * u)


def geometry(view):
    """forward vector on screen (unit = stride), lateral offsets of the right / left hip & foot (x, y), sack side"""
    if view == "front":       # walking toward the viewer: forward = down the screen (foreshortened)
        return dict(fwd=(0.0, 0.38), hip={"R": (-30, 0), "L": (30, 0)}, foot={"R": (-32, 0), "L": (32, 0)}, sack=-1, side=0)
    if view == "back":        # walking away: forward = up the screen; her right is on the image right
        return dict(fwd=(0.0, -0.38), hip={"R": (30, 0), "L": (-30, 0)}, foot={"R": (32, 0), "L": (-32, 0)}, sack=1, side=0)
    if view == "q_front":     # walking toward the lower right; right leg = near (lower on the image)
        # v7 (2026-11-09 "사선 내려오기 좀 이상"): step axis steeper (29 deg down instead of 18) — the 3/4-front view is used for
        # headings 38..110 deg from the camera, whose screen motion runs 0..42 deg down; she walks diagonally DOWN most of the time
        # v8 (2026-11-10 "발이 이상함"): far foot only 5 px above the near one (was 10) so the back / forward far boot stays
        # visible under the mid-shin hem in every frame; boots are rotated ovals with the toe along the step axis
        # v8b: feet 24 px apart sideways (was 18) so the two boots overlap less when they pass (mean x unchanged); far foot 4 px
        # BELOW the root line (was 5 above): at contact R the rear far boot peeks out under the hem (visible 140 -> 390 px of 940).
        # It stays hidden in frames 2 and 8 (lifted under the hem / behind the swinging near leg) — real occlusion.
        return dict(fwd=(1.0, 0.55), hip={"R": (-10, 4), "L": (16, -6)}, foot={"R": (-9, 8), "L": (15, 4)}, sack=-1, side=1)
    return dict(fwd=(1.0, -0.33), hip={"R": (12, 4), "L": (-14, -6)}, foot={"R": (13, 8), "L": (-13, -5)}, sack=1, side=1)


def feet(clip, view, f):
    """reference foot positions (cell coords, sole point) and lift for frame f: {'R': (x, y, lift), 'L': ...}"""
    g, G = geometry(view), GAIT[clip]
    out = {}
    for leg, ph in (("R", 0.0), ("L", 0.5)):
        s, h = leg_phase(f / 8.0 + ph, G["S"], G["H"])
        bx, by = g["foot"][leg]
        out[leg] = (CW / 2 + bx + g["fwd"][0] * s, GROUND + by + g["fwd"][1] * s - h, h)
    return out


def bob(clip, f):
    return GAIT[clip]["bob"] * [0.0, 1.0, 0.0, -1.0][f % 4]


def ik(hip, ankle, L, bend):
    dx, dy = ankle[0] - hip[0], ankle[1] - hip[1]
    d = max(1e-3, math.hypot(dx, dy))
    d2 = min(d, 2 * L - 0.5)
    a = math.acos(d2 / (2 * L))
    base = math.atan2(dy, dx)
    ang = base - a * bend
    return (hip[0] + L * math.cos(ang), hip[1] + L * math.sin(ang))


BOOT_A, BOOT_B = 24.0, 12.0      # v8: 3/4 boot = oval 48 x 24 px, long axis along the step axis (toe toward the travel direction)


def boot_oval(foot, fwd, grow=0.0, n=48):
    """rotated oval: heel end near the foot point, toe 9 px further along fwd, lowest point on the foot's ground y"""
    ang = math.atan2(fwd[1], fwd[0])
    a, b = BOOT_A + grow, BOOT_B + grow
    ymax = math.sqrt((a * math.sin(ang)) ** 2 + (b * math.cos(ang)) ** 2)
    cx, cy = foot[0] + 9.0 * math.cos(ang), foot[1] - ymax
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = a * math.cos(t), b * math.sin(t)
        pts.append((cx + x * math.cos(ang) - y * math.sin(ang), cy + x * math.sin(ang) + y * math.cos(ang)))
    return pts


def draw_leg(d, hip, foot, col, shoe, fwd, front):
    fwdx = fwd[0]
    ankle = (foot[0], foot[1] - 16)
    L = (GROUND - 18 - HIP_Y) / 2 * 1.02          # subtle knee bend
    knee = ik(hip, ankle, L, 1 if fwdx >= 0 else -1) if not front else ((hip[0] + ankle[0]) / 2, (hip[1] + ankle[1]) / 2)
    for a, b in ((hip, knee), (knee, ankle)):
        d.line([a, b], fill=INK, width=46)
        d.line([a, b], fill=col, width=36)
    for p in (knee, ankle):
        d.ellipse([p[0] - 18, p[1] - 18, p[0] + 18, p[1] + 18], fill=col)
    if front:
        box = [foot[0] - 24, foot[1] - 28, foot[0] + 24, foot[1]]          # rounded boot
        d.ellipse([box[0] - 3, box[1] - 3, box[2] + 3, box[3] + 3], fill=INK)
        d.ellipse(box, fill=shoe)
    else:
        d.polygon(boot_oval(foot, fwd, 3.0), fill=INK)
        d.polygon(boot_oval(foot, fwd), fill=shoe)


def draw_frame(d, x0, y0, clip, view, f):
    g = geometry(view)
    by = bob(clip, f)
    cx = x0 + CW / 2
    ft = feet(clip, view, f)
    front = g["side"] == 0
    hips = {k: (cx + v[0], y0 + HIP_Y + by + v[1]) for k, v in g["hip"].items()}
    pts = {k: (x0 + ft[k][0], y0 + ft[k][1]) for k in ft}
    # far leg first (3/4: left = far; front/back: the lifted / back one first)
    order = ["L", "R"] if not front else sorted(["L", "R"], key=lambda k: -ft[k][2])
    colour = {"R": (TAN, BROWN), "L": (CYAN, NAVY)}
    for k in order:
        draw_leg(d, hips[k], pts[k], colour[k][0], colour[k][1], g["fwd"], front)
    # dress (bell to the knee — lower legs and both shoes must stay visible)
    top, hem = y0 + CHIN_Y - 6 + by, y0 + 372 + by
    poly = [(cx - 50, top), (cx + 50, top), (cx + 96, hem), (cx - 96, hem)]
    d.polygon(poly, fill=DRESS, outline=INK, width=5)
    # arms: opposite to the legs (3/4: right arm near), or holding the sack
    sh = {"R": (cx + (-52 if view in ("front", "q_front") else 52), y0 + CHIN_Y + 18 + by),
          "L": (cx + (52 if view in ("front", "q_front") else -52), y0 + CHIN_Y + 18 + by)}
    if view in ("q_front", "q_back"):
        sh = {"R": (cx - 8 * (1 if view == "q_front" else -1), y0 + CHIN_Y + 22 + by), "L": (cx + 30 * (1 if view == "q_front" else -1), y0 + CHIN_Y + 14 + by)}
    sack_c = (cx + g["sack"] * 92, y0 + CHIN_Y - 20 + by)
    for k in ("L", "R"):
        if clip == "carry":
            hand = (sack_c[0] - g["sack"] * 10, sack_c[1] + 58) if k == "R" else (sack_c[0] - g["sack"] * 34, sack_c[1] + 22)
        else:
            other = "L" if k == "R" else "R"
            s = (ft[other][0] - CW / 2) if g["side"] else (ft[other][1] - GROUND) / 0.38
            hand = (sh[k][0] + (g["fwd"][0] * s * 0.55 if g["side"] else 0), sh[k][1] + 88 + (0 if g["side"] else s * 0.15))
        d.line([sh[k], hand], fill=INK, width=24)
        d.line([sh[k], hand], fill=SKIN, width=17)
        d.ellipse([hand[0] - 14, hand[1] - 14, hand[0] + 14, hand[1] + 14], fill=SKIN, outline=INK, width=4)
    if clip == "carry":
        d.ellipse([sack_c[0] - 62, sack_c[1] - 72, sack_c[0] + 62, sack_c[1] + 66], fill=SACK, outline=INK, width=5)
        d.rectangle([sack_c[0] - 58, sack_c[1] - 10, sack_c[0] + 58, sack_c[1] + 14], fill=STRIPE)
    # head placeholder
    hc = (cx + (8 if view == "q_front" else (-4 if view == "q_back" else 0)), y0 + CHIN_Y - HEAD_R + by)
    d.ellipse([hc[0] - HEAD_R, hc[1] - HEAD_R, hc[0] + HEAD_R, hc[1] + HEAD_R], fill=(255, 0, 255))
    if clip == "carry" and g["sack"] < 0:      # front-side sack shows in front of the head edge (as in the drawn sheets)
        pass


def sheet(clip, view):
    im = Image.new("RGB", (4 * CW, 2 * CH), (0, 255, 0))
    d = ImageDraw.Draw(im)
    gcol = (0, 176, 0)
    for f in range(8):
        x0, y0 = (f % 4) * CW, (f // 4) * CH
        d.rectangle((x0 + 4, y0 + 4, x0 + CW - 4, y0 + CH - 4), outline=gcol, width=3)
        d.line((x0 + 30, y0 + GROUND, x0 + CW - 30, y0 + GROUND), fill=gcol, width=4)
        draw_frame(d, x0, y0, clip, view, f)
    return im


def hybrid(clip, view):
    """v4b reference: the UPPER BODY (dress, sleeves, arms, sack, magenta head) cut from the earlier drawn sheet of the same clip /
    view (raw/src_<clip>_<view>.png, correct 3/4 body turn) above its skirt hem, scaled so chin and hem land on the puppet's,
    over the puppet's colour-coded legs. The image model then only has to redraw the legs as traced."""
    import sys as _s
    _s.path.insert(0, os.path.join(HERE, "..", "cutout_a"))
    import numpy as np
    import cut_sheets as C
    src = C.key(os.path.join(RAW, f"src_{clip}_{view}.png"))
    im = Image.new("RGB", (4 * CW, 2 * CH), (0, 255, 0))
    d = ImageDraw.Draw(im)
    gcol = (0, 176, 0)
    g = geometry(view)
    for f in range(8):
        x0, y0 = (f % 4) * CW, (f // 4) * CH
        d.rectangle((x0 + 4, y0 + 4, x0 + CW - 4, y0 + CH - 4), outline=gcol, width=3)
        d.line((x0 + 30, y0 + GROUND, x0 + CW - 30, y0 + GROUND), fill=gcol, width=4)
        by = bob(clip, f)
        ft = feet(clip, view, f)
        cx = x0 + CW / 2
        hips = {k: (cx + v[0], y0 + HIP_Y + by + v[1]) for k, v in g["hip"].items()}
        front = g["side"] == 0
        order = ["L", "R"] if not front else sorted(["L", "R"], key=lambda k: -ft[k][2])
        colour = {"R": (TAN, BROWN), "L": (CYAN, NAVY)}
        for k in order:
            draw_leg(d, hips[k], (x0 + ft[k][0], y0 + ft[k][1]), colour[k][0], colour[k][1], g["fwd"], front)
        sf = (f + 4) % 8 if view == "back" else f        # the earlier back sheets had the other leg phase
        sx0, sy0 = (sf % 4) * CW, (sf // 4) * CH
        cell = src[sy0:sy0 + CH, sx0:sx0 + CW].astype(np.float32)
        r, gg, b, a = cell[..., 0], cell[..., 1], cell[..., 2], cell[..., 3]
        L = 0.299 * r + 0.587 * gg + 0.114 * b
        mag = (r > 170) & (b > 170) & (gg < 110)
        rose = (r - gg > 45) & (np.abs(gg - b) < 28) & (L > 100) & (L < 190) & (r > 150) & (a > 200)
        rows = np.nonzero(rose.sum(1) >= 15)[0]
        my, mx = np.nonzero(mag)
        chin, hem, hx = my.max(), rows.max() + 3, mx.mean()
        keep = cell.copy()
        keep[hem + 1:, :, 3] = 0
        # v8b (2026-11-10): the straight cut left pieces of the source sheet's own legs / boots beside and under the wavy hem
        # (tan stubs, a kicked-back boot, hook strokes) and the image model copied them as a third foot. Per column: nothing
        # below the lowest dress pixel (rose / cream apron) + its ink line; columns without dress near the hem are cleared.
        cream = (L > 195) & (r - b < 85) & (a > 200)
        dress = rose | cream
        band = max(0, hem - 70)
        W_ = cell.shape[1]
        low_y = np.full(W_, -1.0)
        for x in range(W_):
            ys = np.nonzero(dress[band:hem + 1, x])[0]
            if len(ys):
                low_y[x] = band + ys.max()
        for x in range(W_):
            win = low_y[max(0, x - 5):x + 6]            # median over 11 columns: single stray columns leave no ticks
            m = float(np.median(win))
            if m >= 0:
                keep[int(min(m, low_y[x] if low_y[x] >= 0 else m)) + 7:, x, 3] = 0
            else:
                keep[max(0, hem - 45):, x, 3] = 0
        # the source sheets' own legs (v3: cyan / navy far leg, tan / brown near leg) that poke out above the cut: drop them,
        # the puppet legs are the only legs in the reference
        low = np.zeros(cell.shape[:2], bool)
        low[max(0, hem - 90):, :] = True
        legish = (b > r + 25) & (b > gg + 5) & (L < 190)      # the v3 cyan / navy far leg (the near leg is under the cut)
        keep[..., 3] = np.where(low & legish & ~rose, 0, keep[..., 3])
        up = Image.fromarray(np.clip(keep, 0, 255).astype(np.uint8), "RGBA")
        pchin, phem = CHIN_Y + by, HEM_Y + by          # hem at mid-shin (v6)
        k = (phem - pchin) / max(1.0, hem - chin)
        up = up.resize((round(CW * k), round(CH * k)), Image.LANCZOS)
        hc = CW / 2 + (8 if view == "q_front" else (-4 if view == "q_back" else 0))
        ox, oy = x0 + hc - hx * k, y0 + pchin - chin * k
        im.paste(up, (round(ox), round(oy)), up)
    return im


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "hybrid":
    for clip in ("walk", "carry"):
        for v in VIEWS:
            hybrid(clip, v).save(os.path.join(RAW, f"pose_{clip}_{v}.png"))
    print("hybrid ok")
    sys.exit(0)

if __name__ == "__main__":
    for clip in ("walk", "carry"):
        for v in VIEWS:
            sheet(clip, v).save(os.path.join(RAW, f"pose_{clip}_{v}.png"))
    print("ok")
