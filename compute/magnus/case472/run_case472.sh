#!/bin/bash
# MATH-472 (wiki 891 Sec. 18): non-elementary chains mod 27 on capped types WITHOUT the invariant 9.
# Usage: run_case472.sh MODE [PAR]
#   main PAR   (a) s = 3, 4: ALL non-elementary chains (pair-orbit reduction, s5_472.py 'run') on every capped type of
#                  length 3 and 4 without 9 (27 and 107 types, all A): FAILING 0 (a check of Thms 13.6/14.5 on these
#                  types that does not use the normal form of K_9);  control of the orbit reduction: 'full' on 3
#                  (d, A) at s = 4 (all subgroups);  controls without (D2) and without (Kt) on 4 types: must fail;
#              (b) bricks (nonel472.py 'brick'): 'four' m = 1..4 (Jordan J_m(2)), 'wild' m = 1..4 (first 12 seeds,
#                  local ones reported), 'meet' (h_A ∩ h_N != 0) m = 1, 2 (8 seeds): local image of B, all columns nonzero (four), R = 0; controls without (D2)
#                  on 'four' m = 2, 3: must fail;
#              (c) certificate test (nonel472.py 'certs' S = 2, 3): reported (a negative result is expected);
#              (d) random non-elementary chains s = 5, 6, 7 (evidence).
#   pilot5 PAR s = 5: 's5_472.py run' on 4 fixed (d, A) for the volume estimate of the full s = 5 check.
# Progress: $JOB_ROOT/progress.  Exit status 1 iff a claim fails or a control does not fail.
set -uo pipefail
MODE=$1; PAR=${2:-4}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out472}; mkdir -p "$OUT"
PROG=${JOB_ROOT:-$OUT}/progress
st=0
echo "python: $(command -v python3) $(python3 -c 'import numpy; print(numpy.__version__)')"
git -C .. rev-parse HEAD 2>/dev/null || true

