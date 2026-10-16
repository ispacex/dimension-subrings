#!/bin/sh
# run_prof.sh OUTDIR — prof_vertex.g on samples: rank 6 (and 5) at 512, ranks 4-5 at 256.
here=$(cd "$(dirname "$0")" && pwd)
out=$1; mkdir -p "$out"
p() { ( cd "$here" && printf '%s\n' "NN:=$1;; IDFROM:=$2;; IDTO:=$3;; STRIDE:=$4;; NMAX:=10;; LOGQ:=11;; ${JOB_ROOT:+PROGRESS:=\"$JOB_ROOT/progress\";;} STATFILE:=\"$out/p_$5.json\";;" \
      | cat - prof_vertex.g | nice -n "${NICE:-15}" "${GAP:-gap}" -q -b -o 6g --quitonbreak ) > "$out/p_$5.log" 2>&1; cat "$out/p_$5.json"; }
[ -n "${ONLY256:-}" ] || p 512 6260001 10481221 20001 512r6
p 256 13 56092 97 256
