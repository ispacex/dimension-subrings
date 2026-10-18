import sys
from itertools import product
from lat import *
from groups import D8, Q8, M16, affine
NMAX = int(sys.argv[1])
C8 = affine(8, None, [(1, 1)])
C4 = affine(4, None, [(1, 1)])
cases = [("M16", M16, lambda E: E.T[E.gens[0]][E.gens[0]], lambda E: [0, E.gens[0], E.gens[1], E.T[E.gens[0]][E.gens[1]]]),
         ("C8/C4", C8, lambda E: E.T[E.gens[0]][E.gens[0]], lambda E: [0, E.gens[0]]),
         ("C4/C2", C4, lambda E: E.T[E.gens[0]][E.gens[0]], lambda E: [0, E.gens[0]])]
for name, E, zf, tf in cases:
    z = zf(E); C = cyclic_C(E, z); k = len(C); trans = tf(E)
    Dp = delta_powers(E, NMAX)
    order = [g for g in range(E.N) if g not in C] + C
    m0 = E.N - k
    L = []
    for j in range(NMAX + 1):
        Hm = hnf([[r[g] for g in order] for r in Dp[j]], E.N)
        L.append([r[m0:] for r in Hm if all(v == 0 for v in r[:m0])])
    Ps = {}
    for es in product(range(k), repeat=len(trans) - 1):
        vals = [[1] + [0] * (k - 1)] + [[int(i == e) for i in range(k)] for e in es]
        P = P_filtration(E, C, make_p(E, C, trans, vals), NMAX, Dp)
        Ps.setdefault(str(P), (es, P))
    print(name, "|C|", k, "distinct P over transversals:", len(Ps))
    # weights: for k = 4: w(s)=mu, w(s^2)=m, w(s^3)=mu ; for k=2: w(t)=m
    wl = [(mu, m) for mu in range(1, 4) for m in range(mu, 6)] if k == 4 else [(None, m) for m in range(1, 5)]
    for mu, m in wl:
        w = [0, mu, m, mu] if k == 4 else [0, m]
        F = weighted_F(C, w, NMAX)
        Lok = [j for j in range(NMAX + 1) if not subset(L[j], F[j])]
        res = []
        for key, (es, P) in Ps.items():
            bad = [j for j in range(NMAX + 1) if not subset(P[j], F[j])]
            res.append((es, bad[:3]))
        print("  w(s)=%s w(t)=%s : L_j not in F_j at j=%s ; P_j not in F_j:" % (mu, m, Lok[:3]), res)
