#!/usr/bin/env python3
"""Summary of a case451 job's out/ (MATH-451): per shard and total.  Usage: python3 sum451.py OUTDIR"""
import json, os, re, sys
from collections import Counter

REC = re.compile(r"(\w+) := (-?\d+)")


def rec(s):
    return {k: int(v) for k, v in REC.findall(s)}


def main(d):
    tot = Counter()
    types = Counter()
    for sh in sorted(os.listdir(d)):
        f = os.path.join(d, sh, "run.jsonl")
        if not os.path.isfile(f):
            continue
        c = Counter()
        for line in open(f):
            r = json.loads(line)
            if r["kind"] != "group":
                continue
            types[(tuple(r["ab"]), r["mu"])] += 1
            W, Wt, fr = rec(r["W"]), rec(r["Wterm"]), rec(r["free"])
            nb, nd, c1 = rec(r["noB"]), rec(r["noD"]), rec(r["c1"])
            fm = rec(r["forms"])
            bnd = max(r["mu"] - 1, 0)
            c["groups"] += 1
            c["mu>=2"] += r["mu"] >= 2
            c["g4_ord_" + str(sum(r["lcs"][3:]))] += 1
            c["gbad"] += r["gbad"] > 0
            c["gfree>0 (g nonvacuous)"] += r["gfree"] > 0
            c["W viol (R or term > bound)"] += W["viol"] > 0 or W["partviol"] > 0 or Wt["viol"] > 0
            c["W R<>1"] += W["nontriv"] > 0
            c["W some term <>1"] += Wt["nontriv"] > 0
            c["W R of order 9"] += W["maxR"] >= 2
            c["informative (ctl free viol, W ok)"] += fr["viol"] > 0 and W["viol"] == 0 and Wt["viol"] == 0
            c["Lemma 12.5(b) attained (pairmax = mu > 0)"] += r["mu"] > 0 and fm["pairmax"] == r["mu"]
            # mu <= K needed for Omega_{mu-1} = 3 Omega_mu (cyclic C_{3^K})
            c["mu > K (bound reads differently)"] += r["mu"] > r["lcs"][3]
            c["W R attains bound (mu>=2, ord 3^(mu-1))"] += r["mu"] >= 2 and W["maxR"] == bnd and bnd > 0
            c["ctl free viol"] += fr["viol"] > 0
            c["ctl noB3 viol"] += nb["viol"] > 0
            c["ctl noD23 viol"] += nd["viol"] > 0
            c["ctl c1only viol"] += c1["viol"] > 0
            c["thm2 bad (g^2<>R)"] += r["thm2bad"] > 0
            c["thm2 R<>1"] += r["thm2nontriv"] > 0
            c["omega(cbar,Ybar) order > d(i)"] += fm["omYbad"] > 0
            c["omega(c_top,L2) outside Omega_mu"] += fm["pairbad"] > 0
            c["omega(cbar,Ybar) <> 1"] += fm["omY"] > 0
            c["omega(cbar,Ybar) order>=9"] += fm["omYmax"] >= 2
            c["omega(c_top,Ybar_s) <> 1"] += fm["pairY"] > 0
        f5 = os.path.join(d, sh, "d5s.jsonl")
        if os.path.isfile(f5):
            for line in open(f5):
                r = json.loads(line)
                if "z_in_D5" in r:
                    c["d5s records"] += 1
                    c["z in D5"] += any(r["z_in_D5"])
                    c["cert ok"] += bool(r["cert"])
                    c["ctrl z in D4"] += bool(r["ctrl_z_in_D4"])
        print(sh, dict(c))
        tot.update(c)
    print("TOTAL", dict(tot))
    print("TYPES", {f"{list(k[0])} mu={k[1]}": v for k, v in sorted(types.items())})


if __name__ == "__main__":
    main(sys.argv[1])
