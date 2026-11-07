# MATH-443 / D5-5: random 3-groups Q of class 4 with Q/gamma_2(Q) having TWO invariants >= 9,
# Q/gamma_2 = C_d1 x ... x C_dt x C_3^(s-t) (e.g. C_9 x C_9 x C_3^(s-2), C_27 x C_9 x C_3^(s-2),
# C_9^3 x C_3^(s-3)) -- the case not covered by Thm. 6.8 (thm:exp3plus) of the D5 paper.
# Adapted from q9gen.g (same construction of Q, same output read by d5s.py).
#
# Set SEED, NG (groups to try), KS (list of ranks s), TOPS (list of lists of the large invariants,
# e.g. [[9,9]] or [[27,9]]), MODE (1 or 2), EPS0 (probability of forcing x_j^(d_j) into gamma_3 for
# all the top generators), OUT (jsonl) before reading this file; optional EXTRAW (default
# [2, 3, 3, 4], weights of the extra relators; [3, 3, 4] gives larger groups), PQCLASS, S4MAX.
#
# G = <x_1..x_s | x_i^3 = W_i (i <= s-t), x_j^(d_j) = W_j (top j), extra relators, all left-normed
# commutators of weight 5>.  Q = G/gamma_5(G) as the 3-quotient of 3-class PQCLASS, then P/gamma_5(P).
# Default PQCLASS = a + 3b + 1 where 3^a >= 3^b are the two largest invariants: gamma_2/gamma_3
# (a quotient of Lambda^2 Q_ab), gamma_3/gamma_4 and gamma_4 have exponent dividing 3^b, so
# exp gamma_4 | 3^b, exp gamma_3 | 3^(2b), exp gamma_2 | 3^(3b), exp Q | 3^(a+3b), and the lower
# exponent-3 central series P_c = prod_j gamma_j^(3^(c-j)) is trivial for c = a + 3b + 1 (for
# b = 1 this is q9gen.g's a + 4).  We check class 4, Q/gamma_2 = the prescribed invariants, and
# that class PQCLASS + 1 adds nothing (pq_stable).
#
# Per group: e23, e34, e4 = log_3 of the exponents of gamma_2/gamma_3, gamma_3/gamma_4, gamma_4
# (the proof of Thm. 6.8 needs e23 = 1); eps0 = (x_j^(d_j) in gamma_3 for all top j); zcyc = Z(Q)
# cyclic (a minimal counterexample has cyclic centre; recorded, not imposed);
# S = Omega_1(Z) ∩ Q'' ∩ M_5 (as q9gen.g) and S4 = Omega_1(Z) ∩ gamma_4 ∩ M_5 (contains S and every
# element of order 3 of Z ∩ D_5, with no assumption D_5 <= Q'').  zs = one generator of each
# subgroup of order 3 of S (the first nzS entries), then of each subgroup of order 3 of S4 not in S
# (only when |S4| <= 3^S4MAX, default 4; s4skip otherwise).  d5s.py decides z in D_5 for each.
LoadPackage("anupq");
Read("presgens.g");
if not IsBound(EXTRAW) then EXTRAW := [2, 3, 3, 4]; fi;
if not IsBound(S4MAX) then S4MAX := 4; fi;
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
LogExp := function(H, N) if Size(H) = Size(N) then return 0; fi; return Log(Exponent(H / N), 3); end;
Order3Reps := function(A, B)   # one generator of each subgroup of order 3 of A not contained in B
  local R, z;
  R := [];
  for z in Elements(A) do
    if z <> One(A) and not z in B and z < z^-1 then Add(R, z); fi;
  od;
  return R;
end;
OUTS := OutputTextFile(OUT, false); SetPrintFormattingStatus(OUTS, false);
stats := rec(tried := 0, ok := 0, nonmet := 0, eps0 := 0, e23is2 := 0, nonmete23is2 := 0,
             Snontriv := 0, S4nontriv := 0, zcyc := 0, pqunstable := 0, skipS := 0, s4skip := 0);
