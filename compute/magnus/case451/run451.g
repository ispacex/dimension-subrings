# run451.g -- driver (MATH-451).  Set MODE, NG, KS, TOPS, KG4 (log_3 |gamma_4|), EXTRAW, GENORDER, OUT, D5OUT.
# Per group (gamma_4 = C_{3^KG4}, cyclic centre, adapted basis AdaptedX1):
#  * full Tahara lattice (A)-(F): g(tau) = 1? and the image of g on Z^n (non-vacuity);
#  * Theorem C of wiki 891 Sec. 12: on W = (c1) + (B) mod 3 + (D2) mod 3, every term of R(tau) and R(tau) itself
#    have log_3-order <= mu - 1, mu = log_3 of the third largest invariant of Q_ab (0 if s < 3);
#    controls: W without (B) mod 3, without (D2) mod 3, (c1) only, no condition;
#  * the Theorem 2 lattice ((B),(D2),(E),(F2),(c1)): g^2 = R(tau) (counts of R <> 1);
#  * form values: omega(cbar_ih, Ybar_j) has order <= d(i); omega(cbar_{s-1,s}, cbar_ij) has order <= 3^mu;
#  * a record for d5s.py (z = generator of Omega_1(Z) = Omega_1(gamma_4)).
if not IsBound(GENORDER) then GENORDER := "std"; fi;
D5S := OutputTextFile(D5OUT, false); SetPrintFormattingStatus(D5S, false);
stats := rec(tried := 0, groups := 0, skipped := 0, gbad := 0, nonvac := 0, thm2bad := 0, thm2nontriv := 0,
  Wviol := 0, Wpartviol := 0, Wtermviol := 0, Wsharp := 0, ctl_noB := 0, ctl_noD := 0, ctl_c1 := 0, ctl_free := 0,
  omYbad := 0, pairbad := 0, pairY := 0, mu1 := 0, mu2 := 0, Wnontriv := 0);
