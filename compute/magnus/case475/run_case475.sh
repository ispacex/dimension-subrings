#!/bin/bash
# MATH-475 (wiki 891 Sec. 21): classes 2A1N / 1A2N (and 2A2N) of elementary chains mod 27 beyond (T1).
# Usage: run_case475.sh MODE [PAR] [NPARTS]
#   pilot PAR NPARTS [nostruct]  (a) (skipped with 'nostruct') struct475: block sizes on orbits for every s = 5 signature (all classes) and a fixed set of
#                         s = 6 signatures; claim: max block size == Tits prediction everywhere (MISMATCH 0);
#                     (b) enum475 cat / count for 2A1N, 1A2N, 2A2N;
#                     (c) enum475 run: the sample part 0 of NPARTS for 2A1N and 1A2N (of 20*NPARTS for 2A2N),
#                         FAILING 0;
#                     (d) controls: the same sample without (D2) and without (Kt) must fail somewhere.
# Outputs: $JOB_OUT and a durable copy in $JOB_CACHE/math475/<job dir name>.  Exit status 1 iff a claim fails.
set -uo pipefail
MODE=$1; shift
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out475}; mkdir -p "$OUT"
st=0
persist() { if [ -n "${JOB_CACHE:-}" ] && [ -n "${JOB_ROOT:-}" ]; then D=$JOB_CACHE/math475/$(basename "$JOB_ROOT"); mkdir -p "$D"; cp -r "$OUT"/. "$D"/; echo "copied to $D"; fi; }
if [ "$MODE" = pilot ]; then
  PAR=$1; NP=$2; SKIP=${3:-}
  if [ "$SKIP" != nostruct ]; then
  # (a) structure
  python3 struct475.py sig 5 > "$OUT/sig5.txt"
  awk '/^SIG /{print "orbit", $2, $3}' "$OUT/sig5.txt" > "$OUT/struct.args"
  for x in "3,3,9,9,81,81 0,1,2,3" "3,9,9,81,81,81 0,1,2" "3,3,27,27,81,81 0,1" "3,3,27,81,81,243 0,1" \
           "3,9,81,243,729,2187 0,1,3" "3,9,9,81,243,243 0,1,2" "3,9,27,81,243,729 0,1,2"; do
    echo "orbit $x"; done >> "$OUT/struct.args"
  xargs -P "$PAR" -L 1 python3 struct475.py < "$OUT/struct.args" > "$OUT/struct.txt" 2>&1
  n=$(grep -c '^STRUCT' "$OUT/struct.txt"); want=$(wc -l < "$OUT/struct.args"); mm=$(grep -c 'MISMATCH' "$OUT/struct.txt")
  echo "== struct: lines $n of $want, MISMATCH $mm"
  awk '/^STRUCT/{c=$7; for(i=1;i<=NF;i++) if($i=="maxb") m=$(i+1); k=c" maxb="m; K[k]++} END{for(k in K) print "  ", k, K[k]}' "$OUT/struct.txt" | sort
  grep MISMATCH "$OUT/struct.txt" | head
  [ "$n" -eq "$want" ] && [ "$mm" -eq 0 ] || st=1
  fi
  # (b) catalogue and counts
  for C in 2A1N 1A2N 2A2N; do python3 enum475.py cat $C; python3 enum475.py count $C; done > "$OUT/catcount.txt" 2>&1
  grep -E '^(CAT|CATSUM|COUNTSUM)' "$OUT/catcount.txt"
  # (c) + (d) samples
  for C in 2A1N 1A2N 2A2N; do N2=$NP; [ $C = 2A2N ] && N2=$((NP * 20))
    for D in - D2 Kt; do echo "run $C 0 $N2 $D"; done; done > "$OUT/run.args"   # "-": full model (no trailing blank: xargs -L)
  xargs -P "$PAR" -L 1 python3 enum475.py < "$OUT/run.args" > "$OUT/run.txt" 2>&1
  cat "$OUT/run.txt" | grep -v '^FAIL ' | head -40
  for C in 2A1N 1A2N 2A2N; do
    f=$(awk -v C=$C '/^RUN475/ && $2==C && $8=="[]" {print $NF}' "$OUT/run.txt")
    [ "$f" = 0 ] || { echo "$C sample: FAILING '$f'"; st=1; }
    for D in D2 Kt; do
      c=$(awk -v C=$C -v D="['$D']" '/^RUN475/ && $2==C && $8==D {print $NF}' "$OUT/run.txt")
      echo "control $C without $D: failing ${c:-missing} (must be > 0)"; [ "${c:-0}" -gt 0 ] || st=1
    done
  done
fi
persist
echo "overall ok=$((1-st))"
exit $st
