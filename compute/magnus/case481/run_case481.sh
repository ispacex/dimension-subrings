#!/bin/bash
# MATH-481 (wiki 891 Sec. 20): small checks over F_3 / Z/9 of the functor pairs of matrices -> (1,1,1,2) -> configurations.
# Usage: run_case481.sh [SEED] [M2CASES]
# Exit status 1 iff a check fails.
set -uo pipefail
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out481}; mkdir -p "$OUT"
echo "python: $(command -v python3) $(python3 -c 'import numpy; print(numpy.__version__)')"
git -C .. rev-parse HEAD 2>/dev/null || true
python3 check481.py all "${1:-0}" "${2:-24}" 2>&1 | tee "$OUT/check481.txt"
exit "${PIPESTATUS[0]}"
