#!/usr/bin/env python3
"""MATH-475 (wiki 891 Sec. 21): R = 0 on configurations of <= 3 indecomposable blocks (classes 2A1N, 1A2N, 2A2N).

Logic (wiki 891 Sec. 21.2-21.3).  In class C an elementary chain mod 27 decomposes by legal moves into blocks, each an
indecomposable representation of P ⊔ {h} with at most b columns (b = 3 for 2A1N, 1A2N; b = 4 for 2A2N) [Tits form +
Drozd's theorem + steps 1-2 of Lemma 16.4].  Each block can be moved by block-local legal moves (these are legal
globally: gen_mats generators depend only on the two indices) to the first member of its orbit.  So by Prop. 13.3'
it suffices to check R = 0 in the model mod 27 (case467 Model, without (C)) on every U = union of <= 3 such blocks.

Enumeration.  A *point* is (value, class); a U-configuration is: a capped value sequence (d_1 in {3,9,27}, gaps in
{3,9,27}), a set of points on it, and a multiset of <= 3 *atoms* covering every point, where an atom is (block, entry):
a block is a multiset of <= b points (its indices), and 'entry' is an orbit representative of an INDECOMPOSABLE
elementary chain on the block (orbits under the block's gen_mats, computed by brute force: an orbit is indecomposable
iff no member splits along coordinates, struct475.max_atom).  Kept: at least one multi-index atom, and the
incomparable pairs of U have <= ca A-values and <= cn N-values ((ca, cn) = (2,1), (1,2), (2,2)), shape not T0.
This is a superset of what occurs inside a chain of class C (restrictions of C have such shapes).
Values are capped as in wiki 891 Sec. 17.1 (ratios of neighbours cut at 27): the legality of a move and gen_mats
depend on d(i), d(j) only through min(d(j)/d(i), 27) and the thresholds 3, 9, so a block orbit computed on the capped
values of U is the orbit for the true values.  The catalogue is computed here from the orbits, not taken from the
Open Math OS note (whose explicit representatives use the opposite orientation of the chains, review of 27.11.2026).

Modes (one summary line; exit status 1 iff a claim fails):
  cat C                 the catalogue: per block shape, the number of indecomposable orbits (compare: Tits roots)
  count C               number of U-configurations by size |U|, no model checks
  runpts C PART NPARTS [DROP]  the same, but parts by point set (each part enumerates only its point sets; used for
                        the full 2A2N run); prints RUN475P lines
  run C PART NPARTS [DROP]  check R = 0 on the configurations with running number = PART mod NPARTS
                        (NPARTS large = a uniform sample, used by the pilot); with DROP (D2, Kt) the model without that
                        condition (control: must fail somewhere; exit 0 regardless)
"""
import itertools, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
for sub in ('case467', 'case471', 'case473', 'case475'): sys.path.insert(0, os.path.join(HERE, '..', sub))
import numpy as np
from diag467 import Model, gen_mats
from s5_473 import Space, induced27, chain_K, MOD
from struct475 import closed_family, max_atom
import tits475

CLASSES = {'2A1N': (2, 1, 3), '1A2N': (1, 2, 3), '2A2N': (2, 2, 4)}

_space = {}
def space(s):
    if s not in _space:
        sp = Space(s); _space[s] = (sp, closed_family(sp))
    return _space[s]

_cat = {}
def catalogue(block):
    """block: tuple of points (v, c) sorted; returns list of (X9, X27) (RREF rows in block coordinates) = first members
    of the indecomposable orbits"""
    if block in _cat: return _cat[block]
    s = len(block); d = [v for v, c in block]; A = {i for i, (v, c) in enumerate(block) if c == 'A'}
    sp, fam = space(s)
    Ts = {tuple(map(tuple, induced27(Ci, A, s))) for Ci in gen_mats(d, A, MOD)}
    perms = [sp.perm(T) for T in Ts]
    n = len(sp.pairs); parent = list(range(n))
    def find(x):
        while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
        return x
    for t, (i, j) in enumerate(sp.pairs):
        for P in perms:
            a, b = find(t), find(sp.pidx[(P[i], P[j])])
            if a != b:
                if a < b: parent[b] = a
                else: parent[a] = b
    indec = {}
    for t, (i, j) in enumerate(sp.pairs):
        r = find(t); ok = (s == 1) or max_atom(fam[i] & fam[j], s) == s
        indec[r] = indec.get(r, True) and ok
    out = [(sp.subs[sp.pairs[r][0]], sp.subs[sp.pairs[r][1]]) for r in sorted(indec) if indec[r]]
    _cat[block] = out
    return out

def value_seqs(q):
    for d1 in (3, 9, 27):
        for g in itertools.product((3, 9, 27), repeat=q - 1):
            v = [d1]
            for x in g: v.append(v[-1] * x)
            yield v

def shape_pts(pts):
    inc = [(a, n) for a in pts if a[1] == 'A' for n in pts if n[1] == 'N' and n[0] >= 9 * a[0]]
    return len({a[0] for a, n in inc}), len({n[0] for a, n in inc})

def point_sets(maxpts):
    """point sets of <= maxpts points; maxpts = b + 2 (a block of b points plus two singletons)"""
    for q in range(1, maxpts + 1):
        for v in value_seqs(q):
            for cl in itertools.product(('A', 'N', 'AN'), repeat=q):
                pts = tuple((x, c) for x, cc in zip(v, cl) for c in cc)
                if len(pts) <= maxpts: yield pts

