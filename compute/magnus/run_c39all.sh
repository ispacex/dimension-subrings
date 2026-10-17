#!/bin/bash
# MATH-120: the order-3^9 run, part d <= 4, on NSH parallel shards (tm job; run from compute/magnus).
# Per shard: c39all.g writes survivors to a FIFO; they are kept gzipped and decided by d5z.py on
# the fly, so the presentations (~20 KB each) never sit uncompressed on disk.
# Output in $JOB_OUT: d5z_<k>.jsonl (verdicts), cand_<k>.jsonl.gz, c39_<k>.log, summary.txt.
# EXTRA: GAP assignments put before c39all.g, e.g. 'IDS:=[75400..75500];;' for a test run.
NSH=${NSH:-5}; EXTRA=${EXTRA:-}; GAP=${GAP:-gap}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
TOTAL=1396077
for k in $(seq 0 $((NSH - 1))); do
  f="$OUTD/fifo_$k"; rm -f "$f"; mkfifo "$f"
  (tee >(gzip > "$OUTD/cand_$k.jsonl.gz") < "$f" | python d5z.py > "$OUTD/d5z_$k.jsonl") &
  (echo "SHARD:=$k;; NSHARD:=$NSH;; OUT:=\"$f\";; LOG:=\"$OUTD/c39_$k.log\";; PROG:=\"$OUTD/prog_$k\";; $EXTRA"
   cat c39all.g) | $GAP -q -b -o 3g > "$OUTD/gap_$k.out" 2>&1 &
done
while [ "$(jobs -r | wc -l)" -gt 0 ]; do
  [ -n "$JOB_ROOT" ] && echo "$(cat "$OUTD"/prog_* 2>/dev/null | awk '{s+=$1} END {print s+0}')/$TOTAL" > "$JOB_ROOT/progress"
  sleep 60
done
wait
rm -f "$OUTD"/fifo_*
{ tail -qn1 "$OUTD"/c39_*.log
  cat "$OUTD"/d5z_*.jsonl | python -c "
import json, sys, collections
r = [json.loads(l) for l in sys.stdin]
print(len(r), 'decided;', collections.Counter((x['verdict'], x['cert'], x['ctrl_z_in_D4'], any(x['ctrl_gens_in_D2'])) for x in r))"
} | tee "$OUTD/summary.txt"
