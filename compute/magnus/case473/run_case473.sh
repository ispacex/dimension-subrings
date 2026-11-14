#!/bin/bash
# MATH-473 (wiki 891 Sec. 17): exhaustive check at s = 5 of the elementary chains mod 27 on types with the invariant 9,
# for the A violating (T1) (not covered by Thms 15.3, 16.2, 16.5), with orbit reduction.  Uses s5_473.py.
# Usage: run_case473.sh MODE [PART NPARTS] [PAR]
#   main PART NPARTS PAR  the s = 5 types with the invariant 9 whose index (in 's5_473.py types 5') is PART mod NPARTS:
#                         'run TYPE' and 'classify TYPE'.  Claims: every line present, FAILING 0, and the number of A
#                         checked per type equals the number of non-(T1) A from 'classify'.
#   checks PAR            (a) cross-check with s <= 4: 'run TYPE all' on every capped type of length 3 and 4 mod 27 --
#                             orbit total must equal 306 069 (t1471 'orbits', job kimmy/tm/20261114-202633-case471-t1-
#                             3ac4fe5), FAILING 0;
#                         (b) classification of all 768 capped types of length 5: (T0)/(T1) of t0471/t1471 agree with
#                             the independent shape classification (MISMATCH 0);
#                         (c) controls on s = 5 types: without (D2) and without (Kt) the same check must fail;
#                         (d) 'run TYPE all' on a few s = 5 types: the (T0)/(T1) classes too (reported per class).
#   pilot PAR             a fixed sample of 12 s = 5 types ('run' + 'classify') and (c): for the volume estimate.
# Progress: $JOB_ROOT/progress as done/total.  Exit status 1 iff a claim fails or a control does not fail.
set -uo pipefail
MODE=$1; shift
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out473}; mkdir -p "$OUT"
PROG=${JOB_ROOT:-$OUT}/progress
st=0
py=s5_473.py
alltypes() { python3 -c "
import sys; sys.path.insert(0, '../case467')
from diag467 import capped_types_k
for d in capped_types_k($1, 3): print(','.join(map(str, d)))"; }
progress() {  # progress TOTAL FILE...: background updater
  local tot=$1; shift
  ( while :; do n=$(cat "$@" 2>/dev/null | grep -c '^S5'); echo "$n/$tot" > "$PROG"; sleep 20; done ) &
  PPID_PROG=$!
}
main_verdict() {  # main_verdict RUNFILE CLASSFILE NTYPES
  local rf=$1 cf=$2 nt=$3
  local nr nc f mm amis
  nr=$(grep -c '^S5RUN' "$rf"); nc=$(grep -c '^S5CLASS' "$cf")
  f=$(awk '/^S5RUN/{s+=$NF} END{print s+0}' "$rf")
  mm=$(awk '/^S5CLASS/{s+=$NF} END{print s+0}' "$cf")
  # number of A checked per type == number of non-(T1) A in classify (all classes except T0, T1)
  amis=$(awk '/^S5CLASS/{n=0; for(i=4;i<NF-1;i++){split($i,a,":"); if(a[1]!="T0" && a[1]!="T1") n+=a[2]}; want[$3]=n}
              /^S5RUN/{got[$3]=$7} END{m=0; for(t in want) if(got[t]!=want[t]) m++; print m}' "$cf" "$rf")
  awk '/^S5RUN/{A+=$7; o+=$11; c+=$13; z+=$15; sec+=$(NF-2)} END{printf "types %d, A %d, orbits %d, checked %d, sigma!=0 %d, cpu-sec %.0f\n", NR, A, o, c, z, sec}' "$rf"
  awk '/^S5RUN/{for(i=1;i<=NF;i++) if($i ~ /^[0-9]A[0-9]N:/){split($i,a,"[:/]"); A[a[1]]+=a[2]; O[a[1]]+=a[3]; F[a[1]]+=a[4]}}
       END{for(k in A) printf "  class %s: A %d, orbits %d, failing %d\n", k, A[k], O[k], F[k]}' "$rf" | sort
  echo "run lines $nr of $nt, classify lines $nc of $nt, FAILING $f, MISMATCH $mm, types with wrong A count $amis"
  [ "$nr" -eq "$nt" ] && [ "$nc" -eq "$nt" ] && [ "$f" -eq 0 ] && [ "$mm" -eq 0 ] && [ "$amis" -eq 0 ] || st=1
}
controls() {  # controls PAR: without D2 / Kt on fixed s = 5 types (non-(T1) A only)
  local par=$1
  for D in D2 Kt; do for t in 3,9,27,243,729 3,9,81,243,729 9,27,243,729,2187 3,9,9,81,243; do echo "run $t $D"; done; done > "$OUT/ctl.args"
  xargs -P "$par" -L 1 python3 $py < "$OUT/ctl.args" > "$OUT/ctl.txt" 2>&1
  echo "== controls (must fail)"; cat "$OUT/ctl.txt"
  for D in D2 Kt; do
    c=$(awk -v D="['$D']" '/^S5RUN/ && $5==D {s+=$NF} END{print s+0}' "$OUT/ctl.txt")
    echo "control without $D: failing $c (must be > 0)"; [ "$c" -gt 0 ] || st=1
  done
  [ "$(grep -c '^S5RUN' "$OUT/ctl.txt")" -eq 8 ] || st=1
}

case $MODE in
main)
  PART=$1; NP=$2; PAR=${3:-4}
  python3 $py types 5 | awk -v p="$PART" -v n="$NP" '(NR-1)%n==p' > "$OUT/types.txt"
  nt=$(wc -l < "$OUT/types.txt")
  sed 's/^/classify /' "$OUT/types.txt" | xargs -P "$PAR" -L 1 python3 $py > "$OUT/class.txt" 2>&1
  progress "$nt" "$OUT/run.txt"
  sed 's/^/run /' "$OUT/types.txt" | xargs -P "$PAR" -L 1 python3 $py > "$OUT/run.txt" 2>&1
  kill $PPID_PROG 2>/dev/null; echo "$(grep -c '^S5RUN' "$OUT/run.txt")/$nt" > "$PROG"
  echo "== main part $PART of $NP"
  main_verdict "$OUT/run.txt" "$OUT/class.txt" "$nt"
  ;;
pilot)
  PAR=${1:-4}
  python3 $py types 5 | awk 'NR%28==1' > "$OUT/types.txt"      # 13 types spread over the list
  nt=$(wc -l < "$OUT/types.txt")
  sed 's/^/classify /' "$OUT/types.txt" | xargs -P "$PAR" -L 1 python3 $py > "$OUT/class.txt" 2>&1
  progress $((nt + 8)) "$OUT/run.txt" "$OUT/ctl.txt"
  sed 's/^/run /' "$OUT/types.txt" | xargs -P "$PAR" -L 1 python3 $py > "$OUT/run.txt" 2>&1
  echo "== pilot"; cat "$OUT/run.txt"
  main_verdict "$OUT/run.txt" "$OUT/class.txt" "$nt"
  controls "$PAR"
  kill $PPID_PROG 2>/dev/null
  # volume estimate: cpu-seconds per non-(T1) A in the sample, times the number of non-(T1) A over all 341 types
  python3 $py types 5 | sed 's/^/classify /' | xargs -P "$PAR" -L 1 python3 $py > "$OUT/class_all.txt" 2>&1
  awk 'FNR==NR && /^S5RUN/{A+=$7; sec+=$(NF-2); next}
       /^S5CLASS/{for(i=4;i<NF-1;i++){split($i,a,":"); if(a[1]!="T0" && a[1]!="T1") n+=a[2]}}
       END{printf "ESTIMATE sample A %d, cpu-sec %.0f, sec/A %.2f; all non-(T1) A %d -> %.1f core-hours\n", A, sec, sec/A, n, sec/A*n/3600}' \
       "$OUT/run.txt" "$OUT/class_all.txt"
  ;;
