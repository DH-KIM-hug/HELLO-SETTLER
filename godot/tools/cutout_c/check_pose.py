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
TOL = 0.09          # position tolerance for a SWINGING foot (fraction of soles->chin height)
PLANT_TOL = (4.0, 5.0)   # v8 (2026-11-10, tight): a PLANTED foot must be within 4 px (x) / 5 px (y) of the reference boot
TOE_TOL = 25.0      # v8: the boot's long axis within this many degrees of the step axis (3/4 views; blobs with elongation > 1.25)
ORDER_MIN = 0.12    # the reference must separate the feet by this much for the order test
LIFT_MIN = 0.05


def _shoe(mask):
    bl = blobs(mask[::2, ::2], 6)
    if not bl:
        return None
    big = bl[0][0]
    n, cy, cx, box, m = max([b for b in bl if b[0] > 0.3 * big], key=lambda b: b[3][3])    # the lowest sizeable blob (not the sash)
    return (cx * 2.0, box[3] * 2.0 + 1.0, n, m)        # centre x, bottom y (sheet px), half-res px count, half-res mask


def _toe_angle(m):
    """orientation (deg, image coords, y down) of a blob's long axis and its elongation, from second moments"""
    ys, xs = np.nonzero(m)
    x, y = xs - xs.mean(), ys - ys.mean()
    sxx, syy, sxy = (x * x).mean(), (y * y).mean(), (x * y).mean()
    ang = 0.5 * np.degrees(np.arctan2(2 * sxy, sxx - syy))
    tr, det = sxx + syy, sxx * syy - sxy * sxy
    disc = max(tr * tr / 4 - det, 0.0)
    l1, l2 = tr / 2 + np.sqrt(disc), max(tr / 2 - np.sqrt(disc), 1e-6)
    return float(ang), float(np.sqrt(l1 / l2))


STRAY_MAX = 150     # v8b: leg / boot coloured px (after a 5x5 erosion) allowed outside the reference legs' neighbourhood


def _leg_zone(clip, view, f, grow=20):
    """bool mask (cell) of where the two reference legs + boots are, grown by `grow` px"""
    from PIL import Image, ImageDraw, ImageFilter
    im = Image.new("RGB", (P.CW, P.CH), (0, 0, 0))
    d = ImageDraw.Draw(im)
    g, by, ft = P.geometry(view), P.bob(clip, f), P.feet(clip, view, f)
    for k in ("L", "R"):
        hip = (P.CW / 2 + g["hip"][k][0], P.HIP_Y + by + g["hip"][k][1])
        P.draw_leg(d, hip, (ft[k][0], ft[k][1]), (255, 255, 255), (255, 255, 255), g["fwd"], g["side"] == 0)
    m = im.convert("L").point(lambda v: 255 if v else 0).filter(ImageFilter.MaxFilter(2 * grow + 1))
    return np.asarray(m) > 0


def _stray(rgb, fg, clip, view, f):
    """leg / boot coloured pixels below the hem zone that are NOT near a reference leg: a third foot, a leg stub beside the
    skirt, a kicked-back boot (the image model copies such leftovers from the reference) -> px count"""
    from PIL import Image, ImageFilter
    r, gg, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    L = luma(rgb)
    rows = np.arange(P.CH)[:, None]
    low = rows > P.HEM_Y - 35 + P.bob(clip, f)
    tan = (r > 200) & (gg > 130) & (gg < 205) & (b < 150) & (r - b > 80)
    brown = (r > gg + 18) & (gg > b) & (L > 35) & (L < 115) & (r - b > 35)
    blue = (b > r + 25) & (b > gg + 5)
    m = fg & low & (tan | brown | blue) & ~_leg_zone(clip, view, f)
    er = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))
    return int((np.asarray(er) > 0).sum())


