#!/bin/bash
# MATH-414: bm_jen.g on a runner; log in $JOB_OUT.  EXTRA='ONLY:=[2];; MAXONLY:=true;;' for a part.
set -o pipefail
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
echo "${EXTRA:-}" | cat - bm_jen.g | ${GAP:-$JOB_CACHE/gap/gap} -q -b --quitonbreak -o ${GAPMEM:-16g} 2>&1 | tee "$OUTD/bm_jen${TAG:-}.log"
! grep -q "^Error" "$OUTD/bm_jen${TAG:-}.log" && grep -q "^bm_jen done" "$OUTD/bm_jen${TAG:-}.log"
