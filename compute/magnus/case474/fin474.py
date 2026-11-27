#!/usr/bin/env python3
"""MATH-474 (wiki 891 Sec. 23.9): elementary chains at s = 5 for the (d, A) whose poset P ⊔ C_{t-1} is of FINITE type.

Data (Sec. 21.1, Sec. 23.3): an elementary chain X_1 >= ... >= X_t (subspaces of K_3/3K_3 = F_3^s, basis b_h) is a
representation of P ⊔ C_{t-1}: S = F_3^s / X_t (columns c_h = images of b_h), flag H_j = X_j / X_t (j < t);
conversely X_j = {v : sum v_h c_h in H_j} (H_t = 0).  Legal moves: add column g to column h iff g, h are in the same
point or point(g) -> point(h) (tits475.related); scale a column by 2; any change of rows preserving the flag.
Dimension vector (Drozd--Kubichka): (r = dim S; number of columns per point; x_j = dim H_j/H_{j+1}).
Tits form Q = r^2 + sum x_p^2 + sum_{p,q comparable} x_p x_q + sum x_j^2 + sum_{i<j} x_i x_j - r (sum x_p + sum x_j).
[DK04, Thm 1.4]: if P ⊔ C is of finite type, the indecomposables are exactly the positive roots (Q = 1), one per root,
End = F_3.  Here a representative of each root is FOUND by random search and certified by dim End = 1 (computed);
roots whose indecomposable does not have S spanned by its columns could not occur; any such would be reported as
missing (at s = 4, 5: none).

Modes:
  catalog S [PART NPARTS]   for every finite-type open (d, A) of length S: roots, representatives, failures
  count S T [MAXCH [PART NPARTS]]       ORBIT check (independent of the theory): all chains for every finite-type (d, A) with
                            t <= T (signatures deduplicated), orbits under the legal moves by union-find, grouped by
                            (r, x_C); claim: number of orbits == number of multisets of catalogue roots with exactly
                            m_p columns at every point, for every dimension vector.
  check S PART NPARTS [DROP]  R = 0 in the mixed model mod 9 on every direct sum of <= 3 catalogue objects with
                            exactly S columns (sums of >= 4 objects reduce to s <= 4: Prop. 13.3 and Thm 22.6).
"""
import itertools, os, random, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
for p in ('case467', 'case471', 'case474', 'case475'): sys.path.insert(0, os.path.join(HERE, '..', p))
from diag467 import capped_types, subspaces, rref3
from t1471 import T1
from tits475 import points, related

# ------------------------------------------------------------------ F_3 linear algebra
def rref(rows, n):
    return [list(r) for r in rref3([[x % 3 for x in r] for r in rows], n)] if rows else []

def nullspace(M, n):
    """basis of {x in F_3^n : M x = 0}"""
    R = rref(M, n); piv = []
    for r in R: piv.append(next(i for i, x in enumerate(r) if x))
    free = [j for j in range(n) if j not in piv]; out = []
    for f in free:
        x = [0] * n; x[f] = 1
        for r, p in zip(R, piv): x[p] = (-r[f]) % 3
        out.append(x)
    return out

def T0(d, A): return not any(d[n] >= 9 * d[a] for a in A for n in range(len(d)) if n not in A)

def levels(d):
    vals = sorted({x for x in d if x >= 9})
    return len(vals), [0 if d[h] == 3 else vals.index(d[h]) + 1 for h in range(len(d))]

# ------------------------------------------------------------------ posets and Kleiner's criterion
def poset(d, A):
    P = points(d, A)                       # [(value, class, mult)]
    pt = [next(i for i, p in enumerate(P) if p[0] == d[h] and p[1] == ('A' if h in A else 'N')) for h in range(len(d))]
    rel = {(i, j) for i in range(len(P)) for j in range(len(P)) if i != j and related(P[i], P[j])}
    return P, pt, rel

def comparable(rel, i, j): return (i, j) in rel or (j, i) in rel

