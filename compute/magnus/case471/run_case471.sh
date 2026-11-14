#!/bin/bash
# MATH-471 (wiki 891 Sec. 16): elementary chains under (T0) -- no a in A, n in N with d(n) >= 9 d(a).
# Usage: run_case471.sh [PAR]
#  1. diag: the diagonal model, all capped types of length 2 and 3, all diagonal labels (superset of the elementary
#     ones), mod 27 and mod 81; controls (the same without (D2) / without (Kt)) must fail.  This is the finite check
#     behind Thm 16.2 (with Prop. 13.3 for diagonal lattices).
#  2. orbits: all elementary chains, s = 3 (every capped type mod 27 and mod 81) and s = 4 (every capped type mod 27),
#     orbits under the group generators gen_mats of case467 (independent of the move set used in the proof):
#     for every A with (T0) every orbit has a diagonal member (Lemma 16.1); for A without (T0) orbits without a
#     diagonal member must occur (control).
#  3. nf: the algorithm of the proof of Lemma 16.1 on random elementary data, s = 4..7 mod 27 and s = 3..5 mod 81,
#     types with an invariant strictly between 3 and 3^k: only legal moves, diagonal result, R = 0 directly in the model
#     on the original chain.  Control: the same algorithm without (T0) leaves non-diagonal results.
# Exit status 0 iff every claim holds and every control fails as it must.
set -uo pipefail
PAR=${1:-4}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out471}; mkdir -p "$OUT"
st=0
D=../case467/diag467.py; T=t0471.py
alltypes() { python3 -c "
import sys; sys.path.insert(0, '../case467')
from diag467 import capped_types_k
for d in capped_types_k($1, $2): print(','.join(map(str, d)))"; }

# 1. diagonal check
{ for k in 3 4; do for S in 2 3; do echo "diagk $k $S"; done; done
  echo "diagk 3 3 D2"; echo "diagk 3 3 Kt"; echo "diagk 4 3 D2"; echo "diagk 4 3 Kt"; } > "$OUT/diag.args"
xargs -P "$PAR" -L 1 python3 $D < "$OUT/diag.args" > "$OUT/diag.txt" 2>&1
# 2. orbits
{ alltypes 3 3 | sed 's/$/ 3/'; alltypes 3 4 | sed 's/$/ 4/'; alltypes 4 3 | sed 's/$/ 3/'; } | sed 's/^/orbits /' > "$OUT/orb.args"
xargs -P "$PAR" -L 1 python3 $T < "$OUT/orb.args" > "$OUT/orb.txt" 2>&1
# 3. normal form on random data
{ echo "nf 4 3 2000 1"; echo "nf 5 3 1000 2"; echo "nf 6 3 400 3"; echo "nf 7 3 150 4";
  echo "nf 3 4 1000 5"; echo "nf 4 4 600 6"; echo "nf 5 4 300 7";
  echo "nf 4 3 500 8 ctl"; echo "nf 6 3 300 9 ctl"; echo "nf 4 4 300 10 ctl"; } > "$OUT/nf.args"
xargs -P "$PAR" -L 1 python3 $T < "$OUT/nf.args" > "$OUT/nf.txt" 2>&1

# ---- verdicts
echo "== 1. diagonal model"
cat "$OUT/diag.txt"
full=$(grep -c "^DIAGK .*drop \[\] .*FAILING 0$" "$OUT/diag.txt")
ctl=$(grep "^DIAGK .*drop \['" "$OUT/diag.txt" | grep -vc "FAILING 0$")
echo "full checks with 0 failures: $full of 4; controls that fail: $ctl of 4"
[ "$full" -eq 4 ] && [ "$ctl" -eq 4 ] || st=1
echo "== 2. orbits"
n=$(wc -l < "$OUT/orb.args"); ok=$(grep -c '^ORB471' "$OUT/orb.txt")
bad=$(awk '/^ORB471/{for(i=1;i<=NF;i++) if($i=="there") s+=$(i+1)} END{print s+0}' "$OUT/orb.txt")
c=$(awk '/^ORB471/{s+=$NF} END{print s+0}' "$OUT/orb.txt")
tot=$(awk '/^ORB471/{for(i=1;i<=NF;i++) if($i=="orbits"){s+=$(i+1); break}} END{print s+0}' "$OUT/orb.txt")
echo "lines $ok of $n, orbits $tot, (T0) orbits without a diagonal member $bad (must be 0), control $c (must be > 0)"
[ "$ok" -eq "$n" ] && [ "$bad" -eq 0 ] && [ "$c" -gt 0 ] || st=1
echo "== 3. normal form, random data"
cat "$OUT/nf.txt"
nn=$(grep -c '^NF S' "$OUT/nf.txt"); bad=$(grep '^NF S' "$OUT/nf.txt" | grep -vc 'illegal_moves 0 non_diagonal 0 .*R_FAILING 0$')
cl=$(grep -c '^NF_CTL' "$OUT/nf.txt"); cz=$(grep '^NF_CTL' "$OUT/nf.txt" | grep -c 'results 0$')
echo "lines $nn of 7, failing $bad; control lines $cl of 3, controls with 0 non-diagonal results $cz (must be 0)"
[ "$nn" -eq 7 ] && [ "$bad" -eq 0 ] && [ "$cl" -eq 3 ] && [ "$cz" -eq 0 ] || st=1
echo "overall ok=$((1 - st))"
exit $st
