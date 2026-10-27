#!/bin/bash
# MATH-412: bm_obs.g on a runner; log in $JOB_OUT.  EXTRA='LEVEL0:=true;;' to include G itself.
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
echo "${EXTRA:-}" | cat - bm_obs.g | ${GAP:-$JOB_CACHE/gap/gap} -q -b --quitonbreak -o 16g > "$OUTD/bm_obs.log" 2>&1
cat "$OUTD/bm_obs.log"
