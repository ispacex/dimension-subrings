"""MATH-135: summary of d5s.py output on q9gen.g groups.  Usage: python q9sum.py < d5s.jsonl"""
import json
import sys
from collections import Counter

L = [json.loads(l) for l in sys.stdin if l.strip()]
L = [r for r in L if "id" in r]
nm = [r for r in L if r.get("nonmet", r["dd"] > 0)]


def line(name, R):
    print(name, "groups", len(R), "| S>1", sum(r["S"] > 0 for r in R),
          "| z checked", sum(r["nz"] for r in R), "| any z in D5", sum(any(r["z_in_D5"]) for r in R),
          "| cert all", all(r["cert"] for r in R), "| ctrl D4 all", all(r["ctrl_z_in_D4"] for r in R),
          "| id_ok all", all(r["id_ok"] for r in R), "| nq_ok", Counter(str(r.get("nq_ok")) for r in R))


line("all", L)
line("non-metabelian", nm)
for k in sorted(set(r["k"] for r in L)):
    line(f"  s={k}", [r for r in L if r["k"] == k])
    line(f"  s={k} non-met", [r for r in nm if r["k"] == k])
line("non-met eps0 (x_s^9 in gamma_3)", [r for r in nm if r["eps0"]])
line("non-met eps1", [r for r in nm if not r["eps0"]])
line("non-met eps0, m>=1", [r for r in nm if r["eps0"] and r["m"] >= 1])
print("ab", Counter(str(r["ab"]) for r in L))
print("logord range", min(r["logord"] for r in L), max(r["logord"] for r in L),
      "| pclass", Counter(r["pclass"] for r in L), "| m", Counter((r["eps0"], r["m"]) for r in nm))
print("S>1 & eps0:", [(r["id"], r["k"], r["lcs"], r["dd"], r["S"], r["m"]) for r in nm if r["S"] > 0 and r["eps0"]][:60])
print("S>1 & eps1:", [(r["id"], r["k"], r["lcs"], r["dd"], r["S"], r["m"]) for r in nm if r["S"] > 0 and not r["eps0"]][:60])
