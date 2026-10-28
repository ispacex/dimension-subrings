# MATH-412 (bm_mul.g): sections M/N of the 160 maximal subgroups M of bm_sec.g, for every normal N.
# In M/N, (C2) says U = <x1, x2^9, x3^81, x4^729> gamma_2(M) <= gamma_2(M) N (bm_sec.g: N0 covers only
# N containing the elements themselves).  (C3) is not used: its y_ij are the file's witnesses and
# need not lie in M.  Let Gam be the fastest series with Gam_1 = M, Gam_2 = U,
# Gam_j = prod_{i < j} [Gam_i, Gam_{j-i}]; by induction its image in M/N lies in gamma_j(M/N), so
# Gam_j <= gamma_j(M) N.  Gam_j <= gamma_j(Q) (Q = G or G/<u>), with equality for some M only.
# Multilinear obstruction.  A = gamma_6(Q) is central; every N cap A missing w lies in a subgroup K of A
# with A/K cyclic and w notin K.  For g in gamma_j(Q) and x_1..x_{6-j} in M, lam(g) = [g, x_1, ..,
# x_{6-j}] lies in A and is a homomorphism of gamma_j(Q) killing gamma_{j+1}(Q) (gamma_7(Q) = 1).
# For a in Gam_j there is c in gamma_j(M) with a c in N, so lam(a) lam(c) in N cap A <= K for all lam
# at once.  With x_i over generators of M mod Phi(M) (lam is multilinear mod gamma_7), this says: the
# row (log lam(a) in A/K = Z/3^f)_lam lies in the span of the rows of the c in gamma_j(M) (HNF).  If
# for every K some layer j and some a fail, w lies in every N with (C2) in M/N.  Layers JS (default
# [3..6]; layer 2 has r^4 columns).
# MATH-413 (UNIF := true;;): one test per M for every H with H0 = <x1..x4> <= H <= M and every N normal
# in H.  Each term of the test is monotone in H: Gam_j(H0) <= Gam_j(H) (U grows with H), gamma_j(H) <=
# gamma_j(M), and lam with x_i over x1..x4 (generators of H0, so in H) is among the lam of H.  So take
# a over Gam_j(H0), c over gamma_j(M), x_i over x1..x4: if some a fails, its row fails for H as well
# (restrict the lam of H to these), and w lies in every N with (C2) in H/N.  N cap A = 1 still follows
# from w notin N: w in H0 <= H, and A cap H is cyclic.  Every proper H containing x1..x4 lies in some M.
# MATH-413 (SUBS := true;;): the same test as for the M, on every H with Phi(Q) <x1..x4> <= H < Q of index
# >= 9 (preimages of the subspaces of Q/Phi(Q) = F_3^7 over the images of x1..x4, of codimension >= 2).
# PART := [k, n];; tests only the subgroups with number = k mod n (short jobs).
Read("../3group.gap");
W := EvalString(w);;
XS := [x1, x2, x3, x4];;
YS2 := [x1, x2^9, x3^81, x4^729];;
YS3 := [LeftNormedComm([z2,z4,z1]), LeftNormedComm([z2,z4,z2]), LeftNormedComm([z2,z4,z3]), LeftNormedComm([z2,z4,z4])];;
LEV := [2, 2, 2, 2, 3, 3, 3, 3];;
NEED := [1, 2, 3, 4];;   # (C2) only
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
# the K with Phi(H) <xs> <= K < H of index >= 9, largest first
SubsOver := function(H, xs)
  local Fr, hom, V, S, h2, res;
  Fr := FrattiniSubgroup(H);
  hom := NaturalHomomorphismByNormalSubgroupNC(H, Fr);
  V := Image(hom); S := Subgroup(V, List(xs, x -> Image(hom, x)));
  h2 := NaturalHomomorphismByNormalSubgroupNC(V, S);
  res := Filtered(AllSubgroups(Image(h2)), K -> Index(Image(h2), K) >= 9);
  res := List(res, K -> PreImage(hom, PreImage(h2, K)));
  Sort(res, function(a, b) return Size(a) > Size(b); end);
  return res;
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
if not IsBound(JS) then JS := [3..6]; fi;
if not IsBound(VERB) then VERB := false; fi;
if not IsBound(MAXM) then MAXM := infinity; fi;   # only the first MAXM subgroups of each case
if not IsBound(UNIF) then UNIF := false; fi;
if not IsBound(SUBS) then SUBS := false; fi;
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
# self-test of HNF membership: rows [3,0], [0,1] mod 27 contain [6,5], not [1,0]
XT := Concatenation([[3, 0], [0, 1]], 27 * IdentityMat(2));;
SELFTEST := InHNF(HermiteNormalFormIntegerMat(XT), [6, 5]) and not InHNF(HermiteNormalFormIntegerMat(XT), [1, 0]);;
# the K (indices into Ks) for which every a of every layer of data is in the span of its c
Passing := function(data, Tab, nK)
  return Filtered([1..nK], k -> ForAll(data, function(d)
      local f, X, H;
      f := Tab[k][1];
      X := List(d[3], cv -> List(cv, p -> Tab[k][2][p]));
      Append(X, f * IdentityMat(Length(d[2][1])));
      H := HermiteNormalFormIntegerMat(X);
      return ForAll(d[2], av -> InHNF(H, List(av, p -> Tab[k][2][p])));
    end));
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
# Negative control (CTRLH := true;;): D = G x H, H = SmallGroup(81, 7) of class 3, x1 replaced by x1 h
# (h a generator of H).  N = M cap (1 x H) is normal in M, misses w, and if M projects onto G then
# M/N = G satisfies (C2) (x1 h = x1 there): a section exists, so no obstruction may be reported for
# such M ("onto G: true").  The layer-3 rows a = [x1 h, m] are not in gamma_3(M) gamma_4(D) in general,
# while lam kills the H-part (class 3 < 6).
if IsBound(CTRLH) and CTRLH then
  HH := SmallGroup(81, 7);; DD := DirectProduct(G, HH);;
  cases := [["G x SmallGroup(81,7), x1 := x1 h", Embedding(DD, 1), DD, Image(Embedding(DD, 2), Pcgs(HH)[1])]];
