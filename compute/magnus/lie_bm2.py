"""Check of liedim.py on the 2-torsion Lie ring of Bartholdi-Mikhailov, sec. 9.1 (arXiv:1805.10894):
omega = 2^5 [x02, x12] lies in delta_4 minus gamma_4 and 2 omega in gamma_4."""
from liedim import Pres, analyse

P = Pres([(g, 1) for g in ("x01", "x02", "x12")] +
         [(g, 2) for g in ("y01", "y02", "y03", "y12", "y13", "y23")], n=4, p=2)
L, g = P.lin, P.g
P.rel(P.add(L(x01=4), P.sc(-1, g("y01"))))
P.rel(P.add(L(x02=16), P.sc(-1, g("y02"))))
P.rel(P.add(L(x12=64), P.sc(-1, g("y12"))))
P.rel(P.add(L(x01=-64, x02=-128), P.sc(-64, g("y03"))))
P.rel(P.add(L(x01=32, x12=-128), P.sc(-16, g("y13"))))
P.rel(P.add(L(x02=32, x12=64), P.sc(-4, g("y23"))))
w = P.sc(32, P.br(g("x02"), g("x12")))
analyse(P, {"omega": w, "2omega": P.sc(2, w), "[x01,x02]": P.br(g("x01"), g("x02"))})
