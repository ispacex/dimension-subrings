import sys
from lat import *
from groups import M16, D8, Q8
NMAX = int(sys.argv[1])
E = M16; a, b = E.gens
C = cyclic_C(E, E.T[a][a]); trans = [0, a, b, E.T[a][b]]
Dp = delta_powers(E, NMAX)
for es in [(0, 0, 0), (0, 0, 1)]:
    vals = [[1, 0, 0, 0]] + [[int(i == e) for i in range(4)] for e in es]
    P = P_filtration(E, C, make_p(E, C, trans, vals), NMAX, Dp)
    for mu, m in [(2, 3), (2, 2), (1, 3)]:
        F = weighted_F(C, [0, mu, m, mu], NMAX)
        print(es, (mu, m), "bad j:", [j for j in range(NMAX + 1) if not subset(P[j], F[j])])
    print(" P_{j+2} == 2 P_j for j:", [j for j in range(NMAX - 1) if hnf([[2*x for x in r] for r in P[j]], 4) == P[j+2]])
# D8/Q8 sanity: P_j = tau^{ceil(j/2)}
for E2, nm in [(D8, "D8"), (Q8, "Q8")]:
    a2, b2 = E2.gens; C2 = cyclic_C(E2, [i for i in E2.centre() if i][0])
    P = P_filtration(E2, C2, make_p(E2, C2, [0, a2, b2, E2.T[a2][b2]], [[1, 0]] * 4), NMAX)
    print(nm, all(P[j] == [[2 ** (-(-j // 2) - 1), -2 ** (-(-j // 2) - 1)]] for j in range(1, NMAX + 1)))
