#!/bin/bash
# Review of PR #111: negative control for bm_sec.g on D = G x C_9; log in $JOB_OUT.
set -e
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
# Check and MaxOver verbatim from bm_sec.g; NEED and the per-M loop verbatim from bm_sec.g
sed -n '/^Check := function/,/^ZG := /p' bm_sec.g | sed '$d' > funcs.g
grep -q '^MaxOver := function' funcs.g
sed -n '/^NEED := /p' bm_sec.g > secbody.g
sed -n '/^  for M in Ms do/,/^  od;/p' bm_sec.g >> secbody.g
cat funcs.g secbody.g
${GAP:-$JOB_CACHE/gap/gap} -q -b --quitonbreak -o 16g bm_sec_ctrl.g > "$OUTD/bm_sec_ctrl.log" 2>&1 || true
cat "$OUTD/bm_sec_ctrl.log"
for v in A B C; do
  echo "== $v"; sed -n "/^VARIANT $v/,/^END $v/p" "$OUTD/bm_sec_ctrl.log" | grep '^  M:' | sed -E 's/log3\|N0\| = [0-9]+, //' | sort | uniq -c
done
