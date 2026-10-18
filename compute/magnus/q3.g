# MATH-127, question 3: terminality of the order-3^8 groups of type (5,2,1) (ids 1387558..1395381,
# found by r5.g).  For each P with id = SHARD mod NSHARD in that block write one CSV line:
#   id, logZ, logZg2 = log|Z(P) ∩ gamma_2(P)|, pclass(P), logM, logN (nucleus P_4(P*)),
#   class(P*), log|gamma_4(P*)|, log|gamma_5(P*)|, log|P*''|, exp gamma_2(P), P^3 <= Z(P),
#   log|P^3|, log|P^3 ∩ gamma_3(P)|
# Paper claim (wiki, MATH-127 q3): N != 1  ==>  |Z(P) ∩ gamma_2(P)| = 9.
# For the first NDESC parents with N != 1 also run PqDescendants(StepSize 1) and record how many
# descendants there are and how many have Q'' != 1 (paper: none).
LoadPackage("sglppow"); LoadPackage("anupq");
Q3Row := function(P)
  local S, n, M, N, L, G2, row;
  S := PqPCover(P); n := LogInt(Size(P), 3);
  M := Subgroup(S, Pcgs(S){[n + 1 .. Length(Pcgs(S))]});
  N := PCentralSeries(S, 3)[Length(PCentralSeries(P, 3))];
  L := LowerCentralSeriesOfGroup(S);
  G2 := LowerCentralSeriesOfGroup(P)[2];
  row := [LogInt(Size(Centre(P)), 3), LogInt(Size(Intersection(Centre(P), G2)), 3),
          Length(PCentralSeries(P, 3)) - 1, LogInt(Size(M), 3), LogInt(Size(N), 3),
          Length(L) - 1,
          LogInt(Size(L[Minimum(4, Length(L))]), 3), LogInt(Size(L[Minimum(5, Length(L))]), 3),
          LogInt(Size(DerivedSubgroup(DerivedSubgroup(S))), 3),
          Exponent(G2), IsSubgroup(Centre(P), Agemo(P, 3)), LogInt(Size(Agemo(P, 3)), 3),
          LogInt(Size(Intersection(Agemo(P, 3), LowerCentralSeriesOfGroup(P)[3])), 3)];
  return row;
end;
DescStat := function(P)
  local D, nd, nn, t, G, L;
  D := PqDescendants(P : StepSize := 1); nd := Length(D); nn := 0; t := [];
  for G in D do
    L := LowerCentralSeriesOfGroup(G);
    if not IsTrivial(DerivedSubgroup(L[2])) then nn := nn + 1; fi;
    AddSet(t, List([1..Length(L) - 1], i -> LogInt(Index(L[i], L[i + 1]), 3)));
  od;
  return [nd, nn, t];
end;
Q3 := function(shard, nshard)
  local lg, id, P, r, seen, nd, ds, cnt;
  lg := OutputTextFile(LOG, false); SetPrintFormattingStatus(lg, false);
  seen := 0; nd := 0; cnt := rec();
  for id in [1387558 .. 1395381] do
    if id mod nshard <> shard then continue; fi;
    seen := seen + 1; if seen mod 100 = 0 then PrintTo(PROG, seen, "\n"); fi;
    P := SmallGroup(3^8, id);
    r := Q3Row(P);
    WriteAll(lg, Concatenation(String(id), ",", JoinStringsWithSeparator(List(r, String), ","), "\n"));
    if r[5] > 0 and nd < NDESC then
      nd := nd + 1; ds := DescStat(P);
      WriteAll(lg, Concatenation("desc ", String(id), " n=", String(ds[1]), " nonmetab=", String(ds[2]),
        " types=", String(ds[3]), "\n"));
    fi;
  od;
  WriteAll(lg, Concatenation("shard ", String(shard), "/", String(nshard), " done ", String(seen), "\n"));
  CloseStream(lg);
end;
# The explicit non-terminal family: (maximal class of order 81) x (extraspecial 27) x C_3.
Q3Explicit := function()
  local a, b, P, L;
  for a in [7..10] do for b in [3, 4] do
    P := DirectProduct(SmallGroup(81, a), SmallGroup(27, b), CyclicGroup(3));
    P := Image(IsomorphismPcGroup(P));
    L := LowerCentralSeriesOfGroup(P);
    Print("explicit [81,", a, "]x[27,", b, "]xC3 rank=", RankPGroup(P), " type=",
      List([1..Length(L) - 1], i -> LogInt(Index(L[i], L[i + 1]), 3)), " row=", Q3Row(P),
      " desc=", DescStat(P), "\n");
  od; od;
end;
if IsBound(EXPLICIT) then Q3Explicit(); fi;
if IsBound(SHARD) then Q3(SHARD, NSHARD); fi;
QUIT;
