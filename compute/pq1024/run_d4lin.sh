#!/bin/bash
# MATH-415: the D_4 search at order 1024 by d4lin.g + latb/d4lin.py (README, "D_4 by the p-cover,
# linearly").
#   MODE=ctrl   Tahara's groups (2,0) (Rips) and (2,1), orders 2^38, 2^39, |D_4| = 2: the parent
#               R = G/<w> must give U with n in D_4 (count_ND > 0)
#   MODE=check  orders 256 and 512 from all parents of orders 128, 256 (no example exists there:
#               ../magnus/d4s9.g and compute/): must give count_ND = 0 everywhere
#   MODE=main   order 1024 from all SmallGroup(512, i); CHUNKS="a:b ..." overrides the ranges
# Output in $JOB_OUT: l<order>_<a>.jsonl (parents with U), s<order>_<a>.json (stats),
# z<order>_<a>.jsonl (d4lin.py), summary.txt.
cd "$(dirname "$0")"
MODE=${MODE:-main}; NSH=${NSH:-8}; CH=${CH:-20000}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
GAP=${GAP:-$JOB_CACHE/gap/gap}; PY=${PY:-$(ls -d $JOB_CACHE/venv-*/bin/python | head -1)}
gapr() { $GAP -q -b --quitonbreak -o ${GAPMEM:-1500m}; }
one() {  # NN a b: GAP, then d4lin.py on its parents
  o=$((2 * $1))
  echo "NN:=$1;; IDFROM:=$2;; IDTO:=$3;; OUTFILE:=\"$OUTD/l${o}_$2.jsonl\";; STATFILE:=\"$OUTD/s${o}_$2.json\";;" \
    | cat - d4lin.g | gapr
  (cd latb && $PY d4lin.py < "$OUTD/l${o}_$2.jsonl" > "$OUTD/z${o}_$2.jsonl")
}
summ() {
  $PY - "$OUTD" "$@" <<'PYEOF'
import glob, json, sys
d = sys.argv[1]
for o in sys.argv[2:]:
    st = [json.loads(open(f).read()) for f in glob.glob(f"{d}/s{o}_*.json")]
    z = [json.loads(l) for f in glob.glob(f"{d}/z{o}_*.jsonl") for l in open(f) if l.strip()]
    nl = sum(1 for f in glob.glob(f"{d}/l{o}_*.jsonl") for l in open(f) if l.strip())
    tot = {k: sum(s[k] for s in st) for k in ("parents", "skipped_gamma3", "parents_with_U", "gap_ms")}
    pos = [(r["parent"], r["count_ND"], r["count_ABND"]) for r in z if r["count_ND"]]
    print(o, "stat files", len(st), tot, "| decided", len(z), "of", nl,
          "| sec", round(sum(r["seconds"] for r in z)), "| max m", max([r["m"] for r in z] or [0]),
          "| dim K_D", sorted({r["dim_KD"] for r in z}), "| parents with U, n in D_4:", len(pos), pos[:20])
PYEOF
}
case "$MODE" in
ctrl)
  for tl in 0 1; do
    o="ctrl$tl"
    echo "RIPSCTRL:=true;; TK:=2;; TL:=$tl;; OUTFILE:=\"$OUTD/l${o}_0.jsonl\";; STATFILE:=\"$OUTD/s${o}_0.json\";;" \
      | cat - d4lin.g | $GAP -q -b --quitonbreak -o 6g > "$OUTD/gap_$o.out" 2>&1
    (cd latb && $PY d4lin.py < "$OUTD/l${o}_0.jsonl" > "$OUTD/z${o}_0.jsonl")
  done
  { cat "$OUTD"/gap_ctrl*.out; cat "$OUTD"/zctrl*.jsonl; summ ctrl0 ctrl1; } | tee "$OUTD/summary.txt" ;;
check)
  for nn in 128 256; do
    nr=$([ $nn = 128 ] && echo 2328 || echo 56092); step=$(( (nr + NSH - 1) / NSH ))
    for s in $(seq 0 $((NSH - 1))); do
      a=$((1 + s * step)); b=$((a + step - 1)); [ $b -gt $nr ] && b=$nr
      (one $nn $a $b >> "$OUTD/gap_$s.out" 2>&1) &
    done
    wait
  done
  { grep -H -m3 Error "$OUTD"/gap_*.out && echo "GAP ERROR"; summ 256 512; } | tee "$OUTD/summary.txt" ;;
main)
  for r in ${CHUNKS:-1:10494213}; do a=${r%:*}; b=${r#*:}
    while [ "$a" -le "$b" ]; do e=$((a + CH - 1)); [ "$e" -gt "$b" ] && e=$b; echo "$a $e"; a=$((e + 1)); done
  done > "$OUTD/chunks.txt"
  TOTAL=$(wc -l < "$OUTD/chunks.txt")
  for s in $(seq 0 $((NSH - 1))); do
    (awk -v s=$s -v n=$NSH '(NR - 1) % n == s' "$OUTD/chunks.txt" | while read a e; do
       [ -s "$OUTD/s1024_$a.json" ] && [ -f "$OUTD/z1024_$a.jsonl" ] || one 512 $a $e >> "$OUTD/gap_$s.out" 2>&1
     done) &
  done
  while [ "$(jobs -r | wc -l)" -gt 0 ]; do
    [ -n "$JOB_ROOT" ] && echo "$(ls "$OUTD"/s1024_*.json 2>/dev/null | wc -l)/$TOTAL" > "$JOB_ROOT/progress"
    sleep 60
  done
  wait
  { grep -H -m3 Error "$OUTD"/gap_*.out && echo "GAP ERROR"
    n=$(ls "$OUTD"/s1024_*.json | wc -l); [ "$n" = "$TOTAL" ] && echo "chunks complete: $n" || echo "chunks INCOMPLETE: $n of $TOTAL"
    summ 1024; } | tee "$OUTD/summary.txt" ;;
esac
