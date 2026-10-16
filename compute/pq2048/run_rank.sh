#!/bin/sh
# run_rank.sh D OUTDIR [PARALLEL] [L1] [L2] [CHUNK] [BCHUNK] — tree.g for rank D up to parents of order
# 2^10 (candidates of order 2^11, LOGQ = 11), split into pieces that run PARALLEL at a time
# (README.ru.md «Ранг 4 на 2^11»):
#   A  one process from 2^D; vertices of order >= 2^L1 (default 8) are dumped, not expanded;
#   B  the dumped vertices of order < 2^L2 (default 9), BCHUNK (default 20) per piece: their
#      subtrees, vertices of order >= 2^L2 dumped;
#   C  the vertices of order 2^L2 .. 2^9 (A's and B's), CHUNK (default 40) per piece: their subtrees
#      (for L2 = 9: step 1 to the parents of order 2^10 and the cover search on them);
#   L  the candidates of order 2^11 renumbered into OUTDIR/c2048.jsonl, the lattice (variant B,
#      ../pq1024/latb/magnus_pres.py) into OUTDIR/b2048.jsonl, the sums into OUTDIR/summary.json.
# A piece whose stat file exists is not run again, so the script can be restarted after a stop.
# STEPRULES (default true, the step rules of steps.g) is passed to tree.g; GAP's memory: GAPMEM_A for A
# (default 10g), GAPMEM for the pieces (default 6g).  GAP is $GAP (default gap); python with python-flint from remote/py-env.sh for L.
here=$(cd "$(dirname "$0")" && pwd)
[ $# -ge 2 ] || { echo "usage: run_rank.sh D OUTDIR [PARALLEL] [L1] [L2] [CHUNK] [BCHUNK]"; exit 2; }
d=$1 out=$2 par=${3:-6} l1=${4:-8} l2=${5:-9} chunk=${6:-40} bchunk=${7:-20}
GAP=${GAP:-gap}; PY=${PY:-python3}
STEPRULES=${STEPRULES:-true}; GAPMEM_A=${GAPMEM_A:-10g}; GAPMEM=${GAPMEM:-6g}
export here GAP d out STEPRULES GAPMEM
mkdir -p "$out/A" "$out/B" "$out/C" "$out/Cin"
log() { echo "$(date -u +%FT%TZ) $*"; }
tree() { # NAME EXTRA — one tree.g piece into $out/NAME.{json,jsonl,log}
  [ -s "$out/$1.json" ] && return 0
  ( cd "$here" && printf '%s\n' "D:=$d;; STEPRULES:=${STEPRULES:-true};; NMAX:=10;; LOGQ:=11;; COVERMAX:=10;; $2 STATFILE:=\"$out/$1.json\";; OUTFILE:=\"$out/$1.jsonl\";;" \
      | cat - tree.g | nice -n "${NICE:-15}" "$GAP" -q -b -o "$GAPMEM_A" --quitonbreak ) > "$out/$1.log" 2>&1
}
# Progress for a job monitor (when run under remote/ds-remote.sh): "DONE/TOTAL" pieces into $JOB_ROOT/progress every
# 30 s.  TOTAL grows as the stages split: 1 during A, 1 + B's pieces during B, then 1 + B + C.
if [ -n "${JOB_ROOT:-}" ]; then
  ( while :; do
      n() { ls "$out/$1" 2>/dev/null | grep -c "$2"; }
      a=0; [ -s "$out/A/a.json" ] && a=1
      echo "$((a + $(n B '^b_.*json$') + $(n C '^c_.*json$')))/$((1 + $(n B '^in_') + $(n Cin '^c_')))" > "$JOB_ROOT/progress"
      sleep 30
    done ) &
  ppid_loop=$!
  trap 'kill $ppid_loop 2>/dev/null' EXIT
fi
t0=$(date +%s)
log "A: rank $d from 2^$d, dump at 2^$l1"
tree A/a "DUMPLEVEL:=$l1;; DUMPFILE:=\"$out/A/dump.jsonl\";;" || { log "A failed"; exit 1; }
# B: the dumped vertices of order < 2^l2, BCHUNK per piece
lim=$((1 << l2))
if [ ! -s "$out/B/in.jsonl" ]; then
  awk -v lim="$lim" -F'[:,]' '$2 < lim' "$out/A/dump.jsonl" > "$out/B/in.tmp"
  [ -s "$out/B/in.tmp" ] && split -l "$bchunk" -a 4 -d "$out/B/in.tmp" "$out/B/in_"
  mv "$out/B/in.tmp" "$out/B/in.jsonl"
fi
nb=$(ls "$out/B" | grep -c '^in_')
log "B: $(wc -l < "$out/B/in.jsonl") vertices of order < 2^$l2 in $nb pieces, dump at 2^$l2"
ls "$out/B" | grep '^in_' | sed 's/^in_//' | xargs -P "$par" -I{} sh -c '
  [ -s "$out/B/b_{}.json" ] && exit 0
  cd "$here" && printf "%s\n" "D:=$d;; STEPRULES:=${STEPRULES:-true};; NMAX:=10;; LOGQ:=11;; COVERMAX:=10;; STARTFILE:=\"$out/B/in_{}\";; DUMPLEVEL:='"$l2"';; DUMPFILE:=\"$out/B/dump_{}.jsonl\";; STATFILE:=\"$out/B/b_{}.json\";; OUTFILE:=\"$out/B/b_{}.jsonl\";;" \
    | cat - tree.g | nice -n "${NICE:-15}" "$GAP" -q -b -o "$GAPMEM" --quitonbreak > "$out/B/b_{}.log" 2>&1'
nbd=$(ls "$out/B"/b_*.json 2>/dev/null | wc -l)
[ "$nbd" -eq "$nb" ] || { log "B: $nbd of $nb pieces done"; exit 1; }
# C: the vertices of order >= 2^l2, CHUNK per piece
if [ ! -s "$out/Cin/all.jsonl" ]; then
  { awk -v lim="$lim" -F'[:,]' '$2 >= lim' "$out/A/dump.jsonl"; cat "$out/B"/dump_*.jsonl 2>/dev/null; } > "$out/Cin/all.tmp"
  split -l "$chunk" -a 4 -d "$out/Cin/all.tmp" "$out/Cin/c_"
  mv "$out/Cin/all.tmp" "$out/Cin/all.jsonl"
fi
nc=$(ls "$out/Cin"/c_* | wc -l)
log "C: $(wc -l < "$out/Cin/all.jsonl") vertices of order >= 2^$l2 in $nc pieces"
ls "$out/Cin" | grep '^c_' | xargs -P "$par" -I{} sh -c '
  [ -s "$out/C/{}.json" ] && exit 0
  cd "$here" && printf "%s\n" "D:=$d;; STEPRULES:=${STEPRULES:-true};; NMAX:=10;; LOGQ:=11;; COVERMAX:=10;; STARTFILE:=\"$out/Cin/{}\";; STATFILE:=\"$out/C/{}.json\";; OUTFILE:=\"$out/C/{}.jsonl\";;" \
    | cat - tree.g | nice -n "${NICE:-15}" "$GAP" -q -b -o "$GAPMEM" --quitonbreak > "$out/C/{}.log" 2>&1'
ncd=$(ls "$out/C"/c_*.json 2>/dev/null | wc -l)
[ "$ncd" -eq "$nc" ] || { log "C: $ncd of $nc pieces done"; exit 1; }
log "L: candidates and the lattice"
"$PY" "$here/rank_sum.py" "$out" > "$out/summary.json" || exit 1
( cd "$here/../pq1024/latb" && "$PY" magnus_pres.py < "$out/c2048.jsonl" > "$out/b2048.jsonl" 2> "$out/lat.log" ) || { log "lattice failed"; exit 1; }
"$PY" "$here/rank_sum.py" "$out" > "$out/summary.json" || exit 1
[ -n "${JOB_ROOT:-}" ] && echo "$((1 + nb + nc))/$((1 + nb + nc))" > "$JOB_ROOT/progress"
cat "$out/summary.json"
log "done, wall $(( $(date +%s) - t0 )) s"
