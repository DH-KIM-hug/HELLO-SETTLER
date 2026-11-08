"""2D paper-cutout PUPPY (E3-13 / E3-13b, 2026-11-08): cut the 4 part sheets, place every part over the assembled dog,
pack ONE atlas pair and write the rig library proto/cutout_dog/dog_lib.gd reads.

usage: python3 build_dog.py
in : art/cutout/dog_a/raw/{front,q_front,q_back,back}.png (gen.sh, template = sheet_layout.CELLS)
out: art/cutout/dog_a/dog_atlas.png  RGBA, the art as drawn
     art/cutout/dog_a/dog_mask.png   R = drawn base coat weight, G = light coat (muzzle / chest / paws) weight
     art/cutout/dog_a/dog_lib.json   quads + per-view rig (body pivot, hip, shoulder, legs) + measured base colours
     art/cutout/dog_a/parts/<view>/*.png  cut pieces (debug, .gdignore'd)
     art/cutout/dog_a/raw/check_<view>.png  figure | auto doll | overlay | white-coat recolour preview | pointy ears +
                                             straight tail + sweater  (eyeball check)

Keying / cutting / colour-class matching = the resident pipeline (tools/cutout_a/cut_sheets.py, imported read-only).
Dog specifics: legs go on the paw blobs of the figure (four near-identical legs fool the colour match), the floppy ear (the
concept's ear) is matched and the pointy / folded ears sit on its root, the curl tail is matched and the straight tail
shares its root. Views: 3/4 views face image-RIGHT (q_front toward the camera, q_back away), like the residents.
"""
import importlib.util
import json
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "cutout_a"))
import cut_sheets as CS        # noqa: E402  (resident helpers: key, cut_by_cells, classes, place)

_spec = importlib.util.spec_from_file_location("dog_layout", os.path.join(HERE, "sheet_layout.py"))
DL = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(DL)

ART = DL.ART
RAW = os.path.join(ART, "raw")
PARTS = os.path.join(ART, "parts")
VIEWS = ["front", "q_front", "q_back", "back"]
FIG = 430.0          # rig units: every figure normalised to this height (paws = 0, y up)
ATLAS_K = 0.5        # atlas px per rig unit (figure ~215 px — the same density as the resident atlas)
ATLAS_W = 1024
PAD = 4
EXPECT = {"coat": "d98f50", "light": "fbe2bf"}
EARS = ["ear_pointy", "ear_folded", "ear_floppy"]      # = Dogs.EARS order
TAILS = ["tail_curl", "tail_straight"]                 # = Dogs.TAILS order
HEADS = ["head", "head_sleep", "head_bark"]
LEGS = ["leg_fa", "leg_fb", "leg_ha", "leg_hb"]        # front near / far, hind near / far (front, back views: a = image-left)
SLOT = {"body": 1, "sweater": 1, "head": 2, "ear_a": 3, "ear_b": 4, "tail": 5, "leg_fa": 6, "leg_fb": 7, "leg_ha": 8, "leg_hb": 9}
CLS = {"body": 0, "head": 1, "ear": 2, "tail": 3, "leg": 4, "sweater": 5}
# draw order per view (back -> front). "ear_lo" = pointy / folded ears (their base hides behind the head), "ear_hi" = floppy
ORDER = {
    "front": ["tail", "leg_ha", "leg_hb", "leg_fa", "leg_fb", "body", "sweater", "ear_lo_a", "ear_lo_b", "head", "ear_hi_a", "ear_hi_b"],
    "q_front": ["ear_lo_b", "ear_hi_b", "leg_fb", "leg_hb", "tail", "leg_fa", "leg_ha", "body", "sweater", "ear_lo_a", "head", "ear_hi_a"],
    "q_back": ["ear_lo_b", "ear_hi_b", "leg_fb", "leg_hb", "ear_lo_a", "head", "ear_hi_a", "leg_fa", "leg_ha", "body", "sweater", "tail"],
    "back": ["leg_fa", "leg_fb", "ear_lo_a", "ear_lo_b", "ear_hi_a", "ear_hi_b", "head", "leg_ha", "leg_hb", "body", "sweater", "tail"],
}
FAR_LEGS = {"front": ["leg_ha", "leg_hb"], "q_front": ["leg_fb", "leg_hb"], "q_back": ["leg_fb", "leg_hb"], "back": ["leg_fa", "leg_fb"]}


def hexrgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


def lum(c):
    return c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114


