# The 2^11 search for one rank: walk the 2-group generation tree from the elementary abelian
# 2^D by immediate descendants of every step size (PqDescendants), keep a vertex only when it has
# class <= 3, cyclic gamma_3 and passes (Г_N) of prune.g with N = LOGQ (README, Theorems 1-2;
# lossless for candidates of order <= 2^LOGQ), and on every parent R found (class 2 or 3, 2-class
# >= 3) of order <= 2^COVERMAX run the p-cover search of ../pq1024/cover.g (as desc1c.g, DEDUP):
# candidates of order 2|R| up to isomorphism.  Vertices of order 2^NMAX are not expanded.
# Input: D, NMAX, LOGQ, COVERMAX, STATFILE [, OUTFILE: candidates as desc1c.g FORMAT "pres",
# STEPRULES := true: call PqDescendants only for the steps steps.g allows (the step rules); OWNDESC
# (environment PQ2048_OWNDESC=1): step-1 children from children.g instead of PqDescendants].
# STATFILE, by log2 of the order k = D..NMAX:
#   vert[k]   vertices kept;  cut[k]  descendants of class <= 3 with cyclic gamma_3 cut by (Г_N);
#   par[k]    parents among the kept;  cand[k+1] candidates of order 2^(k+1) (classes);
#   (all times: CPU ms with the pq process)
#   ms_desc[k]  ms spent in PqDescendants on the vertices of order 2^k;  ms_cover[k]  in the cover search;
#   ms_steps[k] in steps.g;  calls[k], skipped[k]  PqDescendants calls made / skipped by the rules;
#   noexp[k]  vertices with no call at all.
# Splitting one rank into pieces (run_rank.sh):
#   DUMPLEVEL, DUMPFILE — a kept vertex of order 2^k, DUMPLEVEL <= k < NMAX, is counted and searched
#     here as usual but not expanded: a line {"order":..,"code":..} goes to DUMPFILE instead;
#   STARTFILE — the walk starts from the vertices of such a file instead of 2^D (they are not
#     counted again: the run that wrote them counted them).
# Each vertex has one place in the tree (its parent is G/P_last(G)), so the pieces of a split
# together walk exactly the tree of the run without it.
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("../pq1024/latb/export_pres.g");
Read("prune.g");
Read("steps.g");
if not IsBound(STEPRULES) then STEPRULES := true; fi;
if not IsBound(KMAX) then KMAX := 14; fi;
if not IsBound(CMAX) then CMAX := 4096; fi;
TR_Add := function(t, k, x) if not IsBound(t[k]) then t[k] := 0; fi; t[k] := t[k] + x; end;;
TR_List := t -> List([1..Length(t)], i -> function() if IsBound(t[i]) then return t[i]; fi; return 0; end());;
TR_Run := function()
  local dump, dlev, S, stack, covers, G, k, s, H, c, t, r, cs, x, n, out, line, nm, j, st, steps;
  S := rec(vert := [], cut := [], par := [], cand := [], fallback := [], ms_desc := [], ms_cover := [],
           ms_steps := [], calls := [], skipped := [], noexp := []);
  if IsBound(OUTFILE) then out := OutputTextFile(OUTFILE, false); SetPrintFormattingStatus(out, false); fi;
  if IsBound(STARTFILE) then
    stack := [];
    nm := InputTextFile(ValueGlobal("STARTFILE"));
    while true do
      line := ReadLine(nm);
      if line = fail then break; fi;
      if Length(line) > 2 then
        line := EvalString(ReplacedString(ReplacedString(ReplacedString(line, "{\"order\":", "["), ",\"code\":", ","), "}", "]"));
        Add(stack, PcGroupCode(line[2], line[1]));
      fi;
    od;
    CloseStream(nm);
  else
    stack := [ElementaryAbelianGroup(2 ^ D)];
    TR_Add(S.vert, D, 1);
  fi;
  dlev := infinity;
  if IsBound(DUMPLEVEL) then
    dlev := ValueGlobal("DUMPLEVEL");
    dump := OutputTextFile(ValueGlobal("DUMPFILE"), false); SetPrintFormattingStatus(dump, false);
  fi;
  j := 0;
  while stack <> [] do
    G := Remove(stack);
    k := Log(Size(G), 2);
    if STEPRULES then
      st := TS_Steps(G, NMAX, LOGQ);
      steps := st.steps;
      TR_Add(S.ms_steps, k, st.ms);
    else
      steps := [1 .. NMAX - k];
    fi;
    TR_Add(S.calls, k, Length(steps));
    TR_Add(S.skipped, k, NMAX - k - Length(steps));
    if steps = [] then TR_Add(S.noexp, k, 1); fi;
    t := TS_Cpu();
    covers := [];
    for s in steps do
      for H in CH_Desc(G, s) do
        c := NilpotencyClassOfGroup(H);
        if c > 3 then continue; fi;
        if c = 3 and not IsCyclic(LowerCentralSeriesOfGroup(H)[3]) then continue; fi;
        if not PR_Data(H, LOGQ).p5b then TR_Add(S.cut, k + s, 1); continue; fi;
        TR_Add(S.vert, k + s, 1);
        if k + s < NMAX then
          if k + s >= dlev then
            WriteAll(dump, Concatenation("{\"order\":", String(Size(H)), ",\"code\":", String(CodePcGroup(H)), "}\n"));
          else
            Add(stack, H);
          fi;
        fi;
        if c >= 2 and MS_PClass(H) >= 3 then
          TR_Add(S.par, k + s, 1);
          if k + s <= COVERMAX then
            Add(covers, H);
          fi;
        fi;
      od;
    od;
    TR_Add(S.ms_desc, k, TS_Cpu() - t);
    # the cover search on each parent just found
    for H in covers do
      k := Log(Size(H), 2);
      t := TS_Cpu();
      r := MC_Data(H);
      if r.count > 0 then
        if r.k > KMAX or r.count > CMAX then
          TR_Add(S.fallback, k, 1);
          cs := [];
          for x in MS_Desc(H, 1) do
            if NilpotencyClassOfGroup(x) <> 3 then continue; fi;
            n := MS_MonoInvolution(x);
            if n <> fail then Add(cs, rec(Q := x, n := n)); fi;
          od;
        else
          cs := List(MC_OrbitReps(r, List(MC_Candidates(r, false), y -> y.f)), f -> MC_Quotient(r, f));
        fi;
        TR_Add(S.cand, k + 1, Length(cs));
        if IsBound(OUTFILE) then
          for x in cs do
            j := j + 1;
            line := CP_Line(2 * Size(H), j, x.Q, 5, [x.n]);
            WriteAll(out, Concatenation(line{[1 .. Length(line) - 2]}, ",\"rank\":", String(D),
              ",\"code\":", String(CodePcGroup(x.Q)),
              ",\"n\":", ReplacedString(String(ExponentsOfPcElement(Pcgs(x.Q), x.n)), " ", ""), "}\n"));
          od;
        fi;
      fi;
      TR_Add(S.ms_cover, k, TS_Cpu() - t);
    od;
  od;
  if IsBound(OUTFILE) then CloseStream(out); fi;
  if dlev < infinity then CloseStream(dump); fi;
  out := OutputTextFile(STATFILE, false); SetPrintFormattingStatus(out, false);
  WriteAll(out, Concatenation("{\"rank\":", String(D), ",\"nmax\":", String(NMAX), ",\"logq\":", String(LOGQ),
    ",\"covermax\":", String(COVERMAX)));
  for nm in RecNames(S) do
    WriteAll(out, Concatenation(",\"", nm, "\":", ReplacedString(String(TR_List(S.(nm))), " ", "")));
  od;
  WriteAll(out, "}\n");
  CloseStream(out);
end;;
TR_Run();
QUIT;
