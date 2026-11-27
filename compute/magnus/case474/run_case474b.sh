#!/bin/bash
# MATH-474 (wiki 891 Sec. 21.3-21.4): the mixed model mod 9 -- elementary chains for every k at once.
# Usage: run_case474b.sh [PAR]
#  1. cross: equivalence "full model mod 3^k" <=> "mixed model mod 9" configuration by configuration:
#     (T1) block configurations S = 2, 3 at k = 3, 4; all elementary chains of every capped type of length 3 at k = 4.
#     Also without (D2) (failures must coincide).  Control: without (Kt) Lemma 15.2 fails and the two must differ.
#  2. mixed: (T1) block configurations on types cut at 9, length 2..6, all level profiles; R = 0.  Controls (D2), (Kt).
#  3. melem: ALL elementary chains, types cut at 9 of length 2, 3, 4, all A, all level profiles; R = 0.
#     Controls (D2), (Kt) at S = 3.
# Durable copy: $JOB_CACHE/m474b/<date>.  Exit 0 iff every claim holds and every control fails.
set -uo pipefail
PAR=${1:-4}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out474b}; mkdir -p "$OUT"
st=0; T=t474.py
alltypes() { python3 -c "
import sys; sys.path.insert(0, '../case467')
from diag467 import capped_types_k
for d in capped_types_k($1, $2): print(','.join(map(str, d)))"; }
{ for k in 3 4; do for S in 2 3; do echo "cross $S $k"; echo "cross $S $k D2"; done; echo "cross 3 $k Kt"; done
  alltypes 3 4 | sed 's/^/crosse /; s/$/ 4/'
  alltypes 3 4 | awk 'NR%5==0' | sed 's/^/crosse /; s/$/ 4 D2/'; } > "$OUT/cross.args"
NP=12
{ for S in 2 3 4 5 6; do for p in $(seq 0 $((NP - 1))); do echo "mixed $S $p $NP"; done; done
  for S in 3 4; do for p in $(seq 0 $((NP - 1))); do echo "mixed $S $p $NP D2"; echo "mixed $S $p $NP Kt"; done; done; } > "$OUT/mixed.args"
NE=54
{ for S in 2 3; do echo "melem $S 0 1"; done; for p in $(seq 0 $((NE - 1))); do echo "melem 4 $p $NE"; done
  echo "melem 3 0 1 D2"; echo "melem 3 0 1 Kt"; } > "$OUT/melem.args"
for f in cross mixed melem; do
  xargs -P "$PAR" -L 1 python3 $T < "$OUT/$f.args" > "$OUT/$f.txt" 2>&1
  echo "$f done" > "$JOB_ROOT/progress" 2>/dev/null || true
done
echo "== 1. cross (full mod 3^k vs mixed mod 9)"
n=$(wc -l < "$OUT/cross.args"); ok=$(grep -c '^CROSS' "$OUT/cross.txt")
dd=$(grep '^CROSS' "$OUT/cross.txt" | grep -v "'Kt'" | awk '{s+=$NF} END{print s+0}')
nn=$(grep '^CROSS' "$OUT/cross.txt" | grep -v "'Kt'" | awk '{for(i=1;i<=NF;i++) if($i=="configs"||$i=="chains") s+=$(i+1)} END{print s+0}')
nf=$(grep '^CROSS' "$OUT/cross.txt" | grep "'D2'" | awk '{for(i=1;i<=NF;i++) if($i=="failing") s+=$(i+1)} END{print s+0}')
kt=$(grep '^CROSS' "$OUT/cross.txt" | grep "'Kt'" | awk '{s+=$NF} END{print s+0}')
echo "lines $ok of $n; compared $nn, DIFFERENT $dd (must be 0); failures without D2 (compared) $nf (must be > 0); without Kt different $kt (must be > 0)"
[ "$ok" -eq "$n" ] && [ "$dd" -eq 0 ] && [ "$nf" -gt 0 ] && [ "$kt" -gt 0 ] || st=1
echo "== 2. mixed (T1) blocks"
for S in 2 3 4 5 6; do awk -v S=$S '$1=="MIXED" && $3==S && $9=="[]" {t+=$11; c+=$13; f+=$15; n++} END{printf "S=%d lines %d types %d configs %d FAILING %d\n", S, n, t, c, f}' "$OUT/mixed.txt"; done
n=$(wc -l < "$OUT/mixed.args"); ok=$(grep -c '^MIXED' "$OUT/mixed.txt")
f=$(awk '$1=="MIXED" && $9=="[]" {f+=$NF} END{print f+0}' "$OUT/mixed.txt")
echo "lines $ok of $n, FAILING $f"; [ "$ok" -eq "$n" ] && [ "$f" -eq 0 ] || st=1
for D in D2 Kt; do c=$(awk -v D="['$D']" '$1=="MIXED" && $9==D {f+=$NF} END{print f+0}' "$OUT/mixed.txt"); echo "control without $D: failing $c (must be > 0)"; [ "$c" -gt 0 ] || st=1; done
echo "== 3. melem (all elementary chains, every k)"
for S in 2 3 4; do awk -v S=$S '$1=="MELEM" && $3==S && $9=="[]" {t+=$11; c+=$13; f+=$15; n++} END{printf "S=%d lines %d types %d chains %d FAILING %d\n", S, n, t, c, f}' "$OUT/melem.txt"; done
n=$(wc -l < "$OUT/melem.args"); ok=$(grep -c '^MELEM' "$OUT/melem.txt")
f=$(awk '$1=="MELEM" && $9=="[]" {f+=$15} END{print f+0}' "$OUT/melem.txt")
echo "lines $ok of $n, FAILING $f"; [ "$ok" -eq "$n" ] && [ "$f" -eq 0 ] || st=1
for D in D2 Kt; do c=$(awk -v D="['$D']" '$1=="MELEM" && $9==D {f+=$15} END{print f+0}' "$OUT/melem.txt"); echo "control without $D: failing $c (must be > 0)"; [ "$c" -gt 0 ] || st=1; done
grep '^MELEM' "$OUT/melem.txt" | awk '$15>0' | head -5
echo "overall ok=$((1 - st))"
if [ -n "${JOB_CACHE:-}" ]; then D=$JOB_CACHE/m474b/$(date +%Y%m%d-%H%M%S); mkdir -p "$D" && cp "$OUT"/*.txt "$OUT"/*.args "$D"/ && echo "copied to $D"; fi
exit $st
