#!/bin/bash
# MATH-403: dn3.g for 3^6, 3^7 (one shard each) and 3^8 (NSH contiguous id ranges), then dnz.py on
# all survivors.  Output in $JOB_OUT: dn3_<K>_<s>.jsonl, gap_<K>_<s>.out, dnz.jsonl, summary.txt.
cd "$(dirname "$0")"
NSH=${NSH:-8}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"; GAP=${GAP:-$JOB_CACHE/gap/gap}
PY=${PY:-$(ls -d $JOB_CACHE/venv-*/bin/python | head -1)}
run() { # K FROM TO tag
  echo "K:=$1;; FROM:=$2;; TO:=$3;; OUT:=\"$OUTD/dn3_$4\";;" | cat - dn3.g | $GAP -q -b --quitonbreak -o 1500m > "$OUTD/gap_$4.out" 2>&1
}
run 6 1 100000 6_0 &
run 7 1 100000 7_0 &
N8=1396077; S=$(( (N8 + NSH - 1) / NSH ))
for s in $(seq 0 $((NSH - 1))); do run 8 $((s * S + 1)) $(((s + 1) * S)) 8_$s & done
wait
cat "$OUTD"/dn3_*.jsonl | $PY dnz.py > "$OUTD/dnz.jsonl"
{ grep -H -m3 "Error" "$OUTD"/gap_*.out && echo "GAP ERROR"
  grep -h "^3\^" "$OUTD"/gap_*.out
  # completeness: every group of each order looked at exactly once
  for K in 6 7 8; do
    got=$(grep -h "^3\^$K " "$OUTD"/gap_*.out | sed 's/.*groups=\([0-9]*\).*/\1/' | awk '{s+=$1} END {print s+0}')
    want=$(case $K in 6) echo 504;; 7) echo 9310;; 8) echo 1396077;; esac)
    [ "$got" = "$want" ] && echo "3^$K complete: $got groups" || echo "3^$K INCOMPLETE: $got of $want groups"
  done
  $PY -c "
import json, collections
r = [json.loads(l) for l in open('$OUTD/dnz.jsonl')]
print(len(r), 'decided;', collections.Counter((x['K'], x['n'], x['verdict'], x['ctrl_z_in_Dkz'], any(x['ctrl_gens_in_D2'])) for x in r))"
} | tee "$OUTD/summary.txt"
