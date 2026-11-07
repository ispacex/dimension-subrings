#!/bin/bash
# MATH-444 / D5-49: s444.g + d5s.py over a plan, P shards in parallel; summary by s444sum.py.
# Usage (inside a tm job, tree root): [GSCRIPT=s449.g] bash compute/magnus/run_s444.sh PLAN [P]
# PLAN lines: fam seed TOPS KS EPS0 NG [EXTRAW]   (GAP lists without spaces)
export PATH=$JOB_CACHE/bin:$PATH
source remote/py-env.sh
PLAN=$(realpath "$1"); P=${2:-4}
cd compute/magnus
OUT=${JOB_OUT:-.}; ROOT=${JOB_ROOT:-.}
T0=$(date +%s)
one() {
  fam=$1; s=$2; tops=$3; ks=$4; e=$5; ng=$6; xw=${7:-[2,3,3,4]}
  t=$(date +%s)
  gap -q -b --quitonbreak -o 3g > "$OUT/gap_${fam}_$s.log" 2>&1 <<GAPEOF
SEED:=$s;; NG:=$ng;; KS:=$ks;; TOPS:=$tops;; EPS0:=$e;; EXTRAW:=$xw;; OUT:="$OUT/q_${fam}_$s.jsonl";;
Read("${GSCRIPT:-s444.g}");
GAPEOF
  t1=$(date +%s)
  python d5s.py < "$OUT/q_${fam}_$s.jsonl" > "$OUT/d5s_${fam}_$s.jsonl"
  echo "$fam $s gen $((t1-t)) s d5s $(( $(date +%s)-t1 )) s $(tail -1 "$OUT/d5s_${fam}_$s.jsonl")" | tee -a "$OUT/times.txt"
  grep -q '"with_z_in_D5": [1-9]' "$OUT/d5s_${fam}_$s.jsonl" && echo "HIT $fam $s" | tee -a "$OUT/HIT"
  grep -q 'TAHARA g <> 1' "$OUT/gap_${fam}_$s.log" && echo "TAHHIT $fam $s" | tee -a "$OUT/HIT"
  echo x > "$ROOT/progress_${fam}_$s"
}
export -f one; export OUT ROOT
grep -v '^#' "$PLAN" | grep . | xargs -P "$P" -L 1 bash -c 'one "$@"' _
echo "total wall $(( $(date +%s)-T0 )) s"
grep -h '^stats' "$OUT"/gap_*.log | tee "$OUT/stats.txt"
grep -h -i 'error' "$OUT"/gap_*.log | sort | uniq -c | head | tee -a "$OUT/stats.txt"
cat "$OUT"/d5s_*.jsonl | python s444sum.py | tee "$OUT/summary.txt"
[ -e "$OUT/HIT" ] && echo "!!! hit: $(cat "$OUT/HIT")"
gzip -f "$OUT"/q_*.jsonl
exit 0
