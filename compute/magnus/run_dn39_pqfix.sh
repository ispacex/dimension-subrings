#!/bin/bash
# MATH-403: the GAP part of run_dn39.sh (dn39.g over all of dn39_parents.csv, same NSH shards) again,
# with the ANUPQ in which the defects of the audit are fixed (branch `correctness` of ispacex/anupq,
# https://ispacex.github.io/gap/); no dnz.py.  The survivors' presentations dn39_<s>.jsonl and the
# per-parent counts dn39_<s>.log are to be compared with those of run_dn39.sh.
cd "$(dirname "$0")"
NSH=${NSH:-10}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"; GAP=${GAP:-$JOB_CACHE/gap-pqfix/gap}
TOTAL=$(wc -l < dn39_parents.csv)
git -C "$(dirname "$GAP")/pkg/anupq" log --oneline -1 | tee "$OUTD/anupq.txt"
for s in $(seq 0 $((NSH - 1))); do
  IDS=$(awk -F, -v s=$s -v n=$NSH '(NR - 1) % n == s {print $1}' dn39_parents.csv | paste -sd, -)
  (echo "PARENTS:=[$IDS];; OUT:=\"$OUTD/dn39_$s.jsonl\";; LOG:=\"$OUTD/dn39_$s.log\";;" | cat - dn39.g |
     $GAP -q -b --quitonbreak -o 3g > "$OUTD/gap_$s.out" 2>&1) &
done
wait
{ grep -H -m3 "Error" "$OUTD"/gap_*.out && echo "GAP ERROR"
  grep -h "^parents=" "$OUTD"/gap_*.out
  got=$(cat "$OUTD"/dn39_*.log | wc -l); [ "$got" = "$TOTAL" ] && echo "parents complete: $got" || echo "parents INCOMPLETE: $got of $TOTAL"
  echo "survivors: $(cat "$OUTD"/dn39_*.jsonl | wc -l)"
} | tee "$OUTD/summary.txt"
