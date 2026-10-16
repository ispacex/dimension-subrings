#!/bin/sh
# run_check1024.sh OUTDIR [PARALLEL] — the check of the pruning on order 2^10 (README
# «Сверка на 2^10»): ../pq1024/desc1c.g on all 858 chunks of parents of order 512
# (chunks1024.txt = make_jobs.py main) with PFILTER = (Г_10), DEDUP, PARALLEL processes at a time.
# Stat files OUTDIR/desc/d1024_FROM.json, candidates OUTDIR/desc/c1024_FROM.jsonl.  A chunk whose
# stat file exists is not run again, so the script can be restarted.  Then cmp37.sh compares
# the candidates of the 2^10 run (../pq1024/results/candidates.csv).  GAP is $GAP (default gap).
here=$(cd "$(dirname "$0")" && pwd)
out=$1 par=${2:-6}
[ -n "$out" ] || { echo "usage: run_check1024.sh OUTDIR [PARALLEL]"; exit 2; }
mkdir -p "$out/desc"
GAP=${GAP:-gap}; export GAP
t0=$(date +%s)
todo=$(mktemp)
while read -r a b; do
  [ -s "$out/desc/d1024_$a.json" ] || echo "$a $b"
done < "$here/chunks1024.txt" > "$todo"
echo "chunks to run: $(wc -l < "$todo") of $(wc -l < "$here/chunks1024.txt")"
EXTRA="Read(\"../pq2048/prune.g\");; PFILTER := R -> PR_Data(R, 10).p5b;;" \
  "$here/../pq1024/run_cover.sh" desc1c.g 512 true "$out/desc" "$par" < "$todo"
n=$(ls "$out/desc"/d1024_*.json 2>/dev/null | wc -l)
echo "stat files: $n of 858, wall $(( $(date +%s) - t0 )) s"
[ "$n" -eq 858 ]
