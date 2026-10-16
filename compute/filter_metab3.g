# Sieve for the main question (README, "Reduction"): among the groups of order ORDER with ids
# IDFROM..IDTO keep the metabelian groups of class exactly 3, and for each compute
#   K := Omega_1( gamma_3(G) ∩ M_5(G) ),
# M_5 the 5th Jennings (mod-2 dimension) subgroup.  D_5(G) ⊆ K always (README), so K = 1
# proves D_5(G) = 1 with no lattice computation.  Groups with K ≠ 1 are exported in the format
# of export.g (plus "cand": 0-based indices of the elements of K \ {1}) to OUTFILE; one stats
# line is written to STATFILE.
Read("export_lib.g");
DS_Sieve := function(n, from, to, file, statfile)
  local out, st, i, G, H, c, g3, J, K, elts, nall, nc, nmet, nk, gens, pc, sizes;
  out := OutputTextFile(file, false); SetPrintFormattingStatus(out, false);
  nall := 0; nc := [0,0,0,0,0,0,0,0,0,0]; nmet := 0; nk := 0; sizes := [];
  for i in [from..Minimum(to, NrSmallGroups(n))] do
    nall := nall + 1;
    G := SmallGroup(n, i);
    c := NilpotencyClassOfGroup(G);
    nc[c] := nc[c] + 1;
    if c <> 3 or not IsTrivial(DerivedSubgroup(DerivedSubgroup(G))) then continue; fi;
    nmet := nmet + 1;
    g3 := LowerCentralSeriesOfGroup(G)[3];
    J := JenningsSeries(G);              # ends with the trivial group: M_n = 1 beyond its end
    if Length(J) < 5 then continue; fi;
    K := Intersection(g3, J[5]);
    K := Subgroup(K, Filtered(AsList(K), x -> x^2 = One(G)));   # K is central, hence abelian
    if IsTrivial(K) then continue; fi;
    nk := nk + 1;
    Add(sizes, Size(K));
    H := Image(IsomorphismPcGroup(G));
    elts := AsSSortedList(H);
    K := Image(IsomorphismPcGroup(G), K);
    WriteAll(out, Concatenation(DS_Line(n, i, H, elts),
      ",\"cand\":", String(List(Filtered(AsList(K), x -> x <> One(H)), x -> Position(elts, x) - 1)),
      "}\n"));
  od;
  CloseStream(out);
  st := OutputTextFile(statfile, false); SetPrintFormattingStatus(st, false);
  WriteAll(st, Concatenation("{\"order\":", String(n), ",\"from\":", String(from), ",\"to\":", String(to),
    ",\"groups\":", String(nall), ",\"by_class\":", String(nc), ",\"metab3\":", String(nmet),
    ",\"K_nontrivial\":", String(nk), ",\"K_sizes\":", String(Collected(sizes)), "}\n"));
  CloseStream(st);
end;;
DS_Sieve(ORDER, IDFROM, IDTO, OUTFILE, STATFILE);
QUIT;
