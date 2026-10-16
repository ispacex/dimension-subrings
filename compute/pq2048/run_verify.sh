#!/bin/sh
# run_verify.sh OUTDIR PART — steps.g against full expansion (verify_steps.g) and the walk with and
# without the rules (tree.g), README.ru.md «Вершины без потомков».
#   PART a: tree.g ranks 2, 3, 4 to order 256 (N = 9) with the rules; orders 16..128, all vertices,
#           steps <= 2 (N = 11, children up to 512); order 512 ranks 6-7 (ids from 10481222), every
#           20th, step 1 (N = 11): the measurement.
#   PART c: only the order-512 rank 6-7 measurement;  PART d: the bulk of rank 6 at order 512.
#   PART b1, b2: order 256, every 5th id between them; b2 also order 512, every 5000th id.
#   PART b: order 256, all vertices, step 1 (N = 11, children of order 512); order 512, every 2000th
#           id, step 1.
here=$(cd "$(dirname "$0")" && pwd)
out=$1 part=$2
[ -n "$part" ] || { echo "usage: run_verify.sh OUTDIR a|b"; exit 2; }
mkdir -p "$out"
v() { # NN FROM TO STRIDE NMAX LOGQ MAXSTEP TAG [EXTRA]
  ( cd "$here" && printf '%s\n' "NN:=$1;; IDFROM:=$2;; IDTO:=$3;; STRIDE:=$4;; NMAX:=$5;; LOGQ:=$6;; MAXSTEP:=$7;; ${9:-} STATFILE:=\"$out/v_$8.json\";; ${JOB_ROOT:+PROGRESS:=\"$JOB_ROOT/progress\";;}" \
      | cat - verify_steps.g | nice -n "${NICE:-15}" "${GAP:-gap}" -q -b -o ${GAPMEM:-6g} --quitonbreak ) > "$out/v_$8.log" 2>&1
  cat "$out/v_$8.json"
}
case $part in
  c)  # the measurement alone (rank 6-7 at order 512; rank 8 skipped)
    v 512 10481222 10494213 20 10 11 1 512r67 'MAXD:=7;;'
    ;;
  d)  # the bulk of rank 6 at order 512 (ids 6.26M..10.48M, as sample_desc.g's range 512r5)
    v 512 6260001 10481221 20001 10 11 1 512r6 'MAXD:=7;;'
    ;;
  a)
    [ -n "${NOTREES:-}" ] || "$here/run_trees.sh" "$out/trees" 2 8 9 8  3 8 9 8  4 8 9 8
    for nn in 16 32 64 128; do v $nn 1 100000000 1 9 11 2 $nn; done
    v 512 10481222 10494213 20 10 11 1 512r67 'MAXD:=7;;'
    ;;
  b)
    v 256 1 56092 1 9 11 1 256
    v 512 7 10494213 2000 10 11 1 512s 'MAXD:=7;;'
    ;;
  b1) # order 256 every 10th id from 1, step 1 (the full pass b takes about a day)
    v 256 1 56092 10 9 11 1 256a
    ;;
  b2) # order 256 every 10th id from 6, then order 512 every 5000th id
    v 256 6 56092 10 9 11 1 256b
    v 512 7 10494213 5000 10 11 1 512s 'MAXD:=7;;'
    ;;
esac
grep -h VIOLATION "$out"/v_*.log && exit 1
exit 0
