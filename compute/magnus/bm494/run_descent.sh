#!/bin/bash
# MATH-403: NSH random descents (bm_descent.g, SEED=1..NSH) in parallel; logs in $JOB_OUT.
cd "$(dirname "$0")"
NSH=${NSH:-8}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"; GAP=${GAP:-$JOB_CACHE/gap/gap}
for k in $(seq 1 $NSH); do
  SEED=$k $GAP -q -o 2g bm_descent.g > "$OUTD/descent_$k.log" 2>&1 &
done
wait
grep -h "^SEED\|Error" "$OUTD"/descent_*.log
