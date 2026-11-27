#!/usr/bin/env python3
"""MATH-474 (wiki 891 Sec. 23): chains of DEPTH c -- the mixed model mod 3^(c+1), uniform in k.

Depth of a chain (A, K_3 >= K_9 >= ... >= K_{3^k}), 3K_e <= K_{3e}: the least c >= 1 with 3^c K_3 <= K_{3^k}
(always c <= k-1; c = 1: elementary, Sec. 15.2).  Prop. 23.1: if the depth is <= c <= k-1, every sigma in Sigma
(model mod 3^k) is divisible by 3^(k-c-1), and R = 0 on Lambda x Sigma mod 3^k  <=>  R = 0 mod 3^(c+1) on the
depth-c MIXED model: modulus 3^(c+1), type cut at 3^(c+1), every condition of index level (3^k, d(i)) with the
lattice L(i) = K_{(3^k, d(i))} of that index (for c = 1: Prop. 22.4).

Modes (one summary line each; exit 1 iff a claim fails; with DROP the line is a control and exits 0):
  cross S K C N SEED [DROP]  N random chains mod 3^K on random capped (cut 3^K) types of length S; for those of depth
                             <= C: (i) all generators of Sigma divisible by 3^(K-C-1); (ii) verdict of the full model mod
                             3^K == verdict of the depth-C mixed model.  Reported by depth.
  mdeep S C PART NPARTS [DROP]  all capped (cut 3^(C+1)) types of length S (index = PART mod NPARTS), all A, all
                             profiles: monotone chains (one lattice per distinct value d >= 9) of lattices
                             3^C K_3 <= L <= K_3, L >= 3K_3 for d = 9, K_3 for d = 3;  R = 0 in the depth-C mixed model.
                             Covers every chain of depth <= C for every k >= C+1 (superset of the realizable profiles).
"""
import itertools, os, random, sys
from math import gcd
from functools import lru_cache
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
for p in ('case467', 'case471', 'case474'): sys.path.insert(0, os.path.join(HERE, '..', p))
from diag467 import Model, capped_types_k, hnf_key, subspaces, zbasis, kernel

class MixedC(Model):
    """the model mod 'mod' in which every condition uses the lattice ('L', i) of its level index (as t474.MixedModel)"""
    def __init__(self, d, mod, drop=()):
        super().__init__(d, mod, drop)
        s = self.s; idx = range(s); dr = self.drop; keys = []
        if 'B' not in dr: keys += [i for i in idx]
        if 'D2' not in dr: keys += [i for i, j in itertools.combinations(idx, 2)]
        if 'D1' not in dr: keys += [i for i in idx]
        assert len(keys) == len(self.V)
        self.V = [(vec, ('L', i)) for (vec, e), i in zip(self.V, keys)]
        fk = [(m if d[m] <= d[n] else n) for m, n in itertools.product(idx, idx)] + \
             [a for a, b in itertools.combinations(idx, 2)]
        assert len(fk) == len(self.F)
        self.F = [(fv, ('L', h), kind) for (fv, e, kind), h in zip(self.F, fk) if kind not in self.drop]

