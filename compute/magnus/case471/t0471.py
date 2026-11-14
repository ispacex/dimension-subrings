#!/usr/bin/env python3
"""MATH-471 (wiki 891 Sec. 16): elementary chains under condition (T0) -- simultaneous diagonal form of the whole chain.

Setting (wiki 891 Sec. 14.1-14.2, 15.2).  An elementary chain mod 3^k is given by socle data: an F_3-space S spanned by
columns c_h (c_a = t_a = 3y_a for a in A, c_n = z_n = y_n for n in N) and a flag H_1 >= H_2 >= ... >= H_{k-2} of
subspaces of S (H_j = S cap 3^j U).  The lattices are
    K_{3^(j+1)} = { v : 3 | v_a (a in A),  sum_a (v_a/3) t_a + sum_n v_n z_n in H_j }   (H_0 := 0 ... see below),
with K_{3^k} the relations in S itself (H := 0) and K_{3^(j+1)}, j < k-1, the relations in S / H_j.
For k = 3 there is one subspace H = H_1: K_27 = relations in S, K_9 = relations in S/H.

Legal moves on the data (Lemma 13.1, proof of Thm 15.3): c_j += c * c_i if i, j are in the same class and
d(i) >= d(j); z_n += c * t_a if d(n) <= 3 d(a); c_j *= 2.  (T0): no a in A, n in N with d(n) >= 9 d(a).

Claim (Lemma 16.1).  Under (T0) the moves bring every elementary chain to a form in which ALL K_e are diagonal.
Algorithm (the proof): order A by decreasing d, then N by decreasing d; every column may receive multiples of every
earlier column.  Take a basis e of S adapted to the flag F_j = <c_1..c_j> and to the flag H_1 >= ... >= H_{k-2};
replace c_j by e(j) if c_j is not in F_{j-1}, by 0 otherwise.

Modes (one summary line each; exit status 1 iff a claim fails or a control does not fail):
  nf S K N SEED [ctl]  N random elementary data on random capped types of length S (mod 3^K) with an invariant
                       strictly between 3 and 3^K and a random partition A satisfying (T0) (ctl: violating (T0));
                       run the algorithm, check that only legal moves are used and that the result is diagonal;
                       check R = 0 directly in the model mod 3^K on the ORIGINAL chain.  With ctl the algorithm is
                       run with the same move set and the number of non-diagonal results is reported (must be > 0).
                       Note (review 703): under (T0) the legality assertion holds by construction of the order (it
                       guards the implementation, not the lemma), and the ctl line only shows that THIS algorithm
                       fails without (T0); that a diagonal form can be impossible is shown by the 'orbits' control.
  orbits TYPE K        all elementary chains on TYPE (mod 3^K) for every A, orbits under the group generators of
                       case467 (gen_mats, independent of the move set above); per A: orbits without a diagonal member.
                       Claim: 0 for every A satisfying (T0).  Reported (control) for the other A.
"""
import itertools, os, random, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'case467'))
from diag467 import Model, capped_types_k, subspaces, rref3, gen_mats, hnf_key

# ---------------------------------------------------------------- F_3 linear algebra
def rank3(rows, n):
    return len(rref3([list(r) for r in rows], n)) if rows else 0

def in_span(v, rows, n):
    return rank3(list(rows) + [v], n) == rank3(list(rows), n)

def kernel3(cols, r):
    """F_3-kernel of x -> sum_h x_h cols[h] (cols in F_3^r): RREF basis, as tuples of length s"""
    s = len(cols)
    # rows of the augmented matrix [cols^T | I]
    M = [list(cols[h]) + [int(h == g) for g in range(s)] for h in range(s)]
    R = rref3(M, r + s)
    return rref3([row[r:] for row in R if not any(x % 3 for x in row[:r])], s)

def quotient_cols(cols, H, r):
    """coordinates of the columns in S/H: complete a basis of H to F_3^r and drop the H-part"""
    Hb = [list(x) for x in rref3([list(h) for h in H], r)] if H else []
    comp = []
    for i in range(r):
        e = [int(i == j) for j in range(r)]
        if not in_span(e, Hb + comp, r): comp.append(e)
    B = Hb + comp                                      # basis of F_3^r, rows
    # solve x B = c for each column; take the coordinates on comp
    Bm = np.array(B, dtype=np.int64).T                 # columns = basis vectors
    out = []
    for c in cols:
        x = solve3(Bm, list(c), r)
        out.append(tuple(x[len(Hb):]))
    return out, r - len(Hb)

def solve3(Bm, c, r):
    M = [list(Bm[i]) + [c[i]] for i in range(r)]
    R = rref3(M, r + 1)
    x = [0] * r
    for row in R:
        p = next(j for j in range(r + 1) if row[j] % 3)
        assert p < r
        x[p] = row[r] % 3
    return x

