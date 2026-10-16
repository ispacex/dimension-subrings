#!/bin/sh
# run_latb.sh CANDS.jsonl OUTDIR PARALLEL NMAX — variant B on a candidate file, split into PARALLEL
# parts: OUTDIR/p_<k>.jsonl (export, latb.g) and OUTDIR/b_<k>.jsonl (magnus_pres.py).  Needs
# GAP as $GAP (default gap) and a python with numpy as $PY (default python).
here=$(cd "$(dirname "$0")" && pwd)
in=$1 outdir=$2 par=${3:-3} nmax=${4:-5}
GAP=${GAP:-gap} PY=${PY:-python}
mkdir -p "$outdir"
n=$(wc -l < "$in")
per=$(( (n + par - 1) / par ))
split -l "$per" -d -a 2 "$in" "$outdir/part_"
cd "$here" || exit 2
for f in "$outdir"/part_*; do
  k=${f##*part_}
  (
    t0=$(date +%s.%N)
    printf 'INFILE:="%s";; OUTFILE:="%s";; NMAX:=%s;;\n' "$f" "$outdir/p_$k.jsonl" "$nmax" \
      | cat - latb.g | "$GAP" -q -b -o 4g > "$outdir/gap_$k.log" 2>&1
    t1=$(date +%s.%N)
    "$PY" magnus_pres.py < "$outdir/p_$k.jsonl" > "$outdir/b_$k.jsonl" 2> "$outdir/py_$k.log"
    t2=$(date +%s.%N)
    echo "{\"part\":\"$k\",\"gap_s\":$(echo "$t1 - $t0" | bc),\"py_s\":$(echo "$t2 - $t1" | bc)}" > "$outdir/time_$k.json"
    rm -f "$f"
  ) &
done
wait
