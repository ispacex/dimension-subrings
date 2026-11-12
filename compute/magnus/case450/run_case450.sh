#!/bin/bash
# MATH-450: gamma_4 = C_9, cyclic centre, Q_ab types other than [3,9,9] (wiki 891 Sec. 11).
# Usage (tm job, tree root, cache mikh): bash compute/magnus/case450/run_case450.sh [smoke|main]
# Shards: types with |B| = 2 (B = {i : d(i) >= 9}) test Theorem 11.1 (R = 0 on the weak lattice W, with controls);
# types with |B| >= 3 locate the obstruction (R on W and on W strengthened) and test g = 1 on the full lattice.
# Groups as in case446 (OneC9 from lib446.g; EXTRAW [2,2,3,4] = power words of weight 2 or 3, so Ybar_i <> 0 in L_2).
set -euo pipefail
export PATH=$JOB_CACHE/bin:$PATH
PLAN=${1:-main}
cd "$(dirname "$0")/.."                      # compute/magnus
OUT=${JOB_OUT:-$PWD/case450/out}; mkdir -p "$OUT"
run() {  # name seed NG KS TOPS EXTRAW GENORDER FORCE13 WATCH
  local d=$OUT/$1; mkdir -p "$d"
  cat > "$d/driver.g" <<GEOF
MODE := "$1";; NG := $3;; KS := $4;; TOPS := $5;; EXTRAW := $6;; GENORDER := "$7";; FORCE13 := $8;;
MAXV := 1400;; WATCH := $9;; TRIALS := 80;; BIGLAT := 1500;;
Reset(GlobalMersenneTwister, $2);; Reset(GlobalRandomSource, $2);;
OUT := "$d/run.jsonl";;
Read("case450/lib450.g");; Read("case450/run450.g");;
GEOF
  timeout $(( $9 + 600 )) gap -q -b -o 6g "$d/driver.g" > "$d/gap.log" 2>&1
}
W2='[2,2,3,4]'; W3='[3,2,2,4]'
if [ "$PLAN" = smoke ]; then
  wave1=("s279 1279 4 [3] [[27,9]] $W2 std true 300" "s999 1999 4 [3] [[9,9,9]] $W2 rev false 300"
         "s3999 13999 3 [4] [[9,9,9]] $W2 std true 300" "s9927 19927 3 [3] [[27,9,9]] $W2 rev false 300")
  wave2=()
else
  # |B| = 2: Theorem 11.1 and its controls
  wave1=("a279 2279 100 [3] [[27,9]] $W2 std true 1500" "b279 3279 100 [3] [[27,9]] $W2 rev false 1500"
         "a339 2339 100 [3] [[9,9]] $W2 rev true 1500" "a3927 23927 60 [4] [[27,9]] $W2 std true 1500"
         "a2727 22727 40 [3] [[27,27]] $W2 rev true 1500")
  # |B| >= 3: obstruction and g = 1
  wave2=("a999 2999 100 [3] [[9,9,9]] $W2 rev false 1500" "b999 3999 100 [3] [[9,9,9]] $W3 std false 1500"
         "a3999 23999 60 [4] [[9,9,9]] $W2 std true 1500" "a9927 29927 40 [3] [[27,9,9]] $W2 rev false 1500"
         "a9999 29999 40 [4] [[9,9,9,9]] $W2 rev false 1500")
fi
rc=0
runwave() {
  local pids=() sp p
  set -f
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
