# MATH-444 / D5-49: random 3-groups Q of class 4 with gamma_4(Q) = C_3, cyclic centre, Q'' != 1 and
# exp(gamma_2/gamma_3) = 9 -- the subcase gamma_4 = C_3 of the minimal counterexample.  The point is the
# condition (H2) gamma_2^9 <= gamma_4 (equivalently [x^9,y] in gamma_4 for all x,y): under (H1) exp gamma_4 = 3
# and (H2), D_5 = 1 is proved on paper (wiki page of MATH-444); the records with (H2) false are the
# configurations where that proof breaks.  We record psi = log_3 |gamma_2^9 gamma_4 / gamma_4| (H2 iff psi = 0).
#
# Construction: as q99gen.g (Q = 3-quotient of class PQCLASS of a random presentation, then Q/gamma_5), then
# u = an element of Q'' outside gamma_4^3, gamma_4 cut to C_3 = <u> by the kernel of a random functional
# gamma_4 -> C_3 nonzero on u (a central subgroup), then the cyclic-centre reduction of q99gen.g (kill central
# elements of order 3 other than <u>, inside gamma_2 when possible) until Omega_1(Z) = <u>.  For the result Qb,
# D_5(Qb) = 1 iff u notin D_5(Qb) (a nontrivial normal D_5 meets the centre); d5s.py decides it.
#
# Set SEED, NG, KS, TOPS, EPS0, OUT; optional EXTRAW, TAH (default true: also run the Tahara solver of
# tahara61.g, a second exact method via the Lean theorem taharaFiveOne), TAHMAX (max number of Tahara variables),
# IDCHK (random identity checks per group, default 30).
LoadPackage("anupq");
Read("presgens.g");
Read("tahara61.g");
if not IsBound(EXTRAW) then EXTRAW := [2, 3, 3, 4]; fi;
if not IsBound(TAH) then TAH := true; fi;
if not IsBound(TAHMAX) then TAHMAX := 2500; fi;
if not IsBound(IDCHK) then IDCHK := 30; fi;
if not IsBound(MODE) then MODE := 1; fi;
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
# hom P -> P/N, N <= gamma_4 the kernel of a random functional gamma_4 -> C_3 with u notin N
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
OUTS := OutputTextFile(OUT, false); SetPrintFormattingStatus(OUTS, false);
stats := rec(tried := 0, ok := 0, nonmet := 0, nou := 0, rec := 0, e23is2 := 0, h2 := 0, noth2 := 0,
             tahbad := 0, idbad := 0);
