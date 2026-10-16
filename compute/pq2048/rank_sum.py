"""rank_sum.py OUTDIR — the sums of a run_rank.sh run.

Adds the stat files of the pieces A/a, B/b_*, C/c_* by level, writes the candidates of order
2^11 of all pieces renumbered 1, 2, ... into OUTDIR/c2048.jsonl (when it is not there yet) and, if
OUTDIR/b2048.jsonl (the lattice) exists, counts its answers at n = 4 and 5.  Prints JSON.
"""
import glob
import json
import os
import re
import sys

out = sys.argv[1]
stats = [os.path.join(out, "A", "a.json")] + sorted(glob.glob(os.path.join(out, "B", "b_*.json"))) \
    + sorted(glob.glob(os.path.join(out, "C", "c_*.json")))
tot = {}
pieces = 0
for f in stats:
    if not os.path.exists(f):
        continue
    pieces += 1
    s = json.load(open(f))
    for k, v in s.items():
        if isinstance(v, list):
            t = tot.setdefault(k, [])
            t.extend([0] * (len(v) - len(t)))
            for i, x in enumerate(v):
                t[i] += x
cand_files = [f[:-5] + ".jsonl" for f in stats if os.path.exists(f)]
c2048 = os.path.join(out, "c2048.jsonl")
if not os.path.exists(c2048):
    n = 0
    with open(c2048 + ".tmp", "w") as o:
        for f in cand_files:
            if not os.path.exists(f):
                continue
            for line in open(f):
                if '"order":2048' not in line:
                    continue
                n += 1
                o.write(re.sub(r'"id":\d+', f'"id":{n}', line, count=1))
    os.rename(c2048 + ".tmp", c2048)
res = {"pieces": pieces, "levels": tot,
       "candidates_2048": sum(1 for _ in open(c2048)),
       "cpu_h": {k: round(sum(v) / 3.6e6, 2) for k, v in tot.items() if k.startswith("ms_")}}
lat = os.path.join(out, "b2048.jsonl")
if os.path.exists(lat):
    a = {"lines": 0, "D4_eq_1": 0, "D5_eq_1": 0, "all_equal": 0}
    for line in open(lat):
        r = json.loads(line)
        a["lines"] += 1
        lv = {x["n"]: x for x in r["levels"]}
        a["D4_eq_1"] += lv.get(4, {}).get("Dn_order") == 1
        a["D5_eq_1"] += lv.get(5, {}).get("Dn_order") == 1
        a["all_equal"] += all(x["equal"] for x in r["levels"])
    res["lattice"] = a
json.dump(res, sys.stdout)
print()
