# D5-26: the order-3^8 sieve for D_5 != 1 (needs the sglppow package for SmallGroup(3^8, i)).
# Set FROM, TO (ids) and OUT (file prefix) before reading this file.
#
# Sieve (wiki 579, Prop. 2, and the minimal-counterexample lemma of D5-26):
#   class 4 (D_5 = gamma_5 for class != 4 at this order), d(Q) in {3,4}, Q'' != 1,
#   Z(Q) cyclic (else D_5(Q) lies in two minimal normal subgroups N1, N2 with N1 ∩ N2 = 1,
#   because D_5(Q/N) = 1 for |Q/N| <= 3^7), and soc = Omega_1(Z(Q)) inside Q'' ∩ M_5.
# Writes OUT.csv (one line per non-metabelian class-4 group) and OUT.jsonl (one presentation
# on a minimal generating set per survivor, with the socle generator z as a word) for d5z.py.
LoadPackage("sglppow");
Read("presgens.g");
C38 := function(from, to, prefix)
  local csv, js, i, G, d, L, c, DD, J, M5, K, Z, cyc, soc, fin, gens, pr, rels, zw,
        n, nc4, nnm, nK, ncyc, nfin, t;
  csv := OutputTextFile(Concatenation(prefix, ".csv"), false); SetPrintFormattingStatus(csv, false);
  js := OutputTextFile(Concatenation(prefix, ".jsonl"), false); SetPrintFormattingStatus(js, false);
  n := 0; nc4 := 0; nnm := 0; nK := 0; ncyc := 0; nfin := 0; t := Runtime();
  for i in [from .. Minimum(to, NrSmallGroups(3^8))] do
    G := SmallGroup(3^8, i); n := n + 1;
    d := RankPGroup(G);
    if d < 3 or d > 4 then continue; fi;
    L := LowerCentralSeriesOfGroup(G);
    c := Length(L) - 1;
    if c <> 4 then continue; fi;
    nc4 := nc4 + 1;
    DD := DerivedSubgroup(L[2]);
    if IsTrivial(DD) then continue; fi;
    nnm := nnm + 1;
    J := JenningsSeries(G);
    if Length(J) >= 5 then M5 := J[5]; else M5 := TrivialSubgroup(G); fi;
    K := Intersection(DD, M5);
    Z := Centre(G);
    cyc := IsCyclic(Z);
    soc := Omega(Z, 3, 1);
    if not IsTrivial(K) then nK := nK + 1; fi;
    if cyc then ncyc := ncyc + 1; fi;
    fin := cyc and IsSubgroup(K, soc);
    WriteAll(csv, Concatenation(String(i), ",", String(d), ",",
      JoinStringsWithSeparator(List([1..4], j -> String(Log(Index(L[j], L[j+1]), 3))), ";"), ",",
      String(Size(DD)), ",", String(Size(K)), ",", String(Size(Z)), ",", String(cyc), ",",
      String(fin), "\n"));
    if fin then
      nfin := nfin + 1;
      gens := MinimalGeneratingSet(G);
      pr := PresOnGens(G, gens);
      rels := List(pr.rels, ExtRepOfObj);
      zw := ExtRepOfObj(pr.word(First(GeneratorsOfGroup(soc), x -> x <> One(G))));
      WriteAll(js, Concatenation("{\"id\":", String(i), ",\"k\":", String(Length(gens)),
        ",\"rels\":", String(rels), ",\"z\":", String(zw),
        ",\"lcs\":", String(List([1..4], j -> AbelianInvariants(L[j] / L[j+1]))),
        ",\"dd\":", String(Size(DD)), ",\"exp\":", String(Exponent(G)), "}\n"));
    fi;
  od;
  CloseStream(csv); CloseStream(js);
  Print("ids ", from, "..", to, ": groups=", n, " d in {3,4} & class 4=", nc4,
        " non-metabelian=", nnm, " Q''∩M5!=1:", nK, " Z cyclic:", ncyc,
        " survivors (Z cyclic, soc in Q''∩M5)=", nfin, " sec=", Int((Runtime() - t) / 1000), "\n");
end;
C38(FROM, TO, OUT);
QUIT;
