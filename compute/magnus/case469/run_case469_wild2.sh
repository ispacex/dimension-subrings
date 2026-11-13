#!/bin/bash
# MATH-469 (wiki 891 Sec. 14.2): larger bricks -- (1,3,3) with three indices per point (s = 18, mod 27) and the
# modulus-81 poset (2,2,2) (flag H_1 >= H_2) with one, two, three indices per point (s = 4, 8, 12).
set -uo pipefail
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/outw2}; mkdir -p "$OUT"
D18=3,3,3,9,9,9,27,27,27,243,243,243,729,729,729,2187,2187,2187
{ python3 wild469.py search $D18 0,1,2,3,4,5,6,7,8 11 5 1500 4
  python3 wild469.py search 3,9,243,729 0,1 3 2:1 300 1
  python3 wild469.py search 3,3,9,9,243,243,729,729 0,1,2,3 6 4:2 400 1
  python3 wild469.py search 3,3,3,9,9,9,243,243,243,729,729,729 0,1,2,3,4,5 9 6:3 1500 1; } > "$OUT/wild2.jsonl"
python3 wild469.py check "$OUT/wild2.jsonl" > "$OUT/wild2.txt"; st=$?
python3 - "$OUT/wild2.jsonl" <<'PY'
import json, sys, collections
c = collections.Counter((len(json.loads(l)['d']), str(json.loads(l)['r'])) for l in open(sys.argv[1]))
for k, v in sorted(c.items()): print("bricks s=%d r=%s: %d" % (k[0], k[1], v))
PY
tail -1 "$OUT/wild2.txt"; echo "overall status $st"; exit $st
