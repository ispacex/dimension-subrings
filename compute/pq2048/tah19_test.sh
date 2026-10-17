#!/bin/sh
# tree.g on single order-512 vertices with and without PQ2048_TAH19: tah19_test.sh OUT D id...
# Expected: the candidates with TAH19 are exactly those without it whose abelianization has >= 2 invariants >= 4.
out=$1; D=$2; shift 2; mkdir -p "$out"
case $D in 6) o=64; st=3;; 5) o=32; st=4;; esac
for i in "$@"; do
  echo "{\"order\":$o,\"code\":0,\"steps\":[$st],\"ids\":[$i,$i]}" > "$out/in_$i"
  for v in 0 1; do
    s=$(date +%s)
    printf "%s\n" "D:=$D;; STEPRULES:=true;; COMPACT:=true;; NMAX:=10;; LOGQ:=11;; COVERMAX:=10;; STARTFILE:=\"$out/in_$i\";; STATFILE:=\"$out/b_${i}_$v.json\";; OUTFILE:=\"$out/b_${i}_$v.jsonl\";;" \
      | cat - tree.g | PQ2048_TAH19=$v PQ2048_NOSTAB=1 PQ2048_TIGHT=1 PQ2048_THMB=1 PQ2048_THMA=1 PQ2048_LIBROOT=1 $GAP -q -b -o 2g --quitonbreak > "$out/b_${i}_$v.log" 2>&1
    echo "id $i tah19 $v sec $(( $(date +%s) - s )) cand $(wc -l < $out/b_${i}_$v.jsonl)"
  done
  grep -o '"code":[0-9]*' "$out/b_${i}_0.jsonl" | cut -d: -f2 > "$out/k0"
  grep -o '"code":[0-9]*' "$out/b_${i}_1.jsonl" | cut -d: -f2 > "$out/k1"
  printf '%s\n' 'SetPrintFormattingStatus("*stdout*", false);' \
    'big := s -> Number(AbelianInvariants(PcGroupCode(Int(s), 2048)), x -> x >= 4) >= 2;;' \
    "k0 := Filtered(SplitString(StringFile(\"$out/k0\"), \"\\n\"), s -> s <> \"\");;" \
    "k1 := Filtered(SplitString(StringFile(\"$out/k1\"), \"\\n\"), s -> s <> \"\");;" \
    'Print("  expected ", SortedList(Filtered(k0, big)) = SortedList(k1), ", kept ", Length(k1), " of ", Length(k0), ", all kept big ", ForAll(k1, big), "\n");' \
    'QUIT;' | $GAP -q
  python3 -c "import json; a=json.load(open('$out/b_${i}_0.json')); b=json.load(open('$out/b_${i}_1.json')); print('  tah19', b['tah19'], 'ms_cover', sum(a['ms_cover']), '->', sum(b['ms_cover']), 'ms_desc', sum(a['ms_desc']), '->', sum(b['ms_desc']))"
done
