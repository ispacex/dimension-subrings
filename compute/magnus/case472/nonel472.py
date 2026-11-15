#!/usr/bin/env python3
"""MATH-472 (wiki 891 Sec. 18): NON-elementary chains mod 27 (gamma_4 = C_27) on types WITHOUT the invariant 9
(every d(i) = 3 or 27 | d(i)).  For such types every e of the model mod 27 is 3 or 27, so the model (case467 Model,
Sec. 11.4 / 13.5, without (C)) sees only K_3 = Z^N + 3Z^A and K_27, with 9K_3 <= K_27 <= K_3 and nothing else.

Data (Sec. 14.1, 18.1): a Z/9-module V (here a submodule of (Z/9)^n) with columns g_h (t_a = 3y_a, z_n = y_n);
K_27 = { v : 3 | v_a, sum_a (v_a/3) g_a + sum_n v_n g_n = 0 in V }.

Modes (one summary line each; exit status 1 iff a claim fails; 'brick wild' also exits 1 when the random X is not
local -- run_case472.sh ignores that status and only requires R = 0):
  cert TYPE [A]          the universal certificate of Sec. 18.3: is R (on Lambda_0 x Sigma_0, mod 27) a Z/27-combination
                         of the level-27 pairings <B_i(lambda), F_mn(sigma)> (B_i: (B), (D2), (D1) of level 27; F_mn:
                         (Kt), (Ko) of level 27)?  Lambda_0 = Lambda(K_27 := K_3), Sigma_0 = Sigma(K_27 := 9K_3).
                         Without A: all A.  Prints per A 'yes'/'no'.
  certs S                cert for every capped type of length S without 9 and every A; summary
  brick FAMILY M [DROP]  the configurations D(X) of Sec. 18.2: FAMILY 'four' (four-subspace, Jordan block J_M(2), type
                         3^M 27^M 81^M 729^M) or 'wild' ((1,1,1,2): type 3^M 27^M 81^(M-k) 243^k 2187^M, k = ceil(M/2), random X).  Checks that the
                         image of B in End(W) is local (all elements units or nilpotent), that no column vanishes, and
                         R = 0 in the model (with DROP: the model without that condition; reported, a control)
  rand S N SEED          N random non-elementary chains (random V = (Z/9)^p + 3(Z/9)^q, random columns) on random
                         capped types of length S without 9: R = 0 (evidence only)
  types S                capped types (gaps cut at 27) of length S without the invariant 9
"""
import itertools, os, random, sys, time
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'case467'))
from diag467 import Model, kernel, howell, capped_types_k

MOD = 27

def types_no9(S):
    return [d for d in capped_types_k(S, 3) if 9 not in d]

def K3_gens(s, A):
    E = np.eye(s, dtype=np.int64)
    return [E[h] * (3 if h in A else 1) for h in range(s)]

def K27_from_columns(G, A):
    """G: n x s integer matrix over Z/9 (columns g_h in (Z/9)^n).  K_27 generators (9K_3 included)."""
    n, s = G.shape
    rel = kernel([({h: int(G[r, h]) for h in range(s) if G[r, h] % 9}, 9) for r in range(n) if (G[r] % 9).any()], s, 9)
    E = np.eye(s, dtype=np.int64)
    out = [np.array([(3 if h in A else 1) * int(w[h]) for h in range(s)], dtype=np.int64) for w in rel]
    out += [E[h] * (27 if h in A else 9) for h in range(s)]
    return out

# ---------------------------------------------------------------- the certificate (Sec. 18.3)
def lam_sig_bases(M, A):
    s = M.s; mod = M.mod
    K3 = K3_gens(s, A)
    def lconds(K):
        out = []; Kp = {e: M.perp(K[e]) for e in K}
        for vec, e in M.V:
            if e == 1: continue
            for phi in Kp[e]:
                r = {}
                for h in range(s):
                    if phi[h] % mod:
                        for k, c in vec[h].items(): r[k] = r.get(k, 0) + int(phi[h]) * c
                if r: out.append((r, mod))
        return out
    def sconds(K):
        out = list(M.J)
        for fv, eF, kind in M.F:
            gens = K[eF] if eF in K else [np.eye(s, dtype=np.int64)[h] for h in range(s)]
            for v in gens:
                r = {}
                for h in range(s):
                    if v[h] % mod:
                        for k, c in fv[h].items(): r[k] = r.get(k, 0) + int(v[h]) * c
                if r: out.append((r, mod))
        return out
    nine = [9 * v for v in K3]
    L = kernel(lconds({3: K3, 27: K3}), M.NP, mod)
    S_ = kernel(sconds({3: K3, 27: nine}), M.NS, mod)
    return np.array(L, dtype=np.int64).reshape(-1, M.NP) % mod, np.array(S_, dtype=np.int64).reshape(-1, M.NS) % mod

