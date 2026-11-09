#!/bin/zsh
# usage: gen.sh <walk|carry|idle> <front|q_front|q_back|back> [tag]
#   -> godot/art/cutout/woman_c/raw/<clip>_<view>[_tag].png via codex built-in image gen (method-C frame sheet spike)
T=${0:A:h}; G=${T:h:h}
D=$G/art/cutout/woman_c/raw
OUT=$D/$1_$2${3:+_$3}.png
mkdir -p $T/logs
PROMPT=$(python3 $T/prompts.py $1 $2 $OUT)
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $D/ref_woman_A.png -i $D/ref_inset_woman.png -i $D/template.png <<<"$PROMPT" > $T/logs/log_$1_$2${3:+_$3}.txt 2>&1
ls -la $OUT