def configs(C, ppart=None):
    """all U-configurations; with ppart = (PART, NPARTS) only the point sets with running number = PART mod NPARTS
    (among the point sets that pass the shape filter) -- parts by point set, so the enumeration is not repeated"""
    ca, cn, b = CLASSES[C]
    np_ = -1
    for pts in point_sets(b + 2):
        sh = shape_pts(pts)
        if sh == (0, 0) or sh[0] > ca or sh[1] > cn: continue
        np_ += 1
        if ppart and np_ % ppart[1] != ppart[0]: continue
        atoms = []
        for k in range(1, b + 1):
            for blk in itertools.combinations_with_replacement(pts, k):
                if k > 1 and shape_pts(blk) == (0, 0): continue      # chain poset: only singletons (Lemma 16.1)
                for e in range(len(catalogue(blk))): atoms.append((blk, e))
        P = set(pts)
        for r in range(1, 4):
            for combo in itertools.combinations_with_replacement(range(len(atoms)), r):
                blks = [atoms[t] for t in combo]
                if all(len(bl) == 1 for bl, e in blks): continue
                if {p for bl, e in blks for p in bl} != P: continue
                yield pts, blks

def assemble(blks):
    """U type d, A, X9, X27 rows in U coordinates (indices sorted by value, A before N)"""
    idx = []
    for t, (bl, e) in enumerate(blks):
        for i, p in enumerate(bl): idx.append((p[0], p[1] != 'A', t, i))
    idx.sort(); pos = {(t, i): u for u, (v, nA, t, i) in enumerate(idx)}
    s = len(idx); d = [v for v, nA, t, i in idx]; A = {u for u, (v, nA, t, i) in enumerate(idx) if not nA}
    X9 = []; X27 = []
    for t, (bl, e) in enumerate(blks):
        x9, x27 = catalogue(bl)[e]
        for src, dst in ((x9, X9), (x27, X27)):
            for row in src:
                r = [0] * s
                for i, c in enumerate(row): r[pos[(t, i)]] = c
                dst.append(r)
    return d, A, X9, X27

def cat_mode(C):
    ca, cn, b = CLASSES[C]; tot = 0
    seen = set()
    for pts in point_sets(b + 2):
        for k in range(2, b + 1):
            for blk in itertools.combinations_with_replacement(pts, k):
                sh = shape_pts(blk)
                if sh == (0, 0) or sh[0] > ca or sh[1] > cn: continue
                P3 = [(v, c, 1) for v, c in blk]
                key = (tuple(c for v, c in blk), tuple(sorted(tits475.relation(P3))))
                if key in seen: continue
                seen.add(key); n = len(catalogue(blk)); tot += n
                if n: print("CAT", C, "block", " ".join("%d%s" % p for p in blk), "shape", "%dA%dN" % sh,
                            "indecomposable orbits", n, flush=True)
    print("CATSUM", C, "block posets", len(seen), "indecomposable orbits", tot, flush=True)

def count_mode(C):
    t0 = time.time(); by = {}
    for pts, blks in configs(C):
        d, A, X9, X27 = assemble(blks)
        key = (len(d), tuple(sorted(len(bl) for bl, e in blks)))
        by[key] = by.get(key, 0) + 1
    tot = sum(by.values())
    for k in sorted(by): print("COUNT", C, "S", k[0], "blocks", "+".join(map(str, k[1])), by[k])
    print("COUNTSUM", C, "configs", tot, "sec", round(time.time() - t0, 1), flush=True)

def run_mode(C, part, nparts, drop, bypts=False):
    t0 = time.time(); models = {}; n = nf = nz = 0; secS = {}; cntS = {}
    gen = configs(C, (part, nparts)) if bypts else configs(C)
    for t, (pts, blks) in enumerate(gen):
        if not bypts and t % nparts != part: continue
        if len(models) > 2000: models.clear()          # bound the memory of the model cache
        t1 = time.time()
        d, A, X9, X27 = assemble(blks); s = len(d)
        key = tuple(d)
        if key not in models: models[key] = Model(d, MOD, drop)
        ok, sig = models[key].check(chain_K(X9, X27, A, s))
        n += 1; nf += (not ok); nz += sig
        secS[s] = secS.get(s, 0) + time.time() - t1; cntS[s] = cntS.get(s, 0) + 1
        if not ok and not drop:
            print("FAIL", C, "d", d, "A", sorted(A), "X9", X9, "X27", X27, flush=True)
    per = " ".join("S%d:%d/%.1fs" % (s, cntS[s], secS[s]) for s in sorted(cntS))
    print("RUN475" + ("P" if bypts else ""), C, "part", part, "of", nparts, "drop", sorted(drop), "checked", n, "sigma!=0", nz,
          "per-size[count/sec]", per, "sec", round(time.time() - t0, 1), "FAILING", nf, flush=True)
    return nf

if __name__ == '__main__':
    m, C = sys.argv[1], sys.argv[2]
    if m == 'cat': cat_mode(C); sys.exit(0)
    if m == 'count': count_mode(C); sys.exit(0)
    if m in ('run', 'runpts'):
        part, nparts = int(sys.argv[3]), int(sys.argv[4])
        drop = tuple(x for x in (sys.argv[5].split(',') if len(sys.argv) > 5 else []) if x and x != '-')
        f = run_mode(C, part, nparts, drop, m == 'runpts')
        sys.exit(0 if drop else (1 if f else 0))
