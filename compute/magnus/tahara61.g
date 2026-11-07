# Tahara's Theorem 6.1 [Tah81] as a computation: for a finite p-group P of class <= 4, choose uniqueness
# bases of the layers gamma_i/gamma_{i+1} (i = 1,2,3), compute the structure constants b, c, dd, alpha,
# solve the linear system (A)-(F) over Z (exactly as in group-dimension Tahara.lean, Data.Admissible),
# and evaluate Tahara's generator g(tau) on a Z-basis of the admissible lattice.  g is additive in tau
# (gamma_3 is abelian), so D_5(P) <= < g(tau) > = 1 iff all values are 1 (the inclusion is the Lean
# theorem taharaFiveOne).  Commutators: GAP's Comm(a,b) = a^-1 b^-1 a b = Tahara's [a,b].

LayerBasis := function(L, i)
  local hom, A, ig, ord, perm, x, coords;
  hom := NaturalHomomorphismByNormalSubgroup(L[i], L[i+1]);
  A := Image(hom);
  if IsTrivial(A) then
    return rec(x := [], o := [], coords := g -> [], hom := hom, A := A);
  fi;
  ig := IndependentGeneratorsOfAbelianGroup(A);
  ord := List(ig, Order);
  perm := Sortex(ord);
  coords := function(g) return Permuted(IndependentGeneratorExponents(A, Image(hom, g)), perm); end;
  x := List(Permuted(ig, perm), a -> PreImagesRepresentative(hom, a));
  return rec(x := x, o := ord, coords := coords, hom := hom, A := A);
end;

OProd := function(x, a, one) return Product(List([1..Length(x)], i -> x[i]^a[i]), one); end;

# x1 (optional): a uniqueness basis of P/gamma_2 with nondecreasing orders, NOT checked beyond sortedness
# (unused by the scripts); default (fail): our own, from IndependentGeneratorsOfAbelianGroup.
TaharaData := function(P, x1opt)
  local L, B1, B2, B3, s, t, u, x1, d, x2, e, x3, f, Y, b, c, dd, al, i, k, g, h, r, one;
  L := LowerCentralSeriesOfGroup(P);
  while Length(L) < 5 do Add(L, TrivialSubgroup(P)); od;
  if Length(L) > 5 and not IsTrivial(L[5]) then Error("class > 4"); fi;
  one := One(P);
  B1 := LayerBasis(L, 1); B2 := LayerBasis(L, 2); B3 := LayerBasis(L, 3);
  if x1opt = fail then x1 := B1.x; d := B1.o;
  else x1 := x1opt; d := List(x1, y -> Order(Image(B1.hom, y))); fi;
  if not IsSortedList(d) then Error("orders of x1 not sorted"); fi;
  x2 := B2.x; e := B2.o; x3 := B3.x; f := B3.o;
  s := Length(x1); t := Length(x2); u := Length(x3);
  Y := List([1..s], i -> x1[i]^d[i]);
  b := List(Y, B2.coords);
  c := List([1..s], i -> B3.coords(OProd(x2, b[i], one)^-1 * Y[i]));
  for i in [1..s] do
    if not (OProd(x2, b[i], one) * OProd(x3, c[i], one))^-1 * Y[i] in L[4] then Error("hb"); fi;
  od;
  dd := List([1..t], k -> B3.coords(x2[k]^e[k]));
  al := List([1..s], g -> List([1..s], h -> B3.coords(Comm(Y[g], x1[h]))));
  # Data.Valid: hdd, halpha and the ranges (hb is checked above)
  for k in [1..t] do if not OProd(x3, dd[k], one)^-1 * x2[k]^e[k] in L[4] then Error("hdd"); fi; od;
  for g in [1..s] do for h in [g..s] do
    if not OProd(x3, al[g][h], one)^-1 * Comm(Y[g], x1[h]) in L[4] then Error("halpha"); fi; od; od;
  if not ForAll([1..s], i -> ForAll([1..t], k -> 0 <= b[i][k] and b[i][k] < e[k]) and
         ForAll([1..u], l -> 0 <= c[i][l] and c[i][l] < f[l])) then Error("ranges"); fi;
  return rec(P := P, L := L, s := s, t := t, u := u, x1 := x1, d := d, x2 := x2, e := e, x3 := x3, f := f,
             Y := Y, b := b, c := c, dd := dd, al := al, B2 := B2, B3 := B3);
