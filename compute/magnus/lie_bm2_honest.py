"""The ring of lie_bm2.py with every degree-2 generator y written as [z, z'] of fresh generators
(the honest reading of Bartholdi-Mikhailov's notation): delta_4/gamma_4 must again be Z/2."""
from liedim import Pres, analyse

ys = ("y01", "y02", "y03", "y12", "y13", "y23")
P = Pres([(g, 1) for g in ("x01", "x02", "x12")] +
         [(y + s, 1) for y in ys for s in ("a", "b")], n=4, p=2)
L, g = P.lin, P.g
Y = {y: P.br(g(y + "a"), g(y + "b")) for y in ys}
P.rel(P.add(L(x01=4), P.sc(-1, Y["y01"])))
P.rel(P.add(L(x02=16), P.sc(-1, Y["y02"])))
P.rel(P.add(L(x12=64), P.sc(-1, Y["y12"])))
P.rel(P.add(L(x01=-64, x02=-128), P.sc(-64, Y["y03"])))
P.rel(P.add(L(x01=32, x12=-128), P.sc(-16, Y["y13"])))
P.rel(P.add(L(x02=32, x12=64), P.sc(-4, Y["y23"])))
analyse(P, {"32[x01,x02]": P.sc(32, P.br(g("x01"), g("x02")))})
