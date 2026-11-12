"""Q22 step 4 (2026-11-12): head-piece VARIANTS for the cutout dolls — hair texture (straight / wavy / curly), thinning hair,
bald-ring hair, and beard OVERLAYS — made from the EXISTING head pieces by image edits, with the FACE kept pixel-identical.

usage:
  python3 heads.py sheet <job>     -> raw/heads/in_<job>.png  (the 4 original head pieces of the job's set on chroma green, one row)
  python3 heads.py prompt <job> <out>
  python3 heads.py cut <job> [take] -> parts/<set>/<view>/head_<var>.png (or beard_<var>.png) + raw/heads/<job>_check.png
  python3 heads.py cutall           -> every job whose raw take exists
  python3 heads.py list

Pipeline per job (codex built-in image gen, gen_heads.sh):
  1. sheet: the set's 4 head pieces (front, 3/4 front, 3/4 back, back) at SHEET_K x their piece size, centred in 4 cells of 384 x 1024.
  2. codex redraws the SAME sheet with ONE change (hair texture / thinning / ring / beard), same positions and sizes.
  3. cut: key the green, find the head in each cell, REGISTER it on the original piece (scale + shift search on the face lines),
     then COMPOSITE on a padded canvas of the original piece:
       - head variants: new picture everywhere EXCEPT the protected face = the original's face (skin region with its holes filled —
         eyes, brows, nose, mouth, cheeks — grown by the outline width), which is copied back pixel for pixel. Back views protect the
         neck / ears only (no face). Hair pixels are recoloured so their median brightness matches the original's drawn hair base
         (the shader dyes by brightness / base).
       - beard overlays: only the new pixels that are beard (hair-coloured or ink, below the nose line, inside the face/jaw area and
         different from the original); the original mouth line is cut out of the overlay so the mouth shows through.
  Faces of the variants are therefore identical to the original head (check: cut prints the max difference inside the protected face).

Freckles, white forelock and the speckle ("snowflake") pattern are NOT drawn: they are shader marks gated by the skin / hair dye
channels (cut_doll.gdshader marks()). The freckles DRAWN on heads d and f are erased here (erase_freckles) so freckles follow genes.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "woman_a"))
PARTS = os.path.join(ART, "parts")
RAW = os.path.join(ART, "raw", "heads")
VIEWS = ["front", "q_front", "q_back", "back"]
W, H = 1536, 1024
CELL = 384
SHEET_K = 1.15            # piece px -> sheet px
PAD = 56                  # variant canvas padding around the original piece (piece px) — curly / wavy hair may grow
GREEN = (0, 255, 0)


# ───────────── tiny stand-in for scipy.ndimage (not installed here): 4-connected binary morphology, holes, components, blur ─────────────
class ndimage:
    @staticmethod
    def _shift_or(m):
        o = m.copy()
        o[1:] |= m[:-1]; o[:-1] |= m[1:]; o[:, 1:] |= m[:, :-1]; o[:, :-1] |= m[:, 1:]
        return o

    @staticmethod
    def binary_dilation(m, iterations=1):
        m = np.asarray(m, bool)
        for _ in range(iterations):
            m = ndimage._shift_or(m)
        return m

    @staticmethod
    def binary_erosion(m, iterations=1):
        return ~ndimage.binary_dilation(~np.asarray(m, bool), iterations)

    @staticmethod
    def binary_opening(m, iterations=1):
        return ndimage.binary_dilation(ndimage.binary_erosion(m, iterations), iterations)

    @staticmethod
    def binary_closing(m, iterations=1):
        p = iterations + 1
        mm = np.pad(np.asarray(m, bool), p)
        return ndimage.binary_erosion(ndimage.binary_dilation(mm, iterations), iterations)[p:-p, p:-p]

    @staticmethod
    def binary_fill_holes(m):
        m = np.asarray(m, bool)
        outside = np.zeros_like(m)
        outside[0, :] = ~m[0, :]; outside[-1, :] = ~m[-1, :]; outside[:, 0] = ~m[:, 0]; outside[:, -1] = ~m[:, -1]
        while True:
            nxt = ndimage._shift_or(outside) & ~m
            if (nxt == outside).all():
                break
            outside = nxt
        return ~outside

    @staticmethod
    def label(m):
        m = np.asarray(m, bool)
        lab = np.zeros(m.shape, np.int32)
        n = 0
        ys, xs = np.nonzero(m)
        for y, x in zip(ys, xs):
            if lab[y, x]:
                continue
            n += 1
            cur = np.zeros_like(m)
            cur[y, x] = True
            while True:
                nxt = ndimage._shift_or(cur) & m
                if (nxt == cur).all():
                    break
                cur = nxt
            lab[cur] = n
        return lab, n

    @staticmethod
    def sum(m, lab, idx):
        return np.array([int((lab == i).sum()) for i in idx])

    @staticmethod
    def gaussian_filter(x, sigma):
        r = max(1, int(3 * sigma))
        t = np.arange(-r, r + 1, dtype=np.float32)
        k = np.exp(-0.5 * (t / sigma) ** 2)
        k /= k.sum()
        x = np.asarray(x, np.float32)
        x = np.apply_along_axis(lambda v: np.convolve(np.pad(v, r, mode="edge"), k, "valid"), 0, x)
        return np.apply_along_axis(lambda v: np.convolve(np.pad(v, r, mode="edge"), k, "valid"), 1, x)

_V = ("the four cells show the SAME head in four views, left to right: FRONT, THREE-QUARTER FRONT (turned toward the image right), "
      "THREE-QUARTER BACK (turned away toward the upper right, no eyes or mouth visible), BACK (seen from directly behind, no face)")

# job -> (set, kind, variant name, change text, reference set or None)
# kind: "head" = a whole head variant (face kept), "beard" = an overlay cut from the difference
JOBS = {
    "b_wavy": ("b", "head", "wavy", "her hair becomes SOFT WAVY hair: the same parting, the same length and about the same outline size, but the hair "
               "outline is gently scalloped with a few big loose S-shaped waves and there are 2-3 wavy strand lines inside the hair; the two braids "
               "in the back views stay braids", None),
    "b_curly": ("b", "head", "curly", "her hair becomes CURLY hair made of many small round curls (exactly like the curly hair of the second attached "
                "image): the hair outline is a ring of small round bumps, small curl swirls inside; about the same outline size as now (it may be "
                "up to 10% puffier); the two braids in the back views become two short puffy curly bunches", "c"),
    "b_thin": ("b", "head", "thin", "her hair becomes THINNER, as on an old woman: the same hairstyle and colour but flatter and sparser, a little less "
               "volume, and a WIDE PARTING on top where a strip of scalp skin shows through on the crown; the back views show a small round patch "
               "of skin on the crown", None),
    "d_wavy": ("d", "head", "wavy", "his short hair becomes clearly WAVY: short hair with a few big loose S-shaped waves, the hair outline gently "
               "scalloped, 2-3 wavy strand lines inside; same length and about the same outline size as now", None),
    "d_curly": ("d", "head", "curly", "his short hair becomes CURLY: a short cap of many small round tight curls (exactly like the curly hair of the "
                "second attached image), the outline a ring of small round bumps, small curl swirls inside; about the same outline size as now "
                "(at most 10% puffier)", "c"),
    "d_thin": ("d", "head", "thin", "his hair is THINNING (a man in his forties): the hairline RECEDES at both temples (a high forehead with an M-shaped "
               "hairline), the hair on top is short and sparse with scalp skin showing through on the crown; the back views show a round bald "
               "patch of skin on the crown surrounded by short hair", None),
    "d_beard_s": ("d", "beard", "short", "he gets a SHORT NEAT BEARD: a short trimmed beard along the jaw and chin and a small moustache, in the "
                  "same colour as his hair, drawn like the beard of the second attached image but SHORTER and closer to the face; the mouth "
                  "(his smile line) stays visible above the chin beard; nothing else changes", "e"),
    "d_beard_f": ("d", "beard", "full", "he gets a FULL BEARD: a big full rounded beard covering the jaw, chin and cheeks below the cheekbones plus "
                  "a moustache, in the same colour as his hair, drawn exactly like the beard of the second attached image; the mouth (his smile "
                  "line) stays visible inside the beard; nothing else changes", "c"),
    "f_wavy": ("f", "head", "wavy", "her bob haircut becomes WAVY: the same bob length and about the same outline size, but the outline is gently "
               "scalloped with a few big loose S-shaped waves and there are 2-3 wavy strand lines inside", None),
    "f_curly": ("f", "head", "curly", "her bob haircut becomes CURLY: a round bob of many small round curls (exactly like the curly hair of the "
                "second attached image), the outline a ring of small round bumps, small curl swirls inside, about the same outline size (at most "
                "10% puffier)", "c"),
    "g_straight": ("g", "head", "straight", "the white ring of hair around the sides and back of his bald head becomes STRAIGHT smooth hair: a "
                   "smooth flat band of straight white hair with a few straight strand lines, combed down, instead of puffy curls; the bald top, "
                   "the white eyebrows and the white moustache stay exactly as they are", None),
    "g_wavy": ("g", "head", "wavy", "the white ring of hair around the sides and back of his bald head becomes WAVY hair: a band of softly waved "
               "white hair with a gently scalloped outline and 2-3 wavy strand lines, instead of tight puffy curls; the bald top, the white "
               "eyebrows and the white moustache stay exactly as they are", None),
    "a_wavy": ("a", "head", "wavy", "the hair that shows under her cream headscarf (at the temples, beside the cheeks and at the nape) becomes "
               "WAVY: loose S-shaped waves with a gently scalloped outline; the headscarf itself stays exactly as it is", None),
    "a_curly": ("a", "head", "curly", "the hair that shows under her cream headscarf (at the temples, beside the cheeks and at the nape) becomes "
                "CURLY: small round curls (like the curly hair of the second attached image) with a bumpy outline; the headscarf itself stays "
                "exactly as it is", "c"),
}

PROMPT = """Use your built-in image generation tool to create ONE landscape image, exactly 1536x1024, then save it (copy the generated PNG) to {out} and print the path.

