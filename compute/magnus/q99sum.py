"""MATH-443 / D5-5: summary of d5s.py output on q99gen.g groups, one row per family (tops, s).
Usage: python q99sum.py < d5s.jsonl   (several families may be concatenated)."""
import json
import sys
from collections import Counter, defaultdict

L = [json.loads(l) for l in sys.stdin if l.strip()]
L = [r for r in L if "id" in r]


def row(name, R):
    nm = [r for r in R if r["nonmet"]]
    zS = sum(r["nzS"] for r in R)
    zX = sum(r["nz"] - r["nzS"] for r in R)
    hit = [r["id"] for r in R if any(r["z_in_D5"])]
    print(f"{name}: groups {len(R)} | non-met {len(nm)} | e23=2 {sum(r['e23'] >= 2 for r in R)}"
          f" (non-met {sum(r['e23'] >= 2 for r in nm)}) | eps0 {sum(r['eps0'] for r in R)}"
          f" | Z cyclic {sum(r['zcyc'] for r in R)} (non-met {sum(r['zcyc'] for r in nm)})"
          f" | |Q|>=3^10 {sum(r['logord'] >= 10 for r in R)} (non-met {sum(r['logord'] >= 10 for r in nm)})"
          f" | S>1 {sum(r['S'] > 0 for r in R)} | S4>1 {sum(r['S4'] > 0 for r in R)}"
          f" | z in S {zS} | z in S4\\S {zX} | s4skip {sum(r['s4skip'] for r in R)}"
          f" | z in D5: {len(hit)} {hit[:10]}"
          f" | cert all {all(r['cert'] for r in R)} | ctrl D4 all {all(r['ctrl_z_in_D4'] for r in R)}"
          f" | pq_stable all {all(r['pq_stable'] for r in R)}")


fam = defaultdict(list)
for r in L:
    fam[(tuple(r["tops"]), r["k"])].append(r)
row("all", L)
for key in sorted(fam):
    row(f"  tops={list(key[0])} s={key[1]}", fam[key])
nm = [r for r in L if r["nonmet"]]
row("non-met, e23=2", [r for r in nm if r["e23"] >= 2])
row("non-met, e23=2, Z cyclic", [r for r in nm if r["e23"] >= 2 and r["zcyc"]])
row("non-met, e23=2, |Q|>=3^10", [r for r in nm if r["e23"] >= 2 and r["logord"] >= 10])
if not L:
    sys.exit(0)
print("ab", Counter(str(r["ab"]) for r in L))
print("logord range", min(r["logord"] for r in L), max(r["logord"] for r in L),
      "| logord", sorted(Counter(r["logord"] for r in L).items()),
      "| pclass", sorted(Counter(r["pclass"] for r in L).items()),
      "| (e23,e34,e4)", sorted(Counter((r["e23"], r["e34"], r["e4"]) for r in L).items()))
