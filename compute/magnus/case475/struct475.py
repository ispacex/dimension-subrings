#!/usr/bin/env python3
"""MATH-475 (wiki 891 Sec. 21): block sizes of elementary chains mod 27, checked on orbits (no model, no theory).

For (d, A) an elementary chain mod 27 is a pair X_9 >= X_27 of subspaces of F_3^s (case473/s5_473.py).  K_9 and K_27
are block-diagonal for a partition of {1..s} iff X_9 and X_27 are closed under the coordinate projections P_B of its
blocks; the closed subsets form a Boolean algebra, so there is a finest such partition ("atoms").  For each orbit
under the changes of basis of Q_ab fixing A (gen_mats of case467, acting by induced27 as in s5_473) we compute
  b(orbit) = min over members of (largest atom)
-- the smallest block size reachable by legal moves.  The Tits-form prediction (tits475.maxcols, via Drozd's theorem)
is that max over orbits of b equals the largest number of columns of an indecomposable.

Modes (one line each; exit status 1 iff a claim fails):
  sig S [CLASSES]       list signatures (tits475.signature) of all capped types of length S x all A, with the shape
                        class (s5_473.shape) and the Tits prediction; one representative (d, A) per signature
  orbit TYPE A          histogram of b over the orbits of (TYPE, A); prints the Tits prediction; claim: max b equals
                        the prediction (both directions: no larger blocks needed, and the predicted size occurs)
"""
import itertools, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
for sub in ('case467', 'case471', 'case473'): sys.path.insert(0, os.path.join(HERE, '..', sub))
from diag467 import capped_types_k, gen_mats
from s5_473 import Space, induced27, shape, shape_name, MOD
from t1471 import T1
from t0471 import T0
import tits475

def cls_name(d, A):
    if T0(d, A): return 'T0'
    if T1(d, A): return 'T1'
    return shape_name(shape(d, A))

def vec_code(v):
    c = 0
    for x in v: c = 3 * c + (x % 3)
    return c

def span_codes(X, s):
    out = set()
    for coef in itertools.product(range(3), repeat=len(X)):
        out.add(vec_code([sum(c * r[i] for c, r in zip(coef, X)) % 3 for i in range(s)]))
    return out

def closed_family(sp):
    """per subspace: bitmask over subsets B (as ints 0..2^s-1) of those with P_B(X) <= X"""
    s = sp.s; fam = []
    for X in sp.subs:
        V = span_codes(X, s); m = 0
        for B in range(1 << s):
            if all(vec_code([r[i] if (B >> i) & 1 else 0 for i in range(s)]) in V for r in X): m |= 1 << B
        fam.append(m)
    return fam

_atom_memo = {}
def max_atom(fm, s):
    if fm in _atom_memo: return _atom_memo[fm]
    closed = [B for B in range(1 << s) if (fm >> B) & 1]
    best = 0
    for h in range(s):
        a = (1 << s) - 1
        for B in closed:
            if (B >> h) & 1: a &= B
        best = max(best, bin(a).count('1'))
    _atom_memo[fm] = best
    return best

def orbit_mode(d, A):
    t0 = time.time(); s = len(d); sp = Space(s); fam = closed_family(sp)
    Ts = {tuple(map(tuple, induced27(Ci, A, s))) for Ci in gen_mats(d, A, MOD)}
    perms = [sp.perm(T) for T in Ts]
    n = len(sp.pairs); parent = list(range(n))
    def find(x):
        while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
        return x
    for t, (i, j) in enumerate(sp.pairs):
        for P in perms:
            u = sp.pidx[(P[i], P[j])]; a, b = find(t), find(u)
            if a != b:
                if a < b: parent[b] = a
                else: parent[a] = b
    best = {}
    for t, (i, j) in enumerate(sp.pairs):
        r = find(t); b = max_atom(fam[i] & fam[j], s)
        if r not in best or b < best[r]: best[r] = b
    hist = {}
    for b in best.values(): hist[b] = hist.get(b, 0) + 1
    pred = tits475.maxcols(d, A); mx = max(hist)
    ok = (mx == pred)
    print("STRUCT type", ",".join(map(str, d)), "A", ",".join(map(str, sorted(A))) or '-', "class", cls_name(d, A),
          "orbits", len(best), "hist[b:orbits]", " ".join("%d:%d" % kv for kv in sorted(hist.items())),
          "maxb", mx, "tits", pred, "sec", round(time.time() - t0, 1), "OK" if ok else "MISMATCH", flush=True)
    return 0 if ok else 1

def sig_mode(S, classes):
    seen = {}
    for d in capped_types_k(S, 3):
        for r in range(S + 1):
            for A in itertools.combinations(range(S), r):
                A = set(A); c = cls_name(d, A)
                if classes and c not in classes: continue
                k = tits475.signature(d, A)
                if k not in seen: seen[k] = (d, A, c)
    for k, (d, A, c) in seen.items():
        print("SIG", ",".join(map(str, d)), ",".join(map(str, sorted(A))) or '-', c, tits475.maxcols(d, A))
    print("SIGS", S, "classes", ",".join(classes) or 'all', "signatures", len(seen), flush=True)

if __name__ == '__main__':
    m = sys.argv[1]
    if m == 'sig': sig_mode(int(sys.argv[2]), sys.argv[3].split(',') if len(sys.argv) > 3 else []); sys.exit(0)
    if m == 'orbit':
        d = [int(a) for a in sys.argv[2].split(',')]; A = {int(a) for a in sys.argv[3].split(',') if a and a != '-'}
        sys.exit(orbit_mode(d, A))
