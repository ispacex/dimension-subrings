#!/usr/bin/env python3
"""MATH-469 (wiki 891 Sec. 14): the chain K_9 >= K_27 has no normal form with bounded blocks.

Elementary configurations (wiki 891, Sec. 14.2).  U = 3M (M = L_2/27L_2) is a Z/9-module; t_a = 3y_a (a in A),
z_n = y_n (n in N).  An ELEMENTARY configuration has all t_a, z_n in the socle U[3]; we take
    S = F_3^n (a model of span(t, z) inside U[3]),  H = the first r coordinates = S cap 3U.
Then
    K_27 = { v : 3 | v_a (a in A), sum_a (v_a/3) t_a + sum_n v_n z_n = 0 in S },
    K_9  = { v : 3 | v_a,           same sum in S/H = 0 },                K_3 = Z^N + 3 Z^A .
On such data the basis changes of Lemma 13.1 act as the column operations of the preorder
    q -> p  ("column q may be added to column p")  iff  same class and d(q) >= d(p),  or  q in A, p in N, d(p) <= 3 d(q)
(all other elementary moves are multiplication by 3 of an element of order 3, i.e. trivial).

block-indecomposability criterion: a block decomposition after moves gives an idempotent pi of End(S, H) with
pi g = g E, E in the incidence algebra of the preorder (E = C D C^-1).  So if the algebra
    B = { pi in End(S,H) : exists E in Inc(preorder) with pi g = g E }
is LOCAL (every element nilpotent or invertible), the nonzero columns cannot be split into two blocks.

Modes:
  search TYPE A NDIM RDIM TRIES SEED   random search for configurations on TYPE whose B is local and all columns are
                                       needed ("reduced"); prints them
  check  FILE                          for each configuration in FILE (json lines): B local?, reduced?, and the
                                       modulo-27 model of diag467 (wiki 891 Sec. 13.5) on its chain (A, K_3, K_9, K_27)
"""
import itertools, json, random, sys, os
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'case467'))
from diag467 import Model, kernel, zbasis

P3 = 3

def addable(d, A, q, p):
    """column q may be added (with any F_3 coefficient) to column p on elementary data"""
    if q == p: return True
    qa, pa = q in A, p in A
    if qa == pa: return d[q] >= d[p]
    if qa and not pa: return d[p] <= 3 * d[q]
    return False

def nullspace_mod3(rows, ncols):
    """basis of {x in F_3^ncols : R x = 0}"""
    R = [list(r) for r in rows]
    piv = []; rk = 0
    for c in range(ncols):
        p = next((i for i in range(rk, len(R)) if R[i][c] % 3), None)
        if p is None: continue
        R[rk], R[p] = R[p], R[rk]
        inv = 1 if R[rk][c] % 3 == 1 else 2
        R[rk] = [(x * inv) % 3 for x in R[rk]]
        for i in range(len(R)):
            if i != rk and R[i][c] % 3:
                f = R[i][c]; R[i] = [(a - f * b) % 3 for a, b in zip(R[i], R[rk])]
        piv.append(c); rk += 1
    free = [c for c in range(ncols) if c not in piv]
    out = []
    for f in free:
        x = [0] * ncols; x[f] = 1
        for i, c in enumerate(piv): x[c] = (-R[i][f]) % 3
        out.append(x)
    return out

def rank3(rows, ncols):
    return ncols - len(nullspace_mod3(rows, ncols)) if rows else 0

def end_algebra(G, d, A, n, r):
    """G: n x s matrix over F_3 (column h = generator h).  Returns a basis of B (as n x n matrices)."""
    s = len(d)
    # unknowns: pi (n*n entries, with pi(H) <= H: pi[i][j] = 0 for i >= r, j < r) and E (allowed entries)
    pis = [(i, j) for i in range(n) for j in range(n) if not (i >= r and j < r)]
    Es = [(q, p) for q in range(s) for p in range(s) if addable(d, A, q, p)]
    nv = len(pis) + len(Es)
    rows = []
    for i in range(n):
        for p in range(s):
            # (pi G)[i][p] - (G E)[i][p] = sum_j pi[i][j] G[j][p] - sum_q G[i][q] E[q][p]
            row = [0] * nv
            for t, (a, b) in enumerate(pis):
                if a == i: row[t] = G[b][p] % 3
            for t, (q, pp) in enumerate(Es):
                if pp == p: row[len(pis) + t] = (-G[i][q]) % 3
            rows.append(row)
    sol = nullspace_mod3(rows, nv)
    mats = []
    for x in sol:
        Pm = np.zeros((n, n), dtype=np.int64)
        for t, (a, b) in enumerate(pis): Pm[a][b] = x[t]
        mats.append(Pm)
    # basis of the projection
    flat = [list(m.flatten()) for m in mats]
    basis = []; cur = []
    for m, f in zip(mats, flat):
        if rank3(cur + [f], n * n) > len(cur): cur.append(f); basis.append(m)
    return basis

