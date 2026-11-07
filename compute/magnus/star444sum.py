"""Summary of star444.g output (all.jsonl on stdin): per mode, counts of records, (*) failures, controls, adapted
basis, factors not 1 on the admissible lattice (adapted basis), g not 1, factors not 1 without (C) / without (D)."""
import json, sys, re
from collections import Counter, defaultdict
def fix(l):   # the GAP writer puts lists of strings inside a JSON string (fbad, f_noC, f_noD): escape their quotes
    return re.sub(r'"(fbad|f_noC|f_noD)":"(\[.*?\])"(?=,"|})', lambda m: '"%s":"%s"' % (m.group(1), m.group(2).replace('"', "'")), l)
R = [json.loads(fix(l)) for l in sys.stdin if l.strip()]
by = defaultdict(list)
for r in R:
    g4 = r.get("g4", [])
    e4 = max([0] + [int(round(__import__("math").log(x, 3))) for x in g4])
    by[(r["mode"], "exp g4 = 3^%d" % e4)].append(r)
tot = Counter()
for key in sorted(by):
    rs = by[key]
    c = Counter()
    ab = Counter(str(sorted(r["ab"])) for r in rs)
    for r in rs:
        c["n"] += 1
        c["star_bad"] += r["star"][1] > 0
        c["star_lat"] += r["star"][0]
        for name, (lat, bad) in r["ctl"]:
            c["ctl_" + name] += bad > 0
        c["adapt_bad"] += not r["adapted"]
        c["fbad"] += r["fbad"] not in ("", "[  ]")
        c["gbad"] += r["gbad"] > 0
        c["psi>0"] += r["psi"] > 0
        c["e23>=2"] += r["e23"] >= 2
        c["nonmet"] += r["nonmet"]
        c["zcyc"] += r["zcyc"]
    tot.update(c)
    print(key, dict(c), "| Q_ab:", dict(ab), "| logord", min(r["logord"] for r in rs), max(r["logord"] for r in rs))
    fc = defaultdict(Counter)
    for r in rs:
        for part in r.get("fctl", "").split(";"):
            if ":" in part:
                dr, fx = part.split(":")
                fc[dr]["groups"] += fx != ""
                for x in fx.split(","):
                    if x: fc[dr][x] += 1
    for dr in fc:
        print("   factors != 1 with %s dropped:" % dr, dict(fc[dr]))
print("TOTAL", dict(tot))
