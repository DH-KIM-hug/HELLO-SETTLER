#!/bin/zsh
# usage: gen_state.sh <sheet> [tag]  — v11 state sheets (sit_q_front, sit_q_back, pray_front, work_q_front, work_q_back, work_front,
# work_back): pose reference sheet of pose_states.py as the 3rd image, prompt = prompts.py state <sheet>
T=${0:A:h}; G=${T:h:h}
D=$G/art/cutout/woman_c/raw
OUT=$D/$1${2:+_$2}.png
mkdir -p $T/logs
PROMPT=$(python3 $T/prompts.py state $1 $OUT)
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $D/ref_woman_A.png -i $D/ref_inset_woman.png -i $D/pose_$1.png <<<"$PROMPT" > $T/logs/log_state_$1${2:+_$2}.txt 2>&1
ls -la $OUT
