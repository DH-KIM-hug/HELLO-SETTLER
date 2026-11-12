#!/bin/zsh
# usage: gen_man_queue.sh <queue file> [parallel=6]   — Q22: runs gen_man.sh for every "<sheet> <tag>" line, N at a time
T=${0:A:h}
xargs -P ${2:-6} -L 1 $T/gen_man.sh < $1