end;

# variable indexing
TaharaVars := function(T)
  local s, t, idx, n, i, j, k, add;
  s := T.s; t := T.t; idx := rec(u := [], v := [], vp := [], w := [], wp := [], wpp := []); n := 0;
  add := function() n := n + 1; return n; end;
  for i in [1..s] do idx.u[i] := []; for j in [i+1..s] do idx.u[i][j] := add(); od; od;
  for i in [1..s] do idx.v[i] := List([1..t], k -> add()); idx.vp[i] := List([1..t], k -> add()); od;
  for i in [1..s] do idx.w[i] := []; idx.wp[i] := []; idx.wpp[i] := [];
    for j in [1..s] do idx.w[i][j] := []; idx.wp[i][j] := []; idx.wpp[i][j] := [];
      for k in [1..s] do
        if i <= j and j <= k then idx.w[i][j][k] := add(); fi;
        if i < j and j <= k then idx.wp[i][j][k] := add(); fi;
        if i <= j and j < k then idx.wpp[i][j][k] := add(); fi;
      od; od; od;
  return rec(idx := idx, n := n);
end;

# conditions (A)-(F) as [ [ [col, coef], ... ], modulus ] (modulus 0: equality); dropE etc. for controls
TaharaConds := function(T, V, opts)
  local s, t, u, d, e, f, b, c, dd, al, q, ch, X, conds, add, i, j, k, l, h, g, row, U, Vv, Vp, W, Wp, Wpp;
  s := T.s; t := T.t; u := T.u; d := T.d; e := T.e; f := T.f; b := T.b; c := T.c; dd := T.dd; al := T.al;
  X := V.idx; U := X.u; Vv := X.v; Vp := X.vp; W := X.w; Wp := X.wp; Wpp := X.wpp;
  q := function(i, j) return QuoInt(d[j], d[i]); end;
  ch := function(i, r) return Binomial(d[i], r); end;
  conds := [];
  add := function(name, row, m) if not name in opts.drop then Add(conds, [Filtered(row, x -> x[2] <> 0), m]); fi; end;
  for i in [1..s] do add("A", [[W[i][i][i], 1]], 0); od;
  for i in [1..s] do for j in [i+1..s] do
    add("A", [[U[i][j], q(i,j)*ch(i,2)], [W[i][i][j], d[i]], [Wpp[i][i][j], d[j]]], 0);
    add("A", [[U[i][j], -ch(j,2)], [W[i][j][j], d[i]], [Wp[i][j][j], d[j]]], 0);
    for k in [j+1..s] do add("A", [[W[i][j][k], d[i]], [Wp[i][j][k], d[j]], [Wpp[i][j][k], d[k]]], 0); od;
  od; od;
  for i in [1..s] do for k in [1..t] do
    row := [[Vv[i][k], d[i]], [Vp[i][k], e[k]]];
    for h in [i+1..s] do Add(row, [U[i][h], b[h][k]]); od;
    for h in [1..i-1] do Add(row, [U[h][i], -q(h,i)*b[h][k]]); od;
    add("B", row, 0);
  od; od;
  for i in [1..s] do for j in [i+1..s] do
    add("C", [[U[i][j], q(i,j)*ch(i,3)], [W[i][i][j], ch(i,2)]], d[i]);
    add("C", [[W[i][j][j], ch(i,2)], [Wpp[i][i][j], ch(j,2)]], d[i]);
    add("C", [[U[i][j], -ch(j,3)], [Wp[i][j][j], ch(j,2)]], d[i]);
    for k in [j+1..s] do
      add("C", [[W[i][j][k], ch(i,2)]], d[i]); add("C", [[Wp[i][j][k], ch(j,2)]], d[i]);
      add("C", [[Wpp[i][j][k], ch(k,2)]], d[i]);
    od;
  od; od;
  for i in [1..s] do for k in [1..t] do
    row := [[Vv[i][k], ch(i,2)]];
    for h in [1..i] do Add(row, [W[h][i][i], -b[h][k]]); od;
    for h in [i+1..s] do Add(row, [Wpp[i][i][h], -b[h][k]]); od;
    add("D", row, Gcd(d[i], e[k]));
    for j in [i+1..s] do
      row := [];
      for h in [1..i] do Add(row, [W[h][i][j], b[h][k]]); od;
      for h in [i+1..j] do Add(row, [Wp[i][h][j], b[h][k]]); od;
      for h in [j+1..s] do Add(row, [Wpp[i][j][h], b[h][k]]); od;
      add("D", row, Gcd(d[i], e[k]));
    od;
  od; od;
  for i in [1..s] do for l in [1..u] do
    row := [];
    for h in [1..i-1] do Add(row, [U[h][i], -q(h,i)*al[h][i][l] - q(h,i)*c[h][l]]); od;
    for h in [i+1..s] do Add(row, [U[i][h], c[h][l]]); od;
    for k in [1..t] do Add(row, [Vp[i][k], -dd[k][l]]); od;
    for g in [1..i] do for h in [i..s] do Add(row, [W[g][i][h], -al[g][h][l]]); od; od;
    for g in [1..i] do for h in [g..i] do Add(row, [W[g][h][i], -al[g][h][l]]); od; od;
    for g in [i+1..s] do for h in [g..s] do Add(row, [Wp[i][g][h], -al[g][h][l]]); od; od;
    add("E", row, Gcd(d[i], f[l]));
  od; od;
  for k in [1..t] do
    add("F", List([1..s], i -> [Vv[i][k], b[i][k]]), e[k]);
    for l in [k+1..t] do
      add("F", Concatenation(List([1..s], i -> [Vv[i][k], b[i][l]]), List([1..s], i -> [Vv[i][l], b[i][k]])), e[k]);
    od;
  od;
  return conds;
