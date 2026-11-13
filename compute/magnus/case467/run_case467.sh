#!/bin/bash
# MATH-467 (wiki 891 Sec. 13): diagonal labellings, orbits of (A, K_9), s = 5.
# Usage (tm job, tree root): bash compute/magnus/case467/run_case467.sh [PAR]
set -uo pipefail
PAR=${1:-8}
cd "$(dirname "$0")"
OUT=${JOB_OUT:-$PWD/out}; mkdir -p "$OUT/orb5"
python3 -c 'import numpy; print("numpy", numpy.__version__)'
# 1. the Python model against universal.sage (reference numbers, wiki 891 Sec. 11.4 / case450)
{ for t in 9,9,9 3,9,9; do python3 diag467.py validate $t; for dr in B D2 D1 Kt; do python3 diag467.py validate $t $dr; done; done; } \
  | tee "$OUT/validate.txt"
# 2. diagonal labellings: s = 2..5 (s <= 3 is what the decomposition lemma needs; 4, 5 cross-check it) + controls
{ for S in 2 3 4 5; do python3 diag467.py diag $S | tail -1; done
  for dr in B D1 D2 Kt J; do python3 diag467.py diag 3 9 $dr | tail -1; done; } | tee "$OUT/diag.txt"
# 3a. orbits for all 54 capped types with s = 4 (cross-check with the full enumeration of case450)
python3 -c 'from diag467 import *
tot = 0
for d in capped_types(4): tot += orbits(d, verbose=True)
print("TOTAL s=4 FAILING", tot)' | tee "$OUT/orbits4.txt"
# 3. orbits of (A, K_9) under Stab_Gamma(K_3), all 162 capped types with s = 5
python3 -c 'from diag467 import capped_types
for d in capped_types(5): print(",".join(map(str, d)))' > "$OUT/types5.txt"
echo 0 > "$JOB_ROOT/progress" 2>/dev/null || true
xargs -P "$PAR" -I{} sh -c 'python3 diag467.py orbits {} > "'"$OUT"'/orb5/$(echo {} | tr , _).txt" 2>&1; echo {} >> "'"$OUT"'/done5.txt"; n=$(wc -l < "'"$OUT"'/done5.txt"); echo "$n/162" > "${JOB_ROOT:-/tmp}/progress"' \
  < "$OUT/types5.txt"
cat "$OUT"/orb5/*.txt | grep '^ORBITS' > "$OUT/orbits5.txt"
echo "types: $(wc -l < "$OUT/orbits5.txt") of 162"
python3 -c '
import re,sys
o=nd=c=f=0
for l in open(sys.argv[1]):
    m=re.search(r"orbits (\d+) without diagonal member (\d+) checked directly (\d+) FAILING (\d+)",l)
    o+=int(m[1]);nd+=int(m[2]);c+=int(m[3]);f+=int(m[4])
print("TOTAL s=5: orbits",o,"without diagonal member",nd,"checked directly",c,"FAILING",f)' "$OUT/orbits5.txt" | tee "$OUT/total5.txt"
grep -h FAIL "$OUT"/orb5/*.txt | grep -v 'FAILING 0' | head -20
# 4. brute force over ALL (A, K_9) for two 5-generator types (cross-check of the orbit reduction)
for t in 9,9,9,9,9 3,3,9,9,9; do python3 diag467.py validate $t; done | tee "$OUT/brute5.txt"
