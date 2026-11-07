"""Copy the layers the game uses into godot/art/portrait and make the hat cut masks
(cut_<hat>.png: hair above a hat's crown is hidden — the alpha of the mask says where).
usage: finals.py <layers_dir> <godot_art_portrait_dir>"""
import os
import shutil
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HATS = ["hat_straw", "hat_scarf", "hat_cap", "hat_baker", "hat_fisher", "hat_scarf_top"]


def cut_mask(hat_png):
    a = np.asarray(Image.open(hat_png).convert("RGBA"))[..., 3] > 128
    h, w = a.shape
    cut = np.zeros_like(a)
    rows = np.arange(h)[:, None]
    crown = a.copy()
    crown[h // 2:] = False                 # only the crown part (scarf ends hanging by the neck do not cut hair)
    has = crown.any(0)
    top = np.where(has, crown.argmax(0), h)
    cut = (rows < top[None, :]) & has[None, :]
    cut = ndi.binary_dilation(cut, iterations=3) & ~ndi.binary_erosion(a, iterations=3)
    return Image.fromarray((cut * 255).astype(np.uint8), "L")


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(dst):
        if f.endswith(".png"):
            os.remove(os.path.join(dst, f))
    total = 0
    for f in sorted(os.listdir(src)):
        if f.endswith(".png"):
            shutil.copy(os.path.join(src, f), os.path.join(dst, f))
            total += os.path.getsize(os.path.join(dst, f))
    for h in HATS:
        p = os.path.join(src, h + ".png")
        if os.path.exists(p):
            cut_mask(p).save(os.path.join(dst, "cut_" + h + ".png"), optimize=True)
            total += os.path.getsize(os.path.join(dst, "cut_" + h + ".png"))
    print("total bytes", total)
