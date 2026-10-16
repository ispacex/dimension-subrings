# The own p-cover (pcover.g) against PqPCover, on the vertices G = SmallGroup(NN, i),
# i = IDFROM, IDFROM+STRIDE, ..., that the walk keeps (class <= 3, cyclic gamma_3, (Г_N), N = LOGQ):
#   the cover: same order, same rank m of the multiplicator;
#   steps.g: the same steps, nucleus rank, nu4, nu;
#   a parent (class 2-3, 2-class >= 3): MC_Data's count of admissible U and k the same, and, when
#   there are candidates (count > 0, k <= KMAX, count <= CMAX), the same number of them up to
#   isomorphism and the same set of standard presentations (MC_IsoKey).
# Differences are printed (DIFF ...) and counted in "diff".  Times per rank, CPU ms with pq:
# steps_pq / steps_own, data_pq / data_own (MC_Data).
# Input: NN, IDFROM, IDTO, STRIDE, LOGQ, STATFILE [, NMAX := 10, MAXV, MAXD, PROGRESS].
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("prune.g");
Read("steps.g");
if not IsBound(NMAX) then NMAX := 10; fi;
if not IsBound(MAXV) then MAXV := infinity; fi;
if not IsBound(MAXD) then MAXD := infinity; fi;
if not IsBound(KMAX) then KMAX := 14; fi;
if not IsBound(CMAX) then CMAX := 4096; fi;
V8_Add := function(t, k, x) if not IsBound(t[k]) then t[k] := 0; fi; t[k] := t[k] + x; end;;
V8_List := t -> List([1..Length(t)], i -> function() if IsBound(t[i]) then return t[i]; fi; return 0; end());;
V8_Run := function()
  local S, last, i, G, cls, d, nv, diff, t, a, b, sa, sb, ra, rb, ca, cb, out, nm, keys, x;
  S := rec(vert := [], parents := [], withU := [], cands := [], steps_pq := [], steps_own := [],
           data_pq := [], data_own := []);
  nv := 0; diff := 0;
  last := IDFROM + STRIDE * QuoInt(Minimum(IDTO, NrSmallGroups(NN)) - IDFROM, STRIDE);
  keys := function(r)
    if r.count = 0 or r.k > KMAX or r.count > CMAX then return fail; fi;
    return Set(List(MC_OrbitReps(r, List(MC_Candidates(r, false), y -> y.f)),
                    f -> MC_IsoKey(MC_Quotient(r, f).Q)));
  end;
  for i in [IDFROM, IDFROM + STRIDE .. last] do
    if nv >= MAXV then break; fi;
    if IsBound(PROGRESS) then
      PrintTo(PROGRESS, QuoInt(i - IDFROM, STRIDE) + 1, "/", QuoInt(last - IDFROM, STRIDE) + 1, "\n");
    fi;
    G := SmallGroup(NN, i);
    cls := NilpotencyClassOfGroup(G);
    if cls > 3 then continue; fi;
    if cls = 3 and not IsCyclic(LowerCentralSeriesOfGroup(G)[3]) then continue; fi;
    d := RankPGroup(G);
    if d > MAXD then continue; fi;
    if not PR_Data(G, LOGQ).p5b then continue; fi;
    nv := nv + 1;
    V8_Add(S.vert, d, 1);
    a := PqPCover(G); b := PC_PCover(G);
    if Size(a) <> Size(b) then diff := diff + 1; Print("DIFF size ", NN, " ", i, "\n"); fi;
    OWNCOVER := false; t := TS_Cpu(); sa := TS_Steps(G, NMAX, LOGQ); V8_Add(S.steps_pq, d, TS_Cpu() - t);
    OWNCOVER := true;  t := TS_Cpu(); sb := TS_Steps(G, NMAX, LOGQ); V8_Add(S.steps_own, d, TS_Cpu() - t);
    if [sa.steps, sa.nuc, sa.nu4, sa.nu] <> [sb.steps, sb.nuc, sb.nu4, sb.nu] then
      diff := diff + 1; Print("DIFF steps ", NN, " ", i, " ", [sa.nuc, sa.nu4, sa.nu], " ", [sb.nuc, sb.nu4, sb.nu], "\n");
    fi;
    if cls >= 2 and MS_PClass(G) >= 3 then
      V8_Add(S.parents, d, 1);
      OWNCOVER := false; t := TS_Cpu(); ra := MC_Data(G); V8_Add(S.data_pq, d, TS_Cpu() - t);
      OWNCOVER := true;  t := TS_Cpu(); rb := MC_Data(G); V8_Add(S.data_own, d, TS_Cpu() - t);
      if [ra.count, ra.k, ra.m] <> [rb.count, rb.k, rb.m] then
        diff := diff + 1; Print("DIFF data ", NN, " ", i, " ", [ra.count, ra.k, ra.m], " ", [rb.count, rb.k, rb.m], "\n");
      fi;
      if ra.count > 0 then
        V8_Add(S.withU, d, 1);
        OWNCOVER := false; ca := keys(ra);
        OWNCOVER := true;  cb := keys(rb);
        if ca <> fail then V8_Add(S.cands, d, Length(ca)); fi;
        if ca <> cb then
          diff := diff + 1; Print("DIFF cands ", NN, " ", i, "\n");
        fi;
      fi;
    fi;
  od;
  OWNCOVER := false;
  out := OutputTextFile(STATFILE, false); SetPrintFormattingStatus(out, false);
  WriteAll(out, Concatenation("{\"order\":", String(NN), ",\"from\":", String(IDFROM), ",\"stride\":", String(STRIDE),
    ",\"logq\":", String(LOGQ), ",\"diff\":", String(diff)));
  for nm in RecNames(S) do
    WriteAll(out, Concatenation(",\"", nm, "\":", ReplacedString(String(V8_List(S.(nm))), " ", "")));
  od;
  WriteAll(out, "}\n");
  CloseStream(out);
end;;
V8_Run();
QUIT;
