#!/usr/bin/env python3
"""MATH-481 (wiki 891, Sec. 20): the functor from pairs of matrices over F_3 to configurations of type
3,27,81,243,2187 (Sec. 18.2) -- small checks over F_3 / Z/9.

Construction checked (all on paper in Sec. 20; this is an independent finite check):
  M = (x, y), m x m over F_3;  U = F_3^{2m},  X = [[x, y], [1, 0]] in End(U);
  F(M) = (W = U + U;  S1 = U+0, S2 = 0+U, S3 = diagonal, Sd = {(u, Xu): u in F_3^m + 0} in Se = graph(X)),
  a representation of the poset (1,1,1,2) = {S1, S2, S3, Sd < Se}.
  Realization G (Prop. 18.2(b)) with h_A = S1, h_N = S2, S_{n1} = S3, S_{a1'} = Sd, S_{a1} = Se:
  V = (Z/9)^{4m}, W = 3V = V[3] (so H = h_A + h_N = W);  columns a0, n0 = lifts of bases of S1, S2
  (plus a random element of W if 'lifts' is random), a1', a1, n1 = 3*(lifts of bases of Sd, Se mod Sd, S3).
  Type: 3^{2m} 27^{2m} 81^m 243^m 2187^{2m}, s = 8m.

For two configurations (V,g), (V',g') the solution module {(pi, E): pi g = g' E, E in Inc_9} is computed
exactly (Smith form over Z/9); its image pi mod 3 (= pi|_W, since W = 3V) is an F_3-space.
Checked:
  (1) dim image  ==  dim Hom_{F_3<x,y>}(M, M')                 (R o G o F is full and faithful)
  (2) some (pi, E) with pi and E invertible mod 3 exists  <=>  M ~= M'   (equivalence of configurations
      <=> isomorphism of pairs; pi, E invertible mod 3 <=> invertible over Z/9)
  (3) End-image local  <=>  End(M) local (M indecomposable).
Usage: check481.py all [SEED] [M2CASES=24]  -- m = 1 all 81 ordered pairs of objects;  m = 2 sample (see main);
  negative control: F without S_d (m = 2) -- dim image must exceed dim Hom(M, M) somewhere.
Prints 'CHECK481 ... fail N' lines; exit 1 iff some check fails.
"""
import itertools
import random
import sys

import numpy as np

# classes: (name, A/N, d)
CLASSES = [('a0', 'A', 3), ('n0', 'N', 27), ('a1', 'A', 81), ('a1p', 'A', 243), ('n1', 'N', 2187)]


def ideal_val(q, p):
    """Valuation of I_{qp} in Z/9 (0: Z/9, 1: 3Z/9, 2: 0) by the table of wiki 891 Sec. 18.1."""
    (_, cq, dq), (_, cp, dp) = q, p
    if cq == cp:
        return 0 if dq >= dp else (1 if dp == 3 * dq else 2)
    if cq == 'A':  # q in A, p in N
        return 0 if dp <= 3 * dq else (1 if dp == 9 * dq else 2)
    return 1 if dq >= dp else 2  # q in N, p in A (d(p) >= 3 d(q) gives 0)


# ---------------- linear algebra over F_3 -----------------
def rref3(A):
    A = np.array(A, dtype=np.int64) % 3
    r = 0
    piv = []
    rows, cols = A.shape
    for c in range(cols):
        k = next((i for i in range(r, rows) if A[i, c]), None)
        if k is None:
            continue
        A[[r, k]] = A[[k, r]]
        A[r] = (A[r] * A[r, c]) % 3  # inverse of 1 is 1, of 2 is 2
        for i in range(rows):
            if i != r and A[i, c]:
                A[i] = (A[i] - A[i, c] * A[r]) % 3
        piv.append(c)
        r += 1
        if r == rows:
            break
    return A[:r], piv


def rank3(A):
    A = np.asarray(A)
    if A.ndim < 2:  # an empty sum of maps is the integer 0: the zero map, rank 0
        assert A.ndim == 0 and int(A) % 3 == 0, A
        return 0
    return 0 if A.size == 0 else len(rref3(A)[1])


def nullspace3(A):
    A = np.array(A, dtype=np.int64) % 3
    n = A.shape[1]
    R, piv = rref3(A) if A.shape[0] else (np.zeros((0, n), dtype=np.int64), [])
    free = [c for c in range(n) if c not in piv]
    basis = []
    for f in free:
        v = np.zeros(n, dtype=np.int64)
        v[f] = 1
        for i, c in enumerate(piv):
            v[c] = (-R[i, f]) % 3
        basis.append(v)
    return basis


# ---------------- Smith form kernel over Z/9 -----------------
def val9(a):
    a %= 9
    return 2 if a == 0 else (1 if a % 3 == 0 else 0)


