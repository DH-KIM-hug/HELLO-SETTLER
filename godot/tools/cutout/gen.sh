#!/bin/zsh
# usage: gen.sh <front|back|q_front|q_back> [tag]  -> godot/art/cutout/woman_b/raw/<view>[_tag].png via codex built-in image gen
T=${0:A:h}; G=${T:h:h}; R=${G:h}
D=$G/art/cutout/woman_b/raw
OUT=$D/$1${2:+_$2}.png
PROMPT=$(python3 $T/prompts.py $1 $OUT)
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $R/design/concept/residents/res_B.png <<<"$PROMPT" > $T/logs/log_$1${2:+_$2}.txt 2>&1
ls -la $OUT
