#!/bin/zsh
# usage: gen_redraw.sh <sheet> <tag>   — v13: a finished sheet redrawn whole with ONE change (prompts.py REDRAW_SHEETS):
#        cradle_<view> (from carry_<view>), cradle_hold_<view> (from hold_<view>), hold_back (from hold_back).
#        Third image = raw/<reference sheet>.png. Writes raw/<sheet>_<tag>.png, log logs/log_redraw_<sheet>_<tag>.txt
T=${0:A:h}; G=${T:h:h}
D=$G/art/cutout/woman_c/raw
mkdir -p $T/logs
REF=$(python3 $T/prompts.py redraw_ref $1)
OUT=$D/$1_$2.png
PROMPT=$(python3 $T/prompts.py redraw $1 $OUT)
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $D/ref_woman_A.png -i $D/ref_inset_woman.png -i $D/$REF.png <<<"$PROMPT" > $T/logs/log_redraw_$1_$2.txt 2>&1
ls -la $OUT