def finite_type(P, rel, m):
    """Kleiner: no (1,1,1,1), (2,2,2), (1,3,3), (1,2,5), (N,4) in P ⊔ C_m (P has width <= 2, the chain is apart)"""
    n = len(P)
    chains = [c for r in range(1, n + 1) for c in itertools.combinations(range(n), r)
              if all(comparable(rel, a, b) for a, b in itertools.combinations(c, 2))]
    pairs = set()
    for a in chains:
        for b in chains:
            if not set(a) & set(b) and all(not comparable(rel, x, y) for x in a for y in b):
                pairs.add(tuple(sorted((len(a), len(b)))))
    for p1, p2 in pairs:
        for c in ((2, 2, 2), (1, 3, 3), (1, 2, 5)):
            for q in set(itertools.permutations(c)):
                if q[0] <= p1 and q[1] <= p2 and q[2] <= m: return False
    # width of P is <= 2 here, so (1,1,1,1) cannot occur; (N, 4) needs N inside P and m >= 4
    if m >= 4:
        def lt(i, j): return (i, j) in rel and (j, i) not in rel          # i -> j
        for a, b, c, e in itertools.permutations(range(n), 4):
            if lt(a, b) and lt(c, b) and lt(c, e) and not comparable(rel, a, c) and not comparable(rel, a, e) \
               and not comparable(rel, b, e): return False
    return True

def open_pairs(S):
    for d in capped_types(S, 9):
        t, lev = levels(d)
        for r in range(S + 1):
            for A in itertools.combinations(range(S), r):
                A = set(A)
                if T0(d, A) or T1(d, A): continue
                yield d, A, t

# ------------------------------------------------------------------ roots
def roots(P, rel, m, rmax):
    caps = [p[2] for p in P]; np_ = len(P); out = []
    comp = [(i, j) for i in range(np_) for j in range(i + 1, np_) if comparable(rel, i, j)]
    for xP in itertools.product(*[range(c + 1) for c in caps]):
        sP = sum(xP)
        if sP == 0: continue
        for r in range(0, min(rmax, sP) + 1):
            for xC in itertools.product(range(r + 1), repeat=m):
                sC = sum(xC)
                if sC > r: continue
                q = r * r + sum(x * x for x in xP) + sum(xP[i] * xP[j] for i, j in comp)
                q += sum(x * x for x in xC) + sum(xC[i] * xC[j] for i in range(m) for j in range(i + 1, m))
                q -= r * (sP + sC)
                if q == 1: out.append((r, tuple(xP), tuple(xC)))
    return out

# ------------------------------------------------------------------ representations
def end_dim(C, cols_pt, flag, rel, r):
    """dim of {(phi, T) : phi C = C T, phi H_j <= H_j, T in the incidence pattern}; C: r x n (list of columns)"""
    n = len(cols_pt)
    allowed = [(g, h) for g in range(n) for h in range(n)
               if cols_pt[g] == cols_pt[h] or (cols_pt[g], cols_pt[h]) in rel]
    nphi = r * r; nv = nphi + len(allowed); tidx = {gh: nphi + k for k, gh in enumerate(allowed)}
    eqs = []
    for a in range(r):                       # (phi C)_{a h} - (C T)_{a h} = 0
        for h in range(n):
            row = [0] * nv
            for b in range(r): row[a * r + b] = (row[a * r + b] + C[h][b]) % 3
            for g in range(n):
                if (g, h) in tidx: row[tidx[g, h]] = (row[tidx[g, h]] - C[g][a]) % 3
            eqs.append(row)
    for H in flag:                           # phi H <= H: ann(H) . phi . h = 0
        ann = nullspace(H, r) if H else [[int(i == j) for j in range(r)] for i in range(r)]
        for hv in H:
            for f in ann:
                row = [0] * nv
                for a in range(r):
                    for b in range(r): row[a * r + b] = (row[a * r + b] + f[a] * hv[b]) % 3
                eqs.append(row)
    return len(nullspace(eqs, nv)) if eqs else nv

def rand_rep(root, P, rng):
    r, xP, xC = root
    cols_pt = [p for p in range(len(P)) for _ in range(xP[p])]
    C = [[rng.randrange(3) for _ in range(r)] for _ in cols_pt]
    # flag H_1 >= ... >= H_m with dim H_j / H_{j+1} = xC[j-1]
    N = sum(xC); B = [[rng.randrange(3) for _ in range(r)] for _ in range(N)]
    flag = []; tot = N
    for j in range(len(xC)):
        flag.append(rref(B[:tot], r)); tot -= xC[j]
    return C, cols_pt, flag

def valid(C, flag, root, r):
    """columns span S; flag dims as prescribed"""
    if r and len(rref(C, r)) != r: return False
    tot = sum(root[2])
    for j, H in enumerate(flag):
        if len(H) != tot: return False
        tot -= root[2][j]
    return True

