#!/bin/bash
# MATH-469 (wiki 891 Sec. 14).  Usage: run_case469.sh [PAR]
#  1. wild: elementary configurations with one indecomposable block of size s (s = 6, 8, 10, 12; Sec. 14.2), checked
#     with the End-algebra criterion (control: without H every one must decompose) and with the modulo-27 model;
#  2. cover: Lemma 13.2(b) for chains modulo 27 -- every orbit has a member with K_9 in block normal form (all 48 capped
#     types s = 3, three types s = 4); control NF_NOPAIRS=1 must miss orbits;
#  3. nf: the modulo-27 model on all chains with K_9 in normal form, all capped types s = 3 (48) and s = 4 (192);
#     controls (drop B, D1, D2, Kt) must fail.
# Exit status 0 iff every check passes and every control fails as it must.
set -uo pipefail
PAR=${1:-4}
# MODE=all (default) or MODE=nf4part with PART=k/n: only step 3 for the k-th of n slices of the 192 types s = 4
MODE=${MODE:-all}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out469}; mkdir -p "$OUT/nf" "$OUT/cover"
st=0
if [ "$MODE" = nf4part ]; then
  python3 chain469.py types 4 | awk -v k="${PART%/*}" -v n="${PART#*/}" '(NR - 1) % n == k - 1' > "$OUT/t4part.txt"
  xargs -P "$PAR" -I{} sh -c 'python3 chain469.py nf {} > "'"$OUT"'/nf/$(echo {} | tr , _).txt" 2>&1' < "$OUT/t4part.txt"
  cat "$OUT"/nf/*.txt | grep '^NF' > "$OUT/nf.txt"
  echo "nf part $PART: types $(wc -l < "$OUT/nf.txt") of $(wc -l < "$OUT/t4part.txt"), with failures $(grep -vc 'FAILING 0 \[\]$' "$OUT/nf.txt")"
  [ "$(wc -l < "$OUT/nf.txt")" -eq "$(wc -l < "$OUT/t4part.txt")" ] && ! grep -vq 'FAILING 0 \[\]$' "$OUT/nf.txt"
  exit $?
fi
# 1. wild
: > "$OUT/wild.jsonl"
python3 wild469.py search 3,9,27,243,729,2187 0,1,2 4 2 300 1 >> "$OUT/wild.jsonl"
python3 wild469.py search 3,9,27,81,2187,6561,19683,59049 0,1,2,3 5 2 300 1 >> "$OUT/wild.jsonl"
python3 wild469.py search 3,9,27,81,243,6561,19683,59049,177147,531441 0,1,2,3,4 6 3 300 1 >> "$OUT/wild.jsonl"
python3 wild469.py search 3,3,9,9,27,27,243,243,729,729,2187,2187 0,1,2,3,4,5 7 3 400 1 >> "$OUT/wild.jsonl"
python3 wild469.py check "$OUT/wild.jsonl" > "$OUT/wild.txt" || st=1
grep -c '^{' "$OUT/wild.jsonl"; tail -1 "$OUT/wild.txt"
for s in 6 8 10 12; do echo "wild s=$s: $(grep -c "\"n\"" <(python3 -c "
import json
for l in open('$OUT/wild.jsonl'):
    c = json.loads(l)
    if len(c['d']) == $s: print(l.strip())"))"; done
# 2. cover
python3 chain469.py types 3 > "$OUT/t3.txt"; python3 chain469.py types 4 > "$OUT/t4.txt"
xargs -P "$PAR" -I{} sh -c 'python3 chain469.py cover {} > "'"$OUT"'/cover/$(echo {} | tr , _).txt" 2>&1' < "$OUT/t3.txt"
printf '3,9,27,27\n9,9,27,27\n3,27,27,81\n' | xargs -P "$PAR" -I{} sh -c 'python3 chain469.py cover {} > "'"$OUT"'/cover/$(echo {} | tr , _).txt" 2>&1'
cat "$OUT"/cover/*.txt | grep '^COVER' > "$OUT/cover.txt"
echo "cover: types $(wc -l < "$OUT/cover.txt"), with a miss $(grep -vc 'member 0$' "$OUT/cover.txt")"
[ "$(wc -l < "$OUT/cover.txt")" -eq 51 ] && ! grep -vq 'member 0$' "$OUT/cover.txt" || st=1
NF_NOPAIRS=1 python3 chain469.py cover 3,27,81 | tee "$OUT/cover_control.txt"
grep -q 'member 0$' "$OUT/cover_control.txt" && st=1
# 3. nf
cat "$OUT/t3.txt" "$OUT/t4.txt" | xargs -P "$PAR" -I{} sh -c 'python3 chain469.py nf {} > "'"$OUT"'/nf/$(echo {} | tr , _).txt" 2>&1'
cat "$OUT"/nf/*.txt | grep '^NF' > "$OUT/nf.txt"
echo "nf: types $(wc -l < "$OUT/nf.txt") (expected 240), with failures $(grep -vc 'FAILING 0 \[\]$' "$OUT/nf.txt")"
[ "$(wc -l < "$OUT/nf.txt")" -eq 240 ] && ! grep -vq 'FAILING 0 \[\]$' "$OUT/nf.txt" || st=1
: > "$OUT/nf_controls.txt"
for t in 9,27,27 3,9,27,27 9,9,27,27 27,27,27,27; do for c in B D1 D2 Kt; do
  python3 chain469.py nf $t $c | cut -c1-220 >> "$OUT/nf_controls.txt"; done; done
cat "$OUT/nf_controls.txt"
for c in B D1 D2 Kt; do echo "control drop $c: types with failures $(grep "drop \['$c'\]" "$OUT/nf_controls.txt" | grep -vc 'FAILING 0 ')"; done
[ "$(grep "drop \['D2'\]" "$OUT/nf_controls.txt" | grep -vc 'FAILING 0 ')" -ge 1 ] || st=1
echo "overall status $st"
exit $st
