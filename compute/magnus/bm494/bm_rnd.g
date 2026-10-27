# MATH-412 (bm_rnd.g): sections M/N of the maximal subgroups M of bm_sec.g, for every normal N.
# (C2), (C3) in M/N say exactly: U2 = <x1, x2^9, x3^81, x4^729> gamma_2(M) <= gamma_2(M) N and
# U3 = <y_ij>^M gamma_3(M) <= gamma_3(M) N (bm_sec.g: N0 covers only N containing the elements).
# bm_gam.g: these give gamma_j(Q) <= gamma_j(M) N for all j (Q = G or G/<u>), and conversely
# (U3 <= gamma_3(Q)); bm_lay.g: gamma_5(M) = gamma_5(Q), gamma_6(M) = gamma_6(Q) for the open M.
# Search for a section: NTRY random greedy N, from the bottom layer up: for j = 6..2, while
# gamma_j(Q) is not in gamma_j(M) N, add a random element of gamma_j(Q) and take the normal closure in
# M; give up when w in N.  A found N is checked directly: Check (bm_sub.g) on M/N and w <> 1 there.
# A failure is no proof that no section exists.
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
if not IsBound(NTRY) then NTRY := 5; fi;
TryN := function(M, LM, LQ, wQ)
  local N, j, cnt;
  N := TrivialSubgroup(M); cnt := 0;
  for j in [6, 5 .. 2] do
    while not IsSubgroup(ClosureGroup(LM[j], N), LQ[j]) do
      N := NormalClosure(M, ClosureGroup(N, Random(LQ[j]))); cnt := cnt + 1;
      if wQ in N then return [fail, j, cnt]; fi;
    od;
  od;
  return [N, 0, cnt];
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
  LQ := ShallowCopy(LowerCentralSeriesOfGroup(Q));
  Print("w in gamma_j(Q): ", List(LQ, H -> wQ in H), ", gamma_6(Q) central: ", IsSubgroup(Centre(Q), LQ[6]), "\n");
  Ms := MaxOver(Q, xs);
  Print(c[1], ": log3|Q| = ", Log(Size(Q), 3), ", maximal subgroups containing x1..x4: ", Length(Ms), "\n");
  for M in Ms do
    nall := nall + 1;
    bad := Intersection(Check(M, ys{[1..4]}, ys{[5..8]}), NEED);
    t1 := Runtime();
    LM := ShallowCopy(LowerCentralSeriesOfGroup(M));
    while Length(LM) < 7 do Add(LM, TrivialSubgroup(M)); od;
    res := List([1..NTRY], k -> TryN(M, LM, LQ, wQ));
    found := First(res, r -> r[1] <> fail);
    ok := fail;
    if found <> fail then
      h := NaturalHomomorphismByNormalSubgroupNC(M, found[1]);
      ok := [Log(Size(Image(h)), 3), Check(Image(h), List(ys{[1..4]}, y -> Image(h, y)), List(ys{[5..8]}, y -> Image(h, y))), not IsOne(Image(h, wQ))];
      nobs := nobs + 1;
    fi;
    Print("  M: fails ", bad, ", tries (layer where w entered, elements added): ", List(res, r -> r{[2, 3]}),
      ", SECTION [log3|M/N|, failing in M/N, w <> 1]: ", ok, " (", Int((Runtime() - t1) / 1000), " s)\n");
  od;
  Print("  sec ", Int((Runtime() - t) / 1000), "\n");
od;
Print("maximal subgroups: ", nall, ", with a section found: ", nobs, "\n");
QUIT;
