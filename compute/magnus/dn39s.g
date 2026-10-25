# MATH-403: survey for the order-3^9, class >= 5 part of the 3-torsion bound (dn3.g did 3^6..3^8).
# A least-order Q of order 3^9 has cyclic centre, so the last term of its lower exponent-3 central
# series (central, of exponent 3) is soc = <z>, and Q is a step-1 immediate descendant of
# P = Q/<z> (order 3^8, class >= c-1 >= 4, rank d(Q) <= 5): Q = S/U with S = P*, M the multiplier,
# N the nucleus, U of index 3 in M, N not in U.  Needed: z in Q'' (M ∩ S'' not in U), z in
# M_{c+1}(Q) <= M_6(Q) (M ∩ M_6(S) not in U), class >= 5 (gamma_5(S) not in U).  For each parent of
# rank 2..5 and class >= 4 this writes one CSV line: id, d, class, log3 of M, N, M ∩ S'', M ∩ M_6(S),
# M ∩ gamma_5(S), whether gamma_5(S) <= M, and pass (each of these subspaces is nonzero: necessary
# for some U to satisfy all four conditions, not sufficient).
# Set FROM, TO, OUT before reading.
LoadPackage("sglppow"); LoadPackage("anupq");
SetPrintFormattingStatus("*stdout*", false);
DN39S := function(from, to, out)
  local f, id, P, d, c, S, M, N, L, W, J, A, B, C, inM, pass, np, npass, t;
  f := OutputTextFile(out, false); SetPrintFormattingStatus(f, false);
  np := 0; npass := 0; t := Runtime();
  for id in [from .. Minimum(to, NrSmallGroups(3^8))] do
    P := SmallGroup(3^8, id);
    d := RankPGroup(P);
    if d < 2 or d > 5 then continue; fi;
    c := NilpotencyClassOfGroup(P);
    if c < 4 then continue; fi;
    np := np + 1;
    S := PqPCover(P);
    M := Subgroup(S, Pcgs(S){[9 .. Length(Pcgs(S))]});
    N := PCentralSeries(S, 3)[Length(PCentralSeries(P, 3))];
    if Size(S) / Size(M) <> Size(P) or not IsElementaryAbelian(M) or not IsSubgroup(M, N) then
      Error("DN39S: unexpected p-cover at ", id); fi;
    L := LowerCentralSeriesOfGroup(S);
    if Length(L) >= 5 then W := L[5]; else W := TrivialSubgroup(S); fi;
    J := JenningsSeries(S);
    if Length(J) >= 6 then B := Intersection(M, J[6]); else B := TrivialSubgroup(S); fi;
    A := Intersection(M, DerivedSubgroup(DerivedSubgroup(S)));
    C := Intersection(M, W); inM := IsSubgroup(M, W);
    pass := not IsTrivial(N) and not IsTrivial(A) and not IsTrivial(B) and (not inM or not IsTrivial(C));
    if pass then npass := npass + 1; fi;
    WriteAll(f, Concatenation(String(id), ",", String(d), ",", String(c), ",",
      JoinStringsWithSeparator(List([M, N, A, B, C], H -> String(Log(Size(H), 3))), ","), ",",
      String(inM), ",", String(pass), "\n"));
  od;
  CloseStream(f);
  Print("3^8 ids ", from, "..", to, ": groups=", Minimum(to, NrSmallGroups(3^8)) - from + 1, " parents (d 2..5, class >= 4)=", np,
        " pass=", npass, " sec=", Int((Runtime() - t) / 1000), "\n");
end;;
DN39S(FROM, TO, OUT);
QUIT;
