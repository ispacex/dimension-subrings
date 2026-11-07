#!/bin/bash
# MATH-445 / D5-50 checks (tm jobs), from the repository root:
#   run_m445.sh ids            identities on random elements (+ controls: non-metabelian, p = 2)
#   run_m445.sh tah            exact Tahara admissible-lattice check (+ drop controls, non-metabelian)
#   run_m445.sh d5 SEED NG     D_5 = 1 via d5s.py for random metabelian class-4 3-groups, exp(L2) >= 9
set -e
cd compute/magnus/m445
OUT=${JOB_OUT:-$PWD/out}; mkdir -p "$OUT"
GAP=${GAP:-gap}
T=$(mktemp -d)
case "$1" in
ids)
  for a in "SEED:=1;NG:=200;P:=3;MET:=true;" "SEED:=2;NG:=100;P:=3;MET:=false;" "SEED:=3;NG:=100;P:=2;MET:=true;"; do
    echo "$a" > $T/a.g; $GAP -q $T/a.g ids.g | tr -d '\n' | sed 's/  */ /g' >> "$OUT/ids.log"; echo >> "$OUT/ids.log"
  done ;;
tah)
  for S in 1 2 3 4 5 6; do
    echo "SEED:=$S;NG:=20;KS:=[2,3];DEXP:=[3,9,9,27];NEXTRA:=4;MET:=true;" > $T/b.g
    $GAP -q $T/b.g tahrun.g | tr -d '\n' | sed 's/  */ /g; s/{"seed/\n{"seed/g; s/SUMMARY/\nSUMMARY/' >> "$OUT/tah_met.jsonl"; echo >> "$OUT/tah_met.jsonl"
  done
  for S in 11 12; do
    echo "SEED:=$S;NG:=15;KS:=[2,3];DEXP:=[3,9,9,27];NEXTRA:=4;MET:=false;" > $T/b.g
    $GAP -q $T/b.g tahrun.g | tr -d '\n' | sed 's/  */ /g; s/{"seed/\n{"seed/g; s/SUMMARY/\nSUMMARY/' >> "$OUT/tah_nonmet.jsonl"; echo >> "$OUT/tah_nonmet.jsonl"
  done ;;
d5)
  echo "SEED:=$2;NG:=$3;KS:=[2,3,3];DEXP:=[3,9,9,27];NEXTRA:=6;MAXLOG:=26;MAXS:=4;OUT:=\"$OUT/met9_$2.jsonl\";" > $T/c.g
  $GAP -q $T/c.g met9gen.g | tr -d '\n' | sed 's/  */ /g' > "$OUT/met9gen_$2.log"
  cd .. && python3 d5s.py < "$OUT/met9_$2.jsonl" > "$OUT/met9_d5s_$2.jsonl"
  tail -1 "$OUT/met9_d5s_$2.jsonl" ;;
esac
