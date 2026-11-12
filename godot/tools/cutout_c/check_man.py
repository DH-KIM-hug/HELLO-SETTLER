"""Q22 man body: check a man take against the woman's finished sheet it was redrawn from (and, for the gait sheets, against the
pose reference with check_pose.py — same tight boot tests as the woman's sheets).
Per cell: magenta head disc (centre x, bottom = chin, diameter) vs the woman's cell, the soles row, and — gait sheets — check_pose.
usage: python3 check_man.py <sheet> <tag> [...]     (man_c/raw/<sheet>_<tag>.png; tag '-' = the installed raw/<sheet>.png)
       import: score(sheet, path) -> (n_ok, report lines, per-cell ok list)"""
import os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "cutout_a"))
import cut_sheets as C          # noqa: E402
import check_pose as K          # noqa: E402
from build_frames import luma, blobs   # noqa: E402

ART = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout"))
MRAW = os.path.join(ART, "man_c", "raw")
WRAW = os.path.join(ART, "woman_c", "raw")
CW, CH = 384, 512
# planted boot vs the pose reference: the woman's sheets were held to (4, 5) px; the man's redraws of them land 4-7 px behind
# on the near boot in most takes (a slightly longer boot drawing), so the man is held to (8, 7) px = 3 atlas px, ~0.7 screen px at
# ppu 44. Sliding inside a stance is checked by build_frames_man.py's "boot x - ref" print (same numbers per stance = no slide).
K.PLANT_TOL = (8.0, 7.0)
HEAD_TOL = (6.0, 6.0, 8.0)     # px: head centre x, chin y, diameter — the anchor the head piece is laid on
SOLE_TOL = 8.0                  # px: lowest opaque row (the ground under the figure)
# gait sheets: (clip of the pose reference, which cells to check) — idle / hold / rock: standing reference of that view
GAIT = {"walk": ("walk", range(8)), "carry": ("carry", range(8)), "cradle": ("carry", range(8)),
        "idle": ("idle", range(4)), "hold": ("idle", range(4, 8)), "rock": ("idle", range(4, 8))}


