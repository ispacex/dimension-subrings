# MATH-403: the 3-group of order 3^494 of Bartholdi-Mikhailov (arXiv:1805.10894, Prop. 9.3,
# ancillary file ../3group.gap, unchanged).  The file's w equals BM's omega = [e2,e1,e0]^(3^9)
# (e_i = x_{i+1}), and the relations of (9.2) hold in G with y_i, y_ij commutators in gamma_2,
# gamma_3; so (9.2) maps to G (not onto), omega -> w, and BM Prop. 9.2 gives w in D_7(G).  Checks: both facts, order, class, LCS,
# w notin gamma_7, w^3 in gamma_7,
# the centre, and for every subgroup <u> of order 3 in Omega_1(Z) whether w survives modulo
# gamma_7(G)<u> (every proper quotient factors through some G/<u>).
Read("../3group.gap");
W := EvalString(w);;
Print("all relations hold: ", ForAll(rels, r -> EvalString(r)), ", w = [x3,x2,x1]^(3^9): ",
      W = Comm(Comm(x3, x2), x1)^19683, "\n");
L := LowerCentralSeriesOfGroup(G);;
Print("log3|G| = ", Log(Size(G), 3), ", rank ", Length(MinimalGeneratingSet(G)), "\n");
Print("LCS log3 = ", List(L, H -> Log(Size(H), 3)), "\n");
g7 := L[7];;
Print("w in gamma_7: ", W in g7, ", w^3 in gamma_7: ", W^3 in g7, ", w = 1: ", IsOne(W), "\n");
ZG := Centre(G);;
O := Omega(ZG, 3, 1);;
Print("log3|Z| = ", Log(Size(ZG), 3), ", AbelianInvariants(Z) = ", AbelianInvariants(ZG),
      ", log3|Omega_1(Z)| = ", Log(Size(O), 3), "\n");
Print("w in Z: ", W in ZG, ", w in Omega_1(Z): ", W in O, "\n");
if Log(Size(O), 3) <= 8 then
  us := Filtered(AsList(O), u -> not IsOne(u));;
  seen := [];; surv := 0;; tot := 0;;
  for u in us do
    if ForAny(seen, v -> u in Group(v)) then continue; fi;
    Add(seen, u); tot := tot + 1;
    if not W in ClosureGroup(g7, u) then surv := surv + 1; fi;
  od;
  Print("subgroups of order 3 in Omega_1(Z): ", tot, ", with w surviving mod gamma_7<u>: ", surv, "\n");
else
  Print("Omega_1(Z) too large to enumerate\n");
fi;
QUIT;
