#!/bin/zsh
# usage: gen.sh <front|back|q_front|q_back|props> [tag]  -> godot/art/cutout/woman_a/raw/<view>[_tag].png via codex built-in image gen
# reference (-i 1): concept crop of that character (sets e/f/g = man/child/elder of res_A.png, else the woman); props c = elder
T=${0:A:h}; G=${T:h:h}
D=$G/art/cutout/woman_a/raw
OUT=$D/$1${2:+_$2}.png
TPL=$D/template.png
[[ $1 == props ]] && TPL=$D/template_props.png
[[ $1 == props && $2 == c ]] && TPL=$D/template_props_c.png
REF=$D/ref_woman_A.png
case $2 in
  e) REF=$D/ref_man_A.png ;;
  f) REF=$D/ref_child_A.png ;;
  g|c) REF=$D/ref_elder_A.png ;;
esac
PROMPT=$(python3 $T/prompts.py $1 $OUT ${2:-a})
codex exec --skip-git-repo-check -C $D -s workspace-write - -i $REF -i $TPL <<<"$PROMPT" > $T/logs/log_$1${2:+_$2}.txt 2>&1
ls -la $OUT
