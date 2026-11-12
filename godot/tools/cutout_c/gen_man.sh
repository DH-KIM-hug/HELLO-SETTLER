#!/bin/zsh
# usage: gen_man.sh <sheet> <tag> [extra instruction]   — Q22 adult man body: the woman's finished sheet woman_c/raw/<sheet>.png
#        redrawn whole with the man (man_prompts.py). Writes man_c/raw/<sheet>_<tag>.png, log logs/log_man_<sheet>_<tag>.txt
T=${0:A:h}; G=${T:h:h}
D=$G/art/cutout/man_c/raw
W=$G/art/cutout/woman_c/raw
mkdir -p $T/logs
OUT=$D/$1_$2.png
PROMPT=$(python3 $T/man_prompts.py $1 $OUT "$3")
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $D/ref_man_A.png -i $D/ref_inset_man.png -i $W/$1.png <<<"$PROMPT" > $T/logs/log_man_$1_$2.txt 2>&1
ls -la $OUT
