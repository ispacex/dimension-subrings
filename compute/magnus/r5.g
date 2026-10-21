# D5-26: order 3^9, part d = 5 (wiki, sec. 5).  A candidate Q then has type (5,2,1,1), so its
# parent P = Q/<z> is a group of order 3^8 of rank 5, class 3 and type (5,2,1).  For the ids with
# id = SHARD mod NSHARD: find these parents, run C39Pass (c39.g) on each, and write one line per
# parent to LOG (id, pass, ms) and a summary line at the end.  PqDescendants is not called here.
Read("c39.g");
R5 := function(shard, nshard)
  local lg, id, P, L, ok, t, seen, tot;
  lg := OutputTextFile(LOG, false); SetPrintFormattingStatus(lg, false);
  seen := 0; tot := [0, 0, 0];   # parents of type (5,2,1), passed, ms in C39Pass
  for id in [1..NumberSmallGroups(3^8)] do
    if id mod nshard <> shard then continue; fi;
    seen := seen + 1;
    if seen mod 500 = 0 then PrintTo(PROG, seen, "\n"); fi;
    P := SmallGroup(3^8, id);
    if RankPGroup(P) <> 5 then continue; fi;
    L := LowerCentralSeriesOfGroup(P);
    if List([1..Length(L) - 1], i -> LogInt(Index(L[i], L[i + 1]), 3)) <> [5, 2, 1] then continue; fi;
    t := QuoInt(NanosecondsSinceEpoch(), 1000000); ok := C39Pass(P);
    t := QuoInt(NanosecondsSinceEpoch(), 1000000) - t;
    tot := tot + [1, 0, t]; if ok then tot[2] := tot[2] + 1; fi;
    WriteAll(lg, Concatenation(String(id), " pass=", String(ok), " ms=", String(t), "\n"));
  od;
  PrintTo(PROG, seen, "\n");
  WriteAll(lg, Concatenation("shard ", String(shard), "/", String(nshard), " ids=", String(seen),
    " parents521=", String(tot[1]), " passed=", String(tot[2]), " ms=", String(tot[3]), "\n"));
  CloseStream(lg);
end;
R5(SHARD, NSHARD);
QUIT;