def blobs(m, min_n=30):
    """4-connected components of a bool mask -> list of (n, x0, y0, x1, y1, cx, cy, ys, xs)"""
    lab = np.full(m.shape, -1, np.int32)
    out = []
    for y, x in zip(*np.nonzero(m)):
        if lab[y, x] >= 0:
            continue
        q = deque([(y, x)])
        lab[y, x] = len(out)
        ys, xs = [], []
        while q:
            cy, cx = q.popleft()
            ys.append(cy); xs.append(cx)
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < m.shape[0] and 0 <= nx < m.shape[1] and m[ny, nx] and lab[ny, nx] < 0:
                    lab[ny, nx] = len(out); q.append((ny, nx))
        ys, xs = np.array(ys), np.array(xs)
        out.append((len(ys), xs.min(), ys.min(), xs.max() + 1, ys.max() + 1, xs.mean(), ys.mean(), ys, xs))
    return [b for b in out if b[0] >= min_n]


def near_colour(rgb, base, tol):
    """pixel is a lit / shaded version of base: chromaticity distance + brightness ratio"""
    l = np.maximum(lum(rgb), 1e-3)
    lb = max(float(lum(base)), 1e-3)
    d = np.abs(rgb / l[..., None] - base / lb).sum(-1)
    r = l / lb
    return d, r, (d < tol) & (r > 0.55) & (r < 1.2)


def measure_bases(pieces):
    """drawn coat / light-coat colour = median of the piece pixels near the expected concept colours"""
    px = np.concatenate([p[p[..., 3] > 200][:, :3] for p in pieces]).astype(np.float32) / 255.0
    out = {}
    for k, h in EXPECT.items():
        e = hexrgb(h)
        dist = np.abs(px - e).sum(-1)
        near = px[dist < max(0.2, np.percentile(dist, 3))]
        c = np.median(near, axis=0) if len(near) > 50 else e
        out[k] = "%02x%02x%02x" % tuple(int(round(x * 255)) for x in c)
    return out


def dye_mask(img, bases, tol=0.2):
    """(h, w, 3) weights: R coat, G light coat. Tighter than the resident mask so the cheek blush / nose / ink stay drawn."""
    rgb = img[..., :3].astype(np.float32) / 255.0
    best = np.full(rgb.shape[:2], 9.0)
    idx = np.full(rgb.shape[:2], -1)
    for i, b in enumerate(bases):
        d, r, ok = near_colour(rgb, b, tol)
        d = d + 0.35 * np.abs(np.log(np.maximum(r, 1e-3)))
        upd = ok & (d < best)
        best[upd] = d[upd]
        idx[upd] = i
    w = np.zeros(rgb.shape[:2] + (3,), np.float32)
    for i in range(len(bases)):
        w[..., i] = idx == i
    return w


def erase_stub(p):
    """head pieces are drawn on a narrow neck stub — erase the bottom rows narrower than 45 % of the head width"""
    a = p[..., 3] > 128
    wid = np.array([(np.ptp(np.nonzero(r)[0]) + 1) if r.any() else 0 for r in a])
    mx = wid.max()
    yfull = int(np.nonzero(wid >= 0.6 * mx)[0].max())
    out = p.copy()
    for y in range(yfull, p.shape[0]):
        if wid[y] < 0.45 * mx:
            out[y:, :, 3] = 0
            break
    ys = np.nonzero(out[..., 3].max(1) > 8)[0]
    return out[: ys.max() + 1]


def find_eyes(p):
    """dark round dots fully surrounded by fur inside the head piece -> up to two (x, y) in piece px"""
    a = p[..., 3] > 128
    rgb = p[..., :3].astype(np.float32) / 255.0
    dark = a & (lum(rgb) < 0.28)
    # the outline ring touches the transparent outside: drop dark blobs that touch it
    outside = ~a
    grow = outside.copy()
    for _ in range(3):
        g = grow.copy()
        g[1:] |= grow[:-1]; g[:-1] |= grow[1:]; g[:, 1:] |= grow[:, :-1]; g[:, :-1] |= grow[:, 1:]
        grow = g
    H, W = a.shape
    cand = []
    for n, x0, y0, x1, y1, cx, cy, ys, xs in blobs(dark, min_n=12):
        if grow[ys, xs].any():
            continue
        w, h = x1 - x0, y1 - y0
        if not (0.012 * W < w < 0.12 * W and 0.5 < w / max(h, 1) < 1.6 and cy < 0.62 * H):
            continue
        fill = n / float(w * h)
        if fill < 0.5:          # brows / mouth lines are thin arcs
            continue
        cand.append((n, cx, cy))
    cand.sort(key=lambda c: -c[0])
    eyes = []
    for c in cand:
        # the nose is the lowest / biggest dark dot in the middle of the muzzle: keep dots on the upper row
        if eyes and abs(c[2] - eyes[0][2]) > 0.08 * H:
            continue
        eyes.append(c)
        if len(eyes) == 2:
            break
    if len(eyes) == 2 and cand:
        # if the two picked dots differ a lot in height, one is probably the nose — keep the higher pair
        pass
    return [(e[1], e[2]) for e in sorted(eyes, key=lambda e: e[1])]


