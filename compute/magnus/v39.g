# MATH-120: check of C39Pass (c39.g) against C39One.  For each id in IDS with rank 3/4 and class 3/4
# print: id, C39Pass, ms for it, descendants, survivors, ms for C39One.  A parent with survivors
# that fails C39Pass would be an error in the test, so it is flagged "BAD".  Times are wall clock
# (Runtime() leaves out the pq child process).
Read("c39.g");
if not IsBound(IDS) then
  rs := RandomSource(IsMersenneTwister, SEED);
  IDS := Set(List([1..NSAMPLE], i -> Random(rs, 1, NumberSmallGroups(3^8))));
fi;
js := OutputTextFile("/dev/null", false);
tot := [0, 0, 0, 0, 0, 0];   # parents, pass, ms pass, ms one (all), ms one (passing), bad
for id in IDS do
  P := SmallGroup(3^8, id);
  if not RankPGroup(P) in [3, 4] or not NilpotencyClassOfGroup(P) in [3, 4] then continue; fi;
  t := QuoInt(NanosecondsSinceEpoch(), 1000000); ok := C39Pass(P); tp := QuoInt(NanosecondsSinceEpoch(), 1000000) - t;
  t := QuoInt(NanosecondsSinceEpoch(), 1000000); r := C39One(id, js); t1 := QuoInt(NanosecondsSinceEpoch(), 1000000) - t;
  bad := not ok and r[3] > 0;
  b := function(x) if x then return 1; else return 0; fi; end;
  tot := tot + [1, b(ok), tp, t1, b(ok) * t1, b(bad)];
  Print(id, " d=", RankPGroup(P), " c=", NilpotencyClassOfGroup(P), " pass=", ok, " ms_pass=", tp,
        " desc=", r[1], " cand=", r[2], " surv=", r[3], " ms_one=", t1);
  if bad then Print(" BAD"); fi; Print("\n");
od;
Print("TOTAL parents=", tot[1], " pass=", tot[2], " ms_pass=", tot[3], " ms_one=", tot[4],
      " ms_one_passing=", tot[5], " bad=", tot[6], "\n");
QUIT;