The FIRST attached image is a FINISHED sheet of cut-out HEAD pieces of one villager for a cosy picture-book village game (a paper-doll rig): {views}. Each head sits centred in its quarter of the image on a flat chroma green background.

REDRAW THIS WHOLE SHEET with ONE change — {change}.
{ref}
Everything else stays EXACTLY as in the first image, cell by cell:
- the same four heads at the same positions and the same size (do not enlarge, shrink or move any head);
- the FACE is untouchable: the same eyes (small solid dark dots), the same eyebrows, nose, mouth, cheeks, ears, chin, the same face outline and the same short neck stub at the bottom — copy them exactly;
- the same skin colour, the same hair colour ({hair}) with the same single darker shade step, the same thick dark-brown ink outline of even weight;
- flat cel colour with one soft shade step, light from the upper-left, NO gradients, NO texture noise, NO hatching.
Background: one flat uniform pure chroma green #00FF00 everywhere, NO text, NO numbers, NO cell borders, NO shadows. Exactly one head per quarter, nothing else."""

REF_TEXT = "The SECOND attached image shows another villager's head pieces: use it ONLY as the reference for how the {what} is drawn (its shapes and line style) — do not copy that face, that skin or that hair colour."


def hexrgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


def piece(s, v, name="head"):
    return Image.open(os.path.join(PARTS, s, v, name + ".png")).convert("RGBA")


