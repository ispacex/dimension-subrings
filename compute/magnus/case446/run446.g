# Main driver for lib446.g and newchecks.g (MATH-446)
# Old counters (stats, as in the original run) + substantive counters (NS: rec(n, lhs, rhs, bad) per identity,
# see newchecks.g) + per-control lattice tables (stats.ctl: does the control lattice differ from the full one
# by its Hermite normal form, and the old counters on it) + per-group shares (grp).
if not IsBound(DO_CONTROLS) then DO_CONTROLS := false; fi;
if not IsBound(CONTROL_MODES) then
  CONTROL_MODES := ["dropA", "dropD1", "dropF1", "weakB", "weakD2", "dropE"];
fi;
if not IsBound(CTL_MAXLAT) then CTL_MAXLAT := 500; fi;
if not IsBound(NEW_MAXLAT) then NEW_MAXLAT := 2500; fi;
if not IsBound(GENORDER) then GENORDER := "std"; fi;   # "rev": the top invariants on the first generators

stats := rec(tried := 0, groups := 0, skipped := 0, vectors := 0, nonvac := 0,
  cor_n := 0, cor_bad := 0, A3bad := 0, unondiv3 := 0, gbad := 0, factorbad := 0,
  starbad := 0, thm2bad := 0, t1n := 0, t1bad := 0, tpartbad := 0, t2n := 0, t2bad := 0,
  deltan := 0, deltabad := 0, omegaA := 0, omegaB := 0,
  groups339 := 0, ctl_groups := 0, ctl_vectors := 0, ctl_skipbig := 0);
stats.ctl := rec();
for md in CONTROL_MODES do
  stats.ctl.(md) := rec(groups := 0, differs := 0, skipbig := 0, vectors := 0, cor_bad := 0, A3bad := 0,
    t1bad := 0, tpartbad := 0, t2bad := 0, thm2bad := 0, starbad := 0, factorbad := 0, gbad := 0);
od;
NS := rec();
grp := rec(groups := 0, g339 := 0, A := 0, B := 0, AorB := 0, omega := 0, gfull := 0,
  lat_star := 0, lat_starNoE := 0, lat_thm2 := 0, lat_cor3 := 0, newskip := 0,
  star_vs_full := 0, thm2_vs_star := 0, cor3_vs_thm2 := 0, starNoE_vs_star := 0);

