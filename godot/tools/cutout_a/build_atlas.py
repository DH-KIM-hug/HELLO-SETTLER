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
SETS = ["a", "b", "c", "d"]
FIG = 920.0                 # rig units: every figure normalised to 920 tall (feet = 0, y up)
ATLAS_K = 0.45              # atlas px per rig unit (figure ~414 px tall in the atlas; 2048x1024 holds all 4 sets x 4 views + props)
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
    "front": ["leg_a", "leg_b", "tail", "knot", "body", "prop", "arm_a", "arm_b", "sleeve_a", "sleeve_b", "head", "hat"],
    "q_front": ["tail", "knot", "arm_b", "sleeve_b", "leg_b", "leg_a", "body", "prop", "arm_a", "sleeve_a", "head", "hat"],
    "q_back": ["prop", "arm_b", "sleeve_b", "leg_b", "leg_a", "body", "arm_a", "sleeve_a", "head", "tail", "knot", "hat"],
    "back": ["prop", "leg_a", "leg_b", "body", "arm_a", "arm_b", "sleeve_a", "sleeve_b", "head", "tail", "knot", "hat"],
}
# anim slots (shader): 0 root 1 body 2 head 3 sleeve_a 4 sleeve_b 5 arm_a 6 arm_b 7 leg_a 8 leg_b 9 accessory 10 prop
SLOT_OF = {"body": 1, "head": 2, "sleeve_a": 3, "sleeve_b": 4, "arm_a": 5, "arm_b": 6, "leg_a": 7, "leg_b": 8,
           "tail": 9, "knot": 9, "hat": 2, "prop": 10}
# groups: 0 outfit (body set S, rig frame) 1 head (head set T, frame = its head pivot) 2 headwear (set U, frame = U's head pivot) 3 prop
PROPS = ["bread", "twigs", "basket", "bread_q", "twigs_q", "basket_q", "hoe", "sickle", "rake", "mallet", "wheat", "bucket"]


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
    for s in SETS:
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

            hr = rig_rect(pl["head"])
            hp = [(hr[0] + hr[2]) / 2, hr[1] + 0.06 * (hr[3] - hr[1])]     # neck point = head pivot
            head_socket["%s_%s" % (s, v)] = hp
            ht = [(hr[0] + hr[2]) / 2, hr[3]]                               # top of the (bare) head
            head_top["%s_%s" % (s, v)] = [ht[0] - hp[0], ht[1] - hp[1]]
            for name, q in pl.items():
                if name == "figure":
                    continue
                kind = name.split("_")[0]
                r = rig_rect(q)
                pname = "hat" if (name == "knot" and s != "a") else name
                if pname in ("head", "tail") or (pname == "knot"):
                    group, frame = 1, hp
                elif pname == "hat":
                    group, frame = 2, ht        # headwear sits on the head TOP (any head shape/height)
                else:
                    group, frame = 0, [0.0, 0.0]
                rr = [r[0] - frame[0], r[1] - frame[1], r[2] - frame[0], r[3] - frame[1]]
                if kind == "head":
                    piv = [0.0, 0.0]
                elif kind in ("sleeve", "arm"):
                    sr = rig_rect(pl["sleeve" + name[-2:]]) if ("sleeve" + name[-2:]) in pl else r
                    shoulder = [(sr[0] + sr[2]) / 2, sr[3] - 0.15 * (sr[3] - sr[1])]
                    # arm = forearm: bends at the ELBOW (inside the bottom of the sleeve puff) and follows the sleeve (shoulder)
                    piv = shoulder if kind == "sleeve" else [(sr[0] + sr[2]) / 2, sr[1] + 0.3 * (sr[3] - sr[1])]
                elif kind == "leg":
                    piv = [(r[0] + r[2]) / 2, r[3] - 0.1 * (r[3] - r[1])]           # hip
                elif kind == "body":
                    piv = [(r[0] + r[2]) / 2, r[1] + 0.55 * (r[3] - r[1])]          # waist
                else:   # tail / knot / hat: hangs from its top
                    piv = [(rr[0] + rr[2]) / 2, rr[3]]
                if group == 0 and kind not in ("head",):
                    pass
                img = Image.open(os.path.join(d, name + ".png")).convert("RGBA")
                w = max(2, int(round((r[2] - r[0]) * ATLAS_K)))
                h = max(2, int(round((r[3] - r[1]) * ATLAS_K)))
                img = np.asarray(img.resize((w, h), Image.LANCZOS))
                chans = list(CHANNELS[kind if pname != "hat" else "knot"])
                if kind == "head" and s != "a":
                    chans = ["skin", "hair"]
                if kind == "leg":
                    chans = ["legwear", "shoe", LEG3.get(s, "skin")]
                bases = [hexrgb(BASE[s][c]) for c in chans]
                mask = dye_mask(img, bases)
                items.append((img, mask, {
                    "set": s, "view": VIEWS.index(v), "part": pname, "group": group, "slot": SLOT_OF.get(pname, 1),
                    "rect": [round(x, 2) for x in rr], "pivot": [round(x, 2) for x in piv],
                    "parent_pivot": [round(x, 2) for x in shoulder] if kind == "arm" else [0.0, 0.0],
                    "layer": ORDER[v].index(pname if pname in ORDER[v] else "knot"),
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
        sc = {"hoe": 1.55, "rake": 1.55, "sickle": 0.8, "mallet": 0.8}.get(p, 0.5)   # long tools ~ her height
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
               "slots": SLOTS, "head_socket": head_socket, "head_top": head_top, "base": BASE, "quads": quads},
              open(os.path.join(ART, "doll_lib.json"), "w"), indent=0)
    print("atlas", ATLAS_W, "x", H, "quads", len(quads))


if __name__ == "__main__":
    main()
