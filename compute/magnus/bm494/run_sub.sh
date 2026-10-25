#!/bin/bash
# MATH-403: bm_sub.g on a runner; log in $JOB_OUT.  EXTRA='LEVEL0:=true;;' to include G itself.
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
echo "${EXTRA:-}" | cat - bm_sub.g | ${GAP:-$JOB_CACHE/gap/gap} -q -o 16g > "$OUTD/bm_sub.log" 2>&1
cat "$OUTD/bm_sub.log"
