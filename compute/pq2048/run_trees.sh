#!/bin/sh
# run_trees.sh OUTDIR [D NMAX LOGQ COVERMAX]... — tree.g one run after another (README.ru.md «Поиск по
# одному рангу»); without runs given: the generator controls for ranks 2, 3, 4 (candidates up to
# order 512 against SmallGroups) and rank 2 up to parents of order 512.
here=$(cd "$(dirname "$0")" && pwd)
out=$1
[ -n "$out" ] || { echo "usage: run_trees.sh OUTDIR [D NMAX LOGQ COVERMAX]..."; exit 2; }
shift
[ $# -gt 0 ] || set -- 2 8 9 8  3 8 9 8  4 8 9 8  2 9 10 9
rc=0
while [ $# -ge 4 ]; do
  "$here/run_tree.sh" "$1" "$2" "$3" "$4" "$out" || rc=1
  shift 4
done
exit $rc
