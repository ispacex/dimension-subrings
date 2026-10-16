"""The check on 2^10: the run of run_check1024.sh against the 2^10 run (../pq1024/results/candidates.csv).

    cmp37.py tasks DESCDIR SPLITDIR > tasks.txt   # one line per parent: PARENT KS NEWFILE
    cmp37.py summary DESCDIR CMPDIR > summary.json

`tasks` splits the new candidate lines by parent (SPLITDIR/n_PARENT.jsonl) and lists every parent
that has candidates on either side.  `summary` sums the stat files of desc1c.g (parents, pruned
parents, candidates by rank, time) and the per-parent comparisons of cmp37.g.
"""
import csv
import glob
import json
import os
import re
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, "..", "pq1024", "results", "candidates.csv")


def ref_by_parent():
    ref = defaultdict(list)
    rank = {}
    for r in csv.DictReader(open(REF)):
        ref[int(r["parent"])].append(int(r["k"]))
        rank[int(r["parent"])] = int(r["rank"])
    return ref, rank


def new_by_parent(descdir):
    new = defaultdict(list)
    for f in glob.glob(os.path.join(descdir, "c1024_*.jsonl")):
        for line in open(f):
            m = re.search(r'"parent":(\d+),', line)
            if m:
                new[int(m.group(1))].append(line)
    return new


def tasks(descdir, splitdir):
    os.makedirs(splitdir, exist_ok=True)
    ref, _ = ref_by_parent()
    new = new_by_parent(descdir)
    for p in sorted(set(ref) | set(new)):
        nf = os.path.join(splitdir, f"n_{p}.jsonl")
        with open(nf, "w") as o:
            o.writelines(new.get(p, []))
        print(p, "[" + ",".join(map(str, ref.get(p, []))) + "]", nf)


def summary(descdir, cmpdir):
    ref, rank = ref_by_parent()
    tot = defaultdict(int)
    by_rank = defaultdict(lambda: defaultdict(int))
    for f in glob.glob(os.path.join(descdir, "d1024_*.json")):
        s = json.load(open(f))
        for k in ("parents", "skipped_gamma3", "pfiltered", "parents_with_U", "admissible_U",
                  "fallback_parents", "cand_U", "cand_orbits", "gap_ms", "cpu_ms", "wall_ms"):
            tot[k] += s.get(k, 0)
        tot["chunks"] += 1
        for d, c in enumerate(s["candidates_by_rank"], 1):
            by_rank[d]["new"] += c
    for p, ks in ref.items():
        by_rank[rank[p]]["ref"] += len(ks)
    cmp = {}
    for f in glob.glob(os.path.join(cmpdir, "cmp_*.json")):
        s = json.load(open(f))
        cmp[s["parent"]] = s
    new = new_by_parent(descdir)
    parents = sorted(set(ref) | set(new))
    missing = [p for p in parents if p not in cmp]
    bad = [p for p, s in cmp.items() if not s["same"]]
    res = {
        "desc1c": dict(tot),
        "candidates_by_rank": {d: dict(v) for d, v in sorted(by_rank.items())},
        "parents_with_candidates": {"ref": len(ref), "new": len(new),
                                    "only_ref": sorted(set(ref) - set(new)),
                                    "only_new": sorted(set(new) - set(ref))},
        "compared": len(cmp), "not_compared": missing, "different": bad,
        "direct": sum(s["direct"] for s in cmp.values()),
        "iso": sum(s["iso"] for s in cmp.values()),
        "ref_ok": all(s["ref_ok"] for s in cmp.values()),
        "cmp_gap_ms": sum(s["gap_ms"] for s in cmp.values()),
        "same": not missing and not bad and set(ref) == set(new),
    }
    json.dump(res, sys.stdout, indent=1)
    print()


if __name__ == "__main__":
    {"tasks": tasks, "summary": summary}[sys.argv[1]](*sys.argv[2:])
