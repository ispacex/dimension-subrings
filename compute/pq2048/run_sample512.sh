#!/bin/sh
# run_sample512.sh OUTDIR — count.g on SmallGroups(512): ids 1..111612 (ranks 2 and 3) all, the
# rest (ranks 4..7) every STRIDE-th id (default 100); LOGQ 11.  README.ru.md «Отсев на малых порядках».
here=$(cd "$(dirname "$0")" && pwd)
out=$1; st=${STRIDE:-100}
[ -n "$out" ] || { echo "usage: run_sample512.sh OUTDIR"; exit 2; }
mkdir -p "$out"
GAP=${GAP:-gap}
run() { ( cd "$here" && printf '%s\n' "NN:=512;; IDFROM:=$1;; IDTO:=$2;; STRIDE:=$3;; LOGQ:=11;; STATFILE:=\"$out/count512_$1_$3.json\";;" \
          | cat - count.g | nice -n "${NICE:-15}" "$GAP" -q -b -o 4g --quitonbreak ) > "$out/count512_$1_$3.log" 2>&1; cat "$out/count512_$1_$3.json"; }
run 1 111612 1
run 111613 10494213 "$st"
