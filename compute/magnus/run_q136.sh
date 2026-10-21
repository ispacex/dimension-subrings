#!/bin/bash
# D5-6: q136.g on 4 shards.  Usage: run_q136.sh block        (the 7824 groups of order 3^8, type (5,2,1))
#                                       run_q136.sh p7 P         (groups of order P^7, type (4,2,1))
# Summary in $JOB_OUT/summary_<tag>.txt.
export PATH=$JOB_CACHE/bin:$PATH
MODE=${1:-block}; P=${2:-3}
TAG=$MODE; [ "$MODE" = p7 ] && TAG=p7_$P
cd "$(dirname "$0")"
OUT=${JOB_OUT:-.}
for s in 0 1 2 3; do
  (echo "MODE:=\"$MODE\"; PR:=$P; SHARD:=$s; NSHARD:=4; LOG:=\"$OUT/q136_${TAG}_$s.csv\";"; echo 'Read("q136.g");') \
    | gap -q -b --quitonbreak -o 8g > "$OUT/q136_${TAG}_$s.gaplog" 2>&1 &
done
wait
{ grep -h shard "$OUT"/q136_${TAG}_?.csv
  grep -h -A3 -i error "$OUT"/q136_${TAG}_*.gaplog | head
  echo "count logN(ANUPQ),logN(GAP),N1,N2,N3,Eall,Egen,J,E+J,E+J(no om3),cert,negcert:"
  grep -hv shard "$OUT"/q136_${TAG}_?.csv | cut -d, -f2- | sort | uniq -c
  echo "mismatches (ANUPQ vs GAP, or logN>0 xor (N1..N3 and E+J) -- so N1..N3 false must give logN=0, or logN>0 without cert, or negcert true):"
  grep -hv shard "$OUT"/q136_${TAG}_?.csv | awk -F, '{p=($4=="true"&&$5=="true"&&$6=="true"&&$10=="true");
    if ($2 != $3 || p != ($2>0) || ($2>0 && $12 != "true") || $13 == "true") print}' | head -20
} | tee "$OUT/summary_$TAG.txt"
