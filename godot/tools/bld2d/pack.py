"""Pack the keyed building pictures for the game.
usage: pack.py [cut_dir]      (default: raw/cut — key.py output; a picture missing there is re-read from art/bld2d/<name>.png)
-> godot/art/bld2d/<name>.png   near picture, NEAR_PPU px per world unit (zoom step 4), 256-colour PNG with alpha
-> godot/art/bld2d/far_atlas.png all pictures at FAR_PPU (zoom step 3) in one atlas — the village-zoom MultiMesh draws every
                                 building card from it in ONE draw call
-> godot/view/bld2d/bld2d_pics.gd  generated table (world sizes, card mode, atlas rects, type -> pictures)"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

T = Path(__file__).parent
G = T.parent.parent
sys.path.insert(0, str(T))
import table  # noqa: E402

ART = G / "art" / "bld2d"
OUT_GD = G / "view" / "bld2d" / "bld2d_pics.gd"
INK = np.array([58, 42, 34], np.float32)
ATLAS_W = 2048
PAD = 4


def resize_rgba(img: Image.Image, w: int, h: int, ink=None) -> Image.Image:
    """Premultiplied Lanczos; rim pixels lean to the ink colour so the alpha-cut edge reads as the outline (spike key.py).
    ink = the picture's own line colour (table key "ink" — the wheat rows are drawn with a golden/green line, not the dark one)."""
    INK = np.array(ink, np.float32) if ink is not None else globals()["INK"]
    a = np.asarray(img).astype(np.float32)
    al = a[..., 3:4] / 255.0
    prem = a[..., :3] * al
    P = np.asarray(Image.fromarray(prem.clip(0, 255).astype(np.uint8)).resize((w, h), Image.LANCZOS)).astype(np.float32)
    A = np.asarray(Image.fromarray((al[..., 0] * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS)).astype(np.float32) / 255.0
    A = A.clip(0, 1)
    C = np.where(A[..., None] > 0.02, P / np.maximum(A[..., None], 1e-3), INK)
    edge = ((A > 0.02) & (A < 0.9))[..., None]
    C = np.where(edge, C * 0.5 + INK * 0.5, C)
    return Image.fromarray(np.dstack([C.clip(0, 255), A * 255]).astype(np.uint8), "RGBA")


def save_small(img: Image.Image, path: Path) -> None:
    """256-colour palette PNG (flat cel colours survive; ~1/3 the bytes). Alpha is snapped to 0/255 first — the card shader
    alpha-cuts at 0.5 anyway, and a binary alpha keeps the palette for colours."""
    a = np.asarray(img).copy()
    a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
    q = Image.fromarray(a, "RGBA").quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    q.save(path, optimize=True)


IMPORT_PARAMS = {"mipmaps/generate": "true", "detect_3d/compress_to": "0", "compress/mode": "0"}


def import_settings(png: Path) -> None:
    """Godot import: lossless + mipmaps (the cards are minified 1-3x across zoom steps 3-4), never auto-switch to VRAM
    compression. Patches an existing .import, or writes a stub Godot completes on the next --import."""
    imp = png.with_suffix(".png.import")
    if not imp.exists():
        imp.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n' +
                       "".join(f"{k}={v}\n" for k, v in IMPORT_PARAMS.items()))
        return
    lines = imp.read_text().splitlines()
    out = []
    for ln in lines:
        k = ln.split("=", 1)[0]
        out.append(f"{k}={IMPORT_PARAMS[k]}" if k in IMPORT_PARAMS else ln)
    imp.write_text("\n".join(out) + "\n")


