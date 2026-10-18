import sys
from itertools import product
from lat import *
from groups import D8, Q8, M16
NMAX = int(sys.argv[1]) if len(sys.argv) > 1 else 8

def info(E, name):
    Z = E.centre()
    z = max(Z, key=lambda i: E.order(i)) if name != "M16" else E.T[E.gens[0]][E.gens[0]]
    C = cyclic_C(E, z)
    a, b = E.gens
    ab = E.T[a][b]
    print(name, "|E|", E.N, "|Z|", len(Z), "C", len(C), "orders a,b", E.order(a), E.order(b))
    return C, [0, a, b, ab]

for E, name in [x for x in [(D8, "D8"), (Q8, "Q8"), (M16, "M16")] if x[1] in sys.argv[2:]]:
    C, trans = info(E, name)
    k = len(C)
    Dp = delta_powers(E, NMAX)
    # lower bound for every p: Z[C] cap Delta^j
    L = []
    for j in range(NMAX + 1):
        # intersection of lattice Delta^j with the coordinate sublattice Z[C]: solve via HNF with
        # the other coordinates eliminated first (put non-C coordinates first).
        order = [g for g in range(E.N) if g not in C] + C
        rows = [[r[g] for g in order] for r in Dp[j]]
        Hm = hnf(rows, E.N)
        m = E.N - k
        Lj = [r[m:] for r in Hm if all(v == 0 for v in r[:m])]
        L.append(Lj)
    print(" Z[C] cap Delta^j:", [l for l in L])
    rng = range(-1, 3)
    best = []
    for xs in product(rng, repeat=3 * (k - 1)):
        vals = [[1] + [0] * (k - 1)]
        for i in range(3):
            y = xs[i * (k - 1):(i + 1) * (k - 1)]
            v = [1 - sum(y)] + list(y)   # 1 + sum_e y_e (c^e - 1)
            vals.append(v)
        p = make_p(E, C, trans, vals)
        P = P_filtration(E, C, p, NMAX, Dp)
        best.append((xs, P))
    # print distinct filtrations
    seen = {}
    for xs, P in best:
        key = str(P)
        seen.setdefault(key, []).append(xs)
    print(" distinct P-filtrations:", len(seen))
    for key, xl in sorted(seen.items(), key=lambda t: -len(t[1]))[:12]:
        print("  ", len(xl), xl[:3], key)
