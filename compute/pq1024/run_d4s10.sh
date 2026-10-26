#!/bin/bash
# MATH-415: the D_4 search one order up, by desc1c.g with JK = 4, PCMIN = 2 (README, "D_4").
#   MODE=check  orders 256 and 512 from all parents of orders 128 and 256, up to isomorphism
#               (DEDUP); must give the survivors of ../magnus/d4s9.g: 412 and 4421, by rank
#               [12,124,249,23,4] and [21,128,3682,562,25,3] for ranks 2..7.
#   MODE=main   order 1024 from all SmallGroup(512, i) (class 2-3 and cyclic gamma_3 are tested
#               inside), no isomorphism reduction (every admissible hyperplane is a candidate of
#               its own), then latb/magnus_pres.py on the candidates: |D_4 ∩ {1, n}|.
# CHUNKS="a:b a:b" overrides the main ranges (a benchmark); CH ids per GAP call, NSH shards.
# Output in $JOB_OUT: d<order>_<a>.json (stat), c<order>_<a>.jsonl, gap_<s>.out, lat_all.jsonl,
# summary.txt.
cd "$(dirname "$0")"
MODE=${MODE:-main}; NSH=${NSH:-10}; CH=${CH:-20000}; OUTD=${JOB_OUT:-out}; mkdir -p "$OUTD"
GAP=${GAP:-$JOB_CACHE/gap/gap}; PY=${PY:-$(ls -d $JOB_CACHE/venv-*/bin/python | head -1)}
gapr() { $GAP -q -b --quitonbreak -o ${GAPMEM:-1500m}; }
one() {  # NN a b dedup
  echo "NN:=$1;; IDFROM:=$2;; IDTO:=$3;; PRUNE:=true;; DEDUP:=$4;; JK:=4;; PCMIN:=2;; NMAXL:=4;; OUTFILE:=\"$OUTD/c$(($1 * 2))_$2.jsonl\";; STATFILE:=\"$OUTD/d$(($1 * 2))_$2.json\";;" \
    | cat - desc1c.g | gapr
}
if [ "$MODE" = check ]; then
  for nn in 128 256; do
    nr=$([ $nn = 128 ] && echo 2328 || echo 56092); step=$(( (nr + NSH - 1) / NSH ))
    for s in $(seq 0 $((NSH - 1))); do
      a=$((1 + s * step)); b=$((a + step - 1)); [ $b -gt $nr ] && b=$nr
      (one $nn $a $b true >> "$OUTD/gap_$s.out" 2>&1) &
    done
    wait
  done
  $PY - "$OUTD" <<'PYEOF' | tee "$OUTD/summary.txt"
import glob, json, sys
for order in (256, 512):
    st = [json.loads(open(f).read()) for f in glob.glob(f"{sys.argv[1]}/d{order}_*.json")]
    by = [0] * 10
    for s in st:
        for i, x in enumerate(s["candidates_by_rank"]):
            by[i] += x
    print(order, "stat files", len(st), "candidates", sum(by), "by rank 1..", by[:8],
          "fallback parents", sum(s["fallback_parents"] for s in st))
PYEOF
  exit 0
fi
RANGES=${CHUNKS:-1:10494213}
for r in $RANGES; do a=${r%:*}; b=${r#*:}
  while [ "$a" -le "$b" ]; do e=$((a + CH - 1)); [ "$e" -gt "$b" ] && e=$b; echo "$a $e"; a=$((e + 1)); done
done > "$OUTD/chunks.txt"
TOTAL=$(wc -l < "$OUTD/chunks.txt")
for s in $(seq 0 $((NSH - 1))); do
  (awk -v s=$s -v n=$NSH '(NR - 1) % n == s' "$OUTD/chunks.txt" | while read a e; do
     [ -s "$OUTD/d1024_$a.json" ] || one 512 $a $e false >> "$OUTD/gap_$s.out" 2>&1
   done) &
done
while [ "$(jobs -r | wc -l)" -gt 0 ]; do
  [ -n "$JOB_ROOT" ] && echo "$(ls "$OUTD"/d1024_*.json 2>/dev/null | wc -l)/$TOTAL" > "$JOB_ROOT/progress"
  sleep 60
done
wait
cat "$OUTD"/c1024_*.jsonl 2>/dev/null | $PY latb/magnus_pres.py --jobs "$NSH" > "$OUTD/lat_all.jsonl"
$PY - "$OUTD" "$TOTAL" <<'PYEOF' | tee "$OUTD/summary.txt"
import glob, json, sys
d, total = sys.argv[1], int(sys.argv[2])
st = [json.loads(open(f).read()) for f in glob.glob(f"{d}/d1024_*.json")]
print("stat files", len(st), "of", total, "(COMPLETE)" if len(st) == total else "(INCOMPLETE)")
keys = ["parents", "skipped_gamma3", "parents_with_U", "admissible_U", "fallback_parents", "cand_U", "gap_ms", "cpu_ms"]
print({k: sum(s[k] for s in st) for k in keys}, "max_k", max([s["max_k"] for s in st] or [0]))
by = [0] * 10
for s in st:
    for i, x in enumerate(s["candidates_by_rank"]):
        by[i] += x
ncand = sum(1 for f in glob.glob(f"{d}/c1024_*.jsonl") for l in open(f) if l.strip())
print("candidates by rank 1..", by[:9], "lines", ncand)
res = [json.loads(l) for f in glob.glob(f"{d}/lat_*.jsonl") for l in open(f) if l.strip()]
hit = [r for r in res if any(lv["n"] == 4 and lv["Dn_order"] > 1 for lv in r["levels"])]
cert = [r for r in hit if all(lv.get("certified") for lv in r["levels"] if lv["n"] == 4)]
print("decided", len(res), "of", ncand, "; n in D_4:", len(hit), "certified", len(cert),
      [(r.get("id"), r.get("parent")) for r in hit][:20])
PYEOF
