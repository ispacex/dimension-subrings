# MATH-135: random 3-groups Q of class 4 with Q/gamma_2(Q) = C_9 x C_3^(k-1), as a test of
# "D_5(Q) = 1 when Q/gamma_2 = C_9 x C_3^(s-1)" (wiki, child of 690).  Adapted from q1gen.g.
# Set SEED, NG (groups to try), KS (list of ranks k = s), MODE (1 or 2), EPS0 (probability of
# forcing x_k^9 into gamma_3), OUT (jsonl) before reading this file; optional PQCLASS (default 6).
#
# G = <x_1..x_k | x_i^3 = W_i (i<k), x_k^9 = W_k, extra relators, all left-normed commutators of
# weight 5 in the x_i>.  The weight-5 relators make G/N nilpotent of class <= 4 for every N with G/N
# nilpotent, so the 3-quotient of 3-class PQCLASS is G/(P_c(G)) with gamma_5 = 1.  The lower
# exponent-3 class of a class-4 group with these exponents is <= 6 (x^9 in gamma_2, gamma_2/gamma_3,
# gamma_3/gamma_4, gamma_4 of exponent 3, so exp Q | 3^5 and P_6 = prod gamma_j^(3^(6-j)) = 1), hence
# PQCLASS = 6 gives the largest finite class-4 quotient Q = G/gamma_5(G).  We still pass to
# P/gamma_5(P) and check class 4 and Q/gamma_2 = [3,..,3,9]; with nq loaded we also compare |Q| with
# |NilpotentQuotient(G0, 4)| for G0 = G without the weight-5 relators.
#
# Per group: the identities used in the proof on random elements (id_ok), eps = (x_k^9 in gamma_3),
# m = rank of the cube map P on Omega = {x : x^3 in gamma_2} (mod gamma_2 -> gamma_2/gamma_3), and
# S = Omega_1(Z) ∩ Q'' ∩ M_5 with one word per subgroup of order 3 of S (as q1gen.g; read by d5s.py).
LoadPackage("anupq");
HAVENQ := LoadPackage("nq") = true;
Read("presgens.g");
if not IsBound(PQCLASS) then PQCLASS := 6; fi;
Reset(GlobalMersenneTwister, SEED); Reset(GlobalRandomSource, SEED);
RW := function(F, wt)   # random left-normed commutator of weight wt in the generators
  local g, c, i;
  g := GeneratorsOfGroup(F);
  c := Random(g);
  for i in [2..wt] do c := Comm(c, Random(g)); od;
  return c^Random([1, 2]);
end;
W5 := function(F)        # all left-normed commutators of weight 5 in the generators
  local g, L, i, c;
  g := GeneratorsOfGroup(F);
  L := List(g, x -> x);
  for i in [2..5] do L := Concatenation(List(L, c -> List(g, y -> Comm(c, y)))); od;
  return Filtered(L, c -> c <> One(F));
end;
RankMod3 := function(hom, A, vs)
  local M;
  M := List(vs, v -> ExponentsOfPcElement(Pcgs(A), Image(hom, v)) * One(GF(3)));
  if Length(M) = 0 or Length(M[1]) = 0 then return 0; fi;
  return RankMat(M);
end;
OUTS := OutputTextFile(OUT, false); SetPrintFormattingStatus(OUTS, false);
stats := rec(tried := 0, ok := 0, nonmet := 0, eps0 := 0, eps0nonmet := 0, Snontriv := 0,
             eps0S := 0, idfail := 0, nqfail := 0, skipS := 0);
