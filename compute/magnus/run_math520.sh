#!/bin/bash
# MATH-520: lie_unmet_gen.py families on tm.  Usage: bash compute/magnus/run_math520.sh SHARD
#   SHARD 0  controls + the p=2 positive controls, then p=3 part A
#   SHARD 1  p=3 part B
# Each line of a plan is "Q SEED COUNT EXPS TIES"; output $JOB_OUT/q{Q}_{EXPS}_{TIES}_s{SEED}.jsonl.
set -e
cd "$(dirname "$0")"
OUT=${JOB_OUT:-out}; mkdir -p "$OUT"
PY=python3
if ! $PY -c 'import numpy' 2>/dev/null; then
  PY=${MATH520_PY:-${JOB_CACHE:-$HOME/.cache}/venv-e13b2c068d/bin/python3}   # kimmy: cached numpy venv
fi
$PY -c 'import numpy, sys; print(sys.executable, numpy.__version__)'
case "$1" in
  0) [ -n "$2" ] || $PY lie_unmet_gen.py controls > "$OUT/controls.txt"
     PLAN="2 101 1000 l1 u
2 102 1000 l1 uc
2 103 1000 l1 ub
2 104 1000 l1 ux
2 105 1000 l1 uinh
2 106 1000 l1 mix
2 107 500 local uinh
2 108 500 rand mix
3 201 30000 l1 uinh
3 202 15000 local uinh" ;;
  1) PLAN="3 301 30000 l1 mix
3 302 5000 l1 u
3 303 20000 rand mix" ;;
  *) PLAN="$2" ;;
esac
TOTAL=$(echo "$PLAN" | awk '{s+=$3} END {print s}')
DONE=0
while read -r Q SEED COUNT EXPS TIES; do
  F="$OUT/q${Q}_${EXPS}_${TIES}_s${SEED}.jsonl"
  $PY lie_unmet_gen.py run "$Q" "$SEED" "$COUNT" "$EXPS" "$TIES" > "$F" &
  PID=$!
  while kill -0 $PID 2>/dev/null; do
    sleep 60; echo "$((DONE + $(wc -l < "$F")))/$TOTAL" > "${JOB_ROOT:-.}/progress"
  done
  wait $PID
  DONE=$((DONE + COUNT))
  $PY -c "import json,sys; L=[json.loads(l) for l in open(sys.argv[1])]; h=[r for r in L if r['tors']>0]; k=[r for r in h if r.get('ker_tors',0)>0]; print(sys.argv[1], len(L), 'hits', len(h), 'ker', len(k), 'ker_in_u3', sum(bool(r.get('ker_in_u3')) for r in k))" "$F" | tee -a "$OUT/summary.txt"
done <<< "$PLAN"
echo done
