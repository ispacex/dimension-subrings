"""Validation of the truncated-Magnus method on the group of Bartholdi-Mikhailov, sec. 9.1
(arXiv:1805.10894): omega = [x01,x02]^32 [x01,x12]^64 [x02,x12]^128 lies in delta_4(G)."""
import sys, time
import numpy as np
from magnus import Trunc, Ring, howell, reduce_rows

n = int(sys.argv[1]) if len(sys.argv) > 1 else 4
T = Trunc(15, n)
R = Ring(2, 30)
g = [T.gen(i) for i in range(15)]
x01, x02, x12 = g[0], g[1], g[2]
y = {name: T.comm(g[a], g[a + 1]) for name, a in
     [("01", 3), ("02", 5), ("03", 7), ("12", 9), ("13", 11), ("23", 13)]}
P = T.power
rels = [
    T.prod(P(x01, 4), T.inv(y["01"])),
    T.prod(P(x02, 16), T.inv(y["02"])),
    T.prod(P(x12, 64), T.inv(y["12"])),
    T.prod(P(x01, -64), P(x02, -128), P(y["03"], -64)),
    T.prod(P(x01, 32), P(x12, -128), P(y["13"], -16)),
    T.prod(P(x02, 32), P(x12, 64), P(y["23"], -4)),
]
t = time.time()
A = T.ideal_rows(rels, R)
print("dim", len(T.monos), "rows", A.shape, flush=True)
H = howell(R, A)
print("howell rank", len(H), "time %.0fs" % (time.time() - t), flush=True)
tests = {
    "omega": T.prod(P(T.comm(x01, x02), 32), P(T.comm(x01, x12), 64), P(T.comm(x02, x12), 128)),
    "[x01,x02]^32": P(T.comm(x01, x02), 32),
    "x01": x01,
    "[x01,x02]": T.comm(x01, x02),
}
X = np.array([T.vec(v, R) for v in tests.values()])
ok = reduce_rows(R, H, X)
for name, o in zip(tests, ok):
    print("n=%d  %-14s in I_n + 2^30 T: %s" % (n, name, bool(o)))
