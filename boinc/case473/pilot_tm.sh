#!/bin/bash
# pilot_tm.sh -- the BOINC pieces of case473 run natively on a tm runner, through the same entry point the image runs
# (run_piece.py), make_batch.py and collect.py as for a BUDA batch (boinc/case473/README.md, "Pilot").
#
#   pilot_tm.sh s5 PAR NTH NPARTS REFJOB...  sample of s = 5: every NTH type of the S5RUN lines of the MATH-473 jobs
#                                            REFJOB (their out/run.txt on this runner), all their non-(T1) A, a batch
#                                            with 2 replicas (make_batch.py -p NPARTS), every job run here, then
#                                            collect.py --ref: replicas agree, the manifest is covered, and each type's
#                                            line equals the one of the MATH-473 log (without 'sec').  Then a control
#                                            batch without (D2) on the first sampled type (must fail), and the
#                                            cross-host batch (below).
#   pilot_tm.sh s6 PAR N SEED [NPARTS REPS]  N pairs (d, A) of s = 6 (the first N in the order of make_batch.py --seed
#                                            SEED), each split into NPARTS parts (default 1), NPARTS entries per piece, REPS replicas
#                                            (default 1): timings and memory per pair, replicas compared.
#   pilot_tm.sh cross PAR                    the cross-host batch only.
#   pilot_tm.sh ne5ref PAR                   MATH-479: the 4 pairs (d, A) of the MATH-472 pilot (ax42/tm/20261115-071913-
#                                            case472-pilot5-4006323) as pieces of kind case472 (lift-orbit reduction,
#                                            2 replicas) and case472full (every lift, 1 replica, each pair in 8 parts);
#                                            collect.py --pairs; the per-pair lines must equal those of the pilot's log
#                                            (case472full: all numbers; case472: pair orbits, non-elementary orbits,
#                                            lifts = chains, FAILING 0); then a control batch without (D2) (must fail).
#   pilot_tm.sh ne5 PAR N SEED [NPARTS REPS] MATH-479: N pairs (d, A) of the case472 run at s = 5 (the first N in the
#                                            order of make_batch.py --seed SEED, over all 13 664), kind case472:
#                                            timings and memory per pair, replicas compared (default 1 part, 2 replicas).
# The cross-host batch: 4 fixed small s = 5 pieces of case473 (as in MATH-478) and 3 small pieces of case472 (two at
# s = 4, one part of an s = 5 pair); the sha256 of their results without the '# code' line are printed (CROSS lines),
# the same on every runner and in the image.  Results, batches and stderr (timings, peak memory) go to $JOB_OUT.
set -uo pipefail
MODE=$1; shift
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/../../compute/magnus/case473" && . ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/out478}; mkdir -p "$OUT"
PROG=${JOB_ROOT:-$OUT}/progress
export CASE473_COMMIT=${CASE473_COMMIT:-$(git -C "$HERE" rev-parse HEAD 2>/dev/null || echo unknown)}
RP=$HERE/run_piece.py
st=0
runbatch() {  # runbatch DIR PAR: run_piece.py in every job directory, stderr beside the result
  local dir=$1 par=$2 tot
  tot=$(find "$dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
  ( while :; do echo "$(find "$dir" -name result.txt | wc -l)/$tot" > "$PROG"; sleep 20; done ) & local pp=$!
  find "$dir" -mindepth 1 -maxdepth 1 -type d | sort | \
    xargs -P "$par" -I{} sh -c 'cd "{}" && python3 "$0" piece.txt result.txt 2> stderr.txt || echo "exit $? in {}"' "$RP"
  kill $pp 2>/dev/null; echo "$(find "$dir" -name result.txt | wc -l)/$tot" > "$PROG"
}
cross() {
  printf '%s\n' '3,9,27,243,729 0 0/1' '9,9,27,81,243 0,1 0/2' '9,9,27,81,243 0,1 1/2' '3,9,81,243,729 1,2 0/1' > "$OUT/cross.entries"
  python3 "$HERE/make_batch.py" -r 1 -n 1 --prefix x 5 "$OUT/cross" "$OUT/cross.entries" || st=1
  printf '%s\n' '3,27,81,729 0,2 0/1' '27,27,81,243 1 0/1' '3,27,81,729,2187 0,2 5/16' > "$OUT/cross472.entries"
  python3 "$HERE/make_batch.py" -r 1 -n 1 --kind case472 --prefix y 4 "$OUT/cross472" <(head -n 2 "$OUT/cross472.entries") || st=1
  python3 "$HERE/make_batch.py" -r 1 -n 1 --kind case472 --prefix z 5 "$OUT/cross472z" <(tail -n 1 "$OUT/cross472.entries") || st=1
  for b in cross cross472 cross472z; do runbatch "$OUT/$b" "$1"; done
  echo "== cross-host batch (sha256 of result.txt; the same on every runner)"
  for f in "$OUT"/cross/*/result.txt "$OUT"/cross472/*/result.txt "$OUT"/cross472z/*/result.txt; do
    echo "CROSS $(basename "$(dirname "$f")") $(grep -v '^# code ' "$f" | sha256sum | cut -c1-64)"; done
  grep -h 'done,' "$OUT"/cross*/*/stderr.txt
}
case $MODE in
s5)
  PAR=$1 NTH=$2 NP=$3; shift 3
  refs=()
  for j in "$@"; do f=${JOB_ROOT:?}/../$j/out/run.txt; [ -s "$f" ] || { echo "no $f"; exit 1; }; refs+=(--ref "$f"); cp "$f" "$OUT/ref-$j.txt"; done
  cat "$OUT"/ref-*.txt | awk -v n="$NTH" '/^S5RUN/ && (k++ % n) == 0 {print $3}' > "$OUT/types5.txt"
  python3 - "$OUT/types5.txt" > "$OUT/s5.entries" <<'PY'
