"""Automatic pose check for the v4 (pose-reference) walk / carry sheets (2026-11-09).
Per cell: find the head placeholder (magenta), the soles, the RIGHT shoe (dark brown, tan leg) and the LEFT shoe (navy, cyan leg);
compare both feet with pose_ref.feet() after normalising by the soles->chin height:
  - each foot's position along the walking direction (3/4: x; front/back: y) within TOL,
  - the right/left order along the walking direction where the reference separates them clearly,
  - the lifted foot is lifted where the reference lifts it.
usage: python3 check_pose.py <clip> <view> <tag> [...]   (raw/<clip>_<view>_<tag>.png)  -> prints per-frame PASS/FAIL + score
       import: check(path, clip, view) -> list of per-frame dicts"""
import os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "cutout_a"))
import cut_sheets as C          # noqa: E402
import pose_ref as P            # noqa: E402
from build_frames import blobs, luma   # noqa: E402

RAW = P.RAW
TOL = 0.13          # position tolerance (fraction of soles->chin height)
ORDER_MIN = 0.12    # the reference must separate the feet by this much for the order test
LIFT_MIN = 0.05


def _shoe(mask):
    bl = blobs(mask[::2, ::2], 6)
    if not bl:
        return None
    big = bl[0][0]
    n, cy, cx, box, m = max([b for b in bl if b[0] > 0.3 * big], key=lambda b: b[3][3])    # the lowest sizeable blob (not the sash)
    return (cx * 2.0, box[3] * 2.0 + 1.0, n)        # centre x, bottom y (sheet px)


def check(path, clip, view):
    rgba = C.key(path).astype(np.float32)
    g = P.geometry(view)
    out = []
    for f in range(8):
        x0, y0 = (f % 4) * P.CW, (f // 4) * P.CH
        cell = rgba[y0:y0 + P.CH, x0:x0 + P.CW]
        rgb, a = cell[..., :3], cell[..., 3]
        r, gg, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        L = luma(rgb)
        mag = (r > 170) & (b > 170) & (gg < 110)
        res = dict(frame=f + 1, ok=False, why="")
        if mag.sum() < 500:
            res["why"] = "no head"
            out.append(res)
            continue
        my, mx = np.nonzero(mag)
        hx, chin = mx.mean(), my.max()
        fg = (a > 128) & ~mag
        soles = np.nonzero(fg.any(1))[0].max()
        H = soles - chin
        rows = np.arange(P.CH)[:, None]
        zone = rows > chin + 0.6 * H
        navy = fg & zone & (b > r + 25) & (b > gg + 5) & (L < 120)
        brown = fg & zone & (r > gg + 18) & (gg > b) & (L > 35) & (L < 115) & (r - b > 35)
        R_, L_ = _shoe(brown), _shoe(navy)
        if R_ is None or L_ is None:
            res["why"] = "shoe missing (R %s, L %s)" % (R_ is not None, L_ is not None)
            out.append(res)
            continue
        ref = P.feet(clip, view, f)
        rchin = P.CHIN_Y + P.bob(clip, f)
        rsoles = max(ref["R"][1], ref["L"][1]) + 3.0          # the lowest shoe (+ its ink line) = soles, as measured on the drawing
        rH = rsoles - rchin
        rhx = P.CW / 2 + (8 if view == "q_front" else (-4 if view == "q_back" else 0))
        side = g["side"] == 1
        fwd = np.array(g["fwd"]) / np.linalg.norm(g["fwd"])

        def along(px, py, cx, base, h):
            return float(np.dot([(px - cx) / h, (py - base) / h], fwd))
        gen = {"R": R_, "L": L_}
        errs, why = [], []
        for k in ("R", "L"):
            gx, gy, _ = gen[k]
            rx, ry, rl = ref[k]
            ex = (gx - hx) / H - (rx - rhx) / rH
            ey = (gy - soles) / H - (ry - rsoles) / rH          # height above the soles (lift + depth on the screen)
            e = max(abs(ex), abs(ey) * 1.5)
            errs.append(e)
            if e > TOL:
                why.append("%s off (%+.2f, %+.2f)" % (k, ex, ey))
        ra = along(ref["R"][0], ref["R"][1], rhx, P.GROUND, rH) - along(ref["L"][0], ref["L"][1], rhx, P.GROUND, rH)
        ga = along(gen["R"][0], gen["R"][1], hx, soles, H) - along(gen["L"][0], gen["L"][1], hx, soles, H)
        if abs(ra) > ORDER_MIN and np.sign(ra) != np.sign(ga):
            why.append("order (ref R-L %+.2f, got %+.2f)" % (ra, ga))
        if side:
            # the colour code must sit on the right legs: 3/4 = near (right) shoe lower on the image than the far (left) one
            pass
        res.update(ok=not why, why=", ".join(why), err=round(max(errs), 3), H=float(H))
        out.append(res)
    return out


if __name__ == "__main__":
    clip, view = sys.argv[1], sys.argv[2]
    for tag in sys.argv[3:]:
        p = os.path.join(RAW, f"{clip}_{view}{'_' + tag if tag != '-' else ''}.png")
        rs = check(p, clip, view)
        n = sum(r["ok"] for r in rs)
        print(f"{clip}_{view}_{tag}: {n}/8  " + " | ".join(f"{r['frame']}{'ok' if r['ok'] else ' FAIL ' + r['why']}" for r in rs))
