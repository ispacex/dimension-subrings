#!/usr/bin/env python3
"""MATH-469 (wiki 891 Sec. 14): the modulo-27 model on all chains K_3 >= K_9 >= K_27 whose K_9 is in the block normal
form of Lemma 13.2(b).

Why this covers every group (for a fixed s): by Lemma 13.2(b) (on paper, wiki 891 Sec. 13.2) every adapted basis can be
changed, preserving A ⊔ N and the orders d, into an adapted basis whose K_9 is block diagonal: singletons {h} with
K_9 = m_h Z (m_h in {1,3} for h in N, {3,9} for h in A) and pairs {a,n}, a in A, n in N, d(n) >= 9 d(a), with
K_9 = <(3,-1),(0,3)>.  The same change of basis transforms K_27 into SOME lattice with 3K_9 <= K_27 <= K_9.  We
enumerate all of them (all subspaces of K_9/3K_9), so the union over the normal forms of K_9 is a superset of the chains
that occur.  The model is diag467.Model with MOD = 27 (wiki 891 Sec. 13.5; without (C)).  Pairs are taken with
eps = +-1 (a superset; the lemma needs only eps = 1).

Modes:
  nf TYPE [DROP]       all A, all block normal forms of K_9, all K_27; prints one summary line NF ...
  types S              the capped (cap 27) types of length S, one per line
"""
import itertools, sys, os
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'case467'))
from diag467 import Model, subspaces, zbasis, capped_types_k

LAB9 = [(1, 'N'), (3, 'N'), (3, 'A'), (9, 'A')]

def normal_forms_K9(d):
    """all (blocks, A, K_3 gens, K_9 gens) in the block normal form of Lemma 13.2(b), any number of blocks"""
    s = len(d)
    def partitions(rest):
        if not rest: yield []; return
        h = rest[0]
        for p in partitions(rest[1:]): yield [(h,)] + p
        for n in rest[1:]:
            if d[n] >= 9 * d[h] and not os.environ.get('NF_NOPAIRS'):   # NF_NOPAIRS=1: negative control
                r2 = [x for x in rest[1:] if x != n]
                for p in partitions(r2): yield [(h, n)] + p
    E = np.eye(s, dtype=np.int64)
    for blocks in partitions(list(range(s))):
        singles = [b[0] for b in blocks if len(b) == 1]; pairs = [b for b in blocks if len(b) == 2]
        for lab in itertools.product(LAB9, repeat=len(singles)):
            for eps in itertools.product((1, 2), repeat=len(pairs)):
                A = {h for h, l in zip(singles, lab) if l[1] == 'A'} | {a for a, n in pairs}
                K3 = [E[h] * (3 if h in A else 1) for h in range(s)]
                K9 = [E[h] * l[0] for h, l in zip(singles, lab)]
                for (a, n), e in zip(pairs, eps):
                    K9 += [3 * E[a] + (9 - e) * E[n], 3 * E[n]]
                yield blocks, A, K3, K9

def chains(d):
    s = len(d); subs = subspaces(s)
    for blocks, A, K3, K9 in normal_forms_K9(d):
        B9 = zbasis([list(map(int, k)) for k in K9] + [[9 * int(h == g) for g in range(s)] for h in range(s)], s)
        for Z in subs:
            g27 = [[3 * a for a in b] for b in B9] + [[sum(z[t] * B9[t][h] for t in range(s)) for h in range(s)]
                                                       for z in Z]
            yield blocks, A, {3: K3, 9: [np.array(b) for b in B9], 27: [np.array(g) for g in g27]}

def nf(d, drop=()):
    M = Model(d, 27, drop)
    tot = bad = nfree = nunit = 0; nk9 = 0; ex = []
    for blocks, A, K in chains(d):
        ok, fr = M.check(K)
        tot += 1; bad += (not ok); nfree += fr; nunit += M.last_unit
        if not ok and len(ex) < 2: ex.append((blocks, sorted(A)))
    nk9 = sum(1 for _ in normal_forms_K9(d))
    print("NF type", d, "drop", sorted(drop), "K9_normal_forms", nk9, "chains", tot, "sigma!=0", nfree,
          "sigma_order27", nunit, "FAILING", bad, ex, flush=True)
    return bad

def cover(d):
    """Lemma 13.2(b) in the count: every orbit of chains (A, K_3 >= K_9 >= K_27) under the elementary changes of basis
    (diag467.gen_mats, mod 27) contains a chain enumerated by chains(d)"""
    from diag467 import configs_k, hnf_key, gen_mats
    s = len(d); mod = 27
    key = lambda K: (hnf_key(K[9], s, mod), hnf_key(K[27], s, mod))
    nfkeys = {}
    for blocks, A, K in chains(d): nfkeys.setdefault(frozenset(A), set()).add(key(K))
    tot = miss = 0
    for r in range(s + 1):
        for A in itertools.combinations(range(s), r):
            A = set(A); confs = {}
            for _, K in configs_k(s, 3, [A]): confs[key(K)] = K
            keys = list(confs); pos = {x: t for t, x in enumerate(keys)}; parent = list(range(len(keys)))
            def find(x):
                while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
                return x
            for t, kk in enumerate(keys):
                for Ci in gen_mats(d, A, mod):
                    k2 = tuple(hnf_key([Ci @ np.array(row) for row in H], s, mod) for H in kk)
                    a, b = find(t), find(pos[k2])
                    if a != b: parent[a] = b
            comps = {}
            for t in range(len(keys)): comps.setdefault(find(t), []).append(t)
            nk = nfkeys.get(frozenset(A), set())
            for mem in comps.values():
                tot += 1
                if not any(keys[t] in nk for t in mem): miss += 1
    print("COVER type", d, "orbits", tot, "without a normal-form member", miss, flush=True)
    return miss

if __name__ == '__main__':
    if sys.argv[1] == 'cover':
        sys.exit(1 if cover([int(a) for a in sys.argv[2].split(',')]) else 0)
    if sys.argv[1] == 'nf':
        d = [int(a) for a in sys.argv[2].split(',')]
        drop = sys.argv[3].split(',') if len(sys.argv) > 3 and sys.argv[3] else ()
        sys.exit(1 if nf(d, drop) else 0)
    elif sys.argv[1] == 'types':
        for d in capped_types_k(int(sys.argv[2]), 3): print(','.join(map(str, d)))
