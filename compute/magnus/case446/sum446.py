#!/usr/bin/env python3
"""Tables for case446_result.txt from the run.jsonl.final files of run_case446.sh (MATH-446).

Usage: python3 sum446.py DIR [shard ...]   (default: all shards in DIR)
DIR is a job's out/ (DIR/<shard>/run.jsonl.final) or a results_<sha>/ directory (DIR/<shard>.final).
Prints, summed over the given shards: GRP shares, per-control lattice table (CTL), and the substantive counters
(NEW: n, lhs<>1, rhs<>1, lhs<>rhs) grouped into positive checks and negative controls (names with "_ctl").
"""
import os
import re
import sys
from collections import defaultdict

CTL_EXTRA = {"cor3R_wide_noD23"}  # outside (c3): effectively a control
COUNTS = {"omega_cY", "tpart_base"}  # omega(cbar_ab, Ybar_h); t(c;x_i,x_i) t(c;x_h,x_h)^-1 before the coefficient
REC = re.compile(r"(\w+) := (-?\d+|true|false)")


def parse(rec):
    return {k: int(v) if v not in ("true", "false") else v for k, v in REC.findall(rec)}


def path(outdir, s):
    p = os.path.join(outdir, s, "run.jsonl.final")
    return p if os.path.isfile(p) else os.path.join(outdir, s + ".final")


def shards_in(outdir):
    return sorted(d[:-6] if d.endswith(".final") else d for d in os.listdir(outdir)
                  if os.path.isfile(path(outdir, d[:-6] if d.endswith(".final") else d)))


def load(outdir, shards):
    grp, ctl, new, final = defaultdict(int), defaultdict(lambda: defaultdict(int)), defaultdict(lambda: defaultdict(int)), defaultdict(int)
    for s in shards:
        for line in open(path(outdir, s)):
            kind, rest = line.split(" ", 1)
            if kind == "GRP":
                for k, v in parse(rest).items():
                    grp[k] += v
            elif kind == "CTL":
                md, rec = rest.split(" ", 1)
                for k, v in parse(rec).items():
                    ctl[md][k] += v
            elif kind == "NEW":
                nm, rec = rest.split(" ", 1)
                for k, v in parse(rec).items():
                    new[nm][k] += v
            elif kind == "FINAL":
                for k, v in parse(rest).items():
                    final[k] += v
    return final, grp, ctl, new


def main():
    outdir = sys.argv[1]
    shards = sys.argv[2:] or shards_in(outdir)
    final, grp, ctl, new = load(outdir, shards)
    print("shards:", " ".join(shards))
    print("FINAL (old counters):", " ".join(f"{k}={v}" for k, v in sorted(final.items())))
    print("GRP:", " ".join(f"{k}={v}" for k, v in sorted(grp.items())))
    print("\nper control lattice (differs = HNF differs from the full lattice (A)-(F)):")
    cols = ["groups", "differs", "vectors", "skipbig", "A3bad", "cor_bad", "t1bad", "tpartbad", "t2bad", "thm2bad", "starbad", "factorbad", "gbad"]
    print(f"  {'control':8s} " + " ".join(f"{c:>9s}" for c in cols))
    for md, r in ctl.items():
        print(f"  {md:8s} " + " ".join(f"{r[c]:>9d}" for c in cols))
    print("\nnontriviality counts (no identity; lhs<>1 = how often the value is <> 1):")
    for nm in sorted(n for n in new if n in COUNTS):
        print(f"  {nm:32s} n={new[nm]['n']} ne1={new[nm]['lhs']}")
    for title, pick in (("positive checks", lambda n: "_ctl" not in n and n not in COUNTS | CTL_EXTRA),
                        ("negative controls (bad > 0 expected; 0 where the sides are 1)", lambda n: "_ctl" in n or n in CTL_EXTRA)):
        print(f"\n{title}:")
        print(f"  {'name':32s} {'n':>7s} {'lhs<>1':>7s} {'rhs<>1':>7s} {'bad':>7s}")
        for nm in sorted(n for n in new if pick(n)):
            r = new[nm]
            print(f"  {nm:32s} {r['n']:>7d} {r['lhs']:>7d} {r['rhs']:>7d} {r['bad']:>7d}")


if __name__ == "__main__":
    main()
