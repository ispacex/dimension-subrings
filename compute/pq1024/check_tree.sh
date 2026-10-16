#!/bin/sh
# Generator check: tree counts for orders 2^7, 2^8 (all ranks) against SmallGroups.
cd "$(dirname "$0")" || exit 2
mkdir -p out
{ for N in 7 8; do for D in $(seq 2 $((N - 2))); do echo "tree $N $D"; done; done; echo "lib 128 0"; echo "lib 256 0"; } |
xargs -P "${JOBS:-3}" -L 1 sh -c '
  if [ "$0" = tree ]; then f=out/tree_$1_$2.json; [ -s $f ] || ./run_gap.sh tree.g "N:=$1;; D:=$2;; STATFILE:=\"$f\";;" > out/log_tree_$1_$2.txt
  else f=out/lib_$1.json; [ -s $f ] || ./run_gap.sh libcount.g "NN:=$1;; STATFILE:=\"$f\";;" > out/log_lib_$1.txt; fi'
