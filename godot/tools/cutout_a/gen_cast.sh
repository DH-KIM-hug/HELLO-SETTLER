#!/bin/zsh
# 2026-11-08: generate the concept-A cast part sheets (man e, child f, elder g: 4 views each) + props c (cane, seed), in parallel.
# usage: gen_cast.sh [set ...]   (default: e f g props)
T=${0:A:h}
SETS=($@)
(( $#SETS )) || SETS=(e f g props)
for s in $SETS; do
  if [[ $s == props ]]; then
    zsh $T/gen.sh props c &
  else
    for v in front q_front q_back back; do zsh $T/gen.sh $v $s & done
  fi
done
wait
