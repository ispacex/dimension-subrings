#!/usr/bin/env python3
"""MATH-475 (wiki 891 Sec. 21): posets of elementary data mod 27 and the Tits form.

Elementary data at k = 3 (wiki 891 Sec. 14.2, 16.1) are representations of the poset P ⊔ {h}: one point per
(value of d, class A/N) with multiplicity = number of indices, h (the subspace H) incomparable to all of P.
Order (p -> q: columns of p may be added to columns of q): same class and d(p) >= d(q); or p in A, q in N with
d(q) <= 3 d(p).  Tits form of a poset S (Drozd 1974):  q(x) = x_0^2 + sum_p x_p^2 + sum_{p<q} x_p x_q - x_0 sum_p x_p.
For S of finite type the dimension vectors of indecomposables are exactly the positive roots (q(x) = 1) [literature,
Drozd 1974 / Kleiner 1972]; here this module only computes roots.

  points(d, A)        list of points (d, cls, mult) in order of d (A before N at equal d) and the relation
  signature(d, A)     canonical key: ((cls, mult) ...) and the set of ordered related pairs of point positions
  maxcols(d, A)       max sum_{p in P} x_p over positive roots with x_p <= mult_p, x_0 <= sum_p x_p (S spanned
                      by the columns), x_h <= x_0 -- the predicted largest number of columns of an indecomposable
  core TAG            roots of the abstract core posets used in the text ('21', '22', 'N', '11', '111', '31')
"""
import itertools, sys

def points(d, A):
    pts = {}
    for h, v in enumerate(d):
        c = 'A' if h in A else 'N'
        pts[(v, c)] = pts.get((v, c), 0) + 1
    P = sorted(pts, key=lambda p: (p[0], p[1] != 'A'))
    return [(v, c, pts[(v, c)]) for v, c in P]

def related(p, q):
    """p -> q (p != q as points): columns of p may be added to columns of q"""
    (dp, cp), (dq, cq) = p[:2], q[:2]
    if cp == cq: return dp >= dq
    return cp == 'A' and cq == 'N' and dq <= 3 * dp

def relation(P):
    return frozenset((i, j) for i in range(len(P)) for j in range(len(P)) if i != j and related(P[i], P[j]))

def signature(d, A):
    P = points(d, A)
    return (tuple((c, m) for v, c, m in P), tuple(sorted(relation(P))))

def roots(npts, less, caps, x0max):
    """positive roots of the Tits form of (P with relation 'less') ⊔ {h}; x_p <= caps[p]; returns (x0, xP, xh)"""
    out = []
    for xP in itertools.product(*[range(c + 1) for c in caps]):
        sP = sum(xP)
        for x0 in range(0, min(x0max, max(sP, 1)) + 1):
            for xh in range(0, x0 + 1):
                q = x0 * x0 + sum(v * v for v in xP) + xh * xh - x0 * (sP + xh)
                q += sum(xP[i] * xP[j] for i, j in less)
                if q == 1: out.append((x0, xP, xh))
    return out

def maxcols(d, A):
    P = points(d, A); rel = relation(P)
    # each comparable unordered pair counted once (p<q); same-point pairs never (x_p^2 term)
    less = {(min(i, j), max(i, j)) for i, j in rel}
    R = [r for r in roots(len(P), less, [m for v, c, m in P], sum(m for v, c, m in P))
         if r[0] >= 1 and sum(r[1]) >= 1 and r[0] <= sum(r[1])]
    return max(sum(r[1]) for r in R) if R else 0

CORES = {'11': [1, 1], '21': [2, 1], '22': [2, 2], '31': [3, 1], '111': [1, 1, 1]}

def core_roots(tag, bound=6):
    if tag == 'N':          # a2 -> a1, n1 -> n2, a2 -> n2 (staircase 2A2N)
        npts, less = 4, {(0, 1), (2, 3), (0, 3)}
    else:
        L = CORES[tag]; npts = sum(L); less = set(); o = 0
        for l in L:
            less |= {(o + i, o + j) for i in range(l) for j in range(i + 1, l)}; o += l
    R = roots(npts, less, [bound] * npts, bound)
    return [r for r in R if not (r[0] == 0) and sum(r[1]) >= 1 and r[0] <= sum(r[1])], npts

if __name__ == '__main__':
    if sys.argv[1] == 'core':
        for tag in sys.argv[2:]:
            R, n = core_roots(tag)
            print("CORE", tag, "points", n, "roots(x0>=1, S spanned by columns)", len(R),
                  "maxcols", max(sum(r[1]) for r in R))
            for r in sorted(R, key=lambda r: (sum(r[1]), r)): print("   x0=%d xP=%s xh=%d" % r)
    elif sys.argv[1] == 'maxcols':
        d = [int(a) for a in sys.argv[2].split(',')]; A = {int(a) for a in sys.argv[3].split(',') if a}
        print(points(d, A), maxcols(d, A))
