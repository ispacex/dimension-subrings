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

Blocks.  When every relator is homogeneous in word length (e.g. all relators are linear in the
generators, as in the Bartholdi-Mikhailov rings), T_{<n}, I, F_{<n} and J all split by word
length, and each length is computed separately (analyse(..., blocks=[...]) restricts to some).

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

    # --- blocks -----------------------------------------------------------------------------
    def key(self, m):
        """Block of a monomial: its length when every relator is homogeneous in word length (then
        T_{<n}, I, F_{<n} and J all split by length), else a single block 0."""
        if not hasattr(self, "_homog"):
            self._homog = all(len({len(m) for m in r}) == 1 for r in self.rels)
        return len(m) if self._homog else 0

    def xkey(self, x):
        return self.key(next(iter(x)))

    # --- ideals ------------------------------------------------------------------------------
    def ideal_dicts(self, want=None):
        rows = []
        bywt = {}
        for m in [()] + self.monos:
            bywt.setdefault(self.wt(m), []).append(m)
        for r in self.rels:
            o, lr = self.minwt(r), len(next(iter(r)))
            for wu in range(self.n - o):
                for wv in range(self.n - o - wu):
                    for u in bywt.get(wu, []):
                        for v in bywt.get(wv, []):
                            if want is not None and self._homog and len(u) + lr + len(v) not in want:
                                continue
                            x = self.mul(self.mul({u: 1}, r), {v: 1})
                            if x:
                                rows.append(x)
        return rows

    def lie_ideal_dicts(self, want=None):
        top = max(want) if (want is not None and self._homog) else None
        rows = []
        for r in self.rels:
            frontier = [r]
            while frontier:
                nxt = []
                for x in frontier:
                    rows.append(x)
                    if top is not None and len(next(iter(x))) >= top:
                        continue
                    for i in range(self.k):
                        y = self.br(x, self.g(i))
                        if y:
                            nxt.append(y)
                frontier = nxt
        return rows

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

    def coords(self, x):
        """Lyndon coordinates of a Lie element x (exact: back-substitution over Z)."""
        x = dict(x)
        out = np.zeros(len(self.basis), dtype=np.int64)
        # std(w) = w + (lexicographically larger words of the same length): peel off the smallest
        pos = {w: j for j, w in enumerate(self.lyndon)}
        while x:
            m = min(x, key=lambda w: (len(w), w))
            if m not in pos:
                raise ValueError("not a Lie element: " + repr(m))
            j, c = pos[m], x[m]
            out[j] += c
            x = self.add(x, self.sc(-c, self.basis[j]))
        return out % self.R.D


class Block:
    """One block of T_{<n}: its monomials, its Lyndon words, and K, J there (Lyndon coordinates)."""

    def __init__(self, P, b, Irows, Jrows):
        R = P.R
        self.P, self.b = P, b
        self.cols = [m for m in P.monos if P.key(m) == b]
        self.cidx = {m: i for i, m in enumerate(self.cols)}
        self.lj = [j for j, w in enumerate(P.lyndon) if P.key(w) == b]
        self.K = self.preimage([x for x in Irows if P.xkey(x) == b])
        self.J = self.preimage([x for x in Jrows if P.xkey(x) == b])
        JK = np.array([r for _, _, r in self.J]) if self.J else None
        assert JK is None or reduce_rows(R, self.K, JK).all(), "J not inside K"

    def dense(self, xs):
        X = np.zeros((len(xs), len(self.cols)), dtype=np.int64)
        D = self.P.R.D
        for i, x in enumerate(xs):
            for m, c in x.items():
                X[i, self.cidx[m]] = c % D
        return X

    def preimage(self, xs):
        """Howell form (Lyndon coordinates) of {l : psi(l) in span xs + p^E T}, by one Howell form
        of [psi(b) | e_b ; X | 0] with the T-columns first."""
        P = self.P
        X = P.reduce_span(self.dense(xs)) if xs else np.zeros((0, len(self.cols)), dtype=np.int64)
        nT, nB = len(self.cols), len(self.lj)
        if nB == 0:
            return []
        top = np.hstack([self.dense([P.basis[j] for j in self.lj]), np.eye(nB, dtype=np.int64)])
        A = top if X.size == 0 else np.vstack([top, np.hstack([X, np.zeros((len(X), nB), dtype=np.int64)])])
        H = howell(P.R, A)
        return [(c - nT, v, row[nT:]) for c, v, row in H if c >= nT]


def order_mod(R, H, x):
    """Smallest t with p^t x in span H (E+1 if none below p^E)."""
    for t in range(R.E + 1):
        if reduce_rows(R, H, ((R.ppow[t] * x) % R.D)[None, :])[0]:
            return t
    return R.E + 1


def invariants(R, K, J):
    """(free rank, log_p torsion, orders of the K rows mod J) of K/J.
    S_t = log_p |(p^t K + J)/J|: a free summand adds E - t, a torsion summand p^m adds max(0, m - t)."""
    def S(t):
        Kt = [((R.ppow[t] * r) % R.D) for _, _, r in K] + [r for _, _, r in J]
        Ht = howell(R, np.array(Kt)) if Kt else []
        return sum(R.E - v for _, v, _ in Ht) - sum(R.E - v for _, v, _ in J)
    free = S(R.E - 3) // 3
    orders = [order_mod(R, J, row) for _, _, row in K]
    return free, S(0) - free * R.E, orders


def analyse(P, tests=None, verbose=True, blocks=None):
    """delta_n/gamma_n of P, block by block; 'blocks' restricts to those word lengths (only when the
    relators are length-homogeneous).  Sets P.inv = {free, tors, exp}; returns (witnesses, tests)."""
    R = P.R
    P.key(())                                      # fixes P._homog
    want = set(blocks) if (blocks is not None and P._homog) else None
    Irows, Jrows = P.ideal_dicts(want), P.lie_ideal_dicts(want)
    keys = sorted({P.key(m) for m in P.monos})
    if want is not None:
        keys = [b for b in keys if b in want]
    free = tors = exp = 0
    witnesses, B = [], {}
    for b in keys:
        blk = B[b] = Block(P, b, Irows, Jrows)
        f, t, orders = invariants(R, blk.K, blk.J)
        free, tors = free + f, tors + t
        for (c, _, _), o in zip(blk.K, orders):
            if 0 < o <= R.E - 3:
                exp = max(exp, o)
                witnesses.append((o, P.lyndon[blk.lj[c]]))
    P.inv = dict(free=free, tors=tors, exp=exp)
    res = {}
    for name, x in (tests or {}).items():
        cx = P.coords(x)
        delta, order = True, 0
        for b, blk in B.items():
            v = cx[blk.lj]
            if v.any():
                delta &= bool(reduce_rows(R, blk.K, v[None, :])[0])
                order = max(order, order_mod(R, blk.J, v))
        res[name] = dict(delta=delta, gamma_order=order)
    if verbose:
        print("n=%d gens=%d T=%d Lyndon=%d blocks=%s I=%d J=%d | delta/gamma: free rank %d, torsion p^%d, exponent p^%d"
              % (P.n, P.k, len(P.monos), len(P.basis), keys, len(Irows), len(Jrows), free, tors, exp), flush=True)
        for name, r in res.items():
            print("  %-12s in delta_%d: %s ; order mod gamma_%d: p^%s" % (name, P.n, r["delta"], P.n, r["gamma_order"]))
    return witnesses, res
