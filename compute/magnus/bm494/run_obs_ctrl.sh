#!/bin/bash
# MATH-412: negative control for bm_obs.g on D = G x C_9; log in $JOB_OUT.
set -e
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
# everything from LEV to Obstruct, verbatim from bm_obs.g
sed -n '/^LEV := /,/^ZG := /p' bm_obs.g | sed '$d' > obsfuncs.g
grep -q '^Obstruct := function' obsfuncs.g
echo "${EXTRA:-}" | cat - bm_obs_ctrl.g | ${GAP:-$JOB_CACHE/gap/gap} -q -b --quitonbreak -o 16g > "$OUTD/bm_obs_ctrl.log" 2>&1 || true
cat "$OUTD/bm_obs_ctrl.log"
