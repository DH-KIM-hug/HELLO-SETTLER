"""Cutout prototype v2 (concept A) — step 3: pack EVERY part of every set / view (+ props) into ONE atlas pair and write the
rig library the Godot doll reads.  (2026-11-08)

usage: python3 build_atlas.py
in : art/cutout/woman_a/parts/<set>/<view>/<part>.png + place.json (cut_sheets.py), parts/props/*.png
out: art/cutout/woman_a/doll_atlas.png  — the art as drawn (RGBA)
     art/cutout/woman_a/doll_mcode.png + doll_mlut.png + doll_mq.png — dye weights (R/G/B = how much the pixel belongs to the
                                          part's dye channel 0/1/2), packed (pack_mask; was doll_mask.png until Q22 step 4)
     art/cutout/woman_a/doll_lib.json   — quads (rect, pivot, uv, layer, group, dye slots + the drawn base colour per channel)

Colour by shader: the shader multiplies the drawn pixel by (dye / drawn base colour) per channel weight, so the default
dye reproduces the drawing exactly, shading / blush / line weight stay, and any palette colour can be swapped in.
Dye slots (per resident): 0 skin, 1 hair, 2 main cloth, 3 second (cream), 4 trim (belt/leather), 5 headwear, 6 legwear, 7 shoes.
"""
import json, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sheet_layout as L

ART = L.ART
PARTS = os.path.join(ART, "parts")
VIEWS = ["front", "q_front", "q_back", "back"]
SETS = ["a", "b", "c", "d", "e", "f", "g"]
FIG = 920.0                 # rig units: every figure normalised to 920 tall (feet = 0, y up)
ATLAS_K = 0.42              # atlas px per rig unit (figure ~386 px tall; 2048x1024 holds all 4 sets x 4 views + necks + props)
ATLAS_W = 2048
PAD = 4
SLOTS = {"skin": 0, "hair": 1, "main": 2, "second": 3, "trim": 4, "hat": 5, "legwear": 6, "shoe": 7}

# drawn base colours per set (measured with k-means on the cut parts — the only hand step of the colour pipeline, ~2 min/set)
BASE = {
    "a": {"skin": "f0ad6f", "hair": "774832", "main": "ce6d69", "second": "fce3b9", "trim": "a3623a", "hat": "fbdfb5", "legwear": "dba26d", "shoe": "8e5637"},
    "b": {"skin": "e8985a", "hair": "623e2f", "main": "8c96bc", "second": "f8daae", "trim": "d2a064", "hat": "edbb66", "legwear": "6a4332", "shoe": "945c3c"},
    "c": {"skin": "ba6b37", "hair": "51392c", "main": "989a64", "second": "f7dbaf", "trim": "ebab53", "hat": "f7daaf", "legwear": "fadfb7", "shoe": "744628"},
    "d": {"skin": "fbb377", "hair": "cf7128", "main": "e8b35b", "second": "f7d4a4", "trim": "a05933", "hat": "fadbaf", "legwear": "9f5c35", "shoe": "77462a"},
}
# concept-A cast (2026-11-08): e man, f child, g elder — drawn base colours measured automatically (auto_base) near these
# expected concept colours; the measured values are written into doll_lib.json "base"
EXPECT = {
    "e": {"skin": "9a5a35", "hair": "3a2a22", "main": "8fa87a", "second": "f3e6cc", "trim": "d9a85a", "hat": "e0b860", "legwear": "f3e6cc", "shoe": "8a5a3a"},
    "f": {"skin": "f2b382", "hair": "c8643a", "main": "dcb555", "second": "f3e6cc", "trim": "8a5a3a", "hat": "f3e6cc", "legwear": "f3e6cc", "shoe": "8a5a3a"},
    "g": {"skin": "b07048", "hair": "f2efe8", "main": "8f8cc8", "second": "f3e6cc", "trim": "8a5a3a", "hat": "f3e6cc", "legwear": "8f8cc8", "shoe": "8a5a3a"},
}
# where each slot's colour is measured (part kinds)
MEASURE = {"skin": ["arm"], "hair": ["tail", "head"], "main": ["body", "sleeve"], "second": ["body", "sleeve"], "trim": ["body"],
           "hat": ["knot"], "legwear": ["leg", "body"], "shoe": ["leg"]}

# BODY TYPES (2026-11-08 user: in-game look = the chunky GAME-SCALE INSET of res_A.png — big round head ~1/3 of the height,
# head right on the shoulders, NO visible neck, compact body, short legs). Per OUTFIT (body) set, tunable here:
#   head_k : head (+ hair / headwear) size multiplier on this body (heads are first normalised to HEAD_H)
#   neck   : visible neck between collar top and chin (rig units; < 0 = chin tucked over the collar)
#   bs     : uniform scale of the body pieces (body, sleeves, arms, legs, cane) about the feet
#   bsy    : extra vertical squash of the body pieces (short legs / torso)
#   head_fwd: (optional) head moved forward in the 3/4 views (elder stoop)
# -> doll_lib.json "body_types"; head_k goes to the shader per body, the rest is baked into the quads / sockets.
ADULT = {"type": "adult", "head_k": 1.42, "neck": -14.0, "bs": 1.0, "bsy": 0.8}
BODY = {
    "a": ADULT, "b": ADULT, "c": ADULT, "d": ADULT, "e": ADULT,
    "f": {"type": "child", "head_k": 1.5, "neck": -16.0, "bs": 1.0, "bsy": 0.8},
    "g": {"type": "elder", "head_k": 1.42, "neck": -34.0, "bs": 1.0, "bsy": 0.8, "head_fwd": 28.0},
}
LEGS = {"f": ["skin", "shoe", "second"], "g": ["shoe", "main", "skin"]}      # child: bare lower legs; elder: shoes under the robe


def auto_base(s):
    """drawn base colour per dye slot for a cast set: median of the part pixels whose colour is near the expected one"""
    out = {}
    for slot, exp in EXPECT[s].items():
        e = hexrgb(exp)
        px = []
        for v in VIEWS:
            d = os.path.join(PARTS, s, v)
            for f in os.listdir(d):
                if f.startswith("head_") or f.startswith("beard_"):
                    continue          # Q22 step 4 variants: measured on the original drawings only
                if f.endswith(".png") and f.split("_")[0].split(".")[0] in MEASURE[slot]:
                    a = np.asarray(Image.open(os.path.join(d, f)).convert("RGBA")).reshape(-1, 4)
                    px.append(a[a[:, 3] > 200][:, :3].astype(np.float32) / 255.0)
        px = np.concatenate(px)
        dist = np.abs(px - e).sum(-1)
        near = px[dist < max(0.25, np.percentile(dist, 3))]
        c = np.median(near, axis=0) if len(near) > 30 else e
        out[slot] = "%02x%02x%02x" % tuple(int(round(x * 255)) for x in c)
    return out
# dye channels per part kind (max 3) — the per-quad R/G/B of the mask
CHANNELS = {
    "body": ["main", "second", "trim"],
    "sleeve": ["main", "second"],
    "arm": ["skin"],
    "leg": ["legwear", "shoe", "skin"],
    "head": ["skin", "hair", "hat"],          # "hat" only for set a (scarf drawn on the head)
    "tail": ["hair"],
    "knot": ["hat"],
}
LEG3 = {"d": "second"}                        # set d: cream leg wraps are the 3rd leg channel

