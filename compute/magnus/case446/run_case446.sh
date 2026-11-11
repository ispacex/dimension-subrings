#!/bin/bash
# MATH-446 / D5-51: computational check of the case (b) reduction (gamma_4 = C_9, cyclic centre), from the
# Open Math OS session of 12.11.2026 (Kimi K3.1 Pro), moved here from the tm job
# kimmy/tm/20261111-215358-case446-real-fixeddir-841f7c0 for review.  Four shards in parallel, as in that job.
# Usage (tm job, tree root, cache mikh): bash compute/magnus/case446/run_case446.sh
# Each shard: groups with Q_ab of the given top type, gamma_4 = C_9, cyclic centre; adapted basis (AdaptedX1, as
# in star444.g); on a Z-basis of the admissible lattice (A)-(F): (star), Theorem 2 residual, Corollary 3 ([3,9,9]),
# omega identities, (A_3), T_1 t-part, T_2 formula, (Delta); controls dropping (A), (D_1), (F_1), weakening (B),
# (D_2) to mod 3, dropping (E).  Final line of each gap.log: FINAL rec(...).
set -euo pipefail
export PATH=$JOB_CACHE/bin:$PATH
cd "$(dirname "$0")/.."                      # compute/magnus: lib446.g reads tahara61.g from here
OUT=${JOB_OUT:-$PWD/case446/out}; mkdir -p "$OUT"
C=$PWD/case446
run() {  # name seed NG KS TOPS
  local d=$OUT/$1; mkdir -p "$d"
  cat > "$d/driver.g" <<GEOF
MODE := "$1";; NG := $3;; KS := $4;; TOPS := $5;;
MAXV := 1400;; WATCH := 720;; TRIALS := 80;; BIGLAT := 1500;; CTL_MAXLAT := 2500;;
DO_CONTROLS := true;; NEEDNOTH2 := false;;
Reset(GlobalMersenneTwister, $2);; Reset(GlobalRandomSource, $2);;
OUT := "$d/run.jsonl";;
Read("$C/lib446.g");; Read("$C/newchecks.g");; Read("$C/run446.g");;
GEOF
  timeout 900 gap -q -b -o 4g "$d/driver.g" > "$d/gap.log" 2>&1
}
run r339 339 120 '[3]' '[[9,9]]' & p1=$!
run r279 279 110 '[3]' '[[27,9]]' & p2=$!
run r999 999 110 '[3]' '[[9,9,9]]' & p3=$!
run r9933 9933 90 '[4]' '[[9,9]]' & p4=$!
rc=0; for p in $p1 $p2 $p3 $p4; do wait $p || rc=1; done
for s in r339 r279 r999 r9933; do echo "== $s"; tr -d '\\\n' < "$OUT/$s/gap.log" | grep -o 'FINAL rec([^)]*)' || { echo "no FINAL"; rc=1; }; done
exit $rc
