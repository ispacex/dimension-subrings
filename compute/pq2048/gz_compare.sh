#!/bin/sh
# gz_compare.sh DIR1 DIR2 NAME... — the results of gz_vertex.sh (or of the same walk elsewhere: b_NAME.json,
# b_NAME.jsonl, dump_NAME.jsonl) in DIR1 and DIR2 for each NAME: the STATFILE counts (every field but the
# times ms_*) and the sorted OUTFILE and DUMPFILE lines must agree.  Prints one line per vertex; exit 1 on
# any difference or missing file.
a=$1 b=$2; shift 2; bad=0
counts() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps({k:v for k,v in sorted(d.items()) if not k.startswith("ms_")}))' "$1"; }
for n in "$@"; do
  r=ok
  for f in "b_$n.json" "b_$n.jsonl" "dump_$n.jsonl"; do [ -e "$a/$f" ] && [ -e "$b/$f" ] || r="missing $f"; done
  if [ "$r" = ok ]; then
    [ "$(counts "$a/b_$n.json")" = "$(counts "$b/b_$n.json")" ] || r="STAT DIFFERS"
    [ "$(sort "$a/b_$n.jsonl" | md5sum)" = "$(sort "$b/b_$n.jsonl" | md5sum)" ] || r="$r OUTFILE DIFFERS"
    [ "$(sort "$a/dump_$n.jsonl" | md5sum)" = "$(sort "$b/dump_$n.jsonl" | md5sum)" ] || r="$r DUMPFILE DIFFERS"
  fi
  [ "$r" = ok ] || bad=1
  echo "$n: $r; $(counts "$a/b_$n.json" 2>/dev/null | cut -c1-300); out $(wc -l < "$a/b_$n.jsonl" 2>/dev/null) dump $(wc -l < "$a/dump_$n.jsonl" 2>/dev/null) lines"
done
exit $bad
