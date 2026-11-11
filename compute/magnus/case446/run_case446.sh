#!/bin/bash
# MATH-446 / D5-51: computational check of the case (b) reduction (gamma_4 = C_9, cyclic centre), from the
# Open Math OS session of 12.11.2026 (Kimi K3.1 Pro); reworked after the 703 review of dimension-subrings#145.
# Usage (tm job, tree root, cache mikh): bash compute/magnus/case446/run_case446.sh [smoke|main]
# Each shard: groups with Q_ab of the given type, gamma_4 = C_9, cyclic centre; adapted basis (AdaptedX1, as in
# star444.g).  Wave 1 = the original four shards (same seeds, EXTRAW [2,3,3,4]: power words of weight 3 only, so
# Ybar_i = 0 in L_2 for the generators of the presentation); wave 2 = EXTRAW [2,2,3,4] (power words of weight 2
# or 3), standard and reversed generator order, where omega(cbar, Ybar) <> 1 occurs.  Output per shard:
# run.jsonl (per group / per control lattice) and run.jsonl.final (FINAL = old counters; CTL = per control
# lattice, with "differs" = HNF differs from the full lattice; GRP = per-group shares; NEW = substantive counters
# rec(n, lhs, rhs, bad), see newchecks.g).  At most 4 shards run at a time.
set -euo pipefail
export PATH=$JOB_CACHE/bin:$PATH
PLAN=${1:-main}
cd "$(dirname "$0")/.."                      # compute/magnus: lib446.g reads tahara61.g from here
OUT=${JOB_OUT:-$PWD/case446/out}; mkdir -p "$OUT"
C=$PWD/case446
run() {  # name seed NG KS TOPS EXTRAW GENORDER
  local d=$OUT/$1; mkdir -p "$d"
  cat > "$d/driver.g" <<GEOF
MODE := "$1";; NG := $3;; KS := $4;; TOPS := $5;; EXTRAW := $6;; GENORDER := "$7";;
MAXV := 1400;; WATCH := 1500;; TRIALS := 80;; BIGLAT := 1500;; CTL_MAXLAT := 2500;; NEW_MAXLAT := 2500;;
DO_CONTROLS := true;; NEEDNOTH2 := false;;
Reset(GlobalMersenneTwister, $2);; Reset(GlobalRandomSource, $2);;
OUT := "$d/run.jsonl";;
Read("$C/lib446.g");; Read("$C/newchecks.g");; Read("$C/run446.g");;
GEOF
  timeout 1700 gap -q -b -o 4g "$d/driver.g" > "$d/gap.log" 2>&1
}
W1='[2,3,3,4]'; W2='[2,2,3,4]'
if [ "$PLAN" = smoke ]; then
  wave1=("o339 339 6 [3] [[9,9]] $W1 std" "v339 5339 20 [3] [[9,9]] $W2 rev"
         "w339 6339 20 [3] [[9,9]] [2,2,2,4] rev" "x339 7339 20 [3] [[9,9]] [3,2,2,4] rev")
  wave2=()
else
  wave1=("r339 339 120 [3] [[9,9]] $W1 std" "r279 279 110 [3] [[27,9]] $W1 std"
         "r999 999 110 [3] [[9,9,9]] $W1 std" "r9933 9933 90 [4] [[9,9]] $W1 std")
  wave2=("n339 4339 120 [3] [[9,9]] $W2 std" "v339 5339 120 [3] [[9,9]] $W2 rev"
         "n279 4279 100 [3] [[27,9]] $W2 rev" "n999 4999 100 [3] [[9,9,9]] $W2 std")
fi
rc=0
runwave() {  # the shards of one wave in parallel
  local pids=() sp p
  set -f                                     # TOPS like [[9,9]] must not glob
  for sp in "$@"; do run $sp & pids+=($!); done
  set +f
  for p in "${pids[@]}"; do wait "$p" || rc=1; done
}
runwave "${wave1[@]}"
if [ ${#wave2[@]} -gt 0 ]; then runwave "${wave2[@]}"; fi
for d in "$OUT"/*/; do
  s=$(basename "$d"); echo "== $s"
  if [ -f "$d/run.jsonl.final" ]; then cat "$d/run.jsonl.final"; else echo "no FINAL"; tail -5 "$d/gap.log"; rc=1; fi
done
exit $rc
