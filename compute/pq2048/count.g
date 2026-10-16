# How much the conditions of prune.g cut among SmallGroups(NN) (README.ru.md «Отсев на малых
# порядках»).  Ids IDFROM, IDFROM+STRIDE, ..., <= IDTO.  By rank d:
#   vert    tree vertices of the old search: class <= 3, gamma_3 cyclic;
#   f3, f4, f5, f5b   of them, those failing (Г3), (Г4), (Г), (Г_N) with N = LOGQ;
#   first5, first5b   failing, while the tree parent G/P_c(G) passes (c the 2-class): the roots of cut subtrees;
#   par     parents of the old search: class 2 or 3, 2-class >= 3, gamma_3 cyclic;
#   par5, par5b       of them, passing (Г), resp. (Г_N) with N = LOGQ;
#   par5bc  passing (Г_N) with N = log2(2 NN): the filter of the control (parents of order NN);
#   bad     parents failing (Г_N), N = log2(2 NN), that nevertheless have a candidate among the step-1
#           descendants — must be 0 (only computed when CHECKDESC, by PqDescendants: slow).
# Input: NN, IDFROM, IDTO, STATFILE [, STRIDE := 1, LOGQ := 11, CHECKDESC := false].
Read("../pq1024/lib.g");
Read("prune.g");
if not IsBound(STRIDE) then STRIDE := 1; fi;
if not IsBound(LOGQ) then LOGQ := 11; fi;
if not IsBound(CHECKDESC) then CHECKDESC := false; fi;
PC_Inc := function(t, d) if not IsBound(t[d]) then t[d] := 0; fi; t[d] := t[d] + 1; end;;
PC_List := t -> List([1..Length(t)], i -> function() if IsBound(t[i]) then return t[i]; fi; return 0; end());;
PC_Run := function()
  local T, names, i, G, cls, d, r, pr, logc, t0, out, seen, x, nm;
  names := ["vert", "f3", "f4", "f5", "f5b", "first5", "first5b", "par", "par5", "par5b", "par5bc", "bad"];
  T := rec(); for nm in names do T.(nm) := []; od;
  logc := PR_Log2(2 * NN);
  t0 := Runtime(); seen := 0;
  for i in [IDFROM, IDFROM + STRIDE .. IDFROM + STRIDE * QuoInt(Minimum(IDTO, NrSmallGroups(NN)) - IDFROM, STRIDE)] do
    seen := seen + 1;
    G := SmallGroup(NN, i);
    cls := NilpotencyClassOfGroup(G);
    if cls > 3 then continue; fi;
    if cls = 3 and not IsCyclic(LowerCentralSeriesOfGroup(G)[3]) then continue; fi;
    d := RankPGroup(G);
    PC_Inc(T.vert, d);
    r := PR_Data(G, LOGQ);
    if not r.p3 then PC_Inc(T.f3, d); fi;
    if not r.p4 then PC_Inc(T.f4, d); fi;
    if not r.p5 then PC_Inc(T.f5, d); fi;
    if not r.p5b then PC_Inc(T.f5b, d); fi;
    if not r.p5b then
      x := PR_TreeParent(G);
      if x <> fail then pr := PR_Data(x, LOGQ); else pr := rec(p5 := true, p5b := true); fi;
      if not r.p5 and pr.p5 then PC_Inc(T.first5, d); fi;
      if pr.p5b then PC_Inc(T.first5b, d); fi;
    fi;
    if cls >= 2 and MS_PClass(G) >= 3 then
      PC_Inc(T.par, d);
      if r.p5 then PC_Inc(T.par5, d); fi;
      if r.p5b then PC_Inc(T.par5b, d); fi;
      if r.p5 and r.bud <= logc then
        PC_Inc(T.par5bc, d);
      elif CHECKDESC then
        for x in MS_Desc(G, 1) do
          if NilpotencyClassOfGroup(x) = 3 and MS_MonoInvolution(x) <> fail then
            PC_Inc(T.bad, d); Print("BAD parent ", NN, " ", i, "\n");
          fi;
        od;
      fi;
    fi;
  od;
  out := OutputTextFile(STATFILE, false); SetPrintFormattingStatus(out, false);
  WriteAll(out, Concatenation("{\"order\":", String(NN), ",\"from\":", String(IDFROM), ",\"to\":", String(IDTO),
    ",\"stride\":", String(STRIDE), ",\"seen\":", String(seen), ",\"logq\":", String(LOGQ)));
  for nm in names do
    WriteAll(out, Concatenation(",\"", nm, "\":", ReplacedString(String(PC_List(T.(nm))), " ", "")));
  od;
  WriteAll(out, Concatenation(",\"gap_ms\":", String(Runtime() - t0), "}\n"));
  CloseStream(out);
end;;
PC_Run();
QUIT;
