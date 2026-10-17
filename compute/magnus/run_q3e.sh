#!/bin/bash
# MATH-127 q3: q3e.g on 4 shards + the explicit family; summary in $JOB_OUT/summary_e.txt.
export PATH=$JOB_CACHE/bin:$PATH
cd "$(dirname "$0")"
OUT=${JOB_OUT:-.}
(echo 'EXPLICIT:=true;'; echo 'Read("q3e.g");') | gap -q -b --quitonbreak -o 4g > "$OUT/q3e_explicit.log" 2>&1 &
for s in 0 1 2 3; do
  (echo "SHARD:=$s; NSHARD:=4; LOG:=\"$OUT/q3e_$s.csv\";"; echo 'Read("q3e.g");') \
    | gap -q -b --quitonbreak -o 4g > "$OUT/q3e_$s.gaplog" 2>&1 &
done
wait
{ grep -v Syntax "$OUT"/q3e_explicit.log | grep -v '\^'; grep -h shard "$OUT"/q3e_?.csv
  grep -h -A3 Error "$OUT"/q3e_*.gaplog | head
  echo "count logN,N1,N2,N3,E:"; grep -hv shard "$OUT"/q3e_?.csv | cut -d, -f2- | sort | uniq -c
  echo "mismatches (N>1 xor all of N1..E):"
  grep -hv shard "$OUT"/q3e_?.csv | awk -F, '{p=($3=="true"&&$4=="true"&&$5=="true"&&$6=="true"); if (p != ($2>0)) print}' | head -20
} | tee "$OUT/summary_e.txt"
