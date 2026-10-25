# MATH-403: sieve for 3-torsion in D_n/gamma_n, any n, among SmallGroup(3^K, i) of class >= 5
# (class 4 is the D_5 case of c38.g/c39.g).  Set K, FROM, TO, OUT before reading this file.
#
# A 3-group Q of least order with D_n(Q) != gamma_n(Q) for some n has gamma_n(Q) = 1 (Q/gamma_n is
# again an example), so class c <= n-1, and D_n(Q) lies in every minimal normal subgroup (each proper
# quotient has D_n = gamma_n = 1): Z(Q) is cyclic and D_n(Q) = soc = Omega_1(Z(Q)).  Then soc lies in
# D_{c+1}(Q), in M_{c+1} (Jennings: D_m <= M_m) and in Q'' (Gupta 1991: a finite metabelian group has
# no 3-torsion in D_m/gamma_m; apply it to Q/Q'', of class < m).  Class <= 3 is impossible
# (D_4 = gamma_4 in a 3-group, Passi), class 4 is the D_5 search.  So the test is: z in D_{c+1}(Q)
# for z generating soc, over Q of class c >= 5 with Q'' != 1, Z(Q) cyclic, soc <= Q'' ∩ M_{c+1}.
# Writes OUT.jsonl (one presentation on a minimal generating set per survivor, with z as a word,
# n = c+1, and kz = the largest k with z in gamma_k, for the control z in D_kz) and prints counts.
if K = 8 then LoadPackage("sglppow"); fi;
Read("presgens.g");
SetPrintFormattingStatus("*stdout*", false);
DN3 := function(from, to, prefix)
  local js, i, G, L, c, DD, J, M, Z, soc, gens, pr, z, kz, n, nc, nnm, ncyc, nfin, t;
  js := OutputTextFile(Concatenation(prefix, ".jsonl"), false); SetPrintFormattingStatus(js, false);
  n := 0; nc := 0; nnm := 0; ncyc := 0; nfin := 0; t := Runtime();
  for i in [from .. Minimum(to, NrSmallGroups(3^K))] do
    G := SmallGroup(3^K, i); n := n + 1;
    L := LowerCentralSeriesOfGroup(G);
    c := Length(L) - 1;
    if c < 5 then continue; fi;
    nc := nc + 1;
    DD := DerivedSubgroup(DerivedSubgroup(G));
    if IsTrivial(DD) then continue; fi;
    nnm := nnm + 1;
    Z := Centre(G);
    if not IsCyclic(Z) then continue; fi;
    ncyc := ncyc + 1;
    soc := Omega(Z, 3, 1);
    J := JenningsSeries(G);
    if Length(J) >= c + 1 then M := J[c + 1]; else M := TrivialSubgroup(G); fi;
    if not IsSubgroup(Intersection(DD, M), soc) then continue; fi;
    nfin := nfin + 1;
    z := First(GeneratorsOfGroup(soc), x -> x <> One(G));
    kz := Number(L, H -> z in H);
    gens := MinimalGeneratingSet(G);
    pr := PresOnGens(G, gens);
    WriteAll(js, Concatenation("{\"id\":", String(i), ",\"K\":", String(K), ",\"k\":", String(Length(gens)),
      ",\"n\":", String(c + 1), ",\"kz\":", String(kz),
      ",\"rels\":", String(List(pr.rels, ExtRepOfObj)), ",\"z\":", String(ExtRepOfObj(pr.word(z))),
      ",\"lcs\":", String(List([1..c], j -> AbelianInvariants(L[j] / L[j+1]))), "}\n"));
  od;
  CloseStream(js);
  Print("3^", K, " ids ", from, "..", to, ": groups=", n, " class>=5=", nc, " non-metabelian=", nnm,
        " Z cyclic=", ncyc, " survivors (soc <= Q''∩M_{c+1})=", nfin, " sec=", Int((Runtime() - t) / 1000), "\n");
end;;
DN3(FROM, TO, OUT);
QUIT;
