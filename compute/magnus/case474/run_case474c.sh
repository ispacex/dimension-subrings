#!/bin/bash
# MATH-474 (wiki 891 Sec. 22.4): gamma_4^81 = 1, s = 3 -- ALL chains (A, K_3 >= K_9 >= K_27 >= K_81) with 3K_e <= K_3e,
# elementary or not, on every capped (cut 81) type of length 3 (case467 diag467.py brutek, model mod 81 without (C)).
# Controls: without (D2) and without (Kt) on [9,81,729]-like types (must fail).  Exit 0 iff 0 failures and controls fail.
set -uo pipefail
PAR=${1:-4}
cd "$(dirname "$0")/../case467"
. ./env467.sh
OUT=${JOB_OUT:-$PWD/out474c}; mkdir -p "$OUT"; st=0
python3 -c "
from diag467 import capped_types_k
for d in capped_types_k(3, 4): print('brutek 4 ' + ','.join(map(str, d)))" > "$OUT/brute.args"
printf 'brutek 4 9,81,81 D2\nbrutek 4 9,81,81 Kt\nbrutek 4 27,81,81 D2\nbrutek 4 27,81,81 Kt\n' > "$OUT/ctl.args"
xargs -P "$PAR" -L 1 python3 diag467.py < "$OUT/brute.args" > "$OUT/brute.txt" 2>&1
xargs -P "$PAR" -L 1 python3 diag467.py < "$OUT/ctl.args" > "$OUT/ctl.txt" 2>&1
n=$(wc -l < "$OUT/brute.args"); ok=$(grep -c '^MODK' "$OUT/brute.txt")
f=$(grep '^MODK' "$OUT/brute.txt" | sed 's/.*FAILING: \([0-9]*\).*/\1/' | awk '{s+=$1} END{print s+0}')
c=$(grep '^MODK' "$OUT/brute.txt" | sed 's/.*cases \([0-9]*\).*/\1/' | awk '{s+=$1} END{print s+0}')
u=$(grep '^MODK' "$OUT/brute.txt" | sed 's/.*full order: \([0-9]*\).*/\1/' | awk '{s+=$1} END{print s+0}')
echo "types $ok of $n, chains $c, with sigma of order 81: $u, FAILING $f"
[ "$ok" -eq "$n" ] && [ "$f" -eq 0 ] || st=1
for D in D2 Kt; do
  x=$(grep '^MODK' "$OUT/ctl.txt" | grep "'$D'" | sed 's/.*FAILING: \([0-9]*\).*/\1/' | awk '{s+=$1} END{print s+0}')
  echo "control without $D: failing $x (must be > 0)"; [ "$x" -gt 0 ] || st=1
done
echo "overall ok=$((1 - st))"
if [ -n "${JOB_CACHE:-}" ]; then D=$JOB_CACHE/m474c/$(date +%Y%m%d-%H%M%S); mkdir -p "$D" && cp "$OUT"/*.txt "$OUT"/*.args "$D"/ && echo "copied to $D"; fi
exit $st
