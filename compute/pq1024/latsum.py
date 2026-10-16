"""Summarize lat/out.jsonl: by rank, how many candidates, how many with D_4 = 1, D_5 = 1,
any level with D_n != gamma_n, and the lattice time."""
import json
import sys
from collections import defaultdict

by = defaultdict(lambda: defaultdict(float))
bad = []
for line in open(sys.argv[1] if len(sys.argv) > 1 else "lat/out.jsonl"):
    r = json.loads(line)
    lv = {x["n"]: x for x in r["levels"]}
    d = r["d"]
    s = by[d]
    s["n"] += 1
    s["sec"] += r["seconds"]
    D4 = lv[4]["Dn_order"] if 4 in lv else 1
    D5 = lv[5]["Dn_order"] if 5 in lv else 1
    s["D4=1"] += D4 == 1
    s["D5=1"] += D5 == 1
    if any(not x["equal"] for x in r["levels"]):
        s["Dn!=gamma_n"] += 1
        bad.append((r["id"], [(x["n"], x["Dn_order"], x["gamma_order"]) for x in r["levels"] if not x["equal"]]))
for d in sorted(by):
    s = by[d]
    print(f"d={d}: groups {int(s['n'])}, D4=1 {int(s['D4=1'])}, D5=1 {int(s['D5=1'])}, "
          f"Dn!=gamma_n {int(s['Dn!=gamma_n'])}, lattice {s['sec'] / 3600:.2f} h")
print("total", sum(int(s["n"]) for s in by.values()))
for b in bad[:20]:
    print("not equal:", b)