def main() -> None:
    cut = Path(sys.argv[1]) if len(sys.argv) > 1 else T / "raw" / "cut"
    ART.mkdir(parents=True, exist_ok=True)
    (ART / ".gdignore").unlink(missing_ok=True)
    rows = {}
    fars = {}
    for name, p in table.PICS.items():
        src = cut / f"{name}.png"
        if not src.exists():
            src = ART / f"{name}.png"
        if not src.exists():
            print("MISSING", name)
            continue
        img = Image.open(src).convert("RGBA")
        w = float(p["w"])
        h = w * img.height / img.width
        nw = min(img.width, max(32, round(w * table.NEAR_PPU)))
        nh = max(8, round(nw * img.height / img.width))
        near = resize_rgba(img, nw, nh, p.get("ink")) if (nw, nh) != img.size else img
        if src.parent != ART:
            save_small(near, ART / f"{name}.png")
        fw = max(16, round(w * p.get("atlas", table.FAR_PPU)))
        fh = max(8, round(fw * img.height / img.width))
        fars[name] = resize_rgba(img, fw, fh, p.get("ink"))
        mode = 1 if p.get("mode", "card") == "ground" else 0
        rows[name] = dict(w=round(w, 4), h=round(h, 4), front=round(float(p.get("front", w * table.FRONT_K)), 4),
                          dx=float(p.get("dx", 0.0)), mode=mode, shadow=float(p.get("shadow", 1.0 if mode == 0 else 0.0)),
                          sway=float(p.get("sway", 0.0)), lean=float(p.get("lean", 0.0)), px=[nw, nh])
    # shelf-pack the far pictures (tallest first)
    order = sorted(fars, key=lambda n: -fars[n].height)
    x = y = shelf = 0
    pos = {}
    for n in order:
        im = fars[n]
        if x + im.width + PAD * 2 > ATLAS_W:
            x = 0
            y += shelf
            shelf = 0
        pos[n] = (x + PAD, y + PAD)
        x += im.width + PAD * 2
        shelf = max(shelf, im.height + PAD * 2)
    H = y + shelf
    H = (H + 3) // 4 * 4
    atlas = np.zeros((H, ATLAS_W, 4), np.uint8)
    atlas[..., :3] = INK.astype(np.uint8)
    for n, (px, py) in pos.items():
        a = np.asarray(fars[n])
        atlas[py:py + a.shape[0], px:px + a.shape[1]] = a
    save_small(Image.fromarray(atlas, "RGBA"), ART / "far_atlas.png")
    for i, n in enumerate(rows):
        px, py = pos[n]
        im = fars[n]
        rows[n]["uv"] = [px / ATLAS_W, py / H, im.width / ATLAS_W, im.height / H]
        rows[n]["i"] = i
    # generated GDScript table
    L = ["## GENERATED by godot/tools/bld2d/pack.py from tools/bld2d/table.py — do not edit by hand (tune table.py, re-run pack.py).",
         "## 2D storybook building pictures (RENDERING.md 확정 2026-11-08). Read through Bld2D (view/bld2d/bld2d.gd).",
         "extends RefCounted", "",
         f"const ATLAS := \"res://art/bld2d/far_atlas.png\"",
         f"const ATLAS_SIZE := Vector2i({ATLAS_W}, {H})",
         "## name -> {w, h (world units on screen), front, dx, mode (0 card · 1 ground), shadow, sway (wind lean), lean (depth-only lean toward the camera), px (near size), uv (atlas rect), i (index)}",
         "const PICS := {"]
    for n, r in rows.items():
        L.append(f"\t\"{n}\": {{\"w\": {r['w']}, \"h\": {r['h']}, \"front\": {r['front']}, \"dx\": {r['dx']}, \"mode\": {r['mode']}, "
                 f"\"shadow\": {r['shadow']}, \"sway\": {r['sway']}, \"lean\": {r['lean']}, \"px\": Vector2i({r['px'][0]}, {r['px'][1]}), "
                 f"\"uv\": Rect2({r['uv'][0]:.6f}, {r['uv'][1]:.6f}, {r['uv'][2]:.6f}, {r['uv'][3]:.6f}), \"i\": {r['i']}}},")
    L.append("}")
    L.append("const TYPES := " + json.dumps(table.TYPES, ensure_ascii=False))
    L.append("const WHEAT := " + json.dumps(table.WHEAT))
    L.append("const WHEAT_ROWS := " + json.dumps(table.WHEAT_ROWS))
    L.append("const WHEAT_STUBBLE := " + json.dumps(table.WHEAT_STUBBLE))
    L.append(f"const WHEAT_SOIL := \"{table.WHEAT_SOIL}\"")
    L.append(f"const WHEAT_FENCE := \"{table.WHEAT_FENCE}\"")
    L.append("const WHEAT_ACCENTS := " + json.dumps(table.WHEAT_ACCENTS))
    L.append("const SITES := " + json.dumps(table.SITES))
    L.append("const ALTAR := " + json.dumps(table.ALTAR))
    OUT_GD.parent.mkdir(parents=True, exist_ok=True)
    OUT_GD.write_text("\n".join(L) + "\n", encoding="utf-8")
    for n in list(rows) + ["far_atlas"]:
        import_settings(ART / f"{n}.png")
    tot = sum((ART / f"{n}.png").stat().st_size for n in rows) + (ART / "far_atlas.png").stat().st_size
    vram = sum(r["px"][0] * r["px"][1] * 4 * 4 // 3 for r in rows.values()) + ATLAS_W * H * 4 * 4 // 3
    print(f"{len(rows)} pictures, atlas {ATLAS_W}x{H}, disk {tot / 1e6:.1f} MB, VRAM if all loaded {vram / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