def cut(d, m):
    out = [min(d[0], m)]
    for a, b in zip(d, d[1:]): out.append(out[-1] * min(b // a, m))
    return out

def contains(K, V, s, mod):
    """lattice spanned by K (+ mod Z^s) contains V"""
    return hnf_key(list(K) + list(V), s, mod) == hnf_key(list(K), s, mod)

def depth(K, A, s, k):
    mod = 3 ** k
    K3 = [np.eye(s, dtype=np.int64)[h] * (3 if h in A else 1) for h in range(s)]
    for c in range(0, k + 1):
        if contains(K[mod], [3 ** c * v for v in K3], s, mod): return c
    return k

def rand_chain(s, k, A, rng, bias):
    """K_3 = Z^N + 3Z^A, K_{3e} = 3K_e + X~ (X a random subspace of K_e/3K_e); bias = probability of a full step"""
    subs_by_dim = {}
    K3 = [[(3 if h in A else 1) * int(h == g) for g in range(s)] for h in range(s)]
    K = {3: K3}; B = K3
    for j in range(2, k + 1):
        # random X: random rows over F_3 in the basis B of K_e (as integer combinations)
        r = s if rng.random() < bias else rng.randrange(s + 1)
        X = [[rng.randrange(3) for _ in range(s)] for _ in range(r)]
        g = [[3 * a for a in b] for b in B] + [[sum(x[t] * B[t][h] for t in range(s)) for h in range(s)] for x in X]
        B = zbasis(g, s); K[3 ** j] = B
    return {e: [np.array(b, dtype=np.int64) for b in K[e]] for e in K}

def sigma_gens(M, K):
    mod = M.mod; s = M.s
    sconds = list(M.J)
    for fv, eF, kind in M.F:
        gens = K[eF] if eF in K else [np.eye(s, dtype=np.int64)[h] for h in range(s)]
        for v in gens:
            r = {}
            for h in range(s):
                if v[h] % mod:
                    for kk, c in fv[h].items(): r[kk] = r.get(kk, 0) + int(v[h]) * c
            if r: sconds.append((r, mod))
    return kernel(sconds, M.NS, mod)

def cross_mode(S, k, C, N, seed, drop):
    assert C <= k - 1
    rng = random.Random(seed); types = capped_types_k(S, k)
    by = {}; ndiff = ndiv = 0; cache = {}
    for it in range(N):
        d = rng.choice(types); A = {h for h in range(S) if rng.random() < 0.5}
        K = rand_chain(S, k, A, rng, bias=0.6 if it % 2 else 0.2)
        c = depth(K, A, S, k)
        st = by.setdefault(c, [0, 0, 0, 0])            # chains, compared, full failing, different
        st[0] += 1
        if c > C: continue
        key = tuple(d)
        if key not in cache:
            dc = cut(d, 3 ** (C + 1))
            cache[key] = (Model(d, 3 ** k, drop), MixedC(dc, 3 ** (C + 1), drop))
        M, MM = cache[key]
        if not drop:
            Sg = sigma_gens(M, K)
            if any(int(x) % 3 ** (k - C - 1) for g in Sg for x in g): ndiv += 1
        a, _ = M.check(K)
        Kc = {e: [v % 3 ** (C + 1) for v in K[e]] for e in K}
        L = {('L', h): Kc[gcd(3 ** k, d[h])] for h in range(S)}
        b, _ = MM.check(L)
        st[1] += 1; st[2] += (not a); st[3] += (a != b); ndiff += (a != b)
    print("DEEPCROSS S", S, "k", k, "C", C, "N", N, "seed", seed, "drop", sorted(drop),
          "by depth {c: [chains, compared, full-failing, DIFFERENT]}", dict(sorted(by.items())),
          "sigma-not-divisible", ndiv, "DIFFERENT", ndiff, flush=True)
    return ndiff + ndiv

@lru_cache(None)
def lattice_table(s, c):
    """all lattices 3^c Z^s <= L <= Z^s (coordinates in the basis b of K_3) as HNF rows; containment; L >= 3Z^s"""
    m = 3 ** c; divs = [3 ** j for j in range(c + 1)]; seen = {}; Ls = []
    for diag in itertools.product(divs, repeat=s):
        free = [(r, q) for r in range(s) for q in range(r + 1, s)]
        for vals in itertools.product(*[range(diag[q]) for r, q in free]):
            H = [[0] * s for _ in range(s)]
            for r in range(s): H[r][r] = diag[r]
            for (r, q), v in zip(free, vals): H[r][q] = v
            key = hnf_key([np.array(h) for h in H], s, m)
            if key not in seen: seen[key] = len(Ls); Ls.append(key)
    n = len(Ls)
    sub = [[j for j in range(n) if hnf_key([np.array(x) for x in Ls[i] + Ls[j]], s, m) == Ls[i]] for i in range(n)]
    three = hnf_key([3 * np.eye(s, dtype=np.int64)[h] for h in range(s)], s, m)
    has3 = [hnf_key([np.array(x) for x in Ls[i]] + [np.array(x) for x in three], s, m) == Ls[i] for i in range(n)]
    full = seen[hnf_key([np.eye(s, dtype=np.int64)[h] for h in range(s)], s, m)]
    return Ls, sub, has3, full

def profiles(d, c):
    """monotone chains over the distinct values >= 9 of d (lattice indices into lattice_table)"""
    s = len(d); Ls, sub, has3, full = lattice_table(s, c)
    vals = sorted({x for x in d if x >= 9})
    def rec(j, prev):
        if j == len(vals): yield (); return
        cand = range(len(Ls)) if prev is None else sub[prev]
        for i in cand:
            if vals[j] == 9 and not has3[i]: continue
            for rest in rec(j + 1, i): yield (i,) + rest
    lev = [0 if d[h] == 3 else vals.index(d[h]) + 1 for h in range(s)]
    return lev, list(rec(0, None))

def to_gens(Hrows, A, s, c, mod):
    b = [3 if h in A else 1 for h in range(s)]
    g = [np.array([3 ** c * b[h] * int(h == q) for q in range(s)], dtype=np.int64) for h in range(s)]
    g += [np.array([row[q] * b[q] for q in range(s)], dtype=np.int64) for row in Hrows]
    return g

def mdeep_mode(S, C, part, nparts, drop):
    mod = 3 ** (C + 1); Ls, sub, has3, full = lattice_table(S, C)
    n = nfail = nt = nz = 0; ex = []
    for t_, d in enumerate(capped_types_k(S, C + 1)):
        if t_ % nparts != part: continue
        nt += 1; MM = MixedC(d, mod, drop); lev, prof = profiles(d, C)
        for r in range(S + 1):
            for A in itertools.combinations(range(S), r):
                A = set(A)
                G = [to_gens(Ls[i], A, S, C, mod) for i in range(len(Ls))]
                for pr in prof:
                    L = {('L', h): G[full if lev[h] == 0 else pr[lev[h] - 1]] for h in range(S)}
                    ok, nzs = MM.check(L); n += 1; nz += nzs
                    if not ok:
                        nfail += 1
                        if len(ex) < 3: ex.append((d, sorted(A), [Ls[i] for i in pr]))
    print("MDEEP S", S, "C", C, "part", part, "of", nparts, "drop", sorted(drop), "types", nt, "profiles", n,
          "sigma!=0", nz, "FAILING", nfail, ex, flush=True)
    return nfail

if __name__ == '__main__':
    m = sys.argv[1]
    if m == 'cross':
        S, k, C, N, seed = map(int, sys.argv[2:7])
        drop = sys.argv[7].split(',') if len(sys.argv) > 7 and sys.argv[7] else ()
        f = cross_mode(S, k, C, N, seed, drop); sys.exit(0 if drop else (1 if f else 0))
    if m == 'mdeep':
        S, C, part, nparts = map(int, sys.argv[2:6])
        drop = sys.argv[6].split(',') if len(sys.argv) > 6 and sys.argv[6] else ()
        f = mdeep_mode(S, C, part, nparts, drop); sys.exit(0 if drop else (1 if f else 0))
    if m == 'count':
        S, C = map(int, sys.argv[2:4]); tot = 0
        for d in capped_types_k(S, C + 1):
            lev, prof = profiles(d, C); tot += len(prof) * 2 ** S
        print("COUNT S", S, "C", C, "types", len(capped_types_k(S, C + 1)), "lattices", len(lattice_table(S, C)[0]),
              "configs", tot)
