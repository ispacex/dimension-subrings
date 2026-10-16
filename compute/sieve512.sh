#!/bin/sh
# Sieve all groups of order 512 that can have class >= 3.
# p-class c means P_{c+1} = 1 for the lower exponent-2 central series P_i, and gamma_i ⊆ P_i,
# so class <= p-class: p-class 2 forces class <= 2.  By SmallGroupsInformation(512) the ranges
# below are exactly the ids of p-class >= 3 (everything except 1, the p-class-2 blocks
# 2045, 60904-67612, 420515-6249623, 7532393-10481221, 10493062-10494173, 10494201-10494213).
cd "$(dirname "$0")" || exit 2
mkdir -p sieve
ranges() {
  # rank 2 (p-class 3..8), rank 3 (p-class 3..7), rank 4 (3..6), rank 5 (3..5), rank 6 (3, 4), rank 7 (3)
  for r in 2:2044 2046:60903 67613:420514 6249624:7532392 10481222:10493061 10494174:10494200; do
    a=${r%:*}; b=${r#*:}
    while [ "$a" -le "$b" ]; do
      e=$((a + 49999)); [ "$e" -gt "$b" ] && e=$b
      echo "$a $e"
      a=$((e + 1))
    done
  done
}
ranges | xargs -P "${JOBS:-10}" -n 2 sh -c '
  [ -s sieve/s512_$0.json ] && exit 0
  ./run_sieve.sh 512 $0 $1 sieve/c512_$0.jsonl sieve/s512_$0.json > sieve/log512_$0.txt 2>&1'