import itertools, sys
from s5_473 import T1
for t in open(sys.argv[1]).read().split():
    d = [int(x) for x in t.split(',')]
    for r in range(len(d) + 1):
        for A in itertools.combinations(range(len(d)), r):
            if not T1(d, set(A)): print(t, ','.join(map(str, A)) or '-')
PY
  echo "== s = 5 sample: $(wc -l < "$OUT/types5.txt") types, $(wc -l < "$OUT/s5.entries") pairs (d,A), NPARTS $NP, 2 replicas"
  python3 "$HERE/make_batch.py" -r 2 -n 8 -p "$NP" --seed pilot 5 "$OUT/b5" "$OUT/s5.entries" || st=1
  runbatch "$OUT/b5" "$PAR"
  python3 "$HERE/collect.py" --types "$OUT/types5.out" "${refs[@]}" "$OUT/b5" "$OUT/b5.manifest" || st=1
  awk '/done,/{c+=$(NF-7); n++} END{printf "s5 batch: %d jobs, cpu %.0f s\n", n, c}' "$OUT"/b5/*/stderr.txt
  ctype=$(head -n 1 "$OUT/s5.entries" | cut -d' ' -f1)      # the first sampled type that has a non-(T1) A
  python3 - "$ctype" > "$OUT/ctl.entries" <<'PY'
import itertools, sys
from s5_473 import T1
d = [int(x) for x in sys.argv[1].split(',')]
for r in range(len(d) + 1):
    for A in itertools.combinations(range(len(d)), r):
        if not T1(d, set(A)): print(sys.argv[1], ','.join(map(str, A)) or '-')
PY
  echo "== control without (D2): $(wc -l < "$OUT/ctl.entries") pairs of type $ctype (must fail)"
  python3 "$HERE/make_batch.py" -r 2 -n 64 --drop D2 --prefix c 5 "$OUT/ctl" "$OUT/ctl.entries" || st=1
  runbatch "$OUT/ctl" "$PAR"
  python3 "$HERE/collect.py" "$OUT/ctl" "$OUT/ctl.manifest" | grep -v '^FAIL ' || st=1
  cross "$PAR"
  ;;
s6)
  PAR=$1 N=$2 SEED=$3 NP=${4:-1} REPS=${5:-1}
  # the first N pairs in the order of make_batch.py --seed SEED: spread over all types and classes
  python3 - "$HERE" "$SEED" "$N" > "$OUT/s6.entries" <<'PY'
import hashlib, sys
sys.path.insert(0, sys.argv[1])
from make_batch import all_pairs
key = lambda e: hashlib.sha256(('%s\n%s' % (sys.argv[2], e)).encode()).hexdigest()
for e in sorted(('%s %s 0/1' % p for p in all_pairs(6)), key=key)[:int(sys.argv[3])]: print(e)
PY
  sed 's: 0/1$::' "$OUT/s6.entries" > "$OUT/s6.e" && mv "$OUT/s6.e" "$OUT/s6.entries"
  python3 "$HERE/make_batch.py" -r "$REPS" -n "$NP" -p "$NP" --seed "$SEED" --prefix s6 6 "$OUT/b6" "$OUT/s6.entries" || st=1
  echo "== s = 6 sample: $N pairs (d,A), seed $SEED, NPARTS $NP, $REPS replicas"; cat "$OUT"/b6/*/piece.txt | grep -v '^#'
  runbatch "$OUT/b6" "$PAR"
  python3 "$HERE/collect.py" --minrep "$REPS" "$OUT/b6" "$OUT/b6.manifest" | grep -v '^FAIL ' || st=1
  echo "== per pair (stderr of run_piece.py)"; grep -h 'run_piece: Space\|A=\|done,' "$OUT"/b6/*/stderr.txt
  grep -h '"orbits"' "$OUT"/b6/*/result.txt
  ;;
