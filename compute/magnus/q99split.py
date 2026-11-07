"""MATH-443 / D5-5: split of a run_q99.sh output directory by (e23, Q/gamma_2, gamma_4), separately for the
groups of q99gen.g ("orig") and for their cyclic-centre quotients ("cyc", NCYC > 0).
Usage: python q99split.py OUTDIR   (reads OUTDIR/d5s_*.jsonl).
Columns: groups | non-met | z in Q'' (orig: S != 1) | z checked | z in Q'' | records with z in D5 | cert fail | ctrl D4 fail | Z cyclic.
For a "cyc" record Omega_1(Z) = <z> and gamma_5 = 1, so z notin D_5 means D_5 = 1 for that quotient (a nontrivial
normal D_5 would meet Z, hence contain <z>); there gamma_4 <= Z is cyclic, so gamma_4 = C_3 or C_9.
In "cyc" records tops, eps0, pqc are inherited from Q and pq_stable is not tested; the split keys on ab of the quotient."""
import json, sys, glob
from collections import defaultdict
R = []
for f in sorted(glob.glob(sys.argv[1] + "/d5s_*.jsonl")):
    fam = f.split("/d5s_")[1].rsplit("_", 1)[0]
    for l in open(f):
        r = json.loads(l)
        if "id" in r:
            r["fam"] = fam; R.append(r)
def g4(r):
    l = r["lcs"][3] if len(r["lcs"]) > 3 else 0
    if l == 1: return "C3"
    if l == 2 and r["e4"] == 2: return "C9"
    return "other(log|g4|=%d,e4=%d)" % (l, r["e4"])
def ab(r): return str(sorted(r["ab"], reverse=True))
for kind in ("orig", "cyc"):
    T = [r for r in R if bool(r.get("cyc")) == (kind == "cyc")]
    print("==", kind, "records", len(T), "e23 counts", {e: sum(r["e23"] == e for r in T) for e in (0, 1, 2, 3)})
    agg = defaultdict(lambda: [0]*9)
    for r in T:
        key = (r["e23"], ab(r), g4(r) if kind == "cyc" else ("zcyc" if r["zcyc"] else "-"))
        a = agg[key]
        a[0] += 1; a[1] += r["nonmet"]; a[2] += (r["S"] > 0) if kind == "orig" else (r["nzS"] > 0)
        a[3] += r["nz"]; a[4] += r["nzS"]; a[5] += any(r["z_in_D5"]); a[6] += (not r["cert"]); a[7] += (not r["ctrl_z_in_D4"])
        a[8] += r.get("zcyc", False)
    print("e23 | Q/g2 | g4 | groups | nonmet | S>1 (cyc: z in Q'') | z | z in Q'' | records with z in D5 | cert fail | ctrlD4 fail | Z cyclic")
    for k in sorted(agg): print(k, agg[k])
    hits = [r["id"] for r in T if any(r["z_in_D5"])]
    print("HITS", hits)
    if kind == "cyc":
        nm9 = [r for r in T if r["e23"] == 2 and r["nonmet"]]
        print("cyc nonmet e23=2 total", len(nm9), "by g4", {g: sum(g4(r) == g for r in nm9) for g in sorted(set(map(g4, nm9)))},
              "z in Q''", sum(r["nzS"] for r in nm9), "zcyc all", all(r["zcyc"] for r in nm9),
              "class4 all", all(r["cyc_class4"] for r in nm9), "inM5 all", all(r["cyc_inM5"] for r in nm9),
              "outside_g2", sum(r["cyc_outside_g2"] for r in nm9), "logord", min(r["logord"] for r in nm9), max(r["logord"] for r in nm9))
