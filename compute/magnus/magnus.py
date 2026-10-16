"""Membership in D_n(G) for a finitely presented G through the truncated Magnus algebra.

Z[G]/Delta^n = T_{<n}(Z^k) / I_n, where x_i -> 1 + X_i, T_{<n} is the free associative ring on
X_1..X_k truncated at degree n, and I_n is spanned by m (mu(r) - 1) m2 for defining relators r
and monomials m, m2.  Lattices are taken modulo 2^E (Howell form from compute/dimsub.py,
imported read-only): NON-membership modulo 2^E proves non-membership; membership modulo 2^E is
only a necessary condition.
"""
import sys, itertools
sys.path.insert(0, __import__("os").path.join(__import__("os").path.dirname(__import__("os").path.abspath(__file__)), ".."))
import numpy as np
from dimsub import Ring, howell, reduce_rows


class Trunc:
    def __init__(self, k, n):
        self.k, self.n = k, n
        self.monos = [m for d in range(n) for m in itertools.product(range(k), repeat=d)]
        self.idx = {m: i for i, m in enumerate(self.monos)}

    def mul(self, a, b):
        out = {}
        for ma, ca in a.items():
            for mb, cb in b.items():
                if len(ma) + len(mb) < self.n:
                    m = ma + mb
                    out[m] = out.get(m, 0) + ca * cb
        return {m: c for m, c in out.items() if c}

    def one(self):
        return {(): 1}

    def gen(self, i):
        return {(): 1, (i,): 1}

    def inv(self, a):  # a = 1 + v
        mv = {m: -c for m, c in a.items() if m != ()}
        out, p = self.one(), self.one()
        for _ in range(1, self.n):
            p = self.mul(p, mv)
            for m, c in p.items():
                out[m] = out.get(m, 0) + c
        return {m: c for m, c in out.items() if c}

    def power(self, a, N):
        if N < 0:
            a, N = self.inv(a), -N
        out, base = self.one(), a
        while N:
            if N & 1:
                out = self.mul(out, base)
            base = self.mul(base, base)
            N >>= 1
        return out

    def comm(self, a, b):  # [a,b] = a^-1 b^-1 a b
        return self.mul(self.mul(self.inv(a), self.inv(b)), self.mul(a, b))

    def lnc(self, *xs):  # left-normed commutator
        c = xs[0]
        for x in xs[1:]:
            c = self.comm(c, x)
        return c

    def prod(self, *xs):
        out = self.one()
        for x in xs:
            out = self.mul(out, x)
        return out

    def minus1(self, a):
        d = dict(a)
        d[()] = d.get((), 0) - 1
        return {m: c for m, c in d.items() if c}

    def ideal_rows(self, rels, R):
        rows = []
        for r in rels:
            rho = self.minus1(r)
            if not rho:
                continue
            o = min(len(m) for m in rho)
            for t in range(self.n - o):
                for s in range(t + 1):
                    for m1 in itertools.product(range(self.k), repeat=s):
                        for m2 in itertools.product(range(self.k), repeat=t - s):
                            row = np.zeros(len(self.monos), dtype=np.int64)
                            for m, c in rho.items():
                                mm = m1 + m + m2
                                if len(mm) < self.n:
                                    j = self.idx[mm]
                                    row[j] = (row[j] + c) % R.D
                            if row.any():
                                rows.append(row)
        return np.array(rows)

    def vec(self, a, R):
        row = np.zeros(len(self.monos), dtype=np.int64)
        for m, c in self.minus1(a).items():
            row[self.idx[m]] = c % R.D
        return row
