#!/bin/bash
# MATH-412: bm_mul.g on a runner; log in $JOB_OUT.  EXTRA='LEVEL0:=true;;' to include G itself;
# GAPMEM caps GAP's workspace below the job's MemoryMax.
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
echo "${EXTRA:-}" | cat - bm_mul.g | ${GAP:-$JOB_CACHE/gap/gap} -q -b --quitonbreak -o ${GAPMEM:-16g} 2>&1 | tee "$OUTD/bm_mul${TAG:-}.log"