def cells(path):
    rgba = C.key(path).astype(np.float32)
    if rgba.shape[1] != 4 * CW:
        from PIL import Image
        rgba = np.asarray(Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA").resize((4 * CW, 2 * CH))).astype(np.float32)
    out = []
    for i in range(8):
        c = rgba[(i // 4) * CH:(i // 4 + 1) * CH, (i % 4) * CW:(i % 4 + 1) * CW]
        r, g, b, a = c[..., 0], c[..., 1], c[..., 2], c[..., 3]
        mag = (r > 170) & (b > 170) & (g < 110)
        fg = (a > 128) & ~mag
        d = dict(head=None, soles=None)
        if mag.sum() > 500:
            ys, xs = np.nonzero(mag)
            d["head"] = (float(xs.mean()), float(ys.max()), (xs.max() - xs.min() + ys.max() - ys.min() + 2) / 2.0)
        bl = blobs(fg[::2, ::2], 20)
        if bl:
            m = np.kron(bl[0][4], np.ones((2, 2), bool))[:CH, :CW]
            d["soles"] = float(np.nonzero(m.any(1))[0].max())
            d["fig"] = m
        d["rgb"] = c[..., :3]
        d["a"] = a
        out.append(d)
    return out


BOOT_TOL = (6.0, 6.0)


def boots(m, w):
    """{R: (man boot (centre x, bottom y) | None, woman's), L: ...} — dark-brown (near) / navy (far, coded sheets) boot blobs in the
    lowest 40 % of the figure (the woman's chin -> soles), the lowest sizeable blob as in check_pose"""
    out = {}
    if w["head"] is None or w["soles"] is None:
        return out
    zone = np.arange(CH)[:, None] > w["head"][1] + 0.6 * (w["soles"] - w["head"][1])
    for leg in ("R", "L"):
        got = []
        for d in (m, w):
            r, g, b = d["rgb"][..., 0], d["rgb"][..., 1], d["rgb"][..., 2]
            L = luma(d["rgb"])
            fg = (d["a"] > 128) & zone
            if leg == "R":
                msk = fg & (r > g + 18) & (g > b) & (L > 35) & (L < 115) & (r - b > 35)
            else:
                msk = fg & (b > r + 25) & (b > g + 5) & (L < 120)
            sh = K._shoe(msk) if msk.sum() > 150 else None
            got.append(None if sh is None or sh[2] * 4 < 150 else (sh[0], sh[1]))
        out[leg] = tuple(got)
    return out


def used_cells(sheet):
    """the cells of a sheet the build puts in the atlas (build_frames.py CLIPS / pose_states ENTRIES + CLIP_SHEET) — the others
    (the idle sheets' sack row, the work 3/4 sheets' old gather row, ...) are never played and are not checked"""
    import pose_states as PS
    clip = sheet.split("_")[0]
    if clip in ("idle",):
        return set(range(4))
    if clip in ("hold", "rock"):
        return set(range(4, 8))
    if clip in ("walk", "carry", "cradle"):
        return set(range(8))
    out = set()
    for cl, sheets in PS.CLIP_SHEET.items():
        for sh in sheets:
            if sh == sheet:
                out |= {PS.cell_of(sh, p) for p, _t, _a in PS.ENTRIES[cl]}
    return out


def score(sheet, path):
    use_ = used_cells(sheet)
    man, wom = cells(path), cells(os.path.join(WRAW, sheet + ".png"))
    clip, view = sheet.split("_", 1)
    gait = None
    if clip in GAIT:
        gclip, use = GAIT[clip]
        res = K.check(path, gclip, view)
        wres = K.check(os.path.join(WRAW, sheet + ".png"), gclip, view)
        # a cell the woman's own sheet fails against the pose reference (her hold rows) is held to HER boots instead
        gait = {i: res[i] for i in use if wres[i]["ok"]}
    lines, ok = [], []
    for i in range(8):
        m, w = man[i], wom[i]
        why = []
        if i not in use_:
            ok.append(True)
            lines.append(f"  {i + 1}: ok (not played)")
            continue
        if m["head"] is None:
            why.append("no head disc")
        elif w["head"] is not None:
            dx, dy, dd = m["head"][0] - w["head"][0], m["head"][1] - w["head"][1], m["head"][2] - w["head"][2]
            if abs(dx) > HEAD_TOL[0] or abs(dy) > HEAD_TOL[1] or abs(dd) > HEAD_TOL[2]:
                why.append("head %+.0f,%+.0f d%+.0f" % (dx, dy, dd))
        if m["soles"] is not None and w["soles"] is not None and abs(m["soles"] - w["soles"]) > SOLE_TOL:
            why.append("soles %+.0f" % (m["soles"] - w["soles"]))
        if gait is not None and i not in gait:
            # (state sheets: head anchor + ground only — a sitting / kneeling boot is placed by the pose, not by a step)
            for leg, (bm, bw) in boots(m, w).items():
                if bw is None:
                    continue
                if bm is None:
                    why.append(f"{leg} boot missing")
                elif abs(bm[0] - bw[0]) > BOOT_TOL[0] or abs(bm[1] - bw[1]) > BOOT_TOL[1]:
                    why.append("%s boot %+.0f,%+.0f" % (leg, bm[0] - bw[0], bm[1] - bw[1]))
        if gait is not None and i in gait and not gait[i]["ok"]:
            why.append("pose: " + gait[i]["why"])
        ok.append(not why)
        lines.append(f"  {i + 1}: " + ("ok" if not why else "FAIL " + "; ".join(why)))
    return sum(ok), lines, ok


if __name__ == "__main__":
    sheet = sys.argv[1]
    for tag in sys.argv[2:]:
        p = os.path.join(MRAW, f"{sheet}.png" if tag == "-" else f"{sheet}_{tag}.png")
        n, lines, _ = score(sheet, p)
        print(f"{sheet} {tag}: {n}/8")
        print("\n".join(lines))
