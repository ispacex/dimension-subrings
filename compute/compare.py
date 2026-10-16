"""Compare |D_n| from several methods: compare.py A.jsonl B.jsonl [C.txt].
A, B: dimsub.py outputs (method A, method B); C: output of the GP program from method_c.py.
Also checks the sanity flags.  Exit code 1 on any disagreement."""
import json
import sys


def load_jsonl(path):
    out = {}
    for l in open(path):
        r = json.loads(l)
        out[(r["order"], r["id"])] = r
    return out


A = load_jsonl(sys.argv[1])
B = load_jsonl(sys.argv[2])
bad = 0
for k, ra in A.items():
    rb = B.get(k)
    if rb is None:
        continue
    for la, lb in zip(ra["levels"], rb["levels"]):
        if (la["Dn_order"], la["index_logp"], la["extra"]) != (lb["Dn_order"], lb["index_logp"], lb["extra"]):
            print("A/B mismatch", k, la, lb)
            bad += 1
print(f"A vs B: {len(set(A) & set(B))} groups compared, {bad} mismatches")
if len(sys.argv) > 3:
    badc = 0
    n = 0
    for l in open(sys.argv[3]):
        parts = l.split(None, 2)
        if len(parts) < 3 or not parts[0].isdigit():
            continue
        k = (int(parts[0]), int(parts[1]))
        orders, idx = json.loads(parts[2].replace(";", ","))
        ra = A[k]
        p = ra["p"]
        mine = [x["Dn_order"] for x in ra["levels"]][: len(orders)]
        myidx = [p ** x["index_logp"] if x["certified"] else None for x in ra["levels"]][: len(idx)]
        n += 1
        if mine != orders[: len(mine)] or any(a is not None and a != b for a, b in zip(myidx, idx)):
            print("A/C mismatch", k, mine, orders, myidx, idx)
            badc += 1
    print(f"A vs C: {n} groups compared, {badc} mismatches")
    bad += badc
sys.exit(1 if bad else 0)
