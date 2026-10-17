#!/bin/bash
# MATH-120: chk38.g on the order-3^9 candidates of a run_c39all.sh job (tm job; run from
# compute/magnus).  CANDDIR: that job's out/ with cand_<k>.jsonl.gz; one GAP per file.
# Output in $JOB_OUT: chk_<k>.out, summary.txt.
GAP=${GAP:-gap}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
TOTAL=$(for f in "$CANDDIR"/cand_*.jsonl.gz; do zcat "$f"; done | wc -l)
for f in "$CANDDIR"/cand_*.jsonl.gz; do
  k=$(basename "$f" .jsonl.gz); k=${k#cand_}
  zcat "$f" > "$OUTD/in_$k.jsonl"
  (echo "CHKIN:=\"$OUTD/in_$k.jsonl\";; CHKORDER:=3^9;; PROG:=\"$OUTD/prog_$k\";;"; cat chk38.g) |
    $GAP -q -b --quitonbreak -o 3g > "$OUTD/chk_$k.out" 2>&1 &
done
while [ "$(jobs -r | wc -l)" -gt 0 ]; do
  [ -n "$JOB_ROOT" ] && echo "$(cat "$OUTD"/prog_* 2>/dev/null | awk '{s+=$1} END {print s+0}')/$TOTAL" > "$JOB_ROOT/progress"
  sleep 60
done
wait
rm -f "$OUTD"/in_*.jsonl
{ echo "candidates in $CANDDIR: $TOTAL"
  grep -H -m3 "Error" "$OUTD"/chk_*.out && echo "GAP ERROR"
  grep -h "BAD" "$OUTD"/chk_*.out | head -20
  grep -H "checked" "$OUTD"/chk_*.out
} | tee "$OUTD/summary.txt"
