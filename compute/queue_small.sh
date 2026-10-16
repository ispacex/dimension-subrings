#!/bin/sh
# Validation and small orders: full mode (every level up to 6, every element, certificate,
# right-ideal check) with methods A and B, then the PARI method C where it is cheap.
cd "$(dirname "$0")" || exit 2
PY=env/bin/python
for n in 8 16 32 64 128 81 243 625; do
  $PY run.py data/g$n.jsonl out/F_A$n.jsonl --full --jobs ${JOBS:-3}
done
for n in 8 16 32 64 81 243 625; do
  $PY run.py data/g$n.jsonl out/F_B$n.jsonl --full --method B --jobs ${JOBS:-3}
done
