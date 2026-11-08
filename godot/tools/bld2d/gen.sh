#!/bin/zsh
# usage: gen.sh <sheet> [tag]  -> $BLD2D_RAW/<sheet>[_tag].png via codex built-in image gen (prompts.py)
# BLD2D_REF=<png> adds a 4th reference image (e.g. the finished altar for its build stages).
# Raw sheets are big (~1-2 MB) — keep them outside the repo (default: godot/tools/bld2d/raw, git-ignored); key.py cuts them.
T=${0:A:h}; G=${T:h:h}; R=${G:h}
RAW=${${BLD2D_RAW:-$T/raw}:A}     # resolved (codex refuses a symlinked writable root)
mkdir -p $RAW $T/logs && touch $RAW/.gdignore     # never let Godot import the raw sheets
OUT=$RAW/$1${2:+_$2}.png
PROMPT=$(python3 $T/prompts.py $1 $OUT)
codex exec --skip-git-repo-check -C $RAW -s workspace-write - -i $R/design/concept/residents/res_A.png -i $T/refs/ref_buildings.png -i $T/refs/ref_angle.png ${BLD2D_REF:+-i $BLD2D_REF} <<<"$PROMPT" > $T/logs/log_$1${2:+_$2}.txt 2>&1
ls -la $OUT