T0 := NanosecondsSinceEpoch();
for it in [1..NG] do
  tops := Random(TOPS); t := Length(tops);
  k := Random(Filtered(KS, x -> x >= t));
  ords := Concatenation(List([1..k-t], i -> 3), tops);
  lg := Reversed(SortedList(List(ords, d -> LogInt(d, 3))));
  if IsBound(PQCLASS) then pqc := PQCLASS; else pqc := lg[1] + 3 * lg[2] + 1; fi;
  F := FreeGroup(k); g := GeneratorsOfGroup(F);
  forceeps := Random([1..100]) <= Int(100 * EPS0);
  rels := List([1..k-t], i -> g[i]^3 / Product(List([1..Random([0..2])], j -> RW(F, Random([2, 2, 3]))), One(F)));
  for i in [k-t+1..k] do
    if forceeps then   # x_i^(d_i) in gamma_3
      Add(rels, g[i]^ords[i] / Product(List([1..Random([0..2])], j -> RW(F, Random([3, 3, 4]))), One(F)));
    else
      Add(rels, g[i]^ords[i] / Product(List([1..Random([1..2])], j -> RW(F, Random([2, 2, 3]))), One(F)));
    fi;
  od;
  Append(rels, List([1..Random([0..k+2])], j -> Product(List([1..Random([1..2])], t -> RW(F, Random(EXTRAW))), One(F))));
  if MODE = 2 then   # cubes of gamma_2 into Q'' (Q'' ∩ M_5 != 1), gamma_4 cut down
    Append(rels, List([1..Random([1..2])], j -> RW(F, 2)^3 / Comm(RW(F, 2), RW(F, 2))));
    Append(rels, List([1..Random([2..2*k+4])], j -> RW(F, 4)));
  fi;
  stats.tried := stats.tried + 1;
  Fp := F / Concatenation(rels, W5(F));
  epi := EpimorphismPGroup(Fp, 3, pqc);
  P0 := Image(epi);
  L0 := LowerCentralSeriesOfGroup(P0);
  if Length(L0) >= 5 then nat := NaturalHomomorphismByNormalSubgroup(P0, L0[5]); P := Image(nat);
  else nat := IdentityMapping(P0); P := P0; fi;
  L := LowerCentralSeriesOfGroup(P);
  ab := AbelianInvariants(P);
  if Length(L) - 1 <> 4 or SortedList(ab) <> SortedList(ords) then continue; fi;
  stats.ok := stats.ok + 1;
  gens := List(GeneratorsOfGroup(Fp), x -> Image(nat, Image(epi, x)));
  pqstable := Size(Image(EpimorphismPGroup(Fp, 3, pqc + 1))) = Size(P0);
  if not pqstable then stats.pqunstable := stats.pqunstable + 1; fi;
  eps0 := ForAll([k-t+1..k], i -> gens[i]^ords[i] in L[3]);
  if eps0 then stats.eps0 := stats.eps0 + 1; fi;
  e23 := LogExp(L[2], L[3]); e34 := LogExp(L[3], L[4]); e4 := LogExp(L[4], TrivialSubgroup(P));
  if e23 >= 2 then stats.e23is2 := stats.e23is2 + 1; fi;
  DD := DerivedSubgroup(L[2]);
  nonmet := not IsTrivial(DD);
  if nonmet then stats.nonmet := stats.nonmet + 1; if e23 >= 2 then stats.nonmete23is2 := stats.nonmete23is2 + 1; fi; fi;
  ZQ := Centre(P);
  zcyc := IsCyclic(ZQ);
  if zcyc then stats.zcyc := stats.zcyc + 1; fi;
  J := JenningsSeries(P);
  if Length(J) >= 5 then M5 := J[5]; else M5 := TrivialSubgroup(P); fi;
  Om1 := Omega(ZQ, 3, 1);
  S := Intersection(Om1, DD, M5);
  S4 := Intersection(Om1, L[4], M5);
  if not IsTrivial(S) then stats.Snontriv := stats.Snontriv + 1; fi;
  if not IsTrivial(S4) then stats.S4nontriv := stats.S4nontriv + 1; fi;
  if Size(S) > 3^5 then Print("skip big S ", Size(S), "\n"); stats.skipS := stats.skipS + 1; continue; fi;
  pr := PresOnGens(P, gens);
  zS := Order3Reps(S, TrivialSubgroup(P));
  s4skip := Size(S4) > 3^S4MAX;
  if s4skip then stats.s4skip := stats.s4skip + 1; zX := []; else zX := Order3Reps(S4, S); fi;
  zs := List(Concatenation(zS, zX), z -> ExtRepOfObj(pr.word(z)));
  WriteAll(OUTS, Concatenation("{\"id\":\"", String(SEED), ".", String(it), "\",\"k\":", String(k),
    ",\"rels\":", String(List(pr.rels, ExtRepOfObj)), ",\"zs\":", String(zs),
    ",\"nzS\":", String(Length(zS)), ",\"tops\":", String(tops),
    ",\"logord\":", String(Log(Size(P), 3)),
    ",\"lcs\":", String(List([1..4], j -> Log(Index(L[j], L[j+1]), 3))),
    ",\"ab\":", String(ab), ",\"eps0\":", String(eps0),
    ",\"e23\":", String(e23), ",\"e34\":", String(e34), ",\"e4\":", String(e4),
    ",\"nonmet\":", String(nonmet), ",\"zcyc\":", String(zcyc), ",\"logZ\":", String(Log(Size(ZQ), 3)),
    ",\"pclass\":", String(Length(PCentralSeries(P0, 3)) - 1), ",\"pqc\":", String(pqc),
    ",\"pq_stable\":", String(pqstable),
    ",\"dd\":", String(Log(Size(DD), 3)), ",\"S\":", String(Log(Size(S), 3)),
    ",\"S4\":", String(Log(Size(S4), 3)), ",\"s4skip\":", String(s4skip), "}\n"));
od;
CloseStream(OUTS);
Print("stats ", stats, "\n");
Print("wall ", Int((NanosecondsSinceEpoch() - T0) / 10^9), " s\n");
QUIT;
