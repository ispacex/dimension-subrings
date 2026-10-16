#!/bin/sh
# Big runs, one after another: order 256 (all groups of class >= 3), then the order-512
# candidates of the sieve (metabelian, class 3, K != 1).  Fast mode.
cd "$(dirname "$0")" || exit 2
PY=env/bin/python
while pgrep -f "out/A729.jsonl" > /dev/null; do sleep 30; done
$PY run.py data/g256.jsonl out/A256.jsonl --jobs ${JOBS:-6}
while pgrep -f sieve512.sh > /dev/null; do sleep 30; done
cat sieve/c512_*.jsonl > data/c512.jsonl
$PY run.py data/c512.jsonl out/A512c.jsonl --jobs ${JOBS:-6}