# ---------------------------------------------------------------- chain from data
def chain(cols, Hs, A, k):
    """K_{3^j}, j = 1..k, as generator lists: K_3 = Z^N + 3Z^A; K_{3^k} = relations in S;
    K_{3^(j+1)} (1 <= j < k-1) = relations in S / H_j, H_1 >= ... >= H_{k-2}"""
    s = len(cols); r = len(cols[0]) if cols else 0
    E = np.eye(s, dtype=np.int64)
    K3 = [E[h] * (3 if h in A else 1) for h in range(s)]
    lift = lambda x: np.array([x[h] * (3 if h in A else 1) for h in range(s)], dtype=np.int64)
    K = {3: K3}
    for j in range(1, k):
        e = 3 ** (j + 1)
        if j == k - 1: X = kernel3(cols, r)
        else:
            qc, rq = quotient_cols(cols, Hs[j - 1], r)
            X = kernel3(qc, rq) if rq else tuple(tuple(int(g == h) for g in range(s)) for h in range(s))
        K[e] = [3 * v for v in K3] + [lift(x) for x in X]
    return K

def is_coord(X):
    return all(sum(1 for x in row if x % 3) == 1 for row in X)

def chain_subspaces(cols, Hs, k):
    """the F_3-subspaces X_e of K_3/3K_3 (RREF), e = 9..3^k"""
    s = len(cols); r = len(cols[0]) if cols else 0
    out = {}
    for j in range(1, k):
        if j == k - 1: out[3 ** (j + 1)] = kernel3(cols, r)
        else:
            qc, rq = quotient_cols(cols, Hs[j - 1], r)
            out[3 ** (j + 1)] = kernel3(qc, rq) if rq else tuple(tuple(int(g == h) for g in range(s)) for h in range(s))
    return out

# ---------------------------------------------------------------- the normal form of Lemma 16.1
def legal(d, A, i, j):
    """may column j receive multiples of column i (i != j)?"""
    if (i in A) == (j in A): return d[i] >= d[j]
    if i in A and j not in A: return d[j] <= 3 * d[i]
    return False                                        # N -> A: trivial on the data

def T0(d, A):
    return all(d[n] <= 3 * d[a] for a in A for n in range(len(d)) if n not in A)

def adapted_basis(flag, Hflag, r):
    """basis of F_3^r adapted to two flags (lists of nested subspaces, each a list of rows): every member of both
    flags is spanned by a subset.  Construction: for each step F_j of the first flag, pick vectors from
    F_j cap H_l for the H-steps from the smallest one upwards (Bruhat / Zassenhaus)."""
    basis = []
    Hs = [list(h) for h in Hflag] + [[[int(i == j) for j in range(r)] for i in range(r)]]   # ..., whole space last
    Hs = sorted(Hs, key=lambda h: rank3(h, r))           # increasing
    for F in flag:
        for Hl in Hs:
            # vectors of F cap H_l not yet spanned
            inter = intersect(F, Hl, r)
            for v in inter:
                if not in_span(v, basis, r): basis.append(v)
    return basis

def intersect(U, W, r):
    """basis of U cap W (rows)"""
    U = rref3(U, r) if U else (); W = rref3(W, r) if W else ()
    if not U or not W: return []
    # x U = y W  <=>  (x, -y) [U; W] = 0
    M = [list(u) for u in U] + [[(-x) % 3 for x in w] for w in W]
    ker = kernel3([tuple(row) for row in M], r)     # combinations of rows giving 0
    out = []
    for z in ker:
        v = [sum(z[i] * U[i][c] for i in range(len(U))) % 3 for c in range(r)]
        if any(v): out.append(v)
    return [list(x) for x in rref3(out, r)] if out else []

