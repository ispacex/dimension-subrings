# Sample for the estimate of README.ru.md «Оценка для 2^11»: vertices G = SmallGroup(NN, i), i = IDFROM,
# IDFROM+STRIDE, ..., that the search for candidates of order 2^LOGQ would expand to parents of order
# 2^(LOGQ-1) by one PqDescendants call of step STEP = (LOGQ-1) - log2(NN): G must be a kept vertex
# (class <= 3, cyclic gamma_3, (Г_N) with N = LOGQ) of 2-class >= 2 (the children then have 2-class
# >= 3).  For each such G, by rank: the call's time (GAP + pq), the number of children, how many are
# kept (class <= 3, cyclic gamma_3, (Г_N) exact), the time of that filter, how many kept children have
# admissible hyperplanes (cover.g, MC_Data count > 0; time of MC_Data).
# Also, for every parent P of order NN met (class 2-3, 2-class >= 3), the step it has from its own
# tree parent (log2 |P_c(P)|) — "parstep", by step.
# Input: NN, IDFROM, IDTO, STRIDE, LOGQ, STATFILE [, MAXV: stop after this many expanded vertices,
# DOCOVER := true].
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("prune.g");
if not IsBound(MAXV) then MAXV := infinity; fi;
if not IsBound(DOCOVER) then DOCOVER := true; fi;
SD_Add := function(t, k, x) if not IsBound(t[k]) then t[k] := 0; fi; t[k] := t[k] + x; end;;
SD_List := t -> List([1..Length(t)], i -> function() if IsBound(t[i]) then return t[i]; fi; return 0; end());;
SD_Cpu := function() local r; r := Runtimes();
  return r.user_time + r.system_time + r.user_time_children + r.system_time_children; end;;
SD_Run := function()
  local S, step, i, G, cls, d, pc, P, t, ch, x, c, ok, r, nexp, out, nm;
  S := rec(seen := [], exp := [], children := [], kept := [], withU := [], ms_desc := [], ms_filter := [],
           ms_cover := [], parstep := []);
  step := LOGQ - 1 - Log(NN, 2);
  nexp := 0;
  for i in [IDFROM, IDFROM + STRIDE .. IDFROM + STRIDE * QuoInt(Minimum(IDTO, NrSmallGroups(NN)) - IDFROM, STRIDE)] do
    if nexp >= MAXV then break; fi;
    G := SmallGroup(NN, i);
    cls := NilpotencyClassOfGroup(G);
    if cls > 3 then continue; fi;
    if cls = 3 and not IsCyclic(LowerCentralSeriesOfGroup(G)[3]) then continue; fi;
    d := RankPGroup(G);
    SD_Add(S.seen, d, 1);
    P := PCentralSeries(G, 2);
    pc := Length(P) - 1;
    if cls >= 2 and pc >= 3 then SD_Add(S.parstep, Log(Size(P[pc]), 2), 1); fi;
    if pc < 2 then continue; fi;
    if not PR_Data(G, LOGQ).p5b then continue; fi;
    nexp := nexp + 1;
    SD_Add(S.exp, d, 1);
    t := SD_Cpu();
    ch := PqDescendants(G : StepSize := step);
    SD_Add(S.ms_desc, d, SD_Cpu() - t);
    SD_Add(S.children, d, Length(ch));
    for x in ch do
      t := SD_Cpu();
      c := NilpotencyClassOfGroup(x);
      ok := c <= 3 and (c < 3 or IsCyclic(LowerCentralSeriesOfGroup(x)[3])) and PR_Data(x, LOGQ).p5b;
      SD_Add(S.ms_filter, d, SD_Cpu() - t);
      if not ok then continue; fi;
      SD_Add(S.kept, d, 1);
      if DOCOVER then
        t := SD_Cpu();
        r := MC_Data(x);
        SD_Add(S.ms_cover, d, SD_Cpu() - t);
        if r.count > 0 then SD_Add(S.withU, d, 1); fi;
      fi;
    od;
  od;
  out := OutputTextFile(STATFILE, false); SetPrintFormattingStatus(out, false);
  WriteAll(out, Concatenation("{\"order\":", String(NN), ",\"from\":", String(IDFROM), ",\"to\":", String(IDTO),
    ",\"stride\":", String(STRIDE), ",\"logq\":", String(LOGQ), ",\"step\":", String(step), ",\"last\":", String(i)));
  for nm in RecNames(S) do
    WriteAll(out, Concatenation(",\"", nm, "\":", ReplacedString(String(SD_List(S.(nm))), " ", "")));
  od;
  WriteAll(out, "}\n");
  CloseStream(out);
end;;
SD_Run();
QUIT;
