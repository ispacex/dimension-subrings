#!/bin/bash
# MATH-41: rank-3 check of D_4, D_5 (Magnus algebra mod 2^30) and of Tahara's generators (tahara61.g)
# on random class-3 2-groups, one GAP process per type, in parallel.  On tm submit with cache "mikh"
# (its venv-*/bin/python has numpy; the dimension-subrings cache has none), e.g.
#   SEED=11 PER=300 TYPES="4,4,16 2,8,8 4,8,8 8,8,8 4,4,8 2,4,16 8,8,64" compute/magnus/run_rank3.sh
# with cores = number of types.  Summary on stdout, per-group JSON in $JOB_OUT.
set -euo pipefail
export PATH=${JOB_CACHE:-/nonexistent}/bin:$PATH
cd "$(dirname "$0")"
OUT=${JOB_OUT:-out}; mkdir -p "$OUT"   # default out/ is in .gitignore
SEED=${SEED:-1}; PER=${PER:-2}; TYPES=${TYPES:-"4,4,16 4,4,8"}
PY=${PY:-$(ls -d ${JOB_CACHE:-/nonexistent}/venv-*/bin/python 2>/dev/null | head -1 || true)}; PY=${PY:-python3}
$PY -c 'import numpy' || { echo "no numpy in $PY (use tm cache mikh)"; exit 2; }
for typ in $TYPES; do
  tag=$(echo "$typ" | tr -d ,)
  rm -f "$OUT/groups_$tag.jsonl" "$OUT/tah_$tag.jsonl"; touch "$OUT/groups_$tag.jsonl" "$OUT/tah_$tag.jsonl"
  ( echo "SEED := $SEED;; TYPES := [[$typ]];; PER := $PER;; OUT := \"$OUT/groups_$tag.jsonl\";; TOUT := \"$OUT/tah_$tag.jsonl\";;"
    echo 'Read("rank3.g");' ) | gap -q -b --quitonbreak -o 3g > "$OUT/gap_$tag.log" 2>&1 && \
    $PY check_rank3.py "$OUT/groups_$tag.jsonl" > "$OUT/magnus_$tag.jsonl" 2> "$OUT/py_$tag.err" &
done
wait
grep -h "^type\|Error\|bound hit" "$OUT"/gap_*.log || true
cat "$OUT"/py_*.err
$PY rank3_sum.py "$OUT"
# fail loudly if a type is missing: GAP or Python died, or fewer checked groups than generated
bad=0
for typ in $TYPES; do
  tag=$(echo "$typ" | tr -d ,)
  n=$(grep -h "^type" "$OUT/gap_$tag.log" | sed -n 's/.* class3 \([0-9]*\) .*/\1/p')
  m=$(grep -c . "$OUT/magnus_$tag.jsonl" 2>/dev/null || true)
  if [ -z "$n" ] || [ "$n" != "${m:-0}" ]; then echo "INCOMPLETE type $typ: generated '${n}' checked '${m:-0}'"; bad=1; fi
done
exit $bad
