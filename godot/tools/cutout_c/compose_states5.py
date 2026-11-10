"""Method C states5 evidence sheets (2026-11-10). Run after
    CUTC_MODE=strip CUTC_CLIPS=<clip> CUTC_TAG=<tag> [CUTC_LOAD=..] [CUTC_PROP=..] [CUTC_DYE=..] godot --path godot -s tools/shot_cutC_compare.gd
usage: python3 compose_states5.py <tag> <clip> <out> "<title>"
godot_shots/cutC/strip_tmp_<tag>_ppu<P>_<clip>_<view>.png -> godot_shots/cutC/states5_<out>_ppu<P>.png
(the views that were captured, stacked and labelled: TOP row = current cutout, BOTTOM row = method C). The tmp strips are deleted.
`loads`: python3 compose_states5.py loads -> loads_tmp_ppu<P>_<n>.png -> states5_live_loads_ppu<P>.png (the last capture of each zoom)."""
import glob, os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "godot_shots", "cutC"))
VIEWS = ["front", "3/4 front", "3/4 back", "back"]


def strips(tag, clip, out, title):
    for ppu in (20, 44):
        fs = [(v, os.path.join(OUT, f"strip_tmp_{tag}_ppu{ppu}_{clip}_{v}.png")) for v in range(4)]
        fs = [(v, f) for v, f in fs if os.path.exists(f)]
        if not fs:
            continue
        ims = [Image.open(f).convert("RGB") for _, f in fs]
        lw, th = 92, 26
        W = max(lw + max(i.width for i in ims), 760)
        H = th + sum(i.height + 4 for i in ims)
        sheet = Image.new("RGB", (W, H), (40, 40, 40))
        d = ImageDraw.Draw(sheet)
        d.text((6, 6), f"ppu {ppu} - {title} - TOP row = current cutout, BOTTOM row = method C", fill=(255, 255, 255))
        y = th
        for (v, _), im in zip(fs, ims):
            sheet.paste(im, (lw, y))
            d.text((6, y + im.height // 2 - 14), VIEWS[v], fill=(255, 255, 255))
            d.text((6, y + 4), "old", fill=(255, 210, 120))
            d.text((6, y + im.height - 16), "new C", fill=(140, 220, 255))
            y += im.height + 4
        sheet.save(os.path.join(OUT, f"states5_{out}_ppu{ppu}.png"), optimize=True)
        for _, f in fs:
            os.remove(f)
        print("states5", out, ppu, sheet.size)


def loads():
    for ppu in (20, 44):
        fs = sorted(glob.glob(os.path.join(OUT, f"loads_tmp_ppu{ppu}_*.png")))
        if not fs:
            continue
        pick = fs[int(sys.argv[2])] if len(sys.argv) > 2 else fs[-1]
        Image.open(pick).convert("RGB").save(os.path.join(OUT, f"states5_live_loads_ppu{ppu}.png"), optimize=True)
        for f in fs:
            os.remove(f)
        print("states5 live loads", ppu, os.path.basename(pick))


if __name__ == "__main__":
    if sys.argv[1] == "loads":
        loads()
    else:
        strips(*sys.argv[1:5])
