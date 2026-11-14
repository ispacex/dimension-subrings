#!/bin/bash
# MATH-469 (wiki 891 Sec. 14): evidence for s = 5..8 -- random realizable chains (random t, z in a random Z/9-module),
# modulo-27 model, types with gamma_4 = C_27 outside Theorem 12.6.  Controls without (D2) must fail.
set -uo pipefail
PAR=${1:-4}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/outrand}; mkdir -p "$OUT/r"
{ for seed in 1 2 3 4 5 6 7 8; do echo "5 25000 $seed"; done
  for seed in 11 12 13 14 15 16 17 18; do echo "6 12000 $seed"; done
  for seed in 21 22 23 24; do echo "7 6000 $seed"; done
  for seed in 31 32 33 34; do echo "8 2500 $seed"; done; } > "$OUT/jobs.txt"
xargs -P "$PAR" -L1 sh -c 'python3 chain469.py rand $0 $1 $2 > "'"$OUT"'/r/$0_$2.txt" 2>&1' < "$OUT/jobs.txt"
cat "$OUT"/r/*.txt | grep '^RAND' | tee "$OUT/rand.txt"
st=0
[ "$(wc -l < "$OUT/rand.txt")" -eq 24 ] && ! grep -vq 'FAILING 0 \[\]$' "$OUT/rand.txt" || st=1
for S in 5 6 7 8; do python3 chain469.py rand $S 1000 99 D2 | cut -c1-200; done | tee "$OUT/rand_controls.txt"
[ "$(grep -c 'FAILING 0 ' "$OUT/rand_controls.txt")" -eq 0 ] || st=1
echo "overall status $st"; exit $st
