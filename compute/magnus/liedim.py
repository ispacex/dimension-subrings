"""delta_n(L)/gamma_n(L) for a finitely presented Lie ring L with weighted generators, modulo p^E.

U(L)/w^n = T_{<n}/I, where T_{<n} is the free associative ring on the generators truncated at
weight n (a generator of degree d has weight d) and I is spanned by u r v for defining relators r
and monomials u, v.  The free Lie ring F_{<n} sits in T_{<n} with the Lyndon basis (standard
bracketing); it is a direct summand (PBW over Z), so coordinates in that basis are exact.

    gamma side:  J = Lie ideal of the relators in F_{<n}, spanned by [r, g_1, ..., g_m];
    delta side:  K = { l in F_{<n} : l in I },
    delta_n/gamma_n = K / J  (both taken modulo p^E, see below).

Both K and J are found in Lyndon coordinates by one Howell form of [psi(b) | e_b ; X | 0] with the
T-columns first: the rows whose T-part vanishes span the preimage of span(X).

Modulo p^E.  NON-membership is exact: if p^t w is not in I + p^E T, it is not in I.  Orders of
elements of K/J are only lower bounds near p^E (a free summand of L/gamma_n shows up as order
p^E); torsion of order well below p^E that is stable under a change of E is real.

A generator of degree d stands, as in Bartholdi-Mikhailov (arXiv:1805.10894, sec. 2), for a
d-fold commutator of fresh generators.  Here it is kept as one letter of weight d instead.  That
gives an inclusion delta_n(weighted) -> delta_n(honest) on the delta side (substitution keeps the
filtration); on the gamma side this is what anq computes with weighted generators.
"""
import itertools
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from dimsub import Ring, howell, reduce_rows  # noqa: E402


class Pres:
    def __init__(self, gens, n, p=3, E=None):
        """gens: list of (name, weight)."""
        self.names = [g for g, _ in gens]
        self.w = [w for _, w in gens]
        self.k = len(gens)
        self.n = n
        self.R = Ring(p, E)
        self.monos = []
        self._monos((), 0)
        self.monos.sort(key=lambda m: (self.wt(m), m))
        self.idx = {m: i for i, m in enumerate(self.monos)}
        self.lyndon = [w for w in self._lyndon_words() if self.wt(w) < n]
        self.lyndon.sort(key=lambda m: (self.wt(m), m))
        self.basis = [self.std(w) for w in self.lyndon]
        self.rels = []

    # --- words -------------------------------------------------------------------------------
    def wt(self, m):
        return sum(self.w[i] for i in m)

    def _monos(self, m, s):
        for i in range(self.k):
            if s + self.w[i] < self.n:
                mm = m + (i,)
                self.monos.append(mm)
                self._monos(mm, s + self.w[i])

    def _lyndon_words(self):
        L = self.n - 1
        w = [-1]
        while w:
            w[-1] += 1
            yield tuple(w)
            m = len(w)
            while len(w) < L:
                w.append(w[len(w) - m])
            while w and w[-1] == self.k - 1:
                w.pop()

    def std(self, w):
        if len(w) == 1:
            return self.g(w[0])
        for i in range(1, len(w)):
            v = w[i:]
            if self._is_lyndon(v):
                return self.br(self.std(w[:i]), self.std(v))
        raise AssertionError

    @staticmethod
    def _is_lyndon(w):
        return all(w < w[i:] for i in range(1, len(w)))

    # --- elements: dict word -> int, truncated at weight n ------------------------------------
    def g(self, name):
        i = name if isinstance(name, int) else self.names.index(name)
        return {(i,): 1}

    def add(self, *xs):
        out = {}
        for x in xs:
            for m, c in x.items():
                out[m] = out.get(m, 0) + c
        return {m: c for m, c in out.items() if c}

    def sc(self, c, x):
        return {m: c * v for m, v in x.items() if c * v}

    def mul(self, a, b):
        out = {}
        for ma, ca in a.items():
            for mb, cb in b.items():
                m = ma + mb
                if self.wt(m) < self.n:
                    out[m] = out.get(m, 0) + ca * cb
        return {m: c for m, c in out.items() if c}

    def br(self, a, b):
        return self.add(self.mul(a, b), self.sc(-1, self.mul(b, a)))

    def lnc(self, *xs):
        c = xs[0]
        for x in xs[1:]:
            c = self.br(c, x)
        return c

    def lin(self, **coef):
        """Linear combination of generators: lin(e0=3, e1=-9)."""
        return self.add(*[self.sc(c, self.g(nm)) for nm, c in coef.items()])

    def rel(self, x):
        if x:
            self.rels.append(x)

    def vec(self, x):
        row = np.zeros(len(self.monos), dtype=np.int64)
        for m, c in x.items():
            row[self.idx[m]] = c % self.R.D
        return row

    def minwt(self, x):
        return min(self.wt(m) for m in x)

    # --- ideals ------------------------------------------------------------------------------
    def ideal_rows(self):
        rows = []
        bywt = {}
        for m in [()] + self.monos:
            bywt.setdefault(self.wt(m), []).append(m)
        for r in self.rels:
            o = self.minwt(r)
            for wu in range(self.n - o):
                for wv in range(self.n - o - wu):
                    for u in bywt.get(wu, []):
                        for v in bywt.get(wv, []):
                            x = self.mul(self.mul({u: 1}, r), {v: 1})
                            if x:
                                rows.append(self.vec(x))
        return np.array(rows)

    def lie_ideal_rows(self):
        rows = []
        for r in self.rels:
            frontier = [r]
            while frontier:
                nxt = []
                for x in frontier:
                    rows.append(self.vec(x))
                    for i in range(self.k):
                        y = self.br(x, self.g(i))
                        if y:
                            nxt.append(y)
                frontier = nxt
        return np.array(rows)

    def reduce_span(self, X, chunk=None):
        """Rows of a Howell form of span X, built chunk by chunk (same span, at most ~2 nT rows)."""
        if X.size == 0:
            return X
        chunk = chunk or max(256, 2 * X.shape[1])
        H = []
        for s in range(0, len(X), chunk):
            prev = [r for _, _, r in H]
            H = howell(self.R, np.vstack(prev + [X[s:s + chunk]]) if prev else X[s:s + chunk])
        return np.array([r for _, _, r in H], dtype=np.int64).reshape(-1, X.shape[1])

    def preimage(self, X):
        """Howell form (Lyndon coordinates) of {l in F_{<n} : psi(l) in span X + p^E T}."""
        X = self.reduce_span(X)
        nT, nB = len(self.monos), len(self.basis)
        top = np.hstack([np.array([self.vec(b) for b in self.basis]), np.eye(nB, dtype=np.int64)])
        A = top if X.size == 0 else np.vstack([top, np.hstack([X, np.zeros((len(X), nB), dtype=np.int64)])])
        H = howell(self.R, A)
        return [(c - nT, v, row[nT:]) for c, v, row in H if c >= nT]

    def coords(self, x):
        """Lyndon coordinates of a Lie element x (exact: back-substitution over Z)."""
        x = dict(x)
        out = np.zeros(len(self.basis), dtype=np.int64)
        # leading monomial of std(w) is w itself, with coefficient 1 (Lyndon property)
        order = sorted(range(len(self.lyndon)), key=lambda j: (self.wt(self.lyndon[j]), self.lyndon[j]))
        while x:
            # take the lexicographically smallest Lyndon word present among the monomials
            cand = [j for j in order if self.lyndon[j] in x]
            if not cand:
                raise ValueError("not a Lie element: " + repr(sorted(x)[:3]))
            j = cand[0]
            c = x[self.lyndon[j]]
            out[j] += c
            x = self.add(x, self.sc(-c, self.basis[j]))
        return out % self.R.D


