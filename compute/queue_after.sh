#!/bin/sh
# After queue_big.sh: a sample of the order-2187 class-4 candidates (every 25th, 49 groups).
cd "$(dirname "$0")" || exit 2
while pgrep -f "queue_bi[g].sh" > /dev/null; do sleep 60; done
nice -n 10 env/bin/python run.py data/k2187_sample.jsonl out/A2187s.jsonl --jobs ${JOBS:-6}
