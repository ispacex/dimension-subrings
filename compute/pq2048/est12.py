#!/usr/bin/env python3
"""est12.py OUTDIR [--compare STAT.json] — sums the samples of run_sample12.sh (README "Estimate for 2^12").

Per stratum (order NN, rank D; block of Nb ids, ns sampled) and per sampled kept X:
  a   = level-a children of X (order 2^(LOGQ-2), kept),
  b   = leaves (order 2^(LOGQ-1)) from X directly + a * mean leaves per level-a vertex (stage 2),
  par = the same for the parents among the leaves (2-class >= 3), the input of the cover search,
  cpu = steps.g + PqDescendants + filter on X, + a * the same per level-a vertex (stage 2).
Totals are Nb/ns * the sums (an unbiased estimate), with the standard error of the mean.  Cover
search: parents * mean MC_Data time of the sampled parents.  Heavy ids (out of time or memory)
are listed apart: their contribution is unknown, at least TLIM each.
"""
import glob, json, math, os, sys

def mean(l): return sum(l) / len(l) if l else 0.0

def main():
    out = sys.argv[1]
    rows = []
    covms = {"x": [], "a": []}; covpos = []
    for f in sorted(glob.glob(os.path.join(out, "s_*.jsonl"))):
        _, nn, d = os.path.basename(f)[:-6].split("_")
        blocks = json.load(open(os.path.join(out, f"blocks_{nn}.json")))["blocks"]
        lo, hi = blocks[d]; nb = hi - lo + 1
        ns = sum(1 for _ in open(os.path.join(out, "ids", f"{nn}_{d}.txt")))
        recs = [json.loads(l) for l in open(f) if l.strip()]
        res = [r for r in recs if "id" in r]; heavy = [r for r in recs if "heavy" in r]
        per = {"a": [], "b": [], "par": [], "cpu": []}
        kept = 0
        for r in res:
            if not r["kept"]:
                for k in per: per[k].append(0.0)
                continue
            kept += 1
            a = sum(x["a"] for x in r["by"]); b = sum(x["b"] for x in r["by"]); par = sum(x["par"] for x in r["by"])
            cpu = r["ms_steps"] + sum(x["ms_desc"] + x["ms_filter"] for x in r["by"])
            if r["na"] and r["s2"]:
                s2b = mean([sum(x["b"] for x in s["by"]) for s in r["s2"]])
                s2p = mean([sum(x["par"] for x in s["by"]) for s in r["s2"]])
                s2c = mean([s["ms_steps"] + sum(x["ms_desc"] + x["ms_filter"] for x in s["by"]) for s in r["s2"]])
                b += r["na"] * s2b; par += r["na"] * s2p; cpu += r["na"] * s2c
            per["a"].append(a); per["b"].append(b); per["par"].append(par); per["cpu"].append(cpu / 1000.0)
            for c in r.get("cov", []):
                covms[c["lev"]].append(c["ms"] / 1000.0); covpos.append(1 if c["count"] > 0 else 0)
        n = len(res)
        row = {"order": int(nn), "rank": int(d), "block": nb, "sampled": ns, "done": n, "heavy": len(heavy), "kept": kept}
        for k, v in per.items():
            m = mean(v)
            sd = math.sqrt(sum((x - m) ** 2 for x in v) / (n - 1)) if n > 1 else float("nan")
            row[k] = nb * m; row[k + "_se"] = nb * sd / math.sqrt(n) if n > 1 else float("nan")
        rows.append(row)
    cms = mean(covms["x"] + covms["a"]); cpos = mean(covpos)
    print(f"{'order':>5} {'rank':>4} {'block':>9} {'done/samp':>10} {'heavy':>5} {'kept':>5} "
          f"{'level a':>18} {'leaves':>18} {'parents':>18} {'CPU-days':>16}")
    tot = {"a": 0, "b": 0, "par": 0, "cpu": 0}
    for r in sorted(rows, key=lambda r: (r["rank"], r["order"])):
        f = lambda k, s=1.0: f"{r[k]/s:.3g}±{r[k+'_se']/s:.2g}"
        print(f"{r['order']:>5} {r['rank']:>4} {r['block']:>9} {str(r['done'])+'/'+str(r['sampled']):>10} {r['heavy']:>5} {r['kept']:>5} "
              f"{f('a'):>18} {f('b'):>18} {f('par'):>18} {f('cpu', 86400):>16}")
        for k in tot: tot[k] += r[k]
    print(f"total: level a {tot['a']:.3g}, leaves {tot['b']:.3g}, parents {tot['par']:.3g}, "
          f"walk {tot['cpu']/86400:.3g} CPU-days; cover search {tot['par']*cms/86400:.3g} CPU-days "
          f"({len(covms['x'])+len(covms['a'])} parents timed, {cms*1000:.0f} ms each, {100*cpos:.0f}% with admissible U)")
    json.dump({"rows": rows, "cover_ms": cms * 1000, "cover_pos": cpos}, open(os.path.join(out, "est.json"), "w"), indent=1)

main()
