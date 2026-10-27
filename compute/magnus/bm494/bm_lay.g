# MATH-412 (bm_lay.g): sections M/N of the maximal subgroups M of bm_sec.g, for every normal N.
# (C2), (C3) in M/N say exactly: U2 = <x1, x2^9, x3^81, x4^729> gamma_2(M) <= gamma_2(M) N and
# U3 = <y_ij>^M gamma_3(M) <= gamma_3(M) N (bm_sec.g: N0 covers only N containing the elements).
# bm_gam.g: the series Gam_j these generate equals gamma_j(Q) (Q = G or G/<u>), so (C2), (C3) give
# gamma_j(Q) <= gamma_j(M) N for all j.  Layer obstruction: B = N cap A, A = gamma_6(Q), is central in M,
# misses w and has B gamma_6(M) = A (Dedekind, gamma_6(M) <= A).  If w in A, enlarge B to be maximal
# missing w: A/B cyclic, B the kernel of a linear character chi of A with chi(w) <> 1.  If no such
# kernel B has B gamma_6(M) = A, then w in N for every N: no section M/N satisfying (C2), (C3) keeps w.
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
# kernels B of linear characters of the abelian A with w notin B and B C = A
Layer := function(A, C, wQ)
  local iso, P, chis, n;
  iso := IsomorphismPcGroup(A); P := Image(iso);
  chis := Filtered(LinearCharacters(P), chi -> not IsOne(Image(iso, wQ)^chi));
  n := Number(chis, chi -> Size(ClosureGroup(KernelOfCharacter(chi), Image(iso, C))) = Size(P));
  return [Length(chis), n];
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
  LQ := LowerCentralSeriesOfGroup(Q);
  Print("w in gamma_j(Q): ", List(LQ, H -> wQ in H), ", gamma_6(Q) central: ", IsSubgroup(Centre(Q), LQ[6]), "\n");
  Ms := MaxOver(Q, xs);
  Print(c[1], ": log3|Q| = ", Log(Size(Q), 3), ", maximal subgroups containing x1..x4: ", Length(Ms), "\n");
  for M in Ms do
    nall := nall + 1;
    bad := Intersection(Check(M, ys{[1..4]}, ys{[5..8]}), NEED);
    t1 := Runtime();
    LM := LowerCentralSeriesOfGroup(M);
    if Length(LM) >= 6 then C6 := LM[6]; else C6 := TrivialSubgroup(M); fi;
    if wQ in LQ[6] then ly := Layer(LQ[6], C6, wQ); else ly := [fail, fail]; fi;
    ob := ly[2] = 0;
    if ob then nobs := nobs + 1; fi;
    Print("  M: fails ", bad, ", log3|gamma_j(M)| = ", List(LM, H -> Log(Size(H), 3)), ", w in gamma_6(M): ", wQ in C6,
      ", characters chi(w) <> 1: ", ly[1], ", with ker . gamma_6(M) = A: ", ly[2], ", obstruction: ", ob, " (", Int((Runtime() - t1) / 1000), " s)\n");
  od;
  Print("  sec ", Int((Runtime() - t) / 1000), "\n");
od;
Print("maximal subgroups: ", nall, ", with the layer obstruction: ", nobs, "\n");
QUIT;
