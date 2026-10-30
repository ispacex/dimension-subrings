#!/bin/bash
# MATH-423: modules by mc_$CASE.g (CASE = rips | bm), then modcert.py N E.  EXTRA: GAP assignments
# put before the script.  Logs in $JOB_OUT.
set -eo pipefail
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
GAP=${GAP:-$JOB_CACHE/gap/gap}; PY=${PY:-$(ls -d $JOB_CACHE/venv-*/bin/python 2>/dev/null | head -1)}; PY=${PY:-python3}
C=${CASE:-rips}
echo "OUT := \"$OUTD/mod_$C.txt\";; ${EXTRA:-}" | cat - mc_$C.g | $GAP -q -b --quitonbreak -o ${GAPMEM:-7g} 2>&1 | tee "$OUTD/mc_$C.log"
grep -q "^mc_$C done" "$OUTD/mc_$C.log"
$PY modcert.py ${N:-4} ${E:-12} < "$OUTD/mod_$C.txt" 2>&1 | tee "$OUTD/modcert_$C.log"
grep -q "^modcert done" "$OUTD/modcert_$C.log"
