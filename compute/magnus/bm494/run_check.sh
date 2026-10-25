#!/bin/bash
# MATH-403: bm_check.g on a runner; log in $JOB_OUT.
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
${GAP:-$JOB_CACHE/gap/gap} -q -o 12g bm_check.g > "$OUTD/bm_check.log" 2>&1
cat "$OUTD/bm_check.log"
