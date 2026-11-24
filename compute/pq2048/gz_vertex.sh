#!/bin/bash
# gz_vertex.sh LIST OUTDIR MODE [PAR] [TIMEOUT] — the stage-B walk of single vertices (as m40-vertices40:
# tree.g, D = 4, LOGQ = 12, DUMPLEVEL 9, all rules, STREAM + STREAMFILE) with GZ off (MODE plain) or on
# (MODE gz), PAR at a time (default 1), each under timeout TIMEOUT (default 24h); for MATH-525.
# LIST: lines "NAME {"order":..,"code":..}".  Into OUTDIR/MODE: b_NAME.json (STATFILE), b_NAME.jsonl
# (OUTFILE), dump_NAME.jsonl (DUMPFILE), time_NAME (/usr/bin/time -v), r_NAME — one line
#   NAME MODE rc RC wall S peak_du_M M peak_tmp_M M
# where peak_du is the largest size of the vertex's TMPDIR and peak_tmp that plus the deleted files the
# pq processes in it hold open (sampled every 10 s).  A vertex starts only with MINFREE_G (default 40)
# GB free on OUTDIR's disk and is killed when its TMPDIR passes CAP_M (default 71680) MB (rc "cap").
# Run under pqrun.sh (with PQ2048_GZ=1 in its environment, or an anupq-src/ of ispacex/anupq pq-gz-library,
# for MODE gz); TMPDIR of a vertex: TMPBASE/MODE.NAME (default OUTDIR/tmp), removed after it.  Exit 1 unless
# every vertex ended with rc 0.
here=$(cd "$(dirname "$0")" && pwd)
list=$1 out=$2 mode=$3 par=${4:-1} to=${5:-24h}
case $mode in plain) gz=0;; gz) gz=1;; *) echo "MODE: plain or gz"; exit 2;; esac
export here out mode gz to MINFREE_G=${MINFREE_G:-40} CAP_M=${CAP_M:-71680} TMPBASE=${TMPBASE:-$out/tmp} GAPMEM=${GAPMEM:-2g}
export PQ2048_THMA=1 PQ2048_THMA1=1 PQ2048_THMB=1 PQ2048_TAH19=1 PQ2048_TIGHT=1 PQ2048_LIBROOT=1 PQ2048_NOSTAB=1
export PQ2048_STREAM=1 PQ2048_STREAMFILE=1 PQ2048_GZ=$gz
mkdir -p "$out/$mode/in" "$TMPBASE"
while read -r n j; do [ -n "$n" ] && echo "$j" > "$out/$mode/in/$n"; done < "$list"
one() {
  n=$1 w=$out/$mode t=$TMPBASE/$mode.$1
  [ -s "$w/r_$n" ] && return 0
  while [ "$(df --output=avail -BG "$out" | tail -1 | tr -dc 0-9)" -lt "$MINFREE_G" ]; do sleep 60; done
  rm -rf "$t"; mkdir -p "$t"
  printf '%s\n' "D:=4;; STEPRULES:=true;; COMPACT:=true;; NMAX:=11;; LOGQ:=12;; COVERMAX:=10;; STARTFILE:=\"$w/in/$n\";; DUMPLEVEL:=9;; DUMPFILE:=\"$w/dump_$n.jsonl\";; STATFILE:=\"$w/b_$n.json\";; OUTFILE:=\"$w/b_$n.jsonl\";;" > "$t.head"
  s=$(date +%s)
  setsid bash -c "cd '$here' && cat '$t.head' tree.g | TMPDIR='$t' timeout $to /usr/bin/time -v -o '$w/time_$n' '$GAP' -q -b -o $GAPMEM --quitonbreak > '$w/b_$n.log' 2>&1" & pid=$!
  pd=0 pt=0 cap=
  while kill -0 $pid 2>/dev/null; do
    sleep 10
    d=$(du -sb "$t" 2>/dev/null | cut -f1); d=${d:-0}; del=0
    for p in $(pgrep -x pq); do
      case "$(readlink /proc/$p/cwd 2>/dev/null)" in "$t"|"$t"/*) ;; *) continue;; esac
      for fd in /proc/$p/fd/*; do
        case "$(readlink "$fd" 2>/dev/null)" in *"(deleted)"*) z=$(stat -L -c %s "$fd" 2>/dev/null); del=$((del + ${z:-0}));; esac
      done
    done
    [ "$d" -gt "$pd" ] && pd=$d; [ $((d + del)) -gt "$pt" ] && pt=$((d + del))
    # the whole session of setsid (timeout puts gap and pq in a process group of their own)
    if [ $((d / 1048576)) -gt "$CAP_M" ]; then cap=cap; pkill -TERM -s $pid 2>/dev/null; kill -TERM -- -$pid 2>/dev/null; sleep 20; pkill -KILL -s $pid 2>/dev/null; kill -KILL -- -$pid 2>/dev/null; fi
  done
  wait $pid; rc=${cap:-$?}
  rm -rf "$t" "$t.head"
  echo "$n $mode rc $rc wall $(( $(date +%s) - s )) peak_du_M $((pd / 1048576)) peak_tmp_M $((pt / 1048576))" | tee "$w/r_$n"
}
export -f one
ls "$out/$mode/in" | xargs -P "$par" -I{} bash -c 'one {}'
# exit 1 unless every vertex ended with rc 0
for f in "$out/$mode"/in/*; do grep -q " rc 0 " "$out/$mode/r_${f##*/}" 2>/dev/null || exit 1; done