def kernel9(A):
    """Generators of {z in (Z/9)^N : A z = 0 mod 9}."""
    A = np.array(A, dtype=np.int64) % 9
    rows, N = A.shape
    Vm = np.eye(N, dtype=np.int64)
    diag = []
    r = 0
    while r < min(rows, N):
        sub = A[r:, r:]
        best = None
        for v in (0, 1):
            idx = np.argwhere((sub % 9 != 0) & ((sub % 3 != 0) if v == 0 else True))
            if len(idx):
                best = idx[0]
                break
        if best is None:
            break
        i, j = best[0] + r, best[1] + r
        A[[r, i]] = A[[i, r]]
        A[:, [r, j]] = A[:, [j, r]]
        Vm[:, [r, j]] = Vm[:, [j, r]]
        a = int(A[r, r])
        v = val9(a)
        u = (a // (3 ** v)) % 9
        uinv = pow(u, -1, 9)
        # clear column below pivot (row ops; rows do not affect the kernel)
        for k in range(r + 1, rows):
            if A[k, r]:
                f = (int(A[k, r]) // (3 ** v)) * uinv % 9
                A[k] = (A[k] - f * A[r]) % 9
        # clear row right of pivot (column ops, tracked)
        for k in range(r + 1, N):
            if A[r, k]:
                f = (int(A[r, k]) // (3 ** v)) * uinv % 9
                A[:, k] = (A[:, k] - f * A[:, r]) % 9
                Vm[:, k] = (Vm[:, k] - f * Vm[:, r]) % 9
        diag.append(v)
        r += 1
    gens = []
    for c in range(N):
        v = diag[c] if c < len(diag) else 2
        if v == 2:
            gens.append(Vm[:, c] % 9)
        elif v == 1:
            gens.append(3 * Vm[:, c] % 9)
    return gens


# ---------------- the construction -----------------
def rep_F(x, y, ctl=False):
    """F(M): dict of subspaces (as lists of basis vectors of W = F_3^{4m}).  ctl: without S_d (negative control:
    then End is the centralizer of X, larger than End(M))."""
    m = x.shape[0]
    n2 = 2 * m
    X = np.block([[x, y], [np.eye(m, dtype=np.int64), np.zeros((m, m), dtype=np.int64)]]) % 3
    I = np.eye(n2, dtype=np.int64)
    S1 = [np.concatenate([I[i], np.zeros(n2, dtype=np.int64)]) for i in range(n2)]
    S2 = [np.concatenate([np.zeros(n2, dtype=np.int64), I[i]]) for i in range(n2)]
    S3 = [np.concatenate([I[i], I[i]]) for i in range(n2)]
    Se = [np.concatenate([I[i], X[:, i]]) % 3 for i in range(n2)]
    Sd = [] if ctl else Se[:m]
    return {'S1': S1, 'S2': S2, 'S3': S3, 'Sd': Sd, 'Se': Se}


def realize(rep, rng=None):
    """Configuration (columns in (Z/9)^n, class labels) per Prop. 18.2(b), W = 3V."""
    n = len(rep['S1'][0])
    cols, labels = [], []

    def lift(w):
        return np.array(w, dtype=np.int64) % 3

    def noise():
        return 3 * np.array([rng.randrange(3) for _ in range(n)], dtype=np.int64) if rng else 0

    for w in rep['S1']:
        cols.append((lift(w) + noise()) % 9); labels.append(0)
    for w in rep['S2']:
        cols.append((lift(w) + noise()) % 9); labels.append(1)
    # Se = Sd + complement: the basis of Sd first, the rest completes
    for w in rep['Se'][len(rep['Sd']):]:
        cols.append(3 * lift(w) % 9); labels.append(2)
    for w in rep['Sd']:
        cols.append(3 * lift(w) % 9); labels.append(3)
    for w in rep['S3']:
        cols.append(3 * lift(w) % 9); labels.append(4)
    return np.array(cols, dtype=np.int64).T % 9, labels


def hom_image(g, lab, g2, lab2):
    """Solutions (pi, E) of pi g = g2 E over Z/9; returns list of (pi mod 3, E mod 3) for generators."""
    n, s = g.shape
    n2, s2 = g2.shape
    evars = []  # (q, p, weight)
    for q in range(s2):
        for p in range(s):
            v = ideal_val(CLASSES[lab2[q]], CLASSES[lab[p]])
            if v < 2:
                evars.append((q, p, 3 ** v))
    N = n2 * n + len(evars)
    A = np.zeros((n2 * s, N), dtype=np.int64)
    # (pi g)_{i,p} = sum_k pi_{ik} g_{kp};  (g2 E)_{i,p} = sum_q g2_{iq} E_{qp}
    for i in range(n2):
        for p in range(s):
            row = i * s + p
            for k in range(n):
                A[row, i * n + k] = g[k, p]
            for t, (q, pp, w) in enumerate(evars):
                if pp == p:
                    A[row, n2 * n + t] = (-w * g2[i, q]) % 9
    out = []
    for z in kernel9(A):
        pi = z[:n2 * n].reshape(n2, n) % 3
        E = np.zeros((s2, s), dtype=np.int64)
        for t, (q, p, w) in enumerate(evars):
            E[q, p] = (w * z[n2 * n + t]) % 3
        out.append((pi, E))
    return out


def span_basis(mats):
    vecs = [m.flatten() % 3 for m in mats]
    if not vecs:
        return []
    R, piv = rref3(np.array(vecs))
    return list(R)


def hom_pairs(x, y, x2, y2):
    """Basis of {p : p x = x2 p, p y = y2 p} over F_3."""
    m, m2 = x.shape[0], x2.shape[0]
    rows = []
    for (a, a2) in ((x, x2), (y, y2)):
        for i in range(m2):
            for j in range(m):
                r = np.zeros(m2 * m, dtype=np.int64)
                for k in range(m):
                    r[i * m + k] += a[k, j]       # (p a)_{ij} = sum_k p_{ik} a_{kj}
                for k in range(m2):
                    r[k * m + j] -= a2[i, k]      # (a2 p)_{ij} = sum_k a2_{ik} p_{kj}
                rows.append(r % 3)
    return [v.reshape(m2, m) for v in nullspace3(np.array(rows))]


def is_local(basis, n, cap=12, samples=4000, rng=None):
    """F_3-algebra spanned by basis (n x n matrices): every element invertible or nilpotent."""
    k = len(basis)
    if k == 0:
        return False
    it = (itertools.product(range(3), repeat=k) if k <= cap
          else (tuple(rng.randrange(3) for _ in range(k)) for _ in range(samples)))
    for c in it:
        a = sum(ci * b for ci, b in zip(c, basis)) % 3
        if rank3(a) == n:
            continue
        p = np.eye(n, dtype=np.int64)
        for _ in range(n):
            p = (p @ a) % 3
        if p.any():
            return False
    return True


def exists_equiv(gens, n, s, cap=12, samples=20000, rng=None):
    """Is there an F_3-combination of generators with pi and E both invertible mod 3?"""
    k = len(gens)
    if k == 0:  # no maps at all: an equivalence exists only between empty configurations
        return n == 0 and s == 0
    it = (itertools.product(range(3), repeat=k) if k <= cap
          else (tuple(rng.randrange(3) for _ in range(k)) for _ in range(samples)))
    for c in it:
        pi = sum(ci * g[0] for ci, g in zip(c, gens)) % 3
        if rank3(pi) < n:
            continue
        E = sum(ci * g[1] for ci, g in zip(c, gens)) % 3
        if rank3(E) == s:
            return True
    return False


def compare(M, M2, rng, iso_known=None, ctl=False):
    (x, y), (x2, y2) = M, M2
    g, lab = realize(rep_F(x, y, ctl), rng)
    g2, lab2 = realize(rep_F(x2, y2, ctl), rng)
    gens = hom_image(g, lab, g2, lab2)
    img = span_basis([p for p, _ in gens])
    hp = hom_pairs(x, y, x2, y2)
    n, s = g.shape[0], g.shape[1]
    assert len(hp) <= 10 or iso_known is not None
    # Hom may be 0 between non-isomorphic pairs of one size: then they are isomorphic only if empty
    iso_pairs = (x.shape == x2.shape) and (x.shape[0] == 0 or (len(hp) > 0 and any(
        rank3(sum(c * b for c, b in zip(cc, hp)) % 3) == x.shape[0]
        for cc in (itertools.product(range(3), repeat=len(hp)) if len(hp) <= 10 else []))))
    if iso_known is not None:
        iso_pairs = iso_known
    eq = (g.shape == g2.shape) and exists_equiv(gens, n, s, rng=rng)
    return len(img), len(hp), iso_pairs, eq


def main():
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    rng = random.Random(seed)
    fails = 0
    # sanity of the ideal table (wiki 891 Sec. 18.2 list)
    names = [c[0] for c in CLASSES]
    tab = {(names[i], names[j]): ideal_val(CLASSES[i], CLASSES[j]) for i in range(5) for j in range(5)}
    expect = {('a1p', 'a1'): 0, ('a1', 'a1p'): 1, ('a0', 'n0'): 1, ('n0', 'a0'): 1, ('n1', 'a0'): 1,
              ('a1', 'n0'): 0, ('a1p', 'n0'): 0, ('n1', 'n0'): 0, ('a1', 'n1'): 2, ('a1p', 'n1'): 1,
              ('a0', 'a1'): 2, ('n0', 'n1'): 2, ('a0', 'n1'): 2, ('n0', 'a1'): 2, ('n1', 'a1'): 1,
              ('a0', 'a1p'): 2, ('n0', 'a1p'): 2, ('a1', 'a0'): 0, ('a1p', 'a0'): 0, ('n1', 'a1p'): 1}
    bad = [k for k, v in expect.items() if tab[k] != v]
    print('CHECK481 table', 'ok' if not bad else bad)
    fails += len(bad)

    # m = 1: all 9 pairs of scalars, all ordered pairs of objects, random lifts
    objs = [(np.array([[a]]), np.array([[b]])) for a in range(3) for b in range(3)]
    f1 = 0
    for M in objs:
        for M2 in objs:
            same = M[0][0, 0] == M2[0][0, 0] and M[1][0, 0] == M2[1][0, 0]
            dimg, dhom, iso, eq = compare(M, M2, rng)
            ok = (dimg == dhom) and (iso == same) and (eq == same)
            if not ok:
                f1 += 1
                print('  FAIL m=1', M, M2, dimg, dhom, iso, eq)
    print(f'CHECK481 m=1 pairs {len(objs)**2} fail {f1}')
    fails += f1

    # m = 2: random pairs; conjugates (iso); direct sums of 1x1 (decomposable); locality
    f2 = 0
    cnt = 0
    GL2 = [np.array(P) for P in itertools.product(range(3), repeat=4)]
    GL2 = [P.reshape(2, 2) for P in GL2 if rank3(P.reshape(2, 2)) == 2]
    for t in range(int(sys.argv[3]) if len(sys.argv) > 3 else 24):
        x = np.array([[rng.randrange(3) for _ in range(2)] for _ in range(2)])
        y = np.array([[rng.randrange(3) for _ in range(2)] for _ in range(2)])
        if t % 3 == 0:  # decomposable
            x = np.diag([rng.randrange(3), rng.randrange(3)]); y = np.diag([rng.randrange(3), rng.randrange(3)])
        P = GL2[rng.randrange(len(GL2))]
        Pi = next(Q for Q in GL2 if not ((P @ Q) % 3 - np.eye(2, dtype=np.int64)).any())
        x2, y2 = (P @ x @ Pi) % 3, (P @ y @ Pi) % 3
        # End: locality
        g, lab = realize(rep_F(x, y), rng)
        gens = hom_image(g, lab, g, lab)
        img = span_basis([p for p, _ in gens])
        hp = hom_pairs(x, y, x, y)
        loc_c = is_local([b.reshape(g.shape[0], g.shape[0]) for b in img], g.shape[0], rng=rng)
        loc_m = is_local(hp, 2, rng=rng)
        dimg, dhom, iso, eq = compare((x, y), (x2, y2), rng, iso_known=True)
        # a non-isomorphic partner: change one entry of y
        y3 = y.copy(); y3[0, 1] = (y3[0, 1] + 1) % 3
        hp3 = hom_pairs(x, y, x, y3)
        iso3 = any(rank3(sum(c * b for c, b in zip(cc, hp3)) % 3) == 2
                   for cc in itertools.product(range(3), repeat=len(hp3)))
        dimg3, dhom3, _, eq3 = compare((x, y), (x, y3), rng, iso_known=iso3)
        ok = (len(img) == len(hp)) and (loc_c == loc_m) and dimg == dhom and eq and \
             dimg3 == dhom3 and eq3 == iso3
        cnt += 1
        print(f'  m=2 #{t}: dimEnd {len(img)}/{len(hp)} local {loc_c}/{loc_m} conj: dim {dimg}/{dhom} equiv {eq}; '
              f'partner iso {iso3} equiv {eq3} dim {dimg3}/{dhom3} {"ok" if ok else "FAIL"}')
        f2 += not ok
    print(f'CHECK481 m=2 cases {cnt} fail {f2}')
    fails += f2
    # negative control: without S_d the check (1) must fail on some m = 2 pair
    nbig = 0
    for t in range(8):
        x = np.array([[rng.randrange(3) for _ in range(2)] for _ in range(2)])
        y = np.array([[rng.randrange(3) for _ in range(2)] for _ in range(2)])
        dimg, dhom, _, _ = compare((x, y), (x, y), rng, iso_known=True, ctl=True)
        nbig += dimg > dhom
    print(f'CHECK481 control without S_d: dim image > dim End(M) in {nbig} of 8 (must be > 0)')
    fails += (nbig == 0)
    print('CHECK481 overall', 'ok=1' if fails == 0 else f'ok=0 fails={fails}')
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
