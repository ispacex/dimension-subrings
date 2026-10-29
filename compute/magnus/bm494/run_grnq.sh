#!/bin/bash
# MATH-414: Z[Q]/varpi^n for Q = G, G/<u_k> by grnq.  CASE = G | Gu1 | Gu2 | Gu3 (default G), N = n
# (default 7).  Builds ../grnq/grnq, writes the inputs with bm_grnq.g, runs grnq; logs in $JOB_OUT.
set -eo pipefail
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
c++ -O2 -std=c++17 -o "$OUTD/grnq" ../grnq/grnq.cpp
echo "OUTDIR := \"$OUTD\";; ONLY := [\"${CASE:-G}\"];;" | cat - bm_grnq.g | ${GAP:-$JOB_CACHE/gap/gap} -q -b --quitonbreak -o ${GAPMEM:-7g} 2>&1 | tee "$OUTD/bm_grnq.log"
grep -q "^bm_grnq done" "$OUTD/bm_grnq.log"
"$OUTD/grnq" ${N:-7} < "$OUTD/bm_${CASE:-G}.in" 2>&1 | tee "$OUTD/grnq_${CASE:-G}_n${N:-7}.log"
grep -q "^grnq done" "$OUTD/grnq_${CASE:-G}_n${N:-7}.log"
