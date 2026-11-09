"""Method-C resident spike (docs/RESIDENTS_2D.md section 7, 2026-11-08): frame sheets -> frame atlas + dye masks + anchors.

usage: python3 build_frames.py            (needs raw/{walk,carry,idle}_{front,q_front,q_back,back}.png)
in : art/cutout/woman_c/raw/<clip>_<view>.png  (gen.sh: 2x4 cells, magenta head placeholder, chroma green)
out: art/cutout/woman_c/frames_atlas.png  body+clothes per frame (the magenta head removed)
     art/cutout/woman_c/frames_mask0.png  dye weights R skin  G main  B second(cream)  A trim
     art/cutout/woman_c/frames_mask1.png  dye weights R legwear  G shoe  B sack(not dyed; drawn again over the head)  A far leg (3/4, darkened)
     art/cutout/woman_c/frames.json       per frame: uv rect, head anchor (chin, rig units, origin = soles centre, y up),
                                          hand anchors, sack box; per clip: frame count, stride; base colours
     raw/check_<clip>_<view>.png          aligned frames | dye-class view (eyeball check, not used by the game)
Per frame normalisation: soles (lowest opaque row) -> y 0; the head placeholder centre -> x 0 (the AI drifts figures
inside their cells; the head is the steadiest point); scale per SHEET from the median placeholder diameter -> D_RIG, so
every sheet / view has the same head size and the head overlay fits all of them."""
import json, os, sys
from collections import deque
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "cutout_a"))
import cut_sheets as C   # noqa: E402  key() + guide line removal (same 1536x1024 canvas)

ART = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "woman_c"))
RAW = os.path.join(ART, "raw")
VIEWS = ["front", "q_front", "q_back", "back"]
CW, CH = 384, 512
FIG = 920.0            # rig units of the old doll (cut_lib fig) — same screen_h maps to the same height
D_RIG = 300.0          # nominal head placeholder diameter in rig units (head overlay size)
CHIN_RIG = 500.0      # v6: total figure no taller than the old cutout doll (was 560: +7..20% taller in game)       # soles -> chin in rig units (median per sheet) — same body size in every clip / view
PX_PER_RIG = 0.2       # atlas texel density (figure ~920 rig -> ~185 px; at ppu 44 the figure is ~50 px on screen)
# clips in the atlas: (name, sheet, cells)
CLIPS = [("walk", "walk", list(range(8))), ("carry", "carry", list(range(8))),
         ("idle", "idle", [0, 1, 2, 3]), ("hold", "idle", [4, 5, 6, 7])]
POSE_SHEETS = True      # v4: walk / carry sheets traced from pose_ref.py (frame 1 = contact R in every view)
CLIP_CELLS = {cl: cells for cl, _, cells in CLIPS}
TIME_BLEND = 0.0        # frame timing from the measured planted-foot travel (v3) — 0 for the v4 pose-reference sheets (constant planted speed)
CLASSES = ["none", "skin", "main", "second", "trim", "leg", "shoe", "sack"]


def luma(c):
    return c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114


def shift(m, dy, dx):
    out = np.zeros_like(m)
    h, w = m.shape[:2]
    ys, yd = (slice(dy, h), slice(0, h - dy)) if dy >= 0 else (slice(0, h + dy), slice(-dy, h))
    xs, xd = (slice(dx, w), slice(0, w - dx)) if dx >= 0 else (slice(0, w + dx), slice(-dx, w))
    out[ys, xs] = m[yd, xd]
    return out


def dilate(m, r):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dy or dx:
                out |= shift(m, dy, dx)
    return out


def blobs(mask, min_n=30):
    """4-connected components -> list of (n, cy, cx, box) largest first (plain BFS, cells are small)"""
    lab = np.full(mask.shape, -1, np.int32)
    out = []
    H, W = mask.shape
    for y, x in zip(*np.nonzero(mask)):
        if lab[y, x] >= 0:
            continue
        q = deque([(y, x)]); lab[y, x] = len(out); pts = []
        while q:
            cy, cx = q.popleft(); pts.append((cy, cx))
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < H and 0 <= nx < W and mask[ny, nx] and lab[ny, nx] < 0:
                    lab[ny, nx] = len(out); q.append((ny, nx))
        p = np.array(pts)
        out.append((len(pts), p[:, 0].mean(), p[:, 1].mean(), (p[:, 1].min(), p[:, 0].min(), p[:, 1].max(), p[:, 0].max()), lab == len(out)))
    out = [o for o in out if o[0] >= min_n]
    out.sort(key=lambda o: -o[0])
    return out


