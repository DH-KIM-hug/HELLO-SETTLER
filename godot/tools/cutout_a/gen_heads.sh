#!/bin/zsh
# usage: gen_heads.sh <job> [take]  — Q22 step 4 head variants (heads.py JOBS): the set's 4 head pieces redrawn with ONE change
# (hair texture / thinning / ring / beard) by codex built-in image gen. -i 1 = the sheet of the original pieces (raw/heads/in_<set>.png),
# -i 2 = (curly / beard jobs) the reference set's sheet. Writes raw/heads/<job>[_take].png, log logs/log_heads_<job>[_take].txt
T=${0:A:h}; G=${T:h:h}
D=$G/art/cutout/woman_a/raw/heads
mkdir -p $D $T/logs
OUT=$D/$1${2:+_$2}.png
SET=${1%%_*}
[[ -f $D/in_$SET.png ]] || python3 $T/heads.py sheet
REF=$(python3 $T/heads.py ref $1)
PROMPT=$(python3 $T/heads.py prompt $1 $OUT)
if [[ -n $REF ]]; then
  codex exec --skip-git-repo-check -C $D -s workspace-write - -i $D/in_$SET.png -i $REF <<<"$PROMPT" > $T/logs/log_heads_$1${2:+_$2}.txt 2>&1
else
  codex exec --skip-git-repo-check -C $D -s workspace-write - -i $D/in_$SET.png <<<"$PROMPT" > $T/logs/log_heads_$1${2:+_$2}.txt 2>&1
fi
ls -la $OUT
