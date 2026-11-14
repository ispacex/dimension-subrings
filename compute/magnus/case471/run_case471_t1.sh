#!/bin/bash
# MATH-471 (wiki 891 Sec. 16): elementary chains mod 27 under (T1) -- block form with pairs {x, y}.
# Usage: run_case471_t1.sh [PAR]
#  1. blocks: all configurations of <= 3 blocks (singletons with diagonal labels, pairs of the three kinds with both
#     signs, at least one pair) on all capped types of length 2..6 satisfying (T1); R = 0 in the model mod 27.
#     Controls: without (D2) and without (Kt) (S = 3, 4) must fail.  With Prop. 13.3 (blocks <= 2) and Lemma 16.4
#     this is the finite check behind Thm 16.5.
#  2. orbits: all elementary chains, every capped type of length 3 and 4 mod 27: for every A with (T1) every orbit
#     under gen_mats (case467) has a member in the block form of Lemma 16.4; for A without (T1) orbits without such a
#     member must occur (control).
# Exit status 0 iff every claim holds and every control fails as it must.
set -uo pipefail
PAR=${1:-4}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out471t1}; mkdir -p "$OUT"
st=0
T=t1471.py
alltypes() { python3 -c "
import sys; sys.path.insert(0, '../case467')
from diag467 import capped_types_k
for d in capped_types_k($1, $2): print(','.join(map(str, d)))"; }
NP=12
{ for S in 2 3 4 5 6; do for p in $(seq 0 $((NP - 1))); do echo "blocks $S $p $NP"; done; done; } > "$OUT/blocks.args"
{ for S in 3 4; do for p in $(seq 0 $((NP - 1))); do echo "blocks $S $p $NP D2"; echo "blocks $S $p $NP Kt"; done; done; } > "$OUT/ctl.args"
{ alltypes 3 3; alltypes 4 3; } | sed 's/^/orbits /' > "$OUT/orb.args"
xargs -P "$PAR" -L 1 python3 $T < "$OUT/blocks.args" > "$OUT/blocks.txt" 2>&1
xargs -P "$PAR" -L 1 python3 $T < "$OUT/ctl.args" > "$OUT/ctl.txt" 2>&1
xargs -P "$PAR" -L 1 python3 $T < "$OUT/orb.args" > "$OUT/orb.txt" 2>&1

echo "== 1. blocks"
for S in 2 3 4 5 6; do
  awk -v S=$S '$1=="T1BLOCKS" && $3==S && $9=="[]" {t+=$11; c+=$13; f+=$15; n++} END{printf "S=%d lines %d types %d configs %d FAILING %d\n", S, n, t, c, f}' "$OUT/blocks.txt"
done
n=$(wc -l < "$OUT/blocks.args"); ok=$(grep -c '^T1BLOCKS' "$OUT/blocks.txt")
f=$(awk '$1=="T1BLOCKS"{f+=$NF} END{print f+0}' "$OUT/blocks.txt")
echo "lines $ok of $n, FAILING $f"
[ "$ok" -eq "$n" ] && [ "$f" -eq 0 ] || st=1
for D in D2 Kt; do for S in 3 4; do
  c=$(awk -v S=$S -v D="['$D']" '$1=="T1BLOCKS" && $3==S && $9==D {f+=$NF} END{print f+0}' "$OUT/ctl.txt")
  echo "control without $D, S=$S: failing $c (must be > 0)"; [ "$c" -gt 0 ] || st=1
done; done
nc=$(wc -l < "$OUT/ctl.args"); okc=$(grep -c '^T1BLOCKS' "$OUT/ctl.txt"); [ "$okc" -eq "$nc" ] || st=1
echo "== 2. orbits"
n=$(wc -l < "$OUT/orb.args"); ok=$(grep -c '^T1ORB' "$OUT/orb.txt")
bad=$(awk '/^T1ORB/{for(i=1;i<=NF;i++) if($i=="there") s+=$(i+1)} END{print s+0}' "$OUT/orb.txt")
c=$(awk '/^T1ORB/{s+=$NF} END{print s+0}' "$OUT/orb.txt")
tot=$(awk '/^T1ORB/{for(i=1;i<=NF;i++) if($i=="orbits"){s+=$(i+1); break}} END{print s+0}' "$OUT/orb.txt")
echo "lines $ok of $n, orbits $tot, (T1) orbits without a block member $bad (must be 0), control $c (must be > 0)"
[ "$ok" -eq "$n" ] && [ "$bad" -eq 0 ] && [ "$c" -gt 0 ] || st=1
echo "overall ok=$((1 - st))"
exit $st
