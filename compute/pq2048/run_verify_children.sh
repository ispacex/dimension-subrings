#!/bin/sh
# run_verify_children.sh OUTDIR PART — verify_children.g: children.g against PqDescendants (step 1).
#   PART 1: orders 8..128, all kept vertices.   PART 2: order 256, every 4th id.
#   PART 3: order 512, every 5000th id and every 20001st id in 6.26M..10.48M (rank <= 7).
here=$(cd "$(dirname "$0")" && pwd)
out=$1 part=$2
[ -n "$part" ] || { echo "usage: run_verify_children.sh OUTDIR 1|2|3"; exit 2; }
mkdir -p "$out"
v() { # NN FROM TO STRIDE TAG [EXTRA]
  ( cd "$here" && printf '%s\n' "NN:=$1;; IDFROM:=$2;; IDTO:=$3;; STRIDE:=$4;; LOGQ:=11;; ${6:-} STATFILE:=\"$out/vc_$5.json\";;" \
      | cat - verify_children.g | nice -n "${NICE:-15}" "${GAP:-gap}" -q -b -o "${GAPMEM:-6g}" --quitonbreak ) > "$out/vc_$5.log" 2>&1
  cat "$out/vc_$5.json"
}
case $part in
  1) for nn in 8 16 32 64 128; do v $nn 1 100000000 1 $nn; done ;;
  2) v 256 1 56092 4 256 'MAXD:=7;;' ;;
  3) v 512 7 10494213 5000 512s 'MAXD:=7;;'
     v 512 6260001 10481221 20001 512r6 'MAXD:=7;;' ;;
esac
grep -h DIFF "$out"/vc_*.log && exit 1
exit 0
