# random class-4 3-groups (MET: metabelian), Tahara admissible-lattice check with drop controls
Read("tahadm.g");
Reset(GlobalMersenneTwister, SEED); Reset(GlobalRandomSource, SEED);
P := 3;
RW := function(F, wt) local g, c, i; g := GeneratorsOfGroup(F); c := Random(g);
  for i in [2..wt] do c := Comm(c, Random(g)); od; return c^Random([1..P-1]); end;
ALLC := ["A1","A2","A3","A4","B","C1","C2","C3","C4","D1","D2","E","F1","F2"];
UNUSED := ["A1","A2","C2","C4","D1","D2","F1","F2"];
DROPS := [[], UNUSED, Concatenation(UNUSED, ["E"]), Concatenation(UNUSED, ["C1","C3"]), Concatenation(UNUSED, ["C3"]), Concatenation(UNUSED, ["A3","A4"]), Concatenation(UNUSED, ["B"]), ALLC];
tot := List(DROPS, x -> 0); n := 0; n9 := 0;
for it in [1..NG] do
  k := Random(KS); F := FreeGroup(k); g := GeneratorsOfGroup(F);
  rels := List([1..k], i -> g[i]^Random(DEXP) / Product(List([1..Random([0..1])], j -> RW(F, Random([2,3]))), One(F)));
  Append(rels, List([1..Random([0..NEXTRA])], j -> RW(F, Random([2,3,4]))));
  if MET then
    Append(rels, Concatenation(List(Combinations([1..k], 2), ab -> List(Combinations([1..k], 2), cd ->
      Comm(Comm(g[ab[1]], g[ab[2]]), Comm(g[cd[1]], g[cd[2]]))))));
  fi;
  Q := NilpotentQuotient(F / Concatenation(rels, List(Tuples([1..k], 5), t -> LeftNormedComm(g{t}))), 4);
  if not IsFinite(Q) then continue; fi;
  L := LowerCentralSeriesOfGroup(Q);
  if Length(L) <> 5 then continue; fi;
  if MET and not IsTrivial(DerivedSubgroup(L[2])) then Error("not metabelian"); fi;
  n := n + 1; ex9 := Exponent(L[2]/L[3]) >= 9; if ex9 then n9 := n9 + 1; fi;
  res := List(DROPS, D -> TahCheck(Q, D));
  tot := tot + List(res, r -> SignInt(r.bad));
  Print("{\"seed\":", SEED, ",\"it\":", it, ",\"logord\":", Log(Size(Q), 3), ",\"met\":", IsTrivial(DerivedSubgroup(L[2])),
        ",\"expL2\":", Exponent(L[2]/L[3]), ",\"d\":", res[1].d, ",\"e\":", res[1].e, ",\"nker\":", List(res, r -> r.nker),
        ",\"bad\":", List(res, r -> r.bad), ",\"Vnontriv\":", res[1].Vnontriv, "}\n");
od;
Print("SUMMARY seed ", SEED, " MET ", MET, " groups ", n, " expL2>=9 ", n9, " groups_with_bad_by_drop ", tot, " drops ", DROPS, "\n");
QUIT;
