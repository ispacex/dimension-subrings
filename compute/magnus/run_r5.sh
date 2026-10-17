#!/bin/bash
# MATH-120: r5.g on NSH parallel shards (tm job; run from compute/magnus).  Output in $JOB_OUT:
# r5_<k>.log (one line per parent of type (5,2,1)), gap_<k>.out, summary.txt.
NSH=${NSH:-4}; GAP=${GAP:-gap}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
TOTAL=1396077
for k in $(seq 0 $((NSH - 1))); do
  (echo "SHARD:=$k;; NSHARD:=$NSH;; LOG:=\"$OUTD/r5_$k.log\";; PROG:=\"$OUTD/prog_$k\";;"
   cat r5.g) | $GAP -q -b --quitonbreak -o 3g > "$OUTD/gap_$k.out" 2>&1 &
done
while [ "$(jobs -r | wc -l)" -gt 0 ]; do
  [ -n "$JOB_ROOT" ] && echo "$(cat "$OUTD"/prog_* 2>/dev/null | awk '{s+=$1} END {print s+0}')/$TOTAL" > "$JOB_ROOT/progress"
  sleep 60
done
wait
{ grep -H -m3 "Error" "$OUTD"/gap_*.out && echo "GAP ERROR: some shard did not finish"
  tail -qn1 "$OUTD"/r5_*.log
  echo "passing parents:"; grep -h "pass=true" "$OUTD"/r5_*.log | sort -n | head -50
} | tee "$OUTD/summary.txt"
