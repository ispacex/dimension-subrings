# MATH-413 (bm_tensor.g): the layer-3 test of bm_mul.g for a subgroup H of Q (Q = G or G/<u>) depends
# only on the image V of H in Qb = Q/gamma_2(Q)Q^{3^6}.  For v, v_i in H and y in Y = {x1, x2^9, x3^81,
# x4^729}: the rows a are [y, v] (Gam_3(H) = [U, H] mod gamma_3(H) gamma_4(Q)), the rows c are
# [v1, v2, v3] (gamma_3(H) mod gamma_4(Q)), the functionals are lam(g) = [g, m1, m2, m3] with m_i in H.
# Changing an element of H by gamma_2(Q) moves these by gamma_4(Q) (resp. gamma_7(Q) = 1), changing it by
# a 3^6-th power multiplies lam by a 3^6-th power in A = gamma_6(Q) = C_{3^6}; all are multilinear.  So
# it suffices to tabulate, for generators e_1..e_r of Qb (lifted to Q), the logs in A = <a0> of
#   TA[y][i][j1][j2][j3] = [y, e_i, e_j1, e_j2, e_j3],   TC[i1][i2][i3][j1][j2][j3] = [e_i1, .., e_j3].
# Output: lines "CASE name", "ORD o_1 .. o_r" (orders of e_i in Qb, capped at 3^6), "W log(w)",
# "TA y i j1 j2 j3 v", "TC i1 i2 i3 j1 j2 j3 v".
Read("../3group.gap");
W := EvalString(w);;
YS2 := [x1, x2^9, x3^81, x4^729];;
ZG := Centre(G);; O := Omega(ZG, 3, 1);;
us := [];;
for u in AsList(O) do
  if not IsOne(u) and not u in Group(W) and ForAll(us, v -> not u in Group(v)) then Add(us, u); fi;
od;
cases := [["G", IdentityMapping(G)]];;
for k in [1..Length(us)] do Add(cases, [Concatenation("G/<u", String(k), ">"), NaturalHomomorphismByNormalSubgroupNC(G, Group(us[k]))]); od;
OUT := Concatenation(GAPInfo.SystemEnvironment.JOB_OUT, "/tensor.txt");;
PrintTo(OUT, "");
for c in cases do
  hom := c[2]; Q := Image(hom);
  ys := List(YS2, y -> Image(hom, y)); wQ := Image(hom, W);
  LQ := LowerCentralSeriesOfGroup(Q);
  A := LQ[6];
  if Length(LQ) <> 7 or not IsCyclic(A) or Size(A) <> 3^6 then Error("A is not C_729"); fi;
  a0 := First(GeneratorsOfGroup(A), g -> Order(g) = 3^6);
  if a0 = fail then a0 := MinimalGeneratingSet(A)[1]; fi;
  zs := List([0..3^6 - 1], k -> a0^k);
  lg := function(h) local p; p := Position(zs, h); if p = fail then Error("not in A"); fi; return p - 1; end;
  hb := NaturalHomomorphismByNormalSubgroupNC(Q, LQ[2]);
  Ab := Image(hb);
  gens := IndependentGeneratorsOfAbelianGroup(Ab);
  es := List(gens, g -> PreImagesRepresentative(hb, g));
  r := Length(es);
  Print(c[1], ": AbelianInvariants ", AbelianInvariants(Q), ", r = ", r, "\n");
  AppendTo(OUT, "CASE ", c[1], "\n");
  AppendTo(OUT, "ORD"); for g in gens do AppendTo(OUT, " ", Minimum(Order(g), 3^6)); od; AppendTo(OUT, "\n");
  AppendTo(OUT, "W ", lg(wQ), "\n");
  for y in [1..4] do for i in [1..r] do
    h1 := Comm(ys[y], es[i]);
    for j1 in [1..r] do h2 := Comm(h1, es[j1]); for j2 in [1..r] do h3 := Comm(h2, es[j2]);
      for j3 in [1..r] do AppendTo(OUT, "TA ", y, " ", i, " ", j1, " ", j2, " ", j3, " ", lg(Comm(h3, es[j3])), "\n"); od;
    od; od;
  od; od;
  for i1 in [1..r] do for i2 in [1..r] do for i3 in [1..r] do
    g3 := LeftNormedComm([es[i1], es[i2], es[i3]]);
    for j1 in [1..r] do h1 := Comm(g3, es[j1]); for j2 in [1..r] do h2 := Comm(h1, es[j2]);
      for j3 in [1..r] do AppendTo(OUT, "TC ", i1, " ", i2, " ", i3, " ", j1, " ", j2, " ", j3, " ", lg(Comm(h2, es[j3])), "\n"); od;
    od; od;
  od; od; od;
  Print(c[1], " done\n");
od;
QUIT;
