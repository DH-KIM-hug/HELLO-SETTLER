"""Q22 step 3-1 (2026-11-12, user "1 3"): tight packing of method C's frame atlas.

build_frames.py first lays the frames out on a grid of fixed cells (cw x ch, every frame resampled into its cell at the same rig
position) — about 2/3 of that atlas is empty, and on the phone the ASTC atlas is stored uncompressed in the APK (.astc.ctex, 1 byte
per texel + mips), so the empty texels cost download size and GPU memory alike. repack() moves every frame into a tight atlas:

  - each body cell is trimmed to its used texels (alpha or any dye-mask weight > 0) plus PAD texels on every side (clipped to the
    cell). The game draws only that part of the cell: frames.json "sub" = the kept part as fractions of the cell (x from the left,
    y from the top — the same 0..1 corner coordinates the shader's body quad uses), "uv" = where that part now is in the atlas.
    The shader clamps the quad corners into "sub" (frame_doll.gdshader, fdata row 4), so the drawn doll is exactly where it was.
  - load / eyelid pictures are moved whole (their uv rect is the picture; the game sizes their quads from "size").
  - every slot starts on an ALIGN-texel boundary and keeps PAD empty texels around its content, so down to mip level log2(ALIGN)
    no mip texel mixes two frames (the old grid had cells touching — slightly cleaner than before at far zoom).
  - a frame keeps its texel phase mod 4 (new x - old x and new y - old y are multiples of 4): ASTC 4x4 / BC7 blocks and mip levels
    0-2 hold exactly the same texels as on the grid, so the packed atlas compresses and filters like the grid one (renders identical
    up to the cell edges, where the grid had the neighbour cell instead of empty texels).
  - the masks (m0, m1) move with the same rects (pack_masks.py then packs them into the code texture etc.).
Layout = MaxRects (best short side fit), tallest first, tried over a range of atlas widths; the smallest area wins (sides multiples of
ALIGN; atlas width ≤ MAX_SIDE, the mobile limit is 4096).

usage: called by build_frames.py (python3 build_frames.py rebuilds everything from raw/).
"""
import numpy as np

GAP = 8          # empty texels between any two contents (and at the atlas border)
QPAD = 4         # the drawn quad reaches this far past a cell's used texels (≤ GAP / 2: never over a neighbour)
ALIGN = 16       # atlas sides are multiples of this
MAX_SIDE = 4096


def _used_bounds(atlas, m0, m1, x0, y0, x1, y1):
    """bounding box (x0, y0, x1, y1, half-open, atlas px) of the used texels inside the rect, or None"""
    a = atlas[y0:y1, x0:x1, 3] > 0
    a |= m0[y0:y1, x0:x1].max(-1) > 0
    a |= m1[y0:y1, x0:x1].max(-1) > 0
    if not a.any():
        return None
    ys = np.nonzero(a.any(1))[0]
    xs = np.nonzero(a.any(0))[0]
    return x0 + int(xs[0]), y0 + int(ys[0]), x0 + int(xs[-1]) + 1, y0 + int(ys[-1]) + 1


def _up(v, a):
    return (v + a - 1) // a * a


class _MaxRects:
    """MaxRects bin packer (Jukka Jylänki's best-short-side-fit) on a fixed width, unbounded height"""

    def __init__(self, w, h):
        self.free = [(0, 0, w, h)]

    def insert(self, w, h):
        best = None
        for fx, fy, fw, fh in self.free:
            if w <= fw and h <= fh:
                key = (fy + h, min(fw - w, fh - h), fx)       # lowest top edge first (keeps the atlas short), then short side
                if best is None or key < best[0]:
                    best = (key, fx, fy)
        if best is None:
            return None
        x, y = best[1], best[2]
        self._split(x, y, w, h)
        return x, y

    def _split(self, x, y, w, h):
        out = []
        for fx, fy, fw, fh in self.free:
            if x >= fx + fw or x + w <= fx or y >= fy + fh or y + h <= fy:
                out.append((fx, fy, fw, fh))
                continue
            if x > fx:
                out.append((fx, fy, x - fx, fh))
            if x + w < fx + fw:
                out.append((x + w, fy, fx + fw - x - w, fh))
            if y > fy:
                out.append((fx, fy, fw, y - fy))
            if y + h < fy + fh:
                out.append((fx, y + h, fw, fy + fh - y - h))
        # drop rects contained in others
        keep = []
        for i, r in enumerate(out):
            if not any(j != i and r[0] >= o[0] and r[1] >= o[1] and r[0] + r[2] <= o[0] + o[2] and r[1] + r[3] <= o[1] + o[3]
                       and (r != o or j < i) for j, o in enumerate(out)):
                keep.append(r)
        self.free = keep


