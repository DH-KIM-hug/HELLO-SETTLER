"""Pick the walk & carry sheets from the generated takes (2026-11-09; v8 2026-11-10: whole cells only).
usage: python3 pick_pose.py            -> for every clip x view with takes raw/<clip>_<view>_p*.png:
  check every take (check_pose.check), keep the take with the most passing frames as the base; a frame that fails in the base is
  replaced by the WHOLE cell of another take that passes it (unscaled, unmoved: every take is traced from the same cell template).
  No part of a drawing is ever cut, moved or pasted.  Writes raw/<clip>_<view>.png and prints the result; frames that pass in no
  take are listed (regenerate those)."""
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
            used = []
            for f in range(8):
                if res[base][f]["ok"]:
                    used.append(os.path.basename(base)[:-4].split("_")[-1])
                    continue
                donors = [t for t in takes if res[t][f]["ok"]]
                if not donors:
                    used.append("XX")
                    bad.append((clip, view, f + 1, res[base][f]["why"]))
                    continue
                t = min(donors, key=lambda t: res[t][f]["err"])
                # v8 (2026-11-10): the WHOLE cell of another take, unscaled and unmoved — every take is traced from the same
                # cell template (same root, same scale), and a cell is a complete drawing as generated (no part compositing)
                src = Image.open(t).convert("RGB").resize((4 * P.CW, 2 * P.CH))
                x0, y0 = cell_box(f)
                im.paste(src.crop((x0, y0, x0 + P.CW, y0 + P.CH)), (x0, y0))
                used.append(os.path.basename(t)[:-4].split("_")[-1])
            out = os.path.join(P.RAW, f"{clip}_{view}.png")
            im.save(out)
            final = K.check(out, clip, view)
            print(f"{clip}_{view}: base {os.path.basename(base)} ({score(base)[0]}/8) frames from {used} -> {sum(r['ok'] for r in final)}/8"
                  + "".join(f"\n    frame {r['frame']}: {r['why']}" for r in final if not r["ok"]))
    for b in bad:
        print("NO PASSING TAKE:", b)


if __name__ == "__main__":
    main()