def normal_form(d, A, cols, Hs):
    """returns (new columns, list of moves) following the proof; asserts legality of every move"""
    s = len(cols); r = len(cols[0])
    order = sorted([h for h in range(s) if h in A], key=lambda h: -d[h]) + \
            sorted([h for h in range(s) if h not in A], key=lambda h: -d[h])
    c = {h: list(cols[h]) for h in range(s)}
    flag = [[c[order[t]] for t in range(j + 1)] for j in range(s)]
    e = adapted_basis(flag, Hs, r)
    moves = []
    for j in reversed(range(s)):
        hj = order[j]; prev = [order[t] for t in range(j)]
        Fprev = [c0 for c0 in (list(cols[h]) for h in prev)]
        if in_span(list(cols[hj]), Fprev, r):
            target = [0] * r
        else:
            # the unique basis vector of e that lies in F_j but not in F_{j-1}
            Fj = Fprev + [list(cols[hj])]
            cand = [v for v in e if in_span(v, Fj, r) and not in_span(v, Fprev, r)]
            # adapted basis: exactly one new vector at this step
            assert len([v for v in e if in_span(v, Fj, r)]) == rank3(Fj, r)
            target = cand[0]
        # target = alpha * cols[hj] + sum beta_t cols[prev_t] (original columns; earlier ones are changed later only)
        coef = solve_comb(target, [list(cols[hj])] + [list(cols[h]) for h in prev], r)
        alpha, betas = coef[0], coef[1:]
        if any(target):
            assert alpha % 3, "alpha must be a unit"
            if alpha % 3 == 2: moves.append(('scale', hj))
        else:
            alpha = 0
        for h, b in zip(prev, betas):
            if b % 3:
                assert legal(d, A, h, hj), ("illegal move", h, hj)
                moves.append(('add', h, hj, b % 3))
        if not any(target):
            # c_j in F_{j-1}: c_j - sum beta cols = 0 with alpha = 1
            coef = solve_comb([0] * r, [list(cols[hj])] + [list(cols[h]) for h in prev], r, lead=1)
            for h, b in zip(prev, coef[1:]):
                if b % 3: assert legal(d, A, h, hj), ("illegal move", h, hj)
        c[hj] = target
    return [tuple(c[h]) for h in range(s)], moves

def solve_comb(target, vecs, r, lead=None):
    """coefficients x with sum x_i vecs_i = target (x_0 = lead if given)"""
    n = len(vecs)
    best = None
    # small search is too slow for big n; use linear algebra: unknowns x_i, equations per coordinate
    M = [[vecs[i][c] for i in range(n)] + [target[c]] for c in range(r)]
    if lead is not None:
        M.append([int(i == 0) for i in range(n)] + [lead])
    R = rref3(M, n + 1)
    x = [0] * n
    for row in R:
        p = next(j for j in range(n + 1) if row[j] % 3)
        assert p < n, "no solution"
        x[p] = row[n] % 3
    return x

# ---------------------------------------------------------------- random data
def has_mid(d, k): return any(3 < x < 3 ** k for x in d)

def rand_data(s, k, rng):
    r = rng.randint(1, s)
    while True:
        cols = [tuple(rng.randrange(3) for _ in range(r)) for _ in range(s)]
        if rank3([list(c) for c in cols], r) == r: break
    Hs = []
    cur = [[int(i == j) for j in range(r)] for i in range(r)]
    for _ in range(k - 2):
        # nested: H_1 >= H_2 >= ...
        dim = rng.randint(0, len(rref3(cur, r)))
        basis = rref3(cur, r)
        new = []
        for _ in range(dim):
            co = [rng.randrange(3) for _ in basis]       # one coefficient per basis vector
            new.append([sum(x * b[c] for x, b in zip(co, basis)) % 3 for c in range(r)])
        new = [list(x) for x in rref3(new, r)] if new else []
        Hs.append(new); cur = new if new else []
        if not cur: Hs += [[] for _ in range(k - 2 - len(Hs))]; break
    return cols, Hs, r

def nf_mode(S, k, N, seed, ctl):
    rng = random.Random(seed)
    types = [d for d in capped_types_k(S, k) if has_mid(d, k)]
    M_cache = {}
    done = bad_moves = nondiag = rfail = sig_nz = mixed = 0
    while done < N:
        d = rng.choice(types)
        A = {h for h in range(S) if rng.random() < 0.5}
        if T0(d, A) == ctl: continue
        cols, Hs, r = rand_data(S, k, rng)
        try:
            new, moves = normal_form(d, A, cols, Hs) if not ctl else normal_form_any(d, A, cols, Hs)
        except AssertionError as ex:
            bad_moves += 1; done += 1; continue
        X = chain_subspaces(new, Hs, k)
        nondiag += not all(is_coord(X[e]) for e in X)
        X0 = chain_subspaces(cols, Hs, k)
        mixed += (0 < len(A) < S) and len(set(X0.values())) > 1 and not all(is_coord(X0[e]) for e in X0)
        if not ctl:
            key = tuple(d)
            if key not in M_cache: M_cache[key] = Model(d, 3 ** k)
            ok, nz = M_cache[key].check(chain(cols, Hs, A, k))
            rfail += not ok; sig_nz += nz
        done += 1
    if ctl:
        print("NF_CTL S", S, "mod", 3 ** k, "data", N, "violating (T0)", "non-diagonal results", nondiag, flush=True)
        return nondiag == 0
    print("NF S", S, "mod", 3 ** k, "data", N, "(T0) holds", "nontrivial", mixed, "illegal_moves", bad_moves, "non_diagonal", nondiag,
          "sigma!=0", sig_nz, "R_FAILING", rfail, flush=True)
    return (bad_moves + nondiag + rfail) > 0

