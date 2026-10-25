#!/bin/bash
# MATH-403: quick test of dn3.g + dnz.py on 3^6 and the first 3000 ids of 3^7.
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"; GAP=${GAP:-$JOB_CACHE/gap/gap}
PY=${PY:-$(ls -d $JOB_CACHE/venv-*/bin/python | head -1)}
echo 'K:=6;; FROM:=1;; TO:=100000;; OUT:="'$OUTD'/t6";;' | cat - dn3.g | $GAP -q -b --quitonbreak -o 3g 2>&1 | tail -3
echo 'K:=7;; FROM:=1;; TO:=3000;; OUT:="'$OUTD'/t7";;' | cat - dn3.g | $GAP -q -b --quitonbreak -o 3g 2>&1 | tail -3
cat "$OUTD"/t6.jsonl "$OUTD"/t7.jsonl | head -5 | $PY dnz.py
