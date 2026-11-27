#!/usr/bin/env python3
"""MATH-474 (wiki 891 Sec. 23): local certificates for ELEMENTARY chains in the mixed model mod 9 (Sec. 22.3).

R = sum_I R_I, I = index set of the variable (|I| <= 3); lambda-variables and sigma-forms of R_I have index set I.
Restriction to U ⊇ I:  Lambda|_U ⊆ Lambda_U(P),  Sigma|_U ⊆ Sigma_U(C)  with  P(h) = proj_U L(h),  C(h) = L(h) ∩ Z^U.
So R_I = 0 on Lambda_U(P) x Sigma_U(C)  ==>  R_I = 0 globally.

Modes:
  exact S [PART NPARTS] [DROP]  all elementary chains (all capped-9 types of length S, all A, all profiles): is R_I = 0
                                SEPARATELY for every I?  (necessary for any local certificate)
  cost S N SEED                 size of the full enumeration outside (T0), (T1) and measured CPU seconds per check
  local S [PART NPARTS] [DROP]  all LOCAL data on |U| = S: two monotone chains C_j ⊆ P_j of subspaces of K_3/3K_3
                                (indexed by the distinct values d >= 9 of U): R_I = 0 on Lambda(P) x Sigma(C) for all I
                                with I ⊆ U, |I| in {2, 3} for S <= 3 (|I| = 3 for S > 3; information only).
"""
import itertools, os, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
for p in ('case467', 'case471', 'case474'): sys.path.insert(0, os.path.join(HERE, '..', p))
from diag467 import Model, capped_types, subspaces, rref3, kernel

class LocalModel(Model):
    """mod 9; Lambda-conditions of index i use lattice ('P', i), Sigma-conditions of level index h use ('C', h)."""
    def __init__(self, d, drop=()):
        super().__init__(d, 9, drop)
        s = self.s; idx = range(s); dr = self.drop; keys = []
        if 'B' not in dr: keys += [i for i in idx]
        if 'D2' not in dr: keys += [i for i, j in itertools.combinations(idx, 2)]
        if 'D1' not in dr: keys += [i for i in idx]
        assert len(keys) == len(self.V)
        self.V = [(vec, ('P', i)) for (vec, e), i in zip(self.V, keys)]
        fk = [(m if d[m] <= d[n] else n) for m, n in itertools.product(idx, idx)] + \
             [a for a, b in itertools.combinations(idx, 2)]
        assert len(fk) == len(self.F)
        self.F = [(fv, ('C', h), kind) for (fv, e, kind), h in zip(self.F, fk) if kind not in self.drop]
        self.pI = {}
        for p, key in enumerate(self.P): self.pI.setdefault(frozenset(key[1:]), []).append(p)

    def gens(self, K):
        mod = self.mod; s = self.s
        lconds = []; Kp = {e: self.perp(K[e]) for e in K}
        for vec, e in self.V:
            for phi in Kp[e]:
                r = {}
                for h in range(s):
                    if phi[h] % mod:
                        for k, c in vec[h].items(): r[k] = r.get(k, 0) + int(phi[h]) * c
                if r: lconds.append((r, mod))
        Lg = kernel(lconds, self.NP, mod)
        sconds = list(self.J)
        for fv, eF, kind in self.F:
            for v in K[eF]:
                r = {}
                for h in range(s):
                    if v[h] % mod:
                        for k, c in fv[h].items(): r[k] = r.get(k, 0) + int(v[h]) * c
                if r: sconds.append((r, mod))
        Sg = kernel(sconds, self.NS, mod)
        return (np.array(Lg, dtype=np.int64) % mod if Lg else None, np.array(Sg, dtype=np.int64) % mod if Sg else None)

    def bad_I(self, K, sizes=None):
        """index sets I with R_I != 0 on Lambda x Sigma (and whether the total R != 0)"""
        Lm, Sm = self.gens(K)
        if Lm is None or Sm is None: return [], False
        mod = self.mod; bad = []
        RS = (self.RB @ Sm.T) % mod
        tot = (Lm @ RS) % mod
        for I, ps in self.pI.items():
            if sizes and len(I) not in sizes: continue
            if ((Lm[:, ps] @ RS[ps, :]) % mod).any(): bad.append(tuple(sorted(I)))
        return bad, bool(tot.any())

def lat(X, A, s):
    """3K_3 + X~ (X a tuple of F_3-rows in the basis b_h = e_h (N), 3 e_h (A)); 9Z^s implicit"""
    E = np.eye(s, dtype=np.int64)
    K3 = [E[q] * (3 if q in A else 1) for q in range(s)]
    return [3 * v for v in K3] + [np.array([x[q] * (3 if q in A else 1) for q in range(s)], dtype=np.int64) for x in X]

def levels(d):
    vals = sorted({x for x in d if x >= 9})
    return len(vals), [0 if d[h] == 3 else vals.index(d[h]) + 1 for h in range(len(d))]

def inside(Y, X, s): return rref3(list(X) + list(Y), s) == X

def chains(subs, t, s, X=None):
    if t == 0: yield (); return
    for Y in subs:
        if X is None or inside(Y, X, s):
            for rest in chains(subs, t - 1, s, Y): yield (Y,) + rest

def full(s): return tuple(tuple(int(i == j) for j in range(s)) for i in range(s))

