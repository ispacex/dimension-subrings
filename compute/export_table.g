# Export full multiplication tables (for the independent PARI check, method C).
# Globals ORDER, IDS (list), OUTFILE.  One JSON line per group: order, id, one, table (0-based,
# table[i][j] = index of elts[i]*elts[j]), lev (as in export.g).  Same element order as export.g.
DS_Lev := function(G, elts)
  local lcs, lev, i, k;
  lcs := LowerCentralSeriesOfGroup(G);
  lev := [];
  for i in [1..Length(elts)] do
    k := 1;
    while k < Length(lcs) and elts[i] in lcs[k+1] do k := k + 1; od;
    lev[i] := k;
  od;
  return lev;
end;;
DS_Table := function(n, ids, file)
  local out, i, H, elts;
  out := OutputTextFile(file, false);
  SetPrintFormattingStatus(out, false);
  for i in ids do
    H := Image(IsomorphismPcGroup(SmallGroup(n, i)));
    elts := AsSSortedList(H);
    WriteAll(out, Concatenation("{\"order\":", String(n), ",\"id\":", String(i),
      ",\"one\":", String(Position(elts, One(H)) - 1),
      ",\"table\":", String(List(elts, a -> List(elts, b -> Position(elts, a*b) - 1))),
      ",\"lev\":", String(DS_Lev(H, elts)), "}\n"));
  od;
  CloseStream(out);
end;;
DS_Table(ORDER, IDS, OUTFILE);
QUIT;
