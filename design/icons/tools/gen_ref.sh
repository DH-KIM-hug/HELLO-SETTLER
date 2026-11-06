#!/bin/zsh
# usage: gen_ref.sh <sheet_id> <tag>  — like gen.sh, plus the sheet's extra_ref image (3 existing icons) as a second reference
R=/Users/house_of_4k2b/orca/HELLO-SETTLER
D=$R/design/icons
PY=/private/tmp/claude-501/-Users-house-of-4k2b-orca-HELLO-SETTLER/0e505ef9-4642-45b7-83ba-76508f6942f3/scratchpad/venv/bin/python
OUT=$D/sheets/$1_$2.png
mkdir -p $D/sheets
REF=$($PY -c "import json,sys;d=json.load(open('$D/tools/sheets.json'));print([s for s in d['sheets'] if s['id']=='$1'][0]['extra_ref'])")
NOTE=$($PY -c "import json,sys;d=json.load(open('$D/tools/sheets.json'));print([s for s in d['sheets'] if s['id']=='$1'][0].get('ref_note',''))")
PROMPT=$($PY $D/tools/prompt.py $D/tools/sheets.json $1 $OUT)
PROMPT="$PROMPT
$NOTE"
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $R/design/icon/L_2.png -i $R/$REF <<<"$PROMPT" > $D/tools/log_$1_$2.txt 2>&1
ls -la $OUT
