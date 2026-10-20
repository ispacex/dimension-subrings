#!/bin/bash
# rerun_pieces.sh D OUTDIR MEM [ID...] — rerun (the given B pieces, or by default), one at a time with GAP -o MEM, the stage-B pieces of OUTDIR whose
# log says "reached the pre-set memory limit" (a piece killed for memory leaves no stat file); same
# settings as run_rank.sh's piece_b.  Waits for nothing: pieces still running are left alone.
here=$(cd "$(dirname "$0")" && pwd)
l2=${L2:-9}; GAP=${GAP:-gap}
d=$1 out=$2 M=$3; shift 3
list=$(if [ $# -gt 0 ]; then printf '%s\n' "$@"; else for f in "$out"/B/b_*.log; do grep -q "reached the pre-set memory limit" "$f" && basename "$f" .log | sed 's/^b_//'; done; fi)
for p in $list; do
  f="$out/B/b_$p.log"
  [ -s "$out/B/b_$p.json" ] && { echo "$p already done"; continue; }
  echo "$(date -u +%FT%TZ) piece $p, -o $M"
  [ -f "$f" ] && mv "$f" "$out/B/b_$p.log.oom"; rm -f "$out/B/b_$p.jsonl" "$out/B/dump_$p.jsonl"
  dl="DUMPLEVEL:=$l2;; DUMPFILE:=\"$out/B/dump_$p.jsonl\";;"
  grep -q '"ids"' "$out/B/in_$p" && dl=""
  # a GAP killed for memory leaves its gaptempdir (pq's output, tens of GB) behind: a TMPDIR of
  # the piece's own, removed whatever happened
  t="${TMPDIR:-/tmp}/piece_$p"; mkdir -p "$t"
  ( cd "$here" && printf "%s\n" "D:=$d;; STEPRULES:=${STEPRULES:-true};; COMPACT:=${COMPACT:-false};; NMAX:=10;; LOGQ:=11;; COVERMAX:=10;; STARTFILE:=\"$out/B/in_$p\";; $dl STATFILE:=\"$out/B/b_$p.json\";; OUTFILE:=\"$out/B/b_$p.jsonl\";;" \
    | cat - tree.g | TMPDIR="$t" nice -n "${NICE:-15}" "$GAP" -q -b -o "$M" --quitonbreak > "$out/B/b_$p.log" 2>&1 )
  rm -rf "$t"
  [ -s "$out/B/b_$p.json" ] && echo "  done" || { echo "  FAILED"; tail -5 "$out/B/b_$p.log"; }
done
