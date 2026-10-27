# MATH-412 (bm_mul.g): sections M/N of the maximal subgroups M of bm_sec.g, for every normal N.
# (C2), (C3) in M/N say exactly: U2 = <x1, x2^9, x3^81, x4^729> gamma_2(M) <= gamma_2(M) N and
# U3 = <y_ij>^M gamma_3(M) <= gamma_3(M) N (bm_sec.g: N0 covers only N containing the elements).
# bm_gam.g: these are equivalent to gamma_j(Q) <= gamma_j(M) N for all j (Q = G or G/<u>).
# Multilinear obstruction.  Let A = gamma_6(Q) (central), K = a subgroup of A with A/K cyclic and
# w notin K (every N cap A missing w lies in such a K).  For g in gamma_j(Q) and x_1..x_{6-j} in M,
# lam(g) = [g, x_1, ..., x_{6-j}] lies in A and is a homomorphism of gamma_j(Q) killing gamma_{j+1}(Q)
# (gamma_7(Q) = 1).  If a in gamma_j(Q), then a c in N for some c in gamma_j(M), so lam(a) lam(c) in
# N cap A <= K for all lam at once.  With x_i running over generators of M mod Phi(M) (lam is
# multilinear mod gamma_7), this is: the row (log lam(a))_lam lies in the Z/3^f-span of the rows of
# the c in gamma_j(M).  If for every K some layer j and some a fail, no N exists: w in N for every
# section M/N satisfying (C2), (C3).  Layers JS (default [3..6]; layer 2 has r^4 columns).
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
if not IsBound(JS) then JS := [3..6]; fi;
# greedy representatives of H modulo the subgroup D (by the pcgs of H)
Reps := function(H, D)
  local r, S, g;
  r := []; S := D;
  for g in Pcgs(H) do
    if not g in S then Add(r, g); S := ClosureGroup(S, g); fi;
  od;
  return r;
end;;
# positions in AL (sorted A) of all [g, x_1, .., x_k], x_i in xs
Lam := function(g, xs, k, AL)
  local cur, i;
  cur := [g];
  for i in [1..k] do cur := Concatenation(List(cur, h -> List(xs, x -> Comm(h, x)))); od;
  return List(cur, function(h) local p; p := PositionSorted(AL, h);
    if p > Length(AL) or AL[p] <> h then Error("commutator not in A"); fi; return p; end);
end;;
# v in the Z-row span of the HNF H (full column rank, upper triangular)?
InHNF := function(H, v)
  local v1, row, p, q;
  v1 := ShallowCopy(v);
  for row in H do
    p := PositionNonZero(row);
    if p > Length(row) then continue; fi;
    if v1[p] mod row[p] <> 0 then return false; fi;
    q := v1[p] / row[p]; v1 := v1 - q * row;
  od;
  return IsZero(v1);
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
  while Length(LQ) < 8 do Add(LQ, TrivialSubgroup(Q)); od;
  A := LQ[6]; AL := AsSSortedList(A);
  iso := IsomorphismPcGroup(A); P := Image(iso);
  Ks := Set(List(Filtered(LinearCharacters(P), chi -> not IsOne(Image(iso, wQ)^chi)), chi -> PreImage(iso, KernelOfCharacter(chi))));
  # log tables of A -> A/K = Z/3^f
  Tab := List(Ks, function(K)
    local h, I, z, zs;
    h := NaturalHomomorphismByNormalSubgroupNC(A, K); I := Image(h);
    z := First(AsList(I), y -> Order(y) = Size(I)); zs := List([0..Size(I) - 1], k -> z^k);
    return [Size(I), List(AL, y -> Position(zs, Image(h, y)) - 1)];
  end);
  Print("|A| = 3^", Log(Size(A), 3), ", kernels K: ", Length(Ks), ", orders of A/K: ", Collected(List(Tab, tb -> tb[1])), "\n");
  Ms := MaxOver(Q, xs);
  Print(c[1], ": log3|Q| = ", Log(Size(Q), 3), ", maximal subgroups containing x1..x4: ", Length(Ms), "\n");
  for M in Ms do
    nall := nall + 1;
    bad := Intersection(Check(M, ys{[1..4]}, ys{[5..8]}), NEED);
    t1 := Runtime();
    LM := ShallowCopy(LowerCentralSeriesOfGroup(M));
    while Length(LM) < 8 do Add(LM, TrivialSubgroup(M)); od;
    gm := Reps(M, FrattiniSubgroup(M));
    data := [];
    for j in JS do
      ar := Reps(LQ[j], ClosureGroup(LM[j], LQ[j + 1]));
      if ar = [] then continue; fi;
      cr := Reps(LM[j], LQ[j + 1]);
      Add(data, [j, List(ar, g -> Lam(g, gm, 6 - j, AL)), List(cr, g -> Lam(g, gm, 6 - j, AL))]);
    od;
    t2 := Runtime();
    # K passes if every a of every layer is in the span of the c
    pass := Filtered([1..Length(Ks)], k -> ForAll(data, function(d)
        local f, X, H;
        f := Tab[k][1];
        X := List(d[3], cv -> List(cv, p -> Tab[k][2][p]));
        Append(X, f * IdentityMat(Length(d[2][1])));
        H := HermiteNormalFormIntegerMat(X);
        return ForAll(d[2], av -> InHNF(H, List(av, p -> Tab[k][2][p])));
      end));
    ob := pass = [];
    if ob then nobs := nobs + 1; fi;
    Print("  M: fails ", bad, ", rank ", Length(gm), ", layers [j, #a, #c, #lam]: ", List(data, d -> [d[1], Length(d[2]), Length(d[3]), Length(d[2][1])]),
      ", K passing: ", Length(pass), ", obstruction: ", ob, " (", Int((t2 - t1) / 1000), " + ", Int((Runtime() - t2) / 1000), " s)\n");
  od;
  Print("  sec ", Int((Runtime() - t) / 1000), "\n");
od;
Print("maximal subgroups: ", nall, ", with the multilinear obstruction: ", nobs, "\n");
QUIT;
