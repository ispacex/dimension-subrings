# STARTFILE for tree.g from SmallGroups (checks): the first COUNT vertices of rank D among
# SmallGroup(NN, i), i = IDFROM, IDFROM+STRIDE, ..., that the walk keeps (class <= 3, cyclic gamma_3,
# (Г_N) with N = LOGQ), as lines {"order":..,"code":..} into OUTFILE.
Read("../pq1024/lib.g");
Read("prune.g");
out := OutputTextFile(OUTFILE, false);; SetPrintFormattingStatus(out, false);;
n := 0;; i := IDFROM;;
while n < COUNT and i <= NrSmallGroups(NN) do
  G := SmallGroup(NN, i);
  c := NilpotencyClassOfGroup(G);
  if RankPGroup(G) = D and c <= 3 and (c < 3 or IsCyclic(LowerCentralSeriesOfGroup(G)[3]))
     and PR_Data(G, LOGQ).p5b then
    WriteAll(out, Concatenation("{\"order\":", String(NN), ",\"code\":", String(CodePcGroup(G)), "}\n"));
    n := n + 1;
  fi;
  i := i + STRIDE;
od;
CloseStream(out);
QUIT;
