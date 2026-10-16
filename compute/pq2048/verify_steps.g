# Control of steps.g against full expansion (README.ru.md «Вершины без потомков»).
# For the vertices G = SmallGroup(NN, i), i = IDFROM, IDFROM+STRIDE, ..., that the walk would expand
# (class <= 3, cyclic gamma_3, (Г_N) with N = LOGQ), and every step s = 1 .. min(NMAX - k, MAXSTEP),
# k = log2 NN: PqDescendants(G, s) in full, and the checks
#   nuc   children exist  <=>  s <= dim nucleus                       (rule 0, both ways)
#   r1    a child of class <= 3 exists  =>  s <= nu4                   (rule 1)
#   r2    a kept child (class <= 3, cyclic gamma_3, (Г_N)) exists  =>  s <= nu      (rule 2)
#   r3    a kept child of order 2^NMAX that is a parent exists  =>  2-class(G) >= 2  (rule 3)
# Violations are printed (VIOLATION ...) and counted in "viol".  By rank d: vertices, vertex-steps
# tried, skipped by the rules, how many children the skipped steps had (all / of class <= 3 / kept,
# the last must be 0), CPU of PqDescendants on the skipped steps and on the kept steps, CPU of steps.g.
# Steps >= 2 of the elementary abelian group are not tried (hours; the rules give nothing there).
# Input: NN, IDFROM, IDTO, STRIDE, NMAX, LOGQ, MAXSTEP, STATFILE [, MAXV, MAXD (ranks above it are
# skipped: a rank-8 group of order 512 ran PqDescendants out of 9 GB), PROGRESS: a file that gets
# "DONE/TOTAL" (ids looked at / in the range) after every id, for the task monitor; each id expanded is
# also printed, so a crash names the group].
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("prune.g");
Read("steps.g");
if not IsBound(MAXV) then MAXV := infinity; fi;
if not IsBound(MAXD) then MAXD := infinity; fi;
VS_Add := function(t, k, x) if not IsBound(t[k]) then t[k] := 0; fi; t[k] := t[k] + x; end;;
VS_List := t -> List([1..Length(t)], i -> function() if IsBound(t[i]) then return t[i]; fi; return 0; end());;
VS_Run := function()
  local S, k, i, G, cls, d, pc, st, s, top, t, ch, n3, nk, x, c, nv, out, nm, viol, last, skip;
  S := rec(vert := [], tried := [], skipped := [], noexp := [], ch_skipped := [], ch3_skipped := [],
           kept_skipped := [], kept := [], ms_desc_skipped := [], ms_desc_kept := [], ms_steps := [],
           terminal := []);
  viol := 0; nv := 0;
  k := Log(NN, 2);
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
    if RankPGroup(G) > MAXD then continue; fi;
    if not PR_Data(G, LOGQ).p5b then continue; fi;
    nv := nv + 1;
    d := RankPGroup(G);
    Print("id ", i, " d=", d, "\n");
    pc := MS_PClass(G);
    VS_Add(S.vert, d, 1);
    st := TS_Steps(G, NMAX, LOGQ);
    VS_Add(S.ms_steps, d, st.ms);
    if st.nuc = 0 then VS_Add(S.terminal, d, 1); fi;
    if st.steps = [] then VS_Add(S.noexp, d, 1); fi;
    top := NMAX - k;
    for s in [1 .. Minimum(top, MAXSTEP)] do
      # the elementary abelian root: steps >= 2 cost hours (Aut = GL(d, 2)) and no rule helps there
      if s >= 2 and IsElementaryAbelian(G) then continue; fi;
      VS_Add(S.tried, d, 1);
      skip := not s in st.steps;
      t := TS_Cpu();
      ch := MS_Desc(G, s);
      t := TS_Cpu() - t;
      n3 := 0; nk := 0;
      for x in ch do
        c := NilpotencyClassOfGroup(x);
        if c > 3 then continue; fi;
        n3 := n3 + 1;
        if c = 3 and not IsCyclic(LowerCentralSeriesOfGroup(x)[3]) then continue; fi;
        if not PR_Data(x, LOGQ).p5b then continue; fi;
        if s = top and not (c >= 2 and MS_PClass(x) >= 3) then continue; fi;
        nk := nk + 1;
      od;
      if (ch <> []) <> (s <= st.nuc) then
        viol := viol + 1; Print("VIOLATION nuc ", NN, " ", i, " s=", s, " nuc=", st.nuc, " children=", Length(ch), "\n");
      fi;
      if n3 > 0 and s > st.nu4 then
        viol := viol + 1; Print("VIOLATION r1 ", NN, " ", i, " s=", s, " nu4=", st.nu4, "\n");
      fi;
      if nk > 0 and skip then
        viol := viol + 1; Print("VIOLATION r2/r3 ", NN, " ", i, " s=", s, " nu=", st.nu, " pclass=", pc, "\n");
      fi;
      if skip then
        VS_Add(S.skipped, d, 1); VS_Add(S.ch_skipped, d, Length(ch)); VS_Add(S.ch3_skipped, d, n3);
        VS_Add(S.kept_skipped, d, nk); VS_Add(S.ms_desc_skipped, d, t);
      else
        VS_Add(S.kept, d, nk); VS_Add(S.ms_desc_kept, d, t);
      fi;
    od;
  od;
  out := OutputTextFile(STATFILE, false); SetPrintFormattingStatus(out, false);
  WriteAll(out, Concatenation("{\"order\":", String(NN), ",\"from\":", String(IDFROM), ",\"to\":", String(IDTO),
    ",\"stride\":", String(STRIDE), ",\"nmax\":", String(NMAX), ",\"logq\":", String(LOGQ),
    ",\"maxstep\":", String(MAXSTEP), ",\"last\":", String(i), ",\"viol\":", String(viol)));
  for nm in RecNames(S) do
    WriteAll(out, Concatenation(",\"", nm, "\":", ReplacedString(String(VS_List(S.(nm))), " ", "")));
  od;
  WriteAll(out, "}\n");
  CloseStream(out);
end;;
VS_Run();
QUIT;
