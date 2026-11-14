#!/usr/bin/env python3
"""MATH-471 (wiki 891 Sec. 16): elementary chains mod 27 under condition (T1) -- block form with pairs.

(T1): every incomparable pair a in A, n in N (d(n) >= 9 d(a)) has d(a) = alpha_1 (the smallest A-value) and
d(n) = nu_1 (the largest N-value).  Lemma 16.4: then the legal moves bring an elementary chain (K_9, K_27) to a block
form: singletons with diagonal labels and pairs {x, y}, x in A with d(x) = alpha_1, y in N with d(y) = nu_1, of the kinds
  (i)   t_x = z_y = e, H = 0:        K_27 = K_9 = <(3, -eps), (0, 3)>            (eps = +-1)
  (i')  t_x = z_y = e, H = <e>:      K_27 = <(3, -eps), (0, 3)>, K_9 = <(3, 0), (0, 1)>
  (ii)  t_x = e1, z_y = e2, H = <e1 + eps e2>: K_27 = <(9, 0), (0, 3)>, K_9 = <(3, eps), (0, 3)>
(9Z^2 is implicit.)  Prop. 13.3 (mod 27, blocks of size <= 2) reduces R = 0 to configurations of <= 3 blocks.

Modes (one summary line each; exit status 1 iff a claim fails):
  blocks S PART NPARTS [DROP]  all configurations of <= 3 blocks with at least one pair on the capped (cut 27) types of
                               length S with index = PART mod NPARTS, satisfying (T1); R = 0 in the model mod 27.
                               With DROP (e.g. D2, Kt) the same without that condition (control: must fail somewhere).
  orbits TYPE                  all elementary chains on TYPE mod 27; for every A with (T1) every orbit under gen_mats
                               (case467) contains a chain in this block form; reported for the other A (control).
"""
import itertools, os, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'case467'))
from diag467 import Model, capped_types_k, labels_k, gen_mats, hnf_key
from t0471 import elem_chains

LAB = labels_k(3)            # 8 diagonal labels {3: m3, 9: m9, 27: m27}

def T1(d, A):
    N = [h for h in range(len(d)) if h not in A]
    inc = {(d[a], d[n]) for a in A for n in N if d[n] >= 9 * d[a]}
    return len({x for x, y in inc}) <= 1 and len({y for x, y in inc}) <= 1

def partitions(rest, d):
    """partitions into singletons and ordered pairs (x, y) with d(y) >= 9 d(x) (x the earlier index)"""
    if not rest: yield []; return
    h = rest[0]
    for p in partitions(rest[1:], d): yield [(h,)] + p
    for n in rest[1:]:
        if d[n] >= 9 * d[h]:
            r2 = [x for x in rest[1:] if x != n]
            for p in partitions(r2, d): yield [(h, n)] + p

PAIR_KINDS = [(kind, eps) for kind in ('i', "i'", 'ii') for eps in (1, 2)]   # eps = 2 means -1 mod 3

def pair_lattices(kind, eps):
    """(K_9, K_27) on the coordinates (x, y), x in A, y in N, as generator lists (2-vectors)"""
    m = (-1) % 27 if eps == 1 else 1      # relation t - eps z  (eps = 1: (3, -1); eps = -1: (3, 1))
    pair = [(3, m), (0, 3), (9, 0)]
    if kind == 'i': return pair, pair
    if kind == "i'": return [(3, 0), (0, 1)], pair
    e = 1 if eps == 1 else 26              # (3, eps)
    return [(3, e), (0, 3), (9, 0)], [(9, 0), (0, 3)]

