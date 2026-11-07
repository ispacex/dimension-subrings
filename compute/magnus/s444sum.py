"""MATH-444 / D5-49: summary of d5s.py output on s444.g records (gamma_4 = C_3, cyclic centre, Q'' != 1,
exp(gamma_2/gamma_3) >= 9, e23 >= 2), split by (H2) gamma_2^9 <= gamma_4 and by Q/gamma_2.  Usage: python s444sum.py < d5s.jsonl"""
import json
import sys
from collections import defaultdict

R = [json.loads(l) for l in sys.stdin if l.strip()]
R = [r for r in R if "id" in r]
fam = defaultdict(list)
for r in R:
    fam[(str(sorted(r["ab"], reverse=True)), "H2" if r["H2"] else "notH2")].append(r)
print("# columns: records | z in D5 | cert all | ctrl D4 all | zcyc all | |g4|=3 all | inM5 | inQ'' | id3 all | idcube all"
      " | id4 (H2 rows: all; notH2 rows: count true) | psi_d | tahara g=1 / run | logord range | psi range")
for key in sorted(fam):
    L = fam[key]
    hit = [r["id"] for r in L if any(r["z_in_D5"])]
    tr = [r for r in L if r["tah"] in ("true", "false")]
    pd = sorted({d for r in L for d in r["psi_d"]})
    print(key, len(L), "| zD5", len(hit), hit[:5], "| cert", all(r["cert"] for r in L),
          "| ctrlD4", all(r["ctrl_z_in_D4"] for r in L), "| zcyc", all(r["zcyc"] for r in L),
          "| g4=C3", all(r["e4"] == 1 and r["lcs"][3] == 1 for r in L),
          "| inM5", sum(r["inM5"] for r in L), "| inQ''", sum(r["inQ2"] for r in L),
          "| id3", all(r["id3"] for r in L), "| idcube", all(r["idcube"] for r in L),
          "| id4", sum(r["id4"] for r in L), "| psi_d", pd,
          "| tah", sum(r["tah"] == "true" for r in tr), "/", len(tr),
          "| logord", min(r["logord"] for r in L), max(r["logord"] for r in L),
          "| psi", min(r["psi"] for r in L), max(r["psi"] for r in L),
          "| e23", sorted({r["e23"] for r in L}),
          "| tah non-vacuous", sum(r.get("tah_free", -1) > 0 for r in L))
tot = len(R)
print("total records", tot, "| z in D5", sum(any(r["z_in_D5"]) for r in R),
      "| H2", sum(r["H2"] for r in R), "| notH2", sum(not r["H2"] for r in R),
      "| tahara run", sum(r["tah"] in ("true", "false") for r in R), "| tahara g<>1", sum(r["tah"] == "false" for r in R),
      "| tahara non-vacuous (g not 1 on Z^n)", sum(r.get("tah_free", -1) > 0 for r in R))
