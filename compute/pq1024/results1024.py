"""Final tables of the order-2^10 run from the run's own outputs.

    results1024.py out/main lat/out.jsonl results/

Reads the 858 stat files d1024_*.json of desc1.g (and their GAP logs, which must be empty) and
the lattice answers lat/out.jsonl of ../run.py, checks that the chunks cover the parent ranges
of make_jobs.py exactly once, and writes into results/:

  chunks.csv      one row per chunk: parent id range, rank, parents, descendants, class 3,
                  cyclic centre, candidates, GAP time
  by_rank.json    the same summed by rank, with the lattice answers
  candidates.csv  one row per candidate: id = 1000 * parent + k (Q is the k-th group of
                  PqDescendants(SmallGroup(512, parent) : StepSize := 1)), rank, |D_n| and
                  |gamma_n| by level, D_n = gamma_n at every level, lattice seconds
"""
import csv
import glob
import json
import os
import sys

from make_jobs import P3_512



def rank_of(i):
    for d, (a, b) in zip(range(2, 8), P3_512):
        if a <= i <= b:
            return d
    raise ValueError(i)


def main():
    statdir, latfile, outdir = sys.argv[1:4]
    os.makedirs(outdir, exist_ok=True)
    stats = []
    for f in glob.glob(os.path.join(statdir, "d1024_*.json")):
        r = json.load(open(f))
        log = f[:-5] + ".log"
        if os.path.exists(log) and os.path.getsize(log) > 0:
            raise SystemExit(f"non-empty GAP log: {log}")
        stats.append(r)
    stats.sort(key=lambda r: r["from"])
    # coverage: the chunks are exactly the 2000-id pieces of P3_512, each once
    want = []
    for a, b in P3_512:
        while a <= b:
            e = min(a + 1999, b)
            want.append((a, e))
            a = e + 1
    got = [(r["from"], r["to"]) for r in stats]
    if got != want:
        raise SystemExit(f"chunks do not match make_jobs.py: {len(got)} vs {len(want)}")

    keys = ("class3_by_rank", "cyclic_centre_by_rank", "candidates_by_rank")
    agg = {}
    with open(os.path.join(outdir, "chunks.csv"), "w", newline="") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["from", "to", "rank", "parents", "skipped_gamma3", "descendants",
                    "class3", "cyclic_centre", "candidates", "gap_ms"])
        for r in stats:
            d = rank_of(r["from"])
            vals = [sum(r[k]) for k in keys]
            for k, v in zip(keys, vals):
                # the descendants have the parent's rank
                assert all(x == 0 for i, x in enumerate(r[k]) if i + 1 != d), (r["from"], k)
            w.writerow([r["from"], r["to"], d, r["parents"], r["skipped_gamma3"], r["descendants"],
                        *vals, r["gap_ms"]])
            a = agg.setdefault(d, dict(chunks=0, parents=0, skipped_gamma3=0, descendants=0,
                                       class3=0, cyclic_centre=0, candidates=0, gap_ms=0))
            a["chunks"] += 1
            for k in ("parents", "skipped_gamma3", "descendants", "gap_ms"):
                a[k] += r[k]
            a["class3"] += vals[0]
            a["cyclic_centre"] += vals[1]
            a["candidates"] += vals[2]

    lat = [json.loads(line) for line in open(latfile)]
    ids = set()
    with open(os.path.join(outdir, "candidates.csv"), "w", newline="") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["id", "parent", "k", "rank", "levels", "D_orders", "gamma_orders",
                    "Dn_eq_gamma_n_all_n", "D4", "D5", "seconds"])
        for r in sorted(lat, key=lambda r: r["id"]):
            assert r["id"] not in ids
            ids.add(r["id"])
            lv = sorted(r["levels"], key=lambda x: x["n"])
            D = {x["n"]: x["Dn_order"] for x in lv}
            eq = all(x["equal"] for x in lv)
            parent, k = divmod(r["id"], 1000)
            assert rank_of(parent) == r["d"]
            a = agg[r["d"]]
            a.setdefault("lattice", dict(groups=0, D4_trivial=0, D5_trivial=0, Dn_eq_gamma_n=0, seconds=0.0))
            L = a["lattice"]
            L["groups"] += 1
            L["D4_trivial"] += D.get(4, 1) == 1
            L["D5_trivial"] += D.get(5, 1) == 1
            L["Dn_eq_gamma_n"] += eq
            L["seconds"] = round(L["seconds"] + r["seconds"], 2)
            w.writerow([r["id"], parent, k, r["d"], len(lv),
                        "/".join(str(x["Dn_order"]) for x in lv),
                        "/".join(str(x["gamma_order"]) for x in lv),
                        int(eq), D.get(4, 1), D.get(5, 1), r["seconds"]])
    for d, a in agg.items():
        if a["candidates"] != a.get("lattice", {}).get("groups", 0):
            raise SystemExit(f"rank {d}: {a['candidates']} candidates, lattice has "
                             f"{a.get('lattice', {}).get('groups', 0)}")
    total = {k: sum(a[k] for a in agg.values())
             for k in ("chunks", "parents", "skipped_gamma3", "descendants", "class3",
                       "cyclic_centre", "candidates", "gap_ms")}
    json.dump({"order": 1024, "by_rank": {str(d): agg[d] for d in sorted(agg)}, "total": total},
              open(os.path.join(outdir, "by_rank.json"), "w"), indent=1)
    print(json.dumps(total))
    for d in sorted(agg):
        print(d, agg[d])


if __name__ == "__main__":
    main()
