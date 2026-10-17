#!/bin/bash
# MATH-127 q3: run q3.g on 4 shards plus the explicit family; logs in $JOB_OUT.
set -e
export PATH=$JOB_CACHE/bin:$PATH
cd "$(dirname "$0")"
OUT=${JOB_OUT:-.}
(echo 'EXPLICIT:=true;'; echo 'Read("q3.g");') | gap -q -b --quitonbreak -o 4g > "$OUT/q3_explicit.log" 2>&1 &
for s in 0 1 2 3; do
  (echo "SHARD:=$s; NSHARD:=4; NDESC:=5; LOG:=\"$OUT/q3_$s.csv\"; PROG:=\"$OUT/q3_$s.prog\";"; echo 'Read("q3.g");') \
    | gap -q -b --quitonbreak -o 4g > "$OUT/q3_$s.gaplog" 2>&1 &
done
wait
cat "$OUT"/q3_explicit.log; tail -n 1 "$OUT"/q3_?.csv
