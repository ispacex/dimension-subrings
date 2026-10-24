#!/bin/bash
# MATH-39: NSH shards of ripsqall.g (NWALK walks each) in parallel; logs in $JOB_OUT.
NSH=${NSH:-4}; NWALK=${NWALK:-20}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
export PY=${PY:-$(ls -d $JOB_CACHE/venv-*/bin/python | head -1)}; GAP=${GAP:-$JOB_CACHE/gap/gap}
for k in $(seq 1 $NSH); do
  SEED=$k NWALK=$NWALK $GAP -q -o 3g ripsqall_run.g > "$OUTD/qall_$k.log" 2>&1 &
done
wait
grep -h "^SEED\|^HIT\|Error" "$OUTD"/qall_*.log