def normal_form_any(d, A, cols, Hs):
    """the same algorithm with the same order, skipping the legality assertion (control: without (T0) the needed
    moves are illegal; we apply only the legal part)"""
    s = len(cols); r = len(cols[0])
    order = sorted([h for h in range(s) if h in A], key=lambda h: -d[h]) + \
            sorted([h for h in range(s) if h not in A], key=lambda h: -d[h])
    flag = [[list(cols[order[t]]) for t in range(j + 1)] for j in range(s)]
    e = adapted_basis(flag, Hs, r)
    c = {h: list(cols[h]) for h in range(s)}
    for j in reversed(range(s)):
        hj = order[j]; prev = [order[t] for t in range(j)]
        Fprev = [list(cols[h]) for h in prev]
        if in_span(list(cols[hj]), Fprev, r):
            coef = solve_comb([0] * r, [list(cols[hj])] + Fprev, r, lead=1)
            target = [0] * r
        else:
            Fj = Fprev + [list(cols[hj])]
            target = [v for v in e if in_span(v, Fj, r) and not in_span(v, Fprev, r)][0]
            coef = solve_comb(target, [list(cols[hj])] + Fprev, r)
        if all(legal(d, A, h, hj) or b % 3 == 0 for h, b in zip(prev, coef[1:])):
            c[hj] = target
    return [tuple(c[h]) for h in range(s)], []

# ---------------------------------------------------------------- orbits of elementary chains (group generators)
def elem_chains(s, k, A):
    """all elementary chains for A: nested X_9 >= ... >= X_{3^k} in K_3/3K_3 (as in case470.all_elem_chains)"""
    subs = subspaces(s); E = np.eye(s, dtype=np.int64)
    K3 = [E[h] * (3 if h in A else 1) for h in range(s)]
    lift = lambda x: np.array([x[h] * (3 if h in A else 1) for h in range(s)], dtype=np.int64)
    def inside(Y, X): return rref3(list(X) + list(Y), s) == X
    def rec(j, X, acc):
        if j > k: yield dict(acc); return
        for Y in subs:
            if X is not None and not inside(Y, X): continue
            acc[3 ** j] = [3 * v for v in K3] + [lift(y) for y in Y]
            yield from rec(j + 1, Y, acc)
    yield from rec(2, None, {3: K3})

def orbits_mode(d, k):
    s = len(d); mod = 3 ** k
    def key(K): return tuple(hnf_key(K[3 ** j], s, mod) for j in range(2, k + 1))
    def isdiag(kk): return all(all(H[r][c] == 0 for r in range(s) for c in range(s) if r != c) for H in kk)
    claim_bad = 0; ctl_nodiag = 0; tot = 0; nA_t0 = nA_not = 0
    for rr in range(s + 1):
        for A in itertools.combinations(range(s), rr):
            A = set(A); t0 = T0(d, A)
            confs = {key(K): K for K in elem_chains(s, k, A)}
            keys = list(confs); pos = {x: t for t, x in enumerate(keys)}; parent = list(range(len(keys)))
            def find(x):
                while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
                return x
            G = gen_mats(d, A, mod)
            for t, kk in enumerate(keys):
                for Ci in G:
                    k2 = tuple(hnf_key([Ci @ np.array(row) for row in H], s, mod) for H in kk)
                    assert k2 in pos, "group move left the elementary chains"
                    a, b = find(t), find(pos[k2])
                    if a != b: parent[a] = b
            comps = {}
            for t in range(len(keys)): comps.setdefault(find(t), []).append(t)
            nd = sum(1 for mem in comps.values() if not any(isdiag(keys[t]) for t in mem))
            tot += len(comps)
            if t0: claim_bad += nd; nA_t0 += 1
            else: ctl_nodiag += nd; nA_not += 1
    print("ORB471 type", d, "mod", mod, "orbits", tot, "A with (T0)", nA_t0, "orbits without diagonal member there",
          claim_bad, "| A without (T0)", nA_not, "orbits without diagonal member (control)", ctl_nodiag, flush=True)
    return claim_bad > 0

if __name__ == '__main__':
    m = sys.argv[1]
    if m == 'nf':
        S, k, N, seed = map(int, sys.argv[2:6]); ctl = len(sys.argv) > 6 and sys.argv[6] == 'ctl'
        sys.exit(1 if nf_mode(S, k, N, seed, ctl) else 0)
    if m == 'orbits':
        sys.exit(1 if orbits_mode([int(a) for a in sys.argv[2].split(',')], int(sys.argv[3])) else 0)
