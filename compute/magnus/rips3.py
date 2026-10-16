"""The 3-relator Rips-type group of Bartholdi-Mikhailov (arXiv:1805.10894, sec. 1.2)
  G = < e0,e1,e2,z | e0^4 = [z,e1][z,e2]^2, e1^16 = [z,e0]^-1 [z,e2]^4, e2^64 = [z,e0]^-2 [z,e1]^-4 >,
  alpha = [e0,e1]^32 [e0,e2]^64 [e1,e2]^128  (BM: alpha in D_4(G) minus gamma_4(G)).
Membership of alpha (and variants) in D_n(G) and D_n(G/gamma_4(G)) modulo 2^E via the
truncated Magnus algebra (magnus.py). 'False' is a proof of non-membership."""
import sys, itertools
import numpy as np
from magnus import Trunc, Ring, howell, reduce_rows

def run(n, class3, extra_tests=None):
    T = Trunc(4, n)
    R = Ring(2, 30)
    e0, e1, e2, z = (T.gen(i) for i in range(4))
    C, P, I = T.comm, T.power, T.inv
    rels = [
        T.prod(P(e0, 4), I(T.prod(C(z, e1), P(C(z, e2), 2)))),
        T.prod(P(e1, 16), I(T.prod(I(C(z, e0)), P(C(z, e2), 4)))),
        T.prod(P(e2, 64), I(T.prod(P(C(z, e0), -2), P(C(z, e1), -4)))),
    ]
    if class3:
        gens = [T.gen(i) for i in range(4)] + [I(T.gen(i)) for i in range(4)]
        for w in itertools.product(gens, repeat=4):
            rels.append(T.lnc(*w))
    A = T.ideal_rows(rels, R)
    H = howell(R, A)
    tests = {
        "alpha": T.prod(P(C(e0, e1), 32), P(C(e0, e2), 64), P(C(e1, e2), 128)),
        "[e0,e1]^32": P(C(e0, e1), 32),
        "[e0,e1,z]": T.lnc(e0, e1, z),
    }
    if extra_tests:
        tests.update(extra_tests(T))
    X = np.array([T.vec(v, R) for v in tests.values()])
    ok = reduce_rows(R, H, X)
    for name, o in zip(tests, ok):
        print("%s n=%d dim=%d  %-12s in I_n+2^30T: %s" % ("G/g4" if class3 else "G   ", n, len(T.monos), name, bool(o)), flush=True)

for n in (4, 5):
    run(n, False)
    run(n, True)
