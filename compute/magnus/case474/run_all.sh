#!/bin/bash
# MATH-474: both parts in one job (run_case474.sh, then run_case474b.sh); exit 0 iff both pass.
cd "$(dirname "$0")"
OUT0=${JOB_OUT:-$PWD/outall}
JOB_OUT=$OUT0/a ./run_case474.sh "${1:-4}"; a=$?
JOB_OUT=$OUT0/b ./run_case474b.sh "${1:-4}"; b=$?
echo "run_case474 exit $a, run_case474b exit $b"
[ $a -eq 0 ] && [ $b -eq 0 ]
