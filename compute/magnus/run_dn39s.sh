#!/bin/bash
# MATH-403: dn39s.g on NSH contiguous id ranges of SmallGroup(3^8, .); CSV and counts in $JOB_OUT.
cd "$(dirname "$0")"
NSH=${NSH:-10}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"; GAP=${GAP:-$JOB_CACHE/gap/gap}
N8=1396077; S=$(( (N8 + NSH - 1) / NSH ))
for s in $(seq 0 $((NSH - 1))); do
  (echo "FROM:=$((s * S + 1));; TO:=$(((s + 1) * S));; OUT:=\"$OUTD/dn39s_$s.csv\";;" | cat - dn39s.g |
   $GAP -q -b --quitonbreak -o 1500m > "$OUTD/gap_$s.out" 2>&1) &
done
wait
{ grep -H -m3 "Error" "$OUTD"/gap_*.out && echo "GAP ERROR"
  grep -h "^3\^8 ids" "$OUTD"/gap_*.out
  got=$(grep -h "^3\^8 ids" "$OUTD"/gap_*.out | sed 's/.*groups=\([0-9]*\).*/\1/' | paste -sd+ - | bc)
  [ "$got" = "$N8" ] && echo "groups complete: $got" || echo "groups INCOMPLETE: $got of $N8"
  cat "$OUTD"/dn39s_*.csv | awk -F, '$NF=="true" {n++; m[$4]++; h+=(3^$4-1)/2} END {print "pass:", n, "hyperplanes in all:", h; for (k in m) print "  log3|M| =", k, ":", m[k]}'
} | tee "$OUTD/summary.txt"
