#!/bin/zsh
# usage: gen.sh <sheet_id> <tag>   — draws one 3x2 layer sheet on the green-bust guide with codex built-in image generation
P=${0:A:h:h}
C=${P:h}
PY=${PY:-python3}
OUT=$P/sheets/$1_$2.png
PROMPT=$($PY $P/tools/prompts.py $1 $OUT)
codex exec --skip-git-repo-check -C $P -s workspace-write - -i $P/tools/template_3x2.png -i $C/jobs_a.png -i $C/expressions_a.png <<<"$PROMPT" > $P/tools/logs/log_$1_$2.txt 2>&1
ls -la $OUT
