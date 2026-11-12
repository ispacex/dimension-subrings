# Driver for lib450.g (MATH-450).  Set before reading: MODE, NG, KS, TOPS, EXTRAW, GENORDER, FORCE13, OUT, and the
# lib446 knobs (MAXV, WATCH, TRIALS, BIGLAT).  Per group one JSON line; at the end OUT.final with the totals:
#   LAT <name> rec(n, ne, groups, groups_ne): vectors / vectors with R <> 0 / groups / groups with some R <> 0,
#   for r = R (all terms) and rB = R_B (terms on big indices only) and dB = R - R_B;
#   FULL: g(tau) <> 1 on the full lattice (A)-(F) (a counterexample to D_5 = 1 would show here), and the share of
#   groups where some term of R_B is <> 0 on the full lattice (nonvacuity);  STRUCT: omega / t of order 9.
if not IsBound(GENORDER) then GENORDER := "std"; fi;
LATNAMES := ["W", "WnoB3", "WnoD23", "Wnoc1", "WB", "WD2", "WBD2", "WBD2A", "thm2", "thm2A", "full"];
TOT := rec(tried := 0, groups := 0, skipped := 0, sanity_bad := 0, g2R_bad := 0, g2R_ne := 0,
  gbad := 0, gbad_groups := 0, full_termsne_groups := 0, cc9 := 0, cY9 := 0, tY9 := 0, nB := []);
LT := rec();
for nm in LATNAMES do for kind in ["r", "rB", "dB"] do
  LT.(Concatenation(nm, "_", kind)) := rec(n := 0, ne := 0, groups := 0, groups_ne := 0);
od; od;
EXAMPLES := [];

for it in [1..NG] do
  if Runtime() - STARTTIME > WATCH * 1000 then Print("WATCH stop\n"); break; fi;
  tops := Random(TOPS);
  kk := Random(Filtered(KS, x -> x >= Length(tops)));
  ords := Concatenation(List([1..kk - Length(tops)], i -> 3), tops);
  if GENORDER = "rev" then ords := Reversed(ords); fi;
  TOT.tried := TOT.tried + 1;
  GG := OneC9(ords, EXTRAW, TRIALS);
  if GG = fail then TOT.skipped := TOT.skipped + 1; Print("skip ", it, "\n"); continue; fi;
  LL := LowerCentralSeriesOfGroup(GG);
  AA := TaharaData(GG, AdaptedX1(GG, LL)); DD := TaharaVars(AA);
  if DD.n > MAXV then TOT.skipped := TOT.skipped + 1; Print("big ", it, " nvars=", DD.n, "\n"); continue; fi;
  TC := TaggedConds(AA, DD);
  LA := Lattices450(AA, DD, TC);
  if Length(LA.full) > BIGLAT then TOT.skipped := TOT.skipped + 1; Print("biglat ", it, "\n"); continue; fi;
  TOT.groups := TOT.groups + 1;
  lg := G4Log(AA);
  r := RVec(AA, DD, lg); rB := RVecB(AA, DD, lg); dB := List([1..DD.n], k -> (r[k] - rB[k]) mod 9);
  nB := Length(BigIdx(AA)); Add(TOT.nB, nB);
  # sanity of the vector form against lib446's ResidualParts (on the W lattice and on unit vectors)
  TOT.sanity_bad := TOT.sanity_bad + RVecSanity(AA, DD, lg, r, Concatenation(LA.W, IdentityMat(DD.n)));
  # Theorem 2 on its lattice (2g = R) and g on the full lattice
  for tau in LA.thm2 do
    g := TaharaGen(AA, DD, tau).g;
    if lg(g^2) <> (r * tau) mod 9 then TOT.g2R_bad := TOT.g2R_bad + 1; fi;
    if (r * tau) mod 9 <> 0 then TOT.g2R_ne := TOT.g2R_ne + 1; fi;
  od;
  gb := Number(LA.full, tau -> not IsOne(TaharaGen(AA, DD, tau).g));
  TOT.gbad := TOT.gbad + gb; if gb > 0 then TOT.gbad_groups := TOT.gbad_groups + 1; fi;
  # nonvacuity on the full lattice: some single term of R_B is <> 0 for some admissible tau
  termsne := ForAny(LA.full, tau -> ForAny([1..DD.n], k -> (rB[k] * tau[k]) mod 9 <> 0));
  if termsne then TOT.full_termsne_groups := TOT.full_termsne_groups + 1; fi;
  st := OmegaStruct(AA, lg);
  if st.cc9 > 0 then TOT.cc9 := TOT.cc9 + 1; fi;
  if st.cY9 > 0 then TOT.cY9 := TOT.cY9 + 1; fi;
  if st.tY9 > 0 then TOT.tY9 := TOT.tY9 + 1; fi;
  rec_ne := rec();
  for nm in LATNAMES do
    for kind in ["r", "rB", "dB"] do
      if kind = "r" then vv := r; elif kind = "rB" then vv := rB; else vv := dB; fi;
      key := Concatenation(nm, "_", kind); ne := NeCount(LA.(nm), vv);
      LT.(key).n := LT.(key).n + Length(LA.(nm)); LT.(key).ne := LT.(key).ne + ne;
      LT.(key).groups := LT.(key).groups + 1; if ne > 0 then LT.(key).groups_ne := LT.(key).groups_ne + 1; fi;
      rec_ne.(key) := ne;
    od;
  od;
  # one explicit obstruction per shard: a tau of W with R(tau) <> 0, its nonzero (u, w', w'') entries on B
  if Length(EXAMPLES) < 3 and nB >= 3 then
    tau := First(LA.W, t -> (r * t) mod 9 <> 0);
    if tau <> fail then
      Add(EXAMPLES, rec(id := it, d := AA.d, R := (r * tau) mod 9,
        u := Filtered(List(Combinations(BigIdx(AA), 2), p -> [p, tau[DD.idx.u[p[1]][p[2]]]]), y -> y[2] <> 0),
        terms := Filtered(List([1..DD.n], k -> [k, tau[k], rB[k]]), y -> (y[2] * y[3]) mod 9 <> 0)));
    fi;
  fi;
  emit(Concatenation("{\"kind\":\"group\",\"id\":", String(it), ",\"ab\":", String(AbelianInvariants(GG)),
    ",\"logord\":", String(Log(Size(GG), 3)), ",\"zcyc\":", String(IsCyclic(Centre(GG))), ",\"d\":", String(AA.d),
    ",\"nB\":", String(nB), ",\"nvars\":", String(DD.n), ",\"full\":", String(Length(LA.full)), ",\"gbad\":", String(gb),
    ",\"termsne\":", String(termsne), ",\"struct\":\"", String(st), "\",\"ne\":\"", String(rec_ne), "\"}"));
od;
CloseStream(OUTS);
FIN := OutputTextFile(Concatenation(OUT, ".final"), false); SetPrintFormattingStatus(FIN, false);
nBs := Collected(TOT.nB); Unbind(TOT.nB);
WriteAll(FIN, Concatenation("TOT ", String(TOT), " nB=", String(nBs), "\n"));
for nm in LATNAMES do for kind in ["r", "rB", "dB"] do
  key := Concatenation(nm, "_", kind); WriteAll(FIN, Concatenation("LAT ", key, " ", String(LT.(key)), "\n"));
od; od;
for ex in EXAMPLES do WriteAll(FIN, Concatenation("EX ", String(ex), "\n")); od;
CloseStream(FIN);
Print("TOT ", String(TOT), "\n");
QUIT;
