#!/bin/zsh
# usage: gen.sh <front|back|q_front|q_back|props> [tag]  -> godot/art/cutout/woman_a/raw/<view>[_tag].png via codex built-in image gen
T=${0:A:h}; G=${T:h:h}
D=$G/art/cutout/woman_a/raw
OUT=$D/$1${2:+_$2}.png
TPL=$D/template.png
[[ $1 == props ]] && TPL=$D/template_props.png
PROMPT=$(python3 $T/prompts.py $1 $OUT ${2:-a})
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $D/ref_woman_A.png -i $TPL <<<"$PROMPT" > $T/logs/log_$1${2:+_$2}.txt 2>&1
ls -la $OUT