for it in [1..NG] do
  if Runtime() - STARTTIME > WATCH * 1000 then Print("WATCH stop\n"); break; fi;
  tops := Random(TOPS);
  kk := Random(Filtered(KS, x -> x >= Length(tops)));
  ords := Concatenation(List([1..kk - Length(tops)], i -> 3), tops);
  if GENORDER = "rev" then ords := Reversed(ords); fi;
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
  is339 := AA.s = 3 and AA.d = [3, 9, 9];
  if is339 then stats.groups339 := stats.groups339 + 1; fi;
  # ---- old checks on the full lattice (continuity with the original run)
  CC := MergeChecks(AA, DD, lat);
  stats.vectors := stats.vectors + Length(lat);
  stats.cor_n := stats.cor_n + CC.n; stats.cor_bad := stats.cor_bad + CC.bad;
  stats.A3bad := stats.A3bad + CC.A3bad; stats.unondiv3 := stats.unondiv3 + CC.unondiv3;
  stats.gbad := stats.gbad + CC.gbad; stats.factorbad := stats.factorbad + CC.factorbad;
  stats.starbad := stats.starbad + CC.starbad; stats.thm2bad := stats.thm2bad + CC.thm2bad;
  stats.t1n := stats.t1n + CC.t1n; stats.t1bad := stats.t1bad + CC.t1bad;
  stats.tpartbad := stats.tpartbad + CC.tpartbad;
  stats.t2n := stats.t2n + CC.t2n; stats.t2bad := stats.t2bad + CC.t2bad;
  db := DeltaChecks(AA);
  stats.deltan := stats.deltan + AA.s * (AA.s - 1);
  stats.deltabad := stats.deltabad + db;
  stats.omegaA := stats.omegaA + CC.omegaA; stats.omegaB := stats.omegaB + CC.omegaB;
  # ---- substantive checks
  S := rec();
  PairChecks(AA, S);
  TC := TaggedConds(AA, DD);
  NL := NewLattices(AA, DD, TC);
  newok := ForAll(RecNames(NL), nm -> Length(NL.(nm)) <= NEW_MAXLAT);
  if newok then LatticeChecks(AA, DD, NL, S); else grp.newskip := grp.newskip + 1; fi;
  AddCnt(NS, S);
  grp.groups := grp.groups + 1;
  gA := false; gB := false;
  if is339 then
    grp.g339 := grp.g339 + 1;
    gA := not IsOne(Comm(Comm(AA.Y[2], AA.x1[3]), AA.x1[2]));
    gB := not IsOne(Comm(Comm(AA.Y[3], AA.x1[2]), AA.x1[3]));
    if gA then grp.A := grp.A + 1; fi;
    if gB then grp.B := grp.B + 1; fi;
    if gA or gB then grp.AorB := grp.AorB + 1; fi;
  fi;
  if S.omega_cY.lhs > 0 then grp.omega := grp.omega + 1; fi;
  if CC.gbad > 0 then grp.gfull := grp.gfull + 1; fi;
  Hfull := HNFl(lat);
  if newok then
    grp.lat_star := grp.lat_star + Length(NL.star); grp.lat_starNoE := grp.lat_starNoE + Length(NL.starNoE);
    grp.lat_thm2 := grp.lat_thm2 + Length(NL.thm2);
    Hstar := HNFl(NL.star); Hthm2 := HNFl(NL.thm2);
    if Hstar <> Hfull then grp.star_vs_full := grp.star_vs_full + 1; fi;
    if Hthm2 <> Hstar then grp.thm2_vs_star := grp.thm2_vs_star + 1; fi;
    if HNFl(NL.starNoE) <> Hstar then grp.starNoE_vs_star := grp.starNoE_vs_star + 1; fi;
    if IsBound(NL.cor3) then
      grp.lat_cor3 := grp.lat_cor3 + Length(NL.cor3);
      if HNFl(NL.cor3) <> Hthm2 then grp.cor3_vs_thm2 := grp.cor3_vs_thm2 + 1; fi;
    fi;
  fi;
  emit(Concatenation("{\"kind\":\"group\",\"id\":", String(it), ",\"ab\":", String(AbelianInvariants(GG)),
    ",\"logord\":", String(Log(Size(GG), 3)), ",\"zcyc\":", String(IsCyclic(Centre(GG))),
    ",\"d\":", String(AA.d), ",\"nvars\":", String(DD.n), ",\"lat\":", String(Length(lat)),
    ",\"cor_n\":", String(CC.n), ",\"cor_bad\":", String(CC.bad), ",\"A3bad\":", String(CC.A3bad),
    ",\"t1bad\":", String(CC.t1bad), ",\"tpartbad\":", String(CC.tpartbad),
    ",\"t2bad\":", String(CC.t2bad), ",\"delta_bad\":", String(db),
    ",\"starbad\":", String(CC.starbad), ",\"thm2bad\":", String(CC.thm2bad),
    ",\"factorbad\":", String(CC.factorbad), ",\"gbad\":", String(CC.gbad),
    ",\"A\":", String(gA), ",\"B\":", String(gB), ",\"omega_cY\":", String(S.omega_cY.lhs),
    ",\"newok\":", String(newok), ",\"new\":\"", String(S), "\"}"));
  if DO_CONTROLS then
    stats.ctl_groups := stats.ctl_groups + 1;
    for md in CONTROL_MODES do
      ct := stats.ctl.(md);
      ct.groups := ct.groups + 1;
      lt := TaharaLattice(AA, DD, CondsCtl(AA, DD, md));
      dif := HNFl(lt) <> Hfull;
      if dif then ct.differs := ct.differs + 1; fi;
      if Length(lt) > CTL_MAXLAT then
        stats.ctl_skipbig := stats.ctl_skipbig + 1; ct.skipbig := ct.skipbig + 1;
        emit(Concatenation("{\"kind\":\"ctl\",\"id\":", String(it), ",\"mode\":\"", md, "\",\"differs\":", String(dif),
          ",\"skipbig\":", String(Length(lt)), "}"));
        continue;
      fi;
      CX := MergeChecks(AA, DD, lt);
      stats.ctl_vectors := stats.ctl_vectors + Length(lt);
      ct.vectors := ct.vectors + Length(lt);
      for f in ["A3bad", "t1bad", "tpartbad", "t2bad", "thm2bad", "starbad", "factorbad", "gbad"] do
        ct.(f) := ct.(f) + CX.(f);
      od;
      ct.cor_bad := ct.cor_bad + CX.bad;
      emit(Concatenation("{\"kind\":\"ctl\",\"id\":", String(it), ",\"ab\":", String(AbelianInvariants(GG)),
        ",\"mode\":\"", md, "\",\"differs\":", String(dif), ",\"lat\":", String(Length(lt)), ",\"cor_bad\":", String(CX.bad),
        ",\"A3bad\":", String(CX.A3bad), ",\"unondiv3\":", String(CX.unondiv3),
        ",\"omegaA\":", String(CX.omegaA), ",\"omegaB\":", String(CX.omegaB),
        ",\"t1bad\":", String(CX.t1bad), ",\"tpartbad\":", String(CX.tpartbad),
        ",\"t2bad\":", String(CX.t2bad), ",\"thm2bad\":", String(CX.thm2bad),
        ",\"starbad\":", String(CX.starbad), ",\"factorbad\":", String(CX.factorbad),
        ",\"gbad\":", String(CX.gbad), "}"));
    od;
  fi;
od;
emit(Concatenation("{\"kind\":\"stats\",\"stats\":\"", String(stats), "\",\"grp\":\"", String(grp),
  "\",\"new\":\"", String(NS), "\"}"));
CloseStream(OUTS);
# one-line summaries (old record first, for continuity with the original run)
oldst := ShallowCopy(stats); Unbind(oldst.ctl);
FIN := OutputTextFile(Concatenation(OUT, ".final"), false); SetPrintFormattingStatus(FIN, false);
WriteAll(FIN, Concatenation("FINAL ", String(oldst), "\n"));
for md in CONTROL_MODES do WriteAll(FIN, Concatenation("CTL ", md, " ", String(stats.ctl.(md)), "\n")); od;
WriteAll(FIN, Concatenation("GRP ", String(grp), "\n"));
for nm in SortedList(RecNames(NS)) do WriteAll(FIN, Concatenation("NEW ", nm, " ", String(NS.(nm)), "\n")); od;
CloseStream(FIN);
Print("FINAL ", String(oldst), "\n");
QUIT;
