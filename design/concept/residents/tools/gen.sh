#!/bin/zsh
# usage: gen.sh <A|B|C> [N]  -> res_<A>[_N].png (N=2 uses variant A2 retake text) via codex built-in image generation
T=${0:A:h}; D=${T:h}; R=${D:h:h:h}
OUT=$D/res_$1${2:+_$2}.png
PROMPT=$(python3 $T/prompts.py $1$2 $OUT)
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $R/design/concept/style-test/flat2_map_a.png -i $R/design/concept/style-test/flat2_map_b.png <<<"$PROMPT" > $T/logs/log_$1$2.txt 2>&1
ls -la $OUT
