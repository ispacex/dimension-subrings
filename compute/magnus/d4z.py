"""Decide z in D_4(Q) for the survivors of d4s9.g (MATH-415).

Same method as dnz.py, modulo 2^E (truncated Magnus algebra; non-membership exact, membership
exact under the certificate 2^(E-1) T_+ in I_n + 2^E T).  Controls per group: z in D_kz, where kz
is the largest k with z in gamma_k (must hold), and each generator not in D_2 (must fail).

Usage: python d4z.py [E] < d4s9_*.jsonl   (E = 30 by default)."""
import json
import sys

from magnus import Trunc, Ring
from d5z import member


def main():
    E = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    R = Ring(2, E)
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
            verdict = "z not in D_4: D_4 = 1 (exact)"
        elif cert:
            verdict = "z IN D_4 (exact, certified): D_4 != gamma_4"
        else:
            verdict = "z in D_4 mod 2^E only: undecided, raise E"
        out = {"id": rec["id"], "K": rec["K"], "k": k, "n": n, "monos": len(Tn.monos), "z_in_Dn": zn,
               "cert": cert, "kz": kz, "ctrl_z_in_Dkz": zk, "ctrl_gens_in_D2": g2, "verdict": verdict}
        print(json.dumps(out), flush=True)


if __name__ == "__main__":
    main()
