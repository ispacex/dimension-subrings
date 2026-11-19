# Sampling estimate of the pruned search for candidates of order 2^LOGQ (README, "Estimate for 2^12"):
# the walk of tree.g with NMAX = LOGQ - 1, measured on random vertices instead of walked.
#
# Every vertex of the walk of order 2^k <= 2^(LOGQ-3) is in SmallGroups.  A vertex V of order 2^(LOGQ-2)
# (level a) or a leaf of order 2^(LOGQ-1) (level b) has a unique tree parent X = V/P_last(V) of
# order 2^k, k <= LOGQ-3, or (level b only) of order 2^(LOGQ-2).  So, with X over the kept library
# vertices of one order and rank,
#   #a = sum_X a(X),  #b = sum_X b(X) + sum_{V in a} b(V),  cost likewise,
# where a(X), b(X) are the kept step-s children of X at levels a and b.  Stage 1 takes random ids X
# of order NN and rank D (uniform in the id block of that rank, IDLO..IDHI), and if X is a kept
# vertex expands it by every step s that steps.g allows with k + s in {LOGQ-2, LOGQ-1}, filtering the
# children exactly as tree.g (class <= 3, cyclic gamma_3, Theorems A and B, Tahara's rule, (Г_N),
# TIGHT on the leaves).  Stage 2 takes up to M2 of X's level-a children (reservoir sample) and
# expands each by its step 1 to the leaves.  For up to M3 parents (2-class >= 3) among the leaves met
# (reservoir sample) MC_Data is timed: the cost of the cover search, and whether the parent has
# admissible hyperplanes.
#
# Input: NN, D, LOGQ, IDFILE (one library id per line), OUTFILE (appended), [M2 = 3, M3 = 2, SEED, RULES = true].
# Output: per id, a line {"start":id} before X is touched and then one result line
#   {"id","rank","pclass","cls","kept",["steps","ms_steps","by":[{"s","n","a","b","par","ms_desc","ms_filter","rej","cut"}],
#    "s2":[{"steps","ms_steps","n","b","par","ms_desc","ms_filter"}],"cov":[{"lev","ms","count"}]]}
# (an id with a start line and no result line ran out of time or memory: the driver records it as heavy).
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("prune.g");
Read("steps.g");
if not IsBound(M2) then M2 := 3; fi;
if not IsBound(M3) then M3 := 2; fi;
if not IsBound(SEED) then SEED := 1; fi;
# RULES := false: without Theorems A, B and Tahara's rule (as the rank 2-4 runs at 2^11, for the check)
if not IsBound(RULES) then RULES := true; fi;
NMAX := LOGQ - 1;;
SA_RS := RandomSource(IsMersenneTwister, SEED);;
SA_LA := LOGQ - 2;;   # level a
SA_LB := LOGQ - 1;;   # level b (leaves)
SA_Rt := function() local r; r := Runtimes();
  return r.user_time + r.system_time + r.user_time_children + r.system_time_children; end;;
SA_OneStage := function(G)
  local m;
  m := Log(Size(PqPCover(G)) / Size(G), 2);
  return m <= 19 or (m = 20 and AutomorphismGroupPGroup(G).size <= 810000000);
end;;
SA_NOSTAB := IsBound(ANUPQData.binary_nostab);;
# reservoir sample: r = rec(seen, items, cap)
SA_Res := function(r, x)
  local j;
  r.seen := r.seen + 1;
  if Length(r.items) < r.cap then Add(r.items, x);
  else j := Random(SA_RS, 1, r.seen); if j <= r.cap then r.items[j] := x; fi; fi;
end;;
SA_J := x -> ReplacedString(String(x), " ", "");;

# Kept as a vertex of the walk (order <= 2^(LOGQ-3), where Theorems A/B, Tahara and TIGHT do not act).
SA_Kept := function(G)
  local c;
  c := NilpotencyClassOfGroup(G);
  if c > 3 then return false; fi;
  if c = 3 and not IsCyclic(LowerCentralSeriesOfGroup(G)[3]) then return false; fi;
  return PR_Data(G, LOGQ).p5b;
end;;

