#!/usr/bin/env bash
# split_ids.sh OUTDIR STEP — every unfinished id-range piece B/in_dNNNNN of more than STEP ids is
# replaced by pieces of STEP ids (B/in_dNNNNN keeps the first, the rest become B/in_dNNNNNsMMM);
# its partial outputs are removed.  run_rank.sh then runs them PD at a time.
set -u
out=$1; step=$2
for f in "$out"/B/in_d*; do
  id=${f##*/in_}
  [ -s "$out/B/b_$id.json" ] && continue
  grep -q '"ids"' "$f" || continue
  python3 - "$f" "$step" "$out/B" "$id" <<'PY'
import json, sys, os
f, step, d, pid = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
x = json.loads(open(f).read())
a, b = x["ids"]
if b - a + 1 <= step: sys.exit(0)
parts = [(s, min(b, s + step - 1)) for s in range(a, b + 1, step)]
for j, (s, e) in enumerate(parts):
    y = dict(x); y["ids"] = [s, e]
    name = f if j == 0 else os.path.join(d, "in_%ss%03d" % (pid, j))
    open(name, "w").write(json.dumps(y, separators=(",", ":")) + "\n")
for suf in (".json", ".jsonl", ".log"):
    p = os.path.join(d, "b_" + pid + suf)
    if os.path.exists(p): os.remove(p)
print(pid, "->", len(parts), "pieces")
PY
done
