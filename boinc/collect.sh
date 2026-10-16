#!/bin/sh
# collect.sh FILESDIR RUNDIR — the results of a BUDA batch back into the layout of run_rank.sh.
#
# FILESDIR: the unpacked output zip of the batch page, files
#   batch_<id>__job_<name>.<k>__file_result.txt   (gzip-compressed or not)
# For each piece <name> the replicas must exist and be byte-identical (the output of run_piece.sh
# is deterministic; the header carries the sha256 of the input).  An agreed result is split into
#   RUNDIR/C/<name>.json, <name>.jsonl            (c_* pieces)
#   RUNDIR/B/<name>.json, <name>.jsonl, dump_<id>.jsonl   (b_* pieces)
# which compute/pq2048/rank_sum.py reads as it reads a local run (without the ms_* timings).
# Pieces that disagree or have fewer than MINREP (default 2) replicas are listed on stdout as
# "mismatch NAME" / "missing NAME"; such pieces are resubmitted.  Exit 0 when there are none.
set -eu
[ $# -eq 2 ] || { echo "usage: collect.sh FILESDIR RUNDIR" >&2; exit 2; }
src=$1 run=$2
minrep=${MINREP:-2}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$run/B" "$run/C"
bad=0 ok=0
# unpack: one plain file per replica, named <name>.<k>
for f in "$src"/*__file_result.txt*; do
  [ -e "$f" ] || continue
  job=$(basename "$f" | sed -n 's/^batch_[0-9]*__job_\(.*\)__file_result\.txt.*$/\1/p')
  [ -n "$job" ] || continue
  if gzip -t "$f" 2>/dev/null; then gzip -dc "$f" > "$tmp/$job"; else cp "$f" "$tmp/$job"; fi
done
for name in $(ls "$tmp" | sed 's/\.[0-9]*$//' | sort -u); do
  set -- "$tmp/$name".*
  first=$1 n=0 same=1
  for r in "$@"; do
    n=$((n + 1))
    tail -n 1 "$r" | grep -qx '# end' || same=0
    cmp -s "$first" "$r" || same=0
  done
  if [ "$same" -eq 0 ]; then echo "mismatch $name"; bad=$((bad + 1)); continue; fi
  if [ "$n" -lt "$minrep" ]; then echo "missing $name"; bad=$((bad + 1)); continue; fi
  case $name in b_*) d=B ;; *) d=C ;; esac
  sed -n 's/^# stat //p' "$first" > "$run/$d/$name.json"
  awk '/^# candidates /{s=1; next} /^# dump /{s=0} s' "$first" > "$run/$d/$name.jsonl"
  if [ "$d" = B ]; then
    awk '/^# dump /{s=1; next} /^# end$/{s=0} s' "$first" > "$run/B/dump_${name#b_}.jsonl"
  fi
  ok=$((ok + 1))
done
echo "agreed $ok, to resubmit $bad" >&2
[ "$bad" -eq 0 ]
