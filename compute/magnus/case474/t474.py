#!/usr/bin/env python3
"""MATH-474 (wiki 891 Sec. 21): gamma_4 = C_{3^k}, k >= 4 -- conditions (T0) and (T1) for every k.

Model: case467/diag467.py (Sec. 11.4 without (C), modulus 3^k).

Modes (one summary line each; exit status 1 iff a claim fails; with DROP the line is a control and exits 0):
  diag S K N SEED [DROP]   Claim D (Prop. 21.1): R = 0 on every DIAGONAL chain (K_e = (+)_h m_e(h) Z) -- N random
                           capped types of length S mod 3^K with random diagonal labels (labels_k: m_3 | 3,
                           m_{3e} in {m_e, 3 m_e}); in addition the four term-by-term vanishings of the proof are checked
                           on generators of Lambda x Sigma.  With DROP (e.g. D2, Kt, Ko, B) the same without that
                           condition: the number of failing chains is reported (control).
  blocks S K PART NPARTS [DROP]
                           Thm 21.4 (finite part): all configurations of <= 3 blocks with at least one pair on the capped
                           (cut 3^K) types of length S (index = PART mod NPARTS) satisfying (T1): singletons with
                           diagonal labels, pairs {x, y} of the kinds of Lemma 21.3 with both signs; R = 0 mod 3^K.
  orbits TYPE K            all elementary chains on TYPE mod 3^K; for every A with (T1) every orbit under gen_mats
                           (case467) contains a chain that is block diagonal (singletons and pairs {a, n}, a in A, n in N,
                           d(n) >= 9 d(a)) at ALL levels simultaneously; reported for the other A (control).
"""
import itertools, os, random, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'case467'))
sys.path.insert(0, os.path.join(HERE, '..', 'case471'))
from diag467 import Model, capped_types_k, labels_k, gen_mats, hnf_key, kernel
from t0471 import elem_chains
from t1471 import T1, partitions, proj_ok, subspace_of

# ---------------------------------------------------------------- Claim D: diagonal chains, any k
def diag_K(lab, S, k):
    E = np.eye(S, dtype=np.int64)
    return {3 ** j: [E[h] * lab[h][3 ** j] for h in range(S)] for j in range(1, k + 1)}

def lambda_sigma(M, K):
    """generators of Lambda and Sigma (as in Model.check)"""
    mod = M.mod; s = M.s
    lconds = []
    Kp = {e: M.perp(K[e]) for e in K}
    for vec, e in M.V:
        if e == 1: continue
        for phi in Kp[e]:
            r = {}
            for h in range(s):
                if phi[h] % mod:
                    for kk, c in vec[h].items(): r[kk] = r.get(kk, 0) + int(phi[h]) * c
            if r: lconds.append((r, mod))
    Lg = kernel(lconds, M.NP, mod)
    sconds = list(M.J)
    for fv, eF, kind in M.F:
        if kind in M.drop:
            gens = [np.eye(s, dtype=np.int64)[h] * eF for h in range(s)]
        else:
            gens = K[eF] if eF in K else [np.eye(s, dtype=np.int64)[h] for h in range(s)]
        for v in gens:
            r = {}
            for h in range(s):
                if v[h] % mod:
                    for kk, c in fv[h].items(): r[kk] = r.get(kk, 0) + int(v[h]) * c
            if r: sconds.append((r, mod))
    Sg = kernel(sconds, M.NS, mod)
    return np.array(Lg, dtype=np.int64) % mod, np.array(Sg, dtype=np.int64) % mod

def termwise_ok(M, Lm, Sm):
    """every single product lambda_p * RB[p, :] . sigma vanishes (the proof of Prop. 21.1 is term by term)"""
    if not len(Lm) or not len(Sm): return True
    mod = M.mod
    for p in range(M.NP):
        col = Lm[:, p:p + 1] % mod                       # values of parameter p on Lambda generators
        val = (col * ((M.RB[p] @ Sm.T) % mod)[None, :]) % mod
        if val.any(): return False
    return True