def vec_mats(M):
    """level-27 lambda vectors as (s x NP) matrices, level-27 sigma functionals as (s x NS) matrices"""
    s = M.s
    Bs = []
    for vec, e in M.V:
        if e != 27: continue
        B = np.zeros((s, M.NP), dtype=np.int64)
        for h in range(s):
            for k, c in vec[h].items(): B[h, k] += c
        Bs.append(B % MOD)
    Fs = []
    for fv, eF, kind in M.F:
        if eF != 27: continue
        F = np.zeros((s, M.NS), dtype=np.int64)
        for h in range(s):
            for k, c in fv[h].items(): F[h, k] += c
        Fs.append(F % MOD)
    return Bs, Fs

def in_span(gens, target, mod):
    """target in the Z/mod-span of gens (lists of 1-d arrays)?"""
    if not target.any(): return True
    if not gens: return False
    piv = howell(gens, len(target), mod)
    t = target.copy() % mod
    for col, row, v in piv:
        c = int(t[col]) % mod
        if c == 0: continue
        if c % (3 ** v): return False
        t = (t - (c // 3 ** v) * row) % mod
    return not t.any()

def cert(d, A, M=None):
    M = M or Model(d, MOD)
    Lm, Sm = lam_sig_bases(M, A)
    if Lm.shape[0] == 0 or Sm.shape[0] == 0: return True, 0
    GR = (Lm @ M.RB % MOD) @ Sm.T % MOD
    if not GR.any(): return True, 0
    Bs, Fs = vec_mats(M)
    LB = [(Lm @ B.T) % MOD for B in Bs]          # |L| x s
    SF = [(Sm @ F.T) % MOD for F in Fs]          # |S| x s
    gens = [((lb @ sf.T) % MOD).ravel() for lb in LB for sf in SF]
    gens = [g for g in gens if g.any()]
    return in_span(gens, GR.ravel(), MOD), len(gens)

def all_A(s): return [set(c) for r in range(s + 1) for c in itertools.combinations(range(s), r)]

# ---------------------------------------------------------------- bricks D(X) (Sec. 18.2)
def ring_ok(d, A, q, p):
    """the ideal I_qp of Z/9 as 1 (Z/9), 3 (3Z/9) or 0"""
    if q == p: return 1
    dq, dp = d[q], d[p]
    if (q in A) == (p in A):
        return 1 if dq >= dp else (3 if dp == 3 * dq else 0)
    if q in A:   # q in A, p in N
        return 1 if dp <= 3 * dq else (3 if dp == 9 * dq else 0)
    return 3 if dq >= dp else 0   # q in N, p in A

def brick(family, m, seed=0):
    """(d, A, G): G an n x s matrix over Z/9 of columns; V = (Z/9)^(2m), W = V[3] = 3V = F_3^(2m),
    h_A = 3<g_a0> = first m coordinates, h_N = 3<g_n0> = last m coordinates (so h_A + h_N = W, h_A ∩ h_N = 0).
    'four': classes a0 (A,3), n0 (N,27), a1 (A,81), n1 (N,729), m columns each; S_a1 = graph of id, S_n1 = graph of
            the Jordan block J_m(2) -- a regular four-subspace representation with End = F_3[x]/x^m (local).
    'wild': classes a0 (A,3), n0 (N,27), a1 (A,81), a1' (A,243), n1 (N,2187): poset (1,1,1,2) with the chain
            S_a1' < S_a1; random S_a1 (dim m), S_a1' (dim ceil(m/2)) inside it, S_n1 (dim m), seed 'seed'."""
    rng = random.Random(seed)
    def graph(Mx):   # columns 3*(e_i + sum_j Mx[j][i] e_{m+j})
        cols = []
        for i in range(m):
            v = np.zeros(2 * m, dtype=np.int64); v[i] = 3
            for j in range(m): v[m + j] = 3 * Mx[j][i] % 9
            cols.append(v)
        return cols
    a0 = [np.eye(2 * m, dtype=np.int64)[i] for i in range(m)]
    n0 = [np.eye(2 * m, dtype=np.int64)[m + i] for i in range(m)]
    if family == 'meet': pass
    elif family == 'four':
        I = [[int(i == j) for i in range(m)] for j in range(m)]
        J = [[2 if i == j else (1 if j == i + 1 else 0) for i in range(m)] for j in range(m)]
        groups = [('A', 3, a0), ('N', 27, n0), ('A', 81, graph(I)), ('N', 729, graph(J))]
    else:
        def rnd_sub(dim):
            while True:
                B = [[rng.randrange(3) for _ in range(2 * m)] for _ in range(dim)]
                if rank3(np.array(B, dtype=np.int64)) == dim: return [3 * np.array(b, dtype=np.int64) for b in B]
        k = (m + 1) // 2
        Sa1 = rnd_sub(m)                    # basis of S_a1; its first k vectors span S_a1'
        groups = [('A', 3, a0), ('N', 27, n0), ('A', 81, Sa1[k:]), ('A', 243, Sa1[:k]), ('N', 2187, rnd_sub(m))]
    if family == 'meet':     # h_A ∩ h_N != 0 (Prop. 18.2(b) in general): V0 = (Z/9)^3, W = F_3^3,
        # h_A = <e1,e2>, h_N = <e2,e3>; the n0-lift of e2 differs from the a0-lift (e2 + 3e1)
        E = np.eye(3, dtype=np.int64)
        def rnd(dim):
            while True:
                B = [[rng.randrange(3) for _ in range(3)] for _ in range(dim)]
                if rank3(np.array(B, dtype=np.int64)) == dim: return [3 * np.array(b, dtype=np.int64) for b in B]
        groups = [('A', 3, [E[0], E[1]]), ('N', 27, [E[1] + 3 * E[0], E[2]]), ('A', 81, rnd(m)), ('N', 729, rnd(m))]
    d = []; A = set(); cols = []
    for kind, val, cs in groups:
        for c in cs:
            if kind == 'A': A.add(len(d))
            d.append(val); cols.append(c)
    return d, A, np.array(cols, dtype=np.int64).T % 9

def B_image_local(d, A, G):
    """B = {pi in End(V) : pi g = g E, E in the ideal ring}; V = (Z/9)^n here (columns span with 3V = W).  Returns
    (dim of the image of B in End_F3(W) where W = 3V, local?)"""
    n, s = G.shape
    # V = (Z/9)^n must be spanned by the columns (true for the bricks: a0, n0 columns are unit vectors)
    assert len(howell(list(G.T % 9), n, 9)) == n and all(v == 0 for _, _, v in howell(list(G.T % 9), n, 9))
    # unknowns: pi (n x n over Z/9), E (s x s, E_qp in I_qp): pi G - G E = 0 mod 9
    var = {}
    for a in range(n):
        for b in range(n): var[('p', a, b)] = len(var)
    for q in range(s):
        for p in range(s):
            if ring_ok(d, A, q, p): var[('e', q, p)] = len(var)
    conds = []
    for a in range(n):
        for p in range(s):
            r = {}
            for b in range(n):
                if G[b, p] % 9: r[var[('p', a, b)]] = r.get(var[('p', a, b)], 0) + int(G[b, p])
            for q in range(s):
                if ('e', q, p) in var and G[a, q] % 9:
                    f = ring_ok(d, A, q, p)       # E_qp = f * x
                    r[var[('e', q, p)]] = r.get(var[('e', q, p)], 0) - f * int(G[a, q])
            r = {k: c for k, c in r.items() if c % 9}
            if r: conds.append((r, 9))
    sols = kernel(conds, len(var), 9)
    # image in End(W), W = 3V = F_3^n (pi acts on 3V by pi mod 3)
    imgs = []
    for x in sols:
        P = np.array([[int(x[var[('p', a, b)]]) % 3 for b in range(n)] for a in range(n)], dtype=np.int64)
        imgs.append(P.ravel())
    # F_3 basis of the image
    basis = []
    for v in imgs:
        w = v.copy() % 3
        for bv, pc in basis:
            if w[pc]: w = (w - w[pc] * bv) % 3
        if w.any():
            pc = int(np.nonzero(w)[0][0]); w = (w * pow(int(w[pc]), -1, 3)) % 3
            basis = [((bv - bv[pc] * w) % 3, c) for bv, c in basis] + [(w, pc)]
    dim = len(basis)
    if dim > 9: return dim, None
    mats = [bv.reshape(n, n) for bv, _ in basis]
    local = True
    for coef in itertools.product(range(3), repeat=dim):
        P = sum((c * Mx for c, Mx in zip(coef, mats)), np.zeros((n, n), dtype=np.int64)) % 3
        Q = P.copy()
        for _ in range(n): Q = (Q @ P) % 3
        nil = not Q.any()
        if not nil and rank3(P) < n: local = False; break
    return dim, local

def rank3(P):
    P = P.copy() % 3; r = 0; n, m = P.shape
    for c in range(m):
        piv = [i for i in range(r, n) if P[i, c]]
        if not piv: continue
        P[[r, piv[0]]] = P[[piv[0], r]]
        P[r] = (P[r] * pow(int(P[r, c]), -1, 3)) % 3
        for i in range(n):
            if i != r and P[i, c]: P[i] = (P[i] - P[i, c] * P[r]) % 3
        r += 1
    return r

def model_check(d, A, G, drop=()):
    M = Model(d, MOD, drop)
    K = {3: K3_gens(len(d), A), 27: K27_from_columns(G, A)}
    return M.check(K)

# ---------------------------------------------------------------- random non-elementary chains
def rand_cols(s, rng):
    p = rng.randint(1, 3); q = rng.randint(0, 3); n = p + q
    G = np.zeros((n, s), dtype=np.int64)
    for h in range(s):
        for r in range(n):
            G[r, h] = rng.randrange(9) if r < p else 3 * rng.randrange(3)
    if not ((G[:p] % 3).any()):   # force non-elementary: some column of order 9
        G[0, rng.randrange(s)] = 1
    return G

def is_elementary(G): return not (G % 3).any()

# ---------------------------------------------------------------- main
if __name__ == '__main__':
    mode = sys.argv[1]; t0 = time.time()
    if mode == 'types':
        for d in types_no9(int(sys.argv[2])): print(','.join(map(str, d)))
        sys.exit(0)
    if mode == 'cert':
        d = [int(a) for a in sys.argv[2].split(',')]
        As = [set(int(a) for a in sys.argv[3].split(',') if a != '')] if len(sys.argv) > 3 else all_A(len(d))
        M = Model(d, MOD); no = 0
        for A in As:
            ok, ng = cert(d, A, M); no += (not ok)
            print("  A", sorted(A), "yes" if ok else "no", "gens", ng, flush=True)
        print("CERT type", d, "A", len(As), "without certificate", no, "cpu-sec %.1f" % (time.time() - t0), flush=True)
        sys.exit(0)
    if mode == 'certs':
        S = int(sys.argv[2]); tot = no = 0; bad = {}
        for d in types_no9(S):
            M = Model(d, MOD)
            for A in all_A(S):
                ok, _ = cert(d, A, M); tot += 1
                if not ok: no += 1; bad.setdefault(tuple(d), []).append(sorted(A))
        for d, l in bad.items(): print("  no certificate:", list(d), l)
        print("CERTS S", S, "types", len(types_no9(S)), "(d,A)", tot, "without certificate", no,
              "cpu-sec %.1f" % (time.time() - t0), flush=True)
        sys.exit(0)
    if mode == 'brick':
        fam, m = sys.argv[2], int(sys.argv[3]); drop = sys.argv[4].split(',') if len(sys.argv) > 4 and sys.argv[4] else ()
        seed = int(sys.argv[5]) if len(sys.argv) > 5 else 0
        d, A, G = brick(fam, m, seed)
        dim, local = B_image_local(d, A, G)
        nz = all((G[:, h] % 9).any() for h in range(G.shape[1]))
        ok, fr = model_check(d, A, G, drop)
        print("BRICK", fam, "m", m, "type", d, "A", sorted(A), "nonelementary", not is_elementary(G), "dim B|W", dim,
              "local", local, "R=0", ok, "sigma!=0", fr, "drop", list(drop), "cpu-sec %.1f" % (time.time() - t0), flush=True)
        bad = (not drop) and not (ok and local and nz)
        sys.exit(1 if bad else 0)
    if mode == 'rand':
        S, N, seed = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]); rng = random.Random(seed)
        T = types_no9(S); fail = nsig = 0; models = {}
        for it in range(N):
            d = rng.choice(T); A = {h for h in range(S) if rng.random() < 0.5}
            G = rand_cols(S, rng)
            key = tuple(d)
            if key not in models: models[key] = Model(d, MOD)
            K = {3: K3_gens(S, A), 27: K27_from_columns(G, A)}
            ok, fr = models[key].check(K); fail += (not ok); nsig += fr
        print("RAND S", S, "N", N, "seed", seed, "sigma!=0", nsig, "cpu-sec %.1f" % (time.time() - t0), "FAILING", fail,
              flush=True)
        sys.exit(1 if fail else 0)
