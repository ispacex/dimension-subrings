# lib451.g -- MATH-451 (gamma_4 = C_{3^K}, K >= 2), wiki 891 Sec. 12.  Read after case446/lib446.g and
# case446/newchecks.g (TaharaData, AdaptedX1, ResidualParts, TaggedConds, C1Rows, SelConds, HNFl).
Read("presgens.g");

# as RandP of lib446.g, but also returns the images of the presentation generators
RandPG := function(F, g, ord, pqc, extraw)
  local k, rels, Fp, epi, P0, L0, P, L, p3, i, nat, gens;
  k := Length(g);
  rels := List([1..k], i -> g[i]^ord[i] / Product(List([1..Random([0..extraw[1]])],
    j -> RW(F, Random(extraw{[2, 3]}))), One(F)));
  if FORCE13 and 3 in ord then
    p3 := Position(ord, 3);
    for i in Filtered([1..k], i -> ord[i] >= 9) do
      rels[i] := rels[i] * Comm(g[p3], Random(g{Difference([1..k], [p3])}))^Random([1, 2]);
    od;
  fi;
  # FORCE2 (default false): every power word of a generator of order >= 9 gets 1-2 extra weight-2 factors
  # [g_a, g_b], so that Ybar_i <> 0 in L_2 and the forms omega(cbar, Ybar) are nontrivial more often
  if IsBound(FORCE2) and FORCE2 then
    for i in Filtered([1..k], i -> ord[i] >= 9) do
      for p3 in [1..Random([1, 2])] do rels[i] := rels[i] * Comm(Random(g), Random(g))^Random([1, 2]); od;
    od;
  fi;
  Append(rels, List([1..Random([0..k+2])], j -> Product(List([1..Random([1..2])],
    t -> RW(F, Random(extraw))), One(F))));
  Fp := F / Concatenation(rels, W5(F));
  epi := EpimorphismPGroup(Fp, 3, pqc);
  P0 := Image(epi);
  L0 := LowerCentralSeriesOfGroup(P0);
  if Length(L0) >= 5 then nat := NaturalHomomorphismByNormalSubgroup(P0, L0[5]); P := Image(nat);
  else nat := IdentityMapping(P0); P := P0; fi;
  gens := List(GeneratorsOfGroup(Fp), x -> Image(nat, Image(epi, x)));
  L := LowerCentralSeriesOfGroup(P);
  return [P, Length(L) - 1 = 4 and SortedList(AbelianInvariants(P)) = SortedList(ord), gens];
end;

# hom P -> P/ker f, f: gamma_4 -> C_{3^K} a random functional with f(u) of order 3^K (fail if impossible)
CutPK := function(P, G4, u, K)
  local ig, o, e, M, lam, C, c, f, tries;
  M := 3^K;
  ig := IndependentGeneratorsOfAbelianGroup(G4); o := List(ig, Order);
  e := IndependentGeneratorExponents(G4, u);
  if ForAll([1..Length(ig)], r -> o[r] < M or e[r] mod 3 = 0) then return fail; fi;
  tries := 0;
  repeat
    lam := List(o, x -> Random(Filtered([0..M-1], l -> (l * x) mod M = 0)));
    tries := tries + 1;
  until (lam * e) mod 3 <> 0 or tries > 200;
  if (lam * e) mod 3 = 0 then return fail; fi;
  C := CyclicGroup(IsPcGroup, M); c := MinimalGeneratingSet(C)[1];
  f := GroupHomomorphismByImages(G4, C, ig, List(lam, l -> c^l));
  return NaturalHomomorphismByNormalSubgroupNC(P, Kernel(f));
end;

# a random class-4 3-group with Q_ab of type ab, gamma_4 = C_{3^K}, cyclic centre (Omega_1(Z) = gamma_4^{3^{K-1}}),
# Q'' <> 1 before the cut; returns [Pb, gens of Pb (images of the presentation generators), z] or fail
OneC3k := function(ab, extraw, trials, K)
  local k, pqc, F, g, trial, r, P, L, DD, A3, u, c, x, v, hom, Pb, ub, Lb, Ob, U, gens, nat;
  k := Length(ab); pqc := PQClass(ab);
  F := FreeGroup(k); g := GeneratorsOfGroup(F);
  for trial in [1..trials] do
    CheckWatch();
    r := RandPG(F, g, ab, pqc, extraw);
    P := r[1];
    if not r[2] then continue; fi;
    L := LowerCentralSeriesOfGroup(P);
    if LogExp(L[2], L[3]) < 2 or LogExp(L[4], TrivialSubgroup(P)) < K then continue; fi;
    DD := DerivedSubgroup(L[2]);
    if IsTrivial(DD) then continue; fi;
    A3 := Agemo(L[4], 3, 1);
    u := fail;
    for c in [1..60] do
      x := Random(L[4]);
      if not x in A3 and (c > 30 or x in DD) and CutPK(P, L[4], x, K) <> fail then u := x; break; fi;
    od;
    if u = fail then continue; fi;
    hom := CutPK(P, L[4], u, K);
    Pb := Image(hom); ub := Image(hom, u)^(3^(K-1));
    while true do
      Ob := Omega(Centre(Pb), 3, 1);
      if Size(Ob) = 3 then break; fi;
      U := Subgroup(Pb, [ub]);
      repeat v := Random(Ob); until not v in U;
      hom := hom * NaturalHomomorphismByNormalSubgroup(Pb, NormalClosure(Pb, Subgroup(Pb, [v])));
      Pb := Image(hom); ub := Image(hom, u)^(3^(K-1));
    od;
    Lb := LowerCentralSeriesOfGroup(Pb);
    if Length(Lb) - 1 <> 4 or Size(Lb[4]) <> 3^K or not IsCyclic(Lb[4]) then continue; fi;
    if SortedList(AbelianInvariants(Pb)) <> SortedList(ab) then continue; fi;
    # P is Image(epi) of the free group's quotient: its generators are the images of g in order
    gens := List(r[3], y -> Image(hom, y));
    return [Pb, gens, ub];
  od;
  return fail;