def paws(fig, light):
    """cream paw blobs in the lowest 24 % of the figure -> [(cx, bottom_y, width)] sorted by x"""
    H = fig.shape[0]
    a = fig[..., 3] > 128
    rgb = fig[..., :3].astype(np.float32) / 255.0
    _, _, ok = near_colour(rgb, light, 0.28)
    m = a & ok
    m[: int(0.76 * H)] = False
    out = []
    for n, x0, y0, x1, y1, cx, cy, ys, xs in blobs(m, min_n=60):
        out.append([float(cx), float(y1), float(x1 - x0), n])
    # merge blobs closer than a paw (a toe line can split a paw)
    out.sort(key=lambda b: b[0])
    merged = []
    for b in out:
        if merged and abs(b[0] - merged[-1][0]) < 0.45 * max(b[2], merged[-1][2]):
            m0 = merged[-1]
            tot = m0[3] + b[3]
            merged[-1] = [(m0[0] * m0[3] + b[0] * b[3]) / tot, max(m0[1], b[1]), max(m0[2], b[2]), tot]
        else:
            merged.append(b)
    merged.sort(key=lambda b: -b[3])
    return sorted(merged[:4], key=lambda b: b[0])


def assign_legs(v, pw, W):
    """paw blobs -> leg names (see LEGS). Missing paws are mirrored about the figure centre."""
    while len(pw) < 4:
        # duplicate the paw farthest from the middle, mirrored (hidden leg)
        far = max(pw, key=lambda b: abs(b[0] - W / 2))
        pw.append([W - far[0], far[1] - 6, far[2], far[3] * 0.5])
        pw.sort(key=lambda b: b[0])
    if v in ("front", "back"):
        low = sorted(pw, key=lambda b: -b[1])          # the near pair stands lowest on the screen
        inner = sorted(low[:2], key=lambda b: b[0])
        outer = sorted(low[2:], key=lambda b: b[0])
        if v == "front":
            return {"leg_fa": inner[0], "leg_fb": inner[1], "leg_ha": outer[0], "leg_hb": outer[1]}
        return {"leg_ha": inner[0], "leg_hb": inner[1], "leg_fa": outer[0], "leg_fb": outer[1]}
    # 3/4 views face image-right: hind = the two left paws, front = the two right; near = the lower one of a pair
    hind, front = sorted(pw[:2], key=lambda b: -b[1]), sorted(pw[2:], key=lambda b: -b[1])
    return {"leg_ha": hind[0], "leg_hb": hind[1], "leg_fa": front[0], "leg_fb": front[1]}


def opaque_box(p):
    ys, xs = np.nonzero(p[..., 3] > 128)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def resize(p, s):
    w = max(2, int(round(p.shape[1] * s))); h = max(2, int(round(p.shape[0] * s)))
    return np.asarray(Image.fromarray(p).resize((w, h), Image.LANCZOS))


def end_points(p):
    """the two ends of an elongated piece along its principal axis (piece px)"""
    ys, xs = np.nonzero(p[..., 3] > 128)
    c = np.array([xs.mean(), ys.mean()])
    w, vec = np.linalg.eigh(np.cov(np.vstack([xs - c[0], ys - c[1]])))
    ax = vec[:, 1]
    t = (xs - c[0]) * ax[0] + (ys - c[1]) * ax[1]
    lo, hi = t.argmin(), t.argmax()
    return np.array([xs[lo], ys[lo]], float), np.array([xs[hi], ys[hi]], float)