def representative(root, P, rel, rng, tries=3000):
    r = root[0]
    if r == 0:                                 # trivial object: one zero column (Q = 1 forces a single column)
        cols_pt = [p for p in range(len(P)) for _ in range(root[1][p])]
        return ([[]] * len(cols_pt), cols_pt, [[] for _ in root[2]]) if len(cols_pt) == 1 and not sum(root[2]) else None
    for _ in range(tries):
        C, cp, flag = rand_rep(root, P, rng)
        if valid(C, flag, root, r) and end_dim(C, cp, flag, rel, r) == 1: return C, cp, flag
    return None

def relations(C, H, r, n):
    """{v in F_3^n : sum v_h c_h in span(H)}"""
    if r == 0: return [[int(i == j) for j in range(n)] for i in range(n)]
    M = [[C[h][a] for h in range(n)] + [hv[a] for hv in H] for a in range(r)]
    K = nullspace(M, n + len(H))
    return rref([k[:n] for k in K], n)

_cat = {}
def catalog_for(d, A, t, seed=1):
    P, pt, rel = poset(d, A); m = t - 1
    key = (tuple((p[1], p[2]) for p in P), tuple(sorted(rel)), m)
    if key not in _cat:
        rng = random.Random(seed)
        R = roots(P, rel, m, len(d)); objs = []; miss = []
        for root in R:
            rep = representative(root, P, rel, rng)
            (objs if rep else miss).append((root, rep))
        _cat[key] = (objs, miss)
    return _cat[key], P, pt, rel

# ------------------------------------------------------------------ direct sums
def multisets(objs, mult, maxparts):
    """multisets of catalogue objects (indices) with exactly mult[p] columns at every point, <= maxparts summands"""
    npts = len(mult)
    def rec(start, rem, parts):
        if all(x == 0 for x in rem): yield list(parts); return
        if len(parts) == maxparts: return
        for i in range(start, len(objs)):
            xP = objs[i][0][1]
            if all(x <= y for x, y in zip(xP, rem)):
                parts.append(i)
                yield from rec(i, [y - x for x, y in zip(xP, rem)], parts)
                parts.pop()
    yield from rec(0, list(mult), [])

def assemble(parts, objs, pt, t, s):
    """block-diagonal chain X_1 >= ... >= X_t on F_3^s for the direct sum (indices of each point used in order)"""
    free = {}
    for h in range(s): free.setdefault(pt[h], []).append(h)
    X = [[] for _ in range(t)]
    for i in parts:
        root, (C, cp, flag) = objs[i]; r = root[0]; n = len(cp)
        idx = [free[p].pop(0) for p in cp]
        for j in range(t):
            H = flag[j] if j < t - 1 else []
            for v in relations(C, H, r, n):
                w = [0] * s
                for a, h in enumerate(idx): w[h] = v[a]
                X[j].append(w)
    return [tuple(tuple(r) for r in rref(Xj, s)) for Xj in X]

# ------------------------------------------------------------------ modes
def catalog_mode(S, part, nparts):
    n = nf = 0; nobj = nmiss = 0; mx = 0; seen = set()
    for i, (d, A, t) in enumerate(open_pairs(S)):
        if i % nparts != part: continue
        P, pt, rel = poset(d, A)
        if not finite_type(P, rel, t - 1): continue
        n += 1
        (objs, miss), _, _, _ = catalog_for(d, A, t)
        key = (tuple((p[1], p[2]) for p in P), tuple(sorted(rel)), t - 1)
        if key in seen: continue
        seen.add(key); nobj += len(objs); nmiss += len(miss)
        mx = max([mx] + [sum(o[0][1]) for o in objs])
        if miss: print("  MISS", d, sorted(A), [m_[0] for m_ in miss], flush=True)
    print("CATALOG S", S, "part", part, "of", nparts, "finite (d,A)", n, "signatures", len(seen),
          "objects", nobj, "roots without a spanned End=1 representative", nmiss, "max columns", mx, flush=True)
    return 0

def all_chains(s, t, subs):
    def inside(Y, X): return rref3(list(X) + list(Y), s) == X
    def rec(j, X):
        if j == t: yield (); return
        for Y in subs:
            if X is None or inside(Y, X):
                for rest in rec(j + 1, Y): yield (Y,) + rest
    return list(rec(0, None))

