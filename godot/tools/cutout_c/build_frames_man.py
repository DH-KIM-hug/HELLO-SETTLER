"""Q22 (2026-11-12) ADULT MAN body — a copy of build_frames.py (the woman's build, left untouched while the atlas-memory work changes
it) with: ART = art/cutout/man_c, pose references / load + baby pictures read from woman_c/raw (shared, WRAW), the far leg repainted
to the cream trouser / dark boot colours, classify_man() (garment colours of man_prompts.py: skin, tunic = main, vest = second,
belt = trim, trousers = leg, boots = shoe) and the vest/tunic seam recolour (VEST_SEAM). Output format = the woman's (frames.json,
frames_atlas.png, frames_mask0/1.png) so the runtime takes it as a second body. One command: python3 build_frames_man.py
(check images to $MAN_CHECK_DIR, default man_c/raw). Everything below is the woman's docstring.

Method-C resident spike (docs/RESIDENTS_2D.md section 7, 2026-11-08): frame sheets -> frame atlas + dye masks + anchors.

usage: python3 build_frames.py            (needs raw/{walk,carry,idle}_{front,q_front,q_back,back}.png)
in : art/cutout/woman_c/raw/<clip>_<view>.png  (gen.sh: 2x4 cells, magenta head placeholder, chroma green)
out: art/cutout/woman_c/frames_atlas.png  body+clothes per frame (the magenta head removed)
     art/cutout/woman_c/frames_mask0.png  dye weights R skin  G main  B second(cream)  A trim
     art/cutout/woman_c/frames_mask1.png  dye weights R legwear  G shoe  B hands of the carry / hold frames (not a dye: drawn again over the load, v12)  A far leg (3/4, darkened)
     art/cutout/woman_c/frames.json       per frame: uv rect, head anchor (chin, rig units, origin = soles centre, y up),
                                          hand anchors, sack box; per clip: frame count, stride; base colours
     raw/check_<clip>_<view>.png          aligned frames | dye-class view (eyeball check, not used by the game)
Per frame normalisation:
  walk / carry (traced from pose_ref.py, v4+): the cell template's ROOT — ground line y 470, cell centre x — is the origin and
    the scale is the template's (soles->chin 258 px = CHIN_RIG). The model traces the reference within a few px (head centre,
    chin and both boots), so the drawn frame's position inside its cell IS the animation (the puppet's 6 px bob included).
    2026-11-10 limp fix ("절뚝이면서 걷는디"): the old rule "lowest opaque row -> y 0" took the LOWEST BOOT as the ground; in the
    3/4 views the forward foot is drawn 30 px lower on the screen than the back foot (the step axis runs down the screen, the
    near foot 10 px below the far one), so the body was hoisted 20-33 px (40-64 rig, 7% of the height) once per cycle — a hop
    on one step. Front / back were symmetric (both feet on one depth line) but still bounced 2x per cycle.
  idle (free drawings): soles (lowest opaque row) -> y 0 (3/4 views: minus the near-foot depth offset), head centre -> x 0,
    scale per sheet from the median soles->chin -> CHIN_RIG."""
import json, os, sys
from collections import deque
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "cutout_a"))
import cut_sheets as C   # noqa: E402  key() + guide line removal (same 1536x1024 canvas)
import pose_ref as PR    # noqa: E402  cell template geometry (root, ground line, step S, foot depth offsets)
import pose_states as PS  # noqa: E402  v11 state sheets (sit / kneel / eat, look up, hoe, gather): puppets, clip entries, prop grips

ART = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "man_c"))   # Q22: the man body (copy of build_frames.py)
RAW = os.path.join(ART, "raw")
WRAW = os.path.normpath(os.path.join(ART, "..", "woman_c", "raw"))   # the woman's pose references and load / baby pictures (shared)
CHECK_DIR = os.environ.get("MAN_CHECK_DIR", RAW)   # check_<sheet>.png eyeball images
VIEWS = ["front", "q_front", "q_back", "back"]
CW, CH = 384, 512
FIG = 920.0            # rig units of the old doll (cut_lib fig) — same screen_h maps to the same height
D_RIG = 300.0          # nominal head placeholder diameter in rig units (head overlay size)
CHIN_RIG = 500.0      # v6: total figure no taller than the old cutout doll (was 560: +7..20% taller in game)       # soles -> chin in rig units (median per sheet) — same body size in every clip / view
PX_PER_RIG = 0.2       # atlas texel density (figure ~920 rig -> ~185 px; at ppu 44 the figure is ~50 px on screen)
# clips in the atlas: (name, sheet, cells)
# v12 (states5): carry / hold are drawn with EMPTY arms in the carry pose (carry_<view>.png, hold_<view>.png rows 2) — the load is
# an overlay picture chosen by what she carries (LOADS below), so wheat, flour and bread read differently
# v13 (states6): cradle (walking with a baby in her arms) / rock (standing with it) — the carry / hold sheets redrawn whole with
# the arms cradling in front of the chest (prompts.py REDRAW_SHEETS); the baby bundle is its own picture (BABY_PIC below)
CLIPS = [("walk", "walk", list(range(8))), ("carry", "carry", list(range(8))),
         ("idle", "idle", [0, 1, 2, 3]), ("hold", "hold", [4, 5, 6, 7]),
         ("cradle", "cradle", list(range(8))), ("rock", "rock", [4, 5, 6, 7])]
LOAD_CLIPS = ("carry", "hold")       # a load picture on the shoulder
BABY_CLIPS = ("cradle", "rock")      # the baby picture in the arms
ARM_CLIPS = LOAD_CLIPS + BABY_CLIPS  # traced sheets whose arms hold something (front views: hands drawn again over it)
GAIT_OF = {"cradle": "carry"}        # legs traced from that clip's sheets (stride, boot check)
# load pictures: raw/props_a.png, props_b.png (prompts.py PROP_SHEETS: 8 objects per sheet, cut by blob) -> (name, longer side in rig)
LOAD_SHEETS = ["props_a", "props_b", "props_c"]
LOAD_SIZE = {"flour": 330, "wheat": 390, "bread": 300, "logs": 300, "planks": 300, "stone": 250, "tools": 350, "water": 290,
             "grain": 330, "fruit": 290, "fish": 320, "meat": 300, "cotton": 300, "basket": 280, "silk": 290, "jar": 300}
# where the load sits, per view: (dx, dy px from the chin anchor to the load's bottom centre — image x right, y DOWN; lean rad, + = top
# to the image left). Front views: on her right shoulder at the image left, its bottom in the fist under it (the fists are drawn
# again over the load: mask1.B). Back views: behind her shoulder at the image right, the raised hand against its side.
# v13: 4th value = scale of the whole picture. Back views ("small, a wide-brim hat hides most of one" at ppu 20): the load sits
# further out and lower — beside the shoulder and the raised hand, clear of a hat brim — and a little bigger. Whole-picture
# transform only (the hat is not shrunk, nothing is cut).
LOAD_SEAT = {"front": (-104.0, 58.0, -0.1, 1.0), "q_front": (-102.0, 62.0, -0.1, 1.0),
             "q_back": (132.0, 66.0, 0.16, 1.15), "back": (136.0, 62.0, 0.16, 1.15)}
