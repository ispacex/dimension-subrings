# MATH-403 (bm_sec.g): sections M/N0 of maximal subgroups; built on bm_sub.g.
# MATH-403: subgroups and sections of the Bartholdi-Mikhailov 3-group with the witness w kept in D_7.
# BM's proof of Prop. 9.2 uses only: e_0 = x1, e_1 = x2, e_2 = x3, e_3 = x4 lie in H, and
#   (C2) x1, x2^9, x3^81, x4^729 lie in gamma_2(H)    (BM: e_i^(3^(2i)) = y_i of degree 2),
#   (C3) the y_ij = [z2,z4,z1], [z2,z4,z2], [z2,z4,z4] lie in gamma_3(H)   (degree 3; the file's choice of
#        witnesses for (2,3), (1,3), (0,2), y_01 = 1; [z2,z4,z3] is the file's extra pair (1,2), also tested),
# the relations of (9.2) being identities in G.  Then w in D_7(H); with gamma_7(H) <= gamma_7(G) = 1
# and w <> 1, H has D_7 <> gamma_7.  (C2), (C3) pass to quotients H/N, and w survives if w notin N.
# This file: for each Q = G/<u> of order 3^493 (bm_final.g), check (C2), (C3) in Q (positive control)
# and in each maximal subgroup M of Q containing x1..x4; for each M print which of the 8 elements
# fail.  Set LEVEL0 := true;; to also include G itself.
Read("../3group.gap");
W := EvalString(w);;
XS := [x1, x2, x3, x4];;
YS2 := [x1, x2^9, x3^81, x4^729];;
YS3 := [LeftNormedComm([z2,z4,z1]), LeftNormedComm([z2,z4,z2]), LeftNormedComm([z2,z4,z3]), LeftNormedComm([z2,z4,z4])];;
Print("in G: relations of (9.2) as in the file: ", ForAll(rels, r -> EvalString(r)), "\n");
# fail list: [] = all hold, else the positions (1..4 for Y2, 5..8 for Y3) that fail
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
ZG := Centre(G);; O := Omega(ZG, 3, 1);;
us := [];;
for u in AsList(O) do
  if not IsOne(u) and not u in Group(W) and ForAll(us, v -> not u in Group(v)) then Add(us, u); fi;
od;
cases := [];; hom := fail;;
if IsBound(LEVEL0) and LEVEL0 then Add(cases, ["G", IdentityMapping(G)]); fi;
for k in [1..Length(us)] do Add(cases, [Concatenation("G/<u", String(k), ">"), NaturalHomomorphismByNormalSubgroupNC(G, Group(us[k]))]); od;
# Sections: for M maximal in Q with x1..x4 in M, (C2), (C3) in M/N read d in gamma_k(M)N for each
# failing d.  The smallest normal N containing the failing elements themselves is
# N0 = NormalClosure(M, <failing d>); if w notin N0, then M/N0 satisfies (C2), (C3) (the failing d map
# to 1) and w <> 1 there: a smaller example.  If w in N0, every N containing all failing d kills w.
# (N with d*c in N, c in gamma_k(M), c <> 1, is not covered.)  Only the y_ij BM uses (positions 5, 6, 8)
# count; position 7 is the file's extra pair (1,2).
NEED := [1, 2, 3, 4, 5, 6, 8];;
for c in cases do
  hom := c[2]; Q := Image(hom);
  xs := List(XS, x -> Image(hom, x)); y2 := List(YS2, y -> Image(hom, y)); y3 := List(YS3, y -> Image(hom, y));
  ys := Concatenation(y2, y3); wQ := Image(hom, W);
  t := Runtime();
  Ms := MaxOver(Q, xs);
  Print(c[1], ": log3|Q| = ", Log(Size(Q), 3), ", maximal subgroups containing x1..x4: ", Length(Ms), "\n");
  for M in Ms do
    bad := Intersection(Check(M, y2, y3), NEED);
    if bad = [] then Print("  M: all conditions hold (log3|M| = ", Log(Size(M), 3), ")\n"); continue; fi;
    N0 := NormalClosure(M, Subgroup(M, ys{bad}));
    Print("  M: fails ", bad, ", log3|N0| = ", Log(Size(N0), 3), ", w in N0: ", wQ in N0);
    if not wQ in N0 then Print("  <-- SECTION log3|M/N0| = ", Log(Size(M) / Size(N0), 3)); fi;
    Print("\n");
  od;
  Print("  sec ", Int((Runtime() - t) / 1000), "\n");
od;
QUIT;
