#!/bin/sh
# run_verify_pcover.sh OUTDIR PART — verify_pcover.g: the own p-cover against PqPCover.
#   PART 1: orders 8..128, all kept vertices; order 256, odd ids.
#   PART 2: order 256, even ids; order 512, every 5000th id and every 20001st id in 6.26M..10.48M.
here=$(cd "$(dirname "$0")" && pwd)
out=$1 part=$2
[ -n "$part" ] || { echo "usage: run_verify_pcover.sh OUTDIR 1|2"; exit 2; }
mkdir -p "$out"
v() { # NN FROM TO STRIDE TAG [EXTRA]
  ( cd "$here" && printf '%s\n' "NN:=$1;; IDFROM:=$2;; IDTO:=$3;; STRIDE:=$4;; LOGQ:=11;; ${6:-} STATFILE:=\"$out/vp_$5.json\";;" \
      | cat - verify_pcover.g | nice -n "${NICE:-15}" "${GAP:-gap}" -q -b -o "${GAPMEM:-6g}" --quitonbreak ) > "$out/vp_$5.log" 2>&1
  cat "$out/vp_$5.json"
}
case $part in
  1) for nn in 8 16 32 64 128; do v $nn 1 100000000 1 $nn; done
     v 256 1 56092 2 256odd ;;
  2) v 256 2 56092 2 256even
     v 512 7 10494213 5000 512s 'MAXD:=7;;'
     v 512 6260001 10481221 20001 512r6 'MAXD:=7;;' ;;
esac
grep -h DIFF "$out"/vp_*.log && exit 1
exit 0
