#!/bin/zsh
# usage: gen.sh <sheet> [take]  -> ../<sheet>[_take].png via codex built-in image generation (Q22, 2026-11-12)
# refs (-i): design/concept/residents/res_A.png (style master) + tools/ref_ingame.png (in-game crop of method-C woman)
T=${0:A:h}; D=${T:h}; R=${D:h:h:h:h}
OUT=$D/$1${2:+_$2}.png
PROMPT=$(python3 $T/prompts.py $1 $OUT)
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $R/design/concept/residents/res_A.png -i $T/ref_ingame.png <<<"$PROMPT" > $T/logs/log_$1${2:+_$2}.txt 2>&1
ls -la $OUT
