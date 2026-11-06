#!/bin/zsh
# usage: gen.sh <sheet_id> <tag>
R=/Users/house_of_4k2b/orca/HELLO-SETTLER
D=$R/design/icons

PY=/private/tmp/claude-501/-Users-house-of-4k2b-orca-HELLO-SETTLER/0e505ef9-4642-45b7-83ba-76508f6942f3/scratchpad/venv/bin/python
OUT=$D/sheets/$1_$2.png
mkdir -p $D/sheets
PROMPT=$($PY $D/tools/prompt.py $D/tools/sheets.json $1 $OUT)
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $R/design/icon/L_2.png <<<"$PROMPT" > $D/tools/log_$1_$2.txt 2>&1
ls -la $OUT
