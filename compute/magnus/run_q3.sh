#!/bin/bash
# MATH-127 q3: run q3.g on 4 shards plus the explicit family; logs in $JOB_OUT.
set -e
export PATH=$JOB_CACHE/bin:$PATH
cd "$(dirname "$0")"
OUT=${JOB_OUT:-.}
(echo 'EXPLICIT:=true;'; echo 'Read("q3.g");') | gap -q -b --quitonbreak -o 4g > "$OUT/q3_explicit.log" 2>&1 &
for s in 0 1 2 3; do
  (echo "SHARD:=$s; NSHARD:=4; NDESC:=${NDESC:-5}; LOG:=\"$OUT/q3_$s.csv\"; PROG:=\"$OUT/q3_$s.prog\";"; echo 'Read("q3.g");') \
    | gap -q -b --quitonbreak -o 4g > "$OUT/q3_$s.gaplog" 2>&1 &
done
wait
{ cat "$OUT"/q3_explicit.log; tail -qn 1 "$OUT"/q3_?.csv
  grep -h "Error" "$OUT"/q3_*.gaplog | head -3
  echo "histogram: logZ,logZg2,pclass,logM,logN,classS,log g4S,log g5S,log S'' -> count"
  grep -hv -e '^desc' -e '^shard' "$OUT"/q3_?.csv | cut -d, -f2- | sort | uniq -c
  echo "N>1 vs (logZg2, exp g2, P^3<=Z, log P^3, log P^3∩g3):"
  grep -hv -e '^desc' -e '^shard' "$OUT"/q3_?.csv | awk -F, '{print "N>1=" ($6>0), "Zg2=" $3, "expg2=" $11, "P3inZ=" $12, "P3=" $13, "P3g3=" $14}' | sort | uniq -c
  echo "logZg2 vs nucleus nontrivial:"
  grep -hv -e '^desc' -e '^shard' "$OUT"/q3_?.csv | awk -F, '{k=$3" N>1="($6>0); c[k]++} END {for (k in c) print c[k], "Zg2=" k}'
  grep -h '^desc' "$OUT"/q3_?.csv
  echo "first ids with N>1:"; grep -hv -e '^desc' -e '^shard' "$OUT"/q3_?.csv | awk -F, '$6>0' | sort -n | head -5
  echo "first ids with Zg2=2, N=1:"; grep -hv -e '^desc' -e '^shard' "$OUT"/q3_?.csv | awk -F, '$3==2 && $6==0' | sort -n | head -5
} | tee "$OUT/summary.txt"
