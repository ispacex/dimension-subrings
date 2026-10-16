# SmallGroups side of the generator check: class-3 groups of order NN by rank and p-class.
# Input (prepended): NN:=..;; STATFILE:="..";;
Read("lib.g");
tab := [];;
for i in [1..NrSmallGroups(NN)] do
  G := SmallGroup(NN, i);
  if NilpotencyClassOfGroup(G) <> 3 then continue; fi;
  d := RankPGroup(G); pc := MS_PClass(G);
  if not IsBound(tab[d]) then tab[d] := []; fi;
  if not IsBound(tab[d][pc]) then tab[d][pc] := 0; fi;
  tab[d][pc] := tab[d][pc] + 1;
od;
st := OutputTextFile(STATFILE, false);; SetPrintFormattingStatus(st, false);;
for d in [1..Length(tab)] do
  if IsBound(tab[d]) then
    WriteAll(st, Concatenation("{\"order\":", String(NN), ",\"rank\":", String(d), ",\"class3\":",
      String(Sum(Filtered(tab[d], IsInt))), ",\"by_pclass\":",
      String(List([1..Length(tab[d])], i -> function() if IsBound(tab[d][i]) then return tab[d][i]; fi; return 0; end())),
      "}\n"));
  fi;
od;
CloseStream(st);;
QUIT;
