# MATH-445 / D5-50: random METABELIAN 3-groups Q of class 4 with exp(gamma_2/gamma_3) >= 9, as input
# for d5s.py (D_5(Q) = 1 expected by Gupta-Tahara 1985 and by the Tahara-route proof, wiki 887).
# Q = NilpotentQuotient(F/R, 4), R = x_i^(e_i) * (random words), random extra relators,
# all [[x_a,x_b],[x_c,x_d]] (so Q'' = [gamma_2,gamma_2] = 1, since [gamma_2,gamma_3] <= gamma_5).
# Candidates: a nontrivial D_5(Q) is normal and lies in gamma_4 = D_4 (p = 3) and in M_5, so it meets
# Omega_1(Z(Q)) ∩ gamma_4 ∩ M_5 =: S; zs = one generator of each subgroup of order 3 of S.
# (q1gen.g/q9gen.g use Q'' instead of gamma_4: that uses Lemma 6.1, i.e. Gupta-Tahara itself,
# so it cannot be used here.)  Set SEED, NG, KS, DEXP, NEXTRA, MAXLOG, MAXS, OUT before reading.
Read("cfq.g");
Read("../presgens.g");
Reset(GlobalMersenneTwister, SEED); Reset(GlobalRandomSource, SEED);
RW := function(F, wt) local g, c, i; g := GeneratorsOfGroup(F); c := Random(g);
  for i in [2..wt] do c := Comm(c, Random(g)); od; return c^Random([1, 2]); end;
OUTS := OutputTextFile(OUT, false); SetPrintFormattingStatus(OUTS, false);
st := rec(tried := 0, class4 := 0, exp9 := 0, written := 0, bigS := 0, big := 0);
for it in [1..NG] do
  st.tried := st.tried + 1;
  k := Random(KS); F := FreeGroup(k); g := GeneratorsOfGroup(F);
  rels := List([1..k], i -> g[i]^Random(DEXP) / Product(List([1..Random([0..1])], j -> RW(F, Random([2, 3]))), One(F)));
  Append(rels, List([1..Random([0..NEXTRA])], j -> Product(List([1..Random([1, 2])], t -> RW(F, Random([2, 3, 3, 4]))), One(F))));
  Append(rels, Concatenation(List(Combinations([1..k], 2), ab -> List(Combinations([1..k], 2), cd ->
      Comm(Comm(g[ab[1]], g[ab[2]]), Comm(g[cd[1]], g[cd[2]]))))));
  cq := ClassFourQuotient(F, rels, 3); if cq = fail then continue; fi; Q := cq.Q;
  L := LowerCentralSeriesOfGroup(Q);
  if Length(L) <> 5 then continue; fi;
  st.class4 := st.class4 + 1;
  if not IsTrivial(DerivedSubgroup(L[2])) then Error("not metabelian"); fi;
  if Exponent(L[2] / L[3]) < 9 then continue; fi;
  st.exp9 := st.exp9 + 1;
  if Log(Size(Q), 3) > MAXLOG then st.big := st.big + 1; continue; fi;
  gens := cq.gens;
  if Group(gens) <> Q then Error("gens"); fi;
  J := JenningsSeries(Q);
  if Length(J) >= 5 then M5 := J[5]; else M5 := TrivialSubgroup(Q); fi;
  S := Intersection(Omega(Centre(Q), 3, 1), L[4], M5);
  if Log(Size(S), 3) > MAXS then st.bigS := st.bigS + 1; continue; fi;
  pr := PresOnGens(Q, gens);
  zs := List(Filtered(List(ConjugacyClassesSubgroups(S), Representative), H -> Size(H) = 3),
             H -> ExtRepOfObj(pr.word(First(GeneratorsOfGroup(H), x -> x <> One(Q)))));
  st.written := st.written + 1;
  WriteAll(OUTS, Concatenation("{\"id\":\"", String(SEED), ".", String(it), "\",\"k\":", String(k),
    ",\"rels\":", String(List(pr.rels, ExtRepOfObj)), ",\"zs\":", String(zs),
    ",\"logord\":", String(Log(Size(Q), 3)),
    ",\"lcs\":", String(List([1..4], j -> Log(Index(L[j], L[j+1]), 3))),
    ",\"ab\":", String(AbelianInvariants(Q)), ",\"expL2\":", String(Exponent(L[2] / L[3])),
    ",\"expL3\":", String(Exponent(L[3] / L[4])), ",\"expG4\":", String(Exponent(L[4])),
    ",\"S\":", String(Log(Size(S), 3)), ",\"met\":true}\n"));
od;
CloseStream(OUTS);
Print("stats ", st, "\n");
QUIT;