def diag_mode(S, k, N, seed, drop):
    rng = random.Random(seed); types = capped_types_k(S, k); labs = labels_k(k)
    fail = tfail = 0; nz = 0
    for _ in range(N):
        d = rng.choice(types); lab = [rng.choice(labs) for _ in range(S)]
        M = Model(d, 3 ** k, drop); K = diag_K(lab, S, k)
        Lm, Sm = lambda_sigma(M, K)
        ok = (not len(Lm)) or (not len(Sm)) or not ((Lm @ M.RB % M.mod) @ Sm.T % M.mod).any()
        fail += (not ok); nz += bool(len(Sm) and Sm.any())
        if not drop: tfail += (not termwise_ok(M, Lm, Sm))
    print("DIAG S", S, "k", k, "N", N, "seed", seed, "drop", sorted(drop), "sigma!=0", nz, "FAILING", fail,
          "TERMWISE_FAILING", tfail, flush=True)
    return fail + tfail

# ---------------------------------------------------------------- (T1) blocks for any k
def pair_kinds(k):
    """kinds of Lemma 21.3: ('w', l, c) -- t_x = w, z_y = c w, w in H_j iff j <= l (0 <= l <= k-2);
    ('p', a, m, c) -- t_x = u, z_y = c v, H_j cap <u,v> = all (j <= a), <u+v> (a < j <= m), 0 (j > m), 0 <= a < m <= k-2.
    c in {1, -1}."""
    out = [('w', l, c) for l in range(k - 1) for c in (1, -1)]
    out += [('p', a, m, c) for m in range(1, k - 1) for a in range(m) for c in (1, -1)]
    return out

def pair_lattice(kind, j, mod):
    """generators (2-vectors) of K_{3^{j+1}} on (x, y), j = 1..k-1 (level j: relations in S/H_j, H_{k-1} = 0)"""
    full = [(3, 0), (0, 1)]
    if kind[0] == 'w':
        _, l, c = kind
        return full if j <= l else [(3, (-c) % mod), (0, 3), (9, 0)]
    _, a, m, c = kind
    if j <= a: return full
    if j <= m: return [(3, c % mod), (0, 3), (9, 0)]
    return [(9, 0), (0, 3)]

def configs(d, k):
    s = len(d); E = np.eye(s, dtype=np.int64); LAB = labels_k(k); PK = pair_kinds(k); mod = 3 ** k
    for P in partitions(list(range(s)), d):
        if len(P) > 3: continue
        pairs = [b for b in P if len(b) == 2]
        if not pairs: continue
        if len({d[x] for x, y in pairs}) > 1 or len({d[y] for x, y in pairs}) > 1: continue
        singles = [b[0] for b in P if len(b) == 1]
        for lab in itertools.product(range(len(LAB)), repeat=len(singles)):
            A = {x for x, y in pairs} | {h for h, l in zip(singles, lab) if LAB[l][3] == 3}
            if not T1(d, A): continue
            for kinds in itertools.product(PK, repeat=len(pairs)):
                K = {3 ** j: [] for j in range(1, k + 1)}
                for h in range(s): K[3].append(E[h] * (3 if h in A else 1))
                for h, l in zip(singles, lab):
                    for j in range(2, k + 1): K[3 ** j].append(E[h] * LAB[l][3 ** j])
                for (x, y), kind in zip(pairs, kinds):
                    for j in range(1, k):
                        for gx, gy in pair_lattice(kind, j, mod): K[3 ** (j + 1)].append(gx * E[x] + gy * E[y])
                yield P, A, K

def blocks_mode(S, k, part, nparts, drop):
    types = capped_types_k(S, k)
    ncase = nfail = nt = 0
    for t, d in enumerate(types):
        if t % nparts != part: continue
        nt += 1; M = None
        for P, A, K in configs(d, k):
            if M is None: M = Model(d, 3 ** k, drop)
            ok, _ = M.check(K); ncase += 1; nfail += (not ok)
    print("T1BLOCKSK S", S, "k", k, "part", part, "of", nparts, "drop", sorted(drop), "types", nt, "configs", ncase,
          "FAILING", nfail, flush=True)
    return nfail

