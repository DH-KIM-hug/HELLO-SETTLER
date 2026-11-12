#!/bin/zsh
# usage: gen_woman2.sh <sheet> <tag> [extra instruction]   — Q22 step 5, second adult woman outfit (skirt + laced bodice + apron):
#        the woman's finished sheet woman_c/raw/<sheet>.png redrawn whole with only the clothes changed (woman2_prompts.py).
#        Writes woman2_c/raw/<sheet>_<tag>.png, log logs/log_w2_<sheet>_<tag>.txt.  Queue: xargs -P 6 -L 1 gen_woman2.sh < file
T=${0:A:h}; G=${T:h:h}
D=$G/art/cutout/woman2_c/raw
W=$G/art/cutout/woman_c/raw
mkdir -p $T/logs
OUT=$D/$1_$2.png
PROMPT=$(cd $T && python3 $T/woman2_prompts.py $1 $OUT "$3")
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $D/ref_outfit_bodice.png -i $W/$1.png <<<"$PROMPT" > $T/logs/log_w2_$1_$2.txt 2>&1
ls -la $OUT
