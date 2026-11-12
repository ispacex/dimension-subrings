#!/bin/bash
# Negative controls of the universal model: drop one relation group at a time, all capped types with S generators.
# Usage (tm job, tree root): bash compute/magnus/case450/run_universal_controls.sh S [PAR]
set -uo pipefail
S=${1:-3}; PAR=${2:-2}; BASE=${JOB_OUT:-$PWD/out-controls}
for dr in A B D1 D2 Kt Ko J C; do
  JOB_OUT=$BASE/drop_$dr bash "$(dirname "$0")/run_universal.sh" "$S" "$PAR" "$dr" > /dev/null 2>&1
  f=$BASE/drop_$dr/summary.txt
  nt=$(grep -c '^TYPE' "$f"); nf=$(grep -c -E 'FAILING=[1-9]' "$f")
  nc=$(grep -o 'FAILING=[0-9]*' "$f" | cut -d= -f2 | awk '{s+=$1} END {print s+0}')
  echo "== drop $dr: types with a failure $nf/$nt, failing (A, K_9) cases $nc"
done