def cell_xform(img):
    """sheet placement of a piece: (scale, x0, y0) — centred in its cell"""
    w, h = img.size
    return SHEET_K, (CELL - w * SHEET_K) / 2.0, (H - h * SHEET_K) / 2.0


def make_sheet(s, out):
    sh = Image.new("RGBA", (W, H), GREEN + (255,))
    for i, v in enumerate(VIEWS):
        p = piece(s, v)
        k, x0, y0 = cell_xform(p)
        q = p.resize((round(p.width * k), round(p.height * k)), Image.LANCZOS)
        sh.alpha_composite(q, (int(round(i * CELL + x0)), int(round(y0))))
    sh.convert("RGB").save(out)


def hair_hex(s):
    b = json.load(open(os.path.join(ART, "doll_lib.json")))["base"][s]
    return "#" + b["hair"].upper()


def prompt(job, out):
    s, kind, var, change, ref = JOBS[job]
    what = "beard" if kind == "beard" else "curly hair"
    return PROMPT.format(out=out, views=_V, change=change, hair=hair_hex(s),
                         ref=(REF_TEXT.format(what=what) + "\n") if ref else "")


# ───────────── cutting / registration / composite ─────────────
def key_green(rgb):
    """alpha from greenness (same idea as cut_sheets.py): green-dominant pixels are background"""
    r, g, b = rgb[..., 0].astype(np.float32), rgb[..., 1].astype(np.float32), rgb[..., 2].astype(np.float32)
    gx = g - np.maximum(r, b)
    a = np.clip(1.0 - (gx - 40.0) / 60.0, 0.0, 1.0)
    # de-spill: pull green down to max(r, b) on edge pixels
    out = rgb.astype(np.float32).copy()
    sp = gx > 0
    out[..., 1][sp] = np.maximum(r, b)[sp]
    return out.astype(np.uint8), (a * 255).astype(np.uint8)