# v13 the baby in arms: which props_c picture each view shows, its longer side (rig) and its seat (same form as LOAD_SEAT: the
# picture's bottom centre from the chin anchor). Front views: the bundle lies on the crossed forearms, which are drawn again over
# its lower edge (mask1.B); back views: behind the body, the head end peeking out at her side.
BABY_PIC = {"front": "baby_b", "q_front": "baby_b", "q_back": "baby_back", "back": "baby_back"}
# v14 (Q16, GAME_DESIGN 3.0 "벤 이삭 하나를 어깨에 메고"): carried wheat = ONE big ear over the shoulder, as on the old doll — and
# it is the old doll's own ear picture (art/cutout/woman_a, prop "wheat": ear at the upper left, stalk to the lower right, the
# hand's place on the stalk = that picture's origin), not the sheaf of raw/props_a.png (still in the sheet, no longer packed).
# One picture per side: front views = as drawn, the hand's place in the raised fist at the image-left shoulder; back views =
# mirrored, behind body and head, the ear out past the shoulder at the image right. EAR_LEAN = lean of the picture itself (deg
# from upright, + = ear toward the image left; the frame's own lean of LOAD_SEAT comes on top), whole-picture turn only.
# EAR_SIDE = side of the ear picture in rig (old doll: 473; back views / LOAD_SEAT's 1.15 so both sides show the same size).
EAR_PIC = {"front": "ear_f", "q_front": "ear_f", "q_back": "ear_b", "back": "ear_b"}
EAR_SRC = "wheat"                    # prop name in the old doll's library (cut_lib.gd PROPS)
EAR_NATIVE = 47.0                    # deg: lean of the ear in the picture as drawn (hand -> middle of the ear / its tip: 53 / 42)
EAR_LEAN = {"ear_f": 38.0, "ear_b": -28.0}
EAR_MIRROR = {"ear_f": False, "ear_b": True}
EAR_SIDE = {"ear_f": 470.0, "ear_b": 470.0 / 1.15}
# the seat on the stalk: this far up the stalk from the old doll's hand place toward the ear (px of the old doll's picture) -
# front views: the short end below it is under the fist drawn over the load; back views: the end runs down behind the body
EAR_UP = {"ear_f": 57.0, "ear_b": 30.0}
EAR_STALK = (-0.806, -0.592)         # direction of the stalk in the picture as drawn (hand -> ear, image x right / y down)
EAR_PIVOT = {}                       # picture name -> the hand's place in the packed picture (px from its upper left corner)
BABY_SIZE = 250.0
BABY_SEAT = {"front": (12.0, 96.0, 0.0, 0.92), "q_front": (40.0, 90.0, 0.0, 1.0), "q_back": (62.0, 86.0, 0.0, 1.0), "back": (68.0, 86.0, 0.0, 1.0)}
# v13 closed eyes (sleep): a small eyelid picture per head set, laid over the front head piece of the old cutout library
LID_SETS = ("a", "b")
LID_W = 1.1            # half width of the closed-eye line, in open-eye widths
LID_SAG = 5.0          # rig: how far the middle of the line hangs below its ends
LID_TH = 10.0          # rig: line thickness
LID_PX = 0.6           # px per head rig
LID_LAYER = 0.5        # above the head piece's layer (half a layer, like the hands-over-load overlay), below the hat (+1)
HANDS_OVER = ("front", "q_front")      # views whose hands are drawn again over the load
LOOK_LIFT = 100.0      # look up (front view): the head lifts this many rig per rad of tilt while it leans back about the chin
LIE_ANGLE = 1.5708     # sleep: the whole doll is laid on its side by the shader (head to the image left)
POSE_SHEETS = True      # v4: walk / carry sheets traced from pose_ref.py (frame 1 = contact R in every view)
IDLE_POSE_VIEWS = ("front", "q_front", "q_back", "back")    # v10 3/4, v11 front / back: standing sheets traced from the standing reference (pose_ref.py hybrid idle) — same scale / root as walk
BOOT_R = 46.0          # px: state cells class stockings / boots only this close to a puppet boot (a hand on the ground stays skin)
FIST_R = 36.0          # px: a drawn fist (skin blob) is looked for this close to the puppet's fist
GRIP_SIDE = 0.3        # tools in the 3/4 views: the fists hold the shaft this far (x prop height) above the sprite centre (cut_lib hoe)
TOOL_LEN = 587.0      # the tallest tool sprite (hoe, rig) — back view: keep the blade end above the root line
FOOD_AT = (6.0, 10.0, 0.95)    # bread at the near fist: dx, dy (rig), scale — the old doll's eat prop (cut_lib "eat")
K_POSE = CHIN_RIG / float(PR.GROUND - PR.CHIN_Y)      # rig per template px (1.94): the traced sheets share the template's scale
HEAD_DX = {v: (8.0 if v == "q_front" else (-4.0 if v == "q_back" else 0.0)) for v in VIEWS}   # template head centre - root (px)
FOOT_DEPTH = {v: float(PR.geometry(v)["foot"]["R"][1]) for v in VIEWS}    # near foot below the root ground line (px, 3/4 views)
HEAD_DRIFT_WARN = 6.0   # px: a traced cell whose head centre is further than this from the template's is reported
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
SHOE_L = 100         # below the hem: darker than this = shoe, lighter = stocking
SPECK = 48           # px (sheet): islands of a dye class smaller than this take the class around them
SPECK_IN = 220       # px (sheet): ... and up to this size when the island lies wholly inside the figure (no outside within 4 px)


def classify(rgb, alpha, magenta, feet, fig_h, legzone=None, has_sack=False):
    """hard dye class per pixel (CLASSES index). Ink & magenta = none. Below the skirt hem (per column): tan -> leg, brown -> shoe."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    L = luma(rgb)
    sat = rgb.max(-1) - rgb.min(-1)
    lab = np.zeros(rgb.shape[:2], np.int8)
    fg = (alpha > 128) & ~magenta
    ink = L < 72
    sack = (sat < 34) & (L > 150) | ((b > r + 15) & (b > g))          # grey-white sack + its blue stripe
    if not has_sack:
        # v12: no sheet has a load painted in any more — greyish / bluish shades are cloth and take the nearest dye class
        sack = np.zeros_like(ink)
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
    if legzone is not None:
        # v11 state cells (sitting, kneeling, bending): legs / boots only around the puppet's boots; a boot lying against the
        # skirt (seen from behind, above the hem in its column) is the brown inside that zone
        zone = legzone
        lab[zone & fg & ~ink & (lab == 4)] = 6
    below = zone & ((rows > hem[None, :] + 2) | (hem[None, :] < 0))
    dark = (L < SHOE_L)
    # the apron's lower corner hangs past the dress hem in its own columns (3/4 back): cream that continues up out of the leg
    # rows is cloth, not a stocking (v11 — it took the legwear dye as a sliver beside the skirt)
    cloth = np.zeros_like(fg)
    for n_, _cy, _cx, _box, m_ in blobs(fg & (lab == 3), 1):
        if (m_ & ~below).sum() > 0.5 * n_:
            cloth |= m_
    lab[below & fg & ~ink & ~sack & dark & ~cloth] = 6
    lab[below & fg & ~ink & ~sack & ~dark & ~cloth] = 5
    if legzone is not None:
        # v12: an arm reaching to the ground crosses the boot circles (gather, deep bend) — a "stocking" that continues, with no
        # ink line between, into skin outside the zone is that arm, not a leg (it took the legwear dye as a stripe on the forearm)
        # (the skin it joins must lie outside the boot zone: a few skin pixels left right under the hem do not count)
        sks = list(blobs(lab == 1, 1))
        for n_, _cy, _cx, _box, m_ in blobs(lab == 5, 1):
            ring = dilate(m_, 1)
            if sum((ms & ~zone).sum() for _n, _a, _b, _c, ms in sks if (ring & ms).any()) >= 30:
                lab[m_] = 1
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
    # speckles (v11): a tiny island of one class inside another (seam lines in a sleeve read as skin, the sack's knot as rose,
    # ...) takes the class around it — a dyed dress showed them as dots of the wrong colour
    for c in range(1, len(CLASSES)):
        for n_, _cy, _cx, _box, m_ in blobs(lab == c, 1):
            if n_ >= SPECK_IN:
                continue
            near = dilate(m_, 4) & ~m_
            if n_ >= SPECK and (near & ~fg).any():      # at the silhouette's edge and not tiny = a small real part (a far fist), keep
                continue
            ring = near & (lab > 0)
            if ring.sum() < 4:
                continue
            around = np.bincount(lab[ring].astype(np.int64), minlength=len(CLASSES))
            if around[c] < 0.15 * ring.sum() and around.argmax() != c:
                lab[m_] = around.argmax()
    return lab


SHIN_ZONE = 0.2       # man: skin-coloured blobs wholly in this lowest part of a walking / standing figure are tan shins (trousers)
SHOE_NEAR = 0.16     # man: a brown blob whose lowest pixel is this close to the soles (x figure height) is a boot, else the belt


def classify_man(rgb, alpha, magenta, feet, fig_h, legzone=None, has_sack=False):
    """Q22 man: hard dye class per pixel from the drawn garment colours (man_prompts.py): skin = warm tan hands / forearms,
    main = sage-green TUNIC, second = dusty-rose VEST, trim = brown BELT, leg = cream TROUSERS, shoe = dark-brown BOOTS (the
    far leg was repainted from its cyan / navy key colours in frames_of). Belt and boots are both brown: a brown blob is a boot
    when it reaches down to the soles (walking / standing) or touches a puppet boot (state cells: legzone), else the belt.
    Ink and the magenta disc = none. Then the same edge / speckle clean-up as the woman's classify()."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    L = luma(rgb)
    lab = np.zeros(rgb.shape[:2], np.int8)
    fg = (alpha > 128) & ~magenta
    ink = L < 62
    skin = (r - b > 85) & (L > 120) & (r > 185) & (g - b > 35)
    green = (g > b + 22) & (g >= r - 12) & ~skin
    rose = (r - g > 38) & (np.abs(g - b) < 16) & (r > 115) & ~skin
    cream = (L > 188) & (r - b < 80) & (g - b > 8) & ~skin & ~green
    brown = (L >= 45) & (L < 150) & (r - b > 35) & (r - g > 18) & (g - b > 8) & ~skin & ~rose & ~green
    lab[fg & brown] = 4
    lab[fg & cream] = 5
    lab[fg & green] = 2
    lab[fg & rose] = 3
    lab[fg & skin] = 1
    lab[fg & ink] = 0
    left = fg & ~ink & (lab == 0)
    if left.any():
        cents = {c: np.median(rgb[fg & (lab == c)], axis=0) for c in (1, 2, 3, 4, 5) if (fg & (lab == c)).sum() > 20}
        ks = list(cents)
        d = np.stack([((rgb - cents[k]) ** 2).sum(-1) for k in ks], -1)
        lab[left] = np.array(ks, np.int8)[d.argmin(-1)][left]
    # tan shins: in some walking sheets the model kept the woman's TAN stocking colour on the near leg's lower part (between the
    # cream trouser and the boot) — read as skin it took the skin dye (an orange band above the boot, cradle q_back, first capture).
    # A skin blob lying wholly in the lowest SHIN_ZONE of a walking / standing figure (no hand is that low there) is that trouser
    # leg: recoloured pixel by pixel to the trouser cream (same shading) and classed as legwear. State cells (hands reach the
    # ground) are not touched.
    if legzone is None:
        low = np.arange(rgb.shape[0])[:, None] > feet - SHIN_ZONE * fig_h
        cream_ref = np.median(rgb[fg & (lab == 5)], 0) if (fg & (lab == 5)).sum() > 50 else np.array([246.0, 228.0, 186.0])
        for n_, _cy, _cx, _box, m_ in blobs(fg & (lab == 1), 1):
            if (m_ & ~low).sum() == 0:
                Lm = L[m_]
                rgb[m_] = np.clip(cream_ref[None] * (Lm / max(float(np.median(Lm)), 1.0))[:, None], 0, 255)
                lab[m_] = 5
    # belt or boot: per brown blob
    for n_, _cy, _cx, box, m_ in blobs(fg & (lab == 4), 1):
        boot = (box[3] >= feet - SHOE_NEAR * fig_h) if legzone is None else bool((m_ & legzone).any())
        if boot:
            lab[m_] = 6
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
    if VEST_SEAM:
        # vest switch (Q22): the ink line BETWEEN the vest and the tunic (inside the figure, not its outline) is recoloured pixel
        # by pixel to the tunic's own shade and takes the tunic class — with the vest dyed the tunic colour ("no vest") it reads
        # as a fold of the tunic, not as the outline of a vest. Nothing is moved; the outline of the figure stays ink.
        cv, ct = core & (lab == 3), core & (lab == 2)
        seam = fg & ink & dilate(cv, 4) & dilate(ct, 4) & ~dilate(~fg, 3)
        if seam.any() and ct.sum() > 50:
            rgb[seam] = np.median(rgb[ct], 0) * VEST_SEAM
            lab[seam] = 2
    for c in range(1, len(CLASSES)):
        for n_, _cy, _cx, _box, m_ in blobs(lab == c, 1):
            if n_ >= SPECK_IN:
                continue
            near = dilate(m_, 4) & ~m_
            if n_ >= SPECK and (near & ~fg).any():
                continue
            ring = near & (lab > 0)
            if ring.sum() < 4:
                continue
            around = np.bincount(lab[ring].astype(np.int64), minlength=len(CLASSES))
            if around[c] < 0.15 * ring.sum() and around.argmax() != c:
                lab[m_] = around.argmax()
    return lab


