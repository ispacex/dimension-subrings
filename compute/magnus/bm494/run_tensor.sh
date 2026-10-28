#!/bin/bash
# MATH-413: bm_tensor.g on a runner; tables in $JOB_OUT/tensor.txt, log in $JOB_OUT/bm_tensor.log.
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"; export JOB_OUT=$OUTD
${GAP:-$JOB_CACHE/gap/gap} -q -b --quitonbreak -o 16g bm_tensor.g > "$OUTD/bm_tensor.log" 2>&1
cat "$OUTD/bm_tensor.log"