if [ "$MODE" = main ]; then
  for S in 3 4; do python3 nonel472.py types $S; done | awk '{print "run " $0}' > "$OUT/a.args"
  NA=$(wc -l < "$OUT/a.args")
  echo "0/$NA" > "$PROG"
  ( while :; do n=$(grep -c '^S5NE ' "$OUT/a.txt" 2>/dev/null); echo "${n:-0}/$NA" > "$PROG"; sleep 30; done ) & PP=$!
  xargs -P "$PAR" -L 1 python3 s5_472.py < "$OUT/a.args" > "$OUT/a.txt" 2>&1
  kill $PP 2>/dev/null
  n=$(grep -c '^S5NE ' "$OUT/a.txt"); f=$(awk '/^S5NE /{s+=$NF} END{print s+0}' "$OUT/a.txt")
  awk '/^S5NE /{split($3,t,","); S=length(t); n[S]++; o[S]+=$11; c[S]+=$13; z[S]+=$15; sec[S]+=$17}
       END{for(S in n) printf "  s=%d: types %d, non-elementary pair orbits %d, chains checked %d, sigma!=0 %d, cpu-sec %.0f\n", S, n[S], o[S], c[S], z[S], sec[S]}' "$OUT/a.txt" | sort
  echo "(a) lines $n of $NA, FAILING $f"; [ "$n" -eq "$NA" ] && [ "$f" -eq 0 ] || st=1
  for x in "3,27,81,729 0,2" "27,27,81,243 1" "3,3,27,729 0,3"; do python3 s5_472.py full $x; done > "$OUT/afull.txt" 2>&1
  cat "$OUT/afull.txt"; f=$(awk '/^S5NEFULL/{s+=$NF} END{print s+0}' "$OUT/afull.txt")
  [ "$(grep -c '^S5NEFULL' "$OUT/afull.txt")" -eq 3 ] && [ "$f" -eq 0 ] || st=1
  for D in D2 Kt; do for t in 3,27,81,729 27,27,81,243 3,3,27,729 27,81,243,729; do echo "run $t all $D"; done; done > "$OUT/ctl.args"
  xargs -P "$PAR" -L 1 python3 s5_472.py < "$OUT/ctl.args" > "$OUT/ctl.txt" 2>&1
  grep '^S5NE ' "$OUT/ctl.txt"
  for D in D2 Kt; do
    c=$(awk -v D="['$D']" '/^S5NE / && $5==D {s+=$NF} END{print s+0}' "$OUT/ctl.txt")
    echo "control without $D: failing $c (must be > 0)"; [ "$c" -gt 0 ] || st=1
  done
  echo "== (b) bricks"
  for m in 1 2 3 4; do python3 nonel472.py brick four $m || st=1; done
  for m in 2 3; do python3 nonel472.py brick four $m D2; done > "$OUT/bctl.txt"; cat "$OUT/bctl.txt"
  [ "$(grep -c 'R=0 False' "$OUT/bctl.txt")" -eq 2 ] || { echo "brick control did not fail"; st=1; }
  for m in 1 2 3 4; do for seed in $(seq 0 11); do python3 nonel472.py brick wild $m "" $seed; done; done > "$OUT/wild.txt" 2>&1
  grep -c 'local True' "$OUT/wild.txt" | sed 's/^/wild: local configurations /'
  grep 'local True' "$OUT/wild.txt"
  bad=$(grep '^BRICK' "$OUT/wild.txt" | grep -c 'R=0 False'); echo "wild: R=0 False in $bad"; [ "$bad" -eq 0 ] || st=1
  for m in 1 2; do for seed in $(seq 0 7); do python3 nonel472.py brick meet $m "" $seed; done; done > "$OUT/meet.txt" 2>&1
  grep -c 'local True' "$OUT/meet.txt" | sed 's/^/meet (h_A ∩ h_N != 0): local configurations /'
  grep 'local True' "$OUT/meet.txt"
  bad=$(grep '^BRICK' "$OUT/meet.txt" | grep -c 'R=0 False'); echo "meet: R=0 False in $bad"; [ "$bad" -eq 0 ] || st=1
  [ "$(grep -c '^BRICK' "$OUT/meet.txt")" -eq 16 ] && [ "$(grep -c '^BRICK' "$OUT/wild.txt")" -eq 48 ] || st=1
  echo "== (c) certificate (reported only)"
  python3 nonel472.py certs 2; python3 nonel472.py certs 3
  echo "== (d) random non-elementary chains (evidence)"
  for x in "5 4000 1" "5 4000 2" "6 1500 3" "6 1500 4" "7 400 5" "7 400 6"; do echo "rand $x"; done > "$OUT/r.args"
  xargs -P "$PAR" -L 1 python3 nonel472.py < "$OUT/r.args" > "$OUT/r.txt" 2>&1; cat "$OUT/r.txt"
  [ "$(grep -c '^RAND' "$OUT/r.txt")" -eq 6 ] && [ "$(awk '/^RAND/{s+=$NF} END{print s+0}' "$OUT/r.txt")" -eq 0 ] || st=1
fi

if [ "$MODE" = pilot5 ]; then
  printf 'run %s\n' "3,27,81,729,2187 0,2" "3,27,81,729,2187 -" "27,27,81,243,729 1,3" "3,3,27,81,729 0,3" > "$OUT/p.args"
  echo "0/4" > "$PROG"
  xargs -P "$PAR" -L 1 python3 s5_472.py < "$OUT/p.args" > "$OUT/p.txt" 2>&1
  cat "$OUT/p.txt"
  [ "$(grep -c '^S5NE ' "$OUT/p.txt")" -eq 4 ] && [ "$(awk '/^S5NE /{s+=$NF} END{print s+0}' "$OUT/p.txt")" -eq 0 ] || st=1
fi
echo "overall ok=$((1 - st))"
exit $st
