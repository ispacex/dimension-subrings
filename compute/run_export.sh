#!/bin/sh
# run_export.sh ORDER IDFROM IDTO FILTER OUTFILE      (FILTER: all | class>=3 | metab3 | class4 | class>=4)
here=$(cd "$(dirname "$0")" && pwd)
GAP=${GAP:-$here/env/bin/gap}
case "$5" in /*) out="$5" ;; *) out="$PWD/$5" ;; esac
cd "$here" || exit 2
printf 'ORDER:=%s;; IDFROM:=%s;; IDTO:=%s;; FILTER:="%s";; OUTFILE:="%s";;\n' "$1" "$2" "$3" "$4" "$out" \
  | cat - export.g | nice -n 10 "$GAP" -q -b -o 8g 2>&1 | sed "/packagemanager/d;/RootPaths/d"