def run_view(v, bases):
    rgba = CS.key(os.path.join(RAW, v + ".png"))
    cut = CS.cut_by_cells(rgba, DL.CELLS, DL.FIG_BOX)
    fig = cut["figure"][0]
    od = os.path.join(PARTS, v)
    os.makedirs(od, exist_ok=True)
    Image.fromarray(fig).save(os.path.join(od, "figure.png"))
    for name, (p, _) in cut.items():
        Image.fromarray(p).save(os.path.join(od, name + ".png"))
    Hf, Wf = fig.shape[:2]
    a = fig[..., 3] > 128
    feet_y = int(np.nonzero(a)[0].max())
    cen = CS.classes([fig[fig[..., 3] > 200][:, :3]], k=7)
    light = hexrgb(bases["light"])
    pl = {}      # name -> {"img", "x", "y", "s"} in figure px (x, y = top-left of the scaled piece)

    def put(name, img, x, y, s, score=None):
        pl[name] = {"img": img, "x": float(x), "y": float(y), "s": float(s), "w": img.shape[1] * s, "h": img.shape[0] * s,
                    "score": score}

    # body + head: colour-class match over the figure (free uniform scale)
    sl = [round(0.8 + 0.05 * i, 2) for i in range(10)]
    # windows for the piece CENTRE: the back views are one flat fur colour, so the colour match alone puts the body on the head
    bwin = {"front": (0.25, 0.5, 0.75, 0.85), "q_front": (0.2, 0.45, 0.75, 0.85), "q_back": (0.15, 0.45, 0.7, 0.85),
            "back": (0.3, 0.55, 0.7, 0.85)}[v]
    hwin = {"front": (0.25, 0.1, 0.75, 0.42), "q_front": (0.4, 0.05, 0.9, 0.45), "q_back": (0.45, 0.05, 0.95, 0.45),
            "back": (0.25, 0.1, 0.75, 0.45)}[v]
    sc, (s, _, x, y) = CS.place(fig, cut["body"][0], cen, win=(bwin[0] * Wf, bwin[1] * Hf, bwin[2] * Wf, bwin[3] * Hf), uniform=True, scales=sl)
    put("body", cut["body"][0], x, y, s, sc)
    head = erase_stub(cut["head"][0])
    sc, (s, _, x, y) = CS.place(fig, head, cen, win=(hwin[0] * Wf, hwin[1] * Hf, hwin[2] * Wf, hwin[3] * Hf), uniform=True, scales=sl)
    put("head", head, x, y, s, sc)
    S = (pl["body"]["s"] + pl["head"]["s"]) / 2           # sheet scale for the pieces that cannot measure their own size
    hd = pl["head"]
    # sleeping / barking heads: same head, drawn smaller in narrower cells -> match the width, same bottom centre
    for hn in ("head_sleep", "head_bark"):
        if hn not in cut:
            continue
        p = erase_stub(cut[hn][0])
        s2 = hd["w"] / p.shape[1]
        put(hn, p, hd["x"] + hd["w"] / 2 - p.shape[1] * s2 / 2, hd["y"] + hd["h"] - p.shape[0] * s2, s2)
    # floppy ear (the concept's ear): match per side; pointy / folded ears stand on its root
    hx, hy, hw, hh = hd["x"], hd["y"], hd["w"], hd["h"]
    if v == "front":
        wins = {"a": (hx - 0.35 * hw, hy, hx + 0.2 * hw, hy + 0.65 * hh),
                "b": (hx + 0.8 * hw, hy, hx + 1.35 * hw, hy + 0.65 * hh)}
    elif v == "back":       # the back ears hang OUTSIDE the head outline (they are drawn behind it)
        wins = {"a": (hx - 0.5 * hw, hy + 0.05 * hh, hx + 0.02 * hw, hy + 0.6 * hh),
                "b": (hx + 0.98 * hw, hy + 0.05 * hh, hx + 1.5 * hw, hy + 0.6 * hh)}
    elif v == "q_back":     # walking away to the right: the near ear is on the image-LEFT side of the head
        wins = {"a": (hx - 0.2 * hw, hy + 0.05 * hh, hx + 0.3 * hw, hy + 0.6 * hh),
                "b": (hx + 0.55 * hw, hy - 0.2 * hh, hx + 1.0 * hw, hy + 0.3 * hh)}
    else:
        wins = {"a": (hx - 0.05 * hw, hy - 0.1 * hh, hx + 0.6 * hw, hy + 0.65 * hh),
                "b": (hx + 0.45 * hw, hy - 0.25 * hh, hx + 1.05 * hw, hy + 0.35 * hh)}
    flo = cut["ear_floppy"][0]
    roots = {}
    # back views: one flat fur colour -> no colour match; hang the ear from a fixed root on the upper head side
    FIXED_EAR = {"back": {"a": (0.1, 0.2, -0.3), "b": (0.9, 0.2, 0.3)},
                 "q_back": {"a": (0.22, 0.14, -0.15), "b": (0.8, 0.08, 0.35)}}
    for side, win in wins.items():
        if v in FIXED_EAR:
            fx, fy_, out = FIXED_EAR[v][side]
            p = flo[:, ::-1].copy() if out > 0 else flo      # sheet floppy ear hangs to the image-left
            rx, ry = hx + fx * hw, hy + fy_ * hh
            w, h = p.shape[1] * S, p.shape[0] * S
            x = rx - w / 2 + out * w
            put("ear_floppy_" + side, p, x, ry - 0.12 * h, S, "fixed")
            roots[side] = (rx, ry, out > 0)
            continue
        best = None
        for flip in (False, True):
            for ang in (-60, -40, -20, 0, 20, 40, 60):     # the concept's front ears stick out sideways
                p = flo[:, ::-1].copy() if flip else flo
                if ang:
                    p = np.asarray(Image.fromarray(p).rotate(ang, resample=Image.BICUBIC, expand=True))
                    bx0, by0, bx1, by1 = opaque_box(p)
                    p = p[by0:by1, bx0:bx1].copy()
                sc, (s, _, x, y) = CS.place(fig, p, cen, win=win, uniform=True, fixed=round(S, 3))
                if best is None or sc > best[0]:
                    best = (sc, p, x, y, (flip, ang))
        sc, p, x, y, flip = best
        put("ear_floppy_" + side, p, x, y, S, sc)
        pa = p[..., 3] > 128
        ys = np.nonzero(pa.any(1))[0]
        top = ys.min()
        band = pa[top: top + max(3, int(0.15 * p.shape[0]))]
        rx = np.nonzero(band.any(0))[0].mean()
        roots[side] = (x + rx * S, y + (top + 0.12 * p.shape[0]) * S, flip)
        print(v, "ear_floppy", side, "score %.2f flip %s" % (sc, flip))
    hcx = hx + hw / 2
    for en in ("ear_pointy", "ear_folded"):
        for side, (rx, ry, _) in roots.items():
            p = cut[en][0]
            # sheet pieces lean image-right -> mirror the ones that must lean left (front / back: the image-left ear;
            # 3/4: the near ear, which leans back = image-left)
            lean_left = (rx < hcx) if v in ("front", "back") else side == "a"
            p = p[:, ::-1].copy() if lean_left else p
            se = 0.8 * S            # the sheet ears are drawn big (bunny-like on the doll)
            w, h = p.shape[1] * se, p.shape[0] * se
            bx = rx + (0.1 * hw if rx < hcx else -0.1 * hw)
            put(en + "_" + side, p, bx - w / 2, ry + 0.38 * h - h, se)
    # tails: curl matched (flip tried) around the body; its ROOT = the tail pixel nearest the body centre
    bd = pl["body"]
    bcx, bcy = bd["x"] + bd["w"] / 2, bd["y"] + bd["h"] / 2
    win = (bd["x"] - 0.35 * bd["w"], bd["y"] - 0.7 * bd["h"], bd["x"] + 1.35 * bd["w"], bd["y"] + 0.7 * bd["h"])
    best = None
    for flip in (False, True):
        p = cut["tail_curl"][0][:, ::-1].copy() if flip else cut["tail_curl"][0]
        sc, (s, _, x, y) = CS.place(fig, p, cen, win=win, uniform=True, fixed=round(S, 3))
        if best is None or sc > best[0]:
            best = (sc, p, x, y)
    sc, p, x, y = best
    put("tail_curl", p, x, y, S, sc)
    ys, xs = np.nonzero(p[..., 3] > 128)
    d = (x + xs * S - bcx) ** 2 + (y + ys * S - bcy) ** 2
    i = d.argmin()
    troot = (x + xs[i] * S, y + ys[i] * S)
    print(v, "tail_curl score %.2f root %s" % (sc, troot))
    # straight tail: one end on the root, the other end AWAY from the body centre
    bestt = None
    for flip in (False, True):
        p = cut["tail_straight"][0][:, ::-1].copy() if flip else cut["tail_straight"][0]
        e0, e1 = end_points(p)
        for root_e, tip_e in ((e0, e1), (e1, e0)):
            ox, oy = troot[0] - root_e[0] * S, troot[1] - root_e[1] * S
            tip = (ox + tip_e[0] * S, oy + tip_e[1] * S)
            # prefer: tip far from the body centre, and pointing up (y smaller) — a happy tail
            score = np.hypot(tip[0] - bcx, tip[1] - bcy) - 0.6 * (tip[1] - troot[1])
            if bestt is None or score > bestt[0]:
                bestt = (score, p, ox, oy)
    _, p, ox, oy = bestt
    put("tail_straight", p, ox, oy, S)
    # legs on the paw blobs (bottom of the leg piece = bottom of the paw)
    pw = paws(fig, light)
    print(v, "paws", [(round(b[0]), round(b[1])) for b in pw])
    asg = assign_legs(v, [list(b) for b in pw], Wf)
    # SQUARE STANCE: the concept stands mid-stride (3/4) and the front view's "hind paws" can be belly cream -> the rest
    # pose is rebuilt from the reliable near paws; the walk clip supplies the stride
    lw = np.mean([cut[ln][0].shape[1] for ln in LEGS]) * S
    if v in ("front", "back"):
        na, nb, fa_, fb_ = ("leg_fa", "leg_fb", "leg_ha", "leg_hb") if v == "front" else ("leg_ha", "leg_hb", "leg_fa", "leg_fb")
        a0, b0 = asg[na], asg[nb]
        asg[fa_] = [a0[0] - 0.45 * lw, a0[1] - 0.05 * Hf, a0[2], 0]
        asg[fb_] = [b0[0] + 0.45 * lw, b0[1] - 0.05 * Hf, b0[2], 0]
    else:
        for near, far in (("leg_fa", "leg_fb"), ("leg_ha", "leg_hb")):
            m = (asg[near][0] + asg[far][0]) / 2
            bd_ = pl["body"]       # keep the pair under the body (hind: rear quarter, front: chest quarter)
            if near == "leg_ha":
                m = min(max(m, bd_["x"] + 0.24 * bd_["w"]), bd_["x"] + 0.4 * bd_["w"])
            else:
                m = max(min(m, bd_["x"] + 0.78 * bd_["w"]), bd_["x"] + 0.6 * bd_["w"])
            bot = max(asg[near][1], asg[far][1])
            asg[near] = [m - 0.1 * lw, bot, asg[near][2], 0]
            asg[far] = [m + 0.3 * lw, bot - 0.045 * Hf, asg[far][2], 0]
    for ln in LEGS:
        p = cut[ln][0]
        cx_, by_ = asg[ln][0], asg[ln][1]
        put(ln, p, cx_ - p.shape[1] * S / 2, by_ - p.shape[0] * S, S)
    # sweater (꿀떡이, winter): fitted over the body box
    if "sweater" in cut:
        p = cut["sweater"][0]
        sx = bd["w"] * 1.0 / p.shape[1]
        sy = bd["h"] * 0.92 / p.shape[0]
        s3 = (sx + sy) / 2
        put("sweater", p, bd["x"] + bd["w"] / 2 - p.shape[1] * s3 / 2, bd["y"] - 0.02 * bd["h"], s3)
    # paws centre (all four) = x origin
    cx = float(np.mean([asg[ln][0] for ln in LEGS]))
    eyes = find_eyes(head)
    print(v, "eyes", eyes)
    return {"fig": fig, "pl": pl, "feet_y": feet_y, "cx": cx, "eyes": eyes, "roots": roots, "troot": troot, "asg": asg}