checks)
  PAR=${1:-4}
  { alltypes 3; alltypes 4; } | sed 's/^/run /; s/$/ all/' > "$OUT/x.args"
  alltypes 5 | sed 's/^/classify /' > "$OUT/cl5.args"
  printf 'run %s all\n' 3,9,27,243,729 9,9,27,81,243 3,3,9,27,81 > "$OUT/all5.args"
  progress $(( $(wc -l < "$OUT/x.args") + $(wc -l < "$OUT/cl5.args") + 3 + 8 )) "$OUT/x.txt" "$OUT/cl5.txt" "$OUT/all5.txt" "$OUT/ctl.txt"
  xargs -P "$PAR" -L 1 python3 $py < "$OUT/x.args" > "$OUT/x.txt" 2>&1
  xargs -P "$PAR" -L 1 python3 $py < "$OUT/cl5.args" > "$OUT/cl5.txt" 2>&1
  echo "== (a) cross-check s = 3, 4 (all A)"
  nx=$(grep -c '^S5RUN' "$OUT/x.txt"); ox=$(awk '/^S5RUN/{s+=$11} END{print s+0}' "$OUT/x.txt")
  fx=$(awk '/^S5RUN/{s+=$NF} END{print s+0}' "$OUT/x.txt")
  for S in 3 4; do awk -v S=$S '/^S5RUN/{n=split($3,a,","); if(n==S){t++; o+=$11; f+=$NF}} END{printf "s=%d types %d orbits %d FAILING %d\n", S, t, o, f}' "$OUT/x.txt"; done
  echo "lines $nx of $(wc -l < "$OUT/x.args"), orbits $ox (must be 306069), FAILING $fx"
  [ "$nx" -eq "$(wc -l < "$OUT/x.args")" ] && [ "$ox" -eq 306069 ] && [ "$fx" -eq 0 ] || st=1
  echo "== (b) classification, all capped types of length 5"
  n5=$(grep -c '^S5CLASS' "$OUT/cl5.txt"); m5=$(awk '/^S5CLASS/{s+=$NF} END{print s+0}' "$OUT/cl5.txt")
  echo "lines $n5 of 768, MISMATCH $m5"; [ "$n5" -eq 768 ] && [ "$m5" -eq 0 ] || st=1
  controls "$PAR"
  xargs -P "$PAR" -L 1 python3 $py < "$OUT/all5.args" > "$OUT/all5.txt" 2>&1
  echo "== (d) s = 5, all A (including the (T0)/(T1) classes, covered by Thms 16.2/16.5)"; cat "$OUT/all5.txt"
  [ "$(grep -c '^S5RUN' "$OUT/all5.txt")" -eq 3 ] && [ "$(awk '/^S5RUN/{s+=$NF} END{print s+0}' "$OUT/all5.txt")" -eq 0 ] || st=1
  kill $PPID_PROG 2>/dev/null
  ;;
*) echo "unknown mode $MODE"; exit 2 ;;
esac
echo "overall ok=$((1 - st))"
exit $st
