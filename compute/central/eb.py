"""MATH-184: e_b = pi((y-1)^b) in Z[<c>], y^2=c, pi(v0+v1 y)=v0+v1; test e_b in F_b(w)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lat import hnf, contains
from itertools import combinations_with_replacement as cwr

def mulp(a, b, N):
    r = [0]*N
    for i, x in enumerate(a):
        if x:
            for j, y in enumerate(b):
                if y: r[(i+j) % N] += x*y
    return r

def eseq(m, B):
    N = 2**m
    one = [1]+[0]*(N-1); tau = [-1, 1]+[0]*(N-2) if N > 1 else [0]
    e = [one, [0]*N]
    for b in range(B-1):
        e.append([tau_e - 2*x for tau_e, x in zip(mulp(tau, e[-2], N), e[-1])])
    return e

def F(m, w, b):
    """w[k] = weight of c^(2^k); ideal spanned by prod (c^j-1) with sum w >= b."""
    N = 2**m
    def wt(j):
        v = 0
        while j % 2 == 0: j //= 2; v += 1
        return w[v]
    gens = []
    frontier = [((), 0)]
    seen = set()
    while frontier:
        nf = []
        for js, s in frontier:
            for j in range(1, N):
                if js and j < js[-1]: continue
                k = js + (j,); ss = s + wt(j)
                if ss >= b: gens.append(k)
                else: nf.append((k, ss))
        frontier = nf
    rows = []
    for k in gens:
        p = [1]+[0]*(N-1)
        for j in k:
            f = [0]*N; f[0] -= 1; f[j % N] += 1
            p = mulp(p, f, N)
        for sh in range(N):
            rows.append(p[-sh:]+p[:-sh] if sh else p)
    return hnf(rows, N)

if __name__ == '__main__':
    B = int(sys.argv[1]) if len(sys.argv) > 1 else 12
    for m, ws in [(0, [()]), (1, [(1,), (2,), (3,)]), (2, [(2, 2), (2, 3), (2, 4), (3, 3), (3, 4), (3,5)]), (3, [(2, 3, 4), (2, 3, 3), (2,2,2),(2,3,5),(3,4,5)])]:
        e = eseq(m, B + 1)
        for w in ws:
            bad = [b for b in range(1, B + 1) if not contains(F(m, w, b), e[b])] if m else []
            print(f"|c|=2^{m} w={w}: fails at b={bad}")