def largest_blob(mask):
    lab, n = ndimage.label(mask)
    if n == 0:
        return mask
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    keep = np.zeros(n + 1, bool)
    big = sizes.max()
    for i, sz in enumerate(sizes):
        if sz > 0.02 * big:
            keep[i + 1] = True
    return keep[lab]


def ink(rgba):
    """dark ink lines (outline, eyes, brows, mouth) — float mask"""
    c = rgba[..., :3].astype(np.float32) / 255.0
    l = c @ np.array([0.299, 0.587, 0.114], np.float32)
    return ((l < 0.32) & (rgba[..., 3] > 128)).astype(np.float32)


def face_protect(orig, skin_hex, hair_hex_, back, thin=False):
    """the protected face of an original piece: the skin region with its enclosed holes filled (eyes, brows, nose, mouth, cheeks,
    moustache) + a ring of the outline width around it that is not hair (the hairline itself comes from the new picture).
    thin variants: only from just above the eyebrows down (the receding hairline / forehead is new). Back views: nothing (no face —
    the neck rows are kept separately). Returns (protect, filled skin) bool masks."""
    W3 = np.array([0.299, 0.587, 0.114])
    c = orig[..., :3].astype(np.float32) / 255.0
    a = orig[..., 3] > 128
    sk = hexrgb(skin_hex)
    l = np.maximum(c @ W3, 1e-3)
    ls = float(sk @ W3)
    chrom = np.abs(c / l[..., None] - sk / ls).sum(-1)
    skin = a & (chrom < 0.42) & (l / ls > 0.6) & (l / ls < 1.25)
    skin = ndimage.binary_opening(skin, iterations=1)
    skin = largest_blob(skin) if skin.any() else skin
    filled = ndimage.binary_fill_holes(ndimage.binary_closing(skin, iterations=3)) & a
    if back:
        return np.zeros_like(a), filled
    hb = hexrgb(hair_hex_)
    lh = float(hb @ W3)
    hair = a & (np.abs(c / l[..., None] - hb / lh).sum(-1) < 0.45) & (l / lh > 0.5) & (l / lh < 1.35)
    P = filled | (ndimage.binary_dilation(filled, iterations=4) & a & ~hair)
    if thin:
        ys = np.nonzero(filled.any(1))[0]
        cut_y = int(ys.min() + 0.36 * (ys.max() - ys.min()))
        P[:cut_y] = False
    return P, filled


