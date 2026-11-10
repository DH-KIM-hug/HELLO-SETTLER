"""Method-C spike comparison sheets (2026-11-08). Run after `godot --path godot -s res://tools/shot_cutC_compare.gd`.
godot_shots/cutC/strip_tmp_ppu<P>_<clip>_<view>.png -> godot_shots/cutC/cmp_ppu<P>_<clip>.png (4 views stacked, labelled)
godot_shots/cutC/live_tmp/ppu<P>_NNNN.png          -> godot_shots/cutC/live_ppu<P>.mp4 (12 fps) + live_ppu<P>_sheet.png (every 6th)
The tmp files are deleted afterwards (disk)."""
import glob, os, shutil, subprocess, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "godot_shots", "cutC"))
VIEWS = ["front", "3/4 front", "3/4 back", "back"]
TITLE = {"walk": "walk (8 frames)", "carry": "carry flour sack (8 frames; old = basket)", "idle": "idle 1-4 + hold 5-8"}


def strips():
    for ppu in (20, 44):
        for clip in ("walk", "carry", "idle"):
            fs = [os.path.join(OUT, f"strip_tmp_ppu{ppu}_{clip}_{v}.png") for v in range(4)]
            if not all(os.path.exists(f) for f in fs):
                continue
            ims = [Image.open(f).convert("RGB") for f in fs]
            lw, th = 92, 26
            W = lw + max(i.width for i in ims)
            H = th + sum(i.height + 4 for i in ims)
            sheet = Image.new("RGB", (W, H), (40, 40, 40))
            d = ImageDraw.Draw(sheet)
            d.text((6, 6), f"ppu {ppu} - {TITLE[clip]} - each view: TOP row = current cutout, BOTTOM row = method C (frame-drawn)", fill=(255, 255, 255))
            y = th
            for v, im in enumerate(ims):
                sheet.paste(im, (lw, y))
                d.text((6, y + im.height // 2 - 14), VIEWS[v], fill=(255, 255, 255))
                d.text((6, y + 4), "old", fill=(255, 210, 120))
                d.text((6, y + im.height - 16), "new C", fill=(140, 220, 255))
                y += im.height + 4
            sheet.save(os.path.join(OUT, f"cmp_ppu{ppu}_{clip}.png"), optimize=True)
            for f in fs:
                os.remove(f)
            print("cmp", ppu, clip, sheet.size)


FPS = 30
SEG_T = 0.8 / 0.7          # one octagon side at normal walk (shot_cutC_compare LEG / WALK_SCREEN)


def live():
    tmp = os.path.join(OUT, "live_tmp")
    for ppu in (20, 44, 60):
        fs = sorted(glob.glob(os.path.join(tmp, f"ppu{ppu}_*.png")))
        if not fs:
            continue
        for pre, name in (("ppu", f"live_ppu{ppu}.mp4"), ("b_ppu", f"live_C_close_ppu{ppu}.mp4")):
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(tmp, f"{pre}{ppu}_%04d.png"),
                            "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
                            os.path.join(OUT, name)], check=True)
        # frame-by-frame strips of the method-C woman: 16 consecutive 30 fps captures from the middle of each of the 8 sides
        bs = sorted(glob.glob(os.path.join(tmp, f"b_ppu{ppu}_*.png")))
        rows = []
        for k in range(8):
            i0 = int((k + 0.3) * SEG_T * FPS)
            pick = bs[i0:i0 + 16]
            if len(pick) < 16:
                break
            rows.append([Image.open(f).convert("RGB") for f in pick])
        if rows:
            w, h = rows[0][0].size
            sheet = Image.new("RGB", (16 * w, len(rows) * h + 22), (40, 40, 40))
            d = ImageDraw.Draw(sheet)
            d.text((6, 4), f"ppu {ppu} method C, 16 consecutive frames at 30 fps (0.53 s) per row; rows = the 8 headings of the loop", fill=(255, 255, 255))
            for r, ims in enumerate(rows):
                for c, im in enumerate(ims):
                    sheet.paste(im, (c * w, 22 + r * h))
            sheet.save(os.path.join(OUT, f"live_C_frames_ppu{ppu}.png"), optimize=True)
        print("live", ppu, len(fs), "frames")
    if os.path.isdir(tmp) and "--keep" not in sys.argv:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    strips()
    live()
