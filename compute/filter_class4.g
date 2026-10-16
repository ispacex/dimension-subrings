# Sieve for 3-torsion in D_5/gamma_5 (README): among the 3-groups of order ORDER with ids
# IDFROM..IDTO keep those of class exactly 4, and compute K := Omega_1( gamma_4(G) ∩ M_5(G) ),
# M_5 the 5th Jennings (mod-3 dimension) subgroup.  For a 3-group of class 4,
# D_5 ⊆ D_4 = gamma_4 and D_5 ⊆ M_5, and D_5 = D_5/gamma_5 has exponent dividing 3 (Tahara), so
# D_5 ⊆ K; K = 1 proves D_5 = 1.  Groups with K ≠ 1 go to OUTFILE (export.g format + "cand").
Read("export_lib.g");
DS_Sieve4 := function(n, from, to, file, statfile)
  local out, st, i, G, H, c, g4, J, K, elts, nall, nc, n4, nk, sizes, p;
  out := OutputTextFile(file, false); SetPrintFormattingStatus(out, false);
  nall := 0; nc := List([1..12], i -> 0); n4 := 0; nk := 0; sizes := [];
  for i in [from..Minimum(to, NrSmallGroups(n))] do
    nall := nall + 1;
    G := SmallGroup(n, i);
    p := PrimePGroup(G);
    c := NilpotencyClassOfGroup(G);
    nc[c] := nc[c] + 1;
    if c <> 4 then continue; fi;
    n4 := n4 + 1;
    g4 := LowerCentralSeriesOfGroup(G)[4];
    J := JenningsSeries(G);
    if Length(J) < 5 then continue; fi;
    K := Intersection(g4, J[5]);
    K := Subgroup(K, Filtered(AsList(K), x -> x^p = One(G)));   # gamma_4 is central here
    if IsTrivial(K) then continue; fi;
    nk := nk + 1;
    Add(sizes, Size(K));
    H := G;
    elts := AsSSortedList(H);
    WriteAll(out, Concatenation(DS_Line(n, i, H, elts),
      ",\"cand\":", String(List(Filtered(AsList(K), x -> x <> One(H)), x -> Position(elts, x) - 1)),
      "}\n"));
  od;
  CloseStream(out);
  st := OutputTextFile(statfile, false); SetPrintFormattingStatus(st, false);
  WriteAll(st, Concatenation("{\"order\":", String(n), ",\"from\":", String(from), ",\"to\":", String(to),
    ",\"groups\":", String(nall), ",\"by_class\":", String(nc), ",\"class4\":", String(n4),
    ",\"K_nontrivial\":", String(nk), ",\"K_sizes\":", String(Collected(sizes)), "}\n"));
  CloseStream(st);
end;;
DS_Sieve4(ORDER, IDFROM, IDTO, OUTFILE, STATFILE);
QUIT;
