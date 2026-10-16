# children.g against PqDescendants (step 1), on the vertices G = SmallGroup(NN, i), i = IDFROM,
# IDFROM+STRIDE, ..., that the walk keeps (class <= 3, cyclic gamma_3, (Г_N), N = LOGQ): the
# children of class <= 3 must be the same up to isomorphism — the same number, and the same
# multiset of standard presentations (MC_IsoKey) when there are at most KEYMAX of them, else the
# same multiset of cheap invariants (class, 2-class, abelian invariants, centre, gamma_2).
# Differences are printed (DIFF ...) and counted in "diff".  Per rank: vertices, children, the
# CPU ms of PqDescendants plus the class filter, and of CH_Step1; "fallback" counts CH_Step1 = fail.
# Input: NN, IDFROM, IDTO, STRIDE, LOGQ, STATFILE [, MAXV, MAXD, KEYMAX := 200, PROGRESS].
Read("../pq1024/lib.g");
Read("../pq1024/cover.g");
Read("prune.g");
Read("steps.g");
OWNCOVER := true;
if not IsBound(MAXV) then MAXV := infinity; fi;
if not IsBound(MAXD) then MAXD := infinity; fi;
if not IsBound(KEYMAX) then KEYMAX := 200; fi;
VC_Add := function(t, k, x) if not IsBound(t[k]) then t[k] := 0; fi; t[k] := t[k] + x; end;;
VC_List := t -> List([1..Length(t)], i -> function() if IsBound(t[i]) then return t[i]; fi; return 0; end());;
VC_Inv := x -> [NilpotencyClassOfGroup(x), MS_PClass(x), AbelianInvariants(x), Size(Centre(x)),
                AbelianInvariants(DerivedSubgroup(x))];;
VC_Run := function()
  local S, last, i, G, cls, d, nv, diff, t, a, b, ka, kb, out, nm;
  S := rec(vert := [], children := [], fallback := [], ms_pq := [], ms_own := []);
  nv := 0; diff := 0;
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
    d := RankPGroup(G);
    if d > MAXD then continue; fi;
    if not PR_Data(G, LOGQ).p5b then continue; fi;
    nv := nv + 1;
    VC_Add(S.vert, d, 1);
    t := TS_Cpu();
    a := Filtered(MS_Desc(G, 1), x -> NilpotencyClassOfGroup(x) <= 3);
    VC_Add(S.ms_pq, d, TS_Cpu() - t);
    t := TS_Cpu();
    b := CH_Step1(G);
    VC_Add(S.ms_own, d, TS_Cpu() - t);
    if b = fail then VC_Add(S.fallback, d, 1); continue; fi;
    VC_Add(S.children, d, Length(a));
    if Length(a) <> Length(b) then
      diff := diff + 1; Print("DIFF count ", NN, " ", i, " ", Length(a), " ", Length(b), "\n"); continue;
    fi;
    if Length(a) <= KEYMAX then
      ka := SortedList(List(a, MC_IsoKey)); kb := SortedList(List(b, MC_IsoKey));
    else
      ka := SortedList(List(a, VC_Inv)); kb := SortedList(List(b, VC_Inv));
    fi;
    if ka <> kb then diff := diff + 1; Print("DIFF groups ", NN, " ", i, "\n"); fi;
  od;
  out := OutputTextFile(STATFILE, false); SetPrintFormattingStatus(out, false);
  WriteAll(out, Concatenation("{\"order\":", String(NN), ",\"from\":", String(IDFROM), ",\"stride\":", String(STRIDE),
    ",\"logq\":", String(LOGQ), ",\"diff\":", String(diff)));
  for nm in RecNames(S) do
    WriteAll(out, Concatenation(",\"", nm, "\":", ReplacedString(String(VC_List(S.(nm))), " ", "")));
  od;
  WriteAll(out, "}\n");
  CloseStream(out);
end;;
VC_Run();
QUIT;
