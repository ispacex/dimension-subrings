#!/bin/bash
# MATH-443 / D5-5: q99gen.g + d5s.py over a plan, P shards in parallel; summary by family.
# Usage (inside a tm job, tree root): bash compute/magnus/run_q99.sh PLAN [P]
# PLAN lines: fam seed TOPS KS EPS0 EXTRAW MODE NG   (GAP lists without spaces, e.g. [[9,9]] [3,4])
export PATH=$JOB_CACHE/bin:$PATH
source remote/py-env.sh
PLAN=$(realpath "$1"); P=${2:-4}
cd compute/magnus
OUT=${JOB_OUT:-.}; ROOT=${JOB_ROOT:-.}
T0=$(date +%s)
one() {
  fam=$1; s=$2; tops=$3; ks=$4; e=$5; xw=$6; mode=$7; ng=$8
  t=$(date +%s)
  gap -q -b --quitonbreak -o 3g > "$OUT/gap_${fam}_$s.log" 2>&1 <<EOF
SEED:=$s;; NG:=$ng;; KS:=$ks;; TOPS:=$tops;; MODE:=$mode;; EPS0:=$e;; EXTRAW:=$xw;; OUT:="$OUT/q_${fam}_$s.jsonl";;
Read("q99gen.g");
EOF
  t1=$(date +%s)
  python d5s.py < "$OUT/q_${fam}_$s.jsonl" > "$OUT/d5s_${fam}_$s.jsonl"
  echo "$fam $s gen $((t1-t)) s d5s $(( $(date +%s)-t1 )) s $(tail -1 "$OUT/d5s_${fam}_$s.jsonl")" | tee -a "$OUT/times.txt"
  # stop signal: any z in D_5 is reported at once
  grep -q '"with_z_in_D5": [1-9]' "$OUT/d5s_${fam}_$s.jsonl" && echo "HIT $fam $s" | tee -a "$OUT/HIT"
  echo x > "$ROOT/progress_${fam}_$s"
}
export -f one; export OUT ROOT
grep -v '^#' "$PLAN" | grep . | xargs -P "$P" -L 1 bash -c 'one "$@"' _
echo "total wall $(( $(date +%s)-T0 )) s"
for f in $(grep -v '^#' "$PLAN" | awk '{print $1}' | sort -u); do
  echo "=== $f"
  cat "$OUT"/d5s_${f}_*.jsonl | python q99sum.py
  grep -h -A20 '^stats' "$OUT"/gap_${f}_*.log | tr -d '\n' | sed 's/stats/\nstats/g' | grep stats
  grep -h -i 'error' "$OUT"/gap_${f}_*.log | sort | uniq -c | head
done | tee "$OUT/summary.txt"
echo "=== all"; cat "$OUT"/d5s_*.jsonl | python q99sum.py | tee -a "$OUT/summary.txt"
[ -e "$OUT/HIT" ] && echo "!!! z in D_5 found: $(cat "$OUT/HIT")"
gzip -f "$OUT"/q_*.jsonl
