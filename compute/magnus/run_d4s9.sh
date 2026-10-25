#!/bin/bash
# MATH-415: d4s9.g over all SmallGroup(512, i) of p-class >= 3 (the ranges of ../sieve512.sh;
# class 3 needs p-class >= 3), chunks of CH ids dealt round-robin to NSH shards; each shard then
# runs d4z.py on its survivors.  First the controls: Rips's group (d4s9_ctrl.g, must give
# z IN D_4) and the whole order 256 through the same sieve (must give no z in D_4).
# RANGES overrides the id ranges ("a:b a:b", for a test).
# Output in $JOB_OUT: d4s9_<s>_<a>.jsonl, gap_<s>.out, d4z_<s>.jsonl, ctrl*, summary.txt.
cd "$(dirname "$0")"
NSH=${NSH:-10}; CH=${CH:-20000}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"; GAP=${GAP:-$JOB_CACHE/gap/gap}
RANGES=${RANGES:-"2:2044 2046:60903 67613:420514 6249624:7532392 10481222:10493061 10494174:10494200"}
PY=${PY:-$(ls -d $JOB_CACHE/venv-*/bin/python | head -1)}
gapr() { $GAP -q -b --quitonbreak -o 4g; }
echo "OUT:=\"$OUTD/ctrl_rips.jsonl\";;" | cat - d4s9_ctrl.g | gapr > "$OUTD/ctrl_rips.out" 2>&1
$PY d4z.py < "$OUTD/ctrl_rips.jsonl" > "$OUTD/ctrl_rips_z.jsonl"
echo "ORD:=256;; FROM:=1;; TO:=56092;; OUT:=\"$OUTD/ctrl256\";;" | cat - d4s9.g | gapr > "$OUTD/ctrl256.out" 2>&1
$PY d4z.py < "$OUTD/ctrl256.jsonl" > "$OUTD/ctrl256_z.jsonl"
chunks() {
  for r in $RANGES; do
    a=${r%:*}; b=${r#*:}
    while [ "$a" -le "$b" ]; do e=$((a + CH - 1)); [ "$e" -gt "$b" ] && e=$b; echo "$a $e"; a=$((e + 1)); done
  done
}
chunks > "$OUTD/chunks.txt"; TOTAL=$(wc -l < "$OUTD/chunks.txt")
for s in $(seq 0 $((NSH - 1))); do
  (awk -v s=$s -v n=$NSH '(NR - 1) % n == s' "$OUTD/chunks.txt" | while read a e; do
     echo "ORD:=512;; FROM:=$a;; TO:=$e;; OUT:=\"$OUTD/d4s9_${s}_$a\";;" | cat - d4s9.g | gapr >> "$OUTD/gap_$s.out" 2>&1
   done
   cat "$OUTD"/d4s9_${s}_*.jsonl | $PY d4z.py > "$OUTD/d4z_$s.jsonl") &
done
while [ "$(jobs -r | wc -l)" -gt 0 ]; do
  [ -n "$JOB_ROOT" ] && echo "$(cat "$OUTD"/gap_*.out 2>/dev/null | grep -c '^512 ids')/$TOTAL" > "$JOB_ROOT/progress"
  sleep 60
done
wait
{ grep -H -m3 "Error" "$OUTD"/gap_*.out "$OUTD"/ctrl*.out && echo "GAP ERROR"
  cat "$OUTD/ctrl_rips.out"; echo "ctrl rips: $(cat "$OUTD/ctrl_rips_z.jsonl")"
  cat "$OUTD/ctrl256.out"; echo "ctrl 256 verdicts:"; $PY -c "
import json, collections; print(collections.Counter(json.loads(l)['verdict'] for l in open('$OUTD/ctrl256_z.jsonl')))"
  got=$(cat "$OUTD"/gap_*.out | grep -c '^512 ids'); [ "$got" = "$TOTAL" ] && echo "chunks complete: $got" || echo "chunks INCOMPLETE: $got of $TOTAL"
  cat "$OUTD"/gap_*.out | grep '^512 ids' | $PY -c "
import re, sys
t = [0, 0, 0, 0]
for l in sys.stdin:
    m = re.search(r'groups=(\d+) class3=(\d+) Z cyclic=(\d+) survivors \S+=(\d+)', l)
    t = [a + int(b) for a, b in zip(t, m.groups())]
print('groups, class 3, Z cyclic, survivors:', t)"
  ns=$(cat "$OUTD"/d4s9_*.jsonl | wc -l); nd=$(cat "$OUTD"/d4z_*.jsonl | wc -l)
  [ "$ns" = "$nd" ] && echo "survivors decided: $nd" || echo "survivors UNDECIDED: $nd of $ns"
  cat "$OUTD"/d4z_*.jsonl | $PY -c "
import json, sys, collections
r = [json.loads(l) for l in sys.stdin]
print(len(r), 'decided;', collections.Counter((x['k'], x['verdict'], x['ctrl_z_in_Dkz'], any(x['ctrl_gens_in_D2'])) for x in r))"
} | tee "$OUTD/summary.txt"
