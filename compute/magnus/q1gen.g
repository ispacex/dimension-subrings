# MATH-127 (1): random 3-groups Q of class 4 with Q/gamma_2 of exponent 3, non-metabelian, as a test
# of the theorem "D_5(Q) = 1 when Q/gamma_2(Q) has exponent 3" (wiki, child of 687).
# Set SEED, NG (groups to try), KS (list of ranks), OUT (jsonl) before reading this file.
# Q = class-4 3-quotient (ANUPQ, p-class 4 = lower central class 4 here, since Q^3 <= gamma_2)
# of <x_1..x_k | x_i^3 = W_i, extra relators>, W_i random in gamma_2.
# Per group: identity checks used in the proof; S = Omega_1(Z) ∩ Q'' ∩ M_5 (D_5 <= S·... : a nontrivial
# normal D_5 meets Z, and D_5 <= Q'' ∩ M_5 of exponent 3), one word per subgroup of order 3 of S.
LoadPackage("anupq");
Read("presgens.g");
Reset(GlobalMersenneTwister, SEED); Reset(GlobalRandomSource, SEED);
RW := function(F, wt)   # random left-normed commutator of weight wt in the generators
  local g, c, i;
  g := GeneratorsOfGroup(F);
  c := Random(g);
  for i in [2..wt] do c := Comm(c, Random(g)); od;
  return c^Random([1, 2]);
end;
OUTS := OutputTextFile(OUT, false); SetPrintFormattingStatus(OUTS, false);
stats := rec(tried := 0, ok := 0, nonmet := 0, Snontriv := 0, idfail := 0);
for it in [1..NG] do
  k := Random(KS);
  F := FreeGroup(k); g := GeneratorsOfGroup(F);
  rels := List([1..k], i -> g[i]^3 / Product(List([1..Random([0..2])], j -> RW(F, Random([2, 2, 3]))), One(F)));
  Append(rels, List([1..Random([0..k+2])], j -> Product(List([1..Random([1..2])], t -> RW(F, Random([2, 3, 3, 4]))), One(F))));
  stats.tried := stats.tried + 1;
  Fp := F / rels;
  epi := EpimorphismPGroup(Fp, 3, 4);
  P := Image(epi);
  L := LowerCentralSeriesOfGroup(P);
  if Length(L) - 1 <> 4 or Set(AbelianInvariants(P)) <> [3] then continue; fi;
  stats.ok := stats.ok + 1;
  DD := DerivedSubgroup(L[2]);
  if IsTrivial(DD) then continue; fi;
  stats.nonmet := stats.nonmet + 1;
  # identities used in the proof (random elements)
  idok := ForAll([1..20], function(t)
    local x, y, a, b;
    x := Random(P); y := Random(P); a := Random(L[2]); b := Random(L[2]);
    return Comm(x^3, a) = Comm(x, a^3)                       # [x^3,a] = [x,a]^3 = [x,a^3]
       and Comm(x^3, a) = Comm(x, a)^3
       and Comm(a, x^3) = Comm(a, x)^3
       and (Comm(x, y)^3 / Comm(x^3, y)) in L[4]              # [x,y]^3 = [x^3,y] mod gamma_4
       and (not x^3 in L[3] or Comm(x, y)^3 in L[4])          # C(K,V) <= N
       and (a*b)^3 / (a^3*b^3) in L[4];                       # cube map gamma_2/gamma_3 -> gamma_3/gamma_4 linear
  end) and Exponent(L[4]) = 3 and Exponent(L[2] / L[3]) = 3 and Exponent(L[3] / L[4]) = 3;
  if not idok then stats.idfail := stats.idfail + 1; fi;
  J := JenningsSeries(P);
  if Length(J) >= 5 then M5 := J[5]; else M5 := TrivialSubgroup(P); fi;
  S := Intersection(Omega(Centre(P), 3, 1), DD, M5);
  if not IsTrivial(S) then stats.Snontriv := stats.Snontriv + 1; fi;
  if Size(S) > 3^5 then Print("skip big S ", Size(S), "\n"); continue; fi;
  gens := List(GeneratorsOfGroup(Fp), x -> Image(epi, x));
  pr := PresOnGens(P, gens);
  zs := List(Filtered(List(ConjugacyClassesSubgroups(S), Representative), H -> Size(H) = 3),
             H -> ExtRepOfObj(pr.word(First(GeneratorsOfGroup(H), x -> x <> One(P)))));
  WriteAll(OUTS, Concatenation("{\"id\":\"", String(SEED), ".", String(it), "\",\"k\":", String(k),
    ",\"rels\":", String(List(pr.rels, ExtRepOfObj)), ",\"zs\":", String(zs),
    ",\"logord\":", String(Log(Size(P), 3)),
    ",\"lcs\":", String(List([1..4], j -> Log(Index(L[j], L[j+1]), 3))),
    ",\"dd\":", String(Log(Size(DD), 3)), ",\"S\":", String(Log(Size(S), 3)),
    ",\"id_ok\":", String(idok), "}\n"));
od;
CloseStream(OUTS);
Print("stats ", stats, "\n");
QUIT;
