#!/bin/bash
# MATH-474: parts b and c (run_case474b.sh, run_case474c.sh); part a ran in kimmy/tm/20261127-064140-case474all-6549709.
cd "$(dirname "$0")"
OUT0=${JOB_OUT:-$PWD/outbc}
JOB_OUT=$OUT0/b ./run_case474b.sh "${1:-4}"; b=$?
JOB_OUT=$OUT0/c ./run_case474c.sh "${1:-4}"; c=$?
echo "run_case474b exit $b, run_case474c exit $c"
[ $b -eq 0 ] && [ $c -eq 0 ]
