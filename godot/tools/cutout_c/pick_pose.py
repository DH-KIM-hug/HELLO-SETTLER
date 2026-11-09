"""Pick / composite the v4 walk & carry sheets from the generated takes (2026-11-09).
usage: python3 pick_pose.py            -> for every clip x view with takes raw/<clip>_<view>_p*.png:
  check every take (check_pose.check), keep the take with the most passing frames as the base; frames that fail in the base are
  replaced by a passing cell from another take (scaled to the base take's soles->chin height, aligned on head x + soles).
  Writes raw/<clip>_<view>.png and prints the result; frames that pass in no take are listed (regenerate those)."""
import glob, os, re, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import check_pose as K   # noqa: E402

P = K.P


def cell_box(f):
    return ((f % 4) * P.CW, (f // 4) * P.CH)


def main():
    bad = []
    for clip in ("walk", "carry"):
        for view in P.VIEWS:
            takes = sorted(glob.glob(os.path.join(P.RAW, f"{clip}_{view}_p*.png")))
            if not takes:
                continue
            res = {t: K.check(t, clip, view) for t in takes}
            score = lambda t: (sum(r["ok"] for r in res[t]), -sum(r.get("err", 1.0) for r in res[t]))
            base = max(takes, key=score)
            im = Image.open(base).convert("RGB").resize((4 * P.CW, 2 * P.CH))
            hb = np.median([r["H"] for r in res[base] if "H" in r])
            used = []
            for f in range(8):
                if res[base][f]["ok"]:
                    used.append(os.path.basename(base)[-6:-4])
                    continue
                donors = [t for t in takes if res[t][f]["ok"]]
                if not donors:
                    used.append("XX")
                    bad.append((clip, view, f + 1, res[base][f]["why"]))
                    continue
                t = min(donors, key=lambda t: res[t][f]["err"])
                ht = np.median([r["H"] for r in res[t] if "H" in r])
                src = Image.open(t).convert("RGB").resize((4 * P.CW, 2 * P.CH))
                x0, y0 = cell_box(f)
                c = src.crop((x0, y0, x0 + P.CW, y0 + P.CH))
                k = hb / ht
                c2 = c.resize((round(P.CW * k), round(P.CH * k)))
                bg = Image.new("RGB", (P.CW, P.CH), (0, 255, 0))
                # keep the ground line: scale about the bottom-centre of the cell's ground line
                gx, gy = P.CW / 2, P.GROUND
                bg.paste(c2, (round(gx - gx * k), round(gy - gy * k)))
                im.paste(bg, (x0, y0))
                used.append(os.path.basename(t)[-6:-4])
            out = os.path.join(P.RAW, f"{clip}_{view}.png")
            im.save(out)
            final = K.check(out, clip, view)
            print(f"{clip}_{view}: base {os.path.basename(base)} ({score(base)[0]}/8) frames from {used} -> {sum(r['ok'] for r in final)}/8"
                  + "".join(f"\n    frame {r['frame']}: {r['why']}" for r in final if not r["ok"]))
    for b in bad:
        print("NO PASSING TAKE:", b)


if __name__ == "__main__":
    main()
