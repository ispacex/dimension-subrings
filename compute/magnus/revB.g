# Independent referee checks of "Theorem B" (MATH-444 step 2): lemma-by-lemma identities and g(tau)=1.
# Uses tahara61.g only for TaharaData / TaharaVars / TaharaConds / TaharaLattice / TaharaGen.
# Set SEED, NG, OUT before reading. Groups: fixed examples + random class-4 3-groups (gamma_5 = 1),
# optionally with gamma_4^3 = 1.
Read("tahara61.g");
SizeScreen([4000, 100]);
Reset(GlobalMersenneTwister, SEED); Reset(GlobalRandomSource, SEED);
if not IsBound(MAXLOG) then MAXLOG := 60; fi;
if not IsBound(EXPS) then EXPS := [3, 9, 9, 27, 27, 81]; fi;
if not IsBound(NGEN) then NGEN := [2, 3, 3]; fi;

Words := function(F, wt)
  local g, L, i;
  g := GeneratorsOfGroup(F); L := List(g, x -> x);
  for i in [2..wt] do L := Concatenation(List(L, c -> List(g, y -> Comm(c, y)))); od;
  return L;
end;

# finite 3-group F/rels (+ gamma_5, optionally gamma_4^3) as a pc group
MakeGroup := function(F, rels, cube4)
  local R, G, cl, epi, P, o, olast;
  R := Concatenation(rels, Words(F, 5));
  if cube4 then Append(R, List(Words(F, 4), c -> c^3)); fi;
  G := F / R; olast := -1; cl := 6;
  while true do
    epi := EpimorphismPGroup(G, 3, cl);
    o := Size(Image(epi));
    if o = olast then break; fi;
    if Log(o, 3) > MAXLOG then return fail; fi;
    olast := o; cl := cl + 4;
  od;
  P := Image(epi);
  if Length(LowerCentralSeriesOfGroup(P)) > 5 then Error("class>4"); fi;
  if Length(LowerCentralSeriesOfGroup(P)) < 5 then return fail; fi;
  return P;
end;

# extra condition rows: D2 only, F2 only (same encoding as TaharaConds)
D2Rows := function(T, V)
  local X, rows, i, j, k, h, row;
  X := V.idx; rows := [];
  for i in [1..T.s] do for k in [1..T.t] do for j in [i+1..T.s] do
    row := [];
    for h in [1..i] do Add(row, [X.w[h][i][j], T.b[h][k]]); od;
    for h in [i+1..j] do Add(row, [X.wp[i][h][j], T.b[h][k]]); od;
    for h in [j+1..T.s] do Add(row, [X.wpp[i][j][h], T.b[h][k]]); od;
    Add(rows, [Filtered(row, x -> x[2] <> 0), Gcd(T.d[i], T.e[k])]);
  od; od; od;
  return rows;
end;
F2Rows := function(T, V)
  local X, rows, k, l;
  X := V.idx; rows := [];
  for k in [1..T.t] do for l in [k+1..T.t] do
    Add(rows, [Filtered(Concatenation(List([1..T.s], i -> [X.v[i][k], T.b[i][l]]),
                                      List([1..T.s], i -> [X.v[i][l], T.b[i][k]])), x -> x[2] <> 0), T.e[k]]);
  od; od;
  return rows;
end;
Conds := function(T, V, letters, d2, f2)
  local c;
  c := TaharaConds(T, V, rec(drop := Difference(["A","B","C","D","E","F"], letters)));
  if d2 then Append(c, D2Rows(T, V)); fi;
  if f2 then Append(c, F2Rows(T, V)); fi;
  return c;
end;

