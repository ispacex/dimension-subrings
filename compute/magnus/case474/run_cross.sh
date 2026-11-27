#!/bin/bash
# MATH-474: part 1 of run_case474b.sh alone (equivalence full mod 3^k <=> mixed mod 9, ELEMENTARY configurations only;
# non-elementary singleton labels of 'blocks' are skipped and counted).  Exit 0 iff DIFFERENT = 0 and controls work.
set -uo pipefail
PAR=${1:-4}
cd "$(dirname "$0")"
. ../case467/env467.sh
OUT=${JOB_OUT:-$PWD/outcross}; mkdir -p "$OUT"; st=0
alltypes() { python3 -c "
import sys; sys.path.insert(0, '../case467')
from diag467 import capped_types_k
for d in capped_types_k($1, $2): print(','.join(map(str, d)))"; }
{ for k in 3 4; do for S in 2 3; do echo "cross $S $k"; echo "cross $S $k D2"; done; echo "cross 3 $k Kt"; done
  alltypes 3 4 | sed 's/^/crosse /; s/$/ 4/'
  alltypes 3 4 | awk 'NR%5==0' | sed 's/^/crosse /; s/$/ 4 D2/'; } > "$OUT/cross.args"
xargs -P "$PAR" -L 1 python3 t474.py < "$OUT/cross.args" > "$OUT/cross.txt" 2>&1
n=$(wc -l < "$OUT/cross.args"); ok=$(grep -c '^CROSS' "$OUT/cross.txt")
dd=$(grep '^CROSS' "$OUT/cross.txt" | grep -v "'Kt'" | awk '{s+=$NF} END{print s+0}')
nn=$(grep '^CROSS' "$OUT/cross.txt" | grep -v "'Kt'" | awk '{for(i=1;i<=NF;i++) if($i=="configs"||$i=="chains") s+=$(i+1)} END{print s+0}')
nf=$(grep '^CROSS' "$OUT/cross.txt" | grep "'D2'" | awk '{for(i=1;i<=NF;i++) if($i=="failing") s+=$(i+1)} END{print s+0}')
ne=$(grep '^CROSS ' "$OUT/cross.txt" | grep -v "'Kt'" | awk '{for(i=1;i<=NF;i++){if($i=="nonelementary-skipped") a+=$(i+1); if($i=="nonelem-different") b+=$(i+1)}} END{print a+0, "of them different", b+0}')
kt=$(grep '^CROSS' "$OUT/cross.txt" | grep "'Kt'" | awk '{s+=$NF} END{print s+0}')
echo "lines $ok of $n; compared (elementary) $nn, DIFFERENT $dd (must be 0); failures without D2 among them $nf (must be > 0)"
echo "non-elementary skipped $ne (information); without Kt different $kt (weak control, see review)"
[ "$ok" -eq "$n" ] && [ "$dd" -eq 0 ] && [ "$nf" -gt 0 ] || st=1
grep '^CROSS ' "$OUT/cross.txt"
echo "overall ok=$((1 - st))"
exit $st
