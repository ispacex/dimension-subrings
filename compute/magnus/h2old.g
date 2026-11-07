# MATH-444: for the gamma_4 = C_3 records of the MATH-443 main run (h2old.py), whether (H2) gamma_2^9 <= gamma_4
# holds, i.e. whether the theorem of the MATH-444 wiki page already covers them; also the Tahara solver.
Read("tahara61.g");
WordOf := function(F, e) local g, w, i; g := GeneratorsOfGroup(F); w := One(F);
  for i in [1, 3 .. Length(e) - 1] do w := w * g[e[i]]^e[i+1]; od; return w; end;
nH2 := 0; nnot := 0; ntah := 0; nbad := 0; nfree := 0;
for r in RECS do
  F := FreeGroup(r.k);
  G := F / List(r.rels, e -> WordOf(F, e));
  epi := EpimorphismPGroup(G, 3, r.pclass + 1); P := Image(epi);
  if Log(Size(P), 3) <> r.logord then Print("ORDER MISMATCH ", r.id, "\n"); continue; fi;
  L := LowerCentralSeriesOfGroup(P);
  P9 := ClosureGroup(L[4], List(GeneratorsOfGroup(L[2]), a -> a^9));
  psi := Log(Index(P9, L[4]), 3);
  T := TaharaData(P, fail); V := TaharaVars(T);
  lat := TaharaLattice(T, V, TaharaConds(T, V, rec(drop := [])));
  tah := ForAll(lat, tau -> IsOne(TaharaGen(T, V, tau).g));
  free := Log(Size(Subgroup(P, List(IdentityMat(V.n), tau -> TaharaGen(T, V, tau).g))), 3);
  if free > 0 then nfree := nfree + 1; fi;
  if psi = 0 then nH2 := nH2 + 1; else nnot := nnot + 1; fi;
  if tah then ntah := ntah + 1; else nbad := nbad + 1; Print("TAHARA g <> 1 in ", r.id, "\n"); fi;
  Print(r.id, " ab ", AbelianInvariants(P), " |g4| ", Size(L[4]), " psi ", psi, " tah ", tah, " free ", free, " vars ", V.n, "\n");
od;
Print("records ", Length(RECS), " H2 ", nH2, " notH2 ", nnot, " tahara g=1 ", ntah, " g<>1 ", nbad, " non-vacuous (g not 1 on Z^n) ", nfree, "\n");
QUIT;
