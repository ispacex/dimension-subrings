#!/bin/bash
# MATH-467 (wiki 891 Sec. 13.4): the universal model modulo 27 (gamma_4^27 = 1), all capped types with s <= 3.
set -uo pipefail
PAR=${1:-8}
cd "$(dirname "$0")"
. ./env467.sh
OUT=${JOB_OUT:-$PWD/out27}; mkdir -p "$OUT/b27"
{ python3 diag467.py diag 2 27 | tail -1; python3 diag467.py diag 3 27 | tail -1
  for dr in B D1 D2 Kt J; do python3 diag467.py diag 3 27 $dr | tail -1; done; } | tee "$OUT/diag27.txt"
python3 -c 'from diag467 import capped_types
for S in (2, 3):
    for d in capped_types(S, 27): print(",".join(map(str, d)))' > "$OUT/types27.txt"
xargs -P "$PAR" -I{} sh -c 'python3 diag467.py brute27 {} > "'"$OUT"'/b27/$(echo {} | tr , _).txt" 2>&1' < "$OUT/types27.txt"
cat "$OUT"/b27/*.txt | grep '^MOD27' | tee "$OUT/brute27.txt"
echo "types: $(wc -l < "$OUT/brute27.txt") of $(wc -l < "$OUT/types27.txt"); with failures: $(grep -vc 'FAILING: 0 ' "$OUT/brute27.txt")"
{ for t in 9,27,27 27,27,27 9,9,27; do for dr in B D1 D2 Kt; do python3 diag467.py brute27 $t $dr; done; done; } | tee "$OUT/controls27.txt"
# exit status: 0 iff all 60 types pass and every negative control fails somewhere (controls are expected to fail)
nmain=$(grep -vc 'FAILING: 0 ' "$OUT/brute27.txt"); nctl0=$(grep -c 'FAILING: 0 ' "$OUT/controls27.txt")
echo "main types with failures: $nmain; controls that did NOT fail: $nctl0"
[ "$nmain" = 0 ] && [ "$nctl0" = 0 ] && [ "$(wc -l < "$OUT/brute27.txt")" = "$(wc -l < "$OUT/types27.txt")" ]
