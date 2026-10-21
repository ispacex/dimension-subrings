# D5-26: cost estimate for order 3^9.  A minimal counterexample Q of order 3^9 has cyclic
# centre, so P_c(Q) = Omega_1(Z(Q)) and Q is a step-1 immediate descendant of P = Q/Omega_1(Z(Q)),
# a group of order 3^8.  For a random sample of parents P (ids in RANGES, class 3 or 4) time
# PqDescendants(P : StepSize := 1) and count descendants of class 4 that are non-metabelian with
# cyclic centre (the candidates that would go to the sieve and to d5z.py).
LoadPackage("sglppow"); LoadPackage("anupq");
EST39 := function(ranges, per, seed)
  local rs, rg, k, i, P, c, t, D, nd, ncand, Q, tot;
  rs := RandomSource(IsMersenneTwister, seed); tot := [0, 0, 0, 0];
  for rg in ranges do
    for k in [1..per] do
      i := Random(rs, rg);
      P := SmallGroup(3^8, i);
      c := NilpotencyClassOfGroup(P);
      if not c in [3, 4] then Print(i, " class ", c, " skipped\n"); continue; fi;
      t := Runtime();
      D := PqDescendants(P : StepSize := 1);
      nd := Length(D);
      ncand := Number(D, Q -> NilpotencyClassOfGroup(Q) = 4
                 and not IsTrivial(DerivedSubgroup(DerivedSubgroup(Q))) and IsCyclic(Centre(Q)));
      t := Runtime() - t;
      Print(i, " d=", RankPGroup(P), " class=", c, " descendants=", nd, " candidates=", ncand,
            " ms=", t, "\n");
      tot := tot + [1, nd, ncand, t];
    od;
  od;
  Print("parents=", tot[1], " descendants=", tot[2], " candidates=", tot[3], " ms=", tot[4], "\n");
end;
EST39(RANGES, PER, 1);
QUIT;
