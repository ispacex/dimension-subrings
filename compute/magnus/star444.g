# MATH-444 / D5-49, step 2: checks of the identity (*) and of the vanishing of its terms (wiki MATH page of
# step 2).  For a 3-group P of class 4 with gamma_4^3 = 1 and a Tahara family tau satisfying (B), (D), (E), (F):
#
#   g(tau)^2 = prod_{i<h} Delta_ih^{u_ih} * prod_{h<i} [[Y_h,x_i],x_i]^{-u_hi q_hi}
#              * prod_{i<g<=h} [[Y_g,x_i],x_h]^{-w'_igh} * prod_{j<k<h} [Y_h,[x_j,x_k]]^{-w''_jkh}          (*)
#
# with Delta_ih = [x_i^{d(h)}, x_h] [x_h^{d(h)}, x_i], Y_i = x_i^{d(i)}, Tahara's commutator [a,b] = a^-1 b^-1 a b.
# (*) is checked on a Z-basis of the lattice of families with (B),(D),(E),(F) (A and C dropped), and, as
# controls, with one more of B, D, E, F dropped (then (*) should fail somewhere).
# With the ADAPTED basis x_1 (classes Ybar_i mod 3 gamma_2 gamma_3 of the rows either 0 or linearly
# independent; built from a basis of Omega_1(P/gamma_2) compatible with the height flag and ker Pbar), every
# single factor of (*) is checked to be 1 on a Z-basis of the full admissible lattice (A)-(F).
#
# Groups: as s444.g (random class-4 3-quotients); MODE "cut" = gamma_4 cut to C_3 + cyclic centre (s444.g),
# MODE "raw" = P / gamma_4^3 (gamma_4 elementary of any rank, no centre condition).
# Set SEED, NG, KS, TOPS, MODE, OUT; optional EXTRAW, TAHMAX, NEEDNOTH2 (default false: keep only groups with
# gamma_2^9 not in gamma_4 when true).
LoadPackage("anupq");
Read("tahara61.g");
if not IsBound(EXTRAW) then EXTRAW := [2, 3, 3, 4]; fi;
if not IsBound(TAHMAX) then TAHMAX := 1500; fi;
if not IsBound(NEEDNOTH2) then NEEDNOTH2 := false; fi;
Reset(GlobalMersenneTwister, SEED); Reset(GlobalRandomSource, SEED);
RW := function(F, wt)
  local g, c, i;
  g := GeneratorsOfGroup(F); c := Random(g);
  for i in [2..wt] do c := Comm(c, Random(g)); od;
  return c^Random([1, 2]);
end;
W5 := function(F)
  local g, L, i;
  g := GeneratorsOfGroup(F); L := List(g, x -> x);
  for i in [2..5] do L := Concatenation(List(L, c -> List(g, y -> Comm(c, y)))); od;
  return Filtered(L, c -> c <> One(F));
end;
LogExp := function(H, N) if Size(H) = Size(N) then return 0; fi; return Log(Exponent(H / N), 3); end;
# hom P -> P/N, N <= gamma_4 the kernel of a random functional gamma_4 -> C_9 with u of order 9 mod N
CutG4n9 := function(P, G4, u)
  local ig, o, e, lam, C, c, f;
  ig := IndependentGeneratorsOfAbelianGroup(G4); o := List(ig, Order);
  e := IndependentGeneratorExponents(G4, u);
  if ForAll([1..Length(ig)], r -> o[r] < 9 or e[r] mod 3 = 0) then return fail; fi;
  repeat lam := List(o, x -> Random(Filtered([0..8], l -> (l * x) mod 9 = 0))); until (lam * e) mod 3 <> 0;
  C := CyclicGroup(IsPcGroup, 9); c := MinimalGeneratingSet(C)[1];
  f := GroupHomomorphismByImages(G4, C, ig, List(lam, l -> c^l));
  return NaturalHomomorphismByNormalSubgroupNC(P, Kernel(f));
end;
CutG4 := function(P, G4, u)
  local ig, e, lam, C, c, f;
  ig := IndependentGeneratorsOfAbelianGroup(G4);
  e := IndependentGeneratorExponents(G4, u);
  if ForAll(e, x -> x mod 3 = 0) then return fail; fi;
  repeat lam := List(ig, x -> Random([0..2])); until (lam * e) mod 3 <> 0;
  C := CyclicGroup(IsPcGroup, 3); c := GeneratorsOfGroup(C)[1];
  f := GroupHomomorphismByImages(G4, C, ig, List(lam, l -> c^l));
  return NaturalHomomorphismByNormalSubgroupNC(P, Kernel(f));