end;

LogOrd := x -> Log(Order(x), 3);

# a Z-basis of the lattice, the R parts on it: max log_3 order of R and of each part, and the number of basis
# vectors where log_3 |R| (or of some part) exceeds bnd
RBound := function(T, V, lat, bnd)
  local out, tau, p, R, m;
  out := rec(n := Length(lat), maxR := 0, maxpart := 0, viol := 0, partviol := 0, nontriv := 0);
  for tau in lat do
    p := ResidualParts(T, V, tau);
    R := p.T1 * p.T2 * p.T3 * p.T4;
    if not IsOne(R) then out.nontriv := out.nontriv + 1; fi;
    out.maxR := Maximum(out.maxR, LogOrd(R));
    if LogOrd(R) > bnd then out.viol := out.viol + 1; fi;
    m := Maximum(List([p.T1, p.T2, p.T3, p.T4], LogOrd));
    out.maxpart := Maximum(out.maxpart, m);
    if m > bnd then out.partviol := out.partviol + 1; fi;
  od;
  return out;
end;

# finer: every single term of R (one pair / triple) on the lattice basis, log order vs bnd
TermBound := function(T, V, lat, bnd)
  local s, X, x, Y, d, tau, i, h, g, j, kk, t, out, chk;
  s := T.s; X := V.idx; x := T.x1; Y := T.Y; d := T.d;
  out := rec(terms := 0, nontriv := 0, viol := 0, max := 0);
  chk := function(e)
    out.terms := out.terms + 1;
    if not IsOne(e) then out.nontriv := out.nontriv + 1; fi;
    out.max := Maximum(out.max, LogOrd(e));
    if LogOrd(e) > bnd then out.viol := out.viol + 1; fi;
  end;
  for tau in lat do
    for i in [1..s] do for h in [i+1..s] do
      t := tau[X.u[i][h]];
      chk(Comm(Comm(x[i], x[h]), Y[i])^(QuoInt(d[h], d[i]) * t * QuoInt(d[h] - 1, 2)));   # T1, q-part
      chk(Comm(Comm(x[i], x[h]), Y[h])^(-t * QuoInt(d[h] - 1, 2)));                         # T1, h-part
      chk(Comm(Comm(x[i], x[h]), Y[h])^(-t));                                               # T2 (h<i renamed)
    od; od;
    for i in [1..s] do for g in [i+1..s] do for h in [g..s] do
      chk(Comm(Comm(Y[g], x[i]), x[h])^(-tau[X.wp[i][g][h]]));
    od; od; od;
    for j in [1..s] do for kk in [j+1..s] do for h in [kk+1..s] do
      chk(Comm(Y[h], Comm(x[j], x[kk]))^(-tau[X.wpp[j][kk][h]]));
    od; od; od;
  od;
  return out;
end;

# form values: log orders of omega(cbar_ih, Ybar_j), against log d(i) (i<h), and of omega(cbar_{s-1,s}, cbar_ij)
FormChecks := function(T, mu)
  local s, x, Y, d, i, h, j, l, cc, e, out;
  s := T.s; x := T.x1; Y := T.Y; d := T.d;
  out := rec(omY := 0, omYbad := 0, omYmax := 0, pairmax := 0, pairbad := 0, pairY := 0, pairYmax := 0);
  for i in [1..s] do for h in [i+1..s] do for j in [1..s] do
    e := Comm(Comm(x[i], x[h]), Y[j]);
    if not IsOne(e) then out.omY := out.omY + 1; fi;
    out.omYmax := Maximum(out.omYmax, LogOrd(e));
    if Order(e) > d[i] then out.omYbad := out.omYbad + 1; fi;
  od; od; od;
  if s >= 2 then
    cc := Comm(x[s-1], x[s]);
    for i in [1..s] do for l in [i+1..s] do
      if [i, l] <> [s-1, s] then
        e := Comm(cc, Comm(x[i], x[l]));
        out.pairmax := Maximum(out.pairmax, LogOrd(e));
        if LogOrd(e) > mu then out.pairbad := out.pairbad + 1; fi;
      fi;
    od; od;
    e := Comm(cc, Y[s]);
    if not IsOne(e) then out.pairY := 1; fi;
    out.pairYmax := LogOrd(e);
  fi;
  return out;
end;