# draw order per view (back -> front). far side in 3/4 views = image-right (_b) (measured: lower match score = hidden)
ORDER = {
    "front": ["leg_a", "leg_b", "tail", "knot", "neck", "body", "prop", "arm_a", "arm_b", "sleeve_a", "sleeve_b", "head", "hat"],
    "q_front": ["tail", "knot", "arm_b", "sleeve_b", "leg_b", "leg_a", "neck", "body", "prop", "arm_a", "sleeve_a", "head", "hat"],
    "q_back": ["prop", "arm_b", "sleeve_b", "leg_b", "leg_a", "neck", "body", "arm_a", "sleeve_a", "head", "tail", "knot", "hat"],
    "back": ["prop", "leg_a", "leg_b", "neck", "body", "arm_a", "arm_b", "sleeve_a", "sleeve_b", "head", "tail", "knot", "hat"],
}
# anim slots (shader): 0 root 1 body 2 head 3 sleeve_a 4 sleeve_b 5 arm_a 6 arm_b 7 leg_a 8 leg_b 9 accessory 10 prop
SLOT_OF = {"body": 1, "head": 2, "sleeve_a": 3, "sleeve_b": 4, "arm_a": 5, "arm_b": 6, "leg_a": 7, "leg_b": 8,
           "tail": 9, "knot": 9, "hat": 2, "prop": 10}
# groups: 0 outfit (body set S, rig frame) 1 head (head set T, frame = its head pivot) 2 headwear (set U, frame = U's head pivot) 3 prop
PROPS = ["bread", "twigs", "basket", "bread_q", "twigs_q", "basket_q", "hoe", "sickle", "rake", "mallet", "wheat", "bucket", "seed"]
# wheat (ROADMAP Q8) = ONE ear as big as a head, on its stalk, held by the stalk so the ear stands over the shoulder
# (tools/bld2d/wheat_field.py carry_ear -> parts/props/wheat.png; it prints the grip point).
PROP_GRIP = {"wheat": (0.876, 0.882)}         # the hand's place in the picture (share from the left, from the top); others: the middle
PROP_LATE = {"wheat": (83, 56)}             # packed after everything else, on the free rows at the bottom. Its old cell (h, w px: the
                                            # sheaf it replaced) stays reserved and empty, so every other part keeps its place in the atlas


# concept A (res_A.png, adult woman front, 456 px tall): chin -> collar top 12 px = 2.6 % -> 24 rig units;
# top of the scarf -> chin 123 px = 27 % -> 248 rig units. Bare heads (no scarf) are a little lower on top.
NECK_VIS = 24.0
HEAD_H = {"a": 248.0, "bare": 232.0}


# HEADWEAR DESKEW (2026-11-08 bug "caps worn crooked"): the 3/4-view hat drawings came out of the sheets tilted ~20-30 deg
# (the figure wore it at a jaunty angle), while front/back are level. A brim seen from any side on a level head is level, so
# a brim-like hat (long principal axis, level in the front view) whose 3/4 axis differs from the front's is rotated level
# about its centre. Hats whose tilt is part of the design (pointed cap f: tilted in every view) and wraps that are not
# brim-like (d) are left alone.
DESKEW_MIN_DEG = 10.0      # 3/4 axis vs front axis
DESKEW_FRONT_LEVEL = 3.0   # front axis must be this level (deg)
DESKEW_MIN_RATIO = 1.7     # principal-axis variance ratio = brim-like (front and this view)


# HEADWEAR DEPTH (2026-11-08 user: "the straw hat is still floating" — perched on the hair, crown empty). The hat drawings
# were placed where they sat on the concept figure, so the brim line landed anywhere from 30 units ABOVE the head top
# (e back) to 110 below it; and the hair above the face differs a lot between heads (tall curls vs flat hair), so no
# single depth below the hair top fits every wearer. Now:
#   * every head has a hat SEAT = its brow line (find_brow; back views reuse the front view's depth) and head_top in
#     doll_lib = chin -> seat (the shader puts any hat U on head T's seat — still one quad per hat, any head);
#   * every brim / cap is centred on the head by its OPENING LINE (widest row: brim centre line / knit cuff) and moved so
#     its lowest point under the opening centre (front edge of a brim / lower edge of a cuff — a brim drawn more from
#     above or a thick cuff hangs lower, so the opening line alone would cover the eyes) sits HAT_SINK x head height
#     above (+) / below (-) the brow: the cuff on the brow, the brim edge just over the eyes; the hair top inside the crown
# Wraps (d: a kerchief that frames the face) keep the drawn placement (relative to the seat).
HAT_KIND = {"b": "brim", "c": "cap", "d": "wrap", "e": "brim", "f": "cap", "g": "cap"}
HAT_SINK = {"brim": {"fb": -0.08, "q": -0.08}, "cap": {"fb": 0.0, "q": 0.0}}     # x HEAD_H, + = above the brow
BROW_DEFAULT = 0.33        # brow depth below the head top (x HEAD_H) when a front face has no readable brow
BROW_MAX_DIFF = 0.12       # a 3/4 brow further than this from the front's (x HEAD_H) is a misread (white brows -> eyes)


def hat_opening(img):
    """widest opaque row of a hat drawing -> (row index, x centre of that row's span, lowest opaque row under that
    centre), image px"""
    a = np.asarray(img.convert("RGBA"))[..., 3] > 128
    best, yb, xc = -1, 0, a.shape[1] / 2
    for y in range(a.shape[0]):
        xs = np.nonzero(a[y])[0]
        if len(xs) and xs[-1] - xs[0] > best:
            best, yb, xc = xs[-1] - xs[0], y, (xs[0] + xs[-1] + 1) / 2
    col = np.nonzero(a[:, min(int(xc), a.shape[1] - 1)])[0]
    return yb, xc, int(col.max()) if len(col) else yb


def sink_hat(img, rr, kind, v):
    """move the hat rect (frame = the seat / brow line) so its anchor line sits HAT_SINK above the brow, centred on x = 0"""
    w0, h0 = img.size
    yb, xc, ye = hat_opening(img)
    line = rr[3] - (ye + 0.5) * (rr[3] - rr[1]) / h0
    mid = rr[0] + xc * (rr[2] - rr[0]) / w0
    target = HAT_SINK[kind]["fb" if v in ("front", "back") else "q"] * HEAD_H["bare"]
    dx, dy = -mid, target - line
    return [rr[0] + dx, rr[1] + dy, rr[2] + dx, rr[3] + dy], "dx %.0f dy %.0f" % (dx, dy)


def hat_axis(png):
    """principal axis of the opaque pixels: (degrees in image space, y down; elongation ratio)"""
    a = np.asarray(Image.open(png).convert("RGBA"))[..., 3] > 128
    ys, xs = np.nonzero(a)
    w, vec = np.linalg.eigh(np.cov(np.vstack([xs - xs.mean(), ys - ys.mean()])))
    ang = (np.degrees(np.arctan2(vec[1, 1], vec[0, 1])) + 90.0) % 180.0 - 90.0
    return float(ang), float(w[1] / max(w[0], 1e-6))


def hat_tilt(s, v):
    """degrees to rotate set s / view v's hat drawing counter-clockwise to level it (0 = keep)"""
    if v in ("front", "back"):
        return 0.0
    fa, fr = hat_axis(os.path.join(PARTS, s, "front", "knot.png"))
    va, vr = hat_axis(os.path.join(PARTS, s, v, "knot.png"))
    if abs(fa) > DESKEW_FRONT_LEVEL or fr < DESKEW_MIN_RATIO or vr < DESKEW_MIN_RATIO or abs(va - fa) < DESKEW_MIN_DEG:
        return 0.0
    return va - fa


