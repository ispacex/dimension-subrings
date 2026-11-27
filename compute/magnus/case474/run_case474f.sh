#!/bin/bash
# MATH-474 (wiki 891 Sec. 23.9): s = 5, finite-type posets P ⊔ C_{t-1} -- root catalogue and <= 3-summand check.
# Usage: run_case474f.sh MODE [PAR] [NPARTS]
#   pilot: catalog 5; count 4 4 (all s = 4 signatures); count 5 2 in NPARTS parts, part 0 only; check 5 part 0 of
#          NPARTS; controls (D2), (Kt) on check 5 part 0 of NPARTS -- with timings (estimate of the full run)
#   full:  count 5 2 (all parts); check 5, all NPARTS parts; controls on part 0.
# Claims (exit 1 if one fails): no missing roots; orbit counts == root-multiset counts (MISMATCH 0); FAILING 0;
# both controls fail somewhere.  Durable copy: $JOB_CACHE/m474f/<date>.
set -uo pipefail
MODE=${1:-pilot}; PAR=${2:-4}; NP=${3:-40}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out474f}; mkdir -p "$OUT"; st=0
F=fin474.py
t0=$SECONDS; python3 $F catalog 5 > "$OUT/catalog.txt" 2>&1; echo "TIME $((SECONDS - t0)) s: catalog 5" >> "$OUT/catalog.txt"; cat "$OUT/catalog.txt"
grep -q "roots without a spanned End=1 representative 0 " "$OUT/catalog.txt" || { echo "catalog: missing roots"; st=1; }
if [ "$MODE" = pilot ]; then
  { echo "count 4 4 1000000000 0 2"; echo "count 4 4 1000000000 1 2"; echo "count 5 2 1000000000 0 $NP"; } > "$OUT/count.args"
  { echo "check 5 0 $NP"; echo "check 5 0 $NP D2"; echo "check 5 0 $NP Kt"; } > "$OUT/check.args"
else
  { for p in $(seq 0 $((NP - 1))); do echo "count 5 2 1000000000 $p $NP"; done; } > "$OUT/count.args"
  { for p in $(seq 0 $((NP - 1))); do echo "check 5 $p $NP"; done; echo "check 5 0 $NP D2"; echo "check 5 0 $NP Kt"; } > "$OUT/check.args"
fi
run() { local t0=$SECONDS; python3 $F "$@"; local rc=$?; echo "TIME $((SECONDS - t0)) s: $*"; return $rc; }
export -f run; export F
xargs -P "$PAR" -L 1 bash -c 'run "$@"' _ < "$OUT/count.args" > "$OUT/count.txt" 2>&1; rc1=$?
xargs -P "$PAR" -L 1 bash -c 'run "$@"' _ < "$OUT/check.args" > "$OUT/check.txt" 2>&1; rc2=$?
cat "$OUT/count.txt" "$OUT/check.txt"
nc=$(grep -c "^COUNT" "$OUT/count.txt"); nl=$(wc -l < "$OUT/count.args")
mm=$(grep "^COUNT" "$OUT/count.txt" | sed 's/.*MISMATCH \([0-9]*\).*/\1/' | awk '{s+=$1} END{print s+0}')
echo "count: $nc of $nl lines, MISMATCH $mm"; [ "$nc" -eq "$nl" ] && [ "$mm" -eq 0 ] || st=1
nk=$(grep -c "^FINCHECK.*drop \[\] " "$OUT/check.txt"); nkl=$(grep -c -v " D2$\| Kt$" "$OUT/check.args")
fk=$(grep "^FINCHECK.*drop \[\] " "$OUT/check.txt" | sed 's/.*FAILING \([0-9]*\).*/\1/' | awk '{s+=$1} END{print s+0}')
ck=$(grep "^FINCHECK.*drop \[\] " "$OUT/check.txt" | sed 's/.*configurations \([0-9]*\).*/\1/' | awk '{s+=$1} END{print s+0}')
ms=$(grep "^FINCHECK.*drop \[\] " "$OUT/check.txt" | sed 's/.*missing roots \([0-9]*\).*/\1/' | awk '{s+=$1} END{print s+0}')
np5=$(grep "^FINCHECK.*drop \[\] " "$OUT/check.txt" | sed 's/.*finite (d,A) \([0-9]*\).*/\1/' | awk '{s+=$1} END{print s+0}')
echo "check: $nk of $nkl parts, finite pairs $np5, configurations $ck, missing roots $ms, FAILING $fk"
[ "$nk" -eq "$nkl" ] && [ "$fk" -eq 0 ] && [ "$ms" -eq 0 ] || st=1
grep -q "finite (d,A) 1324 " "$OUT/catalog.txt" || { echo "catalog: not 1324 finite pairs"; st=1; }
[ "$MODE" = pilot ] || [ "$np5" -eq 1324 ] || { echo "check parts do not cover the 1324 finite pairs"; st=1; }
for D in D2 Kt; do
  x=$(grep "^FINCHECK.*'$D'" "$OUT/check.txt" | sed 's/.*FAILING \([0-9]*\).*/\1/'); x=${x:-0}
  echo "control without $D: failing $x (must be > 0)"; [ "$x" -gt 0 ] || st=1
done
[ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ] || { echo "xargs rc $rc1 $rc2"; st=1; }
echo "overall ok=$((1 - st))"
if [ -n "${JOB_CACHE:-}" ]; then D=$JOB_CACHE/m474f/$(date +%Y%m%d-%H%M%S); mkdir -p "$D" && cp "$OUT"/*.txt "$OUT"/*.args "$D"/ && echo "copied to $D"; fi
exit $st
