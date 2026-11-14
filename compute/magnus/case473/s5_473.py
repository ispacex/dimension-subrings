#!/usr/bin/env python3
"""MATH-473 (wiki 891 Sec. 17): exhaustive check of ELEMENTARY chains mod 27 (gamma_4 = C_27) at s = 5, on types
with the invariant 9, for the partitions A that violate (T1) -- the chains not covered by Thms 16.2 (T0) and 16.5 (T1),
nor by Thm 15.3 (no invariant 9).

Setting (wiki 891 Sec. 14.2, 15.2, 16.1).  An elementary chain mod 27 is (A, X_9 >= X_27) with X_e an F_3-subspace of
K_3/3K_3 (basis b_h = e_h for h in N, 3e_h for h in A) and K_e = 3K_3 + lift(X_e) (so 3K_3 <= K_27 <= K_9 <= K_3).
The changes of basis of Q_ab fixing A (generators gen_mats of case467, the same as in t0471/t1471 'orbits') fix K_3 and
3K_3, so they act on these chains through F_3-matrices T on K_3/3K_3 (x -> x T, x a row vector); D_5 is an invariant
of the group, and every member of an orbit is the chain of the same group in another adapted basis, so R = 0 has to be
checked on ONE member of each orbit (orbit reduction, as in Sec. 13.6, 14.4, 16.6).  The model is case467 Model
(Sec. 11.4/13.5, without (C)), mod 27, on the type capped at 27 (Sec. 13.5).

(T1) as in t1471.T1; its complement is classified by the shape (a, n) = (number of distinct d-values on A, on N) among
the incomparable pairs a in A, n in N, d(n) >= 9 d(a): '2A1N', '1A2N', '2A2N', ...  (T1) <=> a <= 1 and n <= 1.

Modes (one summary line per type; exit status 1 iff a claim fails):
  run TYPE [DROP] [all]  for every A violating (T1) (with 'all': for every A): all elementary chains, orbits under T,
                         R = 0 on the first member (in enumeration order) of each orbit.  Prints the orbit count, the
                         number of checked orbits and FAILING.  With DROP (D2 or Kt) the model without that condition
                         (control: must fail somewhere; then the exit status is 0 regardless).
  classify TYPE          per A: (T0), (T1) from t0471/t1471, and the independent shape classification; asserts that
                         (T1) <=> shape <= (1, 1) and (T0) <=> no incomparable pair.
  types S                capped (cut 27) types of length S containing the invariant 9
"""
import itertools, os, sys, time
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'case467')); sys.path.insert(0, os.path.join(HERE, '..', 'case471'))
from diag467 import Model, capped_types_k, subspaces, rref3, gen_mats
from t0471 import T0
from t1471 import T1

MOD = 27

def shape(d, A):
    s = len(d); N = [h for h in range(s) if h not in A]
    inc = [(a, n) for a in A for n in N if d[n] >= 9 * d[a]]
    return len({d[a] for a, n in inc}), len({d[n] for a, n in inc})

def shape_name(sh): return "%dA%dN" % sh

