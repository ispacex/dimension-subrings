#!/bin/sh
# compare tree.g on single order-512 vertices with and without PQ2048_NOSTAB: nostab_test.sh OUT D id...
out=$1; D=$2; shift 2; mkdir -p "$out"
case $D in 6) o=64; st=3;; 5) o=32; st=4;; esac
for i in "$@"; do
  echo "{\"order\":$o,\"code\":0,\"steps\":[$st],\"ids\":[$i,$i]}" > "$out/in_$i"
  for v in 0 1; do
    s=$(date +%s)
    printf "%s\n" "D:=$D;; STEPRULES:=true;; COMPACT:=true;; NMAX:=10;; LOGQ:=11;; COVERMAX:=10;; STARTFILE:=\"$out/in_$i\";; STATFILE:=\"$out/b_${i}_$v.json\";; OUTFILE:=\"$out/b_${i}_$v.jsonl\";;" \
      | cat - tree.g | PQ2048_NOSTAB=$v PQ2048_TIGHT=1 PQ2048_THMB=1 PQ2048_THMA=1 PQ2048_LIBROOT=1 $GAP -q -b -o 2g --quitonbreak > "$out/b_${i}_$v.log" 2>&1
    echo "id $i nostab $v sec $(( $(date +%s) - s )) cand $(wc -l < $out/b_${i}_$v.jsonl)"
  done
  sed 's/"id":[0-9]*,//' "$out/b_${i}_0.jsonl" | sort > "$out/c0"; sed 's/"id":[0-9]*,//' "$out/b_${i}_1.jsonl" | sort > "$out/c1"
  cmp -s "$out/c0" "$out/c1" && echo "  candidates identical" || echo "  CANDIDATES DIFFER"
  python3 -c "import json,sys; a=json.load(open('$out/b_${i}_0.json')); b=json.load(open('$out/b_${i}_1.json')); k=[x for x in a if not x.startswith('ms_') and x != 'onestage' and a[x]!=b.get(x)]; print('  stats differ:', k) if k else print('  stats identical')"
done