# ---------------------------------------------------------------- orbit check of Lemma 21.3
def is_T1_block_k(key, d, A, k):
    s = len(d)
    Xs = [subspace_of(key[j], A, s) for j in range(k - 1)]
    N = [h for h in range(s) if h not in A]
    if not [(a, n) for a in A for n in N if d[n] >= 9 * d[a]]:
        cand = [[(h,) for h in range(s)]]
    else:
        cand = list(partitions(list(range(s)), d))
    for P in cand:
        if any(len(b) == 2 and not (b[0] in A and b[1] not in A) for b in P): continue
        blocks = [set(b) for b in P]
        if all(proj_ok(X, blocks, s) for X in Xs): return True
    return False

def orbits_mode(d, k):
    s = len(d); mod = 3 ** k
    def key(K): return tuple(hnf_key(K[3 ** j], s, mod) for j in range(2, k + 1))
    bad = ctl = tot = nt1 = nnot = 0
    for rr in range(s + 1):
        for A in itertools.combinations(range(s), rr):
            A = set(A); t1 = T1(d, A)
            keys = list({key(K) for K in elem_chains(s, k, A)})
            pos = {x: t for t, x in enumerate(keys)}; parent = list(range(len(keys)))
            def find(x):
                while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
                return x
            G = gen_mats(d, A, mod)
            for t, kk in enumerate(keys):
                for Ci in G:
                    k2 = tuple(hnf_key([Ci @ np.array(row) for row in H], s, mod) for H in kk)
                    a, b = find(t), find(pos[k2])
                    if a != b: parent[a] = b
            comps = {}
            for t in range(len(keys)): comps.setdefault(find(t), []).append(t)
            nb = sum(1 for mem in comps.values() if not any(is_T1_block_k(keys[t], d, A, k) for t in mem))
            tot += len(comps)
            if t1: bad += nb; nt1 += 1
            else: ctl += nb; nnot += 1
    print("T1ORBK k", k, "type", d, "orbits", tot, "A with (T1)", nt1, "orbits without a block member there", bad,
          "| A without (T1)", nnot, "orbits without a block member (control)", ctl, flush=True)
    return bad

if __name__ == '__main__':
    m = sys.argv[1]
    if m == 'diag':
        S, k, N, seed = map(int, sys.argv[2:6])
        drop = sys.argv[6].split(',') if len(sys.argv) > 6 and sys.argv[6] else ()
        f = diag_mode(S, k, N, seed, drop)
        sys.exit(0 if drop else (1 if f else 0))
    if m == 'blocks':
        S, k, part, nparts = map(int, sys.argv[2:6])
        drop = sys.argv[6].split(',') if len(sys.argv) > 6 and sys.argv[6] else ()
        f = blocks_mode(S, k, part, nparts, drop)
        sys.exit(0 if drop else (1 if f else 0))
    if m == 'orbits':
        sys.exit(1 if orbits_mode([int(a) for a in sys.argv[2].split(',')], int(sys.argv[3])) else 0)

# ---------------------------------------------------------------- the mixed model mod 9 (Sec. 21.3): all k at once
class MixedModel(Model):
    """Model mod 9 for an ELEMENTARY chain mod 3^k written as sigma = 3^(k-2) sigma' (Lemma 15.2): every condition of
    index level (3^k, d(i)) uses the lattice L(i) of that index, given per index; coefficients mod 9 (they depend on
    d only through the type cut at 9).  K passed to check(): {('L', h): generators of L(h)}."""
    def __init__(self, d, drop=()):
        super().__init__(d, 9, drop)
        s = self.s; idx = range(s); dr = self.drop; V = []; t = 0
        keys = []
        if 'B' not in dr: keys += [i for i in idx]
        if 'D2' not in dr: keys += [i for i, j in itertools.combinations(idx, 2)]
        if 'D1' not in dr: keys += [i for i in idx]
        assert len(keys) == len(self.V)
        self.V = [(vec, ('L', i)) for (vec, e), i in zip(self.V, keys)]
        fk = [(m if d[m] <= d[n] else n) for m, n in itertools.product(idx, idx)] + \
             [a for a, b in itertools.combinations(idx, 2)]
        assert len(fk) == len(self.F)
        self.F = [(fv, ('L', h), kind) for (fv, e, kind), h in zip(self.F, fk) if kind not in self.drop]

def mixed_K_from_chain(d, k, K):
    """L(h) = K_{(3^k, d(h))}"""
    return {('L', h): K[gcd_(3 ** k, d[h])] for h in range(len(d))}