VEST_SEAM = 0.6       # man: vest / tunic seam = this shade of the tunic (0 = keep the ink line)


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
        far_c = None
        if far.any():
            L_ = luma(rgb)
            st_ref = float(np.median(L_[far_st])) if far_st.any() else 150.0
            sh_ref = float(np.median(L_[far_sh])) if far_sh.any() else 60.0
            # v8: the edge of the key-coloured leg (anti-aliased rim, navy ink outline, pale navy) misses the two tests above and
            # used to stay blue in the atlas -> the same recolour for every bluish pixel within 4 px of the far leg. Colours
            # only: no pixel is moved, added or removed.
            rim = (a > 60) & legrows & (b > r + 10) & (b > g + 3) & ~far & dilate(far, 4)
            mid = 0.5 * (st_ref + sh_ref)
            far_st = far_st | (rim & (L_ >= mid))
            far_sh = far_sh | (rim & (L_ < mid))
            # v5: repaint in the normal stocking / shoe colours; the 3/4 far leg is darkened AFTER the dye in the shader
            # (frames_mask1.a = far leg) so the near / far step survives any stocking colour
            STOCK, SHOE = np.array([246.0, 228.0, 186.0]), np.array([118.0, 66.0, 40.0])   # man: cream trousers, dark-brown boot
            rgb[far_st] = np.clip(STOCK[None] * (L_[far_st] / st_ref)[:, None], 0, 255)
            rgb[far_sh] = np.clip(SHOE[None] * (L_[far_sh] / sh_ref)[:, None], 0, 255)
            if far.sum() > 150:
                fy, fx = np.nonzero(far)
                far_c = (float(fx.mean()), float(fy.max()))
            far = far_st | far_sh
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
        out.append(dict(rgb=rgb, a=a2, mag=mag, head=head, feet=feet, far=far_c, farm=farm, err=foot_errors(rgb, a2, far, sheet, i)))
    if any(f["err"] for f in out):
        # symmetry report: drawn boot centre - reference boot centre (px, along x; visible part of the boot in both) per frame;
        # '.' = swinging in the reference, '?' = hidden. Both stances should read small numbers of the same size (a limp = one
        # leg's row drifting / jumping).
        for leg in ("R", "L"):
            print(f"  {sheet} {leg} boot x - ref: " + " ".join(
                ("%+3d" % f["err"][leg]) if isinstance(f["err"].get(leg), int) else ("  " + str(f["err"].get(leg, "?"))) for f in out))
    return out


_ref_boot_cache = {}


