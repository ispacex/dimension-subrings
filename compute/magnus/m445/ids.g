# MATH-445: metabelian identities used in the Tahara-route proof of D5 = gamma5.
# Groups: Q = NilpotentQuotient(F/R, 4), F free on k gens, R = powers x_i^{e_i} (times random words),
# random extra relators, and (MET=true) all [[x_a,x_b],[x_c,x_d]] (=> Q'' = 1 since class 4).
# Usage: set SEED, NG, P (prime), MET before reading.
Read("cfq.g");
Reset(GlobalMersenneTwister, SEED); Reset(GlobalRandomSource, SEED);
RW := function(F, wt) local g, c, i; g := GeneratorsOfGroup(F); c := Random(g);
  for i in [2..wt] do c := Comm(c, Random(g)); od; return c^Random([1..P-1]); end;
OrdMod := function(x, N) local n; n := 1; while not x^n in N do n := n*P; od; return n; end;
st := rec(groups := 0, exp9 := 0, I1 := 0, I2 := 0, I3 := 0, I4 := 0, I5 := 0, I6 := 0, exp3fail := 0, nonmet := 0, tests := 0);
for it in [1..NG] do
  k := Random([2,3]); F := FreeGroup(k); g := GeneratorsOfGroup(F);
  rels := List([1..k], i -> g[i]^Random([P, P^2, P^2, P^3]) / Product(List([1..Random([0..1])], j -> RW(F, Random([2,3]))), One(F)));
  Append(rels, List([1..Random([0..2])], j -> RW(F, Random([3,4]))));
  if MET then Append(rels, Concatenation(List(Combinations([1..k], 2), ab -> List(Combinations([1..k], 2), cd ->
      Comm(Comm(g[ab[1]], g[ab[2]]), Comm(g[cd[1]], g[cd[2]])))))); 
    Append(rels, List(Tuples([1..k], 3), t -> Comm(Comm(g[t[1]], g[t[2]]), Comm(Comm(g[t[1]], g[t[2]]), g[t[3]]))));
  fi;
  cq := ClassFourQuotient(F, rels, P); if cq = fail then continue; fi; Q := cq.Q;
  if not IsPGroup(Q) then continue; fi;
  L := LowerCentralSeriesOfGroup(Q);
  if Length(L) <> 5 then continue; fi;
  st.groups := st.groups + 1;
  if not IsTrivial(DerivedSubgroup(L[2])) then st.nonmet := st.nonmet + 1; fi;
  if Exponent(L[2]/L[3]) >= P^2 then st.exp9 := st.exp9 + 1; fi;
  for t in [1..30] do
    x := Random(Q); y := Random(Q); z := Random(Q); a := Random(L[2]); b := Random(L[2]);
    n := OrdMod(x, L[2]); m := Maximum(n, OrdMod(y, L[2]));
    st.tests := st.tests + 1;
    # I1: [a,x]^n = 1 for a in gamma2, x^n in gamma2
    if Comm(a, x)^n <> One(Q) then st.I1 := st.I1 + 1; fi;
    # I2: [x,y,z]^m = 1 when x^m, y^m in gamma2
    if Comm(Comm(x, y), z)^m <> One(Q) then st.I2 := st.I2 + 1; fi;
    # I3: [x^n, y] = [x,y]^n [x,y,x,x]^binom(n,3)
    if Comm(x^n, y) <> Comm(x, y)^n * Comm(Comm(Comm(x, y), x), x)^Binomial(n, 3) then st.I3 := st.I3 + 1; fi;
    # I4: [a,x,y] = [a,y,x] for a in gamma2
    if Comm(Comm(a, x), y) <> Comm(Comm(a, y), x) then st.I4 := st.I4 + 1; fi;
    # I5: [y^m, x, z] = 1 when x^m, y^m in gamma2  (the "[Y_b,x_a,x_c]=1" identity, m = d_b >= d_a)
    if Comm(Comm(y^m, x), z) <> One(Q) then st.I5 := st.I5 + 1; fi;
    # I6: [x^n,y] * [y,x]^n ... the pairing identity: q[Y_i,x_j] [Y_j,x_i] = eps (C(.,3) terms)
    #     with n = d_i <= m = d_j: [x^n,y]^(m/n) [y^m,x] = [x,y,x,x]^(m/n*C(n,3)) [x,y,y,y]^(-C(m,3))
    if Comm(x^n, y)^(m/n) * Comm(y^m, x) <> Comm(Comm(Comm(x,y),x),x)^(m/n*Binomial(n,3)) * Comm(Comm(Comm(x,y),y),y)^(-Binomial(m,3)) then st.I6 := st.I6 + 1; fi;
    # control: the exponent-3 identity [x^3,a] = [x,a]^3 (fails when exp L2 = 9)
    if Comm(x^P, a) <> Comm(x, a)^P then st.exp3fail := st.exp3fail + 1; fi;
  od;
od;
Print("SEED ", SEED, " P ", P, " MET ", MET, " stats ", st, "\n");
QUIT;
