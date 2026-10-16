#!/bin/sh
# run_sieve.sh ORDER IDFROM IDTO OUTFILE STATFILE   — see filter_metab3.g
here=$(cd "$(dirname "$0")" && pwd)
GAP=${GAP:-$here/env/bin/gap}
abs() { case "$1" in /*) echo "$1" ;; *) echo "$PWD/$1" ;; esac; }
out=$(abs "$4"); st=$(abs "$5")
cd "$here" || exit 2
printf 'ORDER:=%s;; IDFROM:=%s;; IDTO:=%s;; OUTFILE:="%s";; STATFILE:="%s";;\n' "$1" "$2" "$3" "$out" "$st" \
  | cat - filter_metab3.g | nice -n 10 "$GAP" -q -b -o 8g 2>&1 | sed "/packagemanager/d;/RootPaths/d"
