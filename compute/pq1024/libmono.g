# SmallGroups side of the check of desc1.g: among the class-3 groups of order NN (ids
# IDFROM..IDTO) count by rank those with p-class >= 4 and last p-central term of order 2 (= what
# desc1.g sees without pruning), those of them with cyclic centre, and the candidates.
Read("lib.g");
MS_Inc := function(t, d) if not IsBound(t[d]) then t[d] := 0; fi; t[d] := t[d] + 1; end;;
MS_List := t -> List([1..Length(t)], i -> function() if IsBound(t[i]) then return t[i]; fi; return 0; end());;
A := [];; C := [];; M := [];; t0 := Runtime();;
for i in [IDFROM..Minimum(IDTO, NrSmallGroups(NN))] do
  G := SmallGroup(NN, i);
  if NilpotencyClassOfGroup(G) <> 3 then continue; fi;
  P := PCentralSeries(G, 2);
  if Length(P) - 1 < 4 or Size(P[Length(P) - 1]) <> 2 then continue; fi;
  d := RankPGroup(G);
  MS_Inc(A, d);
  if not IsCyclic(Centre(G)) then continue; fi;
  MS_Inc(C, d);
  if MS_MonoInvolution(G) <> fail then MS_Inc(M, d); fi;
od;
out := OutputTextFile(STATFILE, false);; SetPrintFormattingStatus(out, false);;
WriteAll(out, Concatenation("{\"order\":", String(NN), ",\"from\":", String(IDFROM), ",\"to\":", String(IDTO),
  ",\"class3_by_rank\":", String(MS_List(A)), ",\"cyclic_centre_by_rank\":", String(MS_List(C)),
  ",\"candidates_by_rank\":", String(MS_List(M)), ",\"gap_ms\":", String(Runtime() - t0), "}\n"));;
CloseStream(out);;
QUIT;