def deskew(img, rr, deg):
    """rotate the part image by deg (CCW) about the centre of its rig rect, crop to the opaque box -> (img, rr)"""
    w0, h0 = img.size
    sx, sy = (rr[2] - rr[0]) / w0, (rr[3] - rr[1]) / h0      # rig units per image px
    cx, cy = (rr[0] + rr[2]) / 2, (rr[1] + rr[3]) / 2
    r = img.rotate(deg, resample=Image.BICUBIC, expand=True)
    x0, y0, x1, y1 = r.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    W, H = r.size
    out = [cx + (x0 - W / 2) * sx, cy + (H / 2 - y1) * sy, cx + (x1 - W / 2) * sx, cy + (H / 2 - y0) * sy]
    return r.crop((x0, y0, x1, y1)), out


# STACKED LEGS (2026-11-08 user: "when they turn, why is one leg missing?"): in the 3/4-back sheets of set a (woman) and
# f (child) the concept showed one leg hidden behind the other, so cut_sheets placed BOTH cut legs on the same hip (hip gap
# -8 / 2 rig units vs 125..190 everywhere else) — whenever the doll turned into that view one leg vanished, in every pose.
# A view whose two hips are closer than LEG_MIN_GAP x foot width gets the hip gap of the same set's other 3/4 view (legs
# moved apart symmetrically about their middle; rect, hip pivot and parent pivot move together).
LEG_MIN_GAP = 0.5

# CHILD BRAIDS FROM BEHIND (2026-11-08 A23 stage 3: "the child's big braids and hands cover the body" in back / q_back): the
# concept's back-view braids were cut with the parting arch and placed 1.7-2x larger than the front braids, drawn over the
# body, so the tufts at their ends read as two big hands and hid the dress and legs. Per (set, view): scale the braid piece
# about the centre of its top edge (k) and move it (dx, dy, rig units in the head frame) — ends now sit at the shoulders.
TAIL_FIX = {("f", "q_back"): (0.64, 6.0, -34.0), ("f", "back"): (0.66, 0.0, -38.0)}


def spread_stacked_legs(items):
    legs = {}
    for _img, _m, meta in items:
        if meta["group"] == 0 and meta["part"] in ("leg_a", "leg_b"):
            legs.setdefault((meta["set"], meta["view"]), {})[meta["part"]] = meta

    def gap(pair):
        return pair["leg_b"]["pivot"][0] - pair["leg_a"]["pivot"][0]

    for (s, v), pair in legs.items():
        if len(pair) < 2:
            continue
        fw = pair["leg_a"]["rect"][2] - pair["leg_a"]["rect"][0]
        g = gap(pair)
        if g >= LEG_MIN_GAP * fw:
            continue
        twin = {1: 2, 2: 1, 0: 3, 3: 0}[v]
        ref = legs.get((s, twin))
        want = gap(ref) if ref and len(ref) == 2 and gap(ref) >= LEG_MIN_GAP * fw else 1.4 * fw
        d = (want - g) / 2
        for part, sgn in (("leg_a", -1.0), ("leg_b", 1.0)):
            m = pair[part]
            m["rect"] = [round(m["rect"][0] + sgn * d, 2), m["rect"][1], round(m["rect"][2] + sgn * d, 2), m["rect"][3]]
            m["pivot"] = [round(m["pivot"][0] + sgn * d, 2), m["pivot"][1]]
        print("spread legs", s, VIEWS[v], "gap %.0f -> %.0f" % (g, want))


