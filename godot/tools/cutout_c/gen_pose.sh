#!/bin/zsh
# usage: gen_pose.sh <walk|carry> <view> [tag]  — v4: pose reference sheet (pose_ref.py) as the 3rd image
T=${0:A:h}; G=${T:h:h}
D=$G/art/cutout/woman_c/raw
OUT=$D/$1_$2${3:+_$3}.png
mkdir -p $T/logs
PROMPT=$(python3 $T/prompts.py pose $1 $2 $OUT)
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $D/ref_woman_A.png -i $D/ref_inset_woman.png -i $D/pose_$1_$2.png <<<"$PROMPT" > $T/logs/log_pose_$1_$2${3:+_$3}.txt 2>&1
ls -la $OUT
