# MATH-403: order 3^9, class >= 5.  A least-order example Q of order 3^9 is a step-1 immediate
# descendant of P = Q/<z> (see dn39s.g), so for each parent id in PARENTS (from dn39_parents.csv:
# the SmallGroup(3^8, id) of rank 2..5 and class >= 4 that pass the necessary test of dn39s.g) take
# PqDescendants(P : StepSize := 1) and apply the sieve of dn3.g: class c >= 5, Q'' != 1, Z(Q)
# cyclic, soc <= Q'' ∩ M_{c+1}.  Survivors go to OUT (one JSON line each, for dnz.py; id
# "parent.descendant"), one line per parent to LOG.  Set PARENTS, OUT, LOG before reading.
LoadPackage("sglppow"); LoadPackage("anupq");
Read("presgens.g");
SetPrintFormattingStatus("*stdout*", false);
DN39One := function(pid, js)
  local P, D, j, G, L, c, DD, Z, J, M, soc, z, kz, gens, pr, nd, nc, nfin;
  P := SmallGroup(3^8, pid);
  D := PqDescendants(P : StepSize := 1);
  nd := Length(D); nc := 0; nfin := 0;
  for j in [1..nd] do
    G := D[j];
    L := LowerCentralSeriesOfGroup(G);
    c := Length(L) - 1;
    if c < 5 then continue; fi;
    DD := DerivedSubgroup(DerivedSubgroup(G));
    if IsTrivial(DD) then continue; fi;
    Z := Centre(G);
    if not IsCyclic(Z) then continue; fi;
    nc := nc + 1;
    soc := Omega(Z, 3, 1);
    J := JenningsSeries(G);
    if Length(J) >= c + 1 then M := J[c + 1]; else M := TrivialSubgroup(G); fi;
    if not IsSubgroup(Intersection(DD, M), soc) then continue; fi;
    nfin := nfin + 1;
    z := First(GeneratorsOfGroup(soc), x -> x <> One(G));
    kz := Number(L, H -> z in H);
    gens := MinimalGeneratingSet(G);
    pr := PresOnGens(G, gens);
    WriteAll(js, Concatenation("{\"id\":\"", String(pid), ".", String(j), "\",\"K\":9,\"k\":", String(Length(gens)),
      ",\"n\":", String(c + 1), ",\"kz\":", String(kz),
      ",\"rels\":", String(List(pr.rels, ExtRepOfObj)), ",\"z\":", String(ExtRepOfObj(pr.word(z))),
      ",\"lcs\":", String(List([1..c], i -> AbelianInvariants(L[i] / L[i+1]))), "}\n"));
  od;
  return [nd, nc, nfin];
end;;
DN39 := function(parents)
  local js, lg, pid, r, t, tot;
  js := OutputTextFile(OUT, false); SetPrintFormattingStatus(js, false);
  lg := OutputTextFile(LOG, false); SetPrintFormattingStatus(lg, false);
  tot := [0, 0, 0, 0];
  for pid in parents do
    t := Runtime(); r := DN39One(pid, js); t := Runtime() - t;
    tot := tot + [1, r[1], r[2], r[3]];
    WriteAll(lg, Concatenation(String(pid), " descendants=", String(r[1]), " class>=5+nonmetab+cyclicZ=",
      String(r[2]), " survivors=", String(r[3]), " ms=", String(t), "\n"));
  od;
  CloseStream(js); CloseStream(lg);
  Print("parents=", tot[1], " descendants=", tot[2], " class>=5+nonmetab+cyclicZ=", tot[3], " survivors=", tot[4], "\n");
end;;
DN39(PARENTS);
QUIT;
