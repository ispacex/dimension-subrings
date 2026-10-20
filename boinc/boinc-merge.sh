#!/bin/bash
# boinc-merge.sh TGZ RUNDIR — put collect.sh results (B/b_NNNN.json, .jsonl, dump_NNNN.jsonl) into
# RUNDIR/B for the pieces that have no stat file there yet; never overwrites.
set -eu
tgz=$1 run=$2; t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
tar xzf "$tgz" -C "$t"
added=0 skipped=0
for j in "$t"/B/b_*.json; do
  n=$(basename "$j" .json); id=${n#b_}
  if [ -s "$run/B/$n.json" ]; then skipped=$((skipped+1)); continue; fi
  [ -f "$run/B/in_$id" ] || { echo "no input in_$id in $run/B" >&2; exit 1; }
  cp "$t/B/$n.jsonl" "$run/B/$n.jsonl.boinc"; mv "$run/B/$n.jsonl.boinc" "$run/B/$n.jsonl"
  [ -f "$t/B/dump_$id.jsonl" ] && { cp "$t/B/dump_$id.jsonl" "$run/B/dump_$id.jsonl.boinc"; mv "$run/B/dump_$id.jsonl.boinc" "$run/B/dump_$id.jsonl"; }
  cp "$j" "$run/B/$n.json.boinc"; mv "$run/B/$n.json.boinc" "$run/B/$n.json"   # the stat file last
  echo "boinc $(date -u +%FT%TZ)" > "$run/B/$n.log"
  added=$((added+1))
done
echo "added $added, already there $skipped, done now $(ls "$run"/B | grep -c '^b_.*\.json$') of $(ls "$run"/B | grep -c '^in_')"