def compose(shape, pl, names):
    c = Image.new("RGBA", (shape[1], shape[0]), (0, 0, 0, 0))
    for n in names:
        if n not in pl:
            continue
        q = pl[n]
        img = Image.fromarray(resize(q["img"], q["s"]))
        layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
        layer.paste(img, (int(round(q["x"])), int(round(q["y"]))), img)
        c = Image.alpha_composite(c, layer)
    return c


def order_names(v, ear, tail, head="head", sweater=False):
    out = []
    for n in ORDER[v]:
        if n.startswith("ear_"):
            hi = n.startswith("ear_hi")
            if (ear == "ear_floppy") != hi:
                continue
            out.append(ear + n[-2:])
        elif n == "tail":
            out.append(tail)
        elif n == "head":
            out.append(head)
        elif n == "sweater":
            if sweater:
                out.append("sweater")
        else:
            out.append(n)
    return out


def recolour_preview(img, mask, bases, coat="f1ebe1", light="fbf7f0"):
    a = np.asarray(img).astype(np.float32) / 255.0
    rgb = a[..., :3]
    lc = lum(rgb)[..., None]
    cb = hexrgb(coat) * lc / float(lum(hexrgb(bases["coat"])))
    lb = hexrgb(light) * lc / float(lum(hexrgb(bases["light"])))
    m = mask
    o = rgb * (1 - np.minimum(m[..., :1] + m[..., 1:2], 1)) + m[..., :1] * cb + m[..., 1:2] * lb
    out = np.dstack([np.clip(o, 0, 1), a[..., 3:]])
    return Image.fromarray((out * 255).astype(np.uint8))


