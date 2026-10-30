# MATH-414 (bm_z8.g): the elements of Zbar (bm_grnq.g) that grnq finds in D_6(Q), and small quotients
# keeping them.  For Q = G or G/<u_k>: the basis of Zbar/N as in bm_grnq.g; for the index IDX (from the
# grnq log, "span Zbar: in D_6"), z = that basis element: its order, z^3, whether z lies in gamma_6(Q), and
# a descent Q -> Q/K, K <= Z(Q) with Z(Q)/K cyclic and z notin K, until Z is cyclic: the order of the quotient and its Jennings count (as bm_jen.g).  If it is <= 3^9, z is not
# in D_7(Q) (MATH-403: D_n = gamma_n up to order 3^9, and gamma_7 = 1).
Read("../3group.gap");;
G0 := Parent(G);; fp := FamilyPcgs(G0);; W0 := EvalString(w);;
if not IsBound(CASE) then CASE := "G"; fi;
if not IsBound(IDX) then IDX := 8; fi;
ZG := Centre(G0);; O := Omega(ZG, 3, 1);;
us := [];;
for u in AsList(O) do
  if not IsOne(u) and not u in Group(W0) and ForAll(us, v -> not u in Group(v)) then Add(us, u); fi;
od;
extra := [];; if CASE <> "G" then extra := [us[Int(CASE{[3..Length(CASE)]})]]; fi;
N := NormalClosure(G0, Group(Concatenation(extra, [W0])));;
hom := NaturalHomomorphismByNormalSubgroupNC(G0, N);;
Zb := PreImage(hom, Omega(Centre(Image(hom)), 3, 1));;
h2 := NaturalHomomorphismByNormalSubgroupNC(Zb, N);;
span := List(Pcgs(Image(h2)), y -> PreImagesRepresentative(h2, y));;
z := span[IDX];;
q := NaturalHomomorphismByNormalSubgroupNC(G0, NormalClosure(G0, Group(Concatenation(extra, [One(G0)]))));;
Q := Image(q);; zQ := Image(q, z);; wQ := Image(q, W0);;
LQ := LowerCentralSeriesOfGroup(Q);;
Print(CASE, ": z = span[", IDX, "], order ", Order(zQ), ", z^3 in <w>: ", zQ^3 in Group(wQ), ", z^3 = 1: ", IsOne(zQ^3),
      ", z in gamma_6: ", zQ in LQ[6], ", z in gamma_5: ", zQ in LQ[5], "\n");
NDEG := 7;;
JenDims := function(H)
  local K, hm, B, J, n;
  K := NormalClosure(H, Subgroup(H, List(Pcgs(H), g -> g^9)));
  hm := NaturalHomomorphismByNormalSubgroupNC(H, K); B := Image(hm);
  J := [B];
  for n in [2..NDEG] do Add(J, ClosureGroup(CommutatorSubgroup(J[n - 1], B), Agemo(J[QuoInt(n + 2, 3)], 3))); od;
  return List([1..NDEG - 1], k -> LogInt(Index(J[k], J[k + 1]), 3));
end;;
JenCount := function(d)
  local c, w, i, new, k;
  c := List([1..NDEG], k -> 0); c[1] := 1;
  for w in [1..Length(d)] do for i in [1..d[w]] do
    new := ShallowCopy(c);
    for k in [1..NDEG] do
      if k - w >= 1 then new[k] := new[k] + c[k - w]; fi;
      if k - 2 * w >= 1 then new[k] := new[k] + c[k - 2 * w]; fi;
    od; c := new; od; od;
  return Sum(c);
end;;
# descent: each step kills a subgroup K of Z(cur) with Z(cur)/K cyclic and z notin K (K central, so
# normal); it stops when Z(cur) is cyclic (then every nontrivial subgroup of
# Z(cur) contains z, as z has order 3)
cur := Q;; zc := zQ;; steps := 0;; t := Runtime();;
while true do
  if Order(zc) <> 3 then
    hh := NaturalHomomorphismByNormalSubgroupNC(cur, Group(zc^3)); cur := Image(hh); zc := Image(hh, zc); steps := steps + 1; continue;
  fi;
  ZC := Centre(cur);
  if IsCyclic(ZC) then break; fi;
  # Z = sum of cyclic <e_i>, z = sum c_i e_i; for i with c_i <> 0 and e_i of least order, K = <e_j, j <> i>
  # (Z/K cyclic, z notin K)
  es := IndependentGeneratorsOfAbelianGroup(ZC);
  cz := IndependentGeneratorExponents(ZC, zc);
  cand := Filtered([1..Length(es)], i -> cz[i] mod Order(es[i]) <> 0);
  Sort(cand, function(a, b) return Order(es[a]) < Order(es[b]); end);
  K := Subgroup(ZC, es{Difference([1..Length(es)], [cand[1]])});
  if zc in K then Error("z in K"); fi;
  hh := NaturalHomomorphismByNormalSubgroupNC(cur, K); cur := Image(hh); zc := Image(hh, zc); steps := steps + 1;
  Print("  step ", steps, ": order 3^", LogInt(Size(cur), 3), "\n");
od;
d := JenDims(cur);;
Print(CASE, ": descent of ", steps, " steps (", Int((Runtime() - t) / 1000), " s) to order 3^", LogInt(Size(cur), 3),
      ", class ", NilpotencyClassOfGroup(cur), ", rank ", Length(MinimalGeneratingSet(cur)), ", Jennings d = ", d, " N = ", JenCount(d), "\n");
if LogInt(Size(cur), 3) <= 9 then Print(CASE, ": order <= 3^9, so z is not in D_7(Q) (MATH-403)\n"); fi;
Print("bm_z8 done\n");
QUIT;