ne5ref)
  PAR=$1
  # the per-A lines of the MATH-472 pilot's log (ax42/tm/20261115-071913-case472-pilot5-4006323), as collect.py
  # --pairs writes them for kind case472full (its run_case472.sh pilot5 ran 's5_472.py run TYPE A' on these 4 pairs)
  cat > "$OUT/ne5ref.txt" <<'REF'
S5NEA type 3,3,27,81,729 A 0,3 drop [] pair-orbits 531 non-elem 473 chains 40503 sigma!=0 40503 FAILING 0
S5NEA type 3,27,81,729,2187 A - drop [] pair-orbits 243 non-elem 211 chains 19531 sigma!=0 19450 FAILING 0
S5NEA type 3,27,81,729,2187 A 0,2 drop [] pair-orbits 828 non-elem 748 chains 60544 sigma!=0 60544 FAILING 0
S5NEA type 27,27,81,243,729 A 1,3 drop [] pair-orbits 324 non-elem 284 chains 25662 sigma!=0 25662 FAILING 0
REF
  awk '{print $3, $5}' "$OUT/ne5ref.txt" > "$OUT/ne5.entries"
  python3 "$HERE/make_batch.py" -r 2 -n 1 --kind case472 --seed pilot 5 "$OUT/r5" "$OUT/ne5.entries" || st=1
  python3 "$HERE/make_batch.py" -r 1 -n 1 -p 8 --kind case472full --seed pilot 5 "$OUT/f5" "$OUT/ne5.entries" || st=1
  runbatch "$OUT/r5" "$PAR"; runbatch "$OUT/f5" "$PAR"
  python3 "$HERE/collect.py" --pairs "$OUT/r5.pairs" "$OUT/r5" "$OUT/r5.manifest" || st=1
  python3 "$HERE/collect.py" --minrep 1 --pairs "$OUT/f5.pairs" "$OUT/f5" "$OUT/f5.manifest" || st=1
  echo "== case472full vs the MATH-472 pilot log (every field)"
  cat "$OUT/f5.pairs"
  if cmp -s <(sort "$OUT/f5.pairs") <(sort "$OUT/ne5ref.txt"); then echo "full: 4 of 4 pairs identical"; else echo "full: DIFFERS"; st=1; fi
  echo "== case472 (reduced) vs the MATH-472 pilot log (pair orbits, non-elementary orbits, lifts = chains, FAILING)"
  cat "$OUT/r5.pairs"
  m=$(join <(awk '{print $3"_"$5, $9, $11, $13, $NF}' "$OUT/r5.pairs" | sort) \
           <(awk '{print $3"_"$5, $9, $11, $13, $NF}' "$OUT/ne5ref.txt" | sort) | awk '$2==$6 && $3==$7 && $4==$8 && $5==0 && $9==0' | wc -l)
  echo "reduced: $m of 4 pairs match"; [ "$m" -eq 4 ] || st=1
  awk '{l+=$13; o+=$15} END{printf "reduced: lifts %d, lift orbits checked %d (factor %.1f)\n", l, o, l/o}' "$OUT/r5.pairs"
  for b in r5 f5; do awk -v b=$b '/done,/{c+=$(NF-7); n++} END{printf "%s: %d jobs, cpu %.0f s\n", b, n, c}' "$OUT"/$b/*/stderr.txt; done
  echo "== control without (D2): kind case472, the 4 pairs (must fail)"
  python3 "$HERE/make_batch.py" -r 1 -n 4 --kind case472 --drop D2 --prefix c 5 "$OUT/ctl" "$OUT/ne5.entries" || st=1
  runbatch "$OUT/ctl" "$PAR"
  python3 "$HERE/collect.py" --minrep 1 "$OUT/ctl" "$OUT/ctl.manifest" | grep -v '^FAIL ' || st=1
  ;;
ne5)
  PAR=$1 N=$2 SEED=$3 NP=${4:-1} REPS=${5:-2}
  python3 - "$HERE" "$SEED" "$N" > "$OUT/ne5.entries" <<'PY'
import hashlib, sys
sys.path.insert(0, sys.argv[1])
from make_batch import all_pairs
key = lambda e: hashlib.sha256(('%s\n%s' % (sys.argv[2], e)).encode()).hexdigest()
for e in sorted(('%s %s 0/1' % p for p in all_pairs(5, 'case472')), key=key)[:int(sys.argv[3])]: print(e.rsplit(' ', 1)[0])
PY
  python3 "$HERE/make_batch.py" -r "$REPS" -n 1 -p "$NP" --kind case472 --seed "$SEED" 5 "$OUT/t5" "$OUT/ne5.entries" || st=1
  echo "== case472 s = 5 sample: $N pairs (d,A), seed $SEED, NPARTS $NP, $REPS replicas"
  runbatch "$OUT/t5" "$PAR"
  python3 "$HERE/collect.py" --minrep "$REPS" --pairs "$OUT/t5.pairs" "$OUT/t5" "$OUT/t5.manifest" | grep -v '^FAIL ' || st=1
  cat "$OUT/t5.pairs"
  echo "== per pair (stderr of run_piece.py, replica 1)"; grep -h 'A=' "$OUT"/t5/*.1/stderr.txt
  grep -h 'A=' "$OUT"/t5/*.1/stderr.txt | awk '{for(i=1;i<=NF;i++) if($i=="cpu") c=$(i+1); s+=c; n++; if(c>m) m=c} END{printf "TIMING pairs %d cpu-sec total %.0f mean %.1f max %.1f\n", n, s, s/n, m}'
  awk '{l+=$13; o+=$15} END{printf "reduced: lifts %d, lift orbits checked %d (factor %.1f)\n", l, o, l/o}' "$OUT/t5.pairs"
  grep -h 'peak' "$OUT"/t5/*/stderr.txt | awk '{print $(NF-1)}' | sort -n | tail -n 1 | sed 's/^/peak memory MB /'
  ;;
cross) cross "$1" ;;
*) echo "unknown mode $MODE"; exit 2 ;;
esac
echo "overall ok=$((1 - st))"
exit $st
