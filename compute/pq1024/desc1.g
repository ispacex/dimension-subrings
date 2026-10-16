# The order-2^k search by the minimal-counterexample reduction (README):
# every class-3 2-group Q of order 2^k with D_5(Q) <> 1 (all quotients of order 2^(k-1) being
# known to have D_5 = 1) has cyclic centre with involution n in gamma_3 ∩ M_5, p-class >= 4,
# and is the step-1 immediate descendant of R = Q/<n>, a group of order 2^(k-1), class 2 or 3,
# p-class >= 3 and with cyclic gamma_3.
# For the parents SmallGroup(NN, IDFROM..IDTO) this runs PqDescendants(R : StepSize := 1) and
# tallies the class-3 descendants (all / cyclic centre / candidates) by rank; candidates go to
# OUTFILE in the format of export.g plus "cand" (index of n) and "parent".
# Input: NN, IDFROM, IDTO, PRUNE (true: skip parents with non-cyclic gamma_3), OUTFILE, STATFILE.
Read("lib.g");
Read("export_lib.g");
MS_Inc := function(t, d) if not IsBound(t[d]) then t[d] := 0; fi; t[d] := t[d] + 1; end;;
MS_List := t -> List([1..Length(t)], i -> function() if IsBound(t[i]) then return t[i]; fi; return 0; end());;
MS_Run := function()
  local out, i, R, c, pc, ndesc, npar, k, Q, d, n, elts, A, C, M, H, iso, t0, nskip;
  out := OutputTextFile(OUTFILE, false); SetPrintFormattingStatus(out, false);
  A := []; C := []; M := []; ndesc := 0; npar := 0; nskip := 0; t0 := Runtime();
  for i in [IDFROM..Minimum(IDTO, NrSmallGroups(NN))] do
    R := SmallGroup(NN, i);
    c := NilpotencyClassOfGroup(R);
    if c < 2 or c > 3 then continue; fi;
    if MS_PClass(R) < 3 then continue; fi;
    if PRUNE and not IsCyclic(LowerCentralSeriesOfGroup(R)[3]) then nskip := nskip + 1; continue; fi;
    npar := npar + 1;
    k := 0;
    for Q in MS_Desc(R, 1) do
      k := k + 1; ndesc := ndesc + 1;
      if NilpotencyClassOfGroup(Q) <> 3 then continue; fi;
      d := RankPGroup(Q);
      MS_Inc(A, d);
      if not IsCyclic(Centre(Q)) then continue; fi;
      MS_Inc(C, d);
      n := MS_MonoInvolution(Q);
      if n = fail then continue; fi;
      MS_Inc(M, d);
      iso := IsomorphismPcGroup(Q); H := Image(iso); elts := AsSSortedList(H);
      WriteAll(out, Concatenation(DS_Line(2 * NN, 1000 * i + k, H, elts),
        ",\"cand\":[", String(Position(elts, Image(iso, n)) - 1), "],\"parent\":", String(i), "}\n"));
    od;
  od;
  CloseStream(out);
  out := OutputTextFile(STATFILE, false); SetPrintFormattingStatus(out, false);
  WriteAll(out, Concatenation("{\"order\":", String(2 * NN), ",\"from\":", String(IDFROM), ",\"to\":", String(IDTO),
    ",\"prune\":", String(PRUNE), ",\"parents\":", String(npar), ",\"skipped_gamma3\":", String(nskip),
    ",\"descendants\":", String(ndesc), ",\"class3_by_rank\":", String(MS_List(A)),
    ",\"cyclic_centre_by_rank\":", String(MS_List(C)), ",\"candidates_by_rank\":", String(MS_List(M)),
    ",\"gap_ms\":", String(Runtime() - t0), "}\n"));
  CloseStream(out);
end;;
MS_Run();
QUIT;