end;

# vector space helpers over GF(3)
F3 := GF(3);
InSpan := function(B, v) if B = [] then return IsZero(v); fi; return SolutionMat(B, v) <> fail; end;
Extend := function(B, cands)   # add vectors of cands to B keeping independence, return the added ones
  local added, v, BB;
  added := []; BB := ShallowCopy(B);
  for v in cands do if not InSpan(BB, v) then Add(BB, v); Add(added, v); fi; od;
  return added;
end;

# adapted uniqueness basis of P/gamma_2: z_i = (d(i)/3) xbar_i, basis of Omega_1 compatible with the height
# flag V_j and with K = ker Pbar (Pbar(z) = (lift of z)^3 mod gamma_2^3 gamma_3, in L2/3L2).
AdaptedX1 := function(P, L)
  local hab, A, ig, n, m, lifts, B2, pv, Pb, Kb, J, j, Vj, Kj, Bv, Bh, C1, D, z, xs, ds, perm, y, r;
  hab := NaturalHomomorphismByNormalSubgroup(P, L[2]); A := Image(hab);
  ig := IndependentGeneratorsOfAbelianGroup(A); n := List(ig, Order); m := Length(ig);
  lifts := List(ig, a -> PreImagesRepresentative(hab, a));
  B2 := LayerBasis(L, 2);
  pv := function(w) return List(B2.coords(w), x -> x * One(F3)); end;
  Pb := List([1..m], r -> pv((lifts[r]^(n[r] / 3))^3));
  Kb := NullspaceMat(Pb);          # rows: basis of ker Pbar in the coordinates of the v_r
  J := Maximum(List(n, x -> Log(x, 3))) - 1;
  Bv := []; Bh := [];
  for j in [J, J-1 .. 0] do
    Vj := List(Filtered([1..m], r -> n[r] >= 3^(j+1)), r -> IdentityMat(m, F3)[r]);
    if Kb = [] then Kj := []; else Kj := SumIntersectionMat(Vj, Kb)[2]; fi;
    C1 := Extend(Filtered(Bv, v -> Kb <> [] and InSpan(Kb, v)), Kj);
    D := Extend(Concatenation(Bv, C1), Vj);
    for z in Concatenation(C1, D) do Add(Bv, z); Add(Bh, j); od;
  od;
  if Length(Bv) <> m then Error("adapted basis"); fi;
  # x with 3^j xbar = z, d = 3^(j+1)
  xs := []; ds := [];
  for r in [1..m] do
    y := Product(List([1..m], s -> lifts[s]^(IntFFE(Bv[r][s]) * n[s] / 3^(Bh[r] + 1))), One(P));
    Add(xs, y); Add(ds, 3^(Bh[r] + 1));
  od;
  perm := Sortex(ds);
  return Permuted(xs, perm);
end;

# the factors of (*) for tau; returns a list of [name, element]
StarFactors := function(T, V, tau)
  local s, X, x, Y, d, F, i, h, g, j, k, q, R;
  s := T.s; X := V.idx; x := T.x1; Y := T.Y; d := T.d; F := [];
  q := function(i, j) return QuoInt(d[j], d[i]); end;
  for i in [1..s] do for h in [i+1..s] do
    Add(F, [Concatenation("T1 ", String([d[i], d[h]])), (Comm(x[i]^d[h], x[h]) * Comm(x[h]^d[h], x[i]))^tau[X.u[i][h]]]);
  od; od;
  for h in [1..s] do for i in [h+1..s] do
    Add(F, [Concatenation("T2 ", String([d[h], d[i]])), Comm(Comm(Y[h], x[i]), x[i])^(-tau[X.u[h][i]] * q(h, i))]);
  od; od;
  for i in [1..s] do for g in [i+1..s] do for h in [g..s] do
    Add(F, [Concatenation("T3 ", String([d[i], d[g], d[h]])), Comm(Comm(Y[g], x[i]), x[h])^(-tau[X.wp[i][g][h]])]);
  od; od; od;
  for j in [1..s] do for k in [j+1..s] do for h in [k+1..s] do
    Add(F, [Concatenation("T4 ", String([d[j], d[k], d[h]])), Comm(Y[h], Comm(x[j], x[k]))^(-tau[X.wpp[j][k][h]])]);
  od; od; od;
  for i in [1..s] do
    R := Product(List([1..T.t], k -> T.x2[k]^tau[X.v[i][k]]), One(T.P));
    Add(F, [Concatenation("T5 ", String([d[i]])), Comm(Comm(R, x[i]), x[i])^(-Binomial(d[i], 2))]);
  od;
  return F;
