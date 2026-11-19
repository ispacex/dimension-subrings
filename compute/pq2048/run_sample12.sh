#!/bin/bash
# run_sample12.sh LOGQ OUTDIR PAR TLIM SPEC... — the sampling estimate (sample12.g, README "Estimate for 2^12").
# SPEC = NN:D:NSAMP[:SEED] — NSAMP random ids of rank D among the groups of order NN (uniform in the
# rank's id block, blocks.g), each run as its own GAP process with at most TLIM seconds and GAPMEM
# (default 6g) of memory; PAR at a time.  An id that runs out of time or memory keeps only its start
# line in OUTDIR/s_NN_D.jsonl (est12.py counts it as heavy).  M2, M3, RULES pass to sample12.g.
# GAP is $GAP (pqrun.sh sets it to the wrapper with the fixed pq and PQ_NOSTAB).
set -u
here=$(cd "$(dirname "$0")" && pwd)
logq=$1 out=$2 par=$3 tlim=$4; shift 4
GAP=${GAP:-gap}; GAPMEM=${GAPMEM:-6g}; M2=${M2:-3}; M3=${M3:-2}; RULES=${RULES:-true}
mkdir -p "$out/ids"
export here logq out tlim GAP GAPMEM M2 M3 RULES
for spec in "$@"; do
  IFS=: read nn d ns seed <<< "$spec"; seed=${seed:-1}
  bf="$out/blocks_$nn.json"
  if [ ! -s "$bf" ]; then
    ( cd "$here" && printf 'NN:=%s;; OUTFILE:="%s";;\n' "$nn" "$bf" | cat - blocks.g | "$GAP" -q -b -o 4g --quitonbreak ) > "$out/blocks_$nn.log" 2>&1
  fi
  cat "$bf"
  python3 - "$bf" "$d" "$ns" "$seed" > "$out/ids/${nn}_${d}.txt" <<'PY'
import json, random, sys
b = json.load(open(sys.argv[1]))["blocks"]
d, ns, seed = sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
if d not in b: sys.exit(0)
lo, hi = b[d]
r = random.Random(f"{seed}:{lo}:{hi}")
ids = list(range(lo, hi + 1)) if hi - lo + 1 <= ns else r.sample(range(lo, hi + 1), ns)
print("\n".join(map(str, sorted(ids))))
PY
  echo "order $nn rank $d: $(wc -l < "$out/ids/${nn}_${d}.txt") ids"
  one() { # NN D ID
    f="$out/s_$1_$2.jsonl"; t="$out/ids/one_$1_$2_$3"
    grep -q "^{\"id\":$3," "$f" 2>/dev/null && return 0
    echo "$3" > "$t.txt"
    ( cd "$here" && printf 'NN:=%s;; D:=%s;; LOGQ:=%s;; IDFILE:="%s";; OUTFILE:="%s";; M2:=%s;; M3:=%s;; SEED:=%s;; RULES:=%s;;\n' \
        "$1" "$2" "$logq" "$t.txt" "$t.jsonl" "$M2" "$M3" "$3" "$RULES" | cat - sample12.g \
        | timeout -k 10 "$tlim" "$GAP" -q -b -o "$GAPMEM" --quitonbreak ) > "$t.log" 2>&1
    rc=$?
    if grep -q '^{"id"' "$t.jsonl" 2>/dev/null; then grep '^{"id"' "$t.jsonl" >> "$f"
    else echo "{\"heavy\":$3,\"rc\":$rc}" >> "$f"; fi
    rm -f "$t.txt"
  }
  export -f one
  xargs -P "$par" -I{} bash -c "one $nn $d {}" < "$out/ids/${nn}_${d}.txt"
done
