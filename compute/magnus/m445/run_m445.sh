#!/bin/bash
# MATH-445 / D5-50 checks (tm jobs), from the repository root:
#   run_m445.sh ids            identities on random elements (+ controls: non-metabelian, p = 2; also p = 5)
#   run_m445.sh tah            exact Tahara admissible-lattice check (+ drop controls, non-metabelian)
#   run_m445.sh d5 SEED NG     D_5 = 1 via d5s.py for random metabelian class-4 3-groups, exp(L2) >= 9
set -eo pipefail
cd compute/magnus/m445
OUT=${JOB_OUT:-$PWD/out}; mkdir -p "$OUT"
GAP=${GAP:-$JOB_CACHE/gap/gap}
PY=${PY:-$JOB_CACHE/venv-e13b2c068d/bin/python}; [ -x "$PY" ] || PY=python3
T=$(mktemp -d)
rungap() { $GAP -q --quitonbreak "$@" < /dev/null; }
case "$1" in
ids)
  for a in "SEED:=1;NG:=200;P:=3;MET:=true;" "SEED:=2;NG:=100;P:=3;MET:=false;" "SEED:=3;NG:=100;P:=2;MET:=true;" "SEED:=4;NG:=60;P:=5;MET:=true;"; do
    echo "$a" > $T/a.g; rungap $T/a.g ids.g >> "$OUT/ids.log"
  done
  [ "$(grep -c 'stats' "$OUT/ids.log")" = 4 ] || { echo "missing stats"; exit 1; }
  cat "$OUT/ids.log" ;;
tah)
  for S in 1 2 3 4 5 6; do
    echo "SEED:=$S;NG:=20;KS:=[2,3];DEXP:=[3,9,9,27];NEXTRA:=4;MET:=true;" > $T/b.g
    rungap $T/b.g tahrun.g >> "$OUT/tah_met.jsonl"
  done
  for S in 11 12; do
    echo "SEED:=$S;NG:=15;KS:=[2,3];DEXP:=[3,9,9,27];NEXTRA:=4;MET:=false;" > $T/b.g
    rungap $T/b.g tahrun.g >> "$OUT/tah_nonmet.jsonl"
  done
  [ "$(cat "$OUT"/tah_*.jsonl | grep -c SUMMARY)" = 8 ] || { echo "missing SUMMARY"; exit 1; }
  grep -h SUMMARY "$OUT"/tah_*.jsonl ;;
d5)
  echo "PY=$PY"; $PY -c "import numpy; print('numpy', numpy.__version__)"
  echo "SEED:=$2;NG:=$3;KS:=[2,3,3];DEXP:=[3,9,9,27];NEXTRA:=6;MAXLOG:=26;MAXS:=4;OUT:=\"$OUT/met9_$2.jsonl\";" > $T/c.g
  rungap $T/c.g met9gen.g > "$OUT/met9gen_$2.log"
  grep -q stats "$OUT/met9gen_$2.log" || { echo "missing stats"; exit 1; }
  cat "$OUT/met9gen_$2.log"
  cd .. && $PY d5s.py < "$OUT/met9_$2.jsonl" > "$OUT/met9_d5s_$2.jsonl"
  tail -1 "$OUT/met9_d5s_$2.jsonl" ;;
esac