def register(orig, new_rgba, weight):
    """find scale s and shift (dx, dy) so that new_rgba resampled = orig on the weighted region. Brute force on ink + alpha edges.
    new_rgba is the keyed cell crop (sheet px). returns (s, dx, dy, score) meaning orig(x, y) ~ new(x * s + dx, y * s + dy)."""
    oi = ndimage.gaussian_filter(ink(orig), 1.2) * weight
    best = (None, -1e9)
    ni_full = ndimage.gaussian_filter(ink(new_rgba), 1.2 * SHEET_K)
    h, w = orig.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    for s in np.arange(SHEET_K * 0.9, SHEET_K * 1.1 + 1e-6, 0.01):
        # resample new at scale s around 0, then correlate by FFT for the shift
        nw = int(new_rgba.shape[1] / s)
        nh = int(new_rgba.shape[0] / s)
        ns = np.asarray(Image.fromarray((ni_full * 255).astype(np.uint8)).resize((nw, nh), Image.BILINEAR)).astype(np.float32) / 255.0
        # correlation of oi (template) over ns
        F = np.fft.rfft2(ns, s=(nh + h, nw + w))
        G = np.fft.rfft2(oi[::-1, ::-1], s=(nh + h, nw + w))
        cc = np.fft.irfft2(F * G, s=(nh + h, nw + w))
        iy, ix = np.unravel_index(np.argmax(cc), cc.shape)
        sc = cc[iy, ix] / (np.sqrt((oi ** 2).sum() * (ns ** 2).sum()) + 1e-6)
        if sc > best[1]:
            # template top-left in ns coords
            ty, tx = iy - (h - 1), ix - (w - 1)
            best = ((s, tx * s, ty * s), sc)
    (s, dx, dy), sc = best
    # sub-step refine on a small grid
    def score(s_, dx_, dy_):
        m = sample(new_rgba, s_, dx_, dy_, w, h)
        ni = ndimage.gaussian_filter(ink(m), 1.2)
        return float((ni * oi).sum() / (np.sqrt((oi ** 2).sum() * (ni ** 2).sum()) + 1e-6))
    cur = (s, dx, dy)
    cs = score(*cur)
    for step in (2.0, 1.0, 0.5):
        improved = True
        while improved:
            improved = False
            for d in ((0.005, 0, 0), (-0.005, 0, 0), (0, step, 0), (0, -step, 0), (0, 0, step), (0, 0, -step)):
                cand = (cur[0] + d[0] * (step / 2.0), cur[1] + d[1], cur[2] + d[2])
                c2 = score(*cand)
                if c2 > cs:
                    cur, cs, improved = cand, c2, True
    return cur[0], cur[1], cur[2], cs


def sample(src, s, dx, dy, w, h, ox=0, oy=0):
    """output (h, w) where out(x, y) = src((x + ox) * s + dx, (y + oy) * s + dy) — bilinear, alpha premultiplied"""
    im = Image.fromarray(src)
    # affine: input = (a*x + b*y + c, d*x + e*y + f)
    out = im.transform((w, h), Image.AFFINE, (s, 0, dx + ox * s, 0, s, dy + oy * s), resample=Image.BICUBIC,
                       fillcolor=(0, 255, 0, 0))
    return np.asarray(out)


