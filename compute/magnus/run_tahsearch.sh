#!/bin/bash
# MATH-39: NSH hill-climb chains of tahsearch.g (NROUND rounds each) in parallel; logs in $JOB_OUT.
NSH=${NSH:-8}; NROUND=${NROUND:-300}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
export PY=${PY:-$(ls -d $JOB_CACHE/venv-*/bin/python | head -1)}; GAP=${GAP:-$JOB_CACHE/gap/gap}
for k in $(seq 1 $NSH); do
  SEED=$k NROUND=$NROUND $GAP -q -o 3g tahsearch_run.g > "$OUTD/tah_$k.log" 2>&1 &
done
wait
grep -h "^SEED\|^round\|Error" "$OUTD"/tah_*.log
