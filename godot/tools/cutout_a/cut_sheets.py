"""Cutout prototype v2 (concept A) — step 1+2: key the part sheets, cut the parts by TEMPLATE CELL (no manual index map),
and AUTO-PLACE every part over the assembled figure (multi-scale colour-class matching, numpy FFT only).

usage: python3 cut_sheets.py [set ...]     (default: every set that has 4 views in raw/)
  set "a" = raw/<view>.png, set "b" = raw/<view>_b.png, ...; props: raw/props.png, raw/props_b.png
out: art/cutout/woman_a/parts/<set>/<view>/<part>.png (+ figure.png) and parts/<set>/<view>/place.json:
     {part: {"sx", "sy", "x", "y", "score", "vis"}}  x,y = top-left of the scaled part in FIGURE coordinates
     (sheet px, origin = feet centre, y down), plus "figure": {"w","h","feet_y","cx"}
     raw/<set>_<view>_check.png = figure | auto-assembled doll | overlay (eyeball check)
2026-11-08."""
import json, os, sys
from collections import deque
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sheet_layout as L

ART = L.ART
RAW = os.path.join(ART, "raw")
PARTS = os.path.join(ART, "parts")
VIEWS = ["front", "q_front", "q_back", "back"]
# draw order used only for the check image (the rig has its own per-view order)
CHECK_ORDER = ["leg_a", "leg_b", "tail", "body", "arm_a", "arm_b", "sleeve_a", "sleeve_b", "head", "knot"]


def raw_path(s, v):
    return os.path.join(RAW, v + ("" if s == "a" else "_" + s) + ".png")


def key(path):
    """chroma key by 'greenness' g - max(r, b): pure #00FF00 = 255, template guide lines (#00B000 and darker) >= ~80,
    the sage-green tunic of set c ~25 (kept)."""
    im = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    if im.shape[:2] != (L.H, L.W):
        im = np.asarray(Image.fromarray(im.astype(np.uint8)).resize((L.W, L.H), Image.LANCZOS)).astype(np.float32)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    green = g - np.maximum(r, b)
    a = np.clip((85.0 - green) / 40.0, 0.0, 1.0)
    g2 = np.where(green > 0, np.minimum(g, np.maximum(r, b) + 0.3 * np.maximum(green, 0) * a), g)   # despill
    a = a * (1.0 - guide_lines(a > 0.3))
    return np.dstack([r, g2, b, a * 255.0]).astype(np.uint8)


def _shift_min(m, r, axis):
    out = m.copy()
    for d in range(1, r + 1):
        out &= np.roll(m, d, axis) & np.roll(m, -d, axis)
    return out


def _shift_max(m, r, axis):
    out = m.copy()
    for d in range(1, r + 1):
        out |= np.roll(m, d, axis) | np.roll(m, -d, axis)
    return out


def _runs(m, axis, n):
    """pixels inside a straight run of >= n set pixels along axis"""
    mm = m if axis == 1 else m.T
    out = np.zeros_like(mm)
    for y in range(mm.shape[0]):
        row = mm[y]
        if not row.any():
            continue
        d = np.diff(np.concatenate([[0], row.astype(np.int8), [0]]))
        st, en = np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]
        for a0, a1 in zip(st, en):
            if a1 - a0 >= n:
                out[y, a0:a1] = True
    return out if axis == 1 else out.T


def guide_lines(m, r=3, n=80):
    """template guide lines copied by the model: thin (< 2r+1 px) AND long straight (>= n px) -> 1.0"""
    opened = _shift_max(_shift_max(_shift_min(_shift_min(m, r, 0), r, 1), r, 0), r, 1)
    thin = m & ~opened
    th = _shift_max(thin, 1, 0)
    tv = _shift_max(thin, 1, 1)
    lines = (_runs(th, 1, n) | _runs(tv, 0, n)) & thin
    return _shift_max(_shift_max(lines, 1, 0), 1, 1).astype(np.float32)


