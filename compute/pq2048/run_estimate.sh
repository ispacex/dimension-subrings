#!/bin/sh
# run_estimate.sh OUTDIR — the samples of README.ru.md «Оценка для 2^11» (sample_desc.g, LOGQ 11):
# vertices of order 512 (step 1; five id ranges, tags 512r2..512r6 name the ranges, not ranks — the
# rank of each vertex is in the arrays), 256 (step 2), 128 (step 3), 64 (step 4).
here=$(cd "$(dirname "$0")" && pwd)
out=$1
[ -n "$out" ] || { echo "usage: run_estimate.sh OUTDIR"; exit 2; }
mkdir -p "$out"
s() { # NN FROM TO STRIDE MAXV TAG
  ( cd "$here" && printf '%s\n' "NN:=$1;; IDFROM:=$2;; IDTO:=$3;; STRIDE:=$4;; MAXV:=$5;; LOGQ:=11;; STATFILE:=\"$out/sd_$6.json\";;" \
      | cat - sample_desc.g | nice -n "${NICE:-15}" "${GAP:-gap}" -q -b -o 6g --quitonbreak ) > "$out/sd_$6.log" 2>&1
  cat "$out/sd_$6.json"
}
s 512 7 2045 37 30 512r2
s 512 2111 111612 1999 30 512r3
s 512 120001 6249623 100003 40 512r4
s 512 6260001 10481221 70001 40 512r5
s 512 10481301 10494173 211 40 512r6
s 256 13 56092 997 60 256
s 128 3 2328 41 50 128
s 64 2 267 5 20 64