# pieces, all as elements of gamma_3 (written multiplicatively)
Pieces := function(T, V, tau)
  local X, s, x, Y, d, q, one, R, U, Uc, T1, T2, T3, T4, T5, Ew, L1, i, j, k, h, g, Vrow, VB, L3lhs, Wp;
  X := V.idx; s := T.s; x := T.x1; Y := T.Y; d := T.d; one := One(T.P);
  q := function(i, j) return QuoInt(d[j], d[i]); end;
  R := List([1..s], i -> OProd(T.x2, List([1..T.t], k -> tau[X.v[i][k]]), one));
  # column sums U_i and Lemma 1 per row
  L1 := [];
  for i in [1..s] do
    Uc := Product(List([1..i-1], h -> Comm(Y[h], x[i])^(tau[X.u[h][i]] * q(h, i))), one);
    Ew := one;
    for g in [1..i] do for h in [i..s] do Ew := Ew * Comm(Comm(Y[g], x[h]), x[i])^tau[X.w[g][i][h]]; od; od;
    for g in [1..i] do for h in [g..i] do Ew := Ew * Comm(Comm(Y[g], x[h]), x[i])^tau[X.w[g][h][i]]; od; od;
    for g in [i+1..s] do for h in [g..s] do Ew := Ew * Comm(Comm(Y[g], x[h]), x[i])^tau[X.wp[i][g][h]]; od; od;
    L3lhs := Comm(R[i], x[i])^d[i]
       * Product(List([i+1..s], h -> Comm(Y[h], x[i])^tau[X.u[i][h]]), one)
       * Product(List([1..i-1], h -> Comm(Comm(Y[h], x[i]), x[i])^(-tau[X.u[h][i]] * q(h, i))), one) * Ew^-1;
    Add(L1, rec(Ui := Uc, rhs := L3lhs, Ew := Ew));
  od;
  T1 := one; T2 := one; T3 := one; T4 := one; T5 := one;
  for i in [1..s] do for h in [i+1..s] do
    T1 := T1 * (Comm(x[i]^d[h], x[h]) * Comm(x[h]^d[h], x[i]))^tau[X.u[i][h]];
    T2 := T2 * Comm(Comm(Y[i], x[h]), x[h])^(-tau[X.u[i][h]] * q(i, h));
  od; od;
  for i in [1..s] do for g in [i+1..s] do for h in [g..s] do
    T3 := T3 * Comm(Comm(Y[g], x[i]), x[h])^(-tau[X.wp[i][g][h]]);
  od; od; od;
  for j in [1..s] do for k in [j+1..s] do for h in [k+1..s] do
    T4 := T4 * Comm(Y[h], Comm(x[j], x[k]))^(-tau[X.wpp[j][k][h]]);
  od; od; od;
  for i in [1..s] do T5 := T5 * Comm(Comm(R[i], x[i]), x[i])^(-Binomial(d[i], 2)); od;
  VB := TaharaGen(T, V, tau);
  return rec(R := R, L1 := L1, T := [T1, T2, T3, T4, T5], gen := VB);
end;

