#!/bin/bash
# MATH-474: all three parts in one job (run_case474.sh, run_case474b.sh, run_case474c.sh); exit 0 iff all pass.
cd "$(dirname "$0")"
OUT0=${JOB_OUT:-$PWD/outall}
JOB_OUT=$OUT0/a ./run_case474.sh "${1:-4}"; a=$?
JOB_OUT=$OUT0/b ./run_case474b.sh "${1:-4}"; b=$?
JOB_OUT=$OUT0/c ./run_case474c.sh "${1:-4}"; c=$?
echo "run_case474 exit $a, run_case474b exit $b, run_case474c exit $c"
[ $a -eq 0 ] && [ $b -eq 0 ] && [ $c -eq 0 ]