def ref_boot_x(clip, view):
    """per frame {R: cx, L: cx}: centre x of the VISIBLE boot blob on the pose reference sheet (near = brown, far = navy), measured
    the same way as on the drawing — a boot partly behind the other leg / the hem is compared like with like"""
    key_ = (clip, view)
    if key_ not in _ref_boot_cache:
        rgba = C.key(os.path.join(WRAW, f"pose_{clip}_{view}.png")).astype(np.float32)
        res = []
        for i in range(8):
            x0, y0 = (i % 4) * CW, (i // 4) * CH
            c = rgba[y0:y0 + CH, x0:x0 + CW]
            rgb, a = c[..., :3], c[..., 3]
            L = luma(rgb)
            r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
            legrows = np.arange(CH)[:, None] > 330
            fg = (a > 128) & legrows
            masks = {"R": fg & (r > g + 18) & (g > b) & (L > 35) & (L < 115) & (r - b > 35),
                     "L": fg & (b > r + 25) & (b > g + 5) & (L < 120)}
            d = {}
            for leg, m in masks.items():
                bl = [b_ for b_ in blobs(m[::2, ::2], 6) if b_[0] * 4 >= 150]
                if bl:
                    d[leg] = max(bl, key=lambda b_: b_[3][3])[2] * 2.0
            res.append(d)
        _ref_boot_cache[key_] = res
    return _ref_boot_cache[key_]


def foot_errors(rgb, a, far, sheet, i):
    """{R: dx px | '.' swing | '?' hidden, L: ...} — drawn boot blob centre x vs the reference sheet's boot blob centre x, both the
    visible part only (3/4 traced sheets only; diagnostic, nothing is moved)"""
    clip, view = sheet.split("_", 1)
    clip = GAIT_OF.get(clip, clip)
    if view not in ("q_front", "q_back") or clip not in PR.GAIT or not POSE_SHEETS:
        return {}
    L = luma(rgb)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    legrows = np.arange(CH)[:, None] > 330
    # boot brown (both boots: the far one is repainted to the shoe colour above), ink excluded — same rule as check_pose
    dark = (a > 128) & legrows & (r > g + 18) & (g > b) & (L > 35) & (L < 115) & (r - b > 35)
    refx = ref_boot_x(clip, view)[i]
    out = {}
    for leg, mask in (("R", dark & ~dilate(far, 1)), ("L", dark & far)):
        ref = PR.feet(clip, view, i)[leg]
        if ref[2] > 0.0:
            out[leg] = "."
            continue
        bl = blobs(mask[::2, ::2], 6)
        bl = [b_ for b_ in bl if b_[0] * 4 >= 150]
        if not bl or leg not in refx:
            out[leg] = "?"
            continue
        n, cy, cx, box, m = max(bl, key=lambda b_: b_[3][3])
        out[leg] = int(round(cx * 2.0 - refx[leg]))
    return out


def load_pictures():
    """v12: the load pictures of raw/props_*.png -> [(name, RGBA float array at atlas density, dye mask | None)], in sheet order.
    v13: props_c = the baby bundle (only the pictures of BABY_PIC go in), with a mask (skin, hair) so the baby takes its own colours.
    The model does not keep a strict grid, so the 8 objects of a sheet are its 8 biggest blobs (small loose bits join the nearest
    one), read row by row. Each picture is drawn whole — nothing is cut out of or pasted into it."""
    out = []
    import prompts as PT
    for sname in LOAD_SHEETS:
        p = os.path.join(WRAW, sname + ".png")
        if not os.path.exists(p):
            continue
        rgba = C.key(p).astype(np.float32)
        bl = blobs((rgba[..., 3] > 128)[::2, ::2], 6)
        big, rest = bl[:8], bl[8:]
        boxes = [list(b[3]) for b in big]
        for n, cy, cx, bx, _m in rest:
            j = int(np.argmin([(cx - b[2]) ** 2 + (cy - b[1]) ** 2 for b in big]))
            B = boxes[j]
            if bx[0] > B[0] - 30 and bx[2] < B[2] + 30 and bx[1] > B[1] - 30 and bx[3] < B[3] + 30:
                boxes[j] = [min(B[0], bx[0]), min(B[1], bx[1]), max(B[2], bx[2]), max(B[3], bx[3])]
        items = sorted(zip(big, boxes), key=lambda t: (t[0][1] * 2 > rgba.shape[0] / 2, t[0][2]))
        for (name, _desc), (_b, bx) in zip(PT.PROP_SHEETS[sname], items):
            x0, y0, x1, y1 = bx[0] * 2 - 3, bx[1] * 2 - 3, bx[2] * 2 + 5, bx[3] * 2 + 5
            crop = rgba[max(y0, 0):y1, max(x0, 0):x1].copy()
            baby = name.startswith("baby")
            if baby and name not in BABY_PIC.values():
                continue
            if name == "wheat":
                continue                 # v14: the sheaf is no longer shown (ear_pictures() below)
            k = (BABY_SIZE if baby else LOAD_SIZE[name]) * PX_PER_RIG / max(crop.shape[0], crop.shape[1])
            w, h = max(2, int(round(crop.shape[1] * k))), max(2, int(round(crop.shape[0] * k)))
            pm = crop.copy(); pm[..., :3] *= pm[..., 3:4] / 255.0
            chans = [np.asarray(Image.fromarray(np.ascontiguousarray(pm[..., i]), "F").resize((w, h), Image.BOX)) for i in range(4)]
            al = np.clip(chans[3], 0, 255)
            col = np.where(al[..., None] > 1, np.dstack(chans[:3]) / np.maximum(al[..., None], 1) * 255.0, 0)
            pic = np.zeros((h + 2, w + 2, 4), np.float32)          # 1 px clear rim (mipmaps)
            pic[1:-1, 1:-1] = np.dstack([col, al])
            msk = None
            if baby:
                # skin (face, ear) and hair of the baby -> dyed with the baby's own colours; blanket and ink stay as drawn.
                # Hair = brown areas that survive a 1 px erosion (the anti-aliased rim between ink and skin does not); in a picture
                # with a face only the big ones (the curl), not the two closed-eye lines.
                cr, cb, cl = crop[..., 0], crop[..., 2], luma(crop[..., :3])
                op = crop[..., 3] > 128
                skin = op & (cr - cb > 70) & (cr > 150) & (cl > 120)
                brown = op & (cr - cb > 40) & (cl > 60) & (cl < 130) & ~skin
                core = ~dilate(~brown, 1)
                comps = blobs(core, 12)
                face = "back" not in name and name != "baby_f"
                hair = np.zeros_like(op)
                for n_, _cy, _cx, _bx, m_ in comps:
                    if n_ >= (0.5 * comps[0][0] if face else 40):
                        hair |= dilate(m_, 2) & brown
                print(f"  {name}: skin {int(skin.sum())} px, brown areas {[c_[0] for c_ in comps]} -> hair {int(hair.sum())} px")
                mm = np.dstack([skin, hair]).astype(np.float32) * crop[..., 3:4]
                mr = [np.asarray(Image.fromarray(np.ascontiguousarray(mm[..., i]), "F").resize((w, h), Image.BOX)) for i in range(2)]
                msk = np.zeros((h + 2, w + 2, 2), np.float32)
                msk[1:-1, 1:-1] = np.dstack(mr)
                BABY_BASE[name] = (np.median(crop[skin][:, :3], 0), np.median(crop[hair][:, :3], 0) if hair.any() else None)
            out.append((name, pic, msk))
    return out + ear_pictures()


def ear_pictures():
    """v14 (Q16): the old doll's single wheat ear as the method C load picture — [(name, RGBA float array, None)] for EAR_PIC.
    The picture is mirrored (back views) and turned about the hand's place as a whole, then cropped to what is drawn and
    scaled to the atlas density; EAR_PIVOT[name] = where the hand's place ended up (the seat of the load quad)."""
    cut = os.path.normpath(os.path.join(ART, "..", "woman_a"))
    L = json.load(open(os.path.join(cut, "doll_lib.json")))
    at = np.asarray(Image.open(os.path.join(cut, "doll_atlas.png")).convert("RGBA")).astype(np.float32)
    H_, W_ = at.shape[:2]
    q = [q_ for q_ in L["quads"] if int(q_["group"]) == 3 and q_["set"] == EAR_SRC][0]
    u0, v0, u1, v1 = [int(round(t)) for t in (q["uv"][0] * W_, q["uv"][1] * H_, q["uv"][2] * W_, q["uv"][3] * H_)]
    src = at[v0:v1, u0:u1].copy()
    r = q["rect"]
    gx0 = (0.0 - r[0]) / (r[2] - r[0]) * src.shape[1]          # the hand's place (rig origin of the prop) in the picture, px
    gy0 = (r[3] - 0.0) / (r[3] - r[1]) * src.shape[0]
    out = []
    for name in sorted(set(EAR_PIC.values())):
        gx, gy = gx0 + EAR_STALK[0] * EAR_UP[name], gy0 + EAR_STALK[1] * EAR_UP[name]
        pic0, px = src, gx
        if EAR_MIRROR[name]:
            pic0, px = src[:, ::-1], src.shape[1] - gx
        # canvas centred on the hand's place, turned about its centre (premultiplied, bicubic)
        R = int(np.ceil(np.hypot(*src.shape[:2]))) + 2
        can = np.zeros((2 * R, 2 * R, 4), np.float32)
        x0, y0 = int(round(R - px)), int(round(R - gy))
        pm = pic0.copy(); pm[..., :3] *= pm[..., 3:4] / 255.0
        can[y0:y0 + src.shape[0], x0:x0 + src.shape[1]] = pm
        native = -EAR_NATIVE if EAR_MIRROR[name] else EAR_NATIVE
        turn = EAR_LEAN[name] - native                           # + = anticlockwise on screen = toward the image left
        chans = [np.asarray(Image.fromarray(np.ascontiguousarray(can[..., i]), "F").rotate(turn, Image.BICUBIC)) for i in range(4)]
        rot = np.dstack(chans)
        ys, xs = np.nonzero(rot[..., 3] > 6)
        bx0, by0, bx1, by1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        crop = rot[by0:by1, bx0:bx1]
        k = EAR_SIDE[name] * PX_PER_RIG / max(src.shape[0], src.shape[1])
        w, h = max(2, int(round(crop.shape[1] * k))), max(2, int(round(crop.shape[0] * k)))
        ch_ = [np.asarray(Image.fromarray(np.ascontiguousarray(crop[..., i]), "F").resize((w, h), Image.BOX)) for i in range(4)]
        al = np.clip(ch_[3], 0, 255)
        col = np.clip(np.where(al[..., None] > 1, np.dstack(ch_[:3]) / np.maximum(al[..., None], 1) * 255.0, 0), 0, 255)
        pic = np.zeros((h + 2, w + 2, 4), np.float32)          # 1 px clear rim (mipmaps)
        pic[1:-1, 1:-1] = np.dstack([col, al])
        EAR_PIVOT[name] = ((R - bx0) * w / crop.shape[1] + 1.0, (R - by0) * h / crop.shape[0] + 1.0)
        print(f"  {name}: ear picture {w + 2}x{h + 2} px (turned {turn:+.0f} deg), hand's place at ({EAR_PIVOT[name][0]:.1f}, {EAR_PIVOT[name][1]:.1f}) px")
        out.append((name, pic, None))
    return out


BABY_BASE = {}      # picture name -> (skin rgb, hair rgb) as drawn


def lid_pictures(skin_base=None):
    """v13 closed eyes for the sleep clip: per head set (LID_SETS) one small picture laid over the FRONT head piece of the old
    cutout library (art/cutout/woman_a) — over each eye a patch of that face's own skin colour and on it a closed-eye line
    (a soft U, in the eye's own dark colour). Drawn here from scratch; nothing is copied from another frame.
    -> [(set, pic RGBA float, skin mask, rect [x0, y0, x1, y1] head rig (chin origin, y up), layer)]
    skin_base = the body sheets' skin base colour: the patch is stored relative to it, so the body skin dye (c * dye / base) gives
    exactly the colour the head piece gets from its own base."""
    cut = os.path.normpath(os.path.join(ART, "..", "woman_a"))
    L = json.load(open(os.path.join(cut, "doll_lib.json")))
    at = np.asarray(Image.open(os.path.join(cut, "doll_atlas.png")).convert("RGBA")).astype(np.float32)
    H_, W_ = at.shape[:2]
    out = []
    for sname in LID_SETS:
        best = None
        for q in L["quads"]:
            if int(q["group"]) != 1 or int(q["view"]) != 0 or q["set"] != sname:
                continue
            u0, v0, u1, v1 = [int(round(t)) for t in (q["uv"][0] * W_, q["uv"][1] * H_, q["uv"][2] * W_, q["uv"][3] * H_)]
            crop = at[v0:v1, u0:u1]
            if crop.shape[0] < 40 or crop.shape[1] < 40:
                continue
            L_ = luma(crop[..., :3])
            dark = (crop[..., 3] > 128) & (L_ < 95)
            cand = []
            for n_, cy, cx, bx, m_ in blobs(dark, 8):
                bw, bh = bx[2] - bx[0] + 1, bx[3] - bx[1] + 1
                if n_ > 400 or n_ < 0.55 * bw * bh or not 0.4 < bw / bh < 1.8:
                    continue
                cand.append((n_, cy, cx, bx, m_))
            pair = None
            for i in range(len(cand)):
                for j in range(i + 1, len(cand)):
                    a_, b_ = cand[i], cand[j]
                    eh = max(a_[3][3] - a_[3][1], b_[3][3] - b_[3][1]) + 1
                    if abs(a_[1] - b_[1]) < 0.3 * eh and max(a_[0], b_[0]) < 1.6 * min(a_[0], b_[0]) and abs(a_[2] - b_[2]) > 2.0 * eh * 0.5:
                        if pair is None or a_[0] + b_[0] > pair[0][0] + pair[1][0]:
                            pair = (a_, b_)
            if pair and (best is None or pair[0][0] + pair[1][0] > best[0][0][0] + best[0][1][0]):
                best = (pair, q, crop, L_)
        if best is None:
            print(f"  WARNING lids: no eyes found on the front head of set {sname}")
            continue
        pair, q, crop, L_ = best
        rx0, ry0, rx1, ry1 = q["rect"]
        dx = crop.shape[1] / (rx1 - rx0)        # atlas px per rig
        dy = crop.shape[0] / (ry1 - ry0)
        eyes = []
        for n_, cy, cx, bx, m_ in pair:
            ring = dilate(m_, 5) & ~dilate(m_, 2) & (crop[..., 3] > 128) & (L_ > 140)
            skin = np.median(crop[ring][:, :3], 0)
            ink = np.median(crop[m_ & (L_ <= np.median(L_[m_]))][:, :3], 0)
            eyes.append(dict(cx=rx0 + (bx[0] + bx[2] + 1) * 0.5 / dx, cy=ry1 - (bx[1] + bx[3] + 1) * 0.5 / dy,
                             w=(bx[2] - bx[0] + 1) / dx, h=(bx[3] - bx[1] + 1) / dy, skin=skin, ink=ink))
        M = 5.0                                  # rig: the patch reaches this far past the eye (its anti-aliased rim)
        x0 = min(e["cx"] - e["w"] * LID_W for e in eyes) - M - 2
        x1 = max(e["cx"] + e["w"] * LID_W for e in eyes) + M + 2
        y0 = min(e["cy"] - e["h"] * 0.5 for e in eyes) - M - 2
        y1 = max(e["cy"] + e["h"] * 0.5 for e in eyes) + M + 2
        w, h = int(np.ceil((x1 - x0) * LID_PX)), int(np.ceil((y1 - y0) * LID_PX))
        SS = 4
        yy, xx = np.mgrid[0:h * SS, 0:w * SS]
        X = x0 + (xx + 0.5) / (SS * LID_PX)
        Y = y1 - (yy + 0.5) / (SS * LID_PX)
        col = np.zeros((h * SS, w * SS, 3), np.float32)
        al = np.zeros((h * SS, w * SS), np.float32)
        sk = np.zeros((h * SS, w * SS), np.float32)
        ratio = np.ones(3) if skin_base is None else np.asarray(skin_base, np.float64) / np.array(
            [int(L["base"][sname]["skin"][i:i + 2], 16) for i in (0, 2, 4)], np.float64)
        for e in eyes:
            patch = ((X - e["cx"]) / (e["w"] * 0.5 + M)) ** 2 + ((Y - e["cy"]) / (e["h"] * 0.5 + M)) ** 2 <= 1.0
            col[patch] = np.clip(e["skin"] * ratio, 0, 255)
            al[patch] = 255.0
            sk[patch] = 255.0
            # the closed eye: a long thin lash line (ends up a little, middle low), round ends. First take (a U as wide as the
            # open eye, 7 rig thick) came out as a 3 x 2 px blob on screen = the open eye's dot again; it has to be clearly WIDER
            # and THINNER than the open eye to read as shut (about 5 x 1 px at ppu 44).
            hw, sag, th = e["w"] * LID_W, LID_SAG, LID_TH
            yb = e["cy"] - e["h"] * 0.2
            t = np.clip((X - e["cx"]) / hw, -1.0, 1.0)
            fy = yb + sag * t * t
            slope = 2.0 * sag * t / hw
            d = np.where(np.abs(X - e["cx"]) <= hw, np.abs(Y - fy) / np.sqrt(1.0 + slope * slope),
                         np.sqrt((np.abs(X - e["cx"]) - hw) ** 2 + (Y - (yb + sag)) ** 2))
            line = d <= th * 0.5
            col[line] = e["ink"]
            al[line] = 255.0
            sk[line] = 0.0
        fill = np.clip(np.mean([e["skin"] for e in eyes], 0) * ratio, 0, 255)

        def down(a_):
            return a_.reshape(h, SS, w, SS).mean((1, 3))
        a_s = down(al)
        pm = np.dstack([down(col[..., i] * al / 255.0) for i in range(3)])
        rgb = np.where(a_s[..., None] > 1, pm / np.maximum(a_s[..., None], 1) * 255.0, fill[None, None])
        pic = np.zeros((h + 2, w + 2, 4), np.float32)
        pic[..., :3] = fill
        pic[1:-1, 1:-1] = np.dstack([rgb, a_s])
        msk = np.zeros((h + 2, w + 2, 2), np.float32)
        msk[1:-1, 1:-1, 0] = down(sk)
        rect = [x0 - 1.0 / LID_PX, y0 - 1.0 / LID_PX, x1 + 1.0 / LID_PX, y0 - 1.0 / LID_PX + (h + 2) / LID_PX]
        rect[2] = rect[0] + (w + 2) / LID_PX
        # y: the picture's top row is y1 (+ rim) — recompute the bottom from the pixel height so texels stay square
        rect[3] = y1 + 1.0 / LID_PX
        rect[1] = rect[3] - (h + 2) / LID_PX
        if skin_base is not None:
            print(f"  lids {sname}: eyes at {[(round(e['cx']), round(e['cy']), round(e['w']), round(e['h'])) for e in eyes]} rig, picture {w + 2}x{h + 2}")
        out.append((sname, pic, msk, [round(float(t), 2) for t in rect], float(q["layer"]) + LID_LAYER))
    return out


def main():
    sheets = {}
    for clip in ["walk", "carry", "idle", "hold", "cradle", "rock"]:
        for v in VIEWS:
            p = os.path.join(RAW, f"{clip}_{v}.png")
            if os.path.exists(p):
                sheets[f"{clip}_{v}"] = frames_of(f"{clip}_{v}")
    for sname in PS.SHEETS:
        if os.path.exists(os.path.join(RAW, sname + ".png")):
            sheets[sname] = frames_of(sname)
    # a state clip goes in only when all its sheets are drawn (the game falls back to the old doll for a missing clip)
    state_clips = [cl for cl in PS.ENTRIES if all(sh in sheets for sh in PS.CLIP_SHEET[cl])]
    # entries = the frames the game plays: (clip, view, sheet, cell, t0 | None, extra head tilt, pose name | None). v11: several
    # entries may show the same drawn cell (ping-pong, nod, a view that borrows another view's sheet) — the atlas holds each cell once.
    entries = []
    for clip, sheet, cells in CLIPS:
        for v in VIEWS:
            for c in cells:
                entries.append((clip, v, f"{sheet}_{v}", c, None, 0.0, None))
    for clip in state_clips:
        for vi, v in enumerate(VIEWS):
            sh = PS.CLIP_SHEET[clip][vi]
            for pose_n, t0, dang in PS.ENTRIES[clip]:
                entries.append((clip, v, sh, PS.cell_of(sh, pose_n), t0, dang, pose_n))
    order = []
    for e in entries:
        if (e[2], e[3]) not in order:
            order.append((e[2], e[3]))
    used = set(order)           # v12: cells nobody plays (the old sack rows of idle_*, the old gather cells) are skipped
    # per sheet scale: placeholder diameter -> D_RIG
    placed = {}      # sheet -> list of (rgba_scaled, dye_lab, frame info in rig)
    ext = [0.0, 0.0, 0.0]   # max |x|, max y (body top incl. sack), min y (below the root ground line: the forward foot in 3/4 views)
    for name, frs in sheets.items():
        clip_n, view_n = name.split("_", 1)
        state = name in PS.SHEETS
        pose = state or (POSE_SHEETS and (clip_n in ("walk", "carry", "hold", "cradle", "rock") or (clip_n == "idle" and view_n in IDLE_POSE_VIEWS)))
        dmed = float(np.median([f["head"]["d"] for f in frs]))
        if state:
            # v11: traced from pose_states.py puppets — the same template scale and root; the head moves per pose
            k = K_POSE
            ref = [PS.info(name, i)["head"] for i in range(8)]
            dx = [round(f["head"]["cx"] - r_[0]) for f, r_ in zip(frs, ref)]
            dy = [round((f["head"]["top"] + f["head"]["bottom"]) / 2.0 - r_[1]) for f, r_ in zip(frs, ref)]
            print(f"  {name}: head centre - puppet  dx {dx}  dy {dy} px, placeholder d {[round(f['head']['d']) for f in frs]}")
        elif pose:
            # traced from the cell template: the template's scale, root = (cell centre, ground line 470) in every frame
            k = K_POSE
            drift = [f["head"]["cx"] - (CW / 2.0 + HEAD_DX[view_n]) for f in frs]
            if max(abs(d) for d in drift) > HEAD_DRIFT_WARN:
                print(f"  WARNING {name}: head centre drifts from the template by {[round(d) for d in drift]} px")
        else:
            # free drawings (idle): scale per sheet from the body (soles -> chin, median over the frames): the model draws the
            # placeholder at varying size relative to the body, the head overlay is the same art for all sheets
            chin = float(np.median([f["feet"] - f["head"]["bottom"] for f in frs]))
            k = CHIN_RIG / chin                    # rig per sheet px
        info = []
        for fi_, f in enumerate(frs):
            if (name, fi_) not in used:
                info.append(None)
                continue
            lz = None
            if state:
                yy, xx = np.mgrid[0:CH, 0:CW]
                lz = np.zeros((CH, CW), bool)
                for bx, by in PS.boots(name, fi_):
                    lz |= (xx - bx) ** 2 + (yy - by) ** 2 < BOOT_R ** 2
            lab = classify_man(f["rgb"], f["a"], f["mag"], f["feet"], f["feet"] - f["head"]["top"], lz)
            if pose:
                ox, oy = CW / 2.0, float(PR.GROUND)
            else:
                # same root as the traced sheets: head centre - the view's head offset, soles - the near foot's depth offset
                ox = f["head"]["cx"] - HEAD_DX[view_n] * K_POSE / k
                oy = f["feet"] - FOOT_DEPTH[view_n] * K_POSE / k
            ys, xs = np.nonzero(f["a"] > 8)
            x0, x1 = (xs.min() - ox) * k, (xs.max() - ox) * k
            ytop = (oy - ys.min()) * k
            ext[0] = max(ext[0], -x0, x1)
            ext[1] = max(ext[1], ytop)
            ext[2] = min(ext[2], (oy - ys.max()) * k)
            info.append(dict(k=k, ox=ox, oy=oy, lab=lab, f=f))
        placed[name] = info
        if any(f["far"] for f in frs):
            # alternation check (v3 colour-coded far leg): far foot ahead (+) / behind (-) of the head line, per frame
            print(f"  {name} far foot: " + " ".join("%+.0f" % ((f["far"][0] - f["head"]["cx"]) * k) if f["far"] else "?" for f in frs))
    # v14 (Q16) same ground under a clip as under its neighbour clip: the reap sheets were drawn with the planted boots a few px
    # lower than the hoe sheets' (same puppet stance) - the whole cell is lifted so its soles (median lowest opaque row of the
    # frames played) sit where the hoe sheet's do in that view. Whole-cell shift only: every anchor rides on the same origin.
    for clip_, ref_ in PS.GROUND_AS.items():
        for vi_ in range(len(VIEWS)):
            mine_ = sorted(set((e[2], e[3]) for e in entries if e[0] == clip_ and e[1] == VIEWS[vi_]))
            ref_cells = sorted(set((e[2], e[3]) for e in entries if e[0] == ref_ and e[1] == VIEWS[vi_]))
            d_ = float(np.median([placed[s_][c_]["f"]["feet"] for s_, c_ in mine_]) - np.median([placed[s_][c_]["f"]["feet"] for s_, c_ in ref_cells]))
            for s_, c_ in mine_:
                placed[s_][c_]["oy"] += d_
            print(f"  ground {clip_} {VIEWS[vi_]}: soles {d_:+.0f} px vs {ref_} -> lifted by {d_ * K_POSE:.0f} rig")
    # colour drift between sheets (the model draws e.g. tan stockings in one sheet, brown in another): per sheet and dye class,
    # scale the colours so the class median matches the median over all sheets -> one base colour per class for the dye
    med = {}
    for name, info in placed.items():
        for ci in range(1, len(CLASSES)):
            px = [it["f"]["rgb"][(it["lab"] == ci) & (it["f"]["a"] > 250)] for it in info if it]
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
                if it is None:
                    continue
                sel = it["lab"] == ci
                it["f"]["rgb"][sel] = np.clip(it["f"]["rgb"][sel] * ratio, 0, 255)
            if np.abs(ratio - 1).max() > 0.06:
                print(f"  colour fix {name} {CLASSES[ci]}: x{np.round(ratio, 2)}")
        print(f"{name}: k {k:.2f} rig/px, placeholder d {dmed * k:.0f} rig, {dmed:.0f}px (min {min(f['head']['d'] for f in frs):.0f} max {max(f['head']['d'] for f in frs):.0f}) "
              f"figure h {np.median([(f['feet'] - f['head']['top']) for f in frs]):.0f}px")
    W_RIG = 2 * (ext[0] + 20)
    H_RIG = ext[1] + 20
    Y0 = min(-10.0, float(np.floor(ext[2])) - 10.0)      # the forward foot of the 3/4 views sits below the root ground line
    cw, ch = int(np.ceil(W_RIG * PX_PER_RIG)), int(np.ceil((H_RIG - Y0) * PX_PER_RIG))
    cols = 12
    rows = (len(order) + cols - 1) // cols
    AW, AH = cols * cw, rows * ch
    # v12 load pictures: shelf-packed (tallest first) into the unused end of the last cell row; a strip under the cells if they
    # do not fit there
    loads = load_pictures()
    loads += [("lid_" + ls[0], ls[1], ls[2]) for ls in lid_pictures()]      # sizes only here; colours once the skin base is known

    def pack(width, items):
        x = y = shelf = 0
        at = {}
        for name_, pic_, _msk in sorted(items, key=lambda t: -t[1].shape[0]):
            ph_, pw_ = pic_.shape[:2]
            if x + pw_ + 2 > width:
                x, y, shelf = 0, y + shelf + 2, 0
            at[name_] = (x + 1, y + 1)
            x += pw_ + 2
            shelf = max(shelf, ph_)
        return at, y + shelf + 2
    free_x = (len(order) % cols) * cw
    load_at, need = pack(AW - free_x, loads) if free_x else ({}, ch + 1)
    load_pos = {n_: (free_x + xy[0], (rows - 1) * ch + xy[1]) for n_, xy in load_at.items()}
    if need > ch:
        # v14: the tall pictures (the wheat ear) into the unused end of the last cell row when they fit there, the others in a
        # strip under the cells - the strip stays as low as the other loads need
        load_pos, rest = {}, loads
        tall = [l_ for l_ in loads if l_[0].startswith("ear_")]
        if free_x and tall:
            at_t, need_t = pack(AW - free_x, tall)
            if need_t <= ch:
                load_pos = {n_: (free_x + xy[0], (rows - 1) * ch + xy[1]) for n_, xy in at_t.items()}
                rest = [l_ for l_ in loads if not l_[0].startswith("ear_")]
        load_at, need = pack(AW, rest)
        load_pos.update({n_: (xy[0], AH + xy[1]) for n_, xy in load_at.items()})
        AH += int(np.ceil(need / 4.0) * 4)
    atlas = np.zeros((AH, AW, 4), np.float32)
    m0 = np.zeros((AH, AW, 4), np.float32)
    m1 = np.zeros((AH, AW, 4), np.float32)
    cellinfo = {}
    cls_px = {c: [] for c in range(1, len(CLASSES))}
    strides = {}
    for idx, (sheet, c) in enumerate(order):
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
        m1[ay0:ay0 + ch, ax0:ax0 + cw, :2] = oh[..., [4, 5]]
        sheet_clip, sheet_view = sheet.split("_", 1)
        if sheet_clip in ARM_CLIPS and sheet_view in HANDS_OVER:
            # v12: the hands and forearms (skin + their ink outline) are drawn once more over the load picture, so she HOLDS it
            skin_m = (lab == 1) & (f["a"] > 128)
            hand_m = dilate(skin_m, 4) & (f["a"] > 128) & ((lab == 1) | (luma(f["rgb"]) < 110))
            m1[ay0:ay0 + ch, ax0:ax0 + cw, 2] = rs((hand_m.astype(np.float32) * 255.0)[..., None])[..., 0]
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
        cellinfo[(sheet, c)] = dict(cell=c, uv=[ax0 / AW, ay0 / AH, (ax0 + cw) / AW, (ay0 + ch) / AH],
                                    head=[round(head[0], 1), round(head[1], 1)], hands=[[round(p, 1) for p in h] for h in hands],
                                    sack=[round(p, 1) for p in sack] if sack else None,
                                    shoes=[[round((s_[2] * 2 - it["ox"]) * k, 1), round((it["oy"] - s_[1] * 2) * k, 1)] for s_ in shoes],
                                    far=round((f["far"][0] - it["ox"]) * k, 1) if f.get("far") else None)
    # the frames the game plays (clip by clip, view by view): cell data + timing + head tilt + prop grip
    frames = []
    pos = {}
    for clip, v, sheet, c, t0, dang, pose_n in entries:
        fr = dict(clip=clip, view=v, **cellinfo[(sheet, c)])
        it = placed[sheet][c]
        if t0 is None:
            # uniform timing first (position in the clip)
            key = (clip, v)
            fr["t0"] = pos.get(key, 0) / len(CLIP_CELLS[clip])
            pos[key] = pos.get(key, 0) + 1
            if clip in ARM_CLIPS:
                # v12: the load overlay's seat (bottom centre of the load picture, rig) — it rides on the frame's chin anchor, so
                # it bobs with the drawn body (the drawn fists stay within 3 px of the chin in every frame). v13: the baby too.
                dx, dy, lean, sc = (BABY_SEAT if clip in BABY_CLIPS else LOAD_SEAT)[v]
                fr["prop"] = [lean, round(fr["head"][0] + dx * it["k"], 1), round(fr["head"][1] - dy * it["k"], 1), sc, 0.0]
        else:
            fr["t0"] = t0
            fr["pose"] = pose_n
            inf = PS.info(sheet, c)
            side = inf["view"] in ("q_front", "q_back")
            # head tilt (rad, about the head centre; - = nodding toward where she faces) — 3/4 drawings only; seen from the
            # front / back a nod is a few rig lower instead
            fr["hang"] = round(inf["hang"] + dang, 3) if side else 0.0
            if clip == "lookup":
                # v12 ("head should tilt back"): the overlaid head leans back about the CHIN toward the raised arm (image left) and
                # lifts. The shader turns the head about its centre (head_r above the chin), so the chin anchor is moved to where
                # a turn about the chin would have put that centre.
                r_head = D_RIG * 0.5 - 7.0
                fr["hang"] = round(dang, 3)
                fr["head"] = [round(fr["head"][0] - r_head * float(np.sin(dang)), 1),
                              round(fr["head"][1] + r_head * (float(np.cos(dang)) - 1.0) + LOOK_LIFT * dang, 1)]
            elif not side and dang != 0.0:
                fr["head"] = [fr["head"][0], round(fr["head"][1] - 60.0 * abs(dang), 1)]
            if clip in PS.LIE:
                fr["lie"] = LIE_ANGLE
                fr["shut"] = 1.0          # v13: asleep = eyes closed (the lid picture of her head set is shown)
            if clip in PS.PROP and inf["grip"] is not None:
                # the drawn fists (skin blobs next to the puppet's fists); a fist hidden by the body falls back to the puppet's
                skin = (it["lab"] == 1) & (it["f"]["a"] > 128)
                yy, xx = np.mgrid[0:CH, 0:CW]
                got = []
                for fx, fy in (inf["fists"] if inf["tool"] and not inf.get("one") else inf["fists"][:1]):
                    near = skin & ((xx - fx) ** 2 + (yy - fy) ** 2 < FIST_R ** 2)
                    got.append((float(xx[near].mean()), float(yy[near].mean()), True) if near.sum() > 60 else (fx, fy, False))
                gx, gy = sum(g_[0] for g_ in got) / len(got), sum(g_[1] for g_ in got) / len(got)
                hx, hy = (gx - it["ox"]) * it["k"], (it["oy"] - gy) * it["k"]
                if inf.get("one"):
                    # v14 (Q16) the reap clip's sickle, held in ONE fist: the sprite (head up — FrameLib.PROP_HEAD_UP turns it PI)
                    # points along the pose's tool direction; its handle (PS.SICKLE_GRIP from the sprite centre) sits in the fist, so
                    # the hand point stored here is the sprite CENTRE for that angle (grip 0). A mirrored sprite (PS.TOOL_FLIP: the
                    # hook curves down / toward her) is written as a NEGATIVE scale (frame_doll.gdshader group 3).
                    tool = inf["tool"]
                    ang = float(np.arctan2(tool[0], -tool[1]))
                    flip = PS.TOOL_FLIP[clip][VIEWS.index(v)]
                    th = ang + np.pi
                    sgx, sgy = (-PS.SICKLE_GRIP[0] if flip else PS.SICKLE_GRIP[0]), PS.SICKLE_GRIP[1]
                    cx = hx - float(np.cos(th) * sgx - np.sin(th) * sgy) * PS.SICKLE_K
                    cy = hy - float(np.sin(th) * sgx + np.cos(th) * sgy) * PS.SICKLE_K
                    fr["prop"] = [round(ang, 3), round(cx, 1), round(cy, 1), -PS.SICKLE_K if flip else PS.SICKLE_K, 0.0]
                    fr["prop_short"] = round(ang, 3)
                elif inf["tool"]:
                    tool, short, grip = inf["tool"], inf["tool_short"], (GRIP_SIDE if side else 0.0)
                    if inf["view"] == "back":
                        # v12 ("in the back view no tool is visible"): her fists are hidden in front of her, so the tool was too.
                        # She works at her image-right side: the hand point is beside the body and the tool swings in the image
                        # plane behind her (pose_states.BACK_TOOL) — the part that passes her body is hidden, the rest shows.
                        tool = PS.BACK_TOOL[pose_n]
                        short = PS.BACK_TOOL_SHORT.get(pose_n, tool)
                        grip = GRIP_SIDE
                        hx = PS.BACK_HAND_X * it["k"]
                        # the blade end must not dip under the root line — the shader pulls anything below the root toward the
                        # camera (boots), which put the blade in front of the skirt on the strike frame (states4 strip)
                        hy = max(hy, (grip + 0.5) * TOOL_LEN * max(0.0, -tool[1]) + 10.0)
                    ang = float(np.arctan2(tool[0], -tool[1]))      # sprite = shaft upright, blade down
                    fr["prop"] = [round(ang, 3), round(hx, 1), round(hy, 1), 1.0, grip]
                    fr["prop_short"] = round(float(np.arctan2(short[0], -short[1])), 3)     # sickle / mallet (FrameLib.PROP_HEAD_UP)
                else:
                    fr["prop"] = [0.0, round(hx + FOOD_AT[0], 1), round(hy + FOOD_AT[1], 1), FOOD_AT[2], 0.0]
                fr["fists_seen"] = [bool(g_[2]) for g_ in got]
        frames.append(fr)
    # stride + frame timing from the planted foot (2026-11-09 live check: the drawn foot travel is uneven — e.g. 42 / 152 / 62 / 5
    # rig per frame — so equal frame times made the planted foot slip forward and back). 3/4 views with the colour-coded far leg:
    #   stride (per cycle, 2 steps) = 2 x (far foot max forward - max back) ; frame i's duration ~ far-foot backward travel i -> i+1
    #   during its stance (frames 5-8), the same pattern for frames 1-4 (the near leg's stance, by symmetry), blended with uniform.
    for clip in ("walk", "carry", "cradle"):
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
        measured = round(float(np.mean(st)), 1) if st else 600.0
        if POSE_SHEETS:
            # 2026-11-10: the traced sheets' planted foot moves exactly like the puppet's (2 S px per stance, checked ±2 px), so
            # the stride is the template's: 4 S px per cycle (two steps), horizontal. The far-foot extremes measured on the
            # drawing (incl. the swing overshoot at contact) ran 4-10% long -> the planted foot crept forward on one step.
            strides[clip] = round(4.0 * PR.GAIT[GAIT_OF.get(clip, clip)]["S"] * K_POSE, 1)
            print(f"  stride {clip}: template {strides[clip]} rig / cycle (far-foot extremes on the drawing {measured})")
        else:
            strides[clip] = measured
    base = {}
    for ci in range(1, len(CLASSES)):
        if cls_px[ci]:
            base[CLASSES[ci]] = "%02x%02x%02x" % tuple(np.median(np.concatenate(cls_px[ci]), 0).astype(int))
    # v12 load pictures (not dyed: the masks stay empty there). v13: the baby pictures carry a mask (mask0 R skin, G hair — dyed
    # with the baby's own colours by the shader) and the eyelid pictures one too (mask0 R = skin, the body's skin dye)
    skin_rgb = [int(base["skin"][i:i + 2], 16) for i in (0, 2, 4)]
    lids = lid_pictures(skin_rgb)
    load_tab, lid_tab, where = [], [], {}
    for lname, pic, msk in [l_ for l_ in loads if not l_[0].startswith("lid_")] + [("lid_" + ls[0], ls[1], ls[2]) for ls in lids]:
        ph, pw = pic.shape[:2]
        ax0, ay0 = load_pos[lname]
        atlas[ay0:ay0 + ph, ax0:ax0 + pw] = pic
        if msk is not None:
            m0[ay0:ay0 + ph, ax0:ax0 + pw, :2] = msk
        where[lname] = dict(uv=[ax0 / AW, ay0 / AH, (ax0 + pw) / AW, (ay0 + ph) / AH], size=[round(pw / PX_PER_RIG, 1), round(ph / PX_PER_RIG, 1)])
        if not lname.startswith("lid_") and not lname.startswith("baby") and not lname.startswith("ear_"):
            load_tab.append(dict(name=lname, **where[lname]))
        if lname.startswith("ear_"):
            # pivot = the seat inside the picture (rig from its lower left corner; without it the seat is the bottom centre)
            where[lname]["pivot"] = [round(EAR_PIVOT[lname][0] / PX_PER_RIG, 1), round((ph - EAR_PIVOT[lname][1]) / PX_PER_RIG, 1)]
    for vi, v in enumerate(VIEWS):
        # v14: carried wheat = the old doll's single ear, one picture per side (src = that prop of the old doll's library)
        load_tab.append(dict(name="wheat", view=vi, pic=EAR_PIC[v], src="cutout_a/" + EAR_SRC, **where[EAR_PIC[v]]))
    for vi, v in enumerate(VIEWS):
        load_tab.append(dict(name="baby", view=vi, pic=BABY_PIC[v], **where[BABY_PIC[v]]))
    for sname, _pic, _msk, rect, layer in lids:
        lid_tab.append(dict(set=sname, view=0, rect=rect, layer=layer, uv=where["lid_" + sname]["uv"]))
    bsk = np.median(np.array([BABY_BASE[n_][0] for n_ in set(BABY_PIC.values())]), 0)
    bhr = [BABY_BASE[n_][1] for n_ in set(BABY_PIC.values()) if BABY_BASE[n_][1] is not None]
    base["baby_skin"] = "%02x%02x%02x" % tuple(int(t) for t in bsk)
    base["baby_hair"] = "%02x%02x%02x" % tuple(int(t) for t in (np.median(np.array(bhr), 0) if bhr else (119, 72, 47)))
    def save(arr, name):
        Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(ART, name), optimize=True)
    save(atlas, "frames_atlas.png")
    # Q22 3-0 (2026-11-12, as build_frames.py after the atlas-memory change): the two masks are build sources in raw/ and the game
    # reads them packed (pack_masks.py -> frames_mcode / mlut / mq0 / mq1 in man_c/). Without pack_masks.py: the old two-mask format.
    try:
        import pack_masks
    except ImportError:
        pack_masks = None
    if pack_masks is not None:
        save(m0, os.path.join("raw", "frames_mask0.png"))
        save(m1, os.path.join("raw", "frames_mask1.png"))
        pack_masks.pack(m0, m1, out=ART)
    else:
        save(m0, "frames_mask0.png")
        save(m1, "frames_mask1.png")
    nclip = {cl: len(cells) for cl, _, cells in CLIPS}
    for cl in state_clips:
        nclip[cl] = len(PS.ENTRIES[cl])
        seen = [fr["fists_seen"] for fr in frames if fr["clip"] == cl and "fists_seen" in fr]
        if seen:
            print(f"  {cl}: fists found on the drawing in {sum(all(x) for x in seen)} of {len(seen)} frames (else the puppet's)")
    lib = dict(fig=FIG, d_rig=D_RIG, rect=[-W_RIG / 2, Y0, W_RIG / 2, H_RIG], atlas=[AW, AH], cell=[cw, ch], views=VIEWS,
               clips=[cl for cl, _, _ in CLIPS] + state_clips, frames_per_clip=nclip, stride=strides, base=base, cells=len(order),
               loads=load_tab, lids=lid_tab, frames=frames)
    with open(os.path.join(ART, "frames.json"), "w") as fh:
        json.dump(lib, fh, indent=0)
    print("atlas", AW, AH, "cell", cw, ch, "cells", len(order), "frames", len(frames), "rect", lib["rect"], "stride", strides, "base", base)
    # check images: aligned frames + class colours
    pal = np.array([[0, 0, 0], [240, 170, 110], [210, 60, 60], [250, 240, 200], [140, 80, 40], [60, 160, 220], [40, 40, 160], [180, 180, 180]], np.float32)
    for name, info in placed.items():
        tiles = []
        for it in info:
            if it is None:
                continue
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
        Image.fromarray(out.astype(np.uint8)).resize((out.shape[1] // 2, out.shape[0] // 2)).save(os.path.join(CHECK_DIR, f"check_{name}.png"))


if __name__ == "__main__":
    main()
