# Review of PR #107: the parent set of dn39s.g recounted with other functions (rank from the
# Frattini index, class from the lower central series).  Writes the ids of SmallGroup(3^8, i),
# FROM <= i <= TO, of rank 2..5 and class >= 4 to OUT.
LoadPackage("sglppow");
f := OutputTextFile(OUT, false); SetPrintFormattingStatus(f, false);
for i in [FROM .. Minimum(TO, NrSmallGroups(3^8))] do
  G := SmallGroup(3^8, i); d := Log(Index(G, FrattiniSubgroup(G)), 3);
  if d >= 2 and d <= 5 and Length(LowerCentralSeriesOfGroup(G)) - 1 >= 4 then
    WriteAll(f, Concatenation(String(i), "\n")); fi;
od;
CloseStream(f); Print("RVCOUNT done ", FROM, "..", TO, "\n");
QUIT;
