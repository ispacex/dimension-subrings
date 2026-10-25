# MATH-403: why BM's descent (by maximal subgroups of the centre avoiding w) stops at 3^494, and the
# three quotients G/<u>, |u| = 3, u in Omega_1(Z(G)) \ <w>: their centres and Omega_1.
Read("3group.gap");
W := EvalString(w);;
ZG := Centre(G);;
Print("w in Agemo(Z,3) = Phi(Z): ", W in Agemo(ZG, 3), "\n");
O := Omega(ZG, 3, 1);;
us := [];;
for u in AsList(O) do
  if not IsOne(u) and not u in Group(W) and ForAll(us, v -> not u in Group(v)) then Add(us, u); fi;
od;
for u in us do
  hom := NaturalHomomorphismByNormalSubgroupNC(G, Group(u));;
  Q := Image(hom);; wQ := Image(hom, W);;
  ZQ := Centre(Q);;
  Print("log3|Q| = ", Log(Size(Q), 3), ", w = 1: ", IsOne(wQ), ", AbelianInvariants(Z(Q)) = ",
        AbelianInvariants(ZQ), ", Omega_1(Z(Q)) = <w>: ", Omega(ZQ, 3, 1) = Group(wQ),
        ", u in gamma_6(G): ", u in LowerCentralSeriesOfGroup(G)[6], "\n");
od;
QUIT;
