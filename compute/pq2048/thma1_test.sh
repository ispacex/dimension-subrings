#!/bin/sh
# Theorem A1 against the full walk: tree.g from the root 2^D with and without PQ2048_THMA1 (both with THMA, THMB,
# TAH19, TIGHT, the step rules): thma1_test.sh OUT LOGQ D...
# Expected: the same candidates (by code) and the same parents' cover results; thmA1 > 0 shows the rule acted.
out=$1; logq=$2; shift 2; mkdir -p "$out"
GAP=${GAP:-gap}
for D in "$@"; do
  for v in 0 1; do
    s=$(date +%s)
    printf "%s\n" "D:=$D;; STEPRULES:=true;; COMPACT:=true;; NMAX:=$((logq - 1));; LOGQ:=$logq;; COVERMAX:=10;; STATFILE:=\"$out/t_${logq}_${D}_$v.json\";; OUTFILE:=\"$out/t_${logq}_${D}_$v.jsonl\";;" \
      | cat - tree.g | PQ2048_THMA1=$v PQ2048_TAH19=1 PQ2048_NOSTAB=1 PQ2048_TIGHT=1 PQ2048_THMB=1 PQ2048_THMA=1 PQ2048_LIBROOT=1 \
        $GAP -q -b -o 6g --quitonbreak > "$out/t_${logq}_${D}_$v.log" 2>&1
    rc=$?
    [ -s "$out/t_${logq}_${D}_$v.json" ] || { echo "2^$logq rank $D thma1 $v: FAILED rc $rc (no stat file)"; tail -5 "$out/t_${logq}_${D}_$v.log"; exit 1; }
    echo "2^$logq rank $D thma1 $v: rc $rc sec $(( $(date +%s) - s )) cand $(wc -l < "$out/t_${logq}_${D}_$v.jsonl" 2>/dev/null)"
  done
  grep -o '"code":[0-9]*' "$out/t_${logq}_${D}_0.jsonl" | sort > "$out/k0"
  grep -o '"code":[0-9]*' "$out/t_${logq}_${D}_1.jsonl" | sort > "$out/k1"
  if cmp -s "$out/k0" "$out/k1"; then echo "  same candidates ($(wc -l < "$out/k1"))"; else echo "  DIFFERENT candidates"; fi
  python3 -c "
import json; a=json.load(open('$out/t_${logq}_${D}_0.json')); b=json.load(open('$out/t_${logq}_${D}_1.json'))
print('  thmA1', b.get('thmA1'), 'vert', a['vert'], '->', b['vert'], 'par', a['par'], '->', b['par'])
print('  ms_desc', sum(a['ms_desc']), '->', sum(b['ms_desc']), 'ms_cover', sum(a['ms_cover']), '->', sum(b['ms_cover']))"
done