end;

StarRHS := function(T, V, tau) return Product(List(StarFactors(T, V, tau), f -> f[2]), One(T.P)); end;

# check (*) on the lattice cut out by the conditions not in drop; returns [lattice size, failures]
StarCheck := function(T, V, drop)
  local conds, lat, bad, tau;
  conds := TaharaConds(T, V, rec(drop := drop));
  lat := TaharaLattice(T, V, conds); bad := 0;
  for tau in lat do
    if TaharaGen(T, V, tau).g^2 <> StarRHS(T, V, tau) then bad := bad + 1; fi;
  od;
  return [Length(lat), bad];
end;

OUTS := OutputTextFile(OUT, false); SetPrintFormattingStatus(OUTS, false);
stats := rec(tried := 0, ok := 0, nrec := 0, starbad := 0, adaptbad := 0, factbad := 0, gbad := 0, skipbig := 0);
T0 := NanosecondsSinceEpoch();
for it in [1..NG] do
  tops := Random(TOPS); t := Length(tops);
  k := Random(Filtered(KS, x -> x >= t));
  ords := Concatenation(List([1..k-t], i -> 3), tops);
  lg := Reversed(SortedList(List(ords, d -> LogInt(d, 3))));
  pqc := lg[1] + 3 * lg[2] + 1;
  F := FreeGroup(k); g := GeneratorsOfGroup(F);
  rels := List([1..k-t], i -> g[i]^3 / Product(List([1..Random([0..2])], j -> RW(F, Random([2, 2, 3]))), One(F)));
  for i in [k-t+1..k] do
    Add(rels, g[i]^ords[i] / Product(List([1..Random([1..2])], j -> RW(F, Random([2, 2, 3]))), One(F)));
  od;
  Append(rels, List([1..Random([0..k+2])], j -> Product(List([1..Random([1..2])], t -> RW(F, Random(EXTRAW))), One(F))));
  stats.tried := stats.tried + 1;
  Fp := F / Concatenation(rels, W5(F));
  epi := EpimorphismPGroup(Fp, 3, pqc);
  P0 := Image(epi);
  L0 := LowerCentralSeriesOfGroup(P0);
  if Length(L0) >= 5 then P := Image(NaturalHomomorphismByNormalSubgroup(P0, L0[5])); else P := P0; fi;
  L := LowerCentralSeriesOfGroup(P);
  if Length(L) - 1 <> 4 or SortedList(AbelianInvariants(P)) <> SortedList(ords) then continue; fi;
  if MODE = "raw" then
    Pb := Image(NaturalHomomorphismByNormalSubgroup(P, Agemo(L[4], 3)));
  elif MODE = "raw9" then
    Pb := Image(NaturalHomomorphismByNormalSubgroup(P, Agemo(L[4], 3, 2)));
  else
    DD := DerivedSubgroup(L[2]);
    if MODE = "cut9" then A3 := Agemo(L[4], 3, 2); else A3 := Agemo(L[4], 3); fi;
    u := fail;
    for c in [1..50] do
      x := Random(L[4]);
      if not x in A3 and (MODE <> "cut9" or Order(x) >= 9) and (IsTrivial(DD) or c > 25 or x in DD) then u := x; break; fi;
    od;
    if u = fail then continue; fi;
    if MODE = "cut9" then hom := CutG4n9(P, L[4], u); else hom := CutG4(P, L[4], u); fi;
    if hom = fail then continue; fi;
    Pb := Image(hom); ub := Image(hom, u);
    if MODE = "cut9" then ub := ub^3; fi;      # Omega_1(Z) must become <ub>
    while true do
      Ob := Omega(Centre(Pb), 3, 1);
      if Size(Ob) = 3 then break; fi;
      U := Subgroup(Pb, [ub]);
      repeat v := Random(Ob); until not v in U;
      h2 := NaturalHomomorphismByNormalSubgroup(Pb, NormalClosure(Pb, Subgroup(Pb, [v])));
      hom := hom * h2; Pb := Image(hom); ub := Image(hom, u); if MODE = "cut9" then ub := ub^3; fi;
    od;
  fi;
  Lb := LowerCentralSeriesOfGroup(Pb);
  if Length(Lb) - 1 <> 4 then continue; fi;
  if MODE = "cut9" and not (Size(Lb[4]) = 9 and IsCyclic(Lb[4])) then continue; fi;
  stats.ok := stats.ok + 1;
  e23 := LogExp(Lb[2], Lb[3]);
  P9 := Subgroup(Pb, Concatenation(List(GeneratorsOfGroup(Lb[2]), a -> a^9), GeneratorsOfGroup(Lb[4])));
  psi := Log(Index(P9, Lb[4]), 3);
  if NEEDNOTH2 and psi = 0 then continue; fi;
  t1 := Runtime();
  # (1) identity (*) with the default basis; controls with one more condition group dropped
  T := TaharaData(Pb, fail); V := TaharaVars(T);
  if V.n > TAHMAX then stats.skipbig := stats.skipbig + 1; continue; fi;
  st := StarCheck(T, V, ["A", "C"]);
  ctl := List(["B", "D", "E", "F"], z -> [z, StarCheck(T, V, ["A", "C", z])]);
  Add(ctl, ["all", StarCheck(T, V, ["A", "B", "C", "D", "E", "F"])]);
  if st[2] > 0 then stats.starbad := stats.starbad + 1; Print("STAR FAILS ", SEED, ".", it, "\n"); fi;
  # (2) adapted basis: rows of b mod 3 zero or independent; every factor of (*) is 1 on the admissible lattice
  x1 := AdaptedX1(Pb, Lb);
  TA := TaharaData(Pb, x1); VA := TaharaVars(TA);
  rows := Filtered(List(TA.b, r -> r * One(F3)), r -> not IsZero(r));
  adapt := rows = [] or RankMat(rows) = Length(rows);
  if not adapt then stats.adaptbad := stats.adaptbad + 1; Print("ADAPT FAILS ", SEED, ".", it, "\n"); fi;
  latA := TaharaLattice(TA, VA, TaharaConds(TA, VA, rec(drop := [])));
  fbad := []; gbad := 0;
  for tau in latA do
    if not IsOne(TaharaGen(TA, VA, tau).g) then gbad := gbad + 1; fi;
    for f in StarFactors(TA, VA, tau) do if not IsOne(f[2]) then AddSet(fbad, f[1]); fi; od;
  od;
  if fbad <> [] then stats.factbad := stats.factbad + 1; Print("FACTOR FAILS ", SEED, ".", it, " ", fbad, "\n"); fi;
  if gbad > 0 then stats.gbad := stats.gbad + 1; Print("G FAILS ", SEED, ".", it, "\n"); fi;
  # the factors on the lattice without C (to see that C is what kills T1/T2) and without D (T3/T4)
  fnoC := []; fnoD := [];
  for tau in TaharaLattice(TA, VA, TaharaConds(TA, VA, rec(drop := ["C"]))) do
    for f in StarFactors(TA, VA, tau) do if not IsOne(f[2]) then AddSet(fnoC, f[1]); fi; od; od;
  for tau in TaharaLattice(TA, VA, TaharaConds(TA, VA, rec(drop := ["D"]))) do
    for f in StarFactors(TA, VA, tau) do if not IsOne(f[2]) then AddSet(fnoD, f[1]); fi; od; od;
  stats.nrec := stats.nrec + 1;
  WriteAll(OUTS, Concatenation("{\"id\":\"", String(SEED), ".", String(it), "\",\"mode\":\"", MODE,
    "\",\"ab\":", String(AbelianInvariants(Pb)), ",\"logord\":", String(Log(Size(Pb), 3)),
    ",\"lcs\":", String(List([1..4], j -> Log(Index(Lb[j], Lb[j+1]), 3))),
    ",\"e23\":", String(e23), ",\"e34\":", String(LogExp(Lb[3], Lb[4])), ",\"psi\":", String(psi), ",\"g4\":", String(AbelianInvariants(Lb[4])),
    ",\"zcyc\":", String(IsCyclic(Centre(Pb))), ",\"nonmet\":", String(not IsTrivial(DerivedSubgroup(Lb[2]))),
    ",\"nvars\":", String(V.n), ",\"star\":", String(st), ",\"ctl\":", String(ctl),
    ",\"adapted\":", String(adapt), ",\"latA\":", String(Length(latA)), ",\"gbad\":", String(gbad),
    ",\"fbad\":\"", String(fbad), "\",\"f_noC\":\"", String(fnoC), "\",\"f_noD\":\"", String(fnoD),
    "\",\"ms\":", String(Runtime() - t1), "}\n"));
od;
CloseStream(OUTS);
Print("stats ", String(stats), "\n");
Print("wall ", Int((NanosecondsSinceEpoch() - T0) / 10^9), " s\n");
QUIT;