def find_brow(p, skin):
    """head piece (sheet px) -> the BROW line: topmost row of dark ink (brows, else eyes) with face skin on all four
    sides. None for faceless (back) views. Hats sit on this line (head_top = seat), not on the hair top — hair volume
    above the face differs a lot between heads (tall curls vs flat hair)."""
    a = p[..., 3] > 128
    rgb = p[..., :3].astype(np.float32) / 255.0
    l = np.maximum(lum(rgb), 1e-3)
    ls = float(lum(skin))
    d = np.abs(rgb / l[..., None] - skin / ls).sum(-1)
    r = l / ls
    sk = a & (d < 0.3) & (r > 0.7) & (r < 1.3)
    dark = a & (l < 0.45 * ls)
    g = max(4, sk.shape[1] // 25)
    near = {k: np.zeros_like(sk) for k in "lrud"}
    for k in range(1, 3 * g):
        near["l"][:, k:] |= sk[:, :-k]
        near["r"][:, :-k] |= sk[:, k:]
    for k in range(1, 2 * g):
        near["u"][k:] |= sk[:-k]
        near["d"][:-k] |= sk[k:]
    feat = dark & near["l"] & near["r"] & near["u"] & near["d"]
    rows = np.nonzero(feat.sum(1) >= 2)[0]
    return int(rows.min()) if len(rows) else None


def find_chin(p, skin):
    """head piece (sheet px) -> chin. The drawn neck stub = the LOWEST skin-coloured blob of the piece (braids / hair may
    hang lower, so not simply the bottom rows). Walk up the stub's middle columns until they stop being skin: that row is the
    chin line (front / 3/4) or the nape (back). Returns x (stub centre), y (chin), x0..x1 (stub columns)."""
    a = p[..., 3] > 128
    rgb = p[..., :3].astype(np.float32) / 255.0
    l = np.maximum(lum(rgb), 1e-3)
    ls = float(lum(skin))
    d = np.abs(rgb / l[..., None] - skin / ls).sum(-1)
    r = l / ls
    sk = a & (d < 0.3) & (r > 0.7) & (r < 1.25)
    # lowest row with a stub-wide run of skin (>= 12 % of the piece width) — braid ties / ears are narrower
    def maxrun(row):
        if not row.any():
            return 0
        dd = np.diff(np.concatenate([[0], row.astype(np.int8), [0]]))
        return int((np.nonzero(dd == -1)[0] - np.nonzero(dd == 1)[0]).max())
    runs = np.array([maxrun(sk[y]) for y in range(p.shape[0])])
    rows = np.nonzero(runs >= 0.12 * p.shape[1])[0]
    if len(rows) == 0:      # neck stub drawn in the shade colour only (back views of dark skin) -> accept darker skin
        sk = a & (d < 0.4) & (r > 0.45) & (r < 1.25)
        runs = np.array([maxrun(sk[y]) for y in range(p.shape[0])])
        rows = np.nonzero(runs >= 0.12 * p.shape[1])[0]
    yb = int(rows.max())
    xs = np.nonzero(sk[max(0, yb - 8): yb - 3].any(0))[0]
    if len(xs) == 0:
        xs = np.nonzero(sk[yb])[0]
    x0, x1 = int(xs.min()), int(xs.max())
    xc = (x0 + x1) // 2
    q = 2      # narrow: a slanted jaw line in 3/4 must still stop the walk
    y = yb - 4
    sw = x1 - x0 + 1
    # stop at the chin line, or where the skin suddenly widens into the face (3/4 views: no line between jaw and neck)
    while y > 0 and sk[y, xc - q: xc + q + 1].mean() > 0.6 and runs[y] < 1.5 * sw:
        y -= 1
    return {"x": xc, "y": int(y), "x0": x0, "x1": x1, "yb": yb}


def neck_image(w_rig, h_rig, skin):
    """generated neck: skin tube with the ink side lines, a cel shade step under the chin (like the concept)"""
    w = max(4, int(round(w_rig * ATLAS_K)))
    h = max(4, int(round(h_rig * ATLAS_K)))
    ink = np.array([0x3A, 0x2A, 0x22], np.float32) / 255.0
    lw = max(1.5, 5.5 * ATLAS_K)
    xx = np.arange(w)[None, :] + 0.5
    yy = np.arange(h)[:, None] + 0.5
    edge = np.minimum(xx, w - xx)
    col = np.where((yy < 0.45 * h)[..., None], skin * 0.84, skin)              # shade under the chin
    a_ink = np.clip(lw - edge + 0.5, 0, 1) * np.ones((h, 1))
    rgb = col * (1 - a_ink[..., None]) + ink * a_ink[..., None]
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = (rgb * 255).astype(np.uint8)
    out[..., 3] = 255
    m = np.zeros((h, w, 3), np.float32)
    m[..., 0] = 1.0 - a_ink
    return out, m


def hexrgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0



# ───────────── Q22 step 4 (2026-11-12): head VARIANTS, beard overlays, freckles out of the drawing, face anchors for marks ─────────────
# heads.py made parts/<set>/<view>/head_<var>.png (same face, other hair; a canvas padded by heads.PAD piece px around the original)
# and parts/d/<view>/beard_<var>.png (overlay on the same padded canvas). Every one becomes a quad of its head set:
#   head variants: group 1, part "head", "hv" = HEAD_VAR id (0 = the original drawing) — the shader shows the one the resident wears
#   beards       : group 7, part "beard", "hv" = BEARD id, over the head (layer + 0.5), dyed with the hair channel
# The NEW quads are packed into the free space of the atlas (the old quads keep their place — the atlas stays 2048 x 2048).
# Freckles drawn on heads d and f are erased (they follow the freckle gene now — a shader mark, like the white forelock and the
# speckle pattern); head_eye / head_mark (per head set x view, head frame rig units) give the shader the eyes and the hairline.
HEAD_VAR = {"wavy": 1, "curly": 2, "thin": 3, "straight": 4}
BEARD = {"short": 1, "full": 2}
VAR_PAD = 56                 # = heads.PAD
FRECKLED = ("d", "f")


def _hn():
    import heads
    return heads.ndimage, heads.largest_blob


def head_variants(extra, s, v, d, q, rig_rect, hp, f_head, ch, layer, slot, chans, base_rr, wb, hb):
    """the head variants / beards of head set s, view v (heads.py output) -> quads in `extra` (same frame as the original head)"""
    P = VAR_PAD
    for f in sorted(os.listdir(d)):
        if not (f.startswith("head_") or f.startswith("beard_")) or not f.endswith(".png"):
            continue
        beard = f.startswith("beard_")
        var = f[:-4].split("_", 1)[1]
        a = np.asarray(Image.open(os.path.join(d, f)).convert("RGBA")).copy()
        if not (a[..., 3] > 128).any():
            continue
        if not beard and s in FRECKLED and v in ("front", "q_front"):
            a, _n = erase_freckles(a, hexrgb(BASE[s]["skin"]))
        if not beard:
            # the drawn neck stub (same rows / columns as the original's, + the padding) — like the original head
            sw = ch["x1"] - ch["x0"] + 1
            x0, x1, cy, yb = ch["x0"] + P, ch["x1"] + P, ch["y"] + P, ch["yb"] + P
            lo = max(0, x0 - 18)
            for yy in range(cy + 3, min(a.shape[0], yb + 6)):
                row = a[yy, lo: x1 + 19, 3] > 128
                xs_ = np.nonzero(row)[0]
                if len(xs_) and (xs_.max() - xs_.min() + 1) <= sw + 10:
                    a[yy, max(0, x0 - 4): x1 + 5, 3] = 0
        # resample EXACTLY like the original head (same scale and pixel phase — PIL resize with a box shifted by whole atlas
        # pixels), so the face pixels in the atlas are the original's to the last bit; then crop to what is drawn (whole pixels)
        w0, h0 = Image.open(os.path.join(d, "head.png")).size
        sx, sy = wb / float(w0), hb / float(h0)
        ax, ay = int(P * sx), int(P * sy)
        box = (P - ax / sx, P - ay / sy, P + w0 + ax / sx, P + h0 + ay / sy)
        big = np.asarray(Image.fromarray(a).resize((wb + 2 * ax, hb + 2 * ay), Image.LANCZOS, box=box))
        ys_, xs_ = np.nonzero(big[..., 3] > 0)
        cx0, cy0 = max(0, xs_.min() - 1), max(0, ys_.min() - 1)
        cx1, cy1 = min(big.shape[1], xs_.max() + 2), min(big.shape[0], ys_.max() + 2)
        img = np.ascontiguousarray(big[cy0:cy1, cx0:cx1])
        kx = wb / (base_rr[2] - base_rr[0])
        ky = hb / (base_rr[3] - base_rr[1])
        rr = [base_rr[0] + (cx0 - ax) / kx, base_rr[3] - (cy1 - ay) / ky, base_rr[0] + (cx1 - ax) / kx, base_rr[3] - (cy0 - ay) / ky]
        ch_ = ["hair"] if beard else list(chans)
        bases = [hexrgb(BASE[s][c]) for c in ch_]
        mask = fill_mask(img, dye_mask(img, bases))
        img = neutral_ink(img, mask, ch_)
        extra.append((img, mask, {
            "set": s, "view": VIEWS.index(v), "part": "beard" if beard else "head", "group": 7 if beard else 1, "slot": slot,
            "rect": [round(x, 2) for x in rr], "pivot": [0.0, 0.0], "parent_pivot": [0.0, 0.0], "grip": [0.0, 0.0, 0.0, 0.0],
            "layer": layer + (0.5 if beard else 0.0),
            "dye": [SLOTS[c] for c in ch_] + [-1] * (3 - len(ch_)),
            "base": [list(map(float, hexrgb(BASE[s][c]))) for c in ch_] + [[1, 1, 1]] * (3 - len(ch_)),
            "hv": (BEARD if beard else HEAD_VAR)[var]}))


# Q22 step 4 (2026-11-12): the dye mask is PACKED like the method C body masks (tools/cutout_c/pack_masks.py) — it has only a few
# distinct texel values (one-hot dye channel weights, the neck's ink edge and the bleed into the padding: ~100), so
#   doll_mcode.png  L8, atlas size, nearest, no mipmaps: one byte per texel = a row of the code table (EXACT at level 0)
#   doll_mlut.png   256 x 1 RGBA8: code -> mask RGB (the old doll_mask.png values) — cut_lib.mask_lut() hands the first 128 to the
#                   shaders as a uniform array (a texture more made the method C shader leave discarded texels black)
#   doll_mq.png     the old mask at a quarter of the size (= its mip level 2, box filtered like Godot's own mipmaps), mipmapped
# The shaders (cut_doll / frame_doll head_mask()) filter level 0 / 1 themselves from the codes and let the GPU filter the quarter mask
# further away — the same numbers the old mipmapped RGBA mask gave, at about a quarter of its graphics memory.
GROW = 128


def _box(x):
    x = x.astype(np.int32)
    return ((x[0::2, 0::2] + x[1::2, 0::2] + x[0::2, 1::2] + x[1::2, 1::2] + 2) >> 2).astype(np.uint8)


def pack_mask(rgb):
    h, w = rgb.shape[:2]
    assert h % 4 == 0 and w % 4 == 0
    t = rgb.reshape(-1, 3)
    u, inv, cnt = np.unique(t, axis=0, return_inverse=True, return_counts=True)
    if len(u) > 128:
        raise SystemExit("build_atlas: %d distinct mask texels > 128 (the shaders read the code table as a vec3[128])" % len(u))
    # code 0 = no dye (the most common value) — keep the order stable: by count, then value
    order = np.lexsort((u[:, 2], u[:, 1], u[:, 0], -cnt))
    rank = np.empty(len(u), np.int32)
    rank[order] = np.arange(len(u))
    codes = rank[inv.reshape(-1)].astype(np.uint8).reshape(h, w)
    lut = np.zeros((1, 256, 4), np.uint8)
    lut[0, :len(u), :3] = u[order]
    lut[0, :, 3] = 255
    Image.fromarray(codes, "L").save(os.path.join(ART, "doll_mcode.png"), optimize=True)
    Image.fromarray(lut, "RGBA").save(os.path.join(ART, "doll_mlut.png"), optimize=True)
    q = np.dstack([rgb, np.full((h, w), 255, np.uint8)])
    Image.fromarray(_box(_box(q)), "RGBA").save(os.path.join(ART, "doll_mq.png"), optimize=True)
    print("mask packed: %d codes, quarter %dx%d" % (len(u), w // 4, h // 4))


def fill_mask(img, w, steps=3, ink_l=0.2):
    """(Q22 ④, 2026-11-12) head pieces: opaque pixels that no dye channel claimed (hair highlights / shade grains and the anti-aliased
    rim between hair and skin whose colour is neither base) kept their drawn colour, so a dyed head showed a fringe of drawn-brown /
    orange specks along hair edges and beard bottoms. Every such pixel that is not ink (luma >= ink_l) takes the channel of its
    nearest claimed neighbour (up to `steps` px away). Ink lines stay undyed."""
    a = img[..., 3] > 128
    rgb = img[..., :3].astype(np.float32) / 255.0
    l = lum(rgb)
    w = w.copy()
    free = a & (w.sum(-1) < 0.5) & (l >= ink_l)
    for _ in range(steps):
        if not free.any():
            break
        claimed = w.sum(-1) > 0.5
        acc = np.zeros_like(w)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            acc += np.roll(np.roll(w * claimed[..., None], dy, 0), dx, 1)
        take = free & (acc.sum(-1) > 0)
        if not take.any():
            break
        idx = acc.argmax(-1)
        nw = np.zeros_like(w)
        for c in range(w.shape[-1]):
            nw[..., c] = (idx == c)
        w[take] = nw[take]
        free &= ~take
    return w


INK_RGB = np.array([0x3A, 0x2A, 0x22], np.float32) / 255.0     # the concept's ink


def neutral_ink(img, w, chans, near=2):
    """(Q22 ④, 2026-11-12) the ink of the red-haired heads (d, f and their variants) was drawn red-brown (~#38190B); with any other hair
    dye the hair outline / beard rim then read as an orange fringe. Ink pixels (undyed, dark) that touch hair and do NOT touch skin are
    set to the concept ink hue at their own brightness — hair outlines only; face lines (eyes, brows, mouth, jaw) touch skin and stay."""
    if "hair" not in chans:
        return img
    hi = chans.index("hair")
    si = chans.index("skin") if "skin" in chans else -1
    nd, _lb = _hn()
    a = img[..., 3] > 0
    rgb = img[..., :3].astype(np.float32) / 255.0
    l = lum(rgb)
    ink = a & (w.sum(-1) < 0.5) & (l < 0.2)
    hair = nd.binary_dilation(w[..., hi] > 0.5, iterations=near)
    skin = nd.binary_dilation(w[..., si] > 0.5, iterations=near) if si >= 0 else np.zeros_like(hair)
    sel = ink & hair & ~skin
    if not sel.any():
        return img
    out = img.copy()
    lt = float(lum(INK_RGB))
    out[..., :3][sel] = np.clip(INK_RGB[None, :] * (l[sel] / lt)[:, None] * 255.0, 0, 255).astype(np.uint8)
    return out


def face_skin(p, skin):
    nd, lb = _hn()
    a = p[..., 3] > 128
    rgb = p[..., :3].astype(np.float32) / 255.0
    l = np.maximum(lum(rgb), 1e-3)
    ls = float(lum(skin))
    d = np.abs(rgb / l[..., None] - skin / ls).sum(-1)
    sk = a & (d < 0.42) & (l / ls > 0.6) & (l / ls < 1.25)
    sk = nd.binary_opening(sk, iterations=1)
    sk = lb(sk) if sk.any() else sk
    return sk, nd.binary_fill_holes(nd.binary_closing(sk, iterations=3)) & a, l, ls


def freckle_mask(p, skin):
    """drawn freckles: small spots inside the face that are darker / more saturated than the skin but not ink (eyes, brows, lines)"""
    nd, _lb = _hn()
    sk, filled, l, ls = face_skin(p, skin)
    inner = nd.binary_erosion(filled, iterations=4)
    rgb = p[..., :3].astype(np.float32) / 255.0
    sat = rgb.max(-1) - rgb.min(-1)
    ssat = float(skin.max() - skin.min())
    # a freckle = a small spot a little darker / more saturated than the skin, not an ink line (eyes, brows, nose, mouth are darker)
    spot = inner & ~sk & (l > 0.42 * ls) & (l < 0.985 * ls) & (sat > ssat * 0.9)
    lab, n = nd.label(spot)
    out = np.zeros_like(spot)
    for i in range(1, n + 1):
        r = lab == i
        if r.sum() <= 40:
            out |= r
    return nd.binary_dilation(out, iterations=2) & inner


def erase_freckles(arr, skin):
    """paint the drawn freckles with the surrounding skin (median of the skin ring around each)"""
    nd, _lb = _hn()
    fm = freckle_mask(arr, skin)
    if not fm.any():
        return arr, 0
    sk, _f, _l, _ls = face_skin(arr, skin)
    out = arr.copy()
    ring = nd.binary_dilation(fm, iterations=3) & sk & ~fm
    src = arr[..., :3].astype(np.float32) * ring[..., None]
    acc = nd.gaussian_filter(src[..., 0], 2.5), nd.gaussian_filter(src[..., 1], 2.5), nd.gaussian_filter(src[..., 2], 2.5)
    wgt = nd.gaussian_filter(ring.astype(np.float32), 2.5)
    fill = np.stack(acc, -1) / np.maximum(wgt, 1e-4)[..., None]
    out[..., :3][fm] = np.clip(fill[fm], 0, 255).astype(np.uint8)
    return out, int(fm.sum())


def face_anchors(p, skin):
    """eyes (the best pair of solid, upright dark dots inside the face, at about the same height) + the hairline point above them
    (piece px). None when no pair is found (back views)."""
    nd, _lb = _hn()
    sk, filled, l, ls = face_skin(p, skin)
    if filled.sum() < 200:
        return None
    edge = filled & ~nd.binary_erosion(filled, iterations=2)
    dark = filled & (l < min(0.33, 0.55 * ls))
    lab, n = nd.label(dark)
    ys_f = np.nonzero(filled.any(1))[0]
    fh = float(ys_f.max() - ys_f.min() + 1)
    blobs = []
    for i in range(1, n + 1):
        r = lab == i
        a_ = int(r.sum())
        if a_ < 40 or (r & edge).sum() > 0.2 * a_:
            continue
        ys, xs = np.nonzero(r)
        hh, ww = ys.max() - ys.min() + 1, xs.max() - xs.min() + 1
        if a_ / float(hh * ww) >= 0.6 and hh >= 0.8 * ww and hh <= 3.0 * ww:
            blobs.append((a_, xs.mean(), ys.mean(), 0.5 * max(hh, ww)))
    best, bs = None, 1e9
    for i in range(len(blobs)):
        for j in range(i + 1, len(blobs)):
            A, B_ = blobs[i], blobs[j]
            dx, dy = abs(A[1] - B_[1]), abs(A[2] - B_[2])
            if dx < 3.0 * max(A[3], B_[3]) or dy > 0.12 * fh:
                continue
            sc = dy / fh + abs(A[0] - B_[0]) / max(A[0], B_[0]) + abs((A[2] + B_[2]) / 2 - ys_f.min() - 0.5 * fh) / fh
            if sc < bs:
                best, bs = (A, B_), sc
    if best is None:
        return None
    eyes = sorted(best, key=lambda e: e[1])
    mx = 0.5 * (eyes[0][1] + eyes[1][1])
    col = np.nonzero(filled[:, int(round(mx))])[0]
    top = int(col.min()) if len(col) else int(min(eyes[0][2], eyes[1][2]) - 40)
    fx = np.nonzero(filled.any(0))[0]
    return {"eyes": [(e[1], e[2], e[3]) for e in eyes], "hair": (mx, float(top)), "half_w": 0.5 * float(fx.max() - fx.min())}


def lum(c):
    return c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114


def dye_mask(rgba, bases):
    """weights (h, w, 3): pixel -> nearest channel base by chromaticity, if its brightness is a lit or shade version of it"""
    rgb = rgba[..., :3].astype(np.float32) / 255.0
    l = np.maximum(lum(rgb), 1e-3)[..., None]
    chrom = rgb / l
    best = np.full(rgb.shape[:2], 9.0)
    idx = np.full(rgb.shape[:2], -1)
    for i, b in enumerate(bases):
        lb = max(float(lum(b)), 1e-3)
        r = l[..., 0] / lb
        d = np.abs(chrom - b / lb).sum(-1) + 0.35 * np.abs(np.log(np.maximum(r, 1e-3)))
        ok = (r > 0.55) & (r < 1.2) & (d < 0.45)
        upd = ok & (d < best)
        best[upd] = d[upd]
        idx[upd] = i
    w = np.zeros(rgb.shape[:2] + (3,), np.float32)
    for i in range(len(bases)):
        w[..., i] = (idx == i)
    return w


def dilate_rgb(rgba):
    """bleed colour into transparent padding (no dark fringes when mipmaps blend with alpha 0 texels)"""
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
        out[..., 3][grow] = 1     # marker only (alpha restored below)
    out[..., 3] = np.where(a, rgba[..., 3], 0)
    return out


def main():
    items = []     # (img, mask, meta)
    extra = []     # Q22 step 4: head variants + beards, packed into the free space after the old quads
    head_eye = {}
    head_mark = {}
    head_socket = {}
    head_top = {}
    head_scale = {}
    head_brow = {}
    brow_depth = {}
    for s in EXPECT:
        BASE[s] = auto_base(s)
        print("base", s, BASE[s])
    for s in SETS:
        bt = BODY[s]
        for v in VIEWS:
            d = os.path.join(PARTS, s, v)
            pl = json.load(open(os.path.join(d, "place.json")))
            fg = pl["figure"]
            k = FIG / (fg["feet_y"] + 1)
            cx, fy = fg["cx"], fg["feet_y"]

            def rig_rect(q):
                x0 = (q["x"] - cx) * k
                x1 = (q["x"] + q["w"] - cx) * k
                y1 = (fy - q["y"]) * k
                y0 = (fy - q["y"] - q["h"]) * k
                return [x0, y0, x1, y1]

            # --- head on a NECK SOCKET (2026-11-08 review: "residents look neckless") ---
            # head pivot = CHIN (found on the head piece), the drawn neck stub below the chin is erased and replaced by a
            # generated neck piece; every head set is scaled to the concept-A head size; the socket = body collar top + concept neck.
            hq = pl["head"]
            hpng = np.asarray(Image.open(os.path.join(d, "head.png")).convert("RGBA"))
            ch = find_chin(hpng, hexrgb(BASE[s]["skin"]))
            chin = [(hq["x"] + ch["x"] * hq["sx"] - cx) * k, (fy - (hq["y"] + ch["y"] * hq["sy"])) * k]
            hr = rig_rect(hq)
            hp = chin
            f_head = HEAD_H.get(s, HEAD_H["bare"]) / max(hr[3] - chin[1], 1.0)
            head_scale["%s_%s" % (s, v)] = round(f_head, 3)
            # collar top of THIS set's body under the chin -> neck socket
            bq = pl["body"]
            bpng = np.asarray(Image.open(os.path.join(d, "body.png")).convert("RGBA"))
            bx = int(round((hq["x"] + ch["x"] * hq["sx"] - bq["x"]) / bq["sx"]))
            band = bpng[:, max(0, bx - 6): bx + 7, 3].max(axis=1) > 128
            by = int(np.argmax(band)) if band.any() else 0
            collar_y = (fy - (bq["y"] + by * bq["sy"])) * k
            # body type: the body pieces are scaled about the feet (bs, bsy) -> the socket moves with the collar; neck per body
            fwd = bt.get("head_fwd", 0.0) if v in ("q_front", "q_back") else 0.0     # stoop: head forward (3/4 views face image-right)
            head_socket["%s_%s" % (s, v)] = [chin[0] * bt["bs"] + fwd, collar_y * bt["bs"] * bt["bsy"] + bt["neck"]]
            ht = [(hr[0] + hr[2]) / 2, hr[3]]                               # top of the (bare) head
            # hat SEAT = brow line below the head top (front / 3/4-front measured on the face; the back views have no face
            # and use the depth of the matching front view; a 3/4 reading far from the front's (white brows -> eyes) too)
            by_ = find_brow(hpng, hexrgb(BASE[s]["skin"]))
            meas = by_ * hq["sy"] * k * f_head if by_ is not None else None
            bd = brow_depth.setdefault(s, {})
            if v == "front":
                bd[v] = meas if meas is not None else BROW_DEFAULT * HEAD_H["bare"]
            elif v == "q_front":
                bd[v] = meas if meas is not None and abs(meas - bd["front"]) < BROW_MAX_DIFF * HEAD_H["bare"] else bd["front"]
            else:
                bd[v] = bd["q_front" if v == "q_back" else "front"]
            head_brow["%s_%s" % (s, v)] = round(bd[v], 2)
            head_top["%s_%s" % (s, v)] = [(ht[0] - hp[0]) * f_head, (ht[1] - hp[1]) * f_head - bd[v]]
            # generated neck (skin, dyed with the skin channel), drawn behind the body's collar and behind the head
            nw = (ch["x1"] - ch["x0"]) * hq["sx"] * k * f_head
            nimg, nmask = neck_image(nw, NECK_VIS + 70.0, hexrgb(BASE[s]["skin"]))
            items.append((nimg, nmask, {
                "set": s, "view": VIEWS.index(v), "part": "neck", "group": 1, "slot": 2,
                "rect": [-nw / 2, -(NECK_VIS + 55.0), nw / 2, 15.0], "pivot": [0.0, 0.0], "parent_pivot": [0.0, 0.0],
                "layer": ORDER[v].index("neck"), "dye": [SLOTS["skin"], -1, -1],
                "base": [list(map(float, hexrgb(BASE[s]["skin"]))), [1, 1, 1], [1, 1, 1]]}))
            for name, q in pl.items():
                if name == "figure":
                    continue
                kind = name.split("_")[0]
                r = rig_rect(q)
                pname = "hat" if (name == "knot" and s != "a") else name
                scale = 1.0
                if pname in ("head", "tail") or (pname == "knot"):
                    group, frame, scale = 1, hp, f_head
                elif pname == "hat":
                    group, frame, scale = 2, ht, f_head    # headwear sits on the head TOP (any head shape/height)
                else:
                    group, frame = 0, [0.0, 0.0]
                rr = [(r[0] - frame[0]) * scale, (r[1] - frame[1]) * scale, (r[2] - frame[0]) * scale, (r[3] - frame[1]) * scale]
                if pname == "hat":      # frame = the seat (brow line), bd[v] below the head top
                    rr = [rr[0], rr[1] + bd[v], rr[2], rr[3] + bd[v]]
                if pname == "tail" and (s, v) in TAIL_FIX:
                    tk, tdx, tdy = TAIL_FIX[(s, v)]
                    tcx = (rr[0] + rr[2]) / 2
                    rr = [tcx + (rr[0] - tcx) * tk + tdx, rr[3] - (rr[3] - rr[1]) * tk + tdy, tcx + (rr[2] - tcx) * tk + tdx, rr[3] + tdy]
                    print("braid fix", s, v, [round(x) for x in rr])
                if kind == "head":
                    piv = [0.0, 0.0]
                elif kind in ("sleeve", "arm"):
                    sr = rig_rect(pl["sleeve" + name[-2:]]) if ("sleeve" + name[-2:]) in pl else r
                    shoulder = [(sr[0] + sr[2]) / 2, sr[3] - 0.15 * (sr[3] - sr[1])]
                    # forearm turns about the CENTRE of the sleeve puff (its stub stays inside the puff) and follows the shoulder
                    piv = shoulder if kind == "sleeve" else [(sr[0] + sr[2]) / 2, (sr[1] + sr[3]) / 2]
                elif kind == "leg":
                    piv = [(r[0] + r[2]) / 2, r[3] - 0.1 * (r[3] - r[1])]           # hip
                elif kind == "body":
                    piv = [(r[0] + r[2]) / 2, r[1] + 0.55 * (r[3] - r[1])]          # waist
                elif kind == "cane":
                    # walking stick (elder): rides on the nearer HAND but stays upright (shader: moved by the hand, not turned)
                    ccx = (r[0] + r[2]) / 2
                    side = min("ab", key=lambda sd: abs((rig_rect(pl["arm_" + sd])[0] + rig_rect(pl["arm_" + sd])[2]) / 2 - ccx))
                    ar = rig_rect(pl["arm_" + side])
                    sr = rig_rect(pl["sleeve_" + side])
                    shoulder = [(sr[0] + sr[2]) / 2, sr[3] - 0.15 * (sr[3] - sr[1])]
                    piv = [(sr[0] + sr[2]) / 2, (sr[1] + sr[3]) / 2]
                    grip = [(ar[0] + ar[2]) / 2, ar[1] + 0.18 * (ar[3] - ar[1])]
                    # stick = from the ground up into the hanging hand (its top just above the fist) — the figure may hold it
                    # elsewhere; only its drawn width is kept
                    cw = r[2] - r[0]
                    r = [grip[0] - cw / 2, 0.0, grip[0] + cw / 2, grip[1] + 0.12 * (ar[3] - ar[1])]
                    rr = list(r)
                else:   # tail / knot / hat: hangs from its top
                    piv = [(rr[0] + rr[2]) / 2, rr[3]]
                img = Image.open(os.path.join(d, name + ".png")).convert("RGBA")
                if pname == "hat":
                    tilt = hat_tilt(s, v)
                    if tilt != 0.0:
                        img, rr = deskew(img, rr, tilt)
                        piv = [(rr[0] + rr[2]) / 2, rr[3]]
                        print("deskew hat", s, v, round(tilt, 1))
                    if HAT_KIND.get(s, "wrap") != "wrap":
                        rr, info = sink_hat(img, rr, HAT_KIND[s], v)
                        piv = [(rr[0] + rr[2]) / 2, rr[3]]
                        print("sink hat", s, v, info)
                if kind == "head" and s in FRECKLED and v in ("front", "q_front"):
                    a0, nf = erase_freckles(np.asarray(img).copy(), hexrgb(BASE[s]["skin"]))
                    img = Image.fromarray(a0)
                    print("freckles erased", s, v, nf)
                if kind == "head":
                    a = np.asarray(img).copy()
                    # erase the drawn neck stub only: rows below the chin whose opaque run is stub-narrow (3/4 views: the
                    # jaw beside the neck can hang lower than the chin point and must stay)
                    sw = ch["x1"] - ch["x0"] + 1
                    lo = max(0, ch["x0"] - 18)
                    for yy in range(ch["y"] + 3, min(a.shape[0], ch["yb"] + 6)):
                        row = a[yy, lo: ch["x1"] + 19, 3] > 128
                        xs_ = np.nonzero(row)[0]
                        if len(xs_) and (xs_.max() - xs_.min() + 1) <= sw + 10:      # nothing but the stub in this row
                            a[yy, max(0, ch["x0"] - 4): ch["x1"] + 5, 3] = 0
                    img = Image.fromarray(a)
                w = max(2, int(round((rr[2] - rr[0]) * ATLAS_K)))
                h = max(2, int(round((rr[3] - rr[1]) * ATLAS_K)))
                img = np.asarray(img.resize((w, h), Image.LANCZOS))
                chans = list(CHANNELS.get(kind if pname != "hat" else "knot", []))
                if kind == "head" and s != "a":
                    chans = ["skin", "hair"]
                if kind == "leg":
                    chans = LEGS.get(s, ["legwear", "shoe", LEG3.get(s, "skin")])
                bases = [hexrgb(BASE[s][c]) for c in chans]
                mask = dye_mask(img, bases) if chans else np.zeros(img.shape[:2] + (3,), np.float32)
                if kind in ("head", "tail") and chans:
                    mask = fill_mask(img, mask)     # (Q22 ④) 물감이 안 묻은 머리 · 피부 화소 (붉은 가장자리 점)를 이웃 칸으로
                    img = neutral_ink(img, mask, chans)
                layer = ORDER[v].index(pname if pname in ORDER[v] else "knot")
                slot = SLOT_OF.get(pname, 1)
                gp = [0.0, 0.0, 0.0, 0.0]
                if kind == "cane":
                    layer = ORDER[v].index("arm_" + side) - 0.5
                    slot = SLOT_OF["arm_" + side]
                    gp = [grip[0], grip[1], 1.0, 0.0]
                pp = shoulder if kind in ("arm", "cane") else [0.0, 0.0]
                if group == 0:
                    # body type: scale the body pieces about the feet (rect, pivots, grip)
                    fx, fy_ = bt["bs"], bt["bs"] * bt["bsy"]
                    rr = [rr[0] * fx, rr[1] * fy_, rr[2] * fx, rr[3] * fy_]
                    piv = [piv[0] * fx, piv[1] * fy_]
                    pp = [pp[0] * fx, pp[1] * fy_]
                    gp = [gp[0] * fx, gp[1] * fy_, gp[2], gp[3]]
                items.append((img, mask, {
                    "set": s, "view": VIEWS.index(v), "part": pname, "group": group, "slot": slot,
                    "rect": [round(x, 2) for x in rr], "pivot": [round(x, 2) for x in piv],
                    "parent_pivot": [round(x, 2) for x in pp], "grip": [round(x, 2) for x in gp],
                    "layer": layer,
                    "dye": [SLOTS[c] for c in chans] + [-1] * (3 - len(chans)),
                    "base": [list(map(float, hexrgb(BASE[s][c]))) for c in chans] + [[1, 1, 1]] * (3 - len(chans)),
                }))
                if kind == "head":
                    head_variants(extra, s, v, d, q, rig_rect, hp, f_head, ch, layer, slot, chans, rr, w, h)
                    # face anchors for the shader marks (freckles, forelock, speckle) — head frame rig units, like the quads
                    def px2rig(px, py):
                        return [((q["x"] + px * q["sx"] - cx) * k - hp[0]) * f_head, ((fy - (q["y"] + py * q["sy"])) * k - hp[1]) * f_head]
                    fa = face_anchors(np.asarray(Image.open(os.path.join(d, "head.png")).convert("RGBA")), hexrgb(BASE[s]["skin"])) \
                        if v in ("front", "q_front") else None
                    key = "%s_%s" % (s, v)
                    if fa:
                        e0 = px2rig(*fa["eyes"][0][:2])
                        e1 = px2rig(*fa["eyes"][1][:2])
                        hr_ = px2rig(*fa["hair"])
                        er = max(fa["eyes"][0][2], fa["eyes"][1][2]) * q["sx"] * k * f_head
                        head_eye[key] = [round(x, 2) for x in e0 + e1]
                        head_mark[key] = [round(er, 2), round(hr_[0], 2), round(hr_[1], 2), round(fa["half_w"] * q["sx"] * k * f_head, 2)]
                    else:
                        top = [((rr[0] + rr[2]) / 2), rr[3]]
                        head_eye[key] = [0.0, 0.0, 0.0, 0.0]
                        head_mark[key] = [0.0, round(top[0], 2), round(top[1] - 40.0, 2), round((rr[2] - rr[0]) * 0.4, 2)]
    spread_stacked_legs(items)
    # face anchors that did not read (e: beard merges with the dark skin; g 3/4: the far eye hides in the ear line) or read implausibly
    # (3/4 eyes must sit on the image-right half, front eyes about the middle) take head d's (all heads share HEAD_H and the chin origin)
    for s in SETS:
        for v in ("front", "q_front"):
            key = "%s_%s" % (s, v)
            e = head_eye[key]
            mx = 0.5 * (e[0] + e[2])
            ok = e != [0.0, 0.0, 0.0, 0.0] and (mx > 5.0 if v == "q_front" else abs(mx) < 25.0)
            if not ok:
                head_eye[key] = list(head_eye["d_" + v])
                head_mark[key] = list(head_mark["d_" + v])
                print("face anchors", key, "-> from d")
    # props: drawn at ~sheet scale; rig size = 0.55 of drawn px (a loaf ~ 1/4 of her width)
    pd = os.path.join(PARTS, "props")
    for p in PROPS:
        f = os.path.join(pd, p + ".png")
        if not os.path.exists(f):
            continue
        img = Image.open(f).convert("RGBA")
        sc = {"hoe": 1.55, "rake": 1.55, "sickle": 0.8, "mallet": 0.8, "seed": 0.7, "wheat": 1.0}.get(p, 0.5)   # long tools ~ her height
        rw, rh = img.width * sc, img.height * sc
        w, h = int(round(rw * ATLAS_K)), int(round(rh * ATLAS_K))
        gx, gy = PROP_GRIP.get(p, (0.5, 0.5))
        img = np.asarray(img.resize((w, h), Image.LANCZOS))
        items.append((img, np.zeros(img.shape[:2] + (3,), np.float32), {
            "set": p, "view": -1, "part": "prop", "group": 3, "slot": 10,
            "rect": [-rw * gx, -rh * (1.0 - gy), rw * (1.0 - gx), rh * gy], "pivot": [0.0, 0.0], "parent_pivot": [0.0, 0.0], "layer": 0,
            "dye": [-1, -1, -1], "base": [[1, 1, 1]] * 3}))
    # shelf pack, tallest first
    late = {i: PROP_LATE[m["set"]] for i, (_img, _mask, m) in enumerate(items) if m["part"] == "prop" and m["set"] in PROP_LATE}
    size = lambda i: late[i] if i in late else items[i][0].shape[:2]
    order = sorted(range(len(items)), key=lambda i: -size(i)[0])
    x = y = shelf = 0
    pos = {}
    # a late one comes twice: first its reserved cell (in the old order), then the picture itself after everything else
    for i, (h, w) in [(i, size(i)) for i in order] + [(i, items[i][0].shape[:2]) for i in late]:
        if x + w + 2 * PAD > ATLAS_W:
            x, y, shelf = 0, y + shelf, 0
        pos[i] = (x + PAD, y + PAD)
        x += w + 2 * PAD
        shelf = max(shelf, h + 2 * PAD)
    H = 1 << int(np.ceil(np.log2(y + shelf)))
    # Q22 step 4: the new quads go into the free space left by the shelves (first fit, tallest first) — old quads keep their place
    occ = np.zeros((H, ATLAS_W), bool)
    for i, (img_, _m, _meta) in enumerate(items):
        px, py = pos[i]
        hh, ww = img_.shape[:2]
        occ[max(0, py - PAD): py + hh + PAD, max(0, px - PAD): px + ww + PAD] = True
    base_n = len(items)
    for j in sorted(range(len(extra)), key=lambda j: -extra[j][0].shape[0]):
        img_, m_, meta_ = extra[j]
        hh, ww = img_.shape[0] + 2 * PAD, img_.shape[1] + 2 * PAD
        ii = np.zeros((H + 1, ATLAS_W + 1), np.int32)
        ii[1:, 1:] = occ.cumsum(0).cumsum(1)
        win = ii[hh:, ww:] - ii[:-hh, ww:] - ii[hh:, :-ww] + ii[:-hh, :-ww]
        free = np.argwhere(win == 0)
        while len(free) == 0:
            # no gap big enough: the atlas grows by GROW rows at the bottom (old quads keep their pixels; uv are renormalised)
            H += GROW
            occ = np.vstack([occ, np.zeros((GROW, ATLAS_W), bool)])
            ii = np.zeros((H + 1, ATLAS_W + 1), np.int32)
            ii[1:, 1:] = occ.cumsum(0).cumsum(1)
            win = ii[hh:, ww:] - ii[:-hh, ww:] - ii[hh:, :-ww] + ii[:-hh, :-ww]
            free = np.argwhere(win == 0)
        fy0, fx0 = free[0]
        items.append((img_, m_, meta_))
        pos[len(items) - 1] = (int(fx0) + PAD, int(fy0) + PAD)
        occ[fy0:fy0 + hh, fx0:fx0 + ww] = True
    print("extra quads", len(extra), "free rows left", int((~occ).all(1).sum()))
    atlas = np.zeros((H, ATLAS_W, 4), np.uint8)
    mask = np.zeros((H, ATLAS_W, 4), np.uint8)
    quads = []
    for i, (img, m, meta) in enumerate(items):
        px, py = pos[i]
        h, w = img.shape[:2]
        atlas[py:py + h, px:px + w] = img
        mm = np.dstack([m * 255.0, img[..., 3:4].astype(np.float32)]).astype(np.uint8)
        mask[py:py + h, px:px + w] = mm
        meta["uv"] = [px / ATLAS_W, py / H, (px + w) / ATLAS_W, (py + h) / H]
        quads.append(meta)
    atlas = dilate_rgb(atlas)
    # mask: bleed weights into the padding too
    mk = mask.copy(); mk[..., 3] = atlas[..., 3]
    mk2 = dilate_rgb(np.dstack([mk[..., :3], np.where(mask[..., 3] > 0, 255, 0).astype(np.uint8)]))
    mask[..., :3] = mk2[..., :3]
    mask[..., 3] = 255
    Image.fromarray(atlas).save(os.path.join(ART, "doll_atlas.png"))
    pack_mask(mask[..., :3])
    json.dump({"fig": FIG, "atlas": [ATLAS_W, H], "sets": SETS, "views": VIEWS, "props": PROPS,
               "prop_layer": [ORDER[v].index("prop") for v in VIEWS], "slots": SLOTS, "body_types": {s: BODY[s] for s in SETS}, "head_k": [BODY[s]["head_k"] for s in SETS], "head_socket": head_socket, "head_top": head_top, "head_brow": head_brow, "hat_kind": HAT_KIND, "hat_sink": HAT_SINK, "head_scale": head_scale, "base": BASE,
               "head_var": HEAD_VAR, "beard": BEARD, "head_eye": head_eye, "head_mark": head_mark, "quads": quads},
              open(os.path.join(ART, "doll_lib.json"), "w"), indent=0)
    print("atlas", ATLAS_W, "x", H, "quads", len(quads))


if __name__ == "__main__":
    main()