# check lemmas on a Z-basis of the lattice for the given conditions
CheckLemmas := function(T, V)
  local res, lat, tau, p, ok1, ok2, ok3, okS, X, i, VB, sumRY, W, Ew, two, one, lhs3, rhs3, s, x, Y, g, h, j, k;
  X := V.idx; s := T.s; x := T.x1; Y := T.Y; one := One(T.P);
  res := rec();
  # Lemma 1: (B)+(E) only
  lat := TaharaLattice(T, V, Conds(T, V, ["B", "E"], false, false));
  res.L1 := ForAll(lat, tau -> ForAll(Pieces(T, V, tau).L1, r -> r.Ui = r.rhs));
  lat := TaharaLattice(T, V, Conds(T, V, ["B"], false, false));
  res.L1ctrlE := ForAll(lat, tau -> ForAll(Pieces(T, V, tau).L1, r -> r.Ui = r.rhs));
  lat := TaharaLattice(T, V, Conds(T, V, ["E"], false, false));
  res.L1ctrlB := ForAll(lat, tau -> ForAll(Pieces(T, V, tau).L1, r -> r.Ui = r.rhs));
  # Lemma 2: F2 only: sum_i [R_i,Y_i] + 2V = 0
  lat := TaharaLattice(T, V, Conds(T, V, [], false, true));
  res.L2 := ForAll(lat, function(tau) p := Pieces(T, V, tau);
     return Product(List([1..s], i -> Comm(p.R[i], Y[i])), one) * p.gen.B^2 = one; end);
  lat := TaharaLattice(T, V, Conds(T, V, [], false, false));
  res.L2ctrl := ForAll(lat{[1..Minimum(Length(lat), 400)]}, function(tau) p := Pieces(T, V, tau);
     return Product(List([1..s], i -> Comm(p.R[i], Y[i])), one) * p.gen.B^2 = one; end);
  # Lemma 3: D2 only: 2W - sum_i <E^w_i,x_i> = T3 + T4
  lat := TaharaLattice(T, V, Conds(T, V, [], true, false));
  res.L3 := ForAll(lat, function(tau) p := Pieces(T, V, tau);
     return p.gen.C^2 * Product(List(p.L1, r -> r.Ew), one)^-1 = p.T[3] * p.T[4]; end);
  lat := TaharaLattice(T, V, Conds(T, V, [], false, false));
  res.L3ctrl := ForAll(lat{[1..Minimum(Length(lat), 400)]}, function(tau) p := Pieces(T, V, tau);
     return p.gen.C^2 * Product(List(p.L1, r -> r.Ew), one)^-1 = p.T[3] * p.T[4]; end);
  # (*) with exactly B, D2, E, F2
  lat := TaharaLattice(T, V, Conds(T, V, ["B", "E"], true, true));
  res.star := ForAll(lat, function(tau) p := Pieces(T, V, tau); return p.gen.g^2 = Product(p.T); end);
  res.starnlat := Length(lat);
  lat := TaharaLattice(T, V, Conds(T, V, ["B", "E"], true, false));
  res.starctrlF2 := ForAll(lat, function(tau) p := Pieces(T, V, tau); return p.gen.g^2 = Product(p.T); end);
  lat := TaharaLattice(T, V, Conds(T, V, ["B", "E"], false, true));
  res.starctrlD2 := ForAll(lat, function(tau) p := Pieces(T, V, tau); return p.gen.g^2 = Product(p.T); end);
  return res;
end;

# full Tahara: g(tau) over the admissible lattice, default basis; D5 = <g(tau)> (Tahara's equality)
FullTahara := function(T, V)
  local lat, gens, bad, p, ts;
  lat := TaharaLattice(T, V, TaharaConds(T, V, rec(drop := [])));
  gens := List(lat, tau -> TaharaGen(T, V, tau).g);
  bad := Filtered([1..Length(lat)], r -> gens[r] <> One(T.P));
  ts := List(lat, function(tau) p := Pieces(T, V, tau); return List(p.T, z -> z = One(T.P)); end);
  return rec(nlat := Length(lat), nbad := Length(bad), D5order := Size(Subgroup(T.P, gens)),
             termsAll1 := ForAll(ts, l -> ForAll(l, b -> b)),
             termsNot1 := List([1..5], r -> Number(ts, l -> not l[r])));
end;

# formula of section 5: [Y_g,x_i,x_h] = [ [x_g,x_i], Y_h ] for d(g)=d(h), i<g<=h
CheckF5 := function(T)
  local x, Y, d, ok, i, g, h;
  x := T.x1; Y := T.Y; d := T.d; ok := true;
  for i in [1..T.s] do for g in [i+1..T.s] do for h in [g..T.s] do
    if d[g] = d[h] then ok := ok and Comm(Comm(Y[g], x[i]), x[h]) = Comm(Comm(x[g], x[i]), Y[h]); fi;
  od; od; od;
  return ok;
end;

Info3 := function(P)
  local L, g2, e4, h2;
  L := ShallowCopy(LowerCentralSeriesOfGroup(P));
  while Length(L) < 5 do Add(L, TrivialSubgroup(P)); od;
  e4 := Exponent(L[4]);
  # gamma_2/gamma_4 abelian, so a -> a^9 mod gamma_4 is a homomorphism: generators suffice
  h2 := ForAll(GeneratorsOfGroup(L[2]), a -> a^9 in L[4]);
  return rec(logsize := Log(Size(P), 3), ab := AbelianInvariants(P), exp4 := e4, H2 := h2,
             class := Length(Filtered(L, H -> not IsTrivial(H))),
             exp23 := Exponent(L[2] / L[3]));
