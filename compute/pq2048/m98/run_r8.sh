#!/bin/sh
# m98/run_r8.sh OUTDIR PQBIN -- run_r8.sh of D5-3 (mikh 68ec4a8) with the pq binary PQBIN (the
# patched one of D5-30) and the RSS sampler.
# run_r8.sh OUTDIR — rank 8 on 2^11 (D5-3) from the groups of order 512 of rank 8 in SmallGroups
# instead of from 2^8: PqDescendants(2^8, step 1) (GL(8,2) on a 36-dimensional multiplicator)
# ran out of memory twice.  The rank-8 groups of order 512 are exactly the step-1 descendants of
# 2^8 (|Phi| = 2), so the walk from them (tree.g STARTFILE, NMAX 10, LOGQ 11) is the walk of
# rank 8 below order 512; vertices of order 512 are 2-class 2, hence not parents.  Then the
# lattice (variant B) and the sums (rank_sum.py layout: A/a.json).  GAP $GAP, python $PY.
here=$(cd "$(dirname "$0")/.." && pwd)
pqbin=$2
"$here/m98/sample.sh" 5 "$JOB_OUT/mem.log" & sp=$!
out=$1
[ -n "$out" ] || { echo "usage: run_r8.sh OUTDIR"; exit 2; }
GAP=${GAP:-gap}; PY=${PY:-python3}
mkdir -p "$out/A"
[ -n "${JOB_ROOT:-}" ] && echo "0/2" > "$JOB_ROOT/progress"
if [ ! -s "$out/start512.jsonl" ]; then
  printf '%s\n' 'out := OutputTextFile("'"$out"'/start512.tmp", false);; SetPrintFormattingStatus(out, false);;' \
    'for i in [10494100 .. NrSmallGroups(512)] do G := SmallGroup(512, i); if RankPGroup(G) = 8 then WriteAll(out, Concatenation("{\"order\":512,\"code\":", String(CodePcGroup(G)), "}\n")); fi; od;;' \
    'CloseStream(out);; QUIT;' | "$GAP" -q -b -o 2g --quitonbreak || exit 1
  mv "$out/start512.tmp" "$out/start512.jsonl"
fi
echo "rank-8 groups of order 512: $(wc -l < "$out/start512.jsonl")"
if [ ! -s "$out/A/a.json" ]; then
  ( cd "$here" && printf '%s\n' "LoadPackage(\"anupq\");; ANUPQData.binary := \"$pqbin\";; D:=8;; STEPRULES:=true;; NMAX:=10;; LOGQ:=11;; COVERMAX:=10;; STARTFILE:=\"$out/start512.jsonl\";; STATFILE:=\"$out/A/a.json\";; OUTFILE:=\"$out/A/a.jsonl\";;" \
      | cat - tree.g | nice -n "${NICE:-15}" "$GAP" -q -b -o "${GAPMEM:-6g}" --quitonbreak ) > "$out/A/a.log" 2>&1 || { echo "tree failed"; exit 1; }
fi
[ -n "${JOB_ROOT:-}" ] && echo "1/2" > "$JOB_ROOT/progress"
"$PY" "$here/rank_sum.py" "$out" > "$out/summary.json" || exit 1
( cd "$here/../pq1024/latb" && "$PY" magnus_pres.py < "$out/c2048.jsonl" > "$out/b2048.jsonl" 2> "$out/lat.log" ) || exit 1
"$PY" "$here/rank_sum.py" "$out" > "$out/summary.json" || exit 1
[ -n "${JOB_ROOT:-}" ] && echo "2/2" > "$JOB_ROOT/progress"
cat "$out/summary.json"
kill $sp; tail -1 "$JOB_OUT/mem.log"
