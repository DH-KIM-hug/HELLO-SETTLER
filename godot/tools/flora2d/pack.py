"""Pack the keyed flora / prop pictures for the game (tools/flora2d — same rules as tools/bld2d/pack.py).
usage: pack.py [cut_dir]   (key.py output; a picture missing there is re-read from tools/flora2d/pics/<pic>.png — the packed copy)
-> godot/art/flora2d/atlas_<group>.png  one atlas per group (common · spring · summer · autumn · winter): every card of a group draws
                                        from it in ONE MultiMesh draw (FloraBatch); only the current season's flower atlas is loaded
-> godot/art/flora2d/<pic>.png          single pictures (great trees, giant sunflower body) — own texture, one card each
-> godot/tools/flora2d/pics/<pic>.png   packed-size copy of every picture (re-pack without the raw sheets; not imported)
-> godot/view/flora2d/flora2d_pics.gd   generated table (world sizes from measure.json, atlas rects, model -> picture)"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

T = Path(__file__).parent
G = T.parent.parent
sys.path.insert(0, str(T))
import table  # noqa: E402
from sheets import SHEETS  # noqa: E402
import importlib.util  # noqa: E402
_spec = importlib.util.spec_from_file_location("bld2d_pack", T.parent / "bld2d" / "pack.py")
bpack = importlib.util.module_from_spec(_spec)  # tools/bld2d/pack.py (shared rules)
sys.path.insert(0, str(T.parent / "bld2d"))
_spec.loader.exec_module(bpack)
sys.path.pop(0)

ART = G / "art" / "flora2d"
PICS_DIR = T / "pics"
OUT_GD = G / "view" / "flora2d" / "flora2d_pics.gd"
ATLAS_W = 2048
PAD = 4


def import_settings(path: Path) -> None:
    """lossless + mipmaps like the building pictures, or (table.VRAM) GPU-compressed: BPTC on desktop, ASTC 4x4 on Android
    (high quality — 8 bits/pixel, a quarter of RGBA8; the flat cel colours and the cut-out edge survive it)"""
    old = dict(bpack.IMPORT_PARAMS)
    if table.VRAM:
        bpack.IMPORT_PARAMS.update({"compress/mode": "2", "compress/high_quality": "true"})
    else:
        bpack.IMPORT_PARAMS.update({"compress/mode": "0", "compress/high_quality": "false"})
    bpack.import_settings(path)
    bpack.IMPORT_PARAMS.clear()
    bpack.IMPORT_PARAMS.update(old)


def group_of(pic: str) -> str:
    if pic.startswith(table.SINGLE_PREFIX):
        return "single"
    if pic in table.GIANTS:
        return "giants"
    for s, l in table.SEASONS.items():
        if pic in l:
            return s
    return "common"


def main() -> None:
    cut = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    meas = json.loads((T / "measure.json").read_text())
    ART.mkdir(parents=True, exist_ok=True)
    PICS_DIR.mkdir(parents=True, exist_ok=True)
    (PICS_DIR / ".gdignore").touch()
    rows = {}
    imgs = {}
    for s, d in SHEETS.items():
        for pic, _spec, _desc in d["cells"]:
            src = cut / f"{pic}.png" if cut else None
            if src is None or not src.exists():
                src = PICS_DIR / f"{pic}.png"
            if not src.exists():
                print("MISSING", pic)
                continue
            img = Image.open(src).convert("RGBA")
            m = dict(meas.get(pic, {}))
            m.update(table.NO_MODEL.get(pic, {}))
            m.update(table.OVERRIDE.get(pic, {}))
            if "w" not in m:
                print("NO SIZE", pic)
                continue
            w = float(m["w"])
            h = w * img.height / img.width
            if pic in table.KEEP_H and "h" in m:
                h = float(m["h"])       # stretched to the model's height (the giant sunflower stalk meets its head)
            grp = group_of(pic)
            if grp == "single":
                k = min(1.0, table.SINGLE_MAX / max(img.width, img.height))
            else:
                ppu = table.FLOWER_PPU if w > 3.0 else table.CAP_PPU
                k = min(1.0, w * ppu / img.width)
            nw, nh = max(8, round(img.width * k)), max(8, round(img.height * k))
            im2 = bpack.resize_rgba(img, nw, nh) if (nw, nh) != img.size else img
            if src.parent != PICS_DIR:
                bpack.save_small(im2, PICS_DIR / f"{pic}.png")
            imgs[pic] = im2
            rows[pic] = dict(w=round(w, 4), h=round(h, 4), front=round(float(m.get("front", 0.0)), 4),
                             df=round(float(m.get("df", float(m.get("front", 0.0)) * table.DEPTH_K)), 4),
                             dx=round(float(m.get("dx", 0.0)), 4), cy=round(float(m.get("cy", h * 0.5)), 4),
                             mode=1 if pic in table.GROUND else 0, contact=float(table.CONTACT.get(pic, 0.0)),
                             flip=pic in table.FLIP, sway=pic in table.SWAY, group=grp, px=[nw, nh])
    # atlases
    atlases = {}
    groups = sorted({r["group"] for r in rows.values()} - {"single"})
    for grp in groups:
        names = [n for n in rows if rows[n]["group"] == grp]
        order = sorted(names, key=lambda n: -imgs[n].height)
        x = y = shelf = 0
        pos = {}
        for n in order:
            im = imgs[n]
            if x + im.width + PAD * 2 > ATLAS_W:
                x = 0
                y += shelf
                shelf = 0
            pos[n] = (x + PAD, y + PAD)
            x += im.width + PAD * 2
            shelf = max(shelf, im.height + PAD * 2)
        H = (y + shelf + 3) // 4 * 4
        atlas = np.zeros((H, ATLAS_W, 4), np.uint8)
        atlas[..., :3] = bpack.INK.astype(np.uint8)
        for n, (px, py) in pos.items():
            a = np.asarray(imgs[n])
            atlas[py:py + a.shape[0], px:px + a.shape[1]] = a
        path = ART / f"atlas_{grp}.png"
        bpack.save_small(Image.fromarray(atlas, "RGBA"), path)
        import_settings(path)
        for i, n in enumerate(sorted(names)):
            px, py = pos[n]
            im = imgs[n]
            rows[n]["uv"] = [px / ATLAS_W, py / H, im.width / ATLAS_W, im.height / H]
            rows[n]["i"] = i
        atlases[grp] = (ATLAS_W, H, len(names))
    for n, r in rows.items():
        if r["group"] == "single":
            path = ART / f"{n}.png"
            bpack.save_small(imgs[n], path)
            import_settings(path)
            r["uv"] = [0.0, 0.0, 1.0, 1.0]
            r["i"] = 0
    L = ["## GENERATED by godot/tools/flora2d/pack.py from tools/flora2d/table.py + measure.json — do not edit by hand.",
         "## 2D storybook flora & prop pictures (RENDERING.md 확정 2026-11-08). Read through Flora2D (view/flora2d/flora2d.gd).",
         "extends RefCounted", "",
         "## group -> atlas texture (one MultiMesh draw per group in view)",
         "const ATLASES := {" + ", ".join(f"\"{g}\": \"res://art/flora2d/atlas_{g}.png\"" for g in atlases) + "}",
         "## picture -> {w, h (world units on screen at scale 1), front, dx, cy, mode (0 card · 1 ground), contact, flip, sway,",
         "##   group (atlas name or \"single\"), uv (atlas rect), i (index in its atlas), px}",
         "const PICS := {"]
    for n in sorted(rows):
        r = rows[n]
        L.append(f"\t\"{n}\": {{\"w\": {r['w']}, \"h\": {r['h']}, \"front\": {r['front']}, \"df\": {r['df']}, \"dx\": {r['dx']}, \"cy\": {r['cy']}, "
                 f"\"mode\": {r['mode']}, \"contact\": {r['contact']}, \"flip\": {str(r['flip']).lower()}, \"sway\": {str(r['sway']).lower()}, "
                 f"\"group\": \"{r['group']}\", \"uv\": Rect2({r['uv'][0]:.6f}, {r['uv'][1]:.6f}, {r['uv'][2]:.6f}, {r['uv'][3]:.6f}), "
                 f"\"i\": {r['i']}, \"px\": Vector2i({r['px'][0]}, {r['px'][1]})}},")
    L.append("}")
    L.append("## game model name (Art / FloraBatch kind) -> picture")
    L.append("const MODELS := " + json.dumps({k: v for k, v in table.MODELS.items() if v in rows}, ensure_ascii=False, sort_keys=True))
    L.append("## goods (Style.ITEM_COLORS keys) -> pile picture")
    L.append("const GOODS := " + json.dumps(table.GOODS, ensure_ascii=False))
    OUT_GD.parent.mkdir(parents=True, exist_ok=True)
    OUT_GD.write_text("\n".join(L) + "\n", encoding="utf-8")
    vram = 0
    for g, (w, h, n) in atlases.items():
        vram += w * h * (1 if table.VRAM else 4) * 4 // 3
        print(f"atlas {g}: {w}x{h}, {n} pictures")
    singles = [n for n in rows if rows[n]["group"] == "single"]
    for n in singles:
        vram += rows[n]["px"][0] * rows[n]["px"][1] * (1 if table.VRAM else 4) * 4 // 3
    disk = sum(p.stat().st_size for p in ART.glob("*.png"))
    print(f"{len(rows)} pictures ({len(singles)} single), disk {disk / 1e6:.1f} MB, VRAM if everything loaded {vram / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