def hair_margin(img, orig, hair_hex_, others):
    """(margin, keep) — margin > 0 where a pixel of img is nearer the hair than any of `others` (skin / headwear)."""
    W3 = np.array([0.299, 0.587, 0.114], np.float32)
    c = img[..., :3].astype(np.float32)
    hb = hexrgb(hair_hex_) * 255.0
    lb = float(hb @ W3)
    l = np.maximum(c @ W3, 1.0)
    chrom = c / l[..., None]
    # per-pixel nearest-class decision in (chromaticity, log brightness) with the class centres measured on the ORIGINAL piece itself
    # (its own hair pixels vs its own skin / headwear pixels — red hair and warm skin are close in hue, so the drawn bases alone are
    # not enough), the decision margin smoothed over ~2 px (the drawings carry grain). Pixels inside the original's skin (ears, neck,
    # face edge) are never recoloured.
    oc = orig[..., :3].astype(np.float32)
    ol = np.maximum(oc @ W3, 1.0)
    oa = orig[..., 3] > 200
    def feat(cc, ll):
        return np.concatenate([cc / ll[..., None], 0.6 * np.log(ll / 128.0)[..., None]], -1)
    of = feat(oc, ol)
    def cls(hexs):
        b_ = hexrgb(hexs) * 255.0
        lb_ = float(b_ @ W3)
        return oa & (np.abs(oc / ol[..., None] - b_ / lb_).sum(-1) < 0.45) & (ol / lb_ > 0.55) & (ol / lb_ < 1.25)
    oh_m = cls(hair_hex_)
    nf = feat(c, l)
    if oh_m.sum() > 30:
        ch_ = np.median(of[oh_m], 0)
        dh = np.abs(nf - ch_).sum(-1)
    else:
        dh = np.abs(chrom - hb / lb).sum(-1)
    margin = np.full(dh.shape, 9.0, np.float32)
    keep_skin = np.zeros(img.shape[:2], bool)
    for o in others:
        om_ = cls(o)
        if om_.sum() > 30:
            do = np.abs(nf - np.median(of[om_], 0)).sum(-1)
        else:
            ob = hexrgb(o) * 255.0
            do = np.abs(chrom - ob / float(ob @ W3)).sum(-1)
        margin = np.minimum(margin, do - dh)
        keep_skin |= om_
    margin = ndimage.gaussian_filter(margin, 1.5)
    return margin, keep_skin


def recolour_hair(img, orig, hair_hex_, sel, others=()):
    """new hair pixels (sel, not ink, nearer the drawn hair base than any colour in `others`) get the drawn hair base's HUE (their own
    brightness), then the brightness is scaled so their median matches the original's hair median — so the dye mask finds them
    (build_atlas.dye_mask: chromaticity near the base) and the shader's brightness transfer gives the same shade as the original hair"""
    W3 = np.array([0.299, 0.587, 0.114], np.float32)
    c = img[..., :3].astype(np.float32)
    hb = hexrgb(hair_hex_) * 255.0
    lb = float(hb @ W3)
    l = np.maximum(c @ W3, 1.0)
    chrom = c / l[..., None]
    margin, keep_skin = hair_margin(img, orig, hair_hex_, others)
    m = sel & (l > 0.30 * 255) & (margin > 0.0) & ~ndimage.binary_dilation(keep_skin, iterations=2)
    # the ink-ish pixels (strand lines, outlines inside the hair) take the hair hue too when they touch hair
    m |= sel & (l <= 0.30 * 255) & (l > 0.12 * 255) & ndimage.binary_dilation(m, iterations=2)
    oc = orig[..., :3].astype(np.float32)
    ol = np.maximum(oc @ W3, 1.0)
    oh = (orig[..., 3] > 200) & (np.abs(oc / ol[..., None] - hb / lb).sum(-1) < 0.45) & (ol / lb > 0.5) & (ol / lb < 1.3)
    if m.sum() < 30:
        return img, 1.0
    k = float(np.median(ol[oh]) / np.median(l[m])) if oh.sum() > 30 else 1.0
    k = float(np.clip(k, 0.75, 1.3))
    out = img.copy()
    newc = (hb / lb)[None, :] * (l[m] * k)[:, None]
    out[..., :3][m] = np.clip(newc, 0, 255).astype(np.uint8)
    return out, k


def find_head(cell_rgb):
    rgb, a = key_green(cell_rgb)
    m = largest_blob(a > 128)
    ys, xs = np.nonzero(m)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.dstack([rgb, np.where(m, a, 0)]).astype(np.uint8)
    return rgba, (x0, y0, x1, y1)


