#!/bin/bash
# MATH-467 (wiki 891 Sec. 13): orbits of chain configurations modulo 27 and 81 (gamma_4 = C_27, C_81), s = 3.
set -uo pipefail
PAR=${1:-3}
cd "$(dirname "$0")"
. ./env467.sh
OUT=${JOB_OUT:-$PWD/outk}; mkdir -p "$OUT/o27" "$OUT/o81"
# mod 27: orbits for all 48 capped 3-generator types (cross-check of the brute force in run_case467_27.sh)
python3 -c 'from diag467 import capped_types_k
for d in capped_types_k(3, 3): print(",".join(map(str, d)))' > "$OUT/t27.txt"
xargs -P "$PAR" -I{} sh -c 'python3 diag467.py orbitsk 3 {} > "'"$OUT"'/o27/$(echo {} | tr , _).txt" 2>&1' < "$OUT/t27.txt"
cat "$OUT"/o27/*.txt | grep '^ORBITSK' | tee "$OUT/orbits27.txt"
# mod 81: the 3-generator types that can carry gamma_4 = C_81 outside Theorem 12.6: d(1) >= 9, d(2) >= 81 (capped at 81)
python3 -c 'from diag467 import capped_types_k
for d in capped_types_k(3, 4):
    if d[0] >= 9 and d[1] >= 81: print(",".join(map(str, d)))' > "$OUT/t81.txt"
echo "mod-81 types: $(wc -l < "$OUT/t81.txt")"
python3 -c 'from diag467 import *
T = [[int(a) for a in l.split(",")] for l in open("'"$OUT"'/t81.txt")]
diag_k(3, 4, (), T); diag_k(3, 4, ("D2",), T[:6])' | tee "$OUT/diag81.txt"
xargs -P "$PAR" -I{} sh -c 'python3 diag467.py orbitsk 4 {} > "'"$OUT"'/o81/$(echo {} | tr , _).txt" 2>&1' < "$OUT/t81.txt"
cat "$OUT"/o81/*.txt | grep '^ORBITSK' | tee "$OUT/orbits81.txt"
for f in orbits27 orbits81; do echo "$f: types $(wc -l < "$OUT/$f.txt"), with failures $(grep -vc 'FAILING 0$' "$OUT/$f.txt")"; done
