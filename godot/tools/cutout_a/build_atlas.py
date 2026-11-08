"""Cutout prototype v2 (concept A) — step 3: pack EVERY part of every set / view (+ props) into ONE atlas pair and write the
rig library the Godot doll reads.  (2026-11-08)

usage: python3 build_atlas.py
in : art/cutout/woman_a/parts/<set>/<view>/<part>.png + place.json (cut_sheets.py), parts/props/*.png
out: art/cutout/woman_a/doll_atlas.png  — the art as drawn (RGBA)
     art/cutout/woman_a/doll_mask.png   — dye weights: R/G/B = how much the pixel belongs to the part's dye channel 0/1/2
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


# concept A (res_A.png, adult woman front, 456 px tall): chin -> collar top 12 px = 2.6 % -> 24 rig units;
# top of the scarf -> chin 123 px = 27 % -> 248 rig units. Bare heads (no scarf) are a little lower on top.
NECK_VIS = 24.0
HEAD_H = {"a": 248.0, "bare": 232.0}


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
    head_socket = {}
    head_top = {}
    head_scale = {}
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
            head_top["%s_%s" % (s, v)] = [(ht[0] - hp[0]) * f_head, (ht[1] - hp[1]) * f_head]
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
    # props: drawn at ~sheet scale; rig size = 0.55 of drawn px (a loaf ~ 1/4 of her width)
    pd = os.path.join(PARTS, "props")
    for p in PROPS:
        f = os.path.join(pd, p + ".png")
        if not os.path.exists(f):
            continue
        img = Image.open(f).convert("RGBA")
        sc = {"hoe": 1.55, "rake": 1.55, "sickle": 0.8, "mallet": 0.8, "seed": 0.7}.get(p, 0.5)   # long tools ~ her height
        rw, rh = img.width * sc, img.height * sc
        w, h = int(round(rw * ATLAS_K)), int(round(rh * ATLAS_K))
        img = np.asarray(img.resize((w, h), Image.LANCZOS))
        items.append((img, np.zeros(img.shape[:2] + (3,), np.float32), {
            "set": p, "view": -1, "part": "prop", "group": 3, "slot": 10,
            "rect": [-rw / 2, -rh / 2, rw / 2, rh / 2], "pivot": [0.0, 0.0], "parent_pivot": [0.0, 0.0], "layer": 0,
            "dye": [-1, -1, -1], "base": [[1, 1, 1]] * 3}))
    # shelf pack, tallest first
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
    Image.fromarray(mask).save(os.path.join(ART, "doll_mask.png"))
    json.dump({"fig": FIG, "atlas": [ATLAS_W, H], "sets": SETS, "views": VIEWS, "props": PROPS,
               "prop_layer": [ORDER[v].index("prop") for v in VIEWS], "slots": SLOTS, "body_types": {s: BODY[s] for s in SETS}, "head_k": [BODY[s]["head_k"] for s in SETS], "head_socket": head_socket, "head_top": head_top, "head_scale": head_scale, "base": BASE, "quads": quads},
              open(os.path.join(ART, "doll_lib.json"), "w"), indent=0)
    print("atlas", ATLAS_W, "x", H, "quads", len(quads))


if __name__ == "__main__":
    main()
