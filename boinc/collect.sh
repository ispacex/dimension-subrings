#!/bin/sh
# collect.sh FILESDIR RUNDIR [MANIFEST] — the results of a BUDA batch back into the layout of
# run_rank.sh.
#
# FILESDIR: the unpacked output zip of the batch page, files
#   batch_<id>__job_<name>.<k>__file_result.txt   (gzip-compressed or not, in any order)
# A result is matched to its piece by the name and, with MANIFEST (make_batch.sh's
# OUTDIR.manifest), by the sha256 of the piece's input recorded in the result's header, so the
# order of the jobs, of the files and the shuffle of stage C do not matter.  For each piece the
# replicas must exist and be byte-identical (the output of run_piece.sh is deterministic).  An
# agreed result is split into
#   RUNDIR/C/<name>.json, <name>.jsonl                    (c_* pieces)
#   RUNDIR/B/<name>.json, <name>.jsonl, dump_<id>.jsonl   (b_* pieces)
# which compute/pq2048/rank_sum.py reads as it reads a local run (without the ms_* timings;
# compact candidate lines are expanded by expand_compact.g, run_rank.sh COMPACT=true does it in L).
# Printed on stdout, one per line, the pieces to resubmit: "mismatch NAME" (replicas differ or
# a result is truncated), "missing NAME" (fewer than MINREP, default 2, replicas; with MANIFEST
# also pieces with none), "foreign NAME" (with MANIFEST: not in it, or for another input).
# Exit 0 when there are none.
set -eu
export LC_ALL=C
[ $# -eq 2 ] || [ $# -eq 3 ] || { echo "usage: collect.sh FILESDIR RUNDIR [MANIFEST]" >&2; exit 2; }
src=$1 run=$2 man=${3:-}
minrep=${MINREP:-2}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$run/B" "$run/C" "$tmp/r"
bad=0 ok=0
# unpack: one plain file per replica, named <name>.<k>
for f in "$src"/*__file_result.txt*; do
  [ -e "$f" ] || continue
  job=$(basename "$f" | sed -n 's/^batch_[0-9]*__job_\(.*\)__file_result\.txt.*$/\1/p')
  [ -n "$job" ] || continue
  if gzip -t "$f" 2>/dev/null; then gzip -dc "$f" > "$tmp/r/$job"; else cp "$f" "$tmp/r/$job"; fi
done
ls "$tmp/r" | sed 's/\.[0-9]*$//' | sort -u > "$tmp/names"
if [ -n "$man" ]; then
  grep -v '^#' "$man" | sort > "$tmp/want"
  cut -f1 "$tmp/want" | comm -23 - "$tmp/names" | sed 's/^/missing /'
  bad=$((bad + $(cut -f1 "$tmp/want" | comm -23 - "$tmp/names" | grep -c . || true)))
fi
while read -r name; do
  set -- "$tmp/r/$name".*
  first=$1 n=0 same=1
  for r in "$@"; do
    n=$((n + 1))
    tail -n 1 "$r" | grep -qx '# end' || same=0
    cmp -s "$first" "$r" || same=0
  done
  if [ -n "$man" ]; then
    want=$(awk -F'\t' -v n="$name" '$1 == n {print $2}' "$tmp/want")
    got=$(sed -n 's/^# input-sha256 //p' "$first")
    if [ -z "$want" ] || [ "$want" != "$got" ]; then echo "foreign $name"; bad=$((bad + 1)); continue; fi
  fi
  if [ "$same" -eq 0 ]; then echo "mismatch $name"; bad=$((bad + 1)); continue; fi
  if [ "$n" -lt "$minrep" ]; then echo "missing $name"; bad=$((bad + 1)); continue; fi
  case $name in b_*) d=B ;; *) d=C ;; esac
  sed -n 's/^# stat //p' "$first" > "$run/$d/$name.json"
  awk '/^# candidates /{s=1; next} /^# dump /{s=0} s' "$first" > "$run/$d/$name.jsonl"
  if [ "$d" = B ]; then
    awk '/^# dump /{s=1; next} /^# end$/{s=0} s' "$first" > "$run/B/dump_${name#b_}.jsonl"
  fi
  ok=$((ok + 1))
done < "$tmp/names"
echo "agreed $ok, to resubmit $bad" >&2
[ "$bad" -eq 0 ]
