"""Decide D_5(Q) = 1 for the class-3 2-groups Q of fam.g.

D_5(Q) is contained in K = Omega_1(gamma_3(Q) ∩ M_5(Q)), elementary abelian with independent
generators g_1..g_r (words from fam.g).  On gamma_3 the map g -> (g - 1) mod Delta^5 is a
homomorphism ((g-1)(h-1) is in Delta^6), so D_5 ∩ K is the kernel of c -> sum c_i v_i in
Z[Q]/Delta^5 = T_{<5}/I_5.  We compute the kernel modulo 2^E: a kernel equal to 2Z^r proves
D_5(Q) = 1 (non-membership modulo 2^E is exact); a larger kernel is only a candidate."""
import json, sys, itertools
import numpy as np
from magnus import Trunc, Ring, howell

def word(T, ext):
    out = T.one()
    for i in range(0, len(ext), 2):
        out = T.mul(out, T.power(T.gen(ext[i] - 1), ext[i + 1]))
    return out

def check(rec, E=30, n=5, key="words"):
    a0, a1, a2, p01, p02, p10, p12, p20, p21, k = rec["par"][:10]
    T, R = Trunc(4, n), Ring(2, E)
    e0, e1, e2, z = (T.gen(i) for i in range(4))
    C, P, I = T.comm, T.power, T.inv
    rels = [T.prod(P(e0, 2 ** a0), I(T.prod(P(C(z, e1), p01), P(C(z, e2), p02)))),
            T.prod(P(e1, 2 ** a1), I(T.prod(P(C(z, e0), p10), P(C(z, e2), p12)))),
            T.prod(P(e2, 2 ** a2), I(T.prod(P(C(z, e0), p20), P(C(z, e1), p21)))),
            P(z, 2 ** k)]
    gens = [T.gen(i) for i in range(4)] + [I(T.gen(i)) for i in range(4)]
    rels += [T.lnc(*w) for w in itertools.product(gens, repeat=4)]
    A = T.ideal_rows(rels, R)
    r = len(rec[key])
    if r == 0:
        return "K = 1, so D_5 = 1"
    m = len(T.monos)
    V = np.array([T.vec(word(T, w), R) for w in rec[key]])
    top = np.hstack([A, np.zeros((A.shape[0], r), dtype=np.int64)])
    mid = np.hstack([V, np.eye(r, dtype=np.int64)])
    bot = np.hstack([np.zeros((r, m), dtype=np.int64), 2 * np.eye(r, dtype=np.int64)])
    H = howell(R, np.vstack([top, mid, bot]))
    ker = [row[m:] for c, v, row in H if c >= m]
    ker = np.array(ker) % 2 if ker else np.zeros((0, r), dtype=np.int64)
    # rank over F_2 of the kernel modulo 2Z^r
    M = ker.copy() % 2
    rank = 0
    for c in range(r):
        piv = [i for i in range(rank, M.shape[0]) if M[i, c]]
        if not piv:
            continue
        M[[rank, piv[0]]] = M[[piv[0], rank]]
        for i in range(M.shape[0]):
            if i != rank and M[i, c]:
                M[i] ^= M[rank]
        rank += 1
    return "r=%d, candidate kernel rank over F_2 = %d -> %s" % (
        r, rank, "D_5 = 1 (proved)" if rank == 0 else "CANDIDATE: check over Z")

raw = open(sys.argv[1]).read().replace("\\\n", "").replace("\n", "")
for chunk in raw.replace("}{", "}\x00{").split("\x00"):
    if not chunk.strip():
        continue
    rec = json.loads(chunk)
    print(rec["par"], "log2|Q| =", rec["log2order"], "g3 =", rec["g3"], "K =", rec["K"], "->", check(rec), "| alpha!=1:", rec["alpha_nontrivial"], "alpha in K4:", rec["alpha_in_K4"], "| control D_4 on Omega_1(g3 ∩ M_4):", check(rec, n=4, key="words4"), flush=True)
