#!/bin/bash
# MATH-474 (wiki 891 Sec. 23): depth-c reduction, s = 3 chains of depth <= 2 for every k, local certificates, s = 5 cost.
# Usage: run_case474n.sh [PAR]
#  1. cost:   size of the full s = 5 mixed enumeration outside (T0), (T1) and measured CPU s per check (information).
#  2. cross:  Prop. 23.1 on random chains (S = 3, k = 4..6; S = 4, k = 5): for depth <= C, sigma divisible by 3^(k-C-1)
#             and verdict(full mod 3^k) == verdict(depth-C mixed mod 3^(C+1)).  Control without (D2): failures occur and
#             coincide; without (Kt): information (the divisibility uses (Kt)).
#  3. mdeep:  S = 3, C = 2: all cut-27 types, all A, all profiles (6 403 680), R = 0.  Consistency: mdeep 3 1 = melem 3
#             (21 416).  Controls (D2), (Kt) on part 0 of 16 must fail.
#  4. exact:  loc474 exact 4 on parts 9, 27, 33 of 54: R = 0 (Thm 22.6) and how often a single R_I != 0 (information).
#  5. local:  loc474 local 3 (|U| = 3 relaxation, I of size 2 and 3): number of failing local data (information);
#             control without (D2).
# Durable copy: $JOB_CACHE/m474n/<date>.  Exit 0 iff every claim holds and every required control fails.
set -uo pipefail
PAR=${1:-4}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out474n}; mkdir -p "$OUT"; st=0
python3 loc474.py cost 5 400 1 > "$OUT/cost.txt" 2>&1; cat "$OUT/cost.txt"
{ echo "cross 3 4 2 4000 1"; echo "cross 3 5 2 4000 2"; echo "cross 3 5 3 4000 3"; echo "cross 3 6 3 3000 4"
  echo "cross 3 6 2 3000 5"; echo "cross 4 5 2 1500 6"
  echo "cross 3 5 2 4000 2 D2"; echo "cross 3 6 3 3000 4 D2"; echo "cross 3 5 2 4000 2 Kt"; } > "$OUT/cross.args"
NP=16
{ for p in $(seq 0 $((NP - 1))); do echo "mdeep 3 2 $p $NP"; done; echo "mdeep 3 1 0 1"
  echo "mdeep 3 2 0 $NP D2"; echo "mdeep 3 2 0 $NP Kt"; } > "$OUT/mdeep.args"
xargs -P "$PAR" -L 1 python3 deep474.py < "$OUT/cross.args" > "$OUT/cross.txt" 2>&1; rc1=$?
xargs -P "$PAR" -L 1 python3 deep474.py < "$OUT/mdeep.args" > "$OUT/mdeep.txt" 2>&1; rc2=$?
{ for p in 9 27 33; do echo "exact 4 $p 54"; done; echo "local 3 0 1"; echo "local 3 0 1 D2"; } > "$OUT/loc.args"
xargs -P "$PAR" -L 1 python3 loc474.py < "$OUT/loc.args" > "$OUT/loc.txt" 2>&1
cat "$OUT/cross.txt" "$OUT/mdeep.txt" "$OUT/loc.txt"
# claims
nc=$(grep -c "^DEEPCROSS.*drop \[\] " "$OUT/cross.txt"); dc=$(grep "^DEEPCROSS.*drop \[\] " "$OUT/cross.txt" | awk '{s+=$NF} END{print s+0}')
echo "cross: $nc of 6 lines, DIFFERENT+nondivisible $dc"; [ "$nc" -eq 6 ] && [ "$dc" -eq 0 ] || st=1
ff=$(grep "^DEEPCROSS.*'D2'" "$OUT/cross.txt" | grep -o "\[[0-9]*, [0-9]*, [0-9]*, [0-9]*\]" | awk -F'[][, ]+' '{s+=$4} END{print s+0}')
fd=$(grep "^DEEPCROSS.*'D2'" "$OUT/cross.txt" | awk '{s+=$NF} END{print s+0}')
echo "cross control without D2: full failing $ff (must be > 0), DIFFERENT $fd (must be 0)"; [ "$ff" -gt 0 ] && [ "$fd" -eq 0 ] || st=1
nm=$(grep -c "^MDEEP S 3 C 2 part .* drop \[\] " "$OUT/mdeep.txt")
pm=$(grep "^MDEEP S 3 C 2 part .* drop \[\] " "$OUT/mdeep.txt" | sed 's/.*profiles \([0-9]*\).*/\1/' | awk '{s+=$1} END{print s+0}')
fm=$(grep "^MDEEP S 3 C 2 part .* drop \[\] " "$OUT/mdeep.txt" | sed 's/.*FAILING \([0-9]*\).*/\1/' | awk '{s+=$1} END{print s+0}')
echo "mdeep 3 2: parts $nm of $NP, profiles $pm (must be 6403680), FAILING $fm"
[ "$nm" -eq "$NP" ] && [ "$pm" -eq 6403680 ] && [ "$fm" -eq 0 ] || st=1
grep -q "^MDEEP S 3 C 1 part 0 of 1 drop \[\] types 18 profiles 21416 .* FAILING 0 " "$OUT/mdeep.txt" && echo "mdeep 3 1 = melem 3: ok" || { echo "mdeep 3 1: MISMATCH"; st=1; }
for D in D2 Kt; do
  x=$(grep "^MDEEP S 3 C 2 .*'$D'" "$OUT/mdeep.txt" | sed 's/.*FAILING \([0-9]*\).*/\1/'); x=${x:-0}
  echo "mdeep control without $D: failing $x (must be > 0)"; [ "$x" -gt 0 ] || st=1
done
ne=$(grep "^EXACT S 4 .*drop \[\] " "$OUT/loc.txt" | sed 's/.*R!=0 \([0-9]*\).*/\1/' | awk '{s+=$1} END{print s+0}')
nl=$(grep -c "^EXACT S 4 .*drop \[\] " "$OUT/loc.txt")
echo "exact 4: $nl of 3 parts, R!=0 in $ne (must be 0)"; [ "$nl" -eq 3 ] && [ "$ne" -eq 0 ] || st=1
grep -q "^LOCAL S 3 part 0 of 1 drop \[\] " "$OUT/loc.txt" || { echo "local 3: missing"; st=1; }
[ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ] || { echo "xargs rc $rc1 $rc2"; st=1; }
echo "overall ok=$((1 - st))"
if [ -n "${JOB_CACHE:-}" ]; then D=$JOB_CACHE/m474n/$(date +%Y%m%d-%H%M%S); mkdir -p "$D" && cp "$OUT"/*.txt "$OUT"/*.args "$D"/ && echo "copied to $D"; fi
exit $st
