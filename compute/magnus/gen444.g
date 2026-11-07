W5 := function(F) local g, L, i; g := GeneratorsOfGroup(F); L := ShallowCopy(g);
  for i in [2..5] do L := Concatenation(List(L, c -> List(g, y -> Comm(c, y)))); od; return Filtered(L, c -> c <> One(F)); end;
RW := function(F, wt) local g, c, i; g := GeneratorsOfGroup(F); c := Random(g);
  for i in [2..wt] do c := Comm(c, Random(g)); od; return c^Random([1, 2]); end;
# random class-4 3-group with Q_ab = prescribed ords (list, ascending), extra relators; returns P, gens
RandQ := function(ords, nextra, pqc)
  local k, F, g, rels, Fp, epi, P0, L0, nat, P;
  k := Length(ords); F := FreeGroup(k); g := GeneratorsOfGroup(F);
  rels := List([1..k], i -> g[i]^ords[i] / Product(List([1..Random([0..2])], j -> RW(F, Random([2,2,3]))), One(F)));
  Append(rels, List([1..nextra], j -> Product(List([1..Random([1..2])], t -> RW(F, Random([2,3,3,4]))), One(F))));
  Fp := F / Concatenation(rels, W5(F));
  epi := EpimorphismPGroup(Fp, 3, pqc); P0 := Image(epi);
  L0 := LowerCentralSeriesOfGroup(P0);
  if Length(L0) >= 5 then nat := NaturalHomomorphismByNormalSubgroup(P0, L0[5]); P := Image(nat);
  else nat := IdentityMapping(P0); P := P0; fi;
  return rec(P := P, gens := List(GeneratorsOfGroup(Fp), x -> Image(nat, Image(epi, x))));
end;
LogExp := function(H, N) if Size(H) = Size(N) then return 0; fi; return Log(Exponent(H / N), 3); end;
# cut gamma_4 down to a cyclic group of order 3, keeping a given element u of gamma_4 (if u <> fail) alive
CutG4 := function(P, u)
  local L, G4, M, N, cands;
  L := LowerCentralSeriesOfGroup(P); G4 := L[4];
  cands := Filtered(MaximalSubgroups(G4), M -> (u = fail or not u in M));
  if cands = [] then return fail; fi;
  N := Random(cands);
  # we want gamma_4(P/N) = C3: need G4/N cyclic of order 3 -> N of index 3 containing Frattini; maximal subgroups do
  return NaturalHomomorphismByNormalSubgroup(P, N);
end;
