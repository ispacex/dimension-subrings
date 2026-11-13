#!/usr/bin/env python3
"""MATH-467 (wiki 891 Sec. 13): the universal model of Sec. 11.4 in pure Python, diagonal labellings, and orbits of
(A, K_9) under changes of basis of Q_ab.

Model (identical to compute/magnus/case450/universal.sage, there checked with Sage and GAP; here re-implemented
independently with integer linear algebra over Z/MOD):
  parameters u_ij, w'_ijk, w''_ijk (w eliminated by (A), exact over Z, as in case450/certificate.sage);
  Lambda(A, K) : the constraint vectors (B)_i, (D2)_ij, (D1)_i lie in K_e, e = gcd(MOD, d(i));
  Sigma(A, K)  : sigma mod MOD with (J), (Kt), (Ko);
  check        : R(lambda, sigma) = 0 on generators of Lambda x Sigma.
K is a dict e -> list of generator vectors of K_e (MOD Z^s implicit), for e in {3, 9} (MOD = 9) or {3, 9, 27} (MOD = 27).

Modes:
  validate TYPE [DROP]   all (A, K_9) for MOD = 9 (same enumeration as universal.sage); prints its summary line
  diag S [MOD] [DROP]    all capped types of length S, all A and all DIAGONAL K (labels per index)
  orbits TYPE            MOD = 9: orbits of (A, K_9) under Stab_Gamma(K_3); orbits without a diagonal member are
                         checked directly with the model
"""
import itertools, sys
from math import gcd, comb
import numpy as np

# ---------------------------------------------------------------- linear algebra over Z/3^k
def v3(x, mod):
    x %= mod
    if x == 0: return 99
    v = 0
    while x % 3 == 0: x //= 3; v += 1
    return v