def configs(d):
    s = len(d); E = np.eye(s, dtype=np.int64)
    for P in partitions(list(range(s)), d):
        if len(P) > 3: continue
        pairs = [b for b in P if len(b) == 2]
        if not pairs: continue
        if len({d[x] for x, y in pairs}) > 1 or len({d[y] for x, y in pairs}) > 1: continue
        singles = [b[0] for b in P if len(b) == 1]
        for lab in itertools.product(range(len(LAB)), repeat=len(singles)):
            A = {x for x, y in pairs} | {h for h, l in zip(singles, lab) if LAB[l][3] == 3}
            if not T1(d, A): continue
            for kinds in itertools.product(PAIR_KINDS, repeat=len(pairs)):
                K = {e: [] for e in (3, 9, 27)}
                for h in range(s): K[3].append(E[h] * (3 if h in A else 1))
                for h, l in zip(singles, lab):
                    for e in (9, 27): K[e].append(E[h] * LAB[l][e])
                for (x, y), (kind, eps) in zip(pairs, kinds):
                    k9, k27 = pair_lattices(kind, eps)
                    for e, gens in ((9, k9), (27, k27)):
                        for gx, gy in gens: K[e].append(gx * E[x] + gy * E[y])
                yield P, A, K

def blocks_mode(S, part, nparts, drop):
    types = capped_types_k(S, 3)
    ncase = nfail = nt = 0
    for t, d in enumerate(types):
        if t % nparts != part: continue
        nt += 1; M = Model(d, 27, drop)
        for P, A, K in configs(d):
            ok, _ = M.check(K); ncase += 1; nfail += (not ok)
    print("T1BLOCKS S", S, "part", part, "of", nparts, "drop", sorted(drop), "types", nt, "configs", ncase,
          "FAILING", nfail, flush=True)
    return nfail

# ---------------------------------------------------------------- orbit check of the block form
def proj_ok(X, blocks, s):
    """the subspace X of F_3^s (RREF rows) is the direct sum of its intersections with the coordinate blocks"""
    from diag467 import rref3
    base = rref3([list(r) for r in X], s) if X else ()
    for B in blocks:
        for row in X:
            p = [row[h] if h in B else 0 for h in range(s)]
            if any(p) and rref3(list(base) + [p], s) != base: return False
    return True

def subspace_of(K, A, s):
    """X_e in K_3/3K_3 (basis e_n, 3e_a) for a lattice K_e >= 3K_3, from its HNF key"""
    from diag467 import rref3
    rows = []
    for r in K:
        if any((r[h] // (3 if h in A else 1)) % 3 for h in range(s)):
            rows.append([(r[h] // (3 if h in A else 1)) % 3 for h in range(s)])
    return rref3(rows, s) if rows else ()

def is_T1_block(key, d, A):
    s = len(d)
    X9 = subspace_of(key[0], A, s); X27 = subspace_of(key[1], A, s)
    N = [h for h in range(s) if h not in A]
    if not [(a, n) for a in A for n in N if d[n] >= 9 * d[a]]:
        cand = [[(h,) for h in range(s)]]
    else:
        cand = list(partitions(list(range(s)), d))
    for P in cand:
        if any(len(b) == 2 and not (b[0] in A and b[1] not in A) for b in P): continue
        blocks = [set(b) for b in P]
        if proj_ok(X9, blocks, s) and proj_ok(X27, blocks, s): return True
    return False

def orbits_mode(d):
    s = len(d); mod = 27
    def key(K): return (hnf_key(K[9], s, mod), hnf_key(K[27], s, mod))
    bad = ctl = tot = nt1 = nnot = 0
    for rr in range(s + 1):
        for A in itertools.combinations(range(s), rr):
            A = set(A); t1 = T1(d, A)
            keys = list({key(K) for K in elem_chains(s, 3, A)})
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
            nb = sum(1 for mem in comps.values() if not any(is_T1_block(keys[t], d, A) for t in mem))
            tot += len(comps)
            if t1: bad += nb; nt1 += 1
            else: ctl += nb; nnot += 1
    print("T1ORB type", d, "orbits", tot, "A with (T1)", nt1, "orbits without a block member there", bad,
          "| A without (T1)", nnot, "orbits without a block member (control)", ctl, flush=True)
    return bad

if __name__ == '__main__':
    m = sys.argv[1]
    if m == 'blocks':
        S, part, nparts = map(int, sys.argv[2:5])
        drop = sys.argv[5].split(',') if len(sys.argv) > 5 and sys.argv[5] else ()
        f = blocks_mode(S, part, nparts, drop)
        sys.exit(0 if drop else (1 if f else 0))
    if m == 'orbits':
        sys.exit(1 if orbits_mode([int(a) for a in sys.argv[2].split(',')]) else 0)