def induced27(Ci, A, s):
    """F_3-matrix of K -> Ci K on K_3/3K_3 (basis b_h), row-vector convention: coords(Ci v) = coords(v) T"""
    T = [[0] * s for _ in range(s)]
    for h in range(s):
        b = np.zeros(s, dtype=np.int64); b[h] = 3 if h in A else 1
        w = (Ci @ b) % MOD
        for g in range(s):
            if g in A:
                assert w[g] % 3 == 0, "generator does not fix K_3"
                T[h][g] = (int(w[g]) // 3) % 3
            else: T[h][g] = int(w[g]) % 3
    return T

class Space:
    """all subspaces of F_3^s, indexed; for each, the indices of its subspaces"""
    def __init__(self, s):
        self.s = s
        self.subs = subspaces(s)
        self.idx = {X: t for t, X in enumerate(self.subs)}
        small = {r: subspaces(r) for r in range(s + 1)}
        self.below = []
        for X in self.subs:
            r = len(X); out = []
            for Y in small[r]:     # Y in coordinates of the basis X
                Z = rref3([[sum(y[i] * X[i][c] for i in range(r)) % 3 for c in range(s)] for y in Y], s)
                out.append(self.idx[Z])
            assert len(set(out)) == len(out)
            self.below.append(out)
        self.pairs = [(i, j) for i in range(len(self.subs)) for j in self.below[i]]
        self.pidx = {p: t for t, p in enumerate(self.pairs)}

    def perm(self, T):
        s = self.s
        return [self.idx[rref3([[sum(row[h] * T[h][g] for h in range(s)) % 3 for g in range(s)] for row in X], s)]
                for X in self.subs]

def chain_K(X9, X27, A, s):
    E = np.eye(s, dtype=np.int64)
    K3 = [E[h] * (3 if h in A else 1) for h in range(s)]
    lift = lambda x: np.array([x[h] * (3 if h in A else 1) for h in range(s)], dtype=np.int64)
    return {3: K3, 9: [3 * v for v in K3] + [lift(x) for x in X9], 27: [3 * v for v in K3] + [lift(x) for x in X27]}

def orbit_reps(sp, d, A):
    """first member of each orbit of elementary chains (pairs X_9 >= X_27) under the induced generators"""
    s = sp.s
    Ts = {tuple(map(tuple, induced27(Ci, A, s))) for Ci in gen_mats(d, A, MOD)}
    I = tuple(tuple(int(i == j) for j in range(s)) for i in range(s))
    Ts.discard(I)
    perms = [sp.perm(T) for T in Ts]
    n = len(sp.pairs); parent = list(range(n))
    def find(x):
        while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
        return x
    pidx = sp.pidx
    for t, (i, j) in enumerate(sp.pairs):
        for P in perms:
            u = pidx[(P[i], P[j])]           # KeyError would mean containment is not preserved
            a, b = find(t), find(u)
            if a != b:
                if a < b: parent[b] = a
                else: parent[a] = b
    reps = sorted({find(t) for t in range(n)})
    return reps, len(perms)

def run_mode(d, drop, allA):
    t_start = time.time()
    s = len(d); sp = Space(s); M = Model(d, MOD, drop)
    nA = norb = nchk = nfail = nsig = 0; per = {}
    for r in range(s + 1):
        for A in itertools.combinations(range(s), r):
            A = set(A)
            if T1(d, A) and not allA: continue
            reps, ng = orbit_reps(sp, d, A)
            nA += 1; norb += len(reps); f = 0
            for t in reps:
                i, j = sp.pairs[t]
                ok, nz = M.check(chain_K(sp.subs[i], sp.subs[j], A, s))
                nchk += 1; nsig += nz; f += (not ok)
            nfail += f
            nm = shape_name(shape(d, A)) if not T1(d, A) else ('T0' if T0(d, A) else 'T1')
            c = per.setdefault(nm, [0, 0, 0]); c[0] += 1; c[1] += len(reps); c[2] += f
    cls = " ".join("%s:%d/%d/%d" % (k, *v) for k, v in sorted(per.items()))
    print("S5RUN type", ",".join(map(str, d)), "drop", sorted(drop), "A", nA, "pairs/A", len(sp.pairs), "orbits", norb,
          "checked", nchk, "sigma!=0", nsig, "classes[A/orbits/failing]", cls, "sec", round(time.time() - t_start, 1),
          "FAILING", nfail, flush=True)
    return nfail

def classify_mode(d):
    s = len(d); bad = 0; cnt = {}
    for r in range(s + 1):
        for A in itertools.combinations(range(s), r):
            A = set(A); sh = shape(d, A)
            t1 = sh[0] <= 1 and sh[1] <= 1; t0 = sh == (0, 0)
            bad += (t1 != T1(d, A)) + (t0 != T0(d, A))
            nm = 'T0' if t0 else ('T1' if t1 else shape_name(sh))
            cnt[nm] = cnt.get(nm, 0) + 1
    print("S5CLASS type", ",".join(map(str, d)), " ".join("%s:%d" % kv for kv in sorted(cnt.items())),
          "MISMATCH", bad, flush=True)
    return bad

def types_mode(S):
    for d in capped_types_k(S, 3):
        if 9 in d: print(",".join(map(str, d)))

if __name__ == '__main__':
    m = sys.argv[1]
    if m == 'types': types_mode(int(sys.argv[2])); sys.exit(0)
    d = [int(a) for a in sys.argv[2].split(',')]
    if m == 'classify': sys.exit(1 if classify_mode(d) else 0)
    if m == 'run':
        rest = sys.argv[3:]
        allA = 'all' in rest
        drop = tuple(x for a in rest if a != 'all' for x in a.split(',') if x)
        f = run_mode(d, drop, allA)
        sys.exit(0 if drop else (1 if f else 0))
