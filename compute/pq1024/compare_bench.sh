#!/bin/sh
# compare_bench.sh REFDIR NEWDIR OUTDIR PARALLEL < chunks — compare1024.g on every chunk "FROM TO":
# REFDIR/c1024_FROM.jsonl (desc1.g) against NEWDIR/c1024_FROM.jsonl (desc1c.g).
here=$(cd "$(dirname "$0")" && pwd)
ref=$1 new=$2 outdir=$3 par=${4:-2}
mkdir -p "$outdir"
export here ref new outdir
GAPFLAGS=--quitonbreak; export GAPFLAGS
xargs -L 1 -P "$par" sh -c '
  "$here/run_gap.sh" compare1024.g "REFFILE:=\"$ref/c1024_$0.jsonl\";; NEWFILE:=\"$new/c1024_$0.jsonl\";; STATFILE:=\"$outdir/cmp_$0.json\";;" > "$outdir/cmp_$0.log" 2>&1'