def main():
    # base colours from the front + 3/4 front body / head pieces (first pass cut only)
    pieces = []
    for v in ("front", "q_front"):
        cut = CS.cut_by_cells(CS.key(os.path.join(RAW, v + ".png")), DL.CELLS, DL.FIG_BOX)
        pieces += [cut["body"][0], cut["head"][0]]
    bases = measure_bases(pieces)
    print("bases", bases)
    bl = [hexrgb(bases["coat"]), hexrgb(bases["light"])]
    items = []      # (img, mask, meta) — meta["mirror_of"] = index of a shared atlas image (mirrored UV)
    rig = {}
    body_pivot = {}
    for vi, v in enumerate(VIEWS):
        r = run_view(v, bases)
        pl, fy, cx = r["pl"], r["feet_y"], r["cx"]
        k = FIG / (fy + 1)

        def P(x, y):           # figure px -> rig
            return [(x - cx) * k, (fy - y) * k]

        def rect(q):
            x0, y1 = P(q["x"], q["y"])
            x1, y0 = P(q["x"] + q["w"], q["y"] + q["h"])
            return [x0, y0, x1, y1]

        br = rect(pl["body"])
        bpiv = [(br[0] + br[2]) / 2, (br[1] + br[3]) / 2]
        body_pivot[v] = [round(x, 2) for x in bpiv]
        hr = rect(pl["head"])
        neck = [(hr[0] + hr[2]) / 2, hr[1] + 0.12 * (hr[3] - hr[1])]
        legs = {}
        for ln in LEGS:
            lr = rect(pl[ln])
            foot = max(0.0, lr[1])
            # joint inside the body: 30 % below the leg top (the hidden top swings under the body)
            piv = [(lr[0] + lr[2]) / 2, lr[3] - 0.3 * (lr[3] - lr[1])]
            legs[ln] = {"pivot": [round(x, 2) for x in piv], "len": round(piv[1] - foot, 2), "foot": round(foot, 2)}
        hip = np.mean([legs["leg_ha"]["pivot"], legs["leg_hb"]["pivot"]], axis=0).tolist()
        sh = np.mean([legs["leg_fa"]["pivot"], legs["leg_fb"]["pivot"]], axis=0).tolist()
        rig[v] = {"body_pivot": body_pivot[v], "hip": [round(x, 2) for x in hip], "shoulder": [round(x, 2) for x in sh],
                  "body_bottom": round(br[1], 2), "body_top": round(br[3], 2), "head_h": round(hr[3] - hr[1], 2),
                  "head_w": round(hr[2] - hr[0], 2), "neck": [round(x, 2) for x in neck], "legs": legs,
                  "fig_px": int(fy + 1)}
        eyes_rig = [9999.0, 0.0, 9999.0, 0.0]
        hq = pl["head"]
        for i, (ex, ey) in enumerate(r["eyes"][:2]):
            e = P(hq["x"] + ex * hq["s"], hq["y"] + ey * hq["s"])
            eyes_rig[2 * i], eyes_rig[2 * i + 1] = round(e[0], 2), round(e[1], 2)
        if r["eyes"] and len(r["eyes"]) == 1:
            eyes_rig[2], eyes_rig[3] = 9999.0, 0.0
        order = ORDER[v]

        def add(name, cls, kind, group, slot, layer_key, piv, far=0, parent=(0.0, 0.0), side=0, eyes=None, dye=True):
            q = pl[name]
            rr = rect(q)
            w = max(2, int(round((rr[2] - rr[0]) * ATLAS_K)))
            h = max(2, int(round((rr[3] - rr[1]) * ATLAS_K)))
            img = np.asarray(Image.fromarray(q["img"]).resize((w, h), Image.LANCZOS))
            mask = dye_mask(img, bl) if dye else np.zeros(img.shape[:2] + (3,), np.float32)
            items.append((img, mask, {
                "view": vi, "part": name, "cls": cls, "kind": kind, "group": group, "slot": slot,
                "layer": order.index(layer_key), "rect": [round(x, 2) for x in rr], "pivot": [round(x, 2) for x in piv],
                "far": far, "parent": [round(float(x), 2) for x in parent], "side": side,
                "eyes": eyes if eyes is not None else [9999.0, 0.0, 9999.0, 0.0]}))

        add("body", CLS["body"], 0, 0, 1, "body", bpiv)
        for ki, hn in enumerate(HEADS):
            if hn in pl:
                add(hn, CLS["head"], ki, 1, 2, "head", neck, parent=((hr[0] + hr[2]) / 2, hr[2] - hr[0]), eyes=eyes_rig)
        for ki, en in enumerate(EARS):
            for side in ("a", "b"):
                n = en + "_" + side
                rx, ry, _ = r["roots"][side]
                root = P(rx, ry)
                lk = ("ear_hi_" if en == "ear_floppy" else "ear_lo_") + side
                far = 1 if (v in ("q_front", "q_back") and side == "b") else 0
                add(n, CLS["ear"], ki, 2, SLOT["ear_" + side], lk, root, far=far, parent=neck, side=0 if side == "a" else 1)
        troot = P(*r["troot"])
        for ki, tn in enumerate(TAILS):
            add(tn, CLS["tail"], ki, 3, 5, "tail", troot)
        for ln in LEGS:
            add(ln, CLS["leg"], 0, 0, SLOT[ln], ln, legs[ln]["pivot"], far=1 if ln in FAR_LEGS[v] else 0)
        if "sweater" in pl:
            add("sweater", CLS["sweater"], 0, 4, 1, "sweater", bpiv, dye=False)
        # check image
        fig = Image.fromarray(r["fig"])
        doll = compose(r["fig"].shape, pl, order_names(v, "ear_floppy", "tail_curl"))
        alt = compose(r["fig"].shape, pl, order_names(v, "ear_pointy", "tail_straight", "head_bark", True))
        alt2 = compose(r["fig"].shape, pl, order_names(v, "ear_folded", "tail_curl", "head_sleep"))
        dm = dye_mask(np.asarray(doll), bl)
        white = recolour_preview(doll, dm, bases)
        black = recolour_preview(doll, dm, bases, "4b423e", "c99c6c")
        W = fig.width
        panels = [fig, doll, None, white, black, alt, alt2]
        chk = Image.new("RGBA", ((W + 10) * len(panels), fig.height), (255, 255, 255, 255))
        bg = Image.new("RGBA", fig.size, (255, 255, 255, 255))
        for i, p in enumerate(panels):
            if p is None:
                p = Image.blend(Image.alpha_composite(bg, fig), Image.alpha_composite(bg, doll), 0.5)
            chk.alpha_composite(p, (i * (W + 10), 0))
        from PIL import ImageDraw
        d = ImageDraw.Draw(chk)
        ox = W + 10
        for ln in LEGS:
            px_, py_ = legs[ln]["pivot"]
            gx, gy = ox + px_ / k + cx, fy - py_ / k
            d.ellipse((gx - 4, gy - 4, gx + 4, gy + 4), outline=(255, 0, 0, 255), width=2)
        for e in range(2):
            if eyes_rig[2 * e] < 9000:
                gx, gy = ox + eyes_rig[2 * e] / k + cx, fy - eyes_rig[2 * e + 1] / k
                d.ellipse((gx - 6, gy - 6, gx + 6, gy + 6), outline=(0, 0, 255, 255), width=2)
        tx, ty = r["troot"]
        d.ellipse((ox + tx - 4, ty - 4, ox + tx + 4, ty + 4), outline=(255, 0, 255, 255), width=2)
        d.line((ox, fy, ox + W, fy), fill=(0, 160, 0, 255))
        chk.convert("RGB").save(os.path.join(RAW, "check_%s.png" % v))
    # pack (tallest first)
    order = sorted(range(len(items)), key=lambda i: -items[i][0].shape[0])
    x = y = shelf = 0
    pos = {}
    for i in order:
        h, w = items[i][0].shape[:2]
        if x + w + 2 * PAD > ATLAS_W:
            x, y, shelf = 0, y + shelf, 0
        pos[i] = (x + PAD, y + PAD)
        x += w + 2 * PAD
        shelf = max(shelf, h + 2 * PAD)
    H = 1 << int(np.ceil(np.log2(y + shelf)))
    atlas = np.zeros((H, ATLAS_W, 4), np.uint8)
    mask = np.zeros((H, ATLAS_W, 4), np.uint8)
    quads = []
    for i, (img, m, meta) in enumerate(items):
        px, py = pos[i]
        h, w = img.shape[:2]
        atlas[py:py + h, px:px + w] = img
        mask[py:py + h, px:px + w, :3] = (m * 255).astype(np.uint8)
        mask[py:py + h, px:px + w, 3] = img[..., 3]
        meta["uv"] = [px / ATLAS_W, py / H, (px + w) / ATLAS_W, (py + h) / H]
        quads.append(meta)
    atlas = dilate(atlas)
    mk = dilate(np.dstack([mask[..., :3], mask[..., 3]]))
    mask[..., :3] = mk[..., :3]
    mask[..., 3] = 255
    Image.fromarray(atlas).save(os.path.join(ART, "dog_atlas.png"))
    Image.fromarray(mask).save(os.path.join(ART, "dog_mask.png"))
    json.dump({"fig": FIG, "atlas": [ATLAS_W, H], "views": VIEWS, "ears": EARS, "tails": TAILS, "heads": HEADS,
               "base": bases, "body_pivot": body_pivot, "rig": rig, "quads": quads},
              open(os.path.join(ART, "dog_lib.json"), "w"), indent=0)
    print("atlas", ATLAS_W, "x", H, "quads", len(quads))


def dilate(rgba):
    """bleed colour into the transparent padding (no dark fringes in the mipmaps)"""
    a = rgba[..., 3] > 0
    out = rgba.copy()
    for _ in range(PAD + 2):
        m = out[..., 3] > 0
        acc = np.zeros(out.shape[:2] + (3,), np.float32)
        n = np.zeros(out.shape[:2], np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sm = np.roll(m, (dy, dx), (0, 1))
            acc += np.roll(out[..., :3], (dy, dx), (0, 1)) * sm[..., None]
            n += sm
        grow = (~m) & (n > 0)
        out[..., :3][grow] = (acc[grow] / n[grow][:, None]).astype(np.uint8)
        out[..., 3][grow] = 1
    out[..., 3] = np.where(a, rgba[..., 3], 0)
    return out


if __name__ == "__main__":
    main()
