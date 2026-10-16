"""Positive control for 3-torsion: the Lie ring (9.1) of Bartholdi-Mikhailov (arXiv:1805.10894,
Prop. 9.1, relations as in their anq input, appendix A): omega = 3^9 [e2, e1, e0] lies in
delta_7 minus gamma_7 and 3 omega in gamma_7.  All relators are linear in the generators, so the
computation splits by word length; omega has length 3, so the length-3 block (and, for the whole
delta_7/gamma_7 there, nothing else) is computed.  Usage: python lie_bm3.py [blocks, e.g. 3 or 2,3,4]"""
import sys

from liedim import Pres, analyse

blocks = [int(b) for b in sys.argv[1].split(",")] if len(sys.argv) > 1 else [3]
P = Pres([("e%d" % i, 1) for i in range(4)] + [("y%d" % i, 2) for i in range(4)] +
         [(y, 3) for y in ("y01", "y02", "y13", "y23")], n=7, p=3)
g, sc, add = P.g, P.sc, P.add
for i, a in enumerate((0, 2, 4, 6)):
    P.rel(add(sc(3 ** a, g("e%d" % i)), sc(-1, g("y%d" % i))))
for (i, j, a, b, c) in ((0, 1, 11, 12, 10), (0, 2, 10, 12, 8), (1, 3, 9, 11, 4), (2, 3, 9, 10, 2)):
    # 3^b e_j + 3^a e_i = 3^c y_ij
    P.rel(add(sc(3 ** a, g("e%d" % i)), sc(3 ** b, g("e%d" % j)), sc(-3 ** c, g("y%d%d" % (i, j)))))
w = sc(3 ** 9, P.lnc(g("e2"), g("e1"), g("e0")))
analyse(P, {"omega": w, "3omega": sc(3, w), "omega/3": sc(3 ** 8, P.lnc(g("e2"), g("e1"), g("e0")))},
        blocks=blocks)