def gcd_(a, b):
    from math import gcd
    return gcd(a, b)

def cross_mode(S, k, drop):
    """per configuration of 'blocks' (mod 3^k): full model ok == mixed model ok (Sec. 21.3, equivalence)"""
    n = diff = nf = 0
    for d in capped_types_k(S, k):
        M = None
        for P, A, K in configs(d, k):
            if M is None: M = Model(d, 3 ** k, drop); MM = MixedModel(d, drop)
            a, _ = M.check(K); b, _ = MM.check(mixed_K_from_chain(d, k, K))
            n += 1; diff += (a != b); nf += (not a)
    print("CROSS S", S, "k", k, "drop", sorted(drop), "configs", n, "full-model failing", nf, "DIFFERENT", diff, flush=True)
    return diff

def cross_elem_mode(dstr, k, drop):
    """the same on ALL elementary chains of one type (any A), not only (T1) blocks"""
    d = [int(a) for a in dstr.split(',')]; s = len(d)
    M = Model(d, 3 ** k, drop); MM = MixedModel(d, drop); n = diff = nf = 0
    for r in range(s + 1):
        for A in itertools.combinations(range(s), r):
            for K in elem_chains(s, k, set(A)):
                a, _ = M.check(K); b, _ = MM.check(mixed_K_from_chain(d, k, K))
                n += 1; diff += (a != b); nf += (not a)
    print("CROSSE type", d, "k", k, "drop", sorted(drop), "chains", n, "full-model failing", nf, "DIFFERENT", diff, flush=True)
    return diff

def seqs_single(cls, t):
    lo, hi = (3, 9) if cls == 'A' else (1, 3)
    return [tuple([lo] * a + [hi] * (t - a)) for a in range(t + 1)]

def seqs_pair(t):
    """monotone sequences of pair lattices over levels 1..t (Lemma 21.3): F (= K_3), W_c, G_c, D"""
    out = set()
    for c in (1, -1):
        for a in range(t + 1): out.add(tuple(['F'] * a + [('W', c)] * (t - a)))
        for a in range(t + 1):
            for b in range(t - a + 1): out.add(tuple(['F'] * a + [('G', c)] * b + ['D'] * (t - a - b)))
    return sorted(out, key=str)

def pair_gens(lab):
    if lab == 'F': return [(3, 0), (0, 1)]
    if lab == 'D': return [(9, 0), (0, 3)]
    kind, c = lab
    return [(3, (-c) % 9), (0, 3)] if kind == 'W' else [(3, c % 9), (0, 3)]

def mixed_configs(d):
    """(T1) block configurations (<= 3 blocks, >= 1 pair) on the type d cut at 9, with every level profile:
    level j(h) = rank of d(h) among the distinct values >= 9 (j = 0 for d(h) = 3, lattice K_3); per block a monotone
    sequence of lattices over levels 1..t (repetitions allowed, so this covers every k and every chain profile)."""
    s = len(d); E = np.eye(s, dtype=np.int64)
    vals = sorted({x for x in d if x >= 9}); t = len(vals)
    lev = [0 if d[h] == 3 else vals.index(d[h]) + 1 for h in range(s)]
    for P in partitions(list(range(s)), d):
        if len(P) > 3: continue
        pairs = [b for b in P if len(b) == 2]
        if not pairs: continue
        if len({d[x] for x, y in pairs}) > 1 or len({d[y] for x, y in pairs}) > 1: continue
        singles = [b[0] for b in P if len(b) == 1]
        for cls in itertools.product('AN', repeat=len(singles)):
            A = {x for x, y in pairs} | {h for h, c in zip(singles, cls) if c == 'A'}
            if not T1(d, A): continue
            for ss in itertools.product(*[seqs_single(c, t) for c in cls]):
                for ps in itertools.product(seqs_pair(t), repeat=len(pairs)):
                    L = {}
                    for h in range(s):
                        j = lev[h]; g = []
                        for q in range(s): g.append(E[q] * (3 if q in A else 1) * 3)     # 3K_3 (9Z^s implicit)
                        if j == 0:
                            g = [E[q] * (3 if q in A else 1) for q in range(s)]
                        else:
                            for hh, sq in zip(singles, ss): g.append(E[hh] * sq[j - 1])
                            for (x, y), sq in zip(pairs, ps):
                                for gx, gy in pair_gens(sq[j - 1]): g.append(gx * E[x] + gy * E[y])
                        L[('L', h)] = g
                    yield P, A, L

