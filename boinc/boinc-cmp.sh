#!/bin/bash
# boinc-cmp.sh TGZ OLDRUN — compare collect.sh results with an older run's B pieces (counters
# without ms_* and empty lists, candidates, dump), for the pieces both have.
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT; tar xzf "$1" -C "$t"
python3 - "$t/B" "$2/B" <<'PY'
import json, os, sys
a, b = sys.argv[1], sys.argv[2]
def st(p):
    d = json.load(open(p)); return {k: v for k, v in d.items() if not k.startswith("ms_") and v != [] and k not in ("onestage", "tah19", "thmA", "thmB")}
def rd(p): return open(p).read() if os.path.exists(p) else ""
same = diff = 0
for f in sorted(os.listdir(a)):
    if not (f.startswith("b_") and f.endswith(".json")): continue
    if not os.path.exists(os.path.join(b, f)): continue
    n = f[:-5]; i = n[2:]
    ok = st(os.path.join(a, f)) == st(os.path.join(b, f)) and rd(os.path.join(a, n + ".jsonl")) == rd(os.path.join(b, n + ".jsonl")) and rd(os.path.join(a, "dump_%s.jsonl" % i)) == rd(os.path.join(b, "dump_%s.jsonl" % i))
    if ok: same += 1
    else:
        diff += 1
        if diff <= 5: print("DIFF", n, st(os.path.join(a, f)), st(os.path.join(b, f)))
print("compared", same + diff, "same", same, "diff", diff)
PY
