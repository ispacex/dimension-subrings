#!/bin/bash
# referee checks for Theorem B: bash compute/magnus/run_revB.sh "seeds" NG
export PATH=$JOB_CACHE/bin:$PATH
cd compute/magnus
OUT=${JOB_OUT:-.}
for s in $1; do
  timeout 1500 gap -q -b --quitonbreak -o 6g > "$OUT/revB_$s.log" 2>&1 <<GAPEOF &
SEED:=$s;; NG:=$2;; OUT:="$OUT/revB_$s.last";;
Read("revB.g");
GAPEOF
done
wait
grep -h '^S ' "$OUT"/revB_*.log | tee "$OUT/summary.txt"
grep -h -i -B2 -A5 'error' "$OUT"/revB_*.log | head -40
