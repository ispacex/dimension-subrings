#!/bin/sh
# Lattice pass over the candidates of the main run, as they appear: every finished chunk's
# candidates (c1024_*.jsonl with its d1024_*.json present) are collected into lat/cands.jsonl,
# and ../run.py (restartable: skips groups already in lat/out.jsonl) computes D_n for them.
# Stops after a pass made once the main queue has finished.  A pass takes as many lattice jobs
# as the GAP queue leaves free of 8.
cd "$(dirname "$0")" || exit 2
mkdir -p lat
PY=${PY:-python3}
while true; do
  fin=0; grep -q "all done" out/queue_main.log 2>/dev/null && fin=1
  : > lat/cands.tmp
  for s in out/main/d1024_*.json; do
    c=out/main/c1024_${s#out/main/d1024_}; c=${c%.json}.jsonl
    [ -s "$c" ] && cat "$c" >> lat/cands.tmp
  done
  mv lat/cands.tmp lat/cands.jsonl
  # share the 8 allowed processes with the GAP queue: whatever it does not use, at least 1
  jobs=${LATJOBS:-$((8 - $(pgrep -c -f "[r]un_gap.sh desc1")))}; [ "$jobs" -lt 1 ] && jobs=1
  (cd .. && nice -n 15 "$PY" run.py pq1024/lat/cands.jsonl pq1024/lat/out.jsonl --jobs "$jobs")
  echo "$(date +%H:%M:%S) cands=$(wc -l < lat/cands.jsonl) done=$(wc -l < lat/out.jsonl)"
  [ $fin = 1 ] && break
  sleep 300
done