def howell(rows, ncols, mod):
    """Howell-type echelon form over Z/mod (mod a power of 3): list of (col, row, val), rows as numpy int64 arrays.
    Property used: the submodule of the row span consisting of vectors vanishing on columns < c is spanned by the
    returned rows whose pivot column is >= c (saturation rows 3^(k-v) * pivot row are added)."""
    k = 0
    while 3 ** k < mod: k += 1
    pool = [np.asarray(r, dtype=np.int64) % mod for r in rows]
    pool = [r for r in pool if r.any()]
    piv = []
    for col in range(ncols):
        cand = [t for t, r in enumerate(pool) if r[col] % mod]
        if not cand: continue
        b = min(cand, key=lambda t: v3(int(pool[t][col]), mod))
        best = pool[b]
        v = v3(int(best[col]), mod); unit = (int(best[col]) // 3 ** v) % mod
        prow = (best * pow(unit, -1, mod)) % mod
        newpool = []
        for t, r in enumerate(pool):
            if t == b: continue
            c = int(r[col]) % mod
            if c: r = (r - (c // 3 ** v) * prow) % mod
            if r.any(): newpool.append(r)
        if v > 0:
            sat = (prow * 3 ** (k - v)) % mod
            if sat.any(): newpool.append(sat)
        piv.append((col, prow, v)); pool = newpool
    return piv

def kernel(conds, n, mod):
    """generators of { x in (Z/mod)^n : sum_k r_k x_k = 0 mod m for each (r, m) }, m | mod, r a dict k -> coef"""
    if not conds: return [np.eye(n, dtype=np.int64)[k] for k in range(n)]
    m = len(conds)
    A = np.zeros((n, m + n), dtype=np.int64)
    for c, (r, mm) in enumerate(conds):
        f = mod // mm
        for k, x in r.items(): A[k, c] += f * x
    A[:, m:] = np.eye(n, dtype=np.int64)
    piv = howell(list(A), m + n, mod)
    return [row[m:] for col, row, v in piv if col >= m]

# ---------------------------------------------------------------- the model
class Model:
    def __init__(self, d, mod=9, drop=()):
        self.d = d; self.mod = mod; self.drop = set(drop)
        # (A) is used to eliminate w and cannot be dropped here; that control exists only in case450/universal.sage
        assert self.drop <= {'B', 'D1', 'D2', 'J', 'Kt', 'Ko', 'Kall'}, self.drop
        s = self.s = len(d); idx = range(s)
        assert list(d) == sorted(d)
        q = lambda i, j: d[j] // d[i]
        n0 = lambda *ks: min(d[k] for k in ks)
        P = []
        def par(*k): P.append(k); return len(P) - 1
        U = {}; Wp = {}; Wpp = {}
        for i, j in itertools.combinations(idx, 2): U[i, j] = par('u', i, j)
        for i, j, k in itertools.product(idx, idx, idx):
            if i < j <= k: Wp[i, j, k] = par('wp', i, j, k)
            if i <= j < k: Wpp[i, j, k] = par('wpp', i, j, k)
        self.P = P; NP = self.NP = len(P)
        def W(i, j, k):   # (A), solved for w over Z
            if i == j == k: return {}
            if i == j < k: f = {U[i, k]: (-q(i, k) * comb(d[i], 2), d[i]), Wpp[i, i, k]: (-d[k], d[i])}
            elif i < j == k: f = {U[i, j]: (comb(d[j], 2), d[i]), Wp[i, j, j]: (-d[j], d[i])}
            else: f = {Wp[i, j, k]: (-d[j], d[i]), Wpp[i, j, k]: (-d[k], d[i])}
            out = {}
            for a, (num, den) in f.items():
                assert num % den == 0; out[a] = num // den
            return out
        S = {}
        for g, i, h in itertools.product(idx, idx, idx):
            if g < i: S[g, i, h] = len(S)
        self.S = S; NS = self.NS = len(S)
        def sig(g, i, h):
            if g == i: return {}
            return {S[g, i, h]: 1} if g < i else {S[i, g, h]: -1}
        sc = lambda f, c: {k: v * c for k, v in f.items()}
        tau = lambda g, i, h: {} if g == i else sc(sig(g, i, h), d[g] // n0(g, i, h))
        om = lambda g, i, h: {} if g == i else sc(sig(g, i, h), d[h] // n0(g, i, h))
        self.sig = sig
        RB = np.zeros((NP, NS), dtype=np.int64)
        def addR(p, f, c):
            for t, x in f.items(): RB[p, t] += c * x
        for i, h in itertools.combinations(idx, 2):
            hh = (d[h] - 1) // 2
            addR(U[i, h], om(i, h, i), hh * q(i, h))
            addR(U[i, h], om(i, h, h), -hh - 1)
        for i, g, h in itertools.product(idx, idx, idx):
            if i < g <= h: addR(Wp[i, g, h], tau(g, i, h), -1)
        for j, k, h in itertools.product(idx, idx, idx):
            if j < k < h: addR(Wpp[j, k, h], om(j, k, h), 1)
        self.RB = RB % mod
        V = []
        dr = self.drop
        if 'B' not in dr:
            for i in idx:
                V.append(({h: ({U[i, h]: 1} if i < h else ({U[h, i]: -q(h, i)} if h < i else {})) for h in idx},
                          gcd(mod, d[i])))
        if 'D2' not in dr:
            for i, j in itertools.combinations(idx, 2):
                V.append(({h: (W(h, i, j) if h <= i else ({Wp[i, h, j]: 1} if h <= j else {Wpp[i, j, h]: 1}))
                           for h in idx}, gcd(mod, d[i])))
        if 'D1' not in dr:
            for i in idx:
                V.append(({h: (W(h, i, i) if h <= i else {Wpp[i, i, h]: 1}) for h in idx}, gcd(mod, d[i])))
        self.V = V
        F = []
        for m, n in itertools.product(idx, idx):
            F.append(({h: tau(h, m, n) for h in idx}, gcd(mod, gcd(d[m], d[n])), 'Kt'))
        for a, b in itertools.combinations(idx, 2):
            F.append(({h: om(a, b, h) for h in idx}, gcd(mod, gcd(d[a], d[b])), 'Ko'))
        self.F = F
        J = []
        if 'J' not in dr:
            for a, b, c in itertools.combinations(idx, 3):
                r = {}
                for t in (sig(a, b, c), sig(b, c, a), sig(c, a, b)):
                    for k, x in t.items(): r[k] = r.get(k, 0) + x
                J.append((r, mod))
        self.J = J

    def perp(self, gens):
        """phi with phi . k = 0 mod MOD for all generators k (MOD Z^s implicit)"""
        conds = [({h: int(g[h]) for h in range(self.s) if g[h] % self.mod}, self.mod) for g in gens]
        conds = [c for c in conds if c[0]]
        return kernel(conds, self.s, self.mod)

    def check(self, K):
        """K: dict e -> generators of K_e.  Returns (ok, sigma_nonzero)"""
        mod = self.mod; s = self.s
        lconds = []
        Kp = {e: self.perp(K[e]) for e in K}
        for vec, e in self.V:
            if e == 1: continue
            for phi in Kp[e]:
                r = {}
                for h in range(s):
                    if phi[h] % mod:
                        for k, c in vec[h].items(): r[k] = r.get(k, 0) + int(phi[h]) * c
                if r: lconds.append((r, mod))
        Lg = kernel(lconds, self.NP, mod)
        sconds = list(self.J)
        for fv, eF, kind in self.F:
            if kind in self.drop or 'Kall' in self.drop:
                gens = [np.eye(s, dtype=np.int64)[h] * eF for h in range(s)]
            else:
                gens = K[eF] if eF in K else [np.eye(s, dtype=np.int64)[h] for h in range(s)]
            for v in gens:
                r = {}
                for h in range(s):
                    if v[h] % mod:
                        for k, c in fv[h].items(): r[k] = r.get(k, 0) + int(v[h]) * c
                if r: sconds.append((r, mod))
        Sg = kernel(sconds, self.NS, mod)
        self.last_unit = any(bool((np.asarray(g) % 3).any()) for g in Sg)
        if not Lg or not Sg: return True, bool(Sg)
        Lm = np.array(Lg) % mod; Sm = np.array(Sg) % mod
        val = (Lm @ self.RB % mod) @ Sm.T % mod
        return (not val.any()), bool(Sm.any())

# ---------------------------------------------------------------- configurations for MOD = 9
def capped_types(S, cap=9):
    out = []
    for d1 in [3, 9] + ([27] if cap == 27 else []):
        for gaps in itertools.product([1, 3, 9] + ([27] if cap == 27 else []), repeat=S - 1):
            d = [d1]
            for g in gaps: d.append(d[-1] * g)
            out.append(d)
    return out

def subspaces(n):
    """all subspaces of F_3^n as tuples of RREF rows (tuples)"""
    out = []
    for r in range(n + 1):
        for pivs in itertools.combinations(range(n), r):
            free = [(i, j) for i in range(r) for j in range(n) if j > pivs[i] and j not in pivs]
            for vals in itertools.product(range(3), repeat=len(free)):
                M = [[0] * n for _ in range(r)]
                for i in range(r): M[i][pivs[i]] = 1
                for (i, j), x in zip(free, vals): M[i][j] = x
                out.append(tuple(tuple(row) for row in M))
    return out

def rref3(rows, n):
    M = [list(r) for r in rows]
    out = []; rk = 0
    for c in range(n):
        p = next((i for i in range(rk, len(M)) if M[i][c] % 3), None)
        if p is None: continue
        M[rk], M[p] = M[p], M[rk]
        inv = 1 if M[rk][c] % 3 == 1 else 2
        M[rk] = [(x * inv) % 3 for x in M[rk]]
        for i in range(len(M)):
            if i != rk and M[i][c] % 3:
                f = M[i][c]; M[i] = [(a - f * b) % 3 for a, b in zip(M[i], M[rk])]
        rk += 1
    return tuple(tuple(r) for r in M[:rk])

def config_K(s, A, X):
    """K_3, K_9 generators for the A/N partition and the subspace X of K_3/3K_3 (basis e_n (n in N), 3e_a (a in A))"""
    N = [h for h in range(s) if h not in A]
    K3 = [np.eye(s, dtype=np.int64)[h] * (3 if h in A else 1) for h in range(s)]
    K9 = [3 * k for k in K3]
    for x in X:
        v = np.zeros(s, dtype=np.int64)
        for h in range(s): v[h] = x[h] * (3 if h in A else 1)
        K9.append(v)
    return {3: K3, 9: K9}

def is_block2(X, A, d):
    """K_9 (given by the subspace X of K_3/3K_3 in the basis b_h) is block diagonal with blocks singletons and pairs
    {a, n}, a in A, n in N, d(n) >= 9 d(a) (wiki 891 Sec. 13, Lemma 13.2): the RREF rows have support of size <= 2,
    pairwise disjoint, and every 2-support is such a pair"""
    used = set()
    for row in X:
        sup = [h for h, x in enumerate(row) if x]
        if used & set(sup): return False
        used |= set(sup)
        if len(sup) > 2: return False
        if len(sup) == 2:
            a, n = sup
            if n in A: a, n = n, a
            if not (a in A and n not in A and d[n] >= 9 * d[a]): return False
    return True

def is_diag(X):
    return all(sum(1 for x in row if x) == 1 for row in X)

def stab_generators(d, A):
    """C matrices (mod 9) in Gamma that fix K_3 = Z^N + 3Z^A; Ybar'_j = sum_i c_ij Ybar_i, K' = C^{-1} K"""
    s = len(d); gens = []
    for j in range(s):
        C = np.eye(s, dtype=np.int64); C[j, j] = 2; gens.append(C)
    for i in range(s):
        for j in range(s):
            if i == j: continue
            if d[i] >= d[j]: c = 3 if (j not in A and i in A) else 1
            elif d[j] // d[i] == 3: c = 3
            else: continue
            C = np.eye(s, dtype=np.int64); C[i, j] = c; gens.append(C)
    return gens

def inv_mod9(C):
    """exact inverse mod 9 via the adjugate over Z (C is a small integer matrix with det a unit mod 9)"""
    from fractions import Fraction
    s = C.shape[0]
    M = [[Fraction(int(C[i][j])) for j in range(s)] + [Fraction(int(i == j)) for j in range(s)] for i in range(s)]
    for c in range(s):
        p = next(i for i in range(c, s) if M[i][c] != 0)
        M[c], M[p] = M[p], M[c]
        pv = M[c][c]; M[c] = [x / pv for x in M[c]]
        for i in range(s):
            if i != c and M[i][c] != 0:
                f = M[i][c]; M[i] = [a - f * b for a, b in zip(M[i], M[c])]
    Inv = np.zeros((s, s), dtype=np.int64)
    for i in range(s):
        for j in range(s):
            x = M[i][s + j]
            Inv[i][j] = (x.numerator * pow(x.denominator, -1, 9)) % 9
    assert ((Inv @ C) % 9 == np.eye(s, dtype=np.int64)).all()
    return Inv

def induced(C, A, s):
    """the F_3-matrix of K -> C^{-1} K on K_3/3K_3 (basis b_h = e_h (h in N), 3e_h (h in A)), acting on row vectors"""
    Ci = inv_mod9(C)
    T = [[0] * s for _ in range(s)]
    for h in range(s):
        b = np.zeros(s, dtype=np.int64); b[h] = 3 if h in A else 1
        w = (Ci @ b) % 9
        for g in range(s):
            if g in A: assert w[g] % 3 == 0; T[h][g] = (int(w[g]) // 3) % 3
            else: T[h][g] = int(w[g]) % 3
    return T

def orbits(d, verbose=True):
    s = len(d); M = Model(d, 9); subs = subspaces(s)
    tot_orbits = 0; nodiag = 0; failing = 0; checked = 0; noblock = 0
    for r in range(s + 1):
        for A in itertools.combinations(range(s), r):
            A = set(A)
            Ts = [induced(C, A, s) for C in stab_generators(d, A)]
            pos = {X: t for t, X in enumerate(subs)}
            parent = list(range(len(subs)))
            def find(x):
                while parent[x] != x:
                    parent[x] = parent[parent[x]]; x = parent[x]
                return x
            for t, X in enumerate(subs):
                for T in Ts:
                    Y = rref3([[sum(row[h] * T[h][g] for h in range(s)) % 3 for g in range(s)] for row in X], s)
                    a, b = find(t), find(pos[Y])
                    if a != b: parent[a] = b
            comps = {}
            for t in range(len(subs)): comps.setdefault(find(t), []).append(t)
            tot_orbits += len(comps)
            for members in comps.values():
                if not any(is_block2(subs[t], A, d) for t in members): noblock += 1
                if any(is_diag(subs[t]) for t in members): continue
                nodiag += 1
                X = subs[members[0]]
                ok, _ = M.check(config_K(s, A, X)); checked += 1
                if not ok:
                    failing += 1
                    if verbose: print("   FAIL A =", sorted(A), "X =", X, flush=True)
    print("BLOCK2 type", d, "orbits", tot_orbits, "without a block member (Lemma 13.2)", noblock, flush=True)
    print("ORBITS type", d, "orbits", tot_orbits, "without diagonal member", nodiag, "checked directly", checked,
          "FAILING", failing, flush=True)
    return failing

def validate(d, drop=()):
    s = len(d); M = Model(d, 9, drop); subs = subspaces(s)
    total = nfree = nbad = 0
    for r in range(s + 1):
        for A in itertools.combinations(range(s), r):
            for X in subs:
                ok, fr = M.check(config_K(s, set(A), X))
                total += 1; nfree += fr; nbad += (not ok)
    print("type", d, "drop", sorted(drop), "cases (A, K_9):", total, "with sigma != 0:", nfree, "FAILING:", nbad, flush=True)
    return nbad

def diag(S, mod=9, drop=()):
    labels9 = [(1, 'N'), (3, 'N'), (3, 'A'), (9, 'A')]
    nfail = 0; ncase = 0
    for d in capped_types(S, mod):
        M = Model(d, mod, drop); bad = 0
        if mod == 9:
            for lab in itertools.product(labels9, repeat=S):
                A = {h for h in range(S) if lab[h][1] == 'A'}
                K3 = [np.eye(S, dtype=np.int64)[h] * (3 if h in A else 1) for h in range(S)]
                K9 = [np.eye(S, dtype=np.int64)[h] * lab[h][0] for h in range(S)]
                ok, _ = M.check({3: K3, 9: K9}); ncase += 1
                if not ok: bad += 1
        else:
            for lab in itertools.product(diag27_labels(), repeat=S):
                K = {e: [np.eye(S, dtype=np.int64)[h] * lab[h][e] for h in range(S)] for e in (3, 9, 27)}
                ok, _ = M.check(K); ncase += 1
                if not ok: bad += 1
        nfail += bad
        print("  type", d, "failing labellings", bad, flush=True)
    print("DIAG S =", S, "mod", mod, "drop", sorted(drop), "cases", ncase, "FAILING", nfail, flush=True)
    return nfail

def diag27_labels():
    """per index: (m_3, m_9, m_27) with K_e = m_e Z, m_3 | 3, m_9 | 9, m_27 | 27, m_3 | m_9 | m_27,
    3 m_3 | ... : 3K_3 <= K_9 (m_9 | 3 m_3), 3K_9 <= K_27 (m_27 | 3 m_9)"""
    out = []
    for m3 in (1, 3):
        for m9 in (1, 3, 9):
            for m27 in (1, 3, 9, 27):
                if m9 % m3 or m27 % m9: continue
                if (3 * m3) % m9 or (3 * m9) % m27: continue
                out.append({3: m3, 9: m9, 27: m27})
    return out

if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'validate':
        sys.exit(1 if validate([int(a) for a in sys.argv[2].split(',')], sys.argv[3].split(',') if len(sys.argv) > 3 else ()) else 0)
    elif mode == 'diag':
        sys.exit(1 if diag(int(sys.argv[2]), int(sys.argv[3]) if len(sys.argv) > 3 else 9,
                           sys.argv[4].split(',') if len(sys.argv) > 4 and sys.argv[4] else ()) else 0)
    elif mode == 'orbits':
        f = orbits([int(a) for a in sys.argv[2].split(',')])
        sys.exit(1 if f else 0)

# ---------------------------------------------------------------- MOD = 27 (gamma_4^27 = 1), wiki 891 Sec. 13.4
def zbasis(gens, s):
    """Z-basis (HNF rows) of the lattice spanned by integer vectors gens (full rank expected)"""
    M = [list(map(int, g)) for g in gens]
    H = []
    for c in range(s):
        rows = [r for r in M if r[c] != 0]
        others = [r for r in M if r[c] == 0]
        while len(rows) > 1:
            rows.sort(key=lambda r: abs(r[c]))
            p = rows[0]
            new = [p]
            for r in rows[1:]:
                f = r[c] // p[c]
                r2 = [a - f * b for a, b in zip(r, p)]
                if r2[c] != 0: new.append(r2)
                else: others.append(r2)
            rows = new
        if rows:
            p = rows[0]
            if p[c] < 0: p = [-a for a in p]
            H.append(p)
        M = [r for r in others if any(r)]
    assert len(H) == s
    return H

def configs27(s):
    """all (A, K_3, K_9, K_27) with K_3 = Z^N + 3Z^A, 3K_3 <= K_9 <= K_3, 3K_9 <= K_27 <= K_9"""
    subs = subspaces(s)
    for r in range(s + 1):
        for A in itertools.combinations(range(s), r):
            A = set(A)
            K3 = [[(3 if h in A else 1) * int(h == g) for g in range(s)] for h in range(s)]
            for X in subs:
                g9 = [[3 * a for a in k] for k in K3] + [[x[h] * (3 if h in A else 1) for h in range(s)] for x in X]
                B9 = zbasis(g9, s)
                for Z in subs:
                    g27 = [[3 * a for a in b] for b in B9] + [[sum(z[t] * B9[t][h] for t in range(s)) for h in range(s)]
                                                               for z in Z]
                    yield A, X, Z, {3: [np.array(k) for k in K3], 9: [np.array(k) for k in B9],
                                    27: [np.array(k) for k in g27]}

def brute27(d, drop=()):
    s = len(d); M = Model(d, 27, drop)
    total = nfree = nbad = nunit = 0; ex = []
    for A, X, Z, K in configs27(s):
        ok, fr = M.check(K)
        total += 1; nfree += fr; nunit += M.last_unit
        if not ok:
            nbad += 1
            if len(ex) < 2: ex.append((sorted(A), X, Z))
    print("MOD27 type", d, "drop", sorted(drop), "cases", total, "with sigma != 0:", nfree, "with sigma of order 27:", nunit, "FAILING:", nbad, ex, flush=True)
    return nbad

if __name__ == '__main__' and sys.argv[1] == 'brute27':
    f = brute27([int(a) for a in sys.argv[2].split(',')], sys.argv[3].split(',') if len(sys.argv) > 3 and sys.argv[3] else ())
    sys.exit(1 if f else 0)

# ---------------------------------------------------------------- MOD = 3^k in general (gamma_4^(3^k) = 1)
def configs_k(s, k, A_list=None):
    """all (A, {3^j: K_{3^j}}) with K_3 = Z^N + 3Z^A and 3K_e <= K_{3e} <= K_e (j = 1..k)"""
    subs = subspaces(s)
    As = A_list if A_list is not None else [set(A) for r in range(s + 1) for A in itertools.combinations(range(s), r)]
    for A in As:
        K3 = [[(3 if h in A else 1) * int(h == g) for g in range(s)] for h in range(s)]
        def rec(e, B, acc):
            if e == 3 ** k:
                yield dict(acc); return
            for X in subs:
                g = [[3 * a for a in b] for b in B] + [[sum(x[t] * B[t][h] for t in range(s)) for h in range(s)] for x in X]
                B2 = zbasis(g, s)
                acc[3 * e] = B2
                yield from rec(3 * e, B2, acc)
            acc.pop(3 * e, None)
        for K in rec(3, K3, {3: K3}):
            yield A, {e: [np.array(b) for b in K[e]] for e in K}

def labels_k(k):
    out = []
    for m3 in (1, 3):
        def rec(seq):
            if len(seq) == k: out.append({3 ** (j + 1): seq[j] for j in range(k)}); return
            for m in (seq[-1], 3 * seq[-1]): rec(seq + [m])
        rec([m3])
    return out

def capped_types_k(S, k):
    cap = 3 ** k; vals = [3 ** j for j in range(1, k + 1)]; gaps = [1] + vals
    out = []
    for d1 in vals:
        for g in itertools.product(gaps, repeat=S - 1):
            d = [d1]
            for x in g: d.append(d[-1] * x)
            out.append(d)
    return out

def diag_k(S, k, drop=(), types=None):
    nfail = ncase = 0
    for d in (types or capped_types_k(S, k)):
        M = Model(d, 3 ** k, drop); bad = 0
        for lab in itertools.product(labels_k(k), repeat=S):
            K = {e: [np.eye(S, dtype=np.int64)[h] * lab[h][e] for h in range(S)] for e in lab[0]}
            ok, _ = M.check(K); ncase += 1; bad += (not ok)
        nfail += bad
    print("DIAGK S =", S, "mod", 3 ** k, "drop", sorted(drop), "types", len(types or capped_types_k(S, k)), "cases", ncase,
          "FAILING", nfail, flush=True)
    return nfail

def brute_k(d, k, drop=()):
    s = len(d); M = Model(d, 3 ** k, drop)
    total = nfree = nbad = nunit = 0; ex = []
    for A, K in configs_k(s, k):
        ok, fr = M.check(K)
        total += 1; nfree += fr; nunit += M.last_unit
        if not ok:
            nbad += 1
            if len(ex) < 2: ex.append((sorted(A), {e: [list(map(int, b)) for b in K[e]] for e in K}))
    print("MODK", 3 ** k, "type", d, "drop", sorted(drop), "cases", total, "with sigma != 0:", nfree,
          "with sigma of full order:", nunit, "FAILING:", nbad, ex, flush=True)
    return nbad

if __name__ == '__main__' and sys.argv[1] == 'brutek':
    f = brute_k([int(a) for a in sys.argv[3].split(',')], int(sys.argv[2]),
                sys.argv[4].split(',') if len(sys.argv) > 4 and sys.argv[4] else ())
    sys.exit(1 if f else 0)
if __name__ == '__main__' and sys.argv[1] == 'diagk':
    f = diag_k(int(sys.argv[3]), int(sys.argv[2]), sys.argv[4].split(',') if len(sys.argv) > 4 and sys.argv[4] else ())
    sys.exit(1 if f else 0)

def hnf_key(gens, s, mod):
    """canonical key of the lattice spanned by gens + mod Z^s: HNF with entries above the pivots reduced"""
    H = zbasis([list(map(int, g)) for g in gens] + [[mod * int(h == g) for g in range(s)] for h in range(s)], s)
    for c in range(s):          # rows are in pivot order c = 0..s-1, pivot H[c][c] > 0
        for r in range(c):
            f = H[r][c] // H[c][c]
            if f: H[r] = [a - f * b for a, b in zip(H[r], H[c])]
    return tuple(tuple(r) for r in H)

def gen_mats(d, A, mod):
    """generators of Gamma ∩ Stab(K_3) as integer matrices C (K' = C^{-1} K), with their inverses mod 'mod'"""
    s = len(d); out = []
    for j in range(s):
        C = np.eye(s, dtype=np.int64); C[j, j] = 2
        Ci = np.eye(s, dtype=np.int64); Ci[j, j] = pow(2, -1, mod); out.append(Ci)
    for i in range(s):
        for j in range(s):
            if i == j: continue
            q = d[j] // d[i] if d[j] > d[i] else 1
            c = q
            if d[i] >= d[j] and (j not in A and i in A): c = 3
            if c % mod == 0: continue
            Ci = np.eye(s, dtype=np.int64); Ci[i, j] = -c; out.append(Ci)
    return out

def orbits_k(d, k, verbose=False):
    """orbits of all chain configurations (A, K_3 >= K_9 >= ... >= K_{3^k}) under Stab_Gamma(K_3); orbits without a
    diagonal member are checked directly"""
    s = len(d); mod = 3 ** k; M = Model(d, mod)
    def key(K): return tuple(hnf_key(K[3 ** j], s, mod) for j in range(2, k + 1))
    def isdiag(kk): return all(all(H[r][c] == 0 for r in range(s) for c in range(s) if r != c) for H in kk)
    tot = nd = fail = 0
    for r in range(s + 1):
        for A in itertools.combinations(range(s), r):
            A = set(A)
            confs = {}
            for _, K in configs_k(s, k, [A]): confs[key(K)] = K
            keys = list(confs); pos = {x: t for t, x in enumerate(keys)}; parent = list(range(len(keys)))
            def find(x):
                while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
                return x
            G = gen_mats(d, A, mod)
            for t, kk in enumerate(keys):
                for Ci in G:
                    k2 = tuple(hnf_key([Ci @ np.array(row) for row in H], s, mod) for H in kk)
                    a, b = find(t), find(pos[k2])
                    if a != b: parent[a] = b
            comps = {}
            for t in range(len(keys)): comps.setdefault(find(t), []).append(t)
            tot += len(comps)
            for mem in comps.values():
                if any(isdiag(keys[t]) for t in mem): continue
                nd += 1
                ok, _ = M.check(confs[keys[mem[0]]])
                if not ok:
                    fail += 1
                    if verbose: print("   FAIL", sorted(A), keys[mem[0]])
    print("ORBITSK mod", mod, "type", d, "orbits", tot, "without diagonal member", nd, "FAILING", fail, flush=True)
    return fail

if __name__ == '__main__' and sys.argv[1] == 'orbitsk':
    f = orbits_k([int(a) for a in sys.argv[3].split(',')], int(sys.argv[2]), True)
    sys.exit(1 if f else 0)

# ---------------------------------------------------------------- validate split by A (parallel brute force, s = 5)
def validate_A(d, A):
    """all K_9 for one A (MOD = 9); the union over all A is 'validate'"""
    s = len(d); M = Model(d, 9); subs = subspaces(s)
    total = nfree = nbad = 0
    for X in subs:
        ok, fr = M.check(config_K(s, set(A), X))
        total += 1; nfree += fr; nbad += (not ok)
    print("VALA type", d, "A", sorted(A), "cases", total, "with sigma != 0:", nfree, "FAILING:", nbad, flush=True)
    return nbad

if __name__ == '__main__' and sys.argv[1] == 'validatea':
    _d = [int(a) for a in sys.argv[2].split(',')]
    _A = [int(a) for a in sys.argv[3].split(',') if a != ''] if len(sys.argv) > 3 else []
    sys.exit(1 if validate_A(_d, _A) else 0)

# ---------------------------------------------------------------- block-diagonal configurations (wiki 891 Sec. 13)
def block_configs(d):
    """all (A, K_3, K_9) on the capped type d whose K_9 is block diagonal with at most 3 blocks, each a singleton
    (diagonal label) or a pair a < n with a in A, n in N, d(n) >= 9 d(a) and K_9|_{a,n} = <(3, -eps), (0, 3)>"""
    s = len(d); labels9 = [(1, 'N'), (3, 'N'), (3, 'A'), (9, 'A')]
    def partitions(rest):
        if not rest: yield []; return
        h = rest[0]
        for p in partitions(rest[1:]): yield [(h,)] + p
        for n in rest[1:]:
            if d[n] >= 9 * d[h]:
                r2 = [x for x in rest[1:] if x != n]
                for p in partitions(r2): yield [(h, n)] + p
    for blocks in partitions(list(range(s))):
        if len(blocks) > 3: continue
        singles = [b[0] for b in blocks if len(b) == 1]; pairs = [b for b in blocks if len(b) == 2]
        for lab in itertools.product(labels9, repeat=len(singles)):
            for eps in itertools.product((1, 2), repeat=len(pairs)):
                A = {h for h, l in zip(singles, lab) if l[1] == 'A'} | {a for a, n in pairs}
                E = np.eye(s, dtype=np.int64)
                K3 = [E[h] * (3 if h in A else 1) for h in range(s)]
                K9 = [E[h] * l[0] for h, l in zip(singles, lab)]
                for (a, n), e in zip(pairs, eps):
                    K9 += [3 * E[a] + (9 - e) * E[n], 3 * E[n], 9 * E[a]]
                yield blocks, A, {3: K3, 9: K9}

def blocks_check(S, drop=()):
    nfail = ncase = npair = 0; ntypes = 0
    for d in capped_types(S):
        M = Model(d, 9, drop); bad = 0; ntypes += 1
        for blocks, A, K in block_configs(d):
            ok, _ = M.check(K); ncase += 1; bad += (not ok)
            npair += any(len(b) == 2 for b in blocks)
        nfail += bad
        if bad: print("  type", d, "failing", bad, flush=True)
    print("BLOCKS S =", S, "drop", sorted(drop), "types", ntypes, "configs", ncase, "with a pair block", npair,
          "FAILING", nfail, flush=True)
    return nfail

if __name__ == '__main__' and sys.argv[1] == 'blocks':
    f = blocks_check(int(sys.argv[2]), sys.argv[3].split(',') if len(sys.argv) > 3 and sys.argv[3] else ())
    sys.exit(1 if f else 0)

if __name__ == '__main__' and sys.argv[1] == 'blockstype':
    _d = [int(a) for a in sys.argv[2].split(',')]; _M = Model(_d, 9); _n = _f = 0
    for _b, _A, _K in block_configs(_d):
        _ok, _ = _M.check(_K); _n += 1; _f += (not _ok)
        if not _ok: print("   FAIL", _b, sorted(_A), flush=True)
    print("BLOCKST type", _d, "configs", _n, "FAILING", _f, flush=True)
    sys.exit(1 if _f else 0)
