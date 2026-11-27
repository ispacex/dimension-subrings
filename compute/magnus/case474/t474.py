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