def order_mod(R, H, x):
    """Smallest t with p^t x in span H (E+1 if none below p^E)."""
    for t in range(R.E + 1):
        if reduce_rows(R, H, ((R.ppow[t] * x) % R.D)[None, :])[0]:
            return t
    return R.E + 1


def analyse(P, tests=None, verbose=True):
    """Return (log_p|K/J| restricted to torsion below p^(E-2), list of orders, test results)."""
    R = P.R
    I = P.ideal_rows()
    J = P.lie_ideal_rows()
    K = P.preimage(I)
    HJ = P.preimage(J)
    # sanity: J inside K
    JK = np.array([r for _, _, r in HJ]) if HJ else np.zeros((0, len(P.basis)), dtype=np.int64)
    assert JK.size == 0 or reduce_rows(R, K, JK).all(), "J not inside K"
    orders = []
    for c, v, row in K:
        t = order_mod(R, HJ, row)
        if t:
            orders.append((t, P.lyndon[c]))
    # invariants: S_t = log_p |(p^t K + J)/J|; a free summand adds E - t, torsion p^m adds max(0, m - t)
    def S(t):
        Kt = [((R.ppow[t] * r) % R.D) for _, _, r in K] + [r for _, _, r in HJ]
        Ht = howell(R, np.array(Kt)) if Kt else []
        return sum(R.E - v for _, v, _ in Ht) - sum(R.E - v for _, v, _ in HJ)
    tf = R.E - 3
    free = S(tf) // 3
    tors = S(0) - free * R.E
    P.inv = dict(free=free, tors=tors, exp=max([t for t, _ in orders if t <= tf] or [0]))
    res = {}
    for name, x in (tests or {}).items():
        cx = P.coords(x)
        res[name] = dict(delta=bool(reduce_rows(R, K, cx[None, :])[0]), gamma_order=order_mod(R, HJ, cx))
    if verbose:
        print("n=%d gens=%d T=%d Lyndon=%d I=%d J=%d | delta/gamma: free rank %d, torsion p^%d, exponent p^%d"
              % (P.n, P.k, len(P.monos), len(P.basis), len(I), len(J), free, tors, P.inv["exp"]), flush=True)
        for name, r in res.items():
            print("  %-10s in delta_%d: %s ; order mod gamma_%d: p^%s" % (name, P.n, r["delta"], P.n, r["gamma_order"]))
    return orders, res
