#!/usr/bin/env python3
"""MATH-472 (wiki 891 Sec. 18): exhaustive check of NON-elementary chains mod 27 (gamma_4 = C_27) on capped types
WITHOUT the invariant 9, for one type and all (or given) A, with a partial orbit reduction.

Parametrisation (Sec. 18.4).  K = K_27 with 9K_3 <= K <= K_3 is a subgroup H = K/9K_3 of K_3/9K_3 = (Z/9)^s (basis
b_h = e_h for h in N, 3e_h for h in A).  H is determined by
  Y = { y in F_3^s : 3y~ in H }  >=  X = H mod 3,
and lifts x~_j = x_j + 3c_j of an F_3-basis x_j of X, c_j in F_3^s / Y.  So H <-> (Y >= X, c), and there are
sum 3^(dim X (s - dim Y)) of them (3 622 259 at s = 5).  Elementary <=> Y = F_3^s (closed by Thm 15.3; skipped).
Orbit reduction: changes of basis fixing A (case467 gen_mats) act on (Z/9)^s by matrices whose reduction mod 3 is
case473.induced27; the pair (Y, X) moves by that F_3-matrix.  So it suffices to check, for ONE representative (Y, X)
of each orbit of pairs (case473.orbit_reps, the same code as MATH-473), ALL lifts c (no reduction by the stabiliser).

Modes:
  run TYPE [A|all] [DROP]   all A (default) or one A (comma list; '-' = empty): per A the number of pair orbits, of
                            non-elementary chains checked and of failures; summary line S5NE ... FAILING n.
                            With DROP (D2 or Kt): the model without that condition (control; exit 0).
  full TYPE A               control of the orbit reduction: ALL subgroups H (no orbits) for one A
"""
import itertools, os, sys, time
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
for sub in ('case467', 'case471', 'case473'): sys.path.insert(0, os.path.join(HERE, '..', sub))
from diag467 import Model
from s5_473 import Space, orbit_reps

MOD = 27

def chain_K27(Y, X, c, A, s):
    """K_27 generators in Z^s: lifts x_j + 3c_j, 3y (y in Y), and 9K_3"""
    sc = lambda h: 3 if h in A else 1
    E = np.eye(s, dtype=np.int64)
    gens = []
    for x, cj in zip(X, c):
        gens.append(np.array([sc(h) * (x[h] + 3 * cj[h]) for h in range(s)], dtype=np.int64))
    for y in Y:
        gens.append(np.array([sc(h) * 3 * y[h] for h in range(s)], dtype=np.int64))
    gens += [9 * sc(h) * E[h] for h in range(s)]
    return gens

def lifts(Y, X, s):
    """all c = (c_j) with c_j in the complement of Y (non-pivot coordinates of the RREF of Y)"""
    piv = {next(i for i, a in enumerate(y) if a) for y in Y}
    free = [h for h in range(s) if h not in piv]
    vecs = []
    for coef in itertools.product(range(3), repeat=len(free)):
        v = [0] * s
        for h, a in zip(free, coef): v[h] = a
        vecs.append(v)
    return itertools.product(vecs, repeat=len(X)), len(vecs) ** len(X)

def K3(s, A):
    E = np.eye(s, dtype=np.int64)
    return [E[h] * (3 if h in A else 1) for h in range(s)]

def run_A(sp, M, d, A, reps=None):
    s = len(d)
    if reps is None: reps, _ = orbit_reps(sp, d, A)
    nchk = nfail = nsig = norb_ne = 0
    for t in reps:
        i, j = sp.pairs[t]
        Y, X = sp.subs[i], sp.subs[j]
        if len(Y) == s: continue           # elementary
        norb_ne += 1
        it, _ = lifts(Y, X, s)
        for c in it:
            ok, nz = M.check({3: K3(s, A), 27: chain_K27(Y, X, c, A, s)})
            nchk += 1; nsig += nz; nfail += (not ok)
    return len(reps), norb_ne, nchk, nsig, nfail

if __name__ == '__main__':
    mode = sys.argv[1]; d = [int(a) for a in sys.argv[2].split(',')]; s = len(d)
    assert 9 not in d
    t0 = time.time()
    if mode == 'run':
        rest = sys.argv[3:]
        if rest and rest[0] != 'all' and rest[0] not in ('D2', 'Kt', 'B', 'D1', 'J', 'Ko'):
            As = [set(int(a) for a in rest[0].split(',') if a not in ('', '-'))]; rest = rest[1:]
        else:
            As = [set(c) for r in range(s + 1) for c in itertools.combinations(range(s), r)]
            if rest and rest[0] == 'all': rest = rest[1:]
        drop = tuple(x for a in rest for x in a.split(',') if x)
        sp = Space(s); M = Model(d, MOD, drop)
        tot = [0, 0, 0, 0, 0]
        for A in As:
            ta = time.time()
            r = run_A(sp, M, d, A)
            print("  A", sorted(A), "pair-orbits", r[0], "non-elem", r[1], "chains", r[2], "sigma!=0", r[3],
                  "FAILING", r[4], "sec %.1f" % (time.time() - ta), flush=True)
            tot = [a + b for a, b in zip(tot, r)]
        print("S5NE type", ",".join(map(str, d)), "drop", sorted(drop), "A", len(As), "pair-orbits", tot[0],
              "non-elem-orbits", tot[1], "chains", tot[2], "sigma!=0", tot[3], "sec %.1f" % (time.time() - t0),
              "FAILING", tot[4], flush=True)
        sys.exit(0 if drop else (1 if tot[4] else 0))
    if mode == 'full':
        A = set(int(a) for a in sys.argv[3].split(',') if a not in ('', '-'))
        sp = Space(s); M = Model(d, MOD)
        reps = list(range(len(sp.pairs)))
        r = run_A(sp, M, d, A, reps)
        print("S5NEFULL type", ",".join(map(str, d)), "A", sorted(A), "pairs", r[0], "non-elem pairs", r[1],
              "chains", r[2], "sigma!=0", r[3], "sec %.1f" % (time.time() - t0), "FAILING", r[4], flush=True)
        sys.exit(1 if r[4] else 0)
