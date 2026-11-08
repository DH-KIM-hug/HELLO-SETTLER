"""Key every sheet (key.py) from the raw folder: for each sheet the CHOSEN take (raw/<sheet>_<tag>.png), else the newest
raw/<sheet>[_*].png. usage: cut_all.py [raw_dir] [cut_dir] [sheet ...]"""
import subprocess
import sys
from pathlib import Path

T = Path(__file__).parent
sys.path.insert(0, str(T))
from prompts import SHEETS  # noqa: E402

CHOSEN: dict = {}     # sheet -> tag ("" = the first take) when the newest take is not the best one

raw = Path(sys.argv[1]) if len(sys.argv) > 1 else T / "raw"
cut = Path(sys.argv[2]) if len(sys.argv) > 2 else raw / "cut"
only = sys.argv[3:]
for sheet in SHEETS:
    if only and sheet not in only:
        continue
    if sheet in CHOSEN:
        src = raw / (f"{sheet}_{CHOSEN[sheet]}.png" if CHOSEN[sheet] else f"{sheet}.png")
    else:
        takes = [p for p in raw.glob(f"{sheet}*.png") if p.stem == sheet or (p.stem.startswith(sheet + "_") and
                 p.stem[len(sheet) + 1:].isalpha() and len(p.stem[len(sheet) + 1:]) <= 2)]
        if not takes:
            print("no raw for", sheet)
            continue
        src = max(takes, key=lambda p: p.stat().st_mtime)
    r = subprocess.run([sys.executable, str(T / "key.py"), str(src), sheet, str(cut)], capture_output=True, text=True)
    print(sheet, "<-", src.name, "OK" if r.returncode == 0 else "FAIL\n" + r.stderr[-400:])
