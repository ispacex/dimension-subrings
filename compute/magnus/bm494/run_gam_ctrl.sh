#!/bin/bash
# MATH-412: negative control for bm_gam.g on D = G x C_9; log in $JOB_OUT.
set -e
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
# everything from LEV to Gam, verbatim from bm_gam.g
sed -n '/^LEV := /,/^ZG := /p' bm_gam.g | sed '$d' > gamfuncs.g
grep -q '^Gam := function' gamfuncs.g
echo "${EXTRA:-}" | cat - bm_gam_ctrl.g | ${GAP:-$JOB_CACHE/gap/gap} -q -b --quitonbreak -o 16g > "$OUTD/bm_gam_ctrl.log" 2>&1 || true
cat "$OUTD/bm_gam_ctrl.log"