LEG_ZONE = 0.3


def classify(rgb, alpha, magenta, feet, fig_h):
    """hard dye class per pixel (CLASSES index). Ink & magenta = none. Below the skirt hem (per column): tan -> leg, brown -> shoe."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    L = luma(rgb)
    sat = rgb.max(-1) - rgb.min(-1)
    lab = np.zeros(rgb.shape[:2], np.int8)
    fg = (alpha > 128) & ~magenta
    ink = L < 72
    sack = (sat < 34) & (L > 150) | ((b > r + 15) & (b > g))          # grey-white sack + its blue stripe
    rose = (r - g > 45) & (np.abs(g - b) < 28) & (L < 190) & (L > 100) & (r > 150)
    cream = (L > 196) & (r - b < 80) & (g - b > 22) & ~sack
    skin = (r - b > 85) & (L > 135) & ~rose
    brown = (L >= 72) & (L < 150) & (r - b > 35) & ~rose
    lab[fg & brown] = 4
    lab[fg & skin] = 1
    lab[fg & cream] = 3
    lab[fg & rose] = 2
    lab[fg & sack] = 7
    lab[fg & ink] = 0
    # leftovers (shades between the rules): nearest core colour of a labelled class
    left = fg & ~ink & (lab == 0)
    if left.any():
        cents = {c: np.median(rgb[fg & (lab == c)], axis=0) for c in (1, 2, 3, 4, 7) if (fg & (lab == c)).sum() > 20}
        ks = list(cents)
        d = np.stack([((rgb - cents[k]) ** 2).sum(-1) for k in ks], -1)
        lab[left] = np.array(ks, np.int8)[d.argmin(-1)][left]
    # below the hem: per column, rows under the lowest (solid) rose pixel are legs / shoes — only in the lowest LEG_ZONE of the
    # figure (hands beside the skirt stay skin). Rose speckles inside stockings are opened away first.
    rose_l = (lab == 2)
    rose_l = dilate(~dilate(~rose_l, 2), 2) & rose_l
    H = rgb.shape[0]
    rows = np.arange(H)[:, None]
    hem = np.where(rose_l.any(0), H - 1 - np.argmax(rose_l[::-1], 0), -1)
    hem = np.maximum.reduce([shift(hem[None, :], 0, d)[0] for d in range(-6, 7)])      # widen (skirt edge columns)
    zone = rows > feet - LEG_ZONE * fig_h
    below = zone & ((rows > hem[None, :] + 2) | (hem[None, :] < 0))
    dark = (L < 100)
    lab[below & fg & ~ink & ~sack & dark] = 6
    lab[below & fg & ~ink & ~sack & ~dark] = 5
    # edges: pixels next to ink / the silhouette take the majority class of the nearby core pixels
    core = fg & ~dilate(ink | ~fg, 1)
    edge = fg & ~ink & ~core
    cnt = np.zeros(rgb.shape[:2] + (len(CLASSES),), np.int16)
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            sl = shift(lab, dy, dx)
            sc = shift(core, dy, dx)
            for c in range(1, len(CLASSES)):
                cnt[..., c] += (sc & (sl == c))
    best = cnt.argmax(-1).astype(np.int8)
    lab[edge & (cnt.max(-1) > 0)] = best[edge & (cnt.max(-1) > 0)]
    return lab


def frames_of(sheet):
    rgba = C.key(os.path.join(RAW, sheet + ".png")).astype(np.float32)
    out = []
    for i in range(8):
        cx0, cy0 = (i % 4) * CW, (i // 4) * CH
        cell = rgba[cy0:cy0 + CH, cx0:cx0 + CW].copy()
        rgb, a = cell[..., :3], cell[..., 3]
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        # v3 sheets: the FAR leg is drawn in key colours (cyan stocking, navy shoe) -> stocking / shoe colours one shade darker
        far_st = (b > r + 70) & (g > 110) & (b > 170)
        far_sh = (b > r + 25) & (b > g + 10) & (luma(rgb) < 110) & ~far_st
        legrows = np.arange(CH)[:, None] > 330          # leg zone only (the sack stripe is blue too)
        far_st &= legrows
        far_sh &= legrows
        far = far_st | far_sh
        if far.sum() > 150:
            L_ = luma(rgb)
            st_ref = float(np.median(L_[far_st])) if far_st.any() else 150.0
            sh_ref = float(np.median(L_[far_sh])) if far_sh.any() else 60.0
            # v5: repaint in the normal stocking / shoe colours; the 3/4 far leg is darkened AFTER the dye in the shader
            # (frames_mask1.a = far leg) so the near / far step survives any stocking colour
            STOCK, SHOE = np.array([224.0, 165.0, 113.0]), np.array([124.0, 72.0, 49.0])
            rgb[far_st] = np.clip(STOCK[None] * (L_[far_st] / st_ref)[:, None], 0, 255)
            rgb[far_sh] = np.clip(SHOE[None] * (L_[far_sh] / sh_ref)[:, None], 0, 255)
            fy, fx = np.nonzero(far)
            far_c = (float(fx.mean()), float(fy.max()))
        else:
            far_c = None
        farm = dilate(far, 1) & (("q_front" in sheet) or ("q_back" in sheet))
        mag_core = (r > 170) & (b > 170) & (g < 110)
        mag = (r > 110) & (b > 90) & (b > g + 50) & (r > g + 50) & dilate(mag_core, 3)
        # keep the figure (largest component incl. the head placeholder) — drops copied guide marks & specks
        fgm = a > 100
        bl = blobs(fgm[::2, ::2], 20)
        keep = np.zeros_like(fgm)
        if bl:
            big = bl[0][0]
            for n, _, _, _, m in bl:
                if n > 0.02 * big:
                    keep |= np.kron(m, np.ones((2, 2), bool))[:CH, :CW]
        keep = dilate(keep, 2)
        a = np.where(keep, a, 0)
        ys, xs = np.nonzero(mag_core)
        d = (xs.max() - xs.min() + ys.max() - ys.min() + 2) / 2.0
        head = dict(cx=float(xs.mean()), top=float(ys.min()), bottom=float(ys.max()), d=float(d))
        # anti-aliased ring of the placeholder (magenta + green = grey, half alpha): drop greyish / pinkish pixels around it
        L_ = luma(rgb)
        sat_ = rgb.max(-1) - rgb.min(-1)
        ring = dilate(mag_core, 5) & ~mag_core & (((sat_ < 50) & (L_ > 80) & (L_ < 205)) | ((b > g + 25) & (r > g + 25)) | (a < 200))
        a2 = np.where(mag | ring, 0, a)
        # leftover arcs of the placeholder edge (not connected to the body) -> drop small loose pieces
        bl2 = blobs((a2 > 100)[::2, ::2], 4)
        keep2 = np.zeros_like(fgm)
        if bl2:
            big2 = bl2[0][0]
            for n, _, _, _, m in bl2:
                if n > 0.015 * big2:
                    keep2 |= np.kron(m, np.ones((2, 2), bool))[:CH, :CW]
        a2 = np.where(dilate(keep2, 2), a2, 0)
        a2 = np.where(dilate(mag_core, 7) & (a2 < 230), 0, a2)
        # placeholder drawn with an ink outline (some v2/v3 sheets): drop dark pixels on the circle's rim (R-3 .. R+8)
        my, mx = np.nonzero(mag_core)
        R = (mx.max() - mx.min() + my.max() - my.min()) / 4.0
        yy, xx = np.mgrid[0:CH, 0:CW]
        dd = np.sqrt((xx - mx.mean()) ** 2 + (yy - my.mean()) ** 2)
        a2 = np.where((dd > R - 3) & (dd < R + 8) & (luma(rgb) < 100), 0, a2)
        feet = float(np.nonzero((a2 > 128).any(1))[0].max())
        out.append(dict(rgb=rgb, a=a2, mag=mag, head=head, feet=feet, far=far_c, farm=farm))
    return out


def main():
    sheets = {}
    for clip in ["walk", "carry", "idle"]:
        for v in VIEWS:
            p = os.path.join(RAW, f"{clip}_{v}.png")
            if os.path.exists(p):
                sheets[f"{clip}_{v}"] = frames_of(f"{clip}_{v}")
    # per sheet scale: placeholder diameter -> D_RIG
    placed = {}      # sheet -> list of (rgba_scaled, dye_lab, frame info in rig)
    ext = [0.0, 0.0, 0.0]   # max |x|, max y (body top incl. sack), min y
    for name, frs in sheets.items():
        dmed = float(np.median([f["head"]["d"] for f in frs]))
        # scale per sheet from the body (soles -> chin, median over the frames): the model draws the placeholder at varying size
        # relative to the body (walk q_back ~25% bigger than idle q_front), the head overlay is the same art for all sheets
        chin = float(np.median([f["feet"] - f["head"]["bottom"] for f in frs]))
        k = CHIN_RIG / chin                    # rig per sheet px
        info = []
        for f in frs:
            lab = classify(f["rgb"], f["a"], f["mag"], f["feet"], f["feet"] - f["head"]["top"])
            ox, oy = f["head"]["cx"], f["feet"]
            ys, xs = np.nonzero(f["a"] > 8)
            x0, x1 = (xs.min() - ox) * k, (xs.max() - ox) * k
            ytop = (oy - ys.min()) * k
            ext[0] = max(ext[0], -x0, x1)
            ext[1] = max(ext[1], ytop)
            info.append(dict(k=k, ox=ox, oy=oy, lab=lab, f=f))
        placed[name] = info
        if any(f["far"] for f in frs):
            # alternation check (v3 colour-coded far leg): far foot ahead (+) / behind (-) of the head line, per frame
            print(f"  {name} far foot: " + " ".join("%+.0f" % ((f["far"][0] - f["head"]["cx"]) * k) if f["far"] else "?" for f in frs))
    # colour drift between sheets (the model draws e.g. tan stockings in one sheet, brown in another): per sheet and dye class,
    # scale the colours so the class median matches the median over all sheets -> one base colour per class for the dye
    med = {}
    for name, info in placed.items():
        for ci in range(1, len(CLASSES)):
            px = [it["f"]["rgb"][(it["lab"] == ci) & (it["f"]["a"] > 250)] for it in info]
            px = np.concatenate(px) if px else np.zeros((0, 3))
            if len(px) > 50:
                med[(name, ci)] = np.median(px, 0)
    for ci in range(1, len(CLASSES)):
        if CLASSES[ci] == "sack":
            continue
        allm = [m for (n_, c_), m in med.items() if c_ == ci]
        if not allm:
            continue
        g = np.median(np.array(allm), 0)
        for name, info in placed.items():
            if (name, ci) not in med:
                continue
            ratio = np.clip(g / np.maximum(med[(name, ci)], 1.0), 0.6, 1.6)
            for it in info:
                sel = it["lab"] == ci
                it["f"]["rgb"][sel] = np.clip(it["f"]["rgb"][sel] * ratio, 0, 255)
            if np.abs(ratio - 1).max() > 0.06:
                print(f"  colour fix {name} {CLASSES[ci]}: x{np.round(ratio, 2)}")
        print(f"{name}: k {k:.2f} rig/px, placeholder d {dmed * k:.0f} rig, {dmed:.0f}px (min {min(f['head']['d'] for f in frs):.0f} max {max(f['head']['d'] for f in frs):.0f}) "
              f"figure h {np.median([(f['feet'] - f['head']['top']) for f in frs]):.0f}px")
    W_RIG = 2 * (ext[0] + 20)
    H_RIG = ext[1] + 20
    Y0 = -10.0
    cw, ch = int(np.ceil(W_RIG * PX_PER_RIG)), int(np.ceil((H_RIG - Y0) * PX_PER_RIG))
    order = []
    for clip, sheet, cells in CLIPS:
        for v in VIEWS:
            cs = list(cells)
            if v == "back" and clip in ("walk", "carry") and not POSE_SHEETS:
                # same leg phase in every view (frames 1-4 = her RIGHT foot planted, as in the 3/4 sheets and the front sheet):
                # the back sheets were drawn the other way round -> start at their frame 5 (no pop when the view changes)
                cs = cs[4:] + cs[:4]
            for c in cs:
                order.append((clip, v, f"{sheet}_{v}", c))
    cols = 12
    rows = (len(order) + cols - 1) // cols
    AW, AH = cols * cw, rows * ch
    atlas = np.zeros((AH, AW, 4), np.float32)
    m0 = np.zeros((AH, AW, 4), np.float32)
    m1 = np.zeros((AH, AW, 4), np.float32)
    frames = []
    cls_px = {c: [] for c in range(1, len(CLASSES))}
    strides = {}
    for idx, (clip, v, sheet, c) in enumerate(order):
        if sheet not in placed:
            frames.append(None)
            continue
        it = placed[sheet][c]
        f, k, lab = it["f"], it["k"], it["lab"]
        # resample the cell into the atlas cell: atlas px (u, w) -> rig (x, y) -> sheet px
        s = 1.0 / (k * PX_PER_RIG)          # sheet px per atlas px
        ax0, ay0 = (idx % cols) * cw, (idx // cols) * ch
        rgba = np.dstack([f["rgb"], f["a"]])
        big = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")
        # premultiply for clean downscale
        pm = rgba.copy(); pm[..., :3] *= pm[..., 3:4] / 255.0
        x_left = it["ox"] - (W_RIG / 2) / k
        y_top = it["oy"] - H_RIG / k
        P = 300
        box = (x_left + P, y_top + P, x_left + P + cw * s, y_top + P + ch * s)
        def rs(arr, mode=Image.BOX):
            arr = np.pad(arr, ((P, P), (P, P), (0, 0)))
            chans = [np.asarray(Image.fromarray(arr[..., i].astype(np.float32), "F").resize((cw, ch), mode, box=box)) for i in range(arr.shape[-1])]
            return np.dstack(chans)
        cpm = rs(pm)
        al = np.clip(cpm[..., 3], 0, 255)
        col = np.where(al[..., None] > 1, cpm[..., :3] / np.maximum(al[..., None], 1) * 255.0, 0)
        atlas[ay0:ay0 + ch, ax0:ax0 + cw] = np.dstack([col, al])
        onehot = np.stack([(lab == ci).astype(np.float32) * 255.0 for ci in range(1, len(CLASSES))], -1)
        oh = rs(onehot)
        m0[ay0:ay0 + ch, ax0:ax0 + cw] = oh[..., [0, 1, 2, 3]]
        m1[ay0:ay0 + ch, ax0:ax0 + cw, :3] = oh[..., [4, 5, 6]]
        m1[ay0:ay0 + ch, ax0:ax0 + cw, 3] = rs((f["farm"].astype(np.float32) * 255.0)[..., None])[..., 0]
        for ci in range(1, len(CLASSES)):
            sel = (lab == ci) & (f["a"] > 250)
            if sel.sum():
                cls_px[ci].append(f["rgb"][sel][::5])
        # anchors (rig, origin soles centre, y up)
        hd = f["head"]
        head = [(hd["cx"] - it["ox"]) * k, (it["oy"] - hd["bottom"]) * k]
        hands = []
        sk = blobs(((lab == 1) & (f["a"] > 128))[::2, ::2], 8)[:2]
        for n, cy, cx, _, _ in sk:
            hands.append([(cx * 2 - it["ox"]) * k, (it["oy"] - cy * 2) * k])
        sack = None
        sm = (lab == 7) & (f["a"] > 128)
        if sm.sum() > 200:
            ys, xs = np.nonzero(sm)
            sack = [float((xs.min() - it["ox"]) * k), float((it["oy"] - ys.max()) * k), float((xs.max() - it["ox"]) * k), float((it["oy"] - ys.min()) * k)]
        shoes = blobs(((lab == 6) & (f["a"] > 128))[::2, ::2], 8)[:2]
        frames.append(dict(clip=clip, view=v, cell=c, uv=[ax0 / AW, ay0 / AH, (ax0 + cw) / AW, (ay0 + ch) / AH],
                           head=[round(head[0], 1), round(head[1], 1)], hands=[[round(p, 1) for p in h] for h in hands],
                           sack=[round(p, 1) for p in sack] if sack else None,
                           shoes=[[round((s_[2] * 2 - it["ox"]) * k, 1), round((it["oy"] - s_[1] * 2) * k, 1)] for s_ in shoes],
                           far=round((f["far"][0] - it["ox"]) * k, 1) if f.get("far") else None, t0=0.0))
    # uniform timing first (position in the clip)
    pos = {}
    for fr in frames:
        if fr:
            key = (fr["clip"], fr["view"])
            fr["t0"] = pos.get(key, 0) / len(CLIP_CELLS[fr["clip"]])
            pos[key] = pos.get(key, 0) + 1
    # stride + frame timing from the planted foot (2026-11-09 live check: the drawn foot travel is uneven — e.g. 42 / 152 / 62 / 5
    # rig per frame — so equal frame times made the planted foot slip forward and back). 3/4 views with the colour-coded far leg:
    #   stride (per cycle, 2 steps) = 2 x (far foot max forward - max back) ; frame i's duration ~ far-foot backward travel i -> i+1
    #   during its stance (frames 5-8), the same pattern for frames 1-4 (the near leg's stance, by symmetry), blended with uniform.
    for clip in ("walk", "carry"):
        st = []
        for v in ("q_front", "q_back"):
            fr = [f for f in frames if f and f["clip"] == clip and f["view"] == v]
            xs = [f["far"] for f in fr]
            seen = [x for x in xs if x is not None]
            if len(fr) == 8 and len(seen) >= 5:
                # v6 long skirt: the far boot is hidden in some frames — use the visible ones
                st.append(2.0 * (max(seen) - min(seen)))
            if len(fr) != 8 or any(x is None for x in xs):
                continue
            stance = [max(0.0, xs[i] - xs[(i + 1) % 8]) for i in range(4, 8)]
            m = max(1e-3, sum(stance) / 4.0)
            d4 = [float(np.clip(x / m, 0.6, 1.6)) for x in stance]
            dur = [TIME_BLEND * d + (1.0 - TIME_BLEND) for d in d4] * 2
            tot = sum(dur)
            acc = 0.0
            for i, f in enumerate(fr):
                f["t0"] = round(acc / tot, 4)
                acc += dur[i]
            print(f"  timing {clip} {v}: far x {xs} -> durations {[round(d / tot * 8, 2) for d in dur]}")
        strides[clip] = round(float(np.mean(st)), 1) if st else 600.0
        # (v4: the drawn feet travel ~70% of the pose reference's half-steps, so the stride is measured on the drawing, not taken
        # from pose_ref — otherwise the planted foot would slide backward)
    base = {}
    for ci in range(1, len(CLASSES)):
        if cls_px[ci]:
            base[CLASSES[ci]] = "%02x%02x%02x" % tuple(np.median(np.concatenate(cls_px[ci]), 0).astype(int))
    def save(arr, name):
        Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(ART, name), optimize=True)
    save(atlas, "frames_atlas.png")
    save(m0, "frames_mask0.png")
    save(m1, "frames_mask1.png")
    nclip = {cl: len(cells) for cl, _, cells in CLIPS}
    lib = dict(fig=FIG, d_rig=D_RIG, rect=[-W_RIG / 2, Y0, W_RIG / 2, H_RIG], atlas=[AW, AH], cell=[cw, ch], views=VIEWS,
               clips=[cl for cl, _, _ in CLIPS], frames_per_clip=nclip, stride=strides, base=base, frames=frames)
    with open(os.path.join(ART, "frames.json"), "w") as fh:
        json.dump(lib, fh, indent=0)
    print("atlas", AW, AH, "cell", cw, ch, "rect", lib["rect"], "stride", strides, "base", base)
    # check images: aligned frames + class colours
    pal = np.array([[0, 0, 0], [240, 170, 110], [210, 60, 60], [250, 240, 200], [140, 80, 40], [60, 160, 220], [40, 40, 160], [180, 180, 180]], np.float32)
    for name, info in placed.items():
        tiles = []
        for it in info:
            f = it["f"]
            lab = it["lab"]
            vis = np.dstack([pal[lab], np.where(f["a"] > 128, 255, 0)])
            ys, xs = int(it["oy"]), int(it["ox"])
            a_ = np.dstack([f["rgb"], f["a"]])
            def crop(img):
                pad = np.zeros((CH + 400, CW + 400, 4), np.float32)
                pad[200:200 + CH, 200:200 + CW] = img
                return pad[200 + ys - 470:200 + ys + 10, 200 + xs - 170:200 + xs + 170]
            tiles.append(np.concatenate([crop(a_), crop(vis)], 0))
        sheet = np.concatenate(tiles, 1)
        bg = np.full(sheet.shape[:2] + (3,), 120.0)
        out = bg * (1 - sheet[..., 3:4] / 255) + sheet[..., :3] * sheet[..., 3:4] / 255
        out[470, :] = [0, 0, 255]
        Image.fromarray(out.astype(np.uint8)).resize((out.shape[1] // 2, out.shape[0] // 2)).save(os.path.join(RAW, f"check_{name}.png"))


if __name__ == "__main__":
    main()
