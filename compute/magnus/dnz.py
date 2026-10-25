"""Decide z in D_n(Q) for the survivors of dn3.g (MATH-403): n = class + 1 per record.

Same method as d5z.py (truncated Magnus algebra modulo 3^E; non-membership exact, membership exact
under the certificate 3^(E-1) T_+ in I_n + 3^E T).  Controls per group: z in D_kz, where kz is the
largest k with z in gamma_k (must hold), and each generator not in D_2 (must fail).

Usage: python dnz.py [E] < dn3_*.jsonl   (E = 19 by default)."""
import json
import sys

from magnus import Trunc, Ring
from d5z import member


def main():
    E = int(sys.argv[1]) if len(sys.argv) > 1 else 19
    R = Ring(3, E)
    for line in sys.stdin:
        if not line.strip():
            continue
        rec = json.loads(line)
        k, rels, n, kz = rec["k"], rec["rels"], rec["n"], rec["kz"]
        Tn = Trunc(k, n)
        (zn,), cert = member(Tn, R, rels, [rec["z"]])
        (zk,), _ = member(Trunc(k, kz), R, rels, [rec["z"]])
        g2, _ = member(Trunc(k, 2), R, rels, [[i + 1, 1] for i in range(k)])
        if not zn:
            verdict = "z not in D_n: D_n = gamma_n = 1 (exact)"
        elif cert:
            verdict = "z IN D_n (exact, certified): 3-TORSION"
        else:
            verdict = "z in D_n mod 3^E only: undecided, raise E"
        out = {"id": rec["id"], "K": rec["K"], "k": k, "n": n, "monos": len(Tn.monos), "z_in_Dn": zn,
               "cert": cert, "kz": kz, "ctrl_z_in_Dkz": zk, "ctrl_gens_in_D2": g2, "verdict": verdict}
        print(json.dumps(out), flush=True)


if __name__ == "__main__":
    main()
