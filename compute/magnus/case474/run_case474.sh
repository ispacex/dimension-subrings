#!/bin/bash
# MATH-474 (wiki 891 Sec. 21): gamma_4 = C_{3^k}, k >= 4 -- (T0) for every k, (T1) at k = 4 (and evidence at k = 5).
# Usage: run_case474.sh [PAR]
#  1. diag: Claim D (Prop. 21.1) on random diagonal chains, S = 3, 4, 5, k = 4..7, with the term-by-term check;
#     controls without (D2) (must fail), without (B), (Kt), (Ko) (reported).
#  2. blocks k = 4: all configurations of <= 3 blocks (>= 1 pair, kinds of Lemma 21.3, both signs) on all capped
#     (cut 81) types of length 2, 3 with (T1); controls without (D2), (Kt) at S = 3 (must fail).  A direct check in
#     the full model mod 81; the proof for every k uses the mixed model (run_case474b.sh, all lengths 2..6).
#  3. orbits: all elementary chains, capped types of length 3, k = 3 (consistency with case471) and k = 4:
#     for A with (T1) every orbit has a member block diagonal at all levels; control: A without (T1).
# Durable copy of the output: $JOB_CACHE/m474/<commit-ish>.  Exit status 0 iff every claim holds and controls fail.
set -uo pipefail
PAR=${1:-4}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out474}; mkdir -p "$OUT"
st=0; T=t474.py
alltypes() { python3 -c "
import sys; sys.path.insert(0, '../case467')
from diag467 import capped_types_k
for d in capped_types_k($1, $2): print(','.join(map(str, d)))"; }
{ for S in 3 4 5; do for k in 4 5 6 7; do for seed in 1 2; do echo "diag $S $k 100 $seed"; done; done; done; } > "$OUT/diag.args"
{ for D in D2 B Kt Ko; do for k in 4 5; do echo "diag 3 $k 200 7 $D"; echo "diag 4 $k 100 8 $D"; done; done; } > "$OUT/diagctl.args"
NP=24
{ for S in 2 3; do for p in $(seq 0 $((NP - 1))); do echo "blocks $S 4 $p $NP"; done; done; } > "$OUT/blocks.args"
{ for S in 3; do for p in $(seq 0 $((NP - 1))); do echo "blocks $S 4 $p $NP D2"; echo "blocks $S 4 $p $NP Kt"; done; done; } > "$OUT/ctl.args"
{ alltypes 3 3 | sed 's/$/ 3/'; alltypes 3 4 | sed 's/$/ 4/'; } | sed 's/^/orbits /' > "$OUT/orb.args"
for f in diag diagctl blocks ctl orb; do
  xargs -P "$PAR" -L 1 python3 $T < "$OUT/$f.args" > "$OUT/$f.txt" 2>&1
  echo "$f done" > "$JOB_ROOT/progress" 2>/dev/null || true
done

echo "== 1. diag (Claim D)"
n=$(wc -l < "$OUT/diag.args"); ok=$(grep -c '^DIAG' "$OUT/diag.txt")
f=$(awk '$1=="DIAG"{f+=$(NF-2)+$NF} END{print f+0}' "$OUT/diag.txt")
c=$(awk '$1=="DIAG"{c+=$7; z+=$13} END{print c+0, "sigma!=0", z+0}' "$OUT/diag.txt")
echo "lines $ok of $n, chains $c, FAILING (incl. termwise) $f"
[ "$ok" -eq "$n" ] && [ "$f" -eq 0 ] || st=1
for D in D2 B Kt Ko; do
  c=$(awk -v D="['$D']" '$1=="DIAG" && $11==D {f+=$(NF-2)} END{print f+0}' "$OUT/diagctl.txt")
  echo "control without $D: failing chains $c"
  [ "$D" != D2 ] || [ "$c" -gt 0 ] || st=1
done
echo "== 2. blocks (T1)"
for k in 4; do for S in 2 3; do
  awk -v S=$S -v k=$k '$1=="T1BLOCKSK" && $3==S && $5==k && $11=="[]" {t+=$13; c+=$15; f+=$17; n++} END{if(n) printf "k=%d S=%d lines %d types %d configs %d FAILING %d\n", k, S, n, t, c, f}' "$OUT/blocks.txt"
done; done
n=$(wc -l < "$OUT/blocks.args"); ok=$(grep -c '^T1BLOCKSK' "$OUT/blocks.txt")
f=$(awk '$1=="T1BLOCKSK"{f+=$NF} END{print f+0}' "$OUT/blocks.txt")
echo "lines $ok of $n, FAILING $f"
[ "$ok" -eq "$n" ] && [ "$f" -eq 0 ] || st=1
for D in D2 Kt; do for S in 3; do
  c=$(awk -v S=$S -v D="['$D']" '$1=="T1BLOCKSK" && $3==S && $11==D {f+=$NF} END{print f+0}' "$OUT/ctl.txt")
  echo "control without $D, k=4, S=$S: failing $c (must be > 0)"; [ "$c" -gt 0 ] || st=1
done; done
nc=$(wc -l < "$OUT/ctl.args"); okc=$(grep -c '^T1BLOCKSK' "$OUT/ctl.txt"); [ "$okc" -eq "$nc" ] || st=1
echo "== 3. orbits"
for k in 3 4; do
  awk -v k=$k '$1=="T1ORBK" && $3==k {for(i=1;i<=NF;i++){if($i=="orbits"&&!o){t+=$(i+1);o=1} if($i=="there")b+=$(i+1)} c+=$NF; n++; o=0} END{printf "k=%d types %d orbits %d (T1) orbits without block member %d control %d\n", k, n, t, b, c}' "$OUT/orb.txt"
done
n=$(wc -l < "$OUT/orb.args"); ok=$(grep -c '^T1ORBK' "$OUT/orb.txt")
bad=$(awk '/^T1ORBK/{for(i=1;i<=NF;i++) if($i=="there") s+=$(i+1)} END{print s+0}' "$OUT/orb.txt")
c=$(awk '/^T1ORBK/ && $3==4 {s+=$NF} END{print s+0}' "$OUT/orb.txt")
echo "lines $ok of $n, (T1) orbits without a block member $bad (must be 0), control k=4 $c (must be > 0)"
[ "$ok" -eq "$n" ] && [ "$bad" -eq 0 ] && [ "$c" -gt 0 ] || st=1
echo "overall ok=$((1 - st))"
if [ -n "${JOB_CACHE:-}" ]; then D=$JOB_CACHE/m474/$(date +%Y%m%d-%H%M%S); mkdir -p "$D" && cp "$OUT"/*.txt "$OUT"/*.args "$D"/ && echo "copied to $D"; fi
exit $st