T0 := NanosecondsSinceEpoch();
for it in [1..NG] do
  tops := Random(TOPS); t := Length(tops);
  k := Random(Filtered(KS, x -> x >= t));
  ords := Concatenation(List([1..k-t], i -> 3), tops);
  lg := Reversed(SortedList(List(ords, d -> LogInt(d, 3))));
  pqc := lg[1] + 3 * lg[2] + 1;
  F := FreeGroup(k); g := GeneratorsOfGroup(F);
  forceeps := Random([1..100]) <= Int(100 * EPS0);
  rels := List([1..k-t], i -> g[i]^3 / Product(List([1..Random([0..2])], j -> RW(F, Random([2, 2, 3]))), One(F)));
  for i in [k-t+1..k] do
    if forceeps then
      Add(rels, g[i]^ords[i] / Product(List([1..Random([0..2])], j -> RW(F, Random([3, 3, 4]))), One(F)));
    else
      Add(rels, g[i]^ords[i] / Product(List([1..Random([1..2])], j -> RW(F, Random([2, 2, 3]))), One(F)));
    fi;
  od;
  Append(rels, List([1..Random([0..k+2])], j -> Product(List([1..Random([1..2])], t -> RW(F, Random(EXTRAW))), One(F))));
  stats.tried := stats.tried + 1;
  Fp := F / Concatenation(rels, W5(F));
  epi := EpimorphismPGroup(Fp, 3, pqc);
  P0 := Image(epi);
  L0 := LowerCentralSeriesOfGroup(P0);
  if Length(L0) >= 5 then nat := NaturalHomomorphismByNormalSubgroup(P0, L0[5]); P := Image(nat);
  else nat := IdentityMapping(P0); P := P0; fi;
  L := LowerCentralSeriesOfGroup(P);
  if Length(L) - 1 <> 4 or SortedList(AbelianInvariants(P)) <> SortedList(ords) then continue; fi;
  stats.ok := stats.ok + 1;
  if LogExp(L[2], L[3]) < 2 then continue; fi;
  DD := DerivedSubgroup(L[2]);
  if IsTrivial(DD) then continue; fi;
  stats.nonmet := stats.nonmet + 1;
  gens := List(GeneratorsOfGroup(Fp), x -> Image(nat, Image(epi, x)));
  A3 := Agemo(L[4], 3);
  u := fail;
  for c in [1..50] do x := Random(DD); if not x in A3 then u := x; break; fi; od;
  if u = fail then stats.nou := stats.nou + 1; continue; fi;
  hom := CutG4(P, L[4], u);
  Pb := Image(hom); ub := Image(hom, u); nstep := 0; outside := false;
  while true do
    Ob := Omega(Centre(Pb), 3, 1);
    if Size(Ob) = 3 then break; fi;
    U := Subgroup(Pb, [ub]); O2 := Intersection(Ob, DerivedSubgroup(Pb));
    if IsSubgroup(U, O2) then O2 := Ob; outside := true; fi;
    repeat v := Random(O2); until not v in U;
    h2 := NaturalHomomorphismByNormalSubgroup(Pb, NormalClosure(Pb, Subgroup(Pb, [v])));
    hom := hom * h2; Pb := Image(hom); ub := Image(hom, u); nstep := nstep + 1;
  od;
  gb := List(gens, x -> Image(hom, x));
  Lb := LowerCentralSeriesOfGroup(Pb);
  e23 := LogExp(Lb[2], Lb[3]);
  DDb := DerivedSubgroup(Lb[2]);
  if Length(Lb) - 1 <> 4 or Size(Lb[4]) <> 3 or e23 < 2 or IsTrivial(DDb) then continue; fi;
  stats.e23is2 := stats.e23is2 + 1;
  # (H2): gamma_2^9 <= gamma_4; a -> a^9 is a homomorphism on gamma_2 (gamma_4 central of exponent 3)
  P9 := Subgroup(Pb, Concatenation(List(GeneratorsOfGroup(Lb[2]), a -> a^9), GeneratorsOfGroup(Lb[4])));
  psi := Log(Index(ClosureGroup(P9, Lb[4]), Lb[4]), 3);
  H2 := psi = 0;
  if H2 then stats.h2 := stats.h2 + 1; else stats.noth2 := stats.noth2 + 1; fi;
  # psi on the generators: pairs (i,j) with [x_i^9, x_j] notin gamma_4, by the order of x_i mod gamma_2
  hab := NaturalHomomorphismByNormalSubgroup(Pb, Lb[2]);
  dgen := List(gb, x -> Order(Image(hab, x)));
  psipairs := [];
  for i in [1..k] do for j in [1..k] do
    if i <> j and not Comm(gb[i]^9, gb[j]) in Lb[4] then AddSet(psipairs, dgen[i]); fi;
  od; od;
  # identity checks on random elements: (iii) [x^3,a] = [x,a]^3 = [x,a^3]; (iv) [x^9,y] = [x,y]^9, in gamma_4,
  # [a,x^9] = 1; cube map on gamma_2 a homomorphism; [x,a,x]^3 = 1 (automatic, exp gamma_4 = 3)
  id3 := true; id4 := true; idcube := true;
  for c in [1..IDCHK] do
    x := Random(Pb); y := Random(Pb); a := Random(Lb[2]); b := Random(Lb[2]);
    if not (Comm(x^3, a) = Comm(x, a)^3 and Comm(x, a^3) = Comm(x, a)^3) then id3 := false; fi;
    if not (Comm(x^9, y) = Comm(x, y)^9 and Comm(x^9, y) in Lb[4] and IsOne(Comm(a, x^9))) then id4 := false; fi;
    if not (a * b)^3 = a^3 * b^3 then idcube := false; fi;
  od;
  if not id3 or not idcube or (H2 and not id4) then stats.idbad := stats.idbad + 1; fi;
  # Tahara solver (second method)
  tah := "skip"; tahn := 0; tahlat := 0; taht := 0;
  if TAH then
    t1 := Runtime();
    T := TaharaData(Pb, fail); V := TaharaVars(T); tahn := V.n;
    if V.n <= TAHMAX then
      conds := TaharaConds(T, V, rec(drop := []));
      lat := TaharaLattice(T, V, conds); tahlat := Length(lat);
      gg := List(lat, tau -> TaharaGen(T, V, tau).g);
      tah := ForAll(gg, IsOne);
      if not tah then stats.tahbad := stats.tahbad + 1; Print("TAHARA g <> 1 in ", SEED, ".", it, "\n"); fi;
    fi;
    taht := Runtime() - t1;
  fi;
  prb := PresOnGens(Pb, gb);
  Jb := JenningsSeries(Pb);
  stats.rec := stats.rec + 1;
  WriteAll(OUTS, Concatenation("{\"id\":\"", String(SEED), ".", String(it), "\",\"k\":", String(k),
    ",\"rels\":", String(List(prb.rels, ExtRepOfObj)), ",\"zs\":", String([ExtRepOfObj(prb.word(ub))]),
    ",\"nzS\":1,\"tops\":", String(tops), ",\"logord\":", String(Log(Size(Pb), 3)),
    ",\"lcs\":", String(List([1..4], j -> Log(Index(Lb[j], Lb[j+1]), 3))),
    ",\"ab\":", String(AbelianInvariants(Pb)), ",\"eps0\":", String(forceeps),
    ",\"e23\":", String(e23), ",\"e34\":", String(LogExp(Lb[3], Lb[4])), ",\"e4\":", String(LogExp(Lb[4], TrivialSubgroup(Pb))),
    ",\"nonmet\":true,\"zcyc\":", String(IsCyclic(Centre(Pb))), ",\"logZ\":", String(Log(Size(Centre(Pb)), 3)),
    ",\"inM5\":", String(Length(Jb) >= 5 and ub in Jb[5]), ",\"inQ2\":", String(ub in DDb),
    ",\"psi\":", String(psi), ",\"H2\":", String(H2), ",\"psi_d\":", String(psipairs),
    ",\"id3\":", String(id3), ",\"id4\":", String(id4), ",\"idcube\":", String(idcube),
    ",\"tah\":\"", String(tah), "\",\"tah_vars\":", String(tahn), ",\"tah_lat\":", String(tahlat), ",\"tah_ms\":", String(taht),
    ",\"cyc_steps\":", String(nstep), ",\"cyc_outside_g2\":", String(outside),
    ",\"pq_stable\":true,\"dd\":", String(Log(Size(DDb), 3)), ",\"S\":1,\"S4\":1,\"s4skip\":false,\"cyc\":false}\n"));
od;
CloseStream(OUTS);
Print("stats ", stats, "\n");
Print("wall ", Int((NanosecondsSinceEpoch() - T0) / 10^9), " s\n");
QUIT;
