#!/bin/bash
# MATH-519: controls and families for the fixed-two-factor functional (lie_lambda3*.py).
# Usage (tm): bash compute/magnus/run_math519.sh   (writes $JOB_OUT/*.jsonl, controls.txt)
set -e
cd "$(dirname "$0")"
OUT=${JOB_OUT:-out}; mkdir -p "$OUT"; mkdir -p "${JOB_ROOT:-.}"
PY=python3
if ! $PY -c 'import numpy' 2>/dev/null; then
  # kimmy: the system python has neither numpy nor pip; take a cached venv that has numpy
  rm -rf "${JOB_CACHE:-/nonexistent}/venv-math519"     # a broken venv left by an earlier attempt
  for v in "${JOB_CACHE:-$HOME/.cache}"/venv-*/bin/python3; do
    if "$v" -c 'import numpy' 2>/dev/null; then PY=$v; break; fi
  done
fi
$PY -c 'import numpy, sys; print(sys.executable, numpy.__version__)'
$PY lie_lambda3_run.py controls none > "$OUT/controls_sym2.txt"
$PY lie_lambda3_run.py controls let > "$OUT/controls_let.txt"
$PY lie_lambda3_run.py controls pow > "$OUT/controls_pow.txt"
$PY lie_lambda3_run.py famA 3 11 3000 > "$OUT/famA_q3_sym2.jsonl"
$PY lie_lambda3_run.py famA 3 11 3000 let > "$OUT/famA_q3_let.jsonl"
$PY lie_lambda3_run.py famA 3 11 1000 pow > "$OUT/famA_q3_pow.jsonl"
$PY lie_lambda3_run.py famA 2 12 1000 > "$OUT/famA_q2_sym2.jsonl"
$PY lie_lambda3_run.py famB 3 13 1500 > "$OUT/famB_q3_sym2.jsonl"
$PY lie_lambda3_run.py famB 2 14 500 > "$OUT/famB_q2_sym2.jsonl"
$PY lie_lambda3_run.py unmet 2 15 100 > "$OUT/unmet_q2_sym2.jsonl"
$PY lie_lambda3_run.py unmet 3 16 300 > "$OUT/unmet_q3_sym2.jsonl"
$PY lie_lambda3_run.py unmet 3 16 100 let > "$OUT/unmet_q3_let.jsonl"
$PY lie_lambda3_run.py bm 0 > "$OUT/bm_cut0.txt"
$PY lie_lambda3_run.py bm 3 > "$OUT/bm_cut3.txt"
echo done
