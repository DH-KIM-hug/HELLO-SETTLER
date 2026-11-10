#!/bin/zsh
# usage: gen_empty.sh <carry|hold> <view> <tag>   — v12: the v11 sheet redrawn whole without the sack (arms stay in the
#        shoulder-carry pose; the load is a prop overlay). Third image = raw/ref_sack_<carry|idle>_<view>.png (the v11 sheet:
#        git show 0049163:godot/art/cutout/woman_c/raw/<carry|idle>_<view>.png). Writes raw/<carry|hold>_<view>_<tag>.png
#        gen_empty.sh props <props_a|props_b> <tag>  — the load pictures (no reference image). Writes raw/<sheet>_<tag>.png
T=${0:A:h}; G=${T:h:h}
D=$G/art/cutout/woman_c/raw
mkdir -p $T/logs
if [[ $1 == props ]]; then
  OUT=$D/$2_$3.png
  PROMPT=$(python3 $T/prompts.py props $2 $OUT)
  codex exec --skip-git-repo-check -C $D -s workspace-write - <<<"$PROMPT" > $T/logs/log_$2_$3.txt 2>&1
else
  SRC=carry; [[ $1 == hold ]] && SRC=idle
  OUT=$D/$1_$2_$3.png
  PROMPT=$(python3 $T/prompts.py empty $1 $2 $OUT)
  codex exec --skip-git-repo-check -C $D -s workspace-write - -i $D/ref_woman_A.png -i $D/ref_inset_woman.png -i $D/ref_sack_${SRC}_$2.png <<<"$PROMPT" > $T/logs/log_empty_$1_$2_$3.txt 2>&1
fi
ls -la $OUT
