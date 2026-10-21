"""Decide z in D_5(Q) for one element z of a finite 3-group Q given by a presentation (D5-26).

Input: JSON lines from c38.g, one per group:
  {"id": ..., "k": d, "rels": [extrep, ...], "z": extrep, "ctrl": [extrep, ...]}
where an extrep is GAP's ExtRepOfObj of a word in the d generators ([gen, exp, gen, exp, ...]).

Z[Q]/Delta^n = T_{<n}(Z^k)/I_n (truncated Magnus algebra, magnus.py).  We work modulo 3^E:
  * z - 1 not in I_n + 3^E T   =>  z not in D_n(Q)                          (exact);
  * if moreover 3^(E-1) T_+ is in I_n + 3^E T (`cert`), then 3^(E-1) kills Delta/Delta^n
    (Nakayama for the finite 3-group Delta/Delta^n), so I_n + 3^E T = I_n and membership
    modulo 3^E is membership in Delta^n                                      (exact).
Controls per group: z in D_4 (z is in gamma_4 = D_4), and each generator x_i not in D_2.

Usage: python d5z.py [E] < cand.jsonl   (E = 19 by default, 3^19 < 2^31)."""
import json
import sys

import numpy as np

from magnus import Trunc, Ring, howell
from dimsub import reduce_rows


def shifts(T):
    """sh[i][a] = index of monomial a + (i,) (right multiplication by X_i), or -1 if too long."""
    return [np.array([T.idx.get(m + (i,), -1) for m in T.monos]) for i in range(T.k)]


def word_vec(T, R, ext, sh=None):
    """The image of a word (GAP ext. rep.) in T_{<n}, as a dense vector modulo 3^E."""
    sh = sh or shifts(T)
    a = np.zeros(len(T.monos), dtype=np.int64)
    a[0] = 1
    for p in range(0, len(ext), 2):
        g, e = ext[p] - 1, ext[p + 1]
        ok = sh[g] >= 0
        for _ in range(abs(e)):
            if e > 0:                       # a (1 + X_g)
                b = a.copy()
                np.add.at(b, sh[g][ok], a[ok])
            else:                           # a (1 + X_g)^(-1) = a sum_j (-X_g)^j
                b, t = a.copy(), a.copy()
                for _ in range(1, T.n):
                    u = np.zeros_like(t)
                    np.add.at(u, sh[g][ok], -t[ok])
                    t = u % R.D
                    b += t
            a = b % R.D
    return a


def to_dict(T, v):
    return {T.monos[j]: int(c) for j, c in enumerate(v) if c}


def member(T, R, rels, ws):
    """For each word in ws: is w - 1 in I_n (mod 3^E)?  Also returns the certificate flag."""
    sh = shifts(T)
    A = T.ideal_rows([to_dict(T, word_vec(T, R, r, sh)) for r in rels], R)
    H = howell(R, A)
    m = len(T.monos)
    V = []
    for w in ws:
        v = word_vec(T, R, w, sh)
        v[0] = (v[0] - 1) % R.D
        V.append(v)
    V = np.array(V)
    ok = reduce_rows(R, H, V)
    probe = np.zeros((m - 1, m), dtype=np.int64)
    probe[:, 1:] = R.ppow[R.E - 1] * np.eye(m - 1, dtype=np.int64)
    cert = bool(reduce_rows(R, H, probe).all())
    return [bool(x) for x in ok], cert


def main():
    E = int(sys.argv[1]) if len(sys.argv) > 1 else 19
    R = Ring(3, E)
    for line in sys.stdin:
        if not line.strip():
            continue
        rec = json.loads(line)
        k, rels = rec["k"], rec["rels"]
        T5 = Trunc(k, 5)
        (z5,), cert5 = member(T5, R, rels, [rec["z"]])
        T4 = Trunc(k, 4)
        (z4,), _ = member(T4, R, rels, [rec["z"]])
        T2 = Trunc(k, 2)
        g2, _ = member(T2, R, rels, [[i + 1, 1] for i in range(k)])
        if not z5:
            verdict = "z not in D_5: D_5 = 1 (exact)"
        elif cert5:
            verdict = "z IN D_5 (exact, certified): COUNTEREXAMPLE"
        else:
            verdict = "z in D_5 mod 3^E only: undecided, raise E"
        out = {"id": rec["id"], "k": k, "monos": len(T5.monos), "z_in_D5": z5, "cert": cert5,
               "ctrl_z_in_D4": z4, "ctrl_gens_in_D2": g2, "verdict": verdict}
        print(json.dumps(out), flush=True)


if __name__ == "__main__":
    main()