def layout(sizes, widths, align=ALIGN, lead=0):
    """sizes: [(w, h)] slot sizes (multiples of ALIGN) -> (W, H, [(x, y)]) with the smallest W * H over the tried widths"""
    order = sorted(range(len(sizes)), key=lambda i: (-sizes[i][1], -sizes[i][0]))
    best = None
    for W in widths:
        if W < max(s[0] for s in sizes):
            continue
        mr = _MaxRects(W, MAX_SIDE)
        pos = [None] * len(sizes)
        ok = True
        for i in order:
            p = mr.insert(*sizes[i])
            if p is None:
                ok = False
                break
            pos[i] = p
        if not ok:
            continue
        H = _up(lead + max(p[1] + sizes[i][1] for i, p in enumerate(pos)), align)
        Wt = W + lead
        if best is None or Wt * H < best[0] or (Wt * H == best[0] and abs(Wt - H) < abs(best[1] - best[2])):
            best = (Wt * H, Wt, H, pos)
    if best is None:
        raise SystemExit("pack_atlas: the frames do not fit in %d x %d" % (MAX_SIDE, MAX_SIDE))
    return best[1], best[2], best[3]


def repack(atlas, m0, m1, cells, pics, gap=GAP, qpad=QPAD, align=ALIGN, widths=None, quiet=False):
    """atlas, m0, m1: (H, W, 4) grid arrays. cells: {key: (x0, y0, x1, y1)} body cells (trimmed); pics: {key: (x0, y0, x1, y1)}
    pictures (kept whole). Returns (atlas, m0, m1, place) with place[key] = dict(uv=[u0, v0, u1, v1] of the drawn part in the new
    atlas, sub=[sx0, sy0, sx1, sy1] the drawn part as fractions of the old rect (pictures: [0, 0, 1, 1]), px=[x, y, w, h] copied)"""
    src, quad = {}, {}
    for key, (x0, y0, x1, y1) in cells.items():
        b = _used_bounds(atlas, m0, m1, x0, y0, x1, y1)
        if b is None:
            b = (x0, y0, x0 + 1, y0 + 1)
        src[key] = b
        quad[key] = (max(x0, b[0] - qpad), max(y0, b[1] - qpad), min(x1, b[2] + qpad), min(y1, b[3] + qpad))
    for key, r in pics.items():
        src[key] = tuple(r)
        quad[key] = tuple(r)
    keys = list(src)
    # slot = [phase 0..3][content][up to the next 4][gap]; slots sit on multiples of 4 after a leading gap, so the content keeps its
    # texel phase mod 4 and any two contents are >= gap texels apart
    sizes = []
    for key in keys:
        x0, y0, x1, y1 = src[key]
        sizes.append((_up(x0 % 4 + x1 - x0, 4) + gap, _up(y0 % 4 + y1 - y0, 4) + gap))
    if widths is None:
        area = sum(s[0] * s[1] for s in sizes)
        lo = _up(max(max(s[0] for s in sizes) + gap, int(np.sqrt(area) * 0.5)), align)
        widths = range(lo, min(MAX_SIDE, _up(int(np.sqrt(area) * 2.2), align)) + 1, align)
    W, H, pos = layout(sizes, [w - gap for w in widths], align, lead=gap)
    A = np.zeros((H, W, 4), np.float32)
    M0 = np.zeros((H, W, 4), np.float32)
    M1 = np.zeros((H, W, 4), np.float32)
    AH, AW = atlas.shape[:2]
    place = {}
    for key, (sx, sy) in zip(keys, pos):
        x0, y0, x1, y1 = src[key]
        dx, dy = gap + sx + x0 % 4, gap + sy + y0 % 4
        w, h = x1 - x0, y1 - y0
        A[dy:dy + h, dx:dx + w] = atlas[y0:y1, x0:x1]
        M0[dy:dy + h, dx:dx + w] = m0[y0:y1, x0:x1]
        M1[dy:dy + h, dx:dx + w] = m1[y0:y1, x0:x1]
        qx0, qy0, qx1, qy1 = quad[key]
        ux0, uy0 = dx + qx0 - x0, dy + qy0 - y0          # the drawn part (may reach qpad texels into the empty gap)
        uv = [ux0 / W, uy0 / H, (ux0 + qx1 - qx0) / W, (uy0 + qy1 - qy0) / H]
        if key in cells:
            cx0, cy0, cx1, cy1 = cells[key]
            sub = [(qx0 - cx0) / (cx1 - cx0), (qy0 - cy0) / (cy1 - cy0), (qx1 - cx0) / (cx1 - cx0), (qy1 - cy0) / (cy1 - cy0)]
        else:
            sub = [0.0, 0.0, 1.0, 1.0]
        place[key] = dict(uv=uv, sub=sub, px=[dx, dy, w, h], shift=[dx - x0, dy - y0])
    if not quiet:
        old_used = (atlas[..., 3] > 0).sum()
        print(f"pack_atlas: {AW}x{AH} -> {W}x{H} ({W * H / (AW * AH):.0%} of the texels; texels with alpha {old_used / (AW * AH):.0%} -> "
              f"{(A[..., 3] > 0).sum() / (W * H):.0%}) · {len(cells)} cells trimmed, {len(pics)} pictures · gap {gap}, align {align}")
    return A, M0, M1, place
