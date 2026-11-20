#!/bin/bash
# run_roots12.sh LOGQ OUTDIR PAR TLIM SPEC... — the elementary abelian roots of the estimate (roots12.g).
# SPEC = D:NS — NS random quotients of the p-cover of 2^D (one GAP process each, at most TLIM seconds,
# GAPMEM memory, PAR at a time).  OUTDIR/r_D.jsonl: the counts line, then one line per sample, or
# {"heavy":j,"rc":..} when it ran out of time or memory.  M3 passes to roots12.g.
set -u
here=$(cd "$(dirname "$0")" && pwd)
logq=$1 out=$2 par=$3 tlim=$4; shift 4
GAP=${GAP:-gap}; GAPMEM=${GAPMEM:-6g}; M3=${M3:-2}
mkdir -p "$out/one"
gtmp=${JOB_ROOT:-$out}/gtmp; mkdir -p "$gtmp"
export gtmp here logq out tlim GAP GAPMEM M3
for spec in "$@"; do
  IFS=: read d ns <<< "$spec"
  one() { # D J (J = 0: only the counts line)
    t="$out/one/r_$1_$2"
    # own TMPDIR on disk: pq files of a killed process stay out of the tmpfs /tmp (ax42) and are removed
    tmp=$(mktemp -d "$gtmp/g.XXXXXX")
    ( cd "$here" && printf 'D:=%s;; LOGQ:=%s;; NS:=%s;; SEED:=%s;; OUTFILE:="%s";; M3:=%s;;\n' \
        "$1" "$logq" "$([ "$2" = 0 ] && echo 0 || echo 1)" "$((1000 * $2 + $1))" "$t.jsonl" "$M3" | cat - roots12.g \
        | TMPDIR="$tmp" timeout -k 10 "$tlim" "$GAP" -q -b -o "$GAPMEM" --quitonbreak ) > "$t.log" 2>&1
    rc=$?
    rm -rf "$tmp"
    f="$out/r_$1.jsonl"
    if [ "$2" = 0 ]; then grep '^{"D"' "$t.jsonl" >> "$f"; return; fi
    if grep -q '^{"j"' "$t.jsonl" 2>/dev/null; then grep '^{"j"' "$t.jsonl" | sed "s/^{\"j\":1,/{\"j\":$2,/" >> "$f"
    else echo "{\"heavy\":$2,\"rc\":$rc}" >> "$f"; fi
  }
  export -f one
  one "$d" 0
  seq 1 "$ns" | xargs -P "$par" -I{} bash -c "one $d {}"
  echo "rank $d: $(grep -c '^{"j"' "$out/r_$d.jsonl") done, $(grep -c heavy "$out/r_$d.jsonl") heavy"
done