end;

# Z-basis (generating set) of the admissible lattice in Z^n
TaharaLattice := function(T, V, conds)
  local n, slacks, M, ncond, j, cond, x, ns, sl;
  n := V.n; slacks := Number(conds, x -> x[2] <> 0); ncond := Length(conds);
  if ncond = 0 then return IdentityMat(n); fi;
  M := NullMat(n + slacks, ncond); sl := n;
  for j in [1..ncond] do
    cond := conds[j];
    for x in cond[1] do M[x[1]][j] := M[x[1]][j] + x[2]; od;
    if cond[2] <> 0 then sl := sl + 1; M[sl][j] := -cond[2]; fi;
  od;
  ns := NullspaceIntMat(M);
  return Filtered(List(ns, v -> v{[1..n]}), v -> not IsZero(v));
end;

# Tahara's generator, split into parts; tau a vector over the variables
TaharaGen := function(T, V, tau)
  local s, t, X, one, gA, gB, gC, i, j, k, l, q;
  s := T.s; t := T.t; X := V.idx; one := One(T.P);
  gA := one; gB := one; gC := one;
  for i in [1..s] do for j in [i+1..s] do
    gA := gA * Comm(T.Y[i], T.x1[j])^(tau[X.u[i][j]] * QuoInt(T.d[j], T.d[i]));
  od; od;
  for i in [1..s] do for k in [1..t] do
    gB := gB * Product(List([k+1..t], l -> Comm(T.x2[l], T.x2[k])^T.b[i][l]), one)^tau[X.v[i][k]];
  od; od;
  for i in [1..s] do for j in [i..s] do for k in [j..s] do
    gC := gC * Comm(Comm(T.Y[i], T.x1[j]), T.x1[k])^tau[X.w[i][j][k]];
  od; od; od;
  return rec(g := gA * gB * gC, A := gA, B := gB, C := gC);
end;

# D_5(P) <= < g(tau) >; returns the subgroup and the lattice
TaharaD5 := function(P, x1opt, opts)
  local T, V, conds, lat, gens;
  T := TaharaData(P, x1opt); V := TaharaVars(T);
  conds := TaharaConds(T, V, opts);
  lat := TaharaLattice(T, V, conds);
  gens := List(lat, tau -> TaharaGen(T, V, tau).g);
  return rec(T := T, V := V, lat := lat, gens := gens, D := Subgroup(P, gens), nconds := Length(conds));
end;
