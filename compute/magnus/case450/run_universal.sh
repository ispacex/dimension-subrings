#!/bin/bash
# MATH-450: universal model (universal.g) for all "capped" types with s generators (wiki 891 Sec. 11).
# Usage (tm job, tree root, cache mikh): bash compute/magnus/case450/run_universal.sh S [PAR] [DROP]
# A type d_1 <= ... <= d_s enters the model only through: d_1 = 3 or d_1 >= 9, the ratios d_{i+1}/d_i mod 9 (1, 3, or
# >= 9), (d_i - 1)/2 mod 9 and gcd(9, d_i); so the types d_1 in {3, 9}, d_{i+1}/d_i in {1, 3, 9} represent all.
set -euo pipefail
export PATH=$JOB_CACHE/bin:$PATH
S=${1:-3}; PAR=${2:-4}; DROP=${3:-}
cd "$(dirname "$0")"
OUT=${JOB_OUT:-$PWD/out-universal}; mkdir -p "$OUT"
types=$(python3 -c "
import itertools
S=$S
for d1 in (3,9):
  for gaps in itertools.product((1,3,9), repeat=S-1):
    d=[d1]
    for g in gaps: d.append(d[-1]*g)
    print(','.join(map(str,d)))")
dropg='[]'
if [ -n "$DROP" ]; then dropg="[\"$(echo "$DROP" | sed 's/,/","/g')\"]"; fi
export OUT dropg
echo "$types" | xargs -P "$PAR" -I{} bash -c '
  t={}; f=$OUT/u_$(echo $t | tr , _).txt
  printf "DT := [%s];; DROP := %s;; OUTF := \"%s\";; Read(\"universal.g\");; QUIT;\n" "$t" "$dropg" "$f" > "$f.g"
  timeout 20000 gap -q -b -o 3g "$f.g" > "$f.log" 2>&1 || echo "FAILED $t" >> "$f"
'
cat "$OUT"/u_*.txt | tee "$OUT/summary.txt"
want=$(( 2 * 3 ** (S - 1) )); got=$(grep -c '^TYPE' "$OUT/summary.txt" || true)
echo "types: $got of $want"
[ "$got" -eq "$want" ] && ! grep -q -E "FAILING=[1-9]|FAILED" "$OUT/summary.txt"
