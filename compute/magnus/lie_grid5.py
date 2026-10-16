"""Grid over the Bartholdi-Mikhailov (9.1) pattern at n = 5, p = 3 (MATH-42).

In f_i = 3^i e_i the ring (9.1) reads 3^{a_k} f_k = y_k and f_i + f_j = 3^c y_ij on the pairs
S = {01, 02, 13, 23}.  Here: y_k of weight 2, a in {0..3}^4, one c in {0..4} for all pairs, pair
weight w in {1, 2, 3} (w = 1 is a root, so c >= 1 there), and both signs f_i -/+ f_j.  For each
ring the whole of delta_5/gamma_5 is computed.
Usage: python lie_grid5.py WORKER NWORKERS  -> one JSON line per ring."""
import itertools
import json
import sys
import time

from liedim import Pres, analyse

S = [(0, 1), (0, 2), (1, 3), (2, 3)]


def build(a, c, w, sign):
    if w == 1:
        return build_roots(a, c, sign)
    gens = [("f%d" % i, 1) for i in range(4)] + [("y%d" % i, 2) for i in range(4)]
    gens += [("y%d%d" % ij, w) for ij in S]
    P = Pres(gens, n=5, p=3)
    f = [P.g("f%d" % i) for i in range(4)]
    for k in range(4):
        P.rel(P.add(P.sc(3 ** a[k], f[k]), P.sc(-1, P.g("y%d" % k))))
    for i, j in S:
        P.rel(P.add(f[i], P.sc(sign, f[j]), P.sc(-3 ** c, P.g("y%d%d" % (i, j)))))
    return P


def build_roots(a, c, s):
    """w = 1: the same ring with f1, f2, f3 eliminated through the roots on 01, 02, 13
    (f_i + s f_j = 3^c y_ij gives f_j = s (3^c y_ij - f_i)); only the relation on 23 stays."""
    gens = [("f0", 1), ("y01", 1), ("y02", 1), ("y13", 1), ("y23", 1)] + [("y%d" % i, 2) for i in range(4)]
    P = Pres(gens, n=5, p=3)
    q = 3 ** c
    f = [P.g("f0")]
    f.append(P.sc(s, P.add(P.sc(q, P.g("y01")), P.sc(-1, f[0]))))
    f.append(P.sc(s, P.add(P.sc(q, P.g("y02")), P.sc(-1, f[0]))))
    f.append(P.sc(s, P.add(P.sc(q, P.g("y13")), P.sc(-1, f[1]))))
    for k in range(4):
        P.rel(P.add(P.sc(3 ** a[k], f[k]), P.sc(-1, P.g("y%d" % k))))
    P.rel(P.add(f[2], P.sc(s, f[3]), P.sc(-q, P.g("y23"))))
    return P


def grid():
    for w in (1, 2, 3):
        for sign in (1, -1):
            for c in range(1 if w == 1 else 0, 5):
                for a in itertools.product(range(4), repeat=4):
                    yield a, c, w, sign


def main():
    me, nw = int(sys.argv[1]), int(sys.argv[2])
    for t, (a, c, w, sign) in enumerate(grid()):
        if t % nw != me:
            continue
        t0 = time.time()
        P = build(a, c, w, sign)
        wit, _ = analyse(P, verbose=False)
        print(json.dumps({"a": a, "c": c, "w": w, "sign": sign, **P.inv,
                          "witness": [[o, [P.names[i] for i in m]] for o, m in wit],
                          "sec": round(time.time() - t0, 2)}), flush=True)


if __name__ == "__main__":
    main()
