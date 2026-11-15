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
# The cross-host batch: 4 fixed small s = 5 pieces; the sha256 of their results without the '# code' line are printed (CROSS lines), the same on every
# runner and in the image.  Results, batches and stderr (timings, peak memory) go to $JOB_OUT.
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
  runbatch "$OUT/cross" "$1"
  echo "== cross-host batch (sha256 of result.txt; the same on every runner)"
  for f in "$OUT"/cross/*/result.txt; do echo "CROSS $(basename "$(dirname "$f")") $(grep -v '^# code ' "$f" | sha256sum | cut -c1-64)"; done
  grep -h 'done,' "$OUT"/cross/*/stderr.txt
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
cross) cross "$1" ;;
*) echo "unknown mode $MODE"; exit 2 ;;
esac
echo "overall ok=$((1 - st))"
exit $st
