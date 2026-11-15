#!/bin/bash
# MATH-479 (wiki 891 Sec. 18): the controls of the lift-orbit reduction of the MATH-472 check (red479.py).
# Usage: run_case479.sh controls [PAR]
#   (a) s = 3, 4: the reduced check ('red479.py run') on every capped type without 9, all A: the numbers of pair
#       orbits, non-elementary pair orbits and lifts per type must equal those of 's5_472.py run' (MATH-472 main:
#       s=3 4 396 / 18 244, s=4 135 104 / 1 978 124), FAILING 0;
#   (b) 'cmp' (every lift checked AND the reduced run, verdict per lift orbit): s = 4 on the three (d, A) of MATH-472's
#       'full' control, with the full model (FAILING 0 both ways) and without (D2) (failing lifts > 0, every failing
#       lift's orbit has a failing representative: lost-orbits 0); s = 5 on the smallest pilot pair of MATH-472
#       ([3,27,81,729,2187], A = {}) with the full model and without (D2);
#       In every cmp run (also without (D2), where verdicts vary) each lift must have the verdict of its orbit's
#       representative: mixed-members 0.
#   (c) 'act' (affine map on the lifts vs the HNF image of the lattice under the integer Schreier element): 300
#       samples on each of four s = 5 (d, A) and two s = 4 (d, A): mismatch 0.
# Progress: $JOB_ROOT/progress.  Exit status 1 iff a claim fails or a control does not fail.
set -uo pipefail
MODE=$1; PAR=${2:-4}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out479}; mkdir -p "$OUT"
PROG=${JOB_ROOT:-$OUT}/progress
st=0
git -C .. rev-parse HEAD 2>/dev/null || true
[ "$MODE" = controls ] || { echo "unknown mode $MODE"; exit 2; }

echo "== (a) s = 3, 4: reduced vs MATH-472 counts"
for S in 3 4; do python3 red479.py types $S; done | awk '{print "run " $0}' > "$OUT/a.args"
NA=$(wc -l < "$OUT/a.args"); echo "0/$NA" > "$PROG"
( while :; do n=$(grep -c '^S5NER ' "$OUT/a.txt" 2>/dev/null); echo "${n:-0}/$NA" > "$PROG"; sleep 30; done ) & PP=$!
xargs -P "$PAR" -L 1 python3 red479.py < "$OUT/a.args" > "$OUT/a.txt" 2>&1
kill $PP 2>/dev/null
n=$(grep -c '^S5NER ' "$OUT/a.txt"); f=$(awk '/^S5NER /{s+=$NF} END{print s+0}' "$OUT/a.txt")
awk '/^S5NER /{split($3,t,","); S=length(t); n[S]++; o[S]+=$11; l[S]+=$13; r[S]+=$15; z[S]+=$17; sec[S]+=$19}
     END{for(S in n) printf "  s=%d: types %d, non-elementary pair orbits %d, lifts %d, lift orbits checked %d, sigma!=0 %d, cpu-sec %.0f\n", S, n[S], o[S], l[S], r[S], z[S], sec[S]}' "$OUT/a.txt" | sort | tee "$OUT/a.sum"
echo "(a) lines $n of $NA, FAILING $f"; [ "$n" -eq "$NA" ] && [ "$f" -eq 0 ] || st=1
grep -q '^  s=3: types 27, non-elementary pair orbits 4396, lifts 18244,' "$OUT/a.sum" || { echo "(a) s=3 counts differ from MATH-472"; st=1; }
grep -q '^  s=4: types 107, non-elementary pair orbits 135104, lifts 1978124,' "$OUT/a.sum" || { echo "(a) s=4 counts differ from MATH-472"; st=1; }

echo "== (b) cmp: every lift vs the reduced run"
printf '%s\n' "cmp 3,27,81,729 0,2" "cmp 27,27,81,243 1" "cmp 3,3,27,729 0,3" \
  "cmp 3,27,81,729 0,2 D2" "cmp 27,27,81,243 1 D2" "cmp 3,3,27,729 0,3 D2" \
  "cmp 3,27,81,729,2187 -" "cmp 3,27,81,729,2187 - D2" > "$OUT/b.args"
xargs -P "$PAR" -L 1 python3 red479.py < "$OUT/b.args" > "$OUT/b.txt" 2>&1; cat "$OUT/b.txt"
[ "$(grep -c '^S5NECMP' "$OUT/b.txt")" -eq 8 ] || st=1
# full model: no failures either way, no lost orbits
awk '/^S5NECMP/ && $7=="[]" {if ($15 || $17 || $21) bad++} END{exit bad+0}' "$OUT/b.txt" || { echo "(b) full model: failures or lost orbits"; st=1; }
# without (D2): failing lifts > 0 overall, lost-orbits 0 everywhere, and the failing representatives found
c=$(awk '/^S5NECMP/ && $7 ~ /D2/ {f+=$15; r+=$17; if ($21) bad++} END{if (bad) print -1; else if (r>0 && f>0) print f; else print 0}' "$OUT/b.txt")
echo "control without D2: failing lifts $c (must be > 0, and every failing orbit represented)"; [ "$c" -gt 0 ] || st=1
mixed=$(awk '/^S5NECMP/{s+=$19} END{print s+0}' "$OUT/b.txt"); echo "lift-orbit members with another verdict than their representative (all runs, also without D2): $mixed (must be 0)"
[ "$mixed" -eq 0 ] || st=1

echo "== (c) act: affine map vs the HNF image of the lattice"
printf '%s\n' "act 3,27,81,729,2187 0,2 300 1" "act 27,27,81,243,729 1,3 300 2" "act 3,3,27,81,729 0,3 300 3" \
  "act 3,27,81,729,2187 - 300 4" "act 3,27,81,729 0,2 300 5" "act 27,27,81,243 1 300 6" > "$OUT/c.args"
xargs -P "$PAR" -L 1 python3 red479.py < "$OUT/c.args" > "$OUT/c.txt" 2>&1; cat "$OUT/c.txt"
[ "$(grep -c '^S5NEACT' "$OUT/c.txt")" -eq 6 ] && [ "$(awk '/^S5NEACT/{s+=$11} END{print s+0}' "$OUT/c.txt")" -eq 0 ] || st=1
echo "overall ok=$((1 - st))"
exit $st
