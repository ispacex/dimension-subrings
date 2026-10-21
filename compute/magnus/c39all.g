# D5-26: the full order-3^9 run, part d <= 4 (wiki, sec. 5).  Parents: all SmallGroup(3^8, id)
# of rank 3 or 4 and class 3 or 4 (rank 2 gives Q'' in gamma_5 = 1; rank 5 is a separate part),
# with id = SHARD mod NSHARD.  Each parent that passes C39Pass (c39.g; the others have no candidate
# descendant) goes through C39One; survivors are written to
# OUT (one JSON line each, for d5z.py), one line per parent with descendants to LOG, and the count
# of ids looked at to PROG every 500 ids.  Set SHARD, NSHARD, OUT, LOG, PROG before reading
# (and IDS, a list of ids, for a test run on part of the library).
Read("c39.g");
C39All := function(shard, nshard)
  local js, lg, N, id, P, d, c, r, t, seen, tot, npar;
  js := OutputTextFile(OUT, false); SetPrintFormattingStatus(js, false);
  lg := OutputTextFile(LOG, false); SetPrintFormattingStatus(lg, false);
  N := NumberSmallGroups(3^8); seen := 0; npar := 0; tot := [0, 0, 0, 0, 0];
  if IsBound(IDS) then N := IDS; else N := [1..N]; fi;
  for id in N do
    if id mod nshard <> shard then continue; fi;
    seen := seen + 1;
    if seen mod 500 = 0 then PrintTo(PROG, seen, "\n"); fi;
    P := SmallGroup(3^8, id);
    d := RankPGroup(P);
    if not d in [3, 4] then continue; fi;
    c := NilpotencyClassOfGroup(P);
    if not c in [3, 4] then continue; fi;
    npar := npar + 1;
    if not C39Pass(P) then continue; fi;
    t := QuoInt(NanosecondsSinceEpoch(), 1000000); r := C39One(id, js); t := QuoInt(NanosecondsSinceEpoch(), 1000000) - t;
    tot := tot + [1, r[1], r[2], r[3], t];
    if r[1] > 0 then
      WriteAll(lg, Concatenation(String(id), " d=", String(d), " class=", String(c), " descendants=",
        String(r[1]), " cand=", String(r[2]), " survivors=", String(r[3]), " ms=", String(t), "\n"));
    fi;
  od;
  PrintTo(PROG, seen, "\n");
  WriteAll(lg, Concatenation("shard ", String(shard), "/", String(nshard), " ids=", String(seen),
    " parents=", String(npar), " passed=", String(tot[1]), " descendants=", String(tot[2]), " cand=", String(tot[3]),
    " survivors=", String(tot[4]), " ms=", String(tot[5]), "\n"));
  CloseStream(js); CloseStream(lg);
end;
C39All(SHARD, NSHARD);
QUIT;
