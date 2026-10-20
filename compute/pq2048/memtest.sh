#!/bin/bash
# memtest.sh OUT TREE MEM P... — run the stage-B pieces P of runs/m74r5u (read only) with the tree file
# TREE into OUT, settings as rerun_pieces.sh, GAP under /usr/bin/time -v; compare with the originals.
here=$(cd "$(dirname "$0")" && pwd)
src=/home/leancheck/mikh-jobs/runs/m74r5u/B
out=$1 tree=$2 M=$3; shift 3
mkdir -p "$out"
for p in "$@"; do
  tag=$(basename "$tree" .g)
  cp "$src/in_$p" "$out/in_$p"
  rm -f "$out/b_$p.json" "$out/b_$p.jsonl" "$out/dump_$p.jsonl"
  dl="DUMPLEVEL:=9;; DUMPFILE:=\"$out/dump_$p.jsonl\";;"
  grep -q '"ids"' "$out/in_$p" && dl=""
  echo "$(date -u +%FT%TZ) piece $p $tag -o $M"
  ( cd "$here" && printf "%s\n" "D:=5;; STEPRULES:=${STEPRULES:-true};; COMPACT:=${COMPACT:-false};; NMAX:=10;; LOGQ:=11;; COVERMAX:=10;; STARTFILE:=\"$out/in_$p\";; $dl STATFILE:=\"$out/b_$p.json\";; OUTFILE:=\"$out/b_$p.jsonl\";;" \
    | cat - "$tree" | nice -n 15 /usr/bin/time -v "$GAP" -q -b -o "$M" --quitonbreak > "$out/b_$p.$tag.log" 2> "$out/b_$p.$tag.time" )
  grep -E "Maximum resident|Elapsed" "$out/b_$p.$tag.time" | sed 's/^\s*/  /'
  if [ -s "$out/b_$p.json" ]; then echo "  done"; else echo "  FAILED"; tail -4 "$out/b_$p.$tag.log"; fi
  if [ -s "$src/b_$p.json" ] && [ -s "$out/b_$p.json" ]; then
    cmp -s "$src/b_$p.jsonl" "$out/b_$p.jsonl" && echo "  jsonl same" || echo "  jsonl DIFF"
    [ -z "$dl" ] || { cmp -s "$src/dump_$p.jsonl" "$out/dump_$p.jsonl" && echo "  dump same" || echo "  dump DIFF"; }
    python3 -I - "$src/b_$p.json" "$out/b_$p.json" <<'EOF'
import json, sys
a, b = (json.load(open(f)) for f in sys.argv[1:3])
skip = lambda k: k.startswith("ms_") or "time" in k or "live" in k or k in ("rt", "wall")
diff = sorted(k for k in set(a) | set(b) if not skip(k) and a.get(k) != b.get(k))
print("  stat same (ignoring %s)" % sorted(k for k in a if skip(k)) if not diff else "  stat DIFF in %s" % diff)
EOF
  fi
  for f in b_$p.json b_$p.jsonl dump_$p.jsonl; do [ -f "$out/$f" ] && mv "$out/$f" "$out/$f.$tag"; done
done
