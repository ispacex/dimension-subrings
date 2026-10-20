#!/bin/bash
# run_parts.sh D OUTDIR PIECE LIBFILE PARTS PARALLEL MEM — stage-B piece PIECE of OUTDIR (one vertex and
# one deferred step) walked in parts: LIBFILE is pq's GAP_library file of that step (kept, e.g. a hard
# link to the one the whole run reads; CH_FILEKEEP), cut by split_library.sh into PARTS ranges of
# groups, each walked by tree.g with CH_FILERANGE (PARALLEL at a time, GAP -o MEM, the last ranges
# first: there the groups cost most); merge_parts.py joins the results into OUTDIR/par/PIECE/b_PIECE.*.
# Nothing in OUTDIR/B is touched.  Same settings as rerun_pieces.sh.
set -u
here=$(cd "$(dirname "$0")" && pwd)
l2=${L2:-9}; GAP=${GAP:-gap}; PY=${PY:-python3}
d=$1 out=$2 piece=$3 lib=$4 parts=$5 par=$6 M=$7
w="$out/par/$piece"; mkdir -p "$w"
[ -s "$w/ranges" ] || "$here/split_library.sh" "$lib" "$w" "$parts" || exit 1
dl=1; grep -q '"ids"' "$out/B/in_$piece" && dl=""
export here d out piece w M GAP l2 dl
sort -r "$w/ranges" | xargs -P "$par" -L 1 sh -c '
  i=$0 a=$1 b=$2
  [ -s "$w/b_$i.json" ] && exit 0
  dump=""; [ -n "$dl" ] && dump="DUMPLEVEL:=$l2;; DUMPFILE:=\"$w/dump_$i.jsonl\";;"
  t="${TMPDIR:-/tmp}/part_${piece}_$i"; mkdir -p "$t"
  cd "$here" && printf "%s\n" "D:=$d;; STEPRULES:=${STEPRULES:-true};; COMPACT:=${COMPACT:-false};; NMAX:=10;; LOGQ:=11;; COVERMAX:=10;; STARTFILE:=\"$out/B/in_$piece\";; $dump CH_FILERANGE:=[$a,$b];; CH_FILEPART:=\"$w/part_$i\";; STATFILE:=\"$w/b_$i.json\";; OUTFILE:=\"$w/b_$i.jsonl\";;" \
    | cat - tree.g | TMPDIR="$t" nice -n "${NICE:-15}" "$GAP" -q -b -o "$M" --quitonbreak > "$w/b_$i.log" 2>&1
  rm -rf "$t"
  [ -s "$w/b_$i.json" ] && echo "$(date -u +%FT%TZ) part $i ($a..$b) done" || { echo "$(date -u +%FT%TZ) part $i FAILED"; tail -3 "$w/b_$i.log"; }'
nd=$(ls "$w" | grep -c '^b_[0-9]*\.json$'); np=$(wc -l < "$w/ranges")
[ "$nd" -eq "$np" ] || { echo "parts done: $nd of $np"; exit 1; }
"$PY" "$here/merge_parts.py" "$w" "$w/b_$piece"