# Expand the kept vertex G by its allowed steps s with k + s in levs; children filtered as tree.g.
# resA, resP: reservoirs for level-a children and for parents at level b.
SA_Expand := function(G, levs, resA, resP)
  local k, st, steps, out, s, tb, ds, t0, t1, n, a, b, par, rej, cut, H, c, ms_desc, pqb;
  k := Log(Size(G), 2);
  st := TS_Steps(G, NMAX, LOGQ);
  steps := Filtered(st.steps, s -> k + s in levs);
  out := rec(steps := steps, ms_steps := st.ms, by := []);
  for s in steps do
    tb := RULES and s = 1 and k = LOGQ - 2 and MS_PClass(G) = 2 and Number(AbelianInvariants(G), x -> x >= 4) < 2;
    t0 := SA_Rt();
    if k + s = SA_LB and s = 1 and SA_NOSTAB and SA_OneStage(G) then
      pqb := ANUPQData.binary; ANUPQData.binary := ANUPQData.binary_nostab;
      PushOptions(rec(RankInitialSegmentSubgroups := 100));
      ds := MS_Desc(G, s);
      PopOptions();
      ANUPQData.binary := pqb;
    else
      ds := MS_Desc(G, s);
    fi;
    t1 := SA_Rt(); ms_desc := t1 - t0;
    n := Length(ds); a := 0; b := 0; par := 0; rej := 0; cut := 0;
    for H in ds do
      c := NilpotencyClassOfGroup(H);
      if c > 3 then rej := rej + 1; continue; fi;
      if tb and c = 3 then rej := rej + 1; continue; fi;                       # Theorem B
      if c = 3 and not IsCyclic(LowerCentralSeriesOfGroup(H)[3]) then rej := rej + 1; continue; fi;
      if RULES and k + s = LOGQ - 2 and c <= 2 and MS_PClass(H) = 2
         and ForAll(AbelianInvariants(H), x -> x = 2) then rej := rej + 1; continue; fi;   # Theorem A
      if RULES and k + s = LOGQ - 1 and Number(AbelianInvariants(H), x -> x >= 4) <= 1 then
        rej := rej + 1; continue; fi;                                          # Tahara, Cor. 19
      if c <= 2 and k + s = LOGQ - 1 then
        if not PR_Tight2(H, LOGQ) then cut := cut + 1; continue; fi;
      elif not PR_Data(H, LOGQ).p5b then cut := cut + 1; continue; fi;
      if k + s = SA_LA then
        a := a + 1; SA_Res(resA, rec(code := CodePcGroup(H), order := Size(H)));
      else
        b := b + 1;
        if c >= 2 and MS_PClass(H) >= 3 then
          par := par + 1; SA_Res(resP, rec(code := CodePcGroup(H), order := Size(H)));
        fi;
      fi;
    od;
    Add(out.by, rec(s := s, n := n, a := a, b := b, par := par, rej := rej, cut := cut,
                    ms_desc := ms_desc, ms_filter := SA_Rt() - t1));
    Unbind(ds);
  od;
  return out;
end;;

SA_ByJ := by -> Concatenation("[", JoinStringsWithSeparator(List(by, r -> Concatenation(
  "{\"s\":", String(r.s), ",\"n\":", String(r.n), ",\"a\":", String(r.a), ",\"b\":", String(r.b),
  ",\"par\":", String(r.par), ",\"rej\":", String(r.rej), ",\"cut\":", String(r.cut),
  ",\"ms_desc\":", String(r.ms_desc), ",\"ms_filter\":", String(r.ms_filter), "}")), ","), "]");;

SA_Cov := function(resP, lev)
  local l, x, H, t, r;
  l := [];
  for x in resP.items do
    H := PcGroupCode(x.code, x.order);
    t := SA_Rt();
    r := MC_Data(H);
    Add(l, Concatenation("{\"lev\":\"", lev, "\",\"ms\":", String(SA_Rt() - t), ",\"count\":", String(r.count), "}"));
  od;
  return l;
end;;

SA_Run := function()
  local f, line, ids, id, G, d, pc, cls, kept, resA, resP, resP2, e, s2, x, V, e2, cov, out;
  ids := [];
  f := InputTextFile(IDFILE);
  while true do
    line := ReadLine(f);
    if line = fail then break; fi;
    line := Chomp(line);
    if line <> "" then Add(ids, Int(line)); fi;
  od;
  CloseStream(f);
  for id in ids do
    FileString(OUTFILE, Concatenation("{\"start\":", String(id), "}\n"), true);
    G := SmallGroup(NN, id);
    d := RankPGroup(G);
    cls := NilpotencyClassOfGroup(G);
    pc := MS_PClass(G);
    kept := d = D and SA_Kept(G);
    out := Concatenation("{\"id\":", String(id), ",\"rank\":", String(d), ",\"pclass\":", String(pc),
      ",\"cls\":", String(cls), ",\"kept\":", String(kept));
    if kept then
      resA := rec(seen := 0, items := [], cap := M2);
      resP := rec(seen := 0, items := [], cap := M3);
      e := SA_Expand(G, [SA_LA, SA_LB], resA, resP);
      s2 := [];
      resP2 := rec(seen := 0, items := [], cap := M3);
      for x in resA.items do
        V := PcGroupCode(x.code, x.order);
        e2 := SA_Expand(V, [SA_LB], rec(seen := 0, items := [], cap := 0), resP2);
        Add(s2, Concatenation("{\"steps\":", SA_J(e2.steps), ",\"ms_steps\":", String(e2.ms_steps),
          ",\"by\":", SA_ByJ(e2.by), "}"));
      od;
      cov := Concatenation(SA_Cov(resP, "x"), SA_Cov(resP2, "a"));
      out := Concatenation(out, ",\"steps\":", SA_J(e.steps), ",\"ms_steps\":", String(e.ms_steps),
        ",\"by\":", SA_ByJ(e.by), ",\"na\":", String(resA.seen), ",\"s2\":[", JoinStringsWithSeparator(s2, ","),
        "],\"np2\":", String(resP2.seen), ",\"cov\":[", JoinStringsWithSeparator(cov, ","), "]");
    fi;
    FileString(OUTFILE, Concatenation(out, "}\n"), true);
  od;
end;;
SA_Run();
QUIT;