def capped9(S):
    from diag467 import capped_types
    return capped_types(S, 9)

def mixed_mode(S, part, nparts, drop):
    ncase = nfail = nt = 0
    for t_, d in enumerate(capped9(S)):
        if t_ % nparts != part: continue
        nt += 1; MM = None
        for P, A, L in mixed_configs(d):
            if MM is None: MM = MixedModel(d, drop)
            ok, _ = MM.check(L); ncase += 1; nfail += (not ok)
    print("MIXED S", S, "part", part, "of", nparts, "drop", sorted(drop), "types", nt, "configs", ncase,
          "FAILING", nfail, flush=True)
    return nfail

def melem_mode(S, part, nparts, drop):
    """ALL elementary chains, every k at once (Sec. 21.4): capped (cut 9) types of length S (index = PART mod NPARTS),
    every A, every chain X_1 >= ... >= X_t of subspaces of K_3/3K_3 (t = number of distinct values d >= 9, level of
    an index = rank of its d among them; L = 3K_3 + X_level, K_3 for d = 3); R = 0 in the mixed model mod 9."""
    from diag467 import subspaces, rref3
    subs = subspaces(S)
    def inside(Y, X): return rref3(list(X) + list(Y), S) == X
    def chains(t, X=None):
        if t == 0: yield (); return
        for Y in subs:
            if X is None or inside(Y, X):
                for rest in chains(t - 1, Y): yield (Y,) + rest
    E = np.eye(S, dtype=np.int64)
    ncase = nfail = nt = 0; ex = []
    for t_, d in enumerate(capped9(S)):
        if t_ % nparts != part: continue
        nt += 1; MM = MixedModel(d, drop)
        vals = sorted({x for x in d if x >= 9}); t = len(vals)
        lev = [0 if d[h] == 3 else vals.index(d[h]) + 1 for h in range(S)]
        allch = list(chains(t))
        for r in range(S + 1):
            for A in itertools.combinations(range(S), r):
                A = set(A)
                K3 = [E[q] * (3 if q in A else 1) for q in range(S)]
                for ch in allch:
                    L = {}
                    for h in range(S):
                        if lev[h] == 0: L[('L', h)] = K3; continue
                        X = ch[lev[h] - 1]
                        L[('L', h)] = [3 * v for v in K3] + [np.array([x[q] * (3 if q in A else 1) for q in range(S)],
                                                                      dtype=np.int64) for x in X]
                    ok, _ = MM.check(L); ncase += 1
                    if not ok:
                        nfail += 1
                        if len(ex) < 3: ex.append((d, sorted(A), ch))
    print("MELEM S", S, "part", part, "of", nparts, "drop", sorted(drop), "types", nt, "chains", ncase,
          "FAILING", nfail, ex, flush=True)
    return nfail

if __name__ == '__main__':
    m = sys.argv[1]
    if m == 'melem':
        S, part, nparts = map(int, sys.argv[2:5])
        drop = sys.argv[5].split(',') if len(sys.argv) > 5 and sys.argv[5] else ()
        f = melem_mode(S, part, nparts, drop)
        sys.exit(0 if drop else (1 if f else 0))
    if m == 'cross':
        S, k = map(int, sys.argv[2:4]); drop = sys.argv[4].split(',') if len(sys.argv) > 4 and sys.argv[4] else ()
        sys.exit(1 if cross_mode(S, k, drop) else 0)
    if m == 'crosse':
        drop = sys.argv[4].split(',') if len(sys.argv) > 4 and sys.argv[4] else ()
        sys.exit(1 if cross_elem_mode(sys.argv[2], int(sys.argv[3]), drop) else 0)
    if m == 'mixed':
        S, part, nparts = map(int, sys.argv[2:5])
        drop = sys.argv[5].split(',') if len(sys.argv) > 5 and sys.argv[5] else ()
        f = mixed_mode(S, part, nparts, drop)
        sys.exit(0 if drop else (1 if f else 0))
