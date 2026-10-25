#!/bin/bash
# Review of PR #109: negative control for bm_sub.g on D = G x C_3; log in $JOB_OUT.
set -e
cd "$(dirname "$0")"
OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
# Check and MaxOver verbatim from bm_sub.g
sed -n '/^Check := function/,/^ZG := /p' bm_sub.g | sed '$d' > funcs.g
cat funcs.g
grep -q '^MaxOver := function' funcs.g
${GAP:-$JOB_CACHE/gap/gap} -q -b --quitonbreak -o 16g bm_sub_ctrl.g > "$OUTD/bm_sub_ctrl.log" 2>&1 || true
cat "$OUTD/bm_sub_ctrl.log"
