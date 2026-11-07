"""MATH-444: from the q99gen.g output of the MATH-443 main run, the cyclic-centre quotient records with
exp(gamma_2/gamma_3) = 9, Q'' != 1 and |gamma_4| = 3, as GAP input for h2old.g.  Usage: python h2old.py DIR > recs.g"""
import glob, gzip, json, sys

out = []
for f in sorted(glob.glob(sys.argv[1] + "/q_*.jsonl.gz")):
    for line in gzip.open(f, "rt"):
        r = json.loads(line)
        if r.get("cyc") and r["nonmet"] and r["e23"] == 2 and r["lcs"][3] == 1:
            out.append(r)
print("RECS := [")
print(",\n".join("rec(id := \"%s\", k := %d, rels := %s, z := %s, pclass := %d, logord := %d)"
                 % (r["id"], r["k"], json.dumps(r["rels"]), json.dumps(r["zs"][0]), r["pclass"], r["logord"]) for r in out))
print("];")
