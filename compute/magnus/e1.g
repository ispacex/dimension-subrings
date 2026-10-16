# E1: improved sieve for 3-groups of class 4.
# K  = Omega_1(gamma_4 ∩ M_5)   (the Jennings sieve of ../filter_class4.g)
# K2 = G ∩ M_5                (D_5^2 ⊆ Gγ_5 [MP09, Thm 2.28] + odd order; no Tahara)
# K3 = Omega_1(G ∩ M_5)       (+ Tahara: exponent of D_5 divides 3)
E1 := function(n, file)
  local out, i, G, c, J, M5, g4, dd, K, K2, K3, om, nc4, nmet, nK, nK2, nK3;
  out := OutputTextFile(file, false); SetPrintFormattingStatus(out, false);
  nc4 := 0; nmet := 0; nK := 0; nK2 := 0; nK3 := 0;
  om := H -> Subgroup(H, Filtered(AsList(H), x -> x^3 = One(H)));
  for i in [1..NrSmallGroups(n)] do
    G := SmallGroup(n, i);
    c := NilpotencyClassOfGroup(G);
    if c <> 4 then continue; fi;
    nc4 := nc4 + 1;
    J := JenningsSeries(G);
    if Length(J) >= 5 then M5 := J[5]; else M5 := TrivialSubgroup(G); fi;
    g4 := LowerCentralSeriesOfGroup(G)[4];
    dd := DerivedSubgroup(DerivedSubgroup(G));
    if IsTrivial(dd) then nmet := nmet + 1; fi;
    K := om(Intersection(g4, M5));
    K2 := Intersection(dd, M5);
    K3 := om(K2);
    if not IsTrivial(K) then nK := nK + 1; fi;
    if not IsTrivial(K2) then nK2 := nK2 + 1; fi;
    if not IsTrivial(K3) then nK3 := nK3 + 1; fi;
    WriteAll(out, Concatenation(String(n), ",", String(i), ",", String(RankPGroup(G)), ",",
      String(IsTrivial(dd)), ",", String(Size(dd)), ",", String(Size(K)), ",", String(Size(K2)), ",", String(Size(K3)), "\n"));
  od;
  CloseStream(out);
  Print("order ", n, ": class4=", nc4, " metabelian=", nmet, " K!=1:", nK, " K2!=1:", nK2, " K3!=1:", nK3, "\n");
end;;
E1(243, "e1_243.csv"); E1(729, "e1_729.csv"); E1(2187, "e1_2187.csv");
QUIT;
