#!/bin/bash
# MATH-414: Z[Q]/varpi^n for Q = G, G/<u_k> by grnq.  CASE = G | Gu1 | Gu2 | Gu3 (default G), N = n
# (default 7), E = precision p^E (default 30; <= 20 for 64-bit arithmetic).  Builds ../grnq/grnq, writes the inputs with bm_grnq.g, runs grnq; logs in $JOB_OUT.
set -eo pipefail
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
V32=; [ "${E:-30}" -le 20 ] && V32=-DGRNQ_V32  # p^E < 2^32 for p = 3: the rows in 32 bits
c++ -O2 -std=c++17 -fopenmp $V32 -o "$OUTD/grnq" ../grnq/grnq.cpp
echo "OUTDIR := \"$OUTD\";; ONLY := [\"${CASE:-G}\"];; EGRNQ := ${E:-30};;" | cat - bm_grnq.g | ${GAP:-$JOB_CACHE/gap/gap} -q -b --quitonbreak -o ${GAPMEM:-7g} 2>&1 | tee "$OUTD/bm_grnq.log"
grep -q "^bm_grnq done" "$OUTD/bm_grnq.log"
# under tm: the rows of the running Howell form as tm's progress (tm shows an ETA), and a checkpoint of it in
# the job cache, so that a run cancelled or lost resumes there (GRNQ_CKPT= switches it off; see ../grnq/README.md)
[ -n "$JOB_ROOT" ] && export GRNQ_PROGRESS_FILE=${GRNQ_PROGRESS_FILE:-$JOB_ROOT/progress}
if [ -n "$JOB_CACHE" ] && [ -z "${GRNQ_CKPT+set}" ]; then
  mkdir -p "$JOB_CACHE/grnq-ckpt"; export GRNQ_CKPT="$JOB_CACHE/grnq-ckpt/${CASE:-G}_n${N:-7}_E${E:-30}.ckpt"
fi
"$OUTD/grnq" ${N:-7} < "$OUTD/bm_${CASE:-G}.in" 2>&1 | tee "$OUTD/grnq_${CASE:-G}_n${N:-7}.log"
grep -q "^grnq done" "$OUTD/grnq_${CASE:-G}_n${N:-7}.log"
if [ -n "$GRNQ_CKPT" ]; then rm -f "$GRNQ_CKPT" "$GRNQ_CKPT.tmp"; fi  # done: the checkpoint (as large as the pivot rows) is not needed
