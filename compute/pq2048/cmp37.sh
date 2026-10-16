#!/bin/sh
# cmp37.sh OUTDIR [PARALLEL] [TIMEOUT] — the check on 2^10: the candidates of run_check1024.sh (OUTDIR/desc)
# against the 2^10 run, parent by parent (cmp37.g, at most TIMEOUT seconds each, default 7200), then
# OUTDIR/summary.json (cmp37.py summary).  A parent whose stat file exists is not run again.
here=$(cd "$(dirname "$0")" && pwd)
out=$1 par=${2:-6} tmo=${3:-7200}
[ -n "$out" ] || { echo "usage: cmp37.sh OUTDIR [PARALLEL] [TIMEOUT]"; exit 2; }
mkdir -p "$out/cmp"
GAP=${GAP:-gap}
python3 "$here/cmp37.py" tasks "$out/desc" "$out/split" > "$out/tasks.txt" || exit 2
echo "parents to compare: $(wc -l < "$out/tasks.txt")"
export here out tmo GAP
xargs -L 1 -P "$par" sh -c '
  [ -s "$out/cmp/cmp_$0.json" ] && exit 0
  cd "$here/../pq1024" && printf "%s\n" "PARENT:=$0;; KS:=$1;; NEWFILE:=\"$2\";; STATFILE:=\"$out/cmp/cmp_$0.json\";;" \
    | cat - ../pq2048/cmp37.g | timeout "$tmo" nice -n "${NICE:-15}" "$GAP" -q -b -o 4g --quitonbreak > "$out/cmp/cmp_$0.log" 2>&1
  true' < "$out/tasks.txt"
python3 "$here/cmp37.py" summary "$out/desc" "$out/cmp" > "$out/summary.json"
cat "$out/summary.json"
grep -q '"same": true' "$out/summary.json"
