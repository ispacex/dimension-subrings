# MATH-120: candidates of order 3^9.  Since D_5 = 1 for all 3-groups of order <= 3^8, a 3-group
# Q of order 3^9 with D_5(Q) != 1 has cyclic centre and is a step-1 immediate descendant of
# P = Q / Omega_1(Z(Q)) (wiki: Cor. 7).  For each parent id in PARENTS (SmallGroup(3^8, id))
# take PqDescendants(P : StepSize := 1) and apply the sieve of c38.g: class 4, Q'' != 1,
# Z(Q) cyclic, Omega_1(Z) in Q'' ∩ M_5.  Survivors are written to OUT.jsonl for d5z.py
# (the "id" field is "parent.descendant").
LoadPackage("sglppow"); LoadPackage("anupq");
Read("presgens.g");
C39 := function(parents, prefix)
  local js, pid, P, D, j, G, L, DD, J, M5, K, Z, soc, gens, pr, nd, nc, nfin, t;
  js := OutputTextFile(Concatenation(prefix, ".jsonl"), false); SetPrintFormattingStatus(js, false);
  for pid in parents do
    t := Runtime(); P := SmallGroup(3^8, pid);
    D := PqDescendants(P : StepSize := 1);
    nd := Length(D); nc := 0; nfin := 0;
    for j in [1..nd] do
      G := D[j];
      L := LowerCentralSeriesOfGroup(G);
      if Length(L) - 1 <> 4 then continue; fi;
      DD := DerivedSubgroup(L[2]);
      if IsTrivial(DD) then continue; fi;
      Z := Centre(G);
      if not IsCyclic(Z) then continue; fi;
      nc := nc + 1;
      J := JenningsSeries(G);
      if Length(J) >= 5 then M5 := J[5]; else M5 := TrivialSubgroup(G); fi;
      K := Intersection(DD, M5); soc := Omega(Z, 3, 1);
      if not IsSubgroup(K, soc) then continue; fi;
      nfin := nfin + 1;
      gens := MinimalGeneratingSet(G);
      pr := PresOnGens(G, gens);
      WriteAll(js, Concatenation("{\"id\":\"", String(pid), ".", String(j), "\",\"k\":", String(Length(gens)),
        ",\"rels\":", String(List(pr.rels, ExtRepOfObj)),
        ",\"z\":", String(ExtRepOfObj(pr.word(First(GeneratorsOfGroup(soc), x -> x <> One(G))))),
        ",\"lcs\":", String(List([1..4], i -> AbelianInvariants(L[i] / L[i+1]))), "}\n"));
    od;
    Print("parent ", pid, " d=", RankPGroup(P), " class=", NilpotencyClassOfGroup(P),
          " descendants=", nd, " class4+nonmetab+cyclicZ=", nc, " survivors=", nfin,
          " ms=", Runtime() - t, "\n");
  od;
  CloseStream(js);
end;
C39(PARENTS, OUT);
QUIT;