def count_mode(S, T, maxch, part=0, nparts=1):
    subs = subspaces(S); done = set(); nsig = bad = 0; norb = 0; isig = -1
    chains_by_t = {}
    for d, A, t in open_pairs(S):
        if t > T: continue
        P, pt, rel = poset(d, A)
        if not finite_type(P, rel, t - 1): continue
        key = (tuple((p[1], p[2]) for p in P), tuple(sorted(rel)), t - 1, tuple(pt))
        if key in done: continue
        done.add(key); isig += 1
        if isig % nparts != part: continue
        if t not in chains_by_t: chains_by_t[t] = all_chains(S, t, subs)
        ch = chains_by_t[t]
        if len(ch) > maxch: continue
        nsig += 1
        pos = {c: i for i, c in enumerate(ch)}; parent = list(range(len(ch)))
        def find(x):
            while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
            return x
        gens = []
        for g in range(S):
            for h in range(S):
                if g != h and (pt[g] == pt[h] or (pt[g], pt[h]) in rel):
                    N = [[int(i == j) for j in range(S)] for i in range(S)]; N[h][g] = 1; gens.append(N)
            N = [[int(i == j) for j in range(S)] for i in range(S)]; N[g][g] = 2; gens.append(N)
        for i, c in enumerate(ch):
            for N in gens:
                c2 = tuple(rref3([[sum(v[a] * N[a][b] for a in range(S)) % 3 for b in range(S)] for v in X], S) for X in c)
                a, b = find(i), find(pos[c2])
                if a != b: parent[a] = b
        orb = {}
        for i, c in enumerate(ch):
            if find(i) == i:
                dimv = (S - len(c[-1]), tuple(len(c[j]) - len(c[j + 1]) for j in range(t - 1)))
                orb[dimv] = orb.get(dimv, 0) + 1
        (objs, miss), _, _, _ = catalog_for(d, A, t)
        mult = [p[2] for p in P]; pred = {}
        for ms in multisets(objs, mult, 99):
            r = sum(objs[i][0][0] for i in ms)
            xC = tuple(sum(objs[i][0][2][j] for i in ms) for j in range(t - 1))
            pred[(r, xC)] = pred.get((r, xC), 0) + 1
        ok = orb == pred; bad += (not ok); norb += sum(orb.values())
        if not ok: print("  MISMATCH", d, sorted(A), "orbits", sum(orb.values()), "predicted", sum(pred.values()), flush=True)
    print("COUNT S", S, "t<=", T, "part", part, "of", nparts, "signatures", nsig, "orbits", norb, "MISMATCH", bad, flush=True)
    return bad

def check_mode(S, part, nparts, drop):
    from t474 import MixedModel
    from loc474 import lat
    n = nfail = npairs = nmiss = 0; ex = []; models = {}
    for i, (d, A, t) in enumerate(open_pairs(S)):
        if i % nparts != part: continue
        P, pt, rel = poset(d, A)
        if not finite_type(P, rel, t - 1): continue
        npairs += 1
        (objs, miss), _, _, _ = catalog_for(d, A, t); nmiss += len(miss)
        t_, lev = levels(d); mult = [p[2] for p in P]
        if tuple(d) not in models: models[tuple(d)] = MixedModel(d, drop)
        MM = models[tuple(d)]
        full = tuple(tuple(int(a == b) for b in range(S)) for a in range(S))
        for ms in multisets(objs, mult, 3):
            X = assemble(ms, objs, pt, t, S)
            L = {('L', h): lat(full if lev[h] == 0 else X[lev[h] - 1], A, S) for h in range(S)}
            ok, _ = MM.check(L); n += 1
            if not ok:
                nfail += 1
                if len(ex) < 3: ex.append((d, sorted(A), [objs[j][0] for j in ms]))
    print("FINCHECK S", S, "part", part, "of", nparts, "drop", sorted(drop), "finite (d,A)", npairs,
          "missing roots", nmiss, "configurations", n, "FAILING", nfail, ex, flush=True)
    return nfail + nmiss

if __name__ == '__main__':
    m = sys.argv[1]; S = int(sys.argv[2])
    if m == 'catalog':
        part, nparts = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (0, 1)
        sys.exit(catalog_mode(S, part, nparts))
    if m == 'count':
        a = [int(x) for x in sys.argv[3:]] + [10 ** 9, 0, 1][len(sys.argv) - 4:]
        sys.exit(1 if count_mode(S, a[0], a[1], a[2], a[3]) else 0)
    if m == 'check':
        part, nparts = int(sys.argv[3]), int(sys.argv[4])
        drop = sys.argv[5].split(',') if len(sys.argv) > 5 and sys.argv[5] else ()
        f = check_mode(S, part, nparts, drop); sys.exit(0 if drop else (1 if f else 0))
