#!/bin/bash
# MATH-403: dn39.g over all parents of dn39_parents.csv, NSH round-robin shards; each shard runs
# GAP and then dnz.py on its own survivors.  Output in $JOB_OUT: dn39_<s>.jsonl, dn39_<s>.log,
# dnz_<s>.jsonl, gap_<s>.out, summary.txt; progress = parents done / total.
cd "$(dirname "$0")"
NSH=${NSH:-10}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"; GAP=${GAP:-$JOB_CACHE/gap/gap}
PY=${PY:-$(ls -d $JOB_CACHE/venv-*/bin/python | head -1)}
TOTAL=$(wc -l < dn39_parents.csv)
for s in $(seq 0 $((NSH - 1))); do
  IDS=$(awk -F, -v s=$s -v n=$NSH '(NR - 1) % n == s {print $1}' dn39_parents.csv | paste -sd, -)
  (echo "PARENTS:=[$IDS];; OUT:=\"$OUTD/dn39_$s.jsonl\";; LOG:=\"$OUTD/dn39_$s.log\";;" | cat - dn39.g |
     $GAP -q -b --quitonbreak -o 3g > "$OUTD/gap_$s.out" 2>&1
   $PY dnz.py < "$OUTD/dn39_$s.jsonl" > "$OUTD/dnz_$s.jsonl") &
done
while [ "$(jobs -r | wc -l)" -gt 0 ]; do
  [ -n "$JOB_ROOT" ] && echo "$(cat "$OUTD"/dn39_*.log 2>/dev/null | wc -l)/$TOTAL" > "$JOB_ROOT/progress"
  sleep 60
done
wait
{ grep -H -m3 "Error" "$OUTD"/gap_*.out && echo "GAP ERROR"
  grep -h "^parents=" "$OUTD"/gap_*.out
  got=$(cat "$OUTD"/dn39_*.log | wc -l); [ "$got" = "$TOTAL" ] && echo "parents complete: $got" || echo "parents INCOMPLETE: $got of $TOTAL"
  ns=$(cat "$OUTD"/dn39_*.jsonl | wc -l); nd=$(cat "$OUTD"/dnz_*.jsonl | wc -l)
  [ "$ns" = "$nd" ] && echo "survivors decided: $nd" || echo "survivors UNDECIDED: $nd of $ns"
  cat "$OUTD"/dnz_*.jsonl | $PY -c "
import json, sys, collections
r = [json.loads(l) for l in sys.stdin]
print(len(r), 'decided;', collections.Counter((x['k'], x['n'], x['verdict'], x['ctrl_z_in_Dkz'], any(x['ctrl_gens_in_D2'])) for x in r))"
} | tee "$OUTD/summary.txt"
