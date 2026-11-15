#!/bin/bash
# MATH-480 (wiki 891 Sec. 19).  Usage: run_case480.sh MODE [PAR]
#   diag PAR      exp480.py 'diag' S = 1..4: all diagonal K on capped types without 9 (R = 0); control without (D2)
#   certf PAR     exp480.py 'certf' on every capped type of length 3 without 9 (filtration certificate)
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
if [ "$MODE" = certf ]; then
  python3 ../case472/nonel472.py types 3 | awk '{print "certf " $0}' > "$OUT/c.args"
  NA=$(wc -l < "$OUT/c.args"); echo "0/$NA" > "$PROG"
  xargs -P "$PAR" -L 1 python3 exp480.py < "$OUT/c.args" > "$OUT/c.txt" 2>&1
  n=$(grep -c '^CERTF ' "$OUT/c.txt"); echo "$NA/$NA" > "$PROG"
  awk '/^CERTF /{N+=$7; b+=$9; z+=$11; c+=$13; if($15=="yes")u++; L++} END{printf "TOTAL (d,A) %d pairs %d not9 %d zero %d cert %d uni-yes %d\n", L, N, b, z, c, u}' "$OUT/c.txt" | tee "$OUT/ctotal.txt"
  [ "$n" -eq $((NA * 8)) ] || { echo "missing lines: $n of $((NA*8))"; st=1; }
  grep -q ' not9 0 ' "$OUT/ctotal.txt" || st=1
  grep -v '^CERTF ' "$OUT/c.txt" | head -20
  echo "== (d,A) with a pair without certificate (cert < pairs) or without a uniform c"
  awk '/^CERTF /{ if ($13 < $7 || $15 != "yes") print }' "$OUT/c.txt"
  echo "== loose domain"
  python3 ../case472/nonel472.py types 3 | awk '{print "certf " $0 " all loose"}' > "$OUT/cl.args"
  xargs -P "$PAR" -L 1 python3 exp480.py < "$OUT/cl.args" > "$OUT/cl.txt" 2>&1
  awk '/^CERTF-loose /{N+=$7; b+=$9; z+=$11; c+=$13; if($15=="yes")u++; L++} END{printf "TOTAL-loose (d,A) %d pairs %d not9 %d zero %d cert %d uni-yes %d\n", L, N, b, z, c, u}' "$OUT/cl.txt"
  [ "$(grep -c '^CERTF-loose ' "$OUT/cl.txt")" -eq $((NA * 8)) ] || st=1
fi
if [ "$MODE" = diag ]; then
  for S in 1 2 3 4; do echo "diag $S"; done | xargs -P "$PAR" -L 1 python3 exp480.py > "$OUT/d.txt" 2>&1
  cat "$OUT/d.txt"
  [ "$(grep -c '^DIAG480 ' "$OUT/d.txt")" -eq 4 ] && [ "$(awk '/^DIAG480 /{s+=$NF} END{print s+0}' "$OUT/d.txt")" -eq 0 ] || st=1
  echo "== control: diagonal K without (D2) at S=3 (must fail)"
  python3 - <<'PY' || true
import sys, itertools, numpy as np
sys.path[:0] = ['.', '../case467', '../case472', '../case473']
from exp480 import K3, MOD
from diag467 import Model
from nonel472 import types_no9
f = n = 0
for d in types_no9(3):
    M = Model(d, MOD, ('D2',))
    for A in [set(c) for r in range(4) for c in itertools.combinations(range(3), r)]:
        k3 = K3(3, A)
        for js in itertools.product(range(3), repeat=3):
            Kg = [3 ** j * k3[h] for h, j in zip(range(3), js)] + [27 * np.eye(3, dtype=np.int64)[h] for h in range(3)]
            ok, _ = M.check({3: k3, 27: Kg}); n += 1; f += (not ok)
print("DIAG480-CONTROL noD2 S 3 cases", n, "failing", f)
PY
fi
echo "exit $st"; exit $st