def exact_mode(S, part, nparts, drop):
    subs = subspaces(S); n = nbadI = nbad = 0; hist = {}; ex = []
    for t_, d in enumerate(capped_types(S, 9)):
        if t_ % nparts != part: continue
        M = LocalModel(d, drop); t, lev = levels(d); allch = list(chains(subs, t, S))
        for r in range(S + 1):
            for A in itertools.combinations(range(S), r):
                A = set(A)
                for ch in allch:
                    L = {}
                    for h in range(S):
                        X = full(S) if lev[h] == 0 else ch[lev[h] - 1]
                        L[('P', h)] = L[('C', h)] = lat(X, A, S)
                    bad, tot = M.bad_I(L); n += 1
                    nbad += tot; nbadI += bool(bad)
                    for I in bad: hist[len(I)] = hist.get(len(I), 0) + 1
                    if bad and not tot and len(ex) < 3: ex.append((d, sorted(A), ch, bad))
    print("EXACT S", S, "part", part, "of", nparts, "drop", sorted(drop), "chains", n, "R!=0", nbad,
          "some R_I!=0", nbadI, "by |I|", hist, "examples(R=0 but R_I!=0)", ex, flush=True)
    return nbad

def local_mode(S, part, nparts, drop):
    SIZES = {2, 3} if S <= 3 else {3}
    subs = subspaces(S); n = nbad = 0; hist = {}; ex = []
    pairs = {}
    for t_, d in enumerate(capped_types(S, 9)):
        if t_ % nparts != part: continue
        M = LocalModel(d, drop); t, lev = levels(d)
        Pch = list(chains(subs, t, S))
        for r in range(S + 1):
            for A in itertools.combinations(range(S), r):
                A = set(A)
                for P in Pch:
                    # C chain with C_j ⊆ P_j
                    def cch(j, prev):
                        if j == t: yield (); return
                        for Y in subs:
                            if inside(Y, P[j], S) and (prev is None or inside(Y, prev, S)):
                                for rest in cch(j + 1, Y): yield (Y,) + rest
                    for C in cch(0, None):
                        L = {}
                        for h in range(S):
                            if lev[h] == 0: L[('P', h)] = L[('C', h)] = lat(full(S), A, S); continue
                            L[('P', h)] = lat(P[lev[h] - 1], A, S); L[('C', h)] = lat(C[lev[h] - 1], A, S)
                        bad, tot = M.bad_I(L, sizes=SIZES); n += 1
                        if bad:
                            nbad += 1
                            key = (tuple(d), tuple(sorted(A)))
                            hist[key] = hist.get(key, 0) + 1
                            if len(ex) < 3: ex.append((d, sorted(A), P, C))
    print("LOCAL S", S, "part", part, "of", nparts, "drop", sorted(drop), "data", n, "FAILING", nbad,
          "failing (d,A)", len(hist), "examples", ex, flush=True)
    return nbad

def cost_mode(S, N, seed):
    """size of the full s = S mixed enumeration outside (T0), (T1) (chains = multichains of subspaces of F_3^S,
    counted by Gaussian binomials) and measured seconds per check of the mixed model on N random chains"""
    import random, time
    from functools import lru_cache
    from t474 import MixedModel
    from t1471 import T1
    def gb(n, k, q=3):
        if k < 0 or k > n: return 0
        a = b = 1
        for i in range(k): a *= q ** (n - i) - 1; b *= q ** (i + 1) - 1
        return a // b
    @lru_cache(None)
    def mch(n, t): return 1 if t == 0 else sum(gb(n, a) * mch(a, t - 1) for a in range(n + 1))
    def T0(d, A): return not any(d[n] >= 9 * d[a] for a in A for n in range(len(d)) if n not in A)
    rng = random.Random(seed); subs = subspaces(S); openp = []; byt = {}
    for d in capped_types(S, 9):
        t, lev = levels(d)
        for r in range(S + 1):
            for A in itertools.combinations(range(S), r):
                if T0(d, set(A)) or T1(d, set(A)): continue
                openp.append((d, set(A), t)); byt.setdefault(t, [0, 0]); byt[t][0] += 1; byt[t][1] += mch(S, t)
    tot = sum(v[1] for v in byt.values())
    secs = 0.0; models = {}
    for _ in range(N):
        d, A, t = rng.choice(openp); t, lev = levels(d)
        X = rng.choice(subs); ch = []
        for j in range(t):
            ch.append(X)
            X = rref3([[sum(rng.randrange(3) * x[q] for x in X) % 3 for q in range(S)]
                       for _ in range(rng.randrange(len(X) + 1))], S) if X else X
        if tuple(d) not in models: models[tuple(d)] = MixedModel(d)
        MM = models[tuple(d)]
        L = {('L', h): lat(full(S) if lev[h] == 0 else ch[lev[h] - 1], A, S) for h in range(S)}
        t0 = time.process_time(); MM.check(L); secs += time.process_time() - t0
    per = secs / N
    print("COST S", S, "open (d,A)", len(openp), "by t {t: [pairs, chains]}", dict(sorted(byt.items())),
          "chains", tot, "sec/check", round(per, 5), "core-hours", round(tot * per / 3600), flush=True)
    return 0

if __name__ == '__main__':
    m = sys.argv[1]; S = int(sys.argv[2])
    if m == 'cost': sys.exit(cost_mode(S, int(sys.argv[3]), int(sys.argv[4])))
    part, nparts = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (0, 1)
    drop = sys.argv[5].split(',') if len(sys.argv) > 5 and sys.argv[5] else ()
    f = {'exact': exact_mode, 'local': local_mode}[m](S, part, nparts, drop)
    sys.exit(0 if drop else (1 if f else 0))
