# Main driver for lib446.g and newchecks.g (MATH-446)
if not IsBound(DO_CONTROLS) then DO_CONTROLS := false; fi;
if not IsBound(CONTROL_MODES) then
  CONTROL_MODES := ["dropA", "dropD1", "dropF1", "weakB", "weakD2", "dropE"];
fi;
if not IsBound(CTL_MAXLAT) then CTL_MAXLAT := 500; fi;

stats := rec(tried := 0, groups := 0, skipped := 0, vectors := 0, nonvac := 0,
  cor_n := 0, cor_bad := 0, A3bad := 0, unondiv3 := 0, gbad := 0, factorbad := 0,
  starbad := 0, thm2bad := 0, t1n := 0, t1bad := 0, tpartbad := 0, t2n := 0, t2bad := 0,
  deltan := 0, deltabad := 0, omegaA := 0, omegaB := 0,
  groups339 := 0, ctl_groups := 0, ctl_vectors := 0, ctl_skipbig := 0);

for it in [1..NG] do
  if Runtime() - STARTTIME > WATCH * 1000 then Print("WATCH stop\n"); break; fi;
  tops := Random(TOPS);
  kk := Random(Filtered(KS, x -> x >= Length(tops)));
  ords := Concatenation(List([1..kk - Length(tops)], i -> 3), tops);
  stats.tried := stats.tried + 1;
  GG := OneC9(ords, EXTRAW, TRIALS);
  if GG = fail then stats.skipped := stats.skipped + 1; Print("skip ", it, "\n"); continue; fi;
  LL := LowerCentralSeriesOfGroup(GG);
  AA := TaharaData(GG, AdaptedX1(GG, LL)); DD := TaharaVars(AA);
  if DD.n > MAXV then stats.skipped := stats.skipped + 1; Print("big ", it, " nvars=", DD.n, "\n"); continue; fi;
  lat := TaharaLattice(AA, DD, CondsCtl(AA, DD, "full"));
  if Length(lat) > BIGLAT then stats.skipped := stats.skipped + 1; Print("biglat ", it, "\n"); continue; fi;
  stats.groups := stats.groups + 1;
  if Length(lat) > 1 then stats.nonvac := stats.nonvac + 1; fi;
  if AA.s = 3 and AA.d = [3, 9, 9] then stats.groups339 := stats.groups339 + 1; fi;
  CC := MergeChecks(AA, DD, lat);
  stats.vectors := stats.vectors + Length(lat); stats.nonvac := stats.nonvac + 0;
  stats.cor_n := stats.cor_n + CC.n; stats.cor_bad := stats.cor_bad + CC.bad;
  stats.A3bad := stats.A3bad + CC.A3bad; stats.unondiv3 := stats.unondiv3 + CC.unondiv3;
  stats.gbad := stats.gbad + CC.gbad; stats.factorbad := stats.factorbad + CC.factorbad;
  stats.starbad := stats.starbad + CC.starbad; stats.thm2bad := stats.thm2bad + CC.thm2bad;
  stats.t1n := stats.t1n + CC.t1n; stats.t1bad := stats.t1bad + CC.t1bad;
  stats.tpartbad := stats.tpartbad + CC.tpartbad;
  stats.t2n := stats.t2n + CC.t2n; stats.t2bad := stats.t2bad + CC.t2bad;
  stats.deltan := stats.deltan + AA.s * (AA.s - 1);
  stats.deltabad := stats.deltabad + DeltaChecks(AA);
  stats.omegaA := stats.omegaA + CC.omegaA; stats.omegaB := stats.omegaB + CC.omegaB;
  emit(Concatenation("{\"kind\":\"group\",\"id\":", String(it), ",\"ab\":", String(AbelianInvariants(GG)),
    ",\"logord\":", String(Log(Size(GG), 3)), ",\"zcyc\":", String(IsCyclic(Centre(GG))),
    ",\"d\":", String(AA.d), ",\"nvars\":", String(DD.n), ",\"lat\":", String(Length(lat)),
    ",\"cor_n\":", String(CC.n), ",\"cor_bad\":", String(CC.bad), ",\"A3bad\":", String(CC.A3bad),
    ",\"t1bad\":", String(CC.t1bad), ",\"tpartbad\":", String(CC.tpartbad),
    ",\"t2bad\":", String(CC.t2bad), ",\"delta_bad\":", String(DeltaChecks(AA)),
    ",\"starbad\":", String(CC.starbad), ",\"thm2bad\":", String(CC.thm2bad),
    ",\"factorbad\":", String(CC.factorbad), ",\"gbad\":", String(CC.gbad), "}"));
  if DO_CONTROLS then
    stats.ctl_groups := stats.ctl_groups + 1;
    for md in CONTROL_MODES do
      lt := TaharaLattice(AA, DD, CondsCtl(AA, DD, md));
      if Length(lt) > CTL_MAXLAT then
        stats.ctl_skipbig := stats.ctl_skipbig + 1;
        emit(Concatenation("{\"kind\":\"ctl\",\"id\":", String(it), ",\"mode\":\"", md, "\",\"skipbig\":", String(Length(lt)), "}"));
        continue;
      fi;
      CX := MergeChecks(AA, DD, lt);
      stats.ctl_vectors := stats.ctl_vectors + Length(lt);
      emit(Concatenation("{\"kind\":\"ctl\",\"id\":", String(it), ",\"ab\":", String(AbelianInvariants(GG)),
        ",\"mode\":\"", md, "\",\"lat\":", String(Length(lt)), ",\"cor_bad\":", String(CX.bad),
        ",\"A3bad\":", String(CX.A3bad), ",\"unondiv3\":", String(CX.unondiv3),
        ",\"omegaA\":", String(CX.omegaA), ",\"omegaB\":", String(CX.omegaB),
        ",\"t1bad\":", String(CX.t1bad), ",\"tpartbad\":", String(CX.tpartbad),
        ",\"t2bad\":", String(CX.t2bad), ",\"thm2bad\":", String(CX.thm2bad),
        ",\"starbad\":", String(CX.starbad), ",\"factorbad\":", String(CX.factorbad),
        ",\"gbad\":", String(CX.gbad), "}"));
    od;
  fi;
od;
emit(Concatenation("{\"kind\":\"stats\",\"stats\":", String(stats), "}"));
CloseStream(OUTS);
Print("FINAL ", String(stats), "\n");
QUIT;
