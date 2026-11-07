#!/bin/bash
# MATH-444 / D5-49 step 2: star444.g over a plan, P shards in parallel.
# Usage (tm job, tree root): bash compute/magnus/run_star444.sh PLAN [P]
# PLAN lines: name seed MODE TOPS KS NG [NEEDNOTH2] [EXTRAW]   (GAP lists without spaces)
export PATH=$JOB_CACHE/bin:$PATH
PLAN=$(realpath "$1"); P=${2:-4}
cd compute/magnus
OUT=${JOB_OUT:-.}; ROOT=${JOB_ROOT:-.}
one() {
  nm=$1; s=$2; mode=$3; tops=$4; ks=$5; ng=$6; nn=${7:-false}; xw=${8:-[2,3,3,4]}
  t=$(date +%s)
  gap -q -b --quitonbreak -o 4g > "$OUT/gap_${nm}_$s.log" 2>&1 <<GAPEOF
SEED:=$s;; NG:=$ng;; KS:=$ks;; TOPS:=$tops;; MODE:="$mode";; NEEDNOTH2:=$nn;; EXTRAW:=$xw;; OUT:="$OUT/st_${nm}_$s.jsonl";;
Read("star444.g");
GAPEOF
  echo "$nm $s $(( $(date +%s)-t )) s $(grep '^stats' "$OUT/gap_${nm}_$s.log")" | tee -a "$OUT/times.txt"
  echo x > "$ROOT/progress_${nm}_$s"
}
export -f one; export OUT ROOT
grep -v '^#' "$PLAN" | grep . | xargs -P "$P" -L 1 bash -c 'one "$@"' _
grep -h -i -E 'error|FAILS' "$OUT"/gap_*.log | sort | uniq -c | head -40 | tee "$OUT/problems.txt"
cat "$OUT"/st_*.jsonl > "$OUT/all.jsonl"; wc -l "$OUT/all.jsonl"
exit 0