end;

RunOne := function(name, P)
  local T, V, inf, lem, full, f5, line;
  if Length(LowerCentralSeriesOfGroup(P)) < 5 then Print("skip class<4 ", name, "\n"); return fail; fi;
  inf := Info3(P);
  T := TaharaData(P, fail); V := TaharaVars(T);
  lem := CheckLemmas(T, V);
  if V.n <= 400 then full := FullTahara(T, V); else full := "skip"; fi;
  f5 := CheckF5(T);
  line := rec(name := name, info := inf, d := T.d, e := T.e, f := T.f, nvars := V.n, lemmas := lem,
              full := full, F5formula := f5);
  Print(line, "\n");
  PrintTo(OUT, line, "\n");   # overwritten; full log goes to stdout
  return line;
end;

F := FreeGroup("a", "b", "c"); a := F.1; b := F.2; c := F.3;
F2g := FreeGroup("a", "b"); a2 := F2g.1; b2 := F2g.2;

RandComm := function(F, wt)
  local g, c, i;
  g := GeneratorsOfGroup(F); c := Random(g);
  for i in [2..wt] do c := Comm(c, Random(g)); od;
  return c^Random([1, 2]);
end;

results := [];
AddR := function(r) if r <> fail then Add(results, r); fi; end;
if SEED = 0 then
  for cube in [true, false] do
    P := MakeGroup(F, [a^9 * Comm(b, c)^-1, b^9 * Comm(a, c)^-1, c^9], cube);
    if P <> fail then AddR(RunOne(Concatenation("ex1 cube=", String(cube)), P)); fi;
    P := MakeGroup(F, [a^27 * Comm(b, c)^-1, b^9 * Comm(a, c)^-1, c^27 * Comm(a, b)^-1], cube);
    if P <> fail then AddR(RunOne(Concatenation("ex2 cube=", String(cube)), P)); fi;
    P := MakeGroup(F2g, [a2^27 * Comm(Comm(b2, a2), a2)^-1, b2^27 * Comm(a2, b2)^-1], cube);
    if P <> fail then AddR(RunOne(Concatenation("ex3 cube=", String(cube)), P)); fi;
  od;
else
  ng := 0; tries := 0;
  while ng < NG and tries < 20 * NG do
    tries := tries + 1;
    FG := FreeGroup(Random(NGEN));
    gg := GeneratorsOfGroup(FG);
    rels := List(gg, x -> x^Random(EXPS) * Product(List([1..Random([0..2])],
                 r -> RandComm(FG, Random([2, 2, 3, 4]))), One(FG)));
    cube := Random([true, true, false]);
    P := MakeGroup(FG, rels, cube);
    if P = fail then continue; fi;
    if Length(LowerCentralSeriesOfGroup(P)) < 5 then continue; fi;
    ng := ng + 1;
    AddR(RunOne(Concatenation("rand", String(SEED), "_", String(ng), " cube=", String(cube)), P));
  od;
fi;
Print("SUMMARY seed ", SEED, " groups ", Length(results), "\n");
for r in results do
  Print("S ", r.name, " log|P|=", r.info.logsize, " ab=", r.info.ab, " exp4=", r.info.exp4, " H2=", r.info.H2,
        " exp23=", r.info.exp23, " L1=", r.lemmas.L1, "/", r.lemmas.L1ctrlE, "/", r.lemmas.L1ctrlB,
        " L2=", r.lemmas.L2, "/", r.lemmas.L2ctrl, " L3=", r.lemmas.L3, "/", r.lemmas.L3ctrl,
        " star=", r.lemmas.star, "(", r.lemmas.starnlat, ")/", r.lemmas.starctrlF2, "/", r.lemmas.starctrlD2,
        " F5=", r.F5formula, " full=", r.full, "\n");
od;
QUIT;