def cut(job, take=None):
    s, kind, var, _c, _r = JOBS[job]
    lib = json.load(open(os.path.join(ART, "doll_lib.json")))
    skin_hex, hair_h = lib["base"][s]["skin"], lib["base"][s]["hair"]
    src = os.path.join(RAW, job + (("_" + take) if take else "") + ".png")
    sheet = np.asarray(Image.open(src).convert("RGB").resize((W, H), Image.LANCZOS))
    check = []
    report = {}
    for i, v in enumerate(VIEWS):
        orig_im = piece(s, v)
        orig = np.asarray(orig_im)
        h, w = orig.shape[:2]
        k, x0, y0 = cell_xform(orig_im)
        cell = sheet[:, i * CELL:(i + 1) * CELL]
        rgba, bb = find_head(cell)
        back = v in ("q_back", "back")
        prot, filled = face_protect(orig, skin_hex, hair_h, back, var == "thin")
        wgt = np.where(filled, 1.0, 0.35).astype(np.float32) if not back else np.ones((h, w), np.float32)
        sc, dx, dy, score = register(orig, rgba, wgt)
        # padded canvas: out(x, y) for x in [-PAD, w + PAD)
        new = sample(rgba, sc, dx, dy, w + 2 * PAD, h + 2 * PAD, -PAD, -PAD).copy()
        new[..., 3] = np.where(new[..., 3] > 128, 255, np.where(new[..., 3] > 40, new[..., 3], 0))
        O = np.zeros((h + 2 * PAD, w + 2 * PAD, 4), np.uint8)
        O[PAD:PAD + h, PAD:PAD + w] = orig
        P = np.zeros((h + 2 * PAD, w + 2 * PAD), bool)
        P[PAD:PAD + h, PAD:PAD + w] = prot
        if kind == "head":
            out = new.copy()
            out, kh = recolour_hair(out, O, hair_h, (out[..., 3] > 128) & ~P, [skin_hex] + ([lib["base"][s]["hat"]] if s == "a" else []))
            out[P] = O[P]
            # the neck stub: keep the original's lowest rows exactly (chin pivot / neck erasing in build_atlas)
            nb = int(h * 0.12)
            low = np.zeros_like(P)
            low[PAD + h - nb:PAD + h] = True
            # only the neck stub's columns (its width in the original's last rows, + a margin) — hair beside the neck stays new
            lastx = np.nonzero(orig[h - 3:, :, 3].max(0) > 128)[0]
            colm = np.zeros(w + 2 * PAD, bool)
            if len(lastx):
                colm[PAD + max(0, lastx.min() - 6):PAD + lastx.max() + 7] = True
            low &= colm[None, :] & ((O[..., 3] > 0) | (out[..., 3] > 0))
            if back:
                low[...] = False          # back views: braids / curls may hang over the neck columns
            out[low] = O[low]
            diff = np.abs(out[P].astype(int) - O[P].astype(int)).max() if P.any() else 0
            name = "head_" + var
            report[v] = {"scale": round(sc, 4), "dx": round(dx, 2), "dy": round(dy, 2), "score": round(score, 3),
                         "hair_k": round(kh, 3), "face_px": int(P.sum()), "face_maxdiff": int(diff)}
        else:
            # beard overlay: changed, hair-coloured-or-ink pixels in the lower face, not the original's mouth
            c = new[..., :3].astype(np.float32)
            oc = O[..., :3].astype(np.float32)
            changed = (np.abs(c - oc).sum(-1) > 60) & (new[..., 3] > 128)
            hb = hexrgb(hair_h) * 255.0
            l = np.maximum(c @ np.array([0.299, 0.587, 0.114]), 1.0)
            lb = float(hb @ np.array([0.299, 0.587, 0.114]))
            mg, _k = hair_margin(new, O, hair_h, [skin_hex])
            hairy = (mg > 0.0) & (l > 0.30 * 255) & (new[..., 3] > 128)
            dark = (l <= 0.30 * 255) & (new[..., 3] > 128)
            # lower face: below the eye line (40% down the original face box)
            F = np.zeros_like(P)
            F[PAD:PAD + h, PAD:PAD + w] = filled
            ys_, xs_ = np.nonzero(F)
            fy0, fy1 = ys_.min(), ys_.max()
            low = np.zeros_like(P)
            low[int(fy0 + 0.45 * (fy1 - fy0)):] = True
            grown = ndimage.binary_dilation(F, iterations=10)
            down = grown.copy()
            for _ in range(70):                 # a full beard hangs below the jaw
                down[1:] |= down[:-1]
            region = (grown | (down & ndimage.binary_dilation(F, iterations=44))) & low
            bh = hairy & changed & region
            bh = ndimage.binary_opening(bh, iterations=1)
            bh = largest_blob(bh) if bh.any() else bh
            # its outline: ink next to the beard, not lower than the beard itself (the neck stub lines below stay out)
            ysb = np.nonzero(bh.any(1))[0]
            cap = np.zeros_like(bh)
            if len(ysb):
                cap[:ysb.max() + 7] = True
            bm = bh | (dark & ndimage.binary_dilation(bh, iterations=5) & cap & region)
            bm = ndimage.binary_closing(bm, iterations=1)
            # mouth of the original stays visible: original ink inside the face below the nose
            om = (ink(O) > 0.5) & ndimage.binary_erosion(F, iterations=6) & low
            bm &= ~ndimage.binary_dilation(om, iterations=1)
            out = np.zeros_like(new)
            out[bm] = new[bm]
            out, kh = recolour_hair(out, O, hair_h, bm, [skin_hex])
            name = "beard_" + var
            report[v] = {"scale": round(sc, 4), "dx": round(dx, 2), "dy": round(dy, 2), "score": round(score, 3), "beard_px": int(bm.sum())}
            if back:
                out[...] = 0          # no beard pieces for the back views
        Image.fromarray(out).save(os.path.join(PARTS, s, v, name + ".png"))
        comp = Image.new("RGBA", (out.shape[1], out.shape[0]), (200, 225, 200, 255))
        if kind == "beard":
            comp.alpha_composite(Image.fromarray(O))
        comp.alpha_composite(Image.fromarray(out))
        ob = Image.new("RGBA", comp.size, (200, 225, 200, 255))
        ob.alpha_composite(Image.fromarray(O))
        check.append((ob, comp))
    meta_p = os.path.join(RAW, "variants.json")
    meta = json.load(open(meta_p)) if os.path.exists(meta_p) else {}
    meta[job] = {"set": s, "kind": kind, "var": var, "pad": PAD, "take": take or "", "views": report}
    json.dump(meta, open(meta_p, "w"), indent=1, sort_keys=True)
    # check image: originals on top, variants below
    cw = max(c[1].width for c in check)
    chh = max(c[1].height for c in check)
    ci = Image.new("RGB", (cw * 4, chh * 2), (255, 255, 255))
    for i, (o, n) in enumerate(check):
        ci.paste(o.convert("RGB"), (i * cw, 0))
        ci.paste(n.convert("RGB"), (i * cw, chh))
    ci.save(os.path.join(RAW, job + "_check.png"))
    print(job, json.dumps(report))


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "sheet":
        os.makedirs(RAW, exist_ok=True)
        for st in "abcdefg":
            make_sheet(st, os.path.join(RAW, "in_%s.png" % st))
    elif cmd == "prompt":
        print(prompt(sys.argv[2], sys.argv[3]))
    elif cmd == "ref":
        r = JOBS[sys.argv[2]][4]
        print(os.path.join(RAW, "in_%s.png" % r) if r else "")
    elif cmd == "cut":
        cut(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    elif cmd == "cutall":
        for j in JOBS:
            if os.path.exists(os.path.join(RAW, j + ".png")):
                cut(j)
    elif cmd == "list":
        print(" ".join(JOBS))
