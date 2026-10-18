"""Referee check of Theorem C (central square root adjunction H'' = H o_<s> C_{2 ord s})."""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lat import hnf, contains, Group, delta_powers


def build_Hpp(H, s):
    """H'' = H u Hr, r central, r^2 = s.  Element (h, e) ; index used by Group closure."""
    def mul(x, y):
        (h, e), (k, f) = x, y
        p = H.T[h][k]
        if e and f:
            p = H.T[p][s]
        return (p, e ^ f)
    gens = [(H.gens[i], 0) for i in range(len(H.gens))] + [(0, 1)]
    E = Group(gens, mul, (0, 0))
    return E


def run(name, Hgens, Hmul, Hone, s_el, g_el, nmax, expect_ok=True):
    t = time.time()
    H = Group(Hgens, Hmul, Hone)
    N = H.N
    s, g = H.idx[s_el], H.idx[g_el]
    assert s in H.centre(), "s not central"
    E = build_Hpp(H, s)
    assert E.N == 2 * N
    # coordinates: put the r-block first, then the H-block, so H-intersection = rows with pivot in H-block
    pos = {}
    for i, (h, e) in enumerate(E.els):
        pos[i] = (h if e else N + h)
    def reorder(v):
        w = [0] * (2 * N)
        for i, a in enumerate(v):
            w[pos[i]] = a
        return w
    DH = delta_powers(H, nmax)
    DE = delta_powers(E, nmax)
    print(f"== {name}: |H|={N}, ord s={H.order(s)}, g={g_el}, c=g^-2 s order", end=' ')
    gi = next(i for i in range(N) if H.T[i][g] == 0)
    c = H.T[H.T[gi][gi]][s]
    print(H.order(c), flush=True)

    def q(v):  # v in Z[E] (E-indexing) -> Z[H]: u0 + u1 g
        out = [0] * N
        for i, a in enumerate(v):
            if a:
                h, e = E.els[i]
                out[H.T[h][g] if e else h] += a
        return out
    res = []
    for n in range(1, nmax + 1):
        qok = all(contains(DH[n], q(v)) for v in DE[n])
        L = hnf([reorder(v) for v in DE[n]], 2 * N)
        inter = [r[N:] for r in L if not any(r[:N])]
        Iz = hnf(inter, N)
        eq = (Iz == hnf(DH[n], N))
        # index [Z[H] cap Delta''^n : Delta_H^n]
        idx = 1
        if not eq:
            # both full-ish rank lattices of rank N-1 (inside Delta_H); compare determinants via pivots
            dI = 1
            for r in Iz: dI *= next(x for x in r if x)
            dH = 1
            for r in hnf(DH[n], N): dH *= next(x for x in r if x)
            idx = (dH // dI, len(Iz), len(DH[n]))
        print(f"  n={n}: q(D''^n) in D_H^n: {qok};  Z[H] cap D''^n == D_H^n: {eq}" + ("" if eq else f"  index/ranks {idx}"), flush=True)
        res.append((qok, eq))
    print(f"  time {time.time()-t:.1f}s")
    return res


if __name__ == '__main__':
    which = sys.argv[1:] or ['M16', 'D8', 'Q8', 'C2', 'C4xC2', 'M16g1', 'G64', 'M32']
    nmax = 5
    # M16: (i,j) = a^i b^j, b a b = a^5
    m16 = lambda x, y: ((x[0] + pow(5, x[1], 8) * y[0]) % 8, (x[1] + y[1]) % 2)
    if 'M16' in which:
        run('M16, s=a^2, g=a (non-central), c=1', [(1, 0), (0, 1)], m16, (0, 0), (2, 0), (1, 0), nmax)
    if 'M16g1' in which:
        run('M16, s=a^2, g=1 (hypothesis fails: c=a^2 not in gamma_2) -- q should fail', [(1, 0), (0, 1)], m16, (0, 0), (2, 0), (0, 0), nmax)
    # D8: a^i b^j, b a b = a^-1
    d8 = lambda x, y: ((x[0] + (-1) ** x[1] * y[0]) % 4, (x[1] + y[1]) % 2)
    if 'D8' in which:
        run('D8, s=a^2=[a,b], g=1, c=s (c!=1)', [(1, 0), (0, 1)], d8, (0, 0), (2, 0), (0, 0), nmax)
    # Q8 as quaternion units: (sign, idx) idx in 1,i,j,k
    QT = {('1', '1'): (1, '1')}
    tab = {'i': {'i': (-1, '1'), 'j': (1, 'k'), 'k': (-1, 'j')},
           'j': {'i': (-1, 'k'), 'j': (-1, '1'), 'k': (1, 'i')},
           'k': {'i': (1, 'j'), 'j': (-1, 'i'), 'k': (-1, '1')}}
    def q8(x, y):
        (a, u), (b, v) = x, y
        if u == '1': return (a * b, v)
        if v == '1': return (a * b, u)
        sg, w = tab[u][v]
        return (a * b * sg, w)
    if 'Q8' in which:
        run('Q8, s=-1, g=1, c=s (c!=1)', [(1, 'i'), (1, 'j')], q8, (1, '1'), (-1, '1'), (1, '1'), nmax)
    c2 = lambda x, y: ((x[0] + y[0]) % 2,)
    if 'C2' in which:
        run('NEG: C2, s=gen (s not in Phi), g=1', [(1,)], c2, (0,), (1,), (0,), nmax, expect_ok=False)
    c42 = lambda x, y: ((x[0] + y[0]) % 4, (x[1] + y[1]) % 2)
    if 'C4xC2' in which:
        run('NEG: C4xC2, s=(0,1) not in Phi, g=1', [(1, 0), (0, 1)], c42, (0, 0), (0, 1), (0, 0), nmax, expect_ok=False)
        run('NEG: C4xC2, s=(1,1)? not in Phi, g=1', [(1, 0), (0, 1)], c42, (0, 0), (1, 1), (0, 0), nmax, expect_ok=False)
        run('POS: C4xC2, s=(2,0)=square of central, g=(1,0)', [(1, 0), (0, 1)], c42, (0, 0), (2, 0), (1, 0), nmax)
    # G64: class-2, exponent-2 generators x,y,z, commutators t=(xy,xz,yz) central
    def g64(p, q_):
        a, b, c, t1, t2, t3 = p
        a2, b2, c2_, u1, u2, u3 = q_
        return ((a + a2) % 2, (b + b2) % 2, (c + c2_) % 2,
                (t1 + u1 + b * a2) % 2, (t2 + u2 + c * a2) % 2, (t3 + u3 + c * b2) % 2)
    if 'G64' in which:
        e0 = (0,) * 6
        run('G64 (free class-2 exp-2-gens), s=[x,y][x,z] (in gamma_2, NOT a square), g=1, c=s',
            [(1, 0, 0, 0, 0, 0), (0, 1, 0, 0, 0, 0), (0, 0, 1, 0, 0, 0)], g64, e0, (0, 0, 0, 1, 1, 0), e0, 6)
    m32 = lambda x, y: ((x[0] + pow(9, x[1], 16) * y[0]) % 16, (x[1] + y[1]) % 2)
    if 'M32' in which:
        run('M32, s=a^2, g=a (non-central), c=1', [(1, 0), (0, 1)], m32, (0, 0), (2, 0), (1, 0), 6)
    def dih(m):
        return lambda x, y: ((x[0] + (-1) ** x[1] * y[0]) % m, (x[1] + y[1]) % 2)
    if 'D16' in which:
        run('D16, s=a^4, g=a, c=a^2 (order 4, k=1 non-vacuous)', [(1, 0), (0, 1)], dih(8), (0, 0), (4, 0), (1, 0), 6)
        run('D16, s=a^4, g=b, c=a^4', [(1, 0), (0, 1)], dih(8), (0, 0), (4, 0), (0, 1), 6)
    if 'D32' in which:
        run('D32, s=a^8, g=a, c=a^6 (order 8, k=2 non-vacuous)', [(1, 0), (0, 1)], dih(16), (0, 0), (8, 0), (1, 0), 6)
    d8c2 = lambda x, y: ((x[0] + (-1) ** x[1] * y[0]) % 4, (x[1] + y[1]) % 2, (x[2] + y[2]) % 2)
    if 'D8xC2' in which:
        run('NEG: D8xC2, s=z (C2 factor, not in Phi), g=1', [(1, 0, 0), (0, 1, 0), (0, 0, 1)], d8c2, (0, 0, 0), (0, 0, 1), (0, 0, 0), 5)
        run('NEG: D8xC2, s=a^2 z (not in Phi), g=a', [(1, 0, 0), (0, 1, 0), (0, 0, 1)], d8c2, (0, 0, 0), (2, 0, 1), (1, 0, 0), 5)
    if 'sanity' in which:
        H = Group([(1, 0), (0, 1)], m16, (0, 0)); Z = H.centre()
        print('M16 centre', [H.els[i] for i in Z], 'squares of central', sorted({H.els[H.T[i][i]] for i in Z}))
        H = Group([(1, 0, 0, 0, 0, 0), (0, 1, 0, 0, 0, 0), (0, 0, 1, 0, 0, 0)], g64, (0,) * 6)
        print('G64 order', H.N, 'centre size', len(H.centre()), 'all squares', sorted({H.els[H.T[i][i]] for i in range(H.N)}))
