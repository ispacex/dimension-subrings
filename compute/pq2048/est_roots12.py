#!/usr/bin/env python3
"""est_roots12.py OUTDIR — the roots part of the estimate from run_roots12.sh: per rank D the number of
classes of level-a root children not dropped by Theorem A (#U / |GL(D,2)|) — or, for a run with THMA1,
by Theorems A and A1 (at least two invariants >= 4 in V_ab, "surv2"), the share kept by (Г_N), and
per kept vertex the leaves, parents and CPU of its step-1 expansion; scaled to CPU-days."""
import glob, json, math, re, sys
out = sys.argv[1]
print(f"{'D':>2} {'s':>2} {'classes(all)':>13} {'sampled':>11} {'done/heavy':>10} {'kept':>6} "
      f"{'kept classes':>13} {'leaves':>10} {'parents':>10} {'s/vertex':>9} {'CPU-days':>14}")
tot = 0.0; tcov = 0.0
for f in sorted(glob.glob(f"{out}/r_*.jsonl"), key=lambda p: int(re.findall(r"r_(\d+)", p)[-1])):
    head, rows, heavy = None, [], 0
    for line in open(f):
        r = json.loads(line)
        if "D" in r: head = r
        elif "heavy" in r: heavy += 1
        elif "j" in r: rows.append(r)
    if not head: continue
    gl = int(head["gl"]); call = int(head["total"]) / gl; csurv = int(head["surv2" if head.get("thma1") else "surv"]) / gl
    n = len(rows)
    if n == 0:
        print(f"{head['D']:>2} {head['s']:>2} {call:13.3g} {csurv:11.3g} {0:>4}/{heavy:<5}"); continue
    def ms(r):
        t = r["ms_keep"] + r.get("ms_steps", 0)
        for b in r.get("by", []): t += b["ms_desc"] + b["ms_filter"]
        for c in r.get("cov", []): t += 0  # cover search reported separately
        return t
    k = [r for r in rows if r["kept"]]
    pk = len(k) / n
    def mean_sd(xs):
        m = sum(xs) / len(xs)
        sd = math.sqrt(sum((x - m) ** 2 for x in xs) / (len(xs) - 1) / len(xs)) if len(xs) > 1 else float("nan")
        return m, sd
    leaves = mean_sd([sum(b["b"] for b in r.get("by", [])) for r in rows])
    par = mean_sd([sum(b["par"] for b in r.get("by", [])) for r in rows])
    t = mean_sd([ms(r) / 1000 for r in rows])
    days = csurv * t[0] / 86400; dsd = csurv * t[1] / 86400
    tot += days
    print(f"{head['D']:>2} {head['s']:>2} {call:13.3g} {csurv:11.3g} {n:>4}/{heavy:<5} {pk:6.2f} {csurv*pk:13.3g} "
          f"{csurv*leaves[0]:10.3g} {csurv*par[0]:10.3g} {t[0]:9.3g} {days:9.3g}±{dsd:.2g}")
    cov = [c for r in rows for c in r.get("cov", [])]
    if cov:
        print(f"   cover search on {len(cov)} parents: {sum(c['ms'] for c in cov)/len(cov)/1000:.3g} s each, "
              f"{sum(1 for c in cov if c['count'] > 0)/len(cov):.0%} with admissible U; "
              f"{csurv*par[0]*sum(c['ms'] for c in cov)/len(cov)/1000/86400:.3g} CPU-days for all parents")
        tcov += csurv * par[0] * sum(c["ms"] for c in cov) / len(cov) / 1000 / 86400
print(f"total (walk at the roots' level-a children): {tot:.3g} CPU-days, cover search {tcov:.3g}; heavy samples not included")
