#!/bin/bash
# MATH-480 (wiki 891 Sec. 19).  Usage: run_case480.sh MODE [PAR]
#   explore PAR   exp480.py 'test' on every capped type of length 3 without 9 (all A, all non-elementary K)
# Progress: $JOB_ROOT/progress.  Exit status 1 iff the base check R(L(K),S(K)) = 0 fails somewhere or a line is missing.
set -uo pipefail
MODE=$1; PAR=${2:-4}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out480}; mkdir -p "$OUT"
PROG=${JOB_ROOT:-$OUT}/progress
st=0
git -C .. rev-parse HEAD 2>/dev/null || true
if [ "$MODE" = explore ]; then
  python3 ../case472/nonel472.py types 3 | awk '{print "test " $0}' > "$OUT/x.args"
  NA=$(wc -l < "$OUT/x.args"); echo "0/$NA" > "$PROG"
  ( while :; do n=$(grep -c '^EXP480 ' "$OUT/x.txt" 2>/dev/null); echo "$(( ${n:-0} / 8 ))/$NA" > "$PROG"; sleep 30; done ) & PP=$!
  xargs -P "$PAR" -L 1 python3 exp480.py < "$OUT/x.args" > "$OUT/x.txt" 2>&1
  kill $PP 2>/dev/null
  n=$(grep -c '^EXP480 ' "$OUT/x.txt")
  awk '/^EXP480 /{for(i=1;i<=NF;i++){if($i=="n")N+=$(i+1); if($i=="base")B+=$(i+1); if($i=="a")a+=$(i+1); if($i=="a2")a2+=$(i+1);
       if($i=="b")b+=$(i+1); if($i=="b2")b2+=$(i+1); if($i=="c")c+=$(i+1)}}
       END{printf "TOTAL chains %d base %d a %d a2 %d b %d b2 %d c %d\n", N, B, a, a2, b, b2, c}' "$OUT/x.txt" | tee "$OUT/total.txt"
  [ "$n" -eq $((NA * 8)) ] || { echo "missing lines: $n of $((NA*8))"; st=1; }
  grep -q 'base 0 ' "$OUT/total.txt" || st=1
  grep -v '^EXP480 ' "$OUT/x.txt" | head -20
fi
echo "exit $st"; exit $st