for it in [1..NG] do
  if Runtime() - STARTTIME > WATCH * 1000 then Print("WATCH stop\n"); break; fi;
  tops := Random(TOPS);
  kk := Random(Filtered(KS, x -> x >= Length(tops)));
  ords := Concatenation(List([1..kk - Length(tops)], i -> 3), tops);
  if GENORDER = "rev" then ords := Reversed(ords); fi;
  stats.tried := stats.tried + 1;
  RR := OneC3k(ords, EXTRAW, TRIALS, KG4);
  if RR = fail then stats.skipped := stats.skipped + 1; Print("skip ", it, "\n"); continue; fi;
  GG := RR[1];
  LL := LowerCentralSeriesOfGroup(GG);
  AA := TaharaData(GG, AdaptedX1(GG, LL)); DD := TaharaVars(AA);
  if DD.n > MAXV then stats.skipped := stats.skipped + 1; Print("big ", it, " nvars=", DD.n, "\n"); continue; fi;
  lat := TaharaLattice(AA, DD, TaharaConds(AA, DD, rec(drop := [])));
  if Length(lat) > BIGLAT then stats.skipped := stats.skipped + 1; Print("biglat ", it, "\n"); continue; fi;
  stats.groups := stats.groups + 1;
  s := AA.s; d := AA.d;
  if s >= 3 then mu := Log(d[s-2], 3); else mu := 0; fi;
  if mu <= 1 then stats.mu1 := stats.mu1 + 1; else stats.mu2 := stats.mu2 + 1; fi;
  bnd := Maximum(mu - 1, 0);
  gbad := Number(lat, tau -> not IsOne(TaharaGen(AA, DD, tau).g));
  gfree := Log(Size(Subgroup(GG, List(IdentityMat(DD.n), tau -> TaharaGen(AA, DD, tau).g))), 3);
  if gbad > 0 then stats.gbad := stats.gbad + 1; Print("TAHARA g <> 1 in ", MODE, ".", it, "\n"); fi;
  if gfree > 0 then stats.nonvac := stats.nonvac + 1; fi;
  TC := TaggedConds(AA, DD);
  B3 := List(SelConds(TC, ["B"]), x -> [x[1], 3]); D23 := List(SelConds(TC, ["D2"]), x -> [x[1], 3]);
  C1 := C1Rows(AA, DD);
  W := TaharaLattice(AA, DD, Concatenation(C1, B3, D23));
  rW := RBound(AA, DD, W, bnd); tW := TermBound(AA, DD, W, bnd);
  rNoB := RBound(AA, DD, TaharaLattice(AA, DD, Concatenation(C1, D23)), bnd);
  rNoD := RBound(AA, DD, TaharaLattice(AA, DD, Concatenation(C1, B3)), bnd);
  rC1 := RBound(AA, DD, TaharaLattice(AA, DD, C1), bnd);
  rFree := RBound(AA, DD, IdentityMat(DD.n), bnd);
  if rW.viol > 0 then stats.Wviol := stats.Wviol + 1; fi;
  if rW.partviol > 0 then stats.Wpartviol := stats.Wpartviol + 1; fi;
  if tW.viol > 0 then stats.Wtermviol := stats.Wtermviol + 1; fi;
  if rW.nontriv > 0 then stats.Wnontriv := stats.Wnontriv + 1; fi;
  if mu >= 2 and rW.maxR = mu - 1 then stats.Wsharp := stats.Wsharp + 1; fi;
  if rNoB.viol > 0 then stats.ctl_noB := stats.ctl_noB + 1; fi;
  if rNoD.viol > 0 then stats.ctl_noD := stats.ctl_noD + 1; fi;
  if rC1.viol > 0 then stats.ctl_c1 := stats.ctl_c1 + 1; fi;
  if rFree.viol > 0 then stats.ctl_free := stats.ctl_free + 1; fi;
  thm2 := TaharaLattice(AA, DD, Concatenation(SelConds(TC, ["B", "D2", "E", "F2"]), C1));
  t2bad := 0; t2nt := 0;
  for tau in thm2 do
    R := ResidualOK(AA, DD, tau);
    if not IsOne(R) then t2nt := t2nt + 1; fi;
    if not TaharaGen(AA, DD, tau).g^2 = R then t2bad := t2bad + 1; fi;
  od;
  if t2bad > 0 then stats.thm2bad := stats.thm2bad + 1; fi;
  if t2nt > 0 then stats.thm2nontriv := stats.thm2nontriv + 1; fi;
  FC := FormChecks(AA, mu);
  if FC.omYbad > 0 then stats.omYbad := stats.omYbad + 1; fi;
  if FC.pairbad > 0 then stats.pairbad := stats.pairbad + 1; fi;
  if FC.pairY > 0 then stats.pairY := stats.pairY + 1; fi;
  emit(Concatenation("{\"kind\":\"group\",\"mode\":\"", MODE, "\",\"id\":", String(it),
    ",\"ab\":", String(AbelianInvariants(GG)), ",\"d\":", String(d), ",\"mu\":", String(mu),
    ",\"logord\":", String(Log(Size(GG), 3)), ",\"lcs\":", String(List([1..4], j -> Log(Index(LL[j], LL[j+1]), 3))),
    ",\"e23\":", String(LogExp(LL[2], LL[3])), ",\"zcyc\":", String(IsCyclic(Centre(GG))),
    ",\"nvars\":", String(DD.n), ",\"lat\":", String(Length(lat)), ",\"gbad\":", String(gbad), ",\"gfree\":", String(gfree),
    ",\"W\":\"", String(rW), "\",\"Wterm\":\"", String(tW), "\",\"noB\":\"", String(rNoB), "\",\"noD\":\"", String(rNoD),
    "\",\"c1\":\"", String(rC1), "\",\"free\":\"", String(rFree), "\",\"thm2\":", String(Length(thm2)),
    ",\"thm2bad\":", String(t2bad), ",\"thm2nontriv\":", String(t2nt), ",\"forms\":\"", String(FC), "\"}"));
  prb := PresOnGens(GG, RR[2]);
  WriteAll(D5S, Concatenation("{\"id\":\"", MODE, ".", String(it), "\",\"k\":", String(Length(RR[2])),
    ",\"rels\":", String(List(prb.rels, ExtRepOfObj)), ",\"zs\":", String([ExtRepOfObj(prb.word(RR[3]))]),
    ",\"ab\":", String(AbelianInvariants(GG)), ",\"mu\":", String(mu), ",\"logord\":", String(Log(Size(GG), 3)),
    ",\"g4\":", String(KG4), "}\n"));
od;
CloseStream(D5S);
emit(Concatenation("{\"kind\":\"stats\",\"mode\":\"", MODE, "\",\"stats\":\"", String(stats), "\"}"));
CloseStream(OUTS);
Print("FINAL ", MODE, " ", String(stats), "\n");
QUIT;
