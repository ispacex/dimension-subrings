#!/bin/bash
# Review of PR #107 (not for merge).  MODE=low: rv_desc.g over all parents of order 3^6 and 3^7
# (positive check against dn3.g at 3^7, 3^8 and a complete negative control); MODE=neg: rv_desc.g
# over rv_neg_ids.txt (failing 3^8 parents); MODE=count: rv_count.g over all of 3^8.
cd "$(dirname "$0")"
NSH=${NSH:-10}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"; GAP=${GAP:-$JOB_CACHE/gap/gap}
case $MODE in
low)
  echo "K:=6;; FROM:=1;; TO:=1000;; OUT:=\"$OUTD/low6\";;" | cat - rv_desc.g | $GAP -q -b --quitonbreak -o 3g > "$OUTD/gap_low6.out" 2>&1 &
  for s in $(seq 0 $((NSH - 2))); do
    S=$(( (9310 + NSH - 2) / (NSH - 1) ))
    echo "K:=7;; FROM:=$((s * S + 1));; TO:=$(((s + 1) * S));; OUT:=\"$OUTD/low7_$s\";;" | cat - rv_desc.g |
      $GAP -q -b --quitonbreak -o 3g > "$OUTD/gap_low7_$s.out" 2>&1 &
  done ;;
neg)
  for s in $(seq 0 $((NSH - 1))); do
    IDS=$(awk -v s=$s -v n=$NSH '(NR - 1) % n == s' rv_neg_ids.txt | paste -sd, -)
    echo "K:=8;; PARENTS:=[$IDS];; OUT:=\"$OUTD/neg_$s\";;" | cat - rv_desc.g |
      $GAP -q -b --quitonbreak -o 3g > "$OUTD/gap_neg_$s.out" 2>&1 &
  done ;;
count)
  N8=1396077; S=$(( (N8 + NSH - 1) / NSH ))
  for s in $(seq 0 $((NSH - 1))); do
    echo "FROM:=$((s * S + 1));; TO:=$(((s + 1) * S));; OUT:=\"$OUTD/count_$s.txt\";;" | cat - rv_count.g |
      $GAP -q -b --quitonbreak -o 1500m > "$OUTD/gap_count_$s.out" 2>&1 &
  done ;;
esac
wait
grep -H -m3 -E "Error|RVDONE|RVCOUNT" "$OUTD"/gap_*.out
