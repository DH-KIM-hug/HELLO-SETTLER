#!/bin/zsh
# usage: gen.sh <concept|front|q_front|q_back|back> [tag]  -> godot/art/cutout/dog_a/raw/<what>[_tag].png via codex built-in image gen
# concept: -i 1 = raw/ref_woman_A.png (concept-A woman crop: style + scale). Sheets: -i 1 = raw/ref_dog.png (chosen concept),
#          -i 2 = raw/template.png (strict layout, sheet_layout.py).
T=${0:A:h}; G=${T:h:h}
D=$G/art/cutout/dog_a/raw
OUT=$D/$1${2:+_$2}.png
PROMPT=$(python3 $T/prompts.py $1 $OUT)
if [[ $1 == concept ]]; then
  codex exec --skip-git-repo-check -C $D -s workspace-write - -i $D/ref_woman_A.png <<<"$PROMPT" > $T/logs/log_$1${2:+_$2}.txt 2>&1
else
  codex exec --skip-git-repo-check -C $D -s workspace-write - -i $D/ref_dog.png -i $D/template.png <<<"$PROMPT" > $T/logs/log_$1${2:+_$2}.txt 2>&1
fi
ls -la $OUT
