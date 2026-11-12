"""Q22 man body: install the best take of each sheet (check_man.py), whole cells only — like pick_pose.py for the woman.
usage: python3 pick_man.py [sheet ...]   -> for every sheet with takes man_c/raw/<sheet>_<tag>.png: the take with the most passing
  cells is the base; a cell that fails there is replaced by the WHOLE cell of another take that passes it (unscaled, unmoved: every
  take is a redraw of the same woman's sheet, same cell layout). No part of a drawing is ever cut, moved or pasted.
  Writes man_c/raw/<sheet>.png and prints which take each cell came from; cells that pass in no take are listed."""
import glob, os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import check_man as M   # noqa: E402
import man_prompts as MP   # noqa: E402

CW, CH = M.CW, M.CH


def pick(sheet, quiet=False):
    # takes are tagged with one or two letters (gen_man.sh <sheet> a|b|...); other names (sit_q_front vs sit_q_front_x...) are not takes
    takes = sorted(t for t in glob.glob(os.path.join(M.MRAW, f"{sheet}_*.png")) if os.path.basename(t)[len(sheet) + 1:-4].isalpha() and len(os.path.basename(t)[len(sheet) + 1:-4]) <= 2)
    if not takes:
        return None
    res = {t: M.score(sheet, t) for t in takes}
    base = max(takes, key=lambda t: res[t][0])
    im = Image.open(base).convert("RGB").resize((4 * CW, 2 * CH))
    used, bad = [], []
    for f in range(8):
        if res[base][2][f]:
            used.append(os.path.basename(base)[len(sheet) + 1:-4])
            continue
        donors = [t for t in takes if res[t][2][f]]
        if not donors:
            used.append("XX")
            bad.append(f + 1)
            continue
        t = donors[0]
        src = Image.open(t).convert("RGB").resize((4 * CW, 2 * CH))
        x0, y0 = (f % 4) * CW, (f // 4) * CH
        im.paste(src.crop((x0, y0, x0 + CW, y0 + CH)), (x0, y0))
        used.append(os.path.basename(t)[len(sheet) + 1:-4])
    out = os.path.join(M.MRAW, f"{sheet}.png")
    im.save(out)
    n, lines, _ = M.score(sheet, out)
    if not quiet:
        print(f"{sheet}: takes {[os.path.basename(t)[len(sheet) + 1:-4] + ':' + str(res[t][0]) for t in takes]} -> cells {used} -> {n}/8")
        for ln in lines:
            if "FAIL" in ln:
                print("  " + ln)
    return n, used, bad


if __name__ == "__main__":
    for s in (sys.argv[1:] or sorted(MP.SHEETS)):
        pick(s)
