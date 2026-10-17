"""MATH-127 (1): D_5(Q) for the groups of q1gen.g.  Input lines {"id","k","rels","zs",...}; zs = one
generator of each subgroup of order 3 of S = Omega_1(Z) ∩ Q'' ∩ M_5.  A nontrivial D_5(Q) (normal,
inside Q'' ∩ M_5 of exponent 3) meets Z(Q), so D_5(Q) = 1 iff no z in zs lies in D_5.
Exactness as in d5z.py (non-membership exact; certificate printed).  Usage: python d5s.py [E] < in.jsonl"""
import json
import sys

from magnus import Trunc, Ring
from d5z import member


def main():
    E = int(sys.argv[1]) if len(sys.argv) > 1 else 19
    R = Ring(3, E)
    n = bad = 0
    for line in sys.stdin:
        if not line.strip():
            continue
        rec = json.loads(line)
        k, rels, zs = rec["k"], rec["rels"], rec["zs"]
        T4 = Trunc(k, 4)
        ctrl4, _ = member(T4, R, rels, zs) if zs else ([], True)
        T5 = Trunc(k, 5)
        in5, cert = member(T5, R, rels, zs) if zs else ([], True)
        n += 1
        bad += any(in5)
        out = {kk: rec[kk] for kk in ("id", "k", "logord", "lcs", "dd", "S", "id_ok")}
        out.update({"nz": len(zs), "z_in_D5": in5, "cert": cert, "ctrl_z_in_D4": all(ctrl4)})
        print(json.dumps(out), flush=True)
    print(json.dumps({"groups": n, "with_z_in_D5": bad}), flush=True)


if __name__ == "__main__":
    main()