def is_local(basis, n, limit=14):
    """every element of span(basis) over F_3 is nilpotent or invertible"""
    k = len(basis)
    if k > limit: return None
    I = np.eye(n, dtype=np.int64)
    for coeffs in itertools.product(range(3), repeat=k):
        if not any(coeffs): continue
        X = sum(c * b for c, b in zip(coeffs, basis)) % 3
        det = round(np.linalg.det(X)) % 3 if n else 1
        if det: continue
        # singular: must be nilpotent
        Y = X.copy()
        for _ in range(n): Y = (Y @ X) % 3
        if Y.any(): return False
    return True

def reduced(G, d, A):
    """no column lies in the span of the OTHER columns addable to it (so no column can be made zero by moves)"""
    s = len(d); n = len(G)
    for p in range(s):
        others = [[G[i][q] for i in range(n)] for q in range(s) if q != p and addable(d, A, q, p)]
        col = [G[i][p] for i in range(n)]
        if not any(col): return False
        if rank3(others + [col], n) == rank3(others, n): return False
    return True

def lattices(G, d, A, n, r):
    """(K_3, K_9, K_27) generators for the elementary configuration G (n x s over F_3, H = first r coordinates)"""
    s = len(d); E = np.eye(s, dtype=np.int64)
    K3 = [E[h] * (3 if h in A else 1) for h in range(s)]
    def rel(rowsel):
        # relations among columns restricted to coordinates rowsel, over F_3, in the variables v'_a (a in A), v_n
        R = [[G[i][h] for h in range(s)] for i in rowsel]
        ker = nullspace_mod3(R, s) if R else [list(E[h]) for h in range(s)]
        gens = [[(3 * x[h] if h in A else x[h]) for h in range(s)] for x in ker]
        gens += [list(3 * k) for k in K3]          # 3 K_3: v'_a, v_n in 3Z
        return [np.array(b) for b in zbasis(gens, s)]
    K27 = rel(range(n)); K9 = rel(range(r, n))
    return {3: K3, 9: K9, 27: K27}

def search(d, A, n, r, tries, seed):
    rnd = random.Random(seed); s = len(d); found = 0
    for _ in range(tries):
        G = [[rnd.randrange(3) for _ in range(s)] for _ in range(n)]
        if rank3([list(c) for c in zip(*G)], n) < n: continue          # columns span S
        if not reduced(G, d, A): continue
        B = end_algebra(G, d, A, n, r)
        loc = is_local(B, n)
        if loc:
            found += 1
            print(json.dumps({"d": d, "A": sorted(A), "n": n, "r": r, "G": G, "dimB": len(B)}), flush=True)
    return found

def check(path):
    bad = 0; tot = 0; ctl = 0; notloc = 0
    for line in open(path):
        if not line.strip() or line.startswith('#'): continue
        c = json.loads(line); d = c["d"]; A = set(c["A"]); G = c["G"]; n = c["n"]; r = c["r"]
        B = end_algebra(G, d, A, n, r); loc = is_local(B, n); red = reduced(G, d, A)
        # negative control: forgetting H (r = 0) the preorder has width 2 and every indecomposable is 1-dimensional,
        # so for n >= 2 the algebra must NOT be local
        locH = is_local(end_algebra(G, d, A, n, 0), n)
        ctl += (locH is not False)
        K = lattices(G, d, A, n, r)
        M = Model(d, 27); ok, fr = M.check(K)
        tot += 1; bad += (not ok); notloc += (loc is not True) or (not red)
        print("WILD", d, "A", sorted(A), "n", n, "r", r, "dimB", len(B), "local", loc, "reduced", red,
              "local_without_H", locH, "model_ok", ok, "sigma!=0", fr, flush=True)
    print("WILDCHECK configs", tot, "not_local_or_not_reduced", notloc, "control_local_without_H", ctl,
          "model_FAILING", bad, flush=True)
    return bad or notloc or ctl

if __name__ == '__main__':
    if sys.argv[1] == 'search':
        d = [int(a) for a in sys.argv[2].split(',')]; A = {int(a) for a in sys.argv[3].split(',') if a}
        search(d, A, int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]), int(sys.argv[7]))
    elif sys.argv[1] == 'check':
        sys.exit(1 if check(sys.argv[2]) else 0)
