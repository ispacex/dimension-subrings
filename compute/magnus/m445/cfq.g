# ClassFourQuotient(F, rels, p): the largest finite p-quotient P of F/(rels, all left-normed
# weight-5 commutators in the generators), passed to P/gamma_5(P); returns rec(Q, gens) or fail.
# The p-quotient is taken by GAP's EpimorphismPGroup (not ANUPQ, not nq) up to the p-class c at
# which class c and c+1 give the same order (then P_c = P_{c+1}, so it is the largest p-quotient).
# With nq present and USENQ = true, NilpotentQuotient(F/rels, 4) is used instead (local runs).
ClassFourQuotient := function(F, rels, p)
  local g, W5, Fp, c, e1, e2, P, L, nat, Q;
  g := GeneratorsOfGroup(F);
  if IsBound(USENQ) and USENQ then
    LoadPackage("nq");
    Fp := F / rels;
    e1 := NqEpimorphismNilpotentQuotient(Fp, 4);
    Q := Image(e1);
    if not IsFinite(Q) then return fail; fi;
    return rec(Q := Q, gens := List(GeneratorsOfGroup(Fp), x -> Image(e1, x)));
  fi;
  W5 := List(Tuples([1..Length(g)], 5), t -> LeftNormedComm(g{t}));
  Fp := F / Concatenation(rels, W5);
  c := 4; e1 := EpimorphismPGroup(Fp, p, c);
  while true do
    c := c + 1; if c > 16 then return fail; fi;
    e2 := EpimorphismPGroup(Fp, p, c);
    if Size(Image(e2)) = Size(Image(e1)) then break; fi;
    e1 := e2;
  od;
  P := Image(e1); L := LowerCentralSeriesOfGroup(P);
  if Length(L) >= 5 then nat := NaturalHomomorphismByNormalSubgroup(P, L[5]); else nat := IdentityMapping(P); fi;
  Q := Image(nat);
  return rec(Q := Q, gens := List(GeneratorsOfGroup(Fp), x -> Image(nat, Image(e1, x))));
end;
