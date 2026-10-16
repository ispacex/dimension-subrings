# Profile of one vertex of the walk: where the ms go.  Vertices G = SmallGroup(NN, i),
# i = IDFROM, IDFROM+STRIDE, ..., kept by the walk (class <= 3, cyclic gamma_3, (Г_N) with N = LOGQ),
# rebuilt from CodePcGroup as the pieces of run_rank.sh rebuild them.  Per rank, totals in ms:
#   code      PcGroupCode;  pre  MS_PClass, RankPGroup, gamma_3 (steps.g's preamble);
#   cover_gap / cover_pq  PqPCover, GAP side / the pq process;  ts  all of TS_Steps (its own cover
#             included: ts - cover_gap - cover_pq is the linear part);
#   aut       AutomorphismGroupPGroup (what PqDescendants computes first);
#   desc_gap / desc_pq  PqDescendants on the allowed steps (Aut included), GAP / pq;
#   filter    class, gamma_3, PR_Data on the children;  nch  children.
# Input: NN, IDFROM, IDTO, STRIDE, NMAX, LOGQ, STATFILE [, MAXV, PROGRESS].
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("prune.g");
Read("steps.g");
if not IsBound(MAXV) then MAXV := infinity; fi;
PF_Add := function(t, k, x) if not IsBound(t[k]) then t[k] := 0; fi; t[k] := t[k] + x; end;;
PF_List := t -> List([1..Length(t)], i -> function() if IsBound(t[i]) then return t[i]; fi; return 0; end());;
PF_T := function() local r; r := Runtimes();
  return [r.user_time + r.system_time, r.user_time_children + r.system_time_children]; end;;
PF_Run := function()
  local S, last, i, G, cls, d, nv, t, u, code, Rs, st, s, ch, x, c, out, nm, A;
  S := rec(vert := [], expanded := [], code := [], pre := [], cover_gap := [], cover_pq := [], ts := [],
           aut := [], desc_gap := [], desc_pq := [], filter := [], nch := []);
  nv := 0;
  last := IDFROM + STRIDE * QuoInt(Minimum(IDTO, NrSmallGroups(NN)) - IDFROM, STRIDE);
  for i in [IDFROM, IDFROM + STRIDE .. last] do
    if nv >= MAXV then break; fi;
    if IsBound(PROGRESS) then
      PrintTo(PROGRESS, QuoInt(i - IDFROM, STRIDE) + 1, "/", QuoInt(last - IDFROM, STRIDE) + 1, "\n");
    fi;
    G := SmallGroup(NN, i);
    cls := NilpotencyClassOfGroup(G);
    if cls > 3 then continue; fi;
    if cls = 3 and not IsCyclic(LowerCentralSeriesOfGroup(G)[3]) then continue; fi;
    if not PR_Data(G, LOGQ).p5b then continue; fi;
    nv := nv + 1;
    code := CodePcGroup(G);
    t := PF_T(); G := PcGroupCode(code, NN); u := PF_T();
    d := RankPGroup(G);
    PF_Add(S.vert, d, 1); PF_Add(S.code, d, u[1] - t[1]);
    t := PF_T(); MS_PClass(G); RankPGroup(G); Size(MC_Gamma(G, 3)); u := PF_T();
    PF_Add(S.pre, d, u[1] - t[1]);
    t := PF_T(); Rs := PqPCover(G); u := PF_T();
    PF_Add(S.cover_gap, d, u[1] - t[1]); PF_Add(S.cover_pq, d, u[2] - t[2]);
    # TS_Steps in full (it calls PqPCover again; its own time minus one cover is the linear part)
    t := PF_T(); st := TS_Steps(G, NMAX, LOGQ); u := PF_T();
    PF_Add(S.ts, d, u[1] + u[2] - t[1] - t[2]);
    if st.steps = [] then continue; fi;
    PF_Add(S.expanded, d, 1);
    t := PF_T(); A := AutomorphismGroupPGroup(G); u := PF_T();
    PF_Add(S.aut, d, u[1] - t[1]);
    for s in st.steps do
      G := PcGroupCode(code, NN);           # fresh, no Aut stored
      t := PF_T(); ch := PqDescendants(G : StepSize := s); u := PF_T();
      PF_Add(S.desc_gap, d, u[1] - t[1]); PF_Add(S.desc_pq, d, u[2] - t[2]);
      PF_Add(S.nch, d, Length(ch));
      t := PF_T();
      for x in ch do
        c := NilpotencyClassOfGroup(x);
        if c > 3 then continue; fi;
        if c = 3 and not IsCyclic(LowerCentralSeriesOfGroup(x)[3]) then continue; fi;
        PR_Data(x, LOGQ);
      od;
      u := PF_T();
      PF_Add(S.filter, d, u[1] - t[1]);
    od;
  od;
  out := OutputTextFile(STATFILE, false); SetPrintFormattingStatus(out, false);
  WriteAll(out, Concatenation("{\"order\":", String(NN), ",\"stride\":", String(STRIDE), ",\"logq\":", String(LOGQ)));
  for nm in RecNames(S) do
    WriteAll(out, Concatenation(",\"", nm, "\":", ReplacedString(String(PF_List(S.(nm))), " ", "")));
  od;
  WriteAll(out, "}\n");
  CloseStream(out);
end;;
PF_Run();
QUIT;
