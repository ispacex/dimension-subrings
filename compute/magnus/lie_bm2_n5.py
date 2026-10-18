"""Positive control at n = 5: the ring of lie_bm2.py with y01, y02, y03 of degree n - 2 = 3
(Bartholdi-Mikhailov, sec. 9.1: "let y_{0j} have degree n-2") must have 2-torsion in delta_5/gamma_5."""
from liedim import Pres, analyse

P = Pres([(g, 1) for g in ("x01", "x02", "x12")] +
         [(g, 3) for g in ("y01", "y02", "y03")] +
         [(g, 2) for g in ("y12", "y13", "y23")], n=5, p=2)
L, g = P.lin, P.g
P.rel(P.add(L(x01=4), P.sc(-1, g("y01"))))
P.rel(P.add(L(x02=16), P.sc(-1, g("y02"))))
P.rel(P.add(L(x12=64), P.sc(-1, g("y12"))))
P.rel(P.add(L(x01=-64, x02=-128), P.sc(-64, g("y03"))))
P.rel(P.add(L(x01=32, x12=-128), P.sc(-16, g("y13"))))
P.rel(P.add(L(x02=32, x12=64), P.sc(-4, g("y23"))))
b = P.br
analyse(P, {"32[x01,x02]": P.sc(32, b(g("x01"), g("x02"))),
            "64[x01,x12]": P.sc(64, b(g("x01"), g("x12"))),
            "128[x02,x12]": P.sc(128, b(g("x02"), g("x12")))})