def _check(path, clip, view, skip=frozenset(), partial=frozenset()):
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
        ref = P.feet(clip, view, f)
        rchin = P.CHIN_Y + P.bob(clip, f)
        rsoles = max(ref["R"][1], ref["L"][1]) + 3.0          # the lowest shoe (+ its ink line) = soles, as measured on the drawing
        rH = rsoles - rchin
        rhx = P.CW / 2 + (8 if view == "q_front" else (-4 if view == "q_back" else 0))
        fwd = np.array(g["fwd"]) / np.linalg.norm(g["fwd"])

        def along(px, py, cx, base, h):
            return float(np.dot([(px - cx) / h, (py - base) / h], fwd))
        gen = {"R": R_, "L": L_}
        errs, why, bad, missing = [0.0], [], set(), set()
        # the reference boot is an oval whose centre sits 9 px along the step axis from the foot point (3/4 views)
        toe_dx = 9.0 * fwd[0] if g["side"] else 0.0
        for k in ("R", "L"):
            if (f, k) in skip:            # hidden under the skirt in the reference itself (v6 long skirt) — not checkable
                continue
            if gen[k] is None or gen[k][2] * 4 < 150:
                why.append("%s missing" % k)
                bad.add(k)
                missing.add(k)
                continue
            gx, gy, _, gm = gen[k]
            rx, ry, rl = ref[k]
            ex = (gx - hx) / H - (rx + toe_dx - rhx) / rH
            ey = (gy - soles) / H - (ry - rsoles) / rH          # height above the soles (lift + depth on the screen)
            e = max(abs(ex), abs(ey) * 1.5)
            errs.append(e)
            if rl <= 0.0 and (f, k) not in partial:
                # planted: tight, in px (the traced sheets share the template scale) — the boot centre vs the reference's
                px, py = ex * H, ey * H
                if abs(px) > PLANT_TOL[0] or abs(py) > PLANT_TOL[1]:
                    why.append("%s planted off (%+.0f, %+.0f px)" % (k, px, py))
                    bad.add(k)
            elif e > TOL:
                why.append("%s off (%+.2f, %+.2f)" % (k, ex, ey))
                bad.add(k)
            if g["side"] and gen[k][2] * 4 >= 150 and (f, k) not in partial:
                ang, el = _toe_angle(gm)
                want = np.degrees(np.arctan2(fwd[1], fwd[0]))
                dd = abs((ang - want + 90.0) % 180.0 - 90.0)
                if el > 1.25 and dd > TOE_TOL:
                    why.append("%s toe %.0f deg (axis %.0f)" % (k, ang, want))
                    bad.add(k)
        if R_ is not None and L_ is not None and not ({(f, "R"), (f, "L")} & set(skip)):
            ra = along(ref["R"][0], ref["R"][1], rhx, P.GROUND, rH) - along(ref["L"][0], ref["L"][1], rhx, P.GROUND, rH)
            ga = along(R_[0], R_[1], hx, soles, H) - along(L_[0], L_[1], hx, soles, H)
            if abs(ra) > ORDER_MIN and np.sign(ra) != np.sign(ga):
                why.append("order (ref R-L %+.2f, got %+.2f)" % (ra, ga))
                bad.update(("R", "L"))
        stray = _stray(rgb, fg, clip, view, f) if g["side"] else 0
        if stray > STRAY_MAX:
            why.append("stray leg/boot pieces (%d px)" % stray)
        res.update(ok=not why, why=", ".join(why), err=round(max(errs), 3), H=float(H), bad=bad, missing=missing, stray=stray)
        out.append(res)
    return out


_skip_cache = {}
_partial_cache = {}


def check(path, clip, view):
    """check a generated sheet against pose_ref; feet that are not measurable on the reference sheet itself
    (hidden by the long skirt) are skipped"""
    key = (clip, view)
    if key not in _skip_cache:
        ref = _check(os.path.join(RAW, f"pose_{clip}_{view}.png"), clip, view)
        # only feet that cannot be found on the reference itself (under the hem) are skipped — v8: not feet that merely fail
        _skip_cache[key] = frozenset((r["frame"] - 1, k) for r in ref for k in r.get("missing", {"R", "L"} if "bad" not in r else set()))
        # feet the reference itself occludes (far boot behind the near leg: only a fragment measurable) get the lax test
        _partial_cache[key] = frozenset((r["frame"] - 1, k) for r in ref for k in (r.get("bad", set()) - r.get("missing", set())))
        if _partial_cache[key]:
            print(f"  (reference {clip}_{view}: occluded boots checked loosely: {sorted((f + 1, k) for f, k in _partial_cache[key])})")
    return _check(path, clip, view, _skip_cache[key], _partial_cache[key])


if __name__ == "__main__":
    clip, view = sys.argv[1], sys.argv[2]
    for tag in sys.argv[3:]:
        p = os.path.join(RAW, f"{clip}_{view}{'_' + tag if tag != '-' else ''}.png")
        rs = check(p, clip, view)
        n = sum(r["ok"] for r in rs)
        print(f"{clip}_{view}_{tag}: {n}/8  " + " | ".join(f"{r['frame']}{'ok' if r['ok'] else ' FAIL ' + r['why']}" for r in rs))
