#!/bin/zsh
# usage: gen.sh <sheet> [tag]  -> $FLORA2D_RAW/<sheet>[_tag].png via codex built-in image gen (prompts.py)
# FLORA2D_RAW (required, OUTSIDE the repo — raw sheets are 1-2 MB) also holds ref/sheet_<sheet>.png from compose.py (attached as
# the 3rd image when the sheet has models). Pipeline: sheets.py --json -> ref_render.gd -> compose.py -> gen.sh -> key.py -> pack.py
T=${0:A:h}; G=${T:h:h}; R=${G:h}
RAW=${FLORA2D_RAW:A}
mkdir -p $RAW/logs && touch $RAW/.gdignore
OUT=$RAW/$1${2:+_$2}.png
REF=$RAW/ref/sheet_$1.png
HAS=0
if python3 -c "import sys; sys.path.insert(0, '$T'); from sheets import SHEETS; sys.exit(0 if any(c[1] is not None for c in SHEETS['$1']['cells']) else 1)"; then HAS=1; fi
PROMPT=$(python3 $T/prompts.py $1 $OUT $HAS)
if [[ $HAS == 1 ]]; then
  codex exec --skip-git-repo-check -C $RAW -s workspace-write - -i $R/design/concept/residents/res_A.png -i $G/tools/bld2d/refs/ref_buildings.png -i $REF <<<"$PROMPT" > $RAW/logs/log_$1${2:+_$2}.txt 2>&1
else
  codex exec --skip-git-repo-check -C $RAW -s workspace-write - -i $R/design/concept/residents/res_A.png -i $G/tools/bld2d/refs/ref_buildings.png <<<"$PROMPT" > $RAW/logs/log_$1${2:+_$2}.txt 2>&1
fi
ls -la $OUT
