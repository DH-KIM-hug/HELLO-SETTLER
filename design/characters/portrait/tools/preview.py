"""Quick Python preview of composed portraits (same tint rule as godot/view/ui/portrait_tint.gdshader).
usage: preview.py godot/art/portrait <out.png> [seed]"""
import sys
import numpy as np
from PIL import Image

L = sys.argv[1]
SKINS = ["f8e1cc", "edc7a0", "dca97a", "c3895a", "8d5a3a", "5e3a26"]
HAIRS = ["2a2324", "5b3b29", "d6aa5e", "94401f", "c9c4c2", "d0682e"]
CLOTH = ["46759e", "6e452f", "3e5c2c", "a0703e", "355b6e", "8b5733"]


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float) / 255


def layer(name, tint=None, sx=1.0, cut=None, fill=False):
    im = Image.open(f"{L}/{name}{'_fill' if fill else ''}.png").convert("RGBA")
    if sx != 1.0:
        w = int(round(256 * sx))
        im2 = im.resize((w, 256), Image.LANCZOS)
        canvas = Image.new("RGBA", (256, 256))
        canvas.paste(im2, ((256 - w) // 2, 0))
        im = canvas if w <= 256 else im2.crop(((w - 256) // 2, 0, (w - 256) // 2 + 256, 256))
    a = np.asarray(im).astype(float) / 255
    if fill:
        a[..., :3] = np.clip(a[..., :3] * hexc(tint) / 0.6, 0, 1)
    if cut is not None:
        c = np.asarray(Image.open(f"{L}/cut_{cut}.png").convert("L")).astype(float) / 255
        a[..., 3] *= 1 - c
    return a


def over(dst, src):
    sa = src[..., 3:4]
    dst[..., :3] = src[..., :3] * sa + dst[..., :3] * (1 - sa)
    dst[..., 3:4] = sa + dst[..., 3:4] * (1 - sa)


def compose(spec):
    out = np.zeros((256, 256, 4))
    out[..., :3] = hexc("cfe3cf")
    out[..., 3] = 1
    import os
    for s in spec:
        s = list(s) + [None] * (4 - len(s))
        name, tint, sx, cut = s[0], s[1], s[2] or 1.0, s[3]
        if tint and os.path.exists(f"{L}/{name}_fill.png"):
            over(out, layer(name, tint, sx, cut, True))
        over(out, layer(name, None, sx, cut))
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


combos = []
hairs = ["hair_short", "hair_long", "hair_braids", "hair_bun", "hair_curly", "hair_curly_long", "hair_wave", "hair_wave_long", "hair_receding", "hair_bald_ring", "hair_child", None]
faces = ["face_normal", "face_happy", "face_sad", "face_sick", "face_sleep", "face_surprised", "face_talking"]
cloths = ["cloth_tunic", "cloth_dress", "cloth_robe", "cloth_hood", "cloth_child", "cloth_tunic_tie", "cloth_vest"]
hats = [None, None, "hat_straw", "hat_scarf", "hat_cap", "hat_baker", "hat_fisher", "hat_scarf_top"]
rng = np.random.default_rng(int(sys.argv[3]) if len(sys.argv) > 3 else 1)
for i in range(24):
    sk, hc, cc = SKINS[i % 6], HAIRS[rng.integers(6)], CLOTH[rng.integers(6)]
    hair = hairs[i % len(hairs)]
    hat = hats[rng.integers(len(hats))]
    sx = [0.92, 1.0, 1.1][rng.integers(3)]
    spec = [("skin_body", sk, sx), (cloths[rng.integers(len(cloths))], cc, sx)]
    if i % 5 == 0:
        spec.append(("over_sash", None, sx))
    if i % 7 == 3:
        spec.append(("over_apron", None, sx))
    spec.append(("skin_head", sk))
    spec.append((faces[i % len(faces)], None))
    if i % 6 == 2:
        spec.append(("beard_full", hc))
    if hair:
        spec.append((hair, hc, 1.0, hat))
    if hat:
        spec.append((hat, CLOTH[(i + 2) % 6]))
    combos.append(compose(spec))
sheet = Image.new("RGBA", (256 * 6, 256 * 4))
for i, c in enumerate(combos):
    sheet.paste(c, ((i % 6) * 256, (i // 6) * 256))
sheet.save(sys.argv[2])