def components(alpha, step=2, min_cells=40):
    h, w = alpha.shape
    small = alpha[: h - h % step, : w - w % step].reshape(h // step, step, w // step, step).max(axis=(1, 3)) > 128
    lab = np.full(small.shape, -1, np.int32)
    comps = []
    H, W = small.shape
    ys, xs = np.nonzero(small)
    for y, x in zip(ys, xs):
        if lab[y, x] >= 0:
            continue
        q = deque([(y, x)]); lab[y, x] = len(comps); n = 0
        y0 = y1 = y; x0 = x1 = x
        while q:
            cy, cx = q.popleft(); n += 1
            y0 = min(y0, cy); y1 = max(y1, cy); x0 = min(x0, cx); x1 = max(x1, cx)
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < H and 0 <= nx < W and small[ny, nx] and lab[ny, nx] < 0:
                    lab[ny, nx] = len(comps); q.append((ny, nx))
        comps.append({"n": n, "box": [x0 * step, y0 * step, (x1 + 1) * step, (y1 + 1) * step]})
    keep = [i for i, c in enumerate(comps) if c["n"] >= min_cells]
    return lab, comps, keep, step


def cut_by_cells(rgba, cells, fig_box=None):
    """-> {name: (crop_rgba, (x0, y0))}. Each component goes to the cell (or figure box) holding its centre."""
    lab, comps, keep, step = components(rgba[..., 3])
    boxes = list(cells) + ([("FIG", "figure", fig_box)] if fig_box else [])
    owner = {}
    for i in keep:
        x0, y0, x1, y1 = comps[i]["box"]
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        for _, name, b in boxes:
            if b[0] <= cx <= b[2] and b[1] <= cy <= b[3]:
                owner.setdefault(name, []).append(i)
                break
    out = {}
    for name, ids in owner.items():
        sel = np.isin(lab, ids)
        full = np.kron(sel, np.ones((step, step), bool))
        mask = np.zeros(rgba.shape[:2], bool); mask[: full.shape[0], : full.shape[1]] = full
        ys, xs = np.where(mask & (rgba[..., 3] > 8))
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        part = rgba[y0:y1, x0:x1].copy()
        part[..., 3] = np.where(mask[y0:y1, x0:x1], part[..., 3], 0)
        out[name] = (part, (int(x0), int(y0)))
    return out


# ---------- auto placement ----------
def classes(rgb_list, k=9, iters=12, seed=0):
    """k-means palette over figure pixels (ink included) -> centres (k,3)"""
    px = np.concatenate(rgb_list).astype(np.float32)
    rng = np.random.default_rng(seed)
    px = px[rng.choice(len(px), min(len(px), 40000), replace=False)]
    c = px[rng.choice(len(px), k, replace=False)]
    for _ in range(iters):
        d = ((px[:, None, :] - c[None]) ** 2).sum(-1)
        a = d.argmin(1)
        for j in range(k):
            if (a == j).any():
                c[j] = px[a == j].mean(0)
    return c


def onehot(rgba, cen):
    rgb = rgba[..., :3].astype(np.float32)
    d = ((rgb[..., None, :] - cen[None, None]) ** 2).sum(-1)
    a = d.argmin(-1)
    on = rgba[..., 3] > 128
    return np.stack([(a == j) & on for j in range(len(cen))]).astype(np.float32)


def resize_rgba(p, sx, sy):
    w = max(2, int(round(p.shape[1] * sx))); h = max(2, int(round(p.shape[0] * sy)))
    return np.asarray(Image.fromarray(p).resize((w, h), Image.BILINEAR))


def fair(agree, n):
    """scale-fair score: + agreeing pixels, - half of the disagreeing ones (a plain fraction prefers tiny scales)"""
    return agree - 0.5 * (n - agree)


def xcorr(F, P):
    """valid cross-correlation of F (C,H,W) with P (C,h,w), summed over channels -> (H-h+1, W-w+1)"""
    C, H, W = F.shape
    _, h, w = P.shape
    sh = (H, W)
    acc = np.zeros(sh)
    for c in range(C):
        if P[c].sum() == 0:
            continue
        acc += np.fft.irfft2(np.fft.rfft2(F[c], sh) * np.conj(np.fft.rfft2(P[c], sh)), sh)
    return acc[: H - h + 1, : W - w + 1]


def place(fig, part, cen, ds=4, scales=None, win=None, uniform=False, fixed=None):
    """best (sx, sy, x, y) of part over fig; score = fraction of part pixels whose colour class agrees.
    win = (x0, y0, x1, y1) allowed region for the part CENTRE (figure px), or for "bottom" mode (cx range, bottom-edge range)
    as ("bottom", x0, x1, b0, b1) — legs: only the shoe shows, so the bottom edge is pinned near the soles."""
    scales = [fixed] if fixed else (scales or [round(0.8 + 0.05 * i, 2) for i in range(10)])
    n0 = float((part[..., 3] > 128).sum())

    def allowed(sc, ph, pw, k):
        if win is None:
            return sc
        H, W = sc.shape
        ys = np.arange(H)[:, None] * k
        xs = np.arange(W)[None, :] * k
        cx = xs + pw * k / 2
        if win[0] == "bottom":
            by = ys + ph * k
            ok = (cx >= win[1]) & (cx <= win[2]) & (by >= win[3]) & (by <= win[4])
        else:
            cy = ys + ph * k / 2
            ok = (cx >= win[0]) & (cx <= win[2]) & (cy >= win[1]) & (cy <= win[3])
        return np.where(ok, sc, -1.0)
    Ff = onehot(fig, cen)
    Fd = Ff[:, ::ds, ::ds]
    best = (-1, None)
    for sx in scales:
        for sy in scales:
            if abs(sx - sy) > (0.0 if uniform else 0.11):
                continue
            p = resize_rgba(part, sx / ds, sy / ds)
            P = onehot(p, cen)
            n = P.sum()
            if n < 4 or p.shape[0] >= Fd.shape[1] or p.shape[1] >= Fd.shape[2]:
                continue
            sc = allowed(fair(xcorr(Fd, P), n) / (n0 / ds / ds), p.shape[0], p.shape[1], ds)
            j = np.unravel_index(np.argmax(sc), sc.shape)
            if sc[j] > best[0]:
                best = (sc[j], (sx, sy, j[1] * ds, j[0] * ds))
    # refine at full resolution around the coarse answer
    s0, (sx0, sy0, x0, y0) = best
    best = (-1, None)
    rr = [0.0] if fixed else np.arange(-0.04, 0.041, 0.01)
    for sx in sx0 + np.array(rr):
        for sy in (sy0 + np.array(rr)) if not uniform else [None]:
            sy = sx if sy is None else sy
            p = resize_rgba(part, sx, sy)
            P = onehot(p, cen)
            n = P.sum()
            m = 2 * ds + 4
            ya, xa = max(0, y0 - m), max(0, x0 - m)
            sub = Ff[:, ya: y0 + m + p.shape[0], xa: x0 + m + p.shape[1]]
            if sub.shape[1] < p.shape[0] or sub.shape[2] < p.shape[1]:
                continue
            sc = fair(xcorr(sub, P), n) / n0
            if win is not None:
                H2, W2 = sc.shape
                yy = ya + np.arange(H2)[:, None]; xx = xa + np.arange(W2)[None, :]
                cx = xx + p.shape[1] / 2
                if win[0] == "bottom":
                    ok = (cx >= win[1]) & (cx <= win[2]) & (yy + p.shape[0] >= win[3]) & (yy + p.shape[0] <= win[4])
                else:
                    cy = yy + p.shape[0] / 2
                    ok = (cx >= win[0]) & (cx <= win[2]) & (cy >= win[1]) & (cy <= win[3])
                sc = np.where(ok, sc, -1.0)
            j = np.unravel_index(np.argmax(sc), sc.shape)
            if sc[j] > best[0]:
                best = (float(sc[j]), (float(sx), float(sy), int(xa + j[1]), int(ya + j[0])))
    return best


def windows(name, pl, W, H, feet_y, cx, hat=False):
    """search windows from the reliable big parts (body, head) — the template fixes WHERE a part is, not just its size"""
    if name == "body":
        return (0, H * 0.25, W, H * 0.75)
    if name == "head":
        return (0, 0, W, H * 0.35)
    b = pl["body"]; bw, bh = b["sx"] * 0, 0
    bx0, by0 = b["x"], b["y"]
    bw = b.get("w", W); bh = b.get("h", H * 0.6)
    h = pl["head"]
    side_a = name.endswith("_a")
    xa0, xa1 = (0, cx + W * 0.1) if side_a else (cx - W * 0.1, W)
    if name.startswith("sleeve") or name.startswith("arm"):
        # outer side of the body: the sleeve / arm centre is outside the middle 40% of the body
        xa0, xa1 = (-W, bx0 + 0.3 * bw) if side_a else (bx0 + 0.7 * bw, 2 * W)
    if name.startswith("sleeve"):
        return (xa0, by0 - 0.05 * bh, xa1, by0 + 0.4 * bh)
    if name.startswith("arm"):
        return (xa0, by0 + 0.2 * bh, xa1, by0 + 0.75 * bh)
    if name.startswith("leg"):
        return ("bottom", xa0, xa1, feet_y - 40, feet_y + 6)
    # knot / tail: around the head
    hx0, hy0, hw, hh = h["x"], h["y"], h.get("w", 300), h.get("h", 300)
    if name == "knot" and hat:   # sets b-d: this cell is the HEADWEAR (hat / cap / hood) — sits over the top of the head
        return (hx0 + 0.15 * hw, hy0 - 0.25 * hh, hx0 + 0.85 * hw, hy0 + 0.35 * hh)
    if name == "knot":     # the scarf knot sits low on the image-left side of the head in every view of set a
        return (hx0 - 0.3 * hw, hy0 + 0.5 * hh, hx0 + 0.3 * hw, hy0 + 1.1 * hh)
    return (hx0 - 0.3 * hw, hy0 + 0.35 * hh, hx0 + 1.3 * hw, hy0 + 1.1 * hh)


def hat_from_figure(fig, cut, pl, od):
    """Headwear = cut straight out of the ASSEMBLED figure (it is the top layer, so what shows is all we need).
    The model's separate hat pieces were drawn in another perspective (straw-hat underside, hood ring) — 2026-11-08."""
    piece = cut["knot"][0]
    op = piece[..., 3] > 200
    rgb = piece[..., :3].astype(np.float32)
    l = rgb.mean(-1)
    body_px = rgb[op & (l > np.percentile(l[op], 35))]
    hat = np.median(body_px, axis=0)
    F = fig[..., :3].astype(np.float32)
    lum = lambda c: c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114
    lf = np.maximum(lum(F), 1.0)
    lb = float(lum(hat))
    d = np.abs(F / lf[..., None] - hat / lb).sum(-1)
    r = lf / lb
    # skin of the bare head (its most common bright colour) — straw and skin are close, so a pixel nearer skin is not hat
    hp = cut["head"][0]
    hrgb = hp[..., :3][hp[..., 3] > 200].astype(np.float32)
    hrgb = hrgb[hrgb.mean(-1) > 120]     # bright pixels only (hair is darker than skin in every set)
    q = (hrgb // 16).astype(np.int32)
    keys, cnt = np.unique(q[:, 0] * 256 + q[:, 1] * 16 + q[:, 2], return_counts=True)
    top = keys[np.argmax(cnt)]
    skin = hrgb[(q[:, 0] * 256 + q[:, 1] * 16 + q[:, 2]) == top].mean(0)
    ds = np.abs(F / lf[..., None] - skin / max(float(lum(skin)), 1.0)).sum(-1)
    m = (d < 0.22) & (r > 0.6) & (r < 1.25) & (fig[..., 3] > 128) & (d < ds)
    h = pl["head"]
    y1 = int(h["y"] + 1.0 * h["h"])
    m[y1:] = False
    # keep the biggest blob (+ blobs touching it after a small dilation) — drops cream collars / eye highlights
    from collections import deque
    lab = np.full(m.shape, -1, np.int32); sizes = []
    for y, x in zip(*np.nonzero(m)):
        if lab[y, x] >= 0:
            continue
        q = deque([(y, x)]); lab[y, x] = len(sizes); n = 0
        while q:
            cy, cx = q.popleft(); n += 1
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < m.shape[0] and 0 <= nx < m.shape[1] and m[ny, nx] and lab[ny, nx] < 0:
                    lab[ny, nx] = len(sizes); q.append((ny, nx))
        sizes.append(n)
    if not sizes:
        return
    # blobs that are big enough AND sit on the upper half of the head (drops cream collars / neck openings)
    cy = np.zeros(len(sizes))
    ys_, xs_ = np.nonzero(lab >= 0)
    np.add.at(cy, lab[ys_, xs_], ys_)
    cy /= np.maximum(np.array(sizes), 1)
    top_ok = cy < h["y"] + 0.55 * h["h"]
    mx = max(n for i, n in enumerate(sizes) if top_ok[i]) if top_ok.any() else max(sizes)
    big = [i for i, n in enumerate(sizes) if n >= 0.08 * mx and top_ok[i]]
    m = np.isin(lab, big)
    # fill holes inside the hat (band, stitches) and grow over its own ink outline
    for _ in range(5):
        g = m.copy()
        g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]
        dark = lum(F) < 0.75 * lb
        m = m | (g & (dark | (d < 0.6)))
    # fill small enclosed holes (hat band, knit ribs) — a big hole (the face inside a hood) stays open
    hole = ~m
    lab2 = np.full(m.shape, -1, np.int32); hs = []; border = set()
    for y, x in zip(*np.nonzero(hole)):
        if lab2[y, x] >= 0:
            continue
        q2 = deque([(y, x)]); lab2[y, x] = len(hs); n = 0
        while q2:
            cy, cx = q2.popleft(); n += 1
            if cy in (0, m.shape[0] - 1) or cx in (0, m.shape[1] - 1):
                border.add(len(hs))
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < m.shape[0] and 0 <= nx < m.shape[1] and hole[ny, nx] and lab2[ny, nx] < 0:
                    lab2[ny, nx] = len(hs); q2.append((ny, nx))
        hs.append(n)
    area = m.sum()
    small = [i for i, n in enumerate(hs) if i not in border and n < 0.25 * area]
    m = m | (np.isin(lab2, small) & (fig[..., 3] > 128))
    ys, xs = np.nonzero(m)
    x0, x1, y0, yb = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    part = fig[y0:yb, x0:x1].copy()
    part[..., 3] = np.where(m[y0:yb, x0:x1], part[..., 3], 0)
    Image.fromarray(part).save(os.path.join(od, "knot.png"))
    cut["knot"] = (part, (0, 0))
    pl["knot"] = {"sx": 1.0, "sy": 1.0, "x": int(x0), "y": int(y0), "score": "figure", "w": int(x1 - x0), "h": int(yb - y0), "flip": False}
    print("hat cut from figure", pl["knot"])


def compose(fig_shape, parts, pl, order):
    canvas = Image.new("RGBA", (fig_shape[1], fig_shape[0]), (0, 0, 0, 0))
    for name in order:
        if name not in pl or name not in parts:
            continue
        q = pl[name]
        p = Image.fromarray(resize_rgba(parts[name][0], q["sx"], q["sy"]))
        canvas.alpha_composite(p, (q["x"], q["y"])) if q["x"] >= 0 and q["y"] >= 0 else canvas.paste(p, (q["x"], q["y"]), p)
    return canvas


def run_set(s):
    figs = {}
    for v in VIEWS:
        rgba = key(raw_path(s, v))
        cut = cut_by_cells(rgba, L.CELLS, L.FIG_BOX)
        figs[v] = cut
    cen = classes([figs[v]["figure"][0][figs[v]["figure"][0][..., 3] > 200][:, :3] for v in VIEWS])
    report = {}
    for v in VIEWS:
        cut = figs[v]
        fig, (fx, fy) = cut["figure"]
        od = os.path.join(PARTS, s, v)
        os.makedirs(od, exist_ok=True)
        Image.fromarray(fig).save(os.path.join(od, "figure.png"))
        a = fig[..., 3] > 128
        ys, xs = np.nonzero(a)
        feet_y = int(ys.max())
        # feet centre: mean x of the lowest 6% rows of the figure (both shoes)
        low = a[int(feet_y - 0.06 * fig.shape[0]):feet_y + 1]
        cx = float(np.nonzero(low)[1].mean())
        pl = {"figure": {"w": fig.shape[1], "h": fig.shape[0], "feet_y": feet_y, "cx": cx, "sheet_xy": [fx, fy]}}
        Wf, Hf = fig.shape[1], fig.shape[0]
        order = ["body", "head"] + [n for n in cut if n not in ("figure", "body", "head")]
        for name in order:
            if name not in cut:
                continue
            part = cut[name][0]
            Image.fromarray(part).save(os.path.join(od, name + ".png"))
            win = windows(name, pl, Wf, Hf, feet_y, cx, hat=(s != "a"))
            # partly hidden parts (arm stubs under the sleeve, legs under the skirt, knot / hair tail behind the head) cannot
            # measure their own size -> they use the sheet's scale measured on the big, fully visible parts (body + head)
            fixed = None
            if name.split("_")[0] in ("arm", "leg", "tail", "knot") and "head" in pl and not (name == "knot" and s != "a"):
                fixed = round((pl["body"]["sx"] + pl["body"]["sy"] + pl["head"]["sx"] + pl["head"]["sy"]) / 4, 3)
            sl = [0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.15] if name.startswith("sleeve") else None
            if name == "knot" and s != "a":     # headwear: the model often draws the hat piece smaller than worn
                sl = [round(0.75 + 0.07 * i, 2) for i in range(14)]
            score, (sx, sy, x, y) = place(fig, part, cen, win=win, uniform=name.startswith("sleeve") or (name == "knot" and s != "a"), fixed=fixed, scales=sl)
            flip = False
            if name in ("knot", "tail") and not (name == "knot" and s != "a"):    # small pieces are sometimes drawn mirrored on the sheet -> try the flip too
                s2, r2 = place(fig, part[:, ::-1].copy(), cen, win=win, fixed=fixed)
                if s2 > score + 0.05:
                    score, (sx, sy, x, y), flip = s2, r2, True
                    part = part[:, ::-1].copy()
                    Image.fromarray(part).save(os.path.join(od, name + ".png"))
                    cut[name] = (part, cut[name][1])
            # visible fraction ~ how much of the part shows in the figure (low = occluded / behind)
            pl[name] = {"sx": round(sx, 3), "sy": round(sy, 3), "x": x, "y": y, "score": round(score, 3),
                        "w": int(round(part.shape[1] * sx)), "h": int(round(part.shape[0] * sy)), "flip": flip}
            print(s, v, name, pl[name])
        if s != "a" and "knot" in cut and "head" in pl:
            hat_from_figure(fig, cut, pl, od)
        json.dump(pl, open(os.path.join(od, "place.json"), "w"), indent=1)
        doll = compose(fig.shape, cut, pl, CHECK_ORDER)
        f = Image.fromarray(fig)
        W = fig.shape[1]
        chk = Image.new("RGBA", (W * 3 + 20, fig.shape[0]), (255, 255, 255, 255))
        chk.alpha_composite(f, (0, 0)); chk.alpha_composite(doll, (W + 10, 0))
        ov = Image.blend(Image.alpha_composite(Image.new("RGBA", f.size, (255, 255, 255, 255)), f),
                         Image.alpha_composite(Image.new("RGBA", f.size, (255, 255, 255, 255)), doll), 0.5)
        chk.alpha_composite(ov, (2 * W + 20, 0))
        chk.save(os.path.join(RAW, "%s_%s_check.png" % (s, v)))
        report[v] = pl
    if s in HAT_FROM_BACK:
        hats_front_from_back(s, report)
    return report


# rigid, roughly symmetric hats: the front-facing view of the hat = its back view (front) / mirrored 3/4-back view (3/4 front).
# The figure cut of a hat seen from the front is broken by the face and hair; the back view shows the whole hat. Hoods stay cut.
HAT_FROM_BACK = {"b", "c"}


def hats_front_from_back(s, report):
    for v, src, flip in (("front", "back", False), ("q_front", "q_back", True)):
        od = os.path.join(PARTS, s, v)
        hb = Image.open(os.path.join(PARTS, s, src, "knot.png"))
        if flip:
            hb = hb.transpose(Image.FLIP_LEFT_RIGHT)
        q = report[v]["knot"]
        hd = report[v]["head"]
        hs = report[src]["head"]
        qs = report[src]["knot"]
        k = hd["w"] / hs["w"]                       # same hat, scaled by the head width ratio of the two views
        hb = hb.resize((max(2, int(round(hb.width * k))), max(2, int(round(hb.height * k)))), Image.LANCZOS)
        hb.save(os.path.join(od, "knot.png"))
        # horizontally: same offset from the head centre as in the source view (mirrored for 3/4); vertically: brim bottom at
        # the brow line of the bare head (top-down camera: the brim must not cover the eyes)
        off = (qs["x"] + qs["w"] / 2) - (hs["x"] + hs["w"] / 2)
        if flip:
            off = -off
        cxh = hd["x"] + hd["w"] / 2 + off * k
        q.update({"w": hb.width, "h": hb.height, "x": int(cxh - hb.width / 2), "y": int(hd["y"] + 0.4 * hd["h"] - hb.height),
                  "score": "from_" + src})
        report[v]["knot"] = q
        json.dump(report[v], open(os.path.join(od, "place.json"), "w"), indent=1)
        print("hat", s, v, "from", src, q)


def run_props(tag, names):
    p = os.path.join(RAW, "props%s.png" % ("" if tag == "a" else "_" + tag))
    rgba = key(p)
    cells = [(c[0], n, c[2]) for c, n in zip(L.PROP_CELLS, names)]
    cut = cut_by_cells(rgba, cells)
    od = os.path.join(PARTS, "props")
    os.makedirs(od, exist_ok=True)
    for name, (part, _) in cut.items():
        Image.fromarray(part).save(os.path.join(od, name + ".png"))
        print("prop", name, part.shape)


if __name__ == "__main__":
    sets = sys.argv[1:] or [s for s in "abcd" if all(os.path.exists(raw_path(s, v)) for v in VIEWS)]
    for s in sets:
        if s == "props":
            run_props("a", ["bread", "twigs", "basket", "bread_q", "twigs_q", "basket_q"])
            if os.path.exists(os.path.join(RAW, "props_b.png")):
                run_props("b", ["hoe", "sickle", "rake", "mallet", "wheat", "bucket"])
        else:
            run_set(s)
