# MATH-415: sieve for D_4 != gamma_4 among SmallGroup(ORD, i), ORD = 512 (256 as a control).
# Set ORD, FROM, TO, OUT before reading.
#
# Every 2-group of order <= 256 has D_n = gamma_n for all n (compute/, Proposition "computer").
# Let Q have order 512 and D_4(Q) != gamma_4(Q).  If Q has class >= 4, then Q/gamma_4(Q), of
# smaller order, has D_4 != 1; so Q has class exactly 3 (class <= 2: D_4 <= D_3 = gamma_3 = 1).
# Every proper quotient Q/N has order <= ORD/2 and class <= 3, so D_4(Q/N) = 1 and D_4(Q) <= N for
# every normal N != 1: D_4(Q) lies in every minimal normal subgroup, Z(Q) is cyclic and
# D_4(Q) = soc = Omega_1(Z(Q)).  Also soc <= D_3 = gamma_3 and soc <= M_4 (Jennings: D_m <= M_m).
# So the test is: z in D_4(Q) for z generating soc, over Q of class 3 with Z(Q) cyclic and
# soc <= gamma_3 ∩ M_4.  Writes OUT.jsonl in the format of dn3.g (n = 4, kz = largest k with z in
# gamma_k) and prints counts, with the survivors by rank (Tahara: rank <= 3 gives D_4 = gamma_4).
Read("presgens.g");
SetPrintFormattingStatus("*stdout*", false);
D4S9 := function(from, to, prefix)
  local js, i, G, L, c, J, M, Z, soc, gens, pr, z, kz, n, nc, ncyc, nfin, rk, t;
  js := OutputTextFile(Concatenation(prefix, ".jsonl"), false); SetPrintFormattingStatus(js, false);
  n := 0; nc := 0; ncyc := 0; nfin := 0; rk := []; t := Runtime();
  for i in [from .. Minimum(to, NrSmallGroups(ORD))] do
    G := SmallGroup(ORD, i); n := n + 1;
    L := LowerCentralSeriesOfGroup(G);
    c := Length(L) - 1;
    if c <> 3 then continue; fi;
    nc := nc + 1;
    Z := Centre(G);
    if not IsCyclic(Z) then continue; fi;
    ncyc := ncyc + 1;
    soc := Omega(Z, 2, 1);
    J := JenningsSeries(G);
    if Length(J) >= 4 then M := J[4]; else M := TrivialSubgroup(G); fi;
    if not IsSubgroup(Intersection(L[3], M), soc) then continue; fi;
    nfin := nfin + 1;
    z := First(GeneratorsOfGroup(soc), x -> x <> One(G));
    kz := Number(L, H -> z in H);
    gens := MinimalGeneratingSet(G);
    Add(rk, Length(gens));
    pr := PresOnGens(G, gens);
    WriteAll(js, Concatenation("{\"id\":", String(i), ",\"K\":", String(Log(ORD, 2)), ",\"k\":", String(Length(gens)),
      ",\"n\":4,\"kz\":", String(kz),
      ",\"rels\":", String(List(pr.rels, ExtRepOfObj)), ",\"z\":", String(ExtRepOfObj(pr.word(z))),
      ",\"lcs\":", String(List([1..c], j -> AbelianInvariants(L[j] / L[j+1]))), "}\n"));
  od;
  CloseStream(js);
  Print(ORD, " ids ", from, "..", to, ": groups=", n, " class3=", nc, " Z cyclic=", ncyc,
        " survivors (soc <= gamma_3∩M_4)=", nfin, " by rank ", Collected(rk),
        " sec=", Int((Runtime() - t) / 1000), "\n");
end;;
D4S9(FROM, TO, OUT);
QUIT;
