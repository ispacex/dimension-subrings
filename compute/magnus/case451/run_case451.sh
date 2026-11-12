#!/bin/bash
# MATH-451: gamma_4 = C_{3^K} (K = 3 mostly), wiki 891 Sec. 12.  Usage (tm job, tree root, cache mikh):
#   bash compute/magnus/case451/run_case451.sh [smoke|main] [P]
# Shard line: name seed NG KS TOPS K EXTRAW GENORDER FORCE13.  Per shard: run.jsonl (+ .final via stdout FINAL line),
# d5in.jsonl -> d5s.py -> d5s.jsonl (z = generator of Omega_1(gamma_4) = Omega_1(Z); z in D5 decided exactly).
set -uo pipefail
export PATH=$JOB_CACHE/bin:$PATH
[ -f remote/py-env.sh ] && source remote/py-env.sh
PLAN=${1:-main}; P=${2:-4}
cd "$(dirname "$0")/.."                      # compute/magnus
OUT=${JOB_OUT:-$PWD/case451/out}; mkdir -p "$OUT"; ROOT=${JOB_ROOT:-$OUT}
C=$PWD/case451
one() {
  local name=$1 seed=$2 ng=$3 ks=$4 tops=$5 K=$6 xw=$7 go=$8 f13=$9
  local d=$OUT/$name; mkdir -p "$d"
  cat > "$d/driver.g" <<GEOF
MODE := "$name";; NG := $ng;; KS := $ks;; TOPS := $tops;; KG4 := $K;; EXTRAW := $xw;; GENORDER := "$go";; FORCE13 := $f13;;
MAXV := 1400;; WATCH := ${WATCHS:-2400};; TRIALS := 60;; BIGLAT := 1500;;
Reset(GlobalMersenneTwister, $seed);; Reset(GlobalRandomSource, $seed);;
OUT := "$d/run.jsonl";; D5OUT := "$d/d5in.jsonl";;
Read("$C/../case446/lib446.g");; Read("$C/../case446/newchecks.g");; Read("$C/lib451.g");; Read("$C/run451.g");;
GEOF
  local t0=$(date +%s)
  timeout $(( ${WATCHS:-2400} + 600 )) gap -q -b -o 6g "$d/driver.g" > "$d/gap.log" 2>&1
  local t1=$(date +%s)
  timeout 3000 python d5s.py ${D5E:-19} < "$d/d5in.jsonl" > "$d/d5s.jsonl" 2> "$d/d5s.err"
  echo "$name gen $((t1-t0)) s d5s $(( $(date +%s)-t1 )) s $(grep FINAL "$d/gap.log") $(tail -1 "$d/d5s.jsonl")" | tee -a "$OUT/times.txt"
  grep -q '"with_z_in_D5": [1-9]' "$d/d5s.jsonl" && echo "HIT $name" | tee -a "$OUT/HIT"
  grep -q 'TAHARA g <> 1' "$d/gap.log" && echo "TAHHIT $name" | tee -a "$OUT/HIT"
  echo x > "$ROOT/progress_$name"
}
export -f one; export OUT ROOT C
W2='[2,2,3,4]'; W3='[3,2,2,4]'; W1='[2,3,3,4]'
if [ "$PLAN" = smoke ]; then
  cat > "$OUT/plan.txt" <<PEOF
s27a 4511 3 [3] [[27,27]] 3 $W2 std true
s927 4512 3 [3] [[9,27,27]] 3 $W2 std false
PEOF
else
  cat > "$OUT/plan.txt" <<PEOF
a2727 45101 60 [3] [[27,27]] 3 $W2 std true
b2727 45102 60 [3,4] [[27,27]] 3 $W3 rev true
c2781 45103 40 [3] [[27,81]] 3 $W2 std true
d927k2 45104 60 [3] [[9,27]] 2 $W2 std true
e92727 45105 60 [3] [[9,27,27]] 3 $W2 std false
f92727 45106 60 [3] [[9,27,27]] 3 $W3 rev false
g272727 45107 40 [3] [[27,27,27]] 3 $W2 std false
h92727x 45108 40 [4] [[9,27,27]] 3 $W2 std true
PEOF
fi
grep -v '^#' "$OUT/plan.txt" | grep . | xargs -P "$P" -L 1 bash -c 'one "$@"' _
cat "$OUT"/times.txt
[ -e "$OUT/HIT" ] && echo "!!! hit: $(cat "$OUT/HIT")"
exit 0