fi;
nall := 0;; nobs := 0;;
if IsBound(GAPInfo.SystemEnvironment.JOB_OUT) then OUTF := Concatenation(GAPInfo.SystemEnvironment.JOB_OUT, "/subs.txt");; fi;
if IsBound(GAPInfo.SystemEnvironment.JOB_ROOT) then PROGF := Concatenation(GAPInfo.SystemEnvironment.JOB_ROOT, "/progress");; fi;
for c in cases do
  hom := c[2]; if Length(c) >= 3 then Q := c[3]; else Q := Image(hom); fi;
  xs := List(XS, x -> Image(hom, x));
  ys := List(Concatenation(YS2, YS3), y -> Image(hom, y)); wQ := Image(hom, W);
  if Length(c) >= 4 then xs[1] := xs[1] * c[4]; ys[1] := ys[1] * c[4]; fi;
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
  if SUBS then
    Ms := SubsOver(Q, xs);
  else
    Ms := MaxOver(Q, xs);
  fi;
  if UNIF then
    H0 := Subgroup(Q, xs); gH := Gam(H0, ys);
    Print("UNIF: H0 = <x1..x4> of order 3^", Log(Size(H0), 3), ", |Gam_j(H0)| = 3^", List(gH{[1..7]}, X -> Log(Size(X), 3)), "\n");
  fi;
  if SUBS then
    Print(c[1], ": log3|Q| = ", Log(Size(Q), 3), ", subgroups over Phi(Q) <x1..x4> of index >= 9: ", Length(Ms), ", by log3 index: ", Collected(List(Ms, K -> Log(Index(Q, K), 3))), "\n");
  else
    Print(c[1], ": log3|Q| = ", Log(Size(Q), 3), ", maximal subgroups containing x1..x4: ", Length(Ms), "\n");
  fi;
  sel := [1..Minimum(MAXM, Length(Ms))];
  if IsBound(PART) then sel := Filtered(sel, i -> i mod PART[2] = PART[1] mod PART[2]); fi;
  for i in sel do
    M := Ms[i];
    nall := nall + 1;
    bad := Intersection(Check(M, ys{[1..4]}, ys{[5..8]}), NEED);
    t1 := Runtime();
    LM := ShallowCopy(LowerCentralSeriesOfGroup(M));
    while Length(LM) < 8 do Add(LM, TrivialSubgroup(M)); od;
    if UNIF then gm := xs; else gm := Reps(M, FrattiniSubgroup(M)); fi;
    if VERB then Print("    rank ", Length(gm), " (", Int((Runtime() - t1) / 1000), " s)\n"); fi;
    if UNIF then gg := gH; else gg := Gam(M, ys); fi; gq := ForAll([2..6], j -> Size(gg[j]) = Size(LQ[j]));
    data := [];
    for j in JS do
      ar := Reps(gg[j], ClosureGroup(LM[j], LQ[j + 1]));
      if ar = [] then continue; fi;
      cr := Reps(LM[j], LQ[j + 1]);
      Add(data, [j, List(ar, g -> Lam(g, gm, 6 - j, AL)), List(cr, g -> Lam(g, gm, 6 - j, AL))]);
      if VERB then Print("    layer ", j, ": #a ", Length(ar), ", #c ", Length(cr), " (", Int((Runtime() - t1) / 1000), " s)\n"); fi;
    od;
    t2 := Runtime();
    pass := Passing(data, Tab, Length(Ks));
    perlayer := List(data, d -> [d[1], Length(Passing([d], Tab, Length(Ks)))]);
    ob := pass = [];
    # positive control on the first M: c over gamma_j(Q) instead of gamma_j(M), every K must pass
    if i = sel[1] then
      dc := List(data, d -> [d[1], d[2], List(Reps(LQ[d[1]], LQ[d[1] + 1]), g -> Lam(g, gm, 6 - d[1], AL))]);
      Print("    control (c over gamma_j(Q)): K passing ", Length(Passing(dc, Tab, Length(Ks))), " of ", Length(Ks), "\n");
    fi;
    if ob then nobs := nobs + 1; fi;
    if Length(c) >= 3 then Print("    onto G: ", Size(Image(Projection(Q, 1), M)) = Size(G), "\n"); fi;
    Print("  M #", i, ": index 3^", Log(Index(Q, M), 3), ", fails ", bad, ", rank ", Length(gm), ", layers [j, #a, #c, #lam]: ", List(data, d -> [d[1], Length(d[2]), Length(d[3]), Length(d[2][1])]),
      ", K passing: ", Length(pass), " (by layer alone: ", perlayer, "), Gam = gamma(Q): ", gq, ", obstruction: ", ob, " (", Int((t2 - t1) / 1000), " + ", Int((Runtime() - t2) / 1000), " s)\n");
    # GAP's stdout to a pipe is block-buffered: one flushed line per subgroup, and progress for tm
    if IsBound(OUTF) then
      AppendTo(OUTF, c[1], " #", i, " of ", Length(Ms), ": index 3^", Log(Index(Q, M), 3), ", by layer alone ", perlayer, ", obstruction ", ob, "\n");
    fi;
    if IsBound(PROGF) then PrintTo(PROGF, Position(sel, i), "/", Length(sel), "\n"); fi;
  od;
  Print("  sec ", Int((Runtime() - t) / 1000), "\n");
od;
if SUBS then Print("subgroups: "); else Print("maximal subgroups: "); fi;
Print(nall, ", with the multilinear obstruction: ", nobs, ", HNF self-test: ", SELFTEST, "\n");
QUIT;
