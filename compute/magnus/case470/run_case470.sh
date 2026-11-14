#!/bin/bash
# MATH-470 (wiki 891 Sec. 15): elementary chains and the reduction modulo 3^k -> modulo 9.  Usage: run_case470.sh [PAR]
#  1. all: EXHAUSTIVE over all elementary chains, s = 3: every capped type mod 27 (claims (a), (b), R = 0) and mod 81;
#     s = 4 mod 27: 12 types without invariant 9.  Types WITH a middle invariant are the control for the hypothesis of
#     (b): there the inclusion Lambda -> Lambda_9 must fail somewhere (counted, required > 0).
#  2. reduce: random elementary chains, all types without a middle invariant for s = 4, 5 (mod 27), sampled for
#     s = 6 (mod 27) and s = 4, 5 (mod 81).
#  3. sigma: claim (a) on random elementary chains: s = 5 mod 27 on types with the invariant 9, s = 4 mod 81 on 60
#     random capped types (38 of them with a middle invariant); control: non-elementary chains must violate it.
#  4. evidence for the open mixed case: random elementary chains, s = 5, 6, types with the invariant 9, R = 0 directly.
# Exit status 0 iff every claim holds and every control fails as it must.
set -uo pipefail
PAR=${1:-4}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out470}; mkdir -p "$OUT"
st=0
py=elem470.py
alltypes() { python3 -c "
import sys; sys.path.insert(0, '../case467')
from diag467 import capped_types_k
for d in capped_types_k($1, $2): print(','.join(map(str, d)))"; }
pick() { awk -v n="$1" 'BEGIN{srand(470)} {a[NR]=$0} END{for(i=1;i<=NR;i++){j=int(rand()*NR)+1; t=a[i];a[i]=a[j];a[j]=t}; for(i=1;i<=n&&i<=NR;i++) print a[i]}'; }
run() {  # run LABEL FILE-of-argument-lines CMD-PREFIX
  local lab=$1 f=$2; shift 2
  xargs -P "$PAR" -L 1 python3 $py "$@" < "$f" > "$OUT/$lab.txt" 2>&1
}
# 1. exhaustive
alltypes 3 3 | sed 's/$/ 3/' > "$OUT/a1.args"
alltypes 3 4 | sed 's/$/ 4/' > "$OUT/a2.args"
python3 $py types 4 3 | pick 12 | sed 's/$/ 3/' > "$OUT/a3.args"
cat "$OUT/a1.args" "$OUT/a2.args" "$OUT/a3.args" > "$OUT/all.args"
run all "$OUT/all.args" all
# 2. random, no middle invariant
{ python3 $py types 4 3 | sed 's/$/ 3 40 1/'; python3 $py types 5 3 | sed 's/$/ 3 25 2/';
  python3 $py types 6 3 | pick 300 | sed 's/$/ 3 10 3/'; python3 $py types 4 4 | sed 's/$/ 4 20 4/';
  python3 $py types 5 4 | pick 200 | sed 's/$/ 4 10 5/'; } > "$OUT/reduce.args"
run reduce "$OUT/reduce.args" reduce
# 3. sigma on types with middle invariants, and the non-elementary control
{ alltypes 5 3 | grep -E '(^|,)9(,|$)' | pick 100 | sed 's/$/ 3 20 6/'; alltypes 4 4 | pick 60 | sed 's/$/ 4 20 7/'; } > "$OUT/sigma.args"
run sigma "$OUT/sigma.args" sigma
sed 's/$/ ctl/' "$OUT/sigma.args" > "$OUT/sigmactl.args"
run sigmactl "$OUT/sigmactl.args" sigma
# 4. mixed case (with the invariant 9): evidence only
{ alltypes 5 3 | grep -E '(^|,)9(,|$)' | pick 150 | sed 's/$/ 3 30 8/'; alltypes 6 3 | grep -E '(^|,)9(,|$)' | pick 100 | sed 's/$/ 3 10 9/'; } > "$OUT/mixed.args"
run mixed "$OUT/mixed.args" reduce

# ---- verdicts
cnt() { grep -c "$1" "$2"; }
echo "== 1. exhaustive"
n_all=$(wc -l < "$OUT/all.args"); n_ok=$(grep -c '^ALLELEM' "$OUT/all.txt")
bad=$(grep '^ALLELEM ' "$OUT/all.txt" | grep -vc 'coef_mod9_ok True .*sigma_not_divisible 0 lambda_not_in_Lambda9 0 sigma._not_in_Sigma9 0 identity_R_fails 0 FAILING_direct 0$')
badmid=$(grep '^ALLELEM_MID' "$OUT/all.txt" | grep -vc 'coef_mod9_ok True .*sigma_not_divisible 0 lambda_not_in_Lambda9 [0-9]* sigma._not_in_Sigma9 0 identity_R_fails 0 FAILING_direct 0$')
ctlmid=$(grep '^ALLELEM_MID' "$OUT/all.txt" | grep -vc 'lambda_not_in_Lambda9 0 ')
chains=$(awk '/^ALLELEM/{for(i=1;i<=NF;i++) if($i=="chains") s+=$(i+1)} END{print s}' "$OUT/all.txt")
echo "lines $n_ok of $n_all, chains $chains, failing (no middle) $bad, failing (middle) $badmid, middle types where Lambda -> Lambda_9 fails (control, must be > 0) $ctlmid"
[ "$n_ok" -eq "$n_all" ] && [ "$bad" -eq 0 ] && [ "$badmid" -eq 0 ] && [ "$ctlmid" -gt 0 ] || st=1
echo "== 2. reduce (random, no middle invariant)"
n=$(wc -l < "$OUT/reduce.args"); ok=$(grep -c '^REDUCE ' "$OUT/reduce.txt")
bad=$(grep '^REDUCE ' "$OUT/reduce.txt" | grep -vc 'lambda_not_in_Lambda9 0 sigma._not_in_Sigma9 0 identity_R_fails 0 R9!=0 0 FAILING_direct 0$')
chains=$(awk '/^REDUCE /{for(i=1;i<=NF;i++) if($i=="chains") s+=$(i+1)} END{print s}' "$OUT/reduce.txt")
echo "lines $ok of $n, chains $chains, failing $bad"
[ "$ok" -eq "$n" ] && [ "$bad" -eq 0 ] || st=1
echo "== 3. sigma in 3^(k-2) Z (types with middle invariants) and control"
n=$(wc -l < "$OUT/sigma.args"); ok=$(grep -c '^SIGMA ' "$OUT/sigma.txt"); bad=$(grep '^SIGMA ' "$OUT/sigma.txt" | grep -vc 'VIOLATIONS 0$')
c=$(awk '/^SIGMA_CTL/{s+=$NF} END{print s+0}' "$OUT/sigmactl.txt"); cl=$(grep -c '^SIGMA_CTL' "$OUT/sigmactl.txt")
echo "lines $ok of $n, failing $bad; control: non-elementary chains with sigma not divisible $c (must be > 0), lines $cl"
[ "$ok" -eq "$n" ] && [ "$bad" -eq 0 ] && [ "$c" -gt 0 ] && [ "$cl" -eq "$n" ] || st=1
echo "== 4. mixed case (invariant 9 present; evidence, R = 0 directly)"
n=$(wc -l < "$OUT/mixed.args"); ok=$(grep -c '^REDUCE_MID' "$OUT/mixed.txt")
bad=$(grep '^REDUCE_MID' "$OUT/mixed.txt" | grep -vc 'FAILING_direct 0$')
lam=$(awk '/^REDUCE_MID/{for(i=1;i<=NF;i++) if($i=="lambda_not_in_Lambda9") s+=$(i+1)} END{print s+0}' "$OUT/mixed.txt")
chains=$(awk '/^REDUCE_MID/{for(i=1;i<=NF;i++) if($i=="chains") s+=$(i+1)} END{print s}' "$OUT/mixed.txt")
echo "lines $ok of $n, chains $chains, failing $bad, chains where lambda is not in Lambda_9 (reduction (b) does not apply) $lam"
[ "$ok" -eq "$n" ] && [ "$bad" -eq 0 ] || st=1
echo "overall ok=$((1 - st))"
exit $st
