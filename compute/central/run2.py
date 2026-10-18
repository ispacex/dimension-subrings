import sys
from itertools import product
from lat import *
from groups import D8, Q8, M16
NMAX = int(sys.argv[1])

def periodic(Dp, N):
    for j in range(len(Dp) - 2):
        two = hnf([[2 * x for x in r] for r in Dp[j]], N)
        if two == Dp[j + 2]:
            return j
    return None

for E, name in [(D8, "D8"), (Q8, "Q8"), (M16, "M16")]:
    a, b = E.gens
    z = E.T[a][a] if name == "M16" else [i for i in E.centre() if i][0]
    C = cyclic_C(E, z)
    k = len(C)
    trans = [0, a, b, E.T[a][b]]
    Dp = delta_powers(E, NMAX)
    j0 = periodic(Dp, E.N)
    print(name, "C =", k, "Delta^{j+2} = 2 Delta^j from j0 =", j0, flush=True)
    order = [g for g in range(E.N) if g not in C] + C
    m = E.N - k
    L = []
    for j in range(NMAX + 1):
        Hm = hnf([[r[g] for g in order] for r in Dp[j]], E.N)
        L.append([r[m:] for r in Hm if all(v == 0 for v in r[:m])])
    print(" L_j = Z[C] cap Delta^j:", L)
    seen = {}
    for es in product(range(k), repeat=3):
        vals = [[1] + [0] * (k - 1)] + [[int(i == e) for i in range(k)] for e in es]
        p = make_p(E, C, trans, vals)
        P = P_filtration(E, C, p, NMAX, Dp)
        seen.setdefault(str(P), []).append(es)
    print(" transversal choices -> distinct P:", len(seen))
    for key, xl in seen.items():
        print("  ", len(xl), xl[:4], key)
