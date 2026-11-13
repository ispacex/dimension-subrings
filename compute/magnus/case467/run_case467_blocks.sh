#!/bin/bash
# MATH-467 (wiki 891 Sec. 13): block-diagonal configurations (Lemma 13.2 + Prop. 13.3) for gamma_4^9 = 1, any s.
#  1. BLOCKS: all capped types of length S = 2..6, all (A, K_9) block diagonal with <= 3 blocks (singletons with a
#     diagonal label, pairs {a in A, n in N, d(n) >= 9 d(a)} with K_9 = <(3,-eps),(0,3)>); expected FAILING 0.
#  2. controls: the same with (B), (D1), (D2), (Kt), (J) dropped, S = 3, 4.
#  3. BLOCK2: every orbit of (A, K_9) under the basis changes contains a block-diagonal member (s = 4: 54 types,
#     s = 5: 162 types); expected "without a block member 0".
set -uo pipefail
PAR=${1:-8}
cd "$(dirname "$0")"
. ./env467.sh
OUT=${JOB_OUT:-$PWD/outbl}; mkdir -p "$OUT/b6" "$OUT/o4" "$OUT/o5"
{ for S in 2 3 4 5; do python3 diag467.py blocks $S | tail -1; done; } | tee "$OUT/blocks25.txt"
python3 -c 'from diag467 import capped_types
for d in capped_types(6): print(",".join(map(str, d)))' > "$OUT/types6.txt"
xargs -P "$PAR" -I{} sh -c 'python3 diag467.py blockstype {} > "'"$OUT"'/b6/$(echo {} | tr , _).txt" 2>&1' < "$OUT/types6.txt"
cat "$OUT"/b6/*.txt | grep '^BLOCKST' > "$OUT/blocks6.txt"
python3 -c '
import re,sys
n=c=f=0
for l in open(sys.argv[1]):
    m=re.search(r"configs (\d+) FAILING (\d+)",l); n+=1; c+=int(m[1]); f+=int(m[2])
print("BLOCKS S = 6 types",n,"configs",c,"FAILING",f)' "$OUT/blocks6.txt" | tee -a "$OUT/blocks25.txt"
{ for S in 3 4; do for dr in B D1 D2 Kt J; do python3 diag467.py blocks $S $dr | tail -1; done; done; } | tee "$OUT/controls.txt"
python3 -c 'from diag467 import capped_types
for S in (4, 5):
    for d in capped_types(S): print(",".join(map(str, d)))' > "$OUT/types45.txt"
xargs -P "$PAR" -I{} sh -c 'python3 diag467.py orbits {} > "'"$OUT"'/o5/$(echo {} | tr , _).txt" 2>&1' < "$OUT/types45.txt"
cat "$OUT"/o5/*.txt | grep '^BLOCK2' > "$OUT/block2.txt"
cat "$OUT"/o5/*.txt | grep '^ORBITS' > "$OUT/orbits45.txt"
echo "BLOCK2 types $(wc -l < "$OUT/block2.txt") of $(wc -l < "$OUT/types45.txt"); types with an orbit without a block member: $(grep -vc 'member (Lemma 13.2) 0$' "$OUT/block2.txt"); ORBITS types with failures: $(grep -vc 'FAILING 0$' "$OUT/orbits45.txt")"
# exit 0 iff: exactly the 4 lines S = 2..5 and the S = 6 line, all "FAILING 0"; all 486 S = 6 types reported;
# every type of s = 4, 5 has a BLOCK2 line with 0 orbits without a block member; the D2 and Kt controls fail somewhere
ok=1
[ "$(grep -c '^BLOCKS S = [2-5] drop \[\] .* FAILING 0$' "$OUT/blocks25.txt")" = 4 ] || ok=0
grep -q '^BLOCKS S = 6 types 486 configs [0-9]* FAILING 0$' "$OUT/blocks25.txt" || ok=0
[ "$(wc -l < "$OUT/block2.txt")" = "$(wc -l < "$OUT/types45.txt")" ] || ok=0
[ "$(grep -vc 'member (Lemma 13.2) 0$' "$OUT/block2.txt")" = 0 ] || ok=0
for dr in D2 Kt; do grep "drop \['$dr'\]" "$OUT/controls.txt" | grep -q 'FAILING [1-9]' || ok=0; done
echo "overall ok=$ok"; [ "$ok" = 1 ]
