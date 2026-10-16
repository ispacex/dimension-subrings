#!/bin/sh
# run_cover.sh SCRIPT.g NN DEDUP OUTDIR PARALLEL < chunks  — run desc1c.g (or cover_check.g with
# NN, IDFROM, IDTO) on the chunks "FROM TO" read from stdin, PARALLEL at a time; stat files
# OUTDIR/d<2NN>_<FROM>.json, candidates OUTDIR/c<2NN>_<FROM>.jsonl, logs next to them; $EXTRA
# replaces the default 'LIB:=false;; FULL:=false;;' of cover_check.g.
here=$(cd "$(dirname "$0")" && pwd)
script=$1 nn=$2 dedup=$3 outdir=$4 par=${5:-3}
mkdir -p "$outdir"
GAPFLAGS=--quitonbreak
export here script nn dedup outdir EXTRA GAPFLAGS
xargs -L 1 -P "$par" sh -c '
  o=$((2 * nn))
  "$here/run_gap.sh" "$script" "NN:=$nn;; IDFROM:=$0;; IDTO:=$1;; PRUNE:=true;; DEDUP:=$dedup;; ${EXTRA:-LIB:=false;; FULL:=false;;} OUTFILE:=\"$outdir/c${o}_$0.jsonl\";; STATFILE:=\"$outdir/d${o}_$0.json\";;" > "$outdir/d${o}_$0.log" 2>&1'
