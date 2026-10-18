"""Lemma R (MATH-186): K = H<r>, r central, r^m = sigma in H, <r> cap H = <sigma>.
If sigma = g^m for some g in H, then q(u r^j) = u g^j maps Delta_K^n into Delta_H^n.
Checks q(Delta_K^n) in Delta_H^n and the ring equality Z[H] cap Delta_K^n = Delta_H^n,
exact HNF.  python3 rootm.py [NAME...]"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lat import hnf, contains, Group, delta_powers


def build_K(H, sigma, m):
    """K = {(h, e) : e in Z/m}, (h,e)(k,f) = (h k sigma^[e+f >= m], e+f mod m)."""
    def mul(x, y):
        (h, e), (k, f) = x, y
        p = H.T[h][k]
        if e + f >= m:
            p = H.T[p][sigma]
        return (p, (e + f) % m)
    return Group([(g, 0) for g in H.gens] + [(0, 1)], mul, (0, 0))


def run(name, Hgens, Hmul, Hone, sigma_el, m, g_el, nmax):
    t0 = time.time()
    H = Group(Hgens, Hmul, Hone)
    N = H.N
    sigma, g = H.idx[sigma_el], H.idx[g_el]
    assert sigma in H.centre()
    K = build_K(H, sigma, m)
    assert K.N == m * N, (K.N, m, N)
    gp = [0]
    for _ in range(m):
        gp.append(H.T[gp[-1]][g])
    print(f"== {name}: |H|={N}, |K|={K.N}, m={m}, g^m = sigma: {gp[m] == sigma}", flush=True)
    pos = {i: (N * (m - 1) if e == 0 else N * (e - 1)) + h for i, (h, e) in enumerate(K.els)}
    def reorder(v):
        w = [0] * K.N
        for i, a in enumerate(v):
            w[pos[i]] = a
        return w
    def q(v):
        out = [0] * N
        for i, a in enumerate(v):
            if a:
                h, e = K.els[i]
                out[H.T[h][gp[e]]] += a
        return out
    DH = delta_powers(H, nmax)
    DK = delta_powers(K, nmax)
    for n in range(1, nmax + 1):
        qok = all(contains(DH[n], q(v)) for v in DK[n])
        L = hnf([reorder(v) for v in DK[n]], K.N)
        cut = K.N - N
        Iz = hnf([r[cut:] for r in L if not any(r[:cut])], N)
        DHn = hnf(DH[n], N)
        eq = Iz == DHn
        extra = ""
        if not eq:
            piv = lambda B: [next(x for x in r if x) for r in B]
            pI, pH = 1, 1
            for x in piv(Iz): pI *= x
            for x in piv(DHn): pH *= x
            extra = f"  index {pH // pI}"
        print(f"  n={n}: q filtered {qok}; ring equality {eq}{extra}", flush=True)
    print(f"  {time.time() - t0:.1f}s")


if __name__ == '__main__':
    which = sys.argv[1:] or ['M16', 'D16', 'Q16', 'D8', 'C4xC2', 'D8m2', 'M16sq']
    def mpq(mod, k):  # a^i b^j with b a b^-1 = a^k, b^2 = 1
        return lambda x, y: ((x[0] + pow(k, x[1], mod) * y[0]) % mod, (x[1] + y[1]) % 2)
    def q16(x, y):  # a^i b^j, a^8 = 1, b^2 = a^4, b a b^-1 = a^-1
        i, j = x; k, l = y
        e = (i + (-1) ** j * k) % 8
        if j and l:
            e = (e + 4) % 8
        return (e, (j + l) % 2)
    if 'M16' in which:
        run('POS M16, sigma=a^4 (central involution), m=4, g=a non-central', [(1, 0), (0, 1)], mpq(8, 5), (0, 0), (4, 0), 4, (1, 0), 5)
    if 'M16sq' in which:
        run('POS M16, sigma=a^2, m=2, g=a (Theorem C, c=1)', [(1, 0), (0, 1)], mpq(8, 5), (0, 0), (2, 0), 2, (1, 0), 5)
    if 'D16' in which:
        run('POS D16, sigma=a^4, m=4, g=a', [(1, 0), (0, 1)], mpq(8, 7), (0, 0), (4, 0), 4, (1, 0), 5)
    if 'Q16' in which:
        run('POS Q16, sigma=a^4, m=4, g=a', [(1, 0), (0, 1)], q16, (0, 0), (4, 0), 4, (1, 0), 5)
    if 'D8' in which:
        run('NEG D8, sigma=a^2 (a square, not a 4th power), m=4, g=a (g^4=1)', [(1, 0), (0, 1)], mpq(4, 3), (0, 0), (2, 0), 4, (1, 0), 5)
    if 'D8m2' in which:
        run('POS D8, sigma=a^2, m=2, g=a', [(1, 0), (0, 1)], mpq(4, 3), (0, 0), (2, 0), 2, (1, 0), 5)
    c42 = lambda x, y: ((x[0] + y[0]) % 4, (x[1] + y[1]) % 2)
    if 'C4xC2' in which:
        run('NEG C4xC2, sigma=(2,0), m=4, g=(1,0) (g^4=1)', [(1, 0), (0, 1)], c42, (0, 0), (2, 0), 4, (1, 0), 5)
