# MATH-412 (bm_gam.g): sections M/N of the maximal subgroups M of bm_sec.g, for every normal N.
# (C2), (C3) in M/N say exactly: U2 = <x1, x2^9, x3^81, x4^729> gamma_2(M) <= gamma_2(M) N and
# U3 = <y_ij>^M gamma_3(M) <= gamma_3(M) N (bm_sec.g: N0 covers only N containing the elements).
# Obstruction: the fastest series with Gam_1 = M, Gam_2 = U2, Gam_3 = U3 [Gam_2, M],
# Gam_j = prod_{i < j} [Gam_i, Gam_{j-i}] (j >= 4).  By induction its image in Q = M/N lies in gamma_j(Q)
# for every such N; gamma_7(Q) = 1 (class of G is 6), so w in Gam_7 gives w in N: no section M/N
# satisfying (C2), (C3) keeps w.  (In G itself Gam = gamma and w notin Gam_7 = 1.)
Read("../3group.gap");
W := EvalString(w);;
XS := [x1, x2, x3, x4];;
YS2 := [x1, x2^9, x3^81, x4^729];;
YS3 := [LeftNormedComm([z2,z4,z1]), LeftNormedComm([z2,z4,z2]), LeftNormedComm([z2,z4,z3]), LeftNormedComm([z2,z4,z4])];;
LEV := [2, 2, 2, 2, 3, 3, 3, 3];;
NEED := [1, 2, 3, 4, 5, 6, 8];;
Check := function(H, y2, y3)
  local D, L3, bad;
  D := DerivedSubgroup(H);
  bad := Filtered([1..4], i -> not y2[i] in D);
  L3 := CommutatorSubgroup(D, H);
  Append(bad, Filtered([1..4], i -> not y3[i] in L3) + 4);
  return bad;
end;;
MaxOver := function(H, xs)
  local Fr, hom, V, S, res;
  Fr := FrattiniSubgroup(H);
  hom := NaturalHomomorphismByNormalSubgroupNC(H, Fr);
  V := Image(hom); S := Subgroup(V, List(xs, x -> Image(hom, x)));
  res := Filtered(MaximalSubgroups(V), K -> IsSubgroup(K, S));
  return List(res, K -> PreImage(hom, K));
end;;
# the series Gam_1..Gam_7 of M for the elements ys (positions NEED)
Gam := function(M, ys)
  local L, g, j, i, P;
  L := LowerCentralSeriesOfGroup(M);
  g := [M, ClosureGroup(L[2], ys{Filtered(NEED, p -> LEV[p] = 2)})];
  P := ClosureGroup(L[3], ys{Filtered(NEED, p -> LEV[p] = 3)});
  P := NormalClosure(M, P);
  g[3] := ClosureGroup(P, CommutatorSubgroup(g[2], M));
  for j in [4..7] do
    P := CommutatorSubgroup(g[j - 1], M);
    for i in [2..QuoInt(j, 2)] do P := ClosureGroup(P, CommutatorSubgroup(g[i], g[j - i])); od;
    g[j] := P;
  od;
  return g;
end;;
ZG := Centre(G);; O := Omega(ZG, 3, 1);;
us := [];;
for u in AsList(O) do
  if not IsOne(u) and not u in Group(W) and ForAll(us, v -> not u in Group(v)) then Add(us, u); fi;
od;
cases := [];;
if IsBound(LEVEL0) and LEVEL0 then Add(cases, ["G", IdentityMapping(G)]); fi;
for k in [1..Length(us)] do Add(cases, [Concatenation("G/<u", String(k), ">"), NaturalHomomorphismByNormalSubgroupNC(G, Group(us[k]))]); od;
# ONLY := [i, ...];; restricts to those cases (1 = G when LEVEL0, then the G/<u>), for parallel jobs
if IsBound(ONLY) then cases := cases{ONLY}; fi;
nall := 0;; nobs := 0;;
for c in cases do
  hom := c[2]; Q := Image(hom);
  xs := List(XS, x -> Image(hom, x));
  ys := List(Concatenation(YS2, YS3), y -> Image(hom, y)); wQ := Image(hom, W);
  t := Runtime();
  Ms := MaxOver(Q, xs);
  Print(c[1], ": log3|Q| = ", Log(Size(Q), 3), ", maximal subgroups containing x1..x4: ", Length(Ms), "\n");
  for M in Ms do
    nall := nall + 1;
    bad := Intersection(Check(M, ys{[1..4]}, ys{[5..8]}), NEED);
    t1 := Runtime();
    g := Gam(M, ys);
    ob := wQ in g[7];
    if ob then nobs := nobs + 1; fi;
    Print("  M: fails ", bad, ", log3|Gam_j| = ", List(g, H -> Log(Size(H), 3)), ", w in Gam_7: ", ob, " (", Int((Runtime() - t1) / 1000), " s)\n");
  od;
  Print("  sec ", Int((Runtime() - t) / 1000), "\n");
od;
Print("maximal subgroups: ", nall, ", with w in Gam_7: ", nobs, "\n");
QUIT;