T0 := NanosecondsSinceEpoch();
for it in [1..NG] do
  k := Random(KS);
  F := FreeGroup(k); g := GeneratorsOfGroup(F);
  forceeps := Random([1..100]) <= Int(100 * EPS0);
  rels := List([1..k-1], i -> g[i]^3 / Product(List([1..Random([0..2])], j -> RW(F, Random([2, 2, 3]))), One(F)));
  if forceeps then   # x_k^9 in gamma_3: W_k of weight >= 3
    Add(rels, g[k]^9 / Product(List([1..Random([0..2])], j -> RW(F, Random([3, 3, 4]))), One(F)));
  else
    Add(rels, g[k]^9 / Product(List([1..Random([1..2])], j -> RW(F, Random([2, 2, 3]))), One(F)));
  fi;
  Append(rels, List([1..Random([0..k+2])], j -> Product(List([1..Random([1..2])], t -> RW(F, Random([2, 3, 3, 4]))), One(F))));
  if MODE = 2 then   # cubes of gamma_2 into Q'' (Q'' ∩ M_5 != 1), gamma_4 cut down
    Append(rels, List([1..Random([1..2])], j -> RW(F, 2)^3 / Comm(RW(F, 2), RW(F, 2))));
    Append(rels, List([1..Random([2..2*k+4])], j -> RW(F, 4)));
  fi;
  stats.tried := stats.tried + 1;
  Fp := F / Concatenation(rels, W5(F));
  epi := EpimorphismPGroup(Fp, 3, PQCLASS);
  P0 := Image(epi);
  L0 := LowerCentralSeriesOfGroup(P0);
  if Length(L0) >= 5 then nat := NaturalHomomorphismByNormalSubgroup(P0, L0[5]); P := Image(nat);
  else nat := IdentityMapping(P0); P := P0; fi;
  L := LowerCentralSeriesOfGroup(P);
  ab := AbelianInvariants(P);
  if Length(L) - 1 <> 4 or SortedList(ab) <> Concatenation(List([1..k-1], i -> 3), [9]) then continue; fi;
  stats.ok := stats.ok + 1;
  gens := List(GeneratorsOfGroup(Fp), x -> Image(nat, Image(epi, x)));
  nqok := fail;
  if HAVENQ then
    nqok := Size(NilpotentQuotient(F / rels, 4)) = Size(P);
    if not nqok then stats.nqfail := stats.nqfail + 1; fi;
  fi;
  xk := gens[k];
  eps0 := xk^9 in L[3];
  if eps0 then stats.eps0 := stats.eps0 + 1; fi;
  DD := DerivedSubgroup(L[2]);
  nonmet := not IsTrivial(DD);
  if nonmet then stats.nonmet := stats.nonmet + 1; if eps0 then stats.eps0nonmet := stats.eps0nonmet + 1; fi; fi;
  # Omega = {x : x^3 in gamma_2} = <x_1..x_{k-1}, x_k^3, gamma_2>; cube map Omega -> gamma_2/gamma_3
  Om := ClosureGroup(L[2], Concatenation(gens{[1..k-1]}, [xk^3]));
  h23 := NaturalHomomorphismByNormalSubgroup(L[2], L[3]); A23 := Image(h23);
  m := RankMod3(h23, A23, List(Concatenation(gens{[1..k-1]}, [xk^3]), x -> x^3));
  Lx9 := ClosureGroup(L[3], xk^9);
  # identities used in the proof (random elements)
  idok := ForAll([1..20], function(t)
    local x, y, a, b, w;
    x := Random(P); y := Random(P); a := Random(L[2]); b := Random(L[2]); w := Random(Om);
    return Comm(x^9, y) = Comm(x, y)^9                         # key lemma [x^9,y] = [x,y]^9
       and Comm(x^3, a) = Comm(x, a^3)                         # Lemma 2(c), any x in Q
       and Comm(x^3, a) = Comm(x, a)^3
       and Comm(a, x^3) = Comm(a, x)^3
       and Comm(a^3, x) = Comm(a, x)^3
       and Comm(w^3, y^3) = Comm(w^9, y)                       # [x_i^3,x_s^3] = [x_i^9,x_s]
       and Comm(w^3, y)^3 = Comm(w^9, y)
       and Comm(x^9, a) = One(P)                               # [Q^9, gamma_2] = 1
       and Comm(x^27, y) = One(P)                              # Q^27 central
       and (a*b)^3 = a^3*b^3                                   # cube on gamma_2 additive
       and x^9 in Lx9                                          # x^9 gamma_3 in <x_k^9 gamma_3>
       and w^3 in L[2];
  end) and Exponent(L[4]) = 3 and Exponent(L[2] / L[3]) = 3 and Exponent(L[3] / L[4]) = 3
       and not xk^3 in L[2] and Index(P, Om) = 3;
  if not idok then stats.idfail := stats.idfail + 1; fi;
  J := JenningsSeries(P);
  if Length(J) >= 5 then M5 := J[5]; else M5 := TrivialSubgroup(P); fi;
  S := Intersection(Omega(Centre(P), 3, 1), DD, M5);
  if not IsTrivial(S) then stats.Snontriv := stats.Snontriv + 1; if eps0 then stats.eps0S := stats.eps0S + 1; fi; fi;
  if Size(S) > 3^5 then Print("skip big S ", Size(S), "\n"); stats.skipS := stats.skipS + 1; continue; fi;
  pr := PresOnGens(P, gens);
  zs := List(Filtered(List(ConjugacyClassesSubgroups(S), Representative), H -> Size(H) = 3),
             H -> ExtRepOfObj(pr.word(First(GeneratorsOfGroup(H), x -> x <> One(P)))));
  WriteAll(OUTS, Concatenation("{\"id\":\"", String(SEED), ".", String(it), "\",\"k\":", String(k),
    ",\"rels\":", String(List(pr.rels, ExtRepOfObj)), ",\"zs\":", String(zs),
    ",\"logord\":", String(Log(Size(P), 3)),
    ",\"lcs\":", String(List([1..4], j -> Log(Index(L[j], L[j+1]), 3))),
    ",\"ab\":", String(ab), ",\"eps0\":", String(eps0), ",\"m\":", String(m),
    ",\"nonmet\":", String(nonmet), ",\"pclass\":", String(Length(PCentralSeries(P0, 3)) - 1),
    ",\"nq_ok\":", String(nqok),
    ",\"dd\":", String(Log(Size(DD), 3)), ",\"S\":", String(Log(Size(S), 3)),
    ",\"id_ok\":", String(idok), "}\n"));
od;
CloseStream(OUTS);
Print("stats ", stats, "\n");
Print("wall ", Int((NanosecondsSinceEpoch() - T0) / 10^9), " s\n");
QUIT;
