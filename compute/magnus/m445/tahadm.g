# MATH-445: exact check of "every admissible family gives g = 1" (Tahara 6.1 generators, conditions
# (A)-(F) as in group-dimension Tahara.lean, Data.Admissible) on a given finite p-group Q of class 4.
# The admissible families form a lattice (kernel of an integer matrix with slack variables for the
# congruences); g is additive in tau (gamma_3 abelian), so g = 1 on a lattice basis decides it.
# DROP: list of condition names to drop (negative control), e.g. ["E"].

LayerBasis := function(Q, L, i)  # uniqueness basis of L[i]/L[i+1], orders nondecreasing
  local hom, A, ind, ord, perm, seq, j, pc, x, o;
  hom := NaturalHomomorphismByNormalSubgroup(L[i], L[i+1]); A := Image(hom);
  ind := IndependentGeneratorsOfAbelianGroup(A); ord := List(ind, Order);
  perm := Sortex(ord); ind := Permuted(ind, perm);
  seq := [];
  for x in ind do o := Order(x); j := 1; while j < o do Add(seq, x^j); j := j * PrimePGroup(Q); od; od;
  pc := PcgsByPcSequence(FamilyObj(One(A)), seq);
  return rec(hom := hom, x := List(ind, y -> PreImagesRepresentative(hom, y)), o := ord, ind := ind, pc := pc);
end;
Coords := function(B, g)  # coefficients of g in the basis B (0 <= a_j < o_j)
  local e, res, pos, j, o, c, m;
  e := ExponentsOfPcElement(B.pc, Image(B.hom, g)); res := []; pos := 1;
  for o in B.o do c := 0; m := 1; while m < o do c := c + e[pos] * m; m := m * PrimePGroup(Image(B.hom)); pos := pos + 1; od; Add(res, c); od;
  return res;
end;
OP := function(xs, a) return Product([1..Length(xs)], j -> xs[j]^a[j], One(xs[1])); end;
TahCheck := function(Q, DROP)
  local L, B1, B2, B3, s, t, u, d, e, f, x1, x2, x3, Y, b, c, dd, al, i, j, k, l, g, h, q, ch, V, nv, idx,
        rows, sl, addEq, addCong, M, ker, vec, tau, gen, U, W, VV, bad, ids, h3;
  L := LowerCentralSeriesOfGroup(Q);
  B1 := LayerBasis(Q, L, 1); B2 := LayerBasis(Q, L, 2); B3 := LayerBasis(Q, L, 3);
  x1 := B1.x; d := B1.o; s := Length(d); x2 := B2.x; e := B2.o; t := Length(e); x3 := B3.x; f := B3.o; u := Length(f);
  Y := List([1..s], i -> x1[i]^d[i]);
  b := List(Y, y -> Coords(B2, y));
  c := List([1..s], i -> Coords(B3, OP(x2, b[i])^-1 * Y[i]));
  if ForAny([1..s], i -> not (OP(x2, b[i]) * OP(x3, c[i]))^-1 * Y[i] in L[4]) then Error("b,c"); fi;
  dd := List([1..t], k -> Coords(B3, x2[k]^e[k]));
  al := List([1..s], g -> List([1..s], h -> Coords(B3, Comm(Y[g], x1[h]))));
  q := function(i, j) return d[j] / d[i]; end;
  ch := function(i, r) return Binomial(d[i], r); end;
  # variables
  V := []; idx := function(key) local p; p := Position(V, key); if p = fail then Add(V, key); p := Length(V); fi; return p; end;
  for i in [1..s] do for j in [i+1..s] do idx(["u", i, j]); od; od;
  for i in [1..s] do for k in [1..t] do idx(["v", i, k]); idx(["v'", i, k]); od; od;
  for i in [1..s] do for j in [i..s] do for k in [j..s] do idx(["w", i, j, k]); od; od; od;
  for i in [1..s] do for j in [i+1..s] do for k in [j..s] do idx(["w'", i, j, k]); od; od; od;
  for i in [1..s] do for j in [i..s] do for k in [j+1..s] do idx(["w''", i, j, k]); od; od; od;
  nv := Length(V);
  rows := [];  # each: list of [key, coeff]; slack added for congruences
  addEq := function(name, terms) if not name in DROP then Add(rows, rec(t := terms, m := 0)); fi; end;
  addCong := function(name, terms, m) if not name in DROP then Add(rows, rec(t := terms, m := m)); fi; end;
  for i in [1..s] do addEq("A1", [[["w", i, i, i], 1]]); od;
  for i in [1..s] do for j in [i+1..s] do
    addEq("A2", [[["u", i, j], q(i,j)*ch(i,2)], [["w", i, i, j], d[i]], [["w''", i, i, j], d[j]]]);
    addEq("A3", [[["u", i, j], -ch(j,2)], [["w", i, j, j], d[i]], [["w'", i, j, j], d[j]]]);
    addCong("C1", [[["u", i, j], q(i,j)*ch(i,3)], [["w", i, i, j], ch(i,2)]], d[i]);
    addCong("C2", [[["w", i, j, j], ch(i,2)], [["w''", i, i, j], ch(j,2)]], d[i]);
    addCong("C3", [[["u", i, j], -ch(j,3)], [["w'", i, j, j], ch(j,2)]], d[i]);
    for k in [j+1..s] do
      addEq("A4", [[["w", i, j, k], d[i]], [["w'", i, j, k], d[j]], [["w''", i, j, k], d[k]]]);
      addCong("C4", [[["w", i, j, k], ch(i,2)]], d[i]);
      addCong("C4", [[["w'", i, j, k], ch(j,2)]], d[i]);
      addCong("C4", [[["w''", i, j, k], ch(k,2)]], d[i]);
    od; od; od;
  for i in [1..s] do for k in [1..t] do
    addEq("B", Concatenation(List([i+1..s], h -> [["u", i, h], b[h][k]]), List([1..i-1], h -> [["u", h, i], -q(h,i)*b[h][k]]),
       [[["v", i, k], d[i]], [["v'", i, k], e[k]]]));
    addCong("D1", Concatenation([[["v", i, k], ch(i,2)]], List([1..i], h -> [["w", h, i, i], -b[h][k]]), List([i+1..s], h -> [["w''", i, i, h], -b[h][k]])), Gcd(d[i], e[k]));
    for j in [i+1..s] do
      addCong("D2", Concatenation(List([1..i], h -> [["w", h, i, j], b[h][k]]), List([i+1..j], h -> [["w'", i, h, j], b[h][k]]), List([j+1..s], h -> [["w''", i, j, h], b[h][k]])), Gcd(d[i], e[k]));
    od; od; od;
  for i in [1..s] do for l in [1..u] do
    addCong("E", Concatenation(
      List([1..i-1], h -> [["u", h, i], -q(h,i)*al[h][i][l]]),
      List([i+1..s], h -> [["u", i, h], c[h][l]]),
      List([1..i-1], h -> [["u", h, i], -q(h,i)*c[h][l]]),
      List([1..t], k -> [["v'", i, k], -dd[k][l]]),
      Concatenation(List([1..i], g -> List([i..s], h -> [["w", g, i, h], -al[g][h][l]]))),
      Concatenation(List([1..i], g -> List([g..i], h -> [["w", g, h, i], -al[g][h][l]]))),
      Concatenation(List([i+1..s], g -> List([g..s], h -> [["w'", i, g, h], -al[g][h][l]])))), Gcd(d[i], f[l]));
  od; od;
  for k in [1..t] do
    addCong("F1", List([1..s], i -> [["v", i, k], b[i][k]]), e[k]);
    for l in [k+1..t] do addCong("F2", Concatenation(List([1..s], i -> [["v", i, k], b[i][l]]), List([1..s], i -> [["v", i, l], b[i][k]])), e[k]); od;
  od;
  # matrix: rows = variables (nv) + slacks, columns = equations
  sl := Filtered([1..Length(rows)], j -> rows[j].m <> 0);
  M := NullMat(nv + Length(sl), Length(rows));
  for j in [1..Length(rows)] do
    for g in rows[j].t do M[idx(g[1])][j] := M[idx(g[1])][j] + g[2]; od;
    if rows[j].m <> 0 then M[nv + Position(sl, j)][j] := rows[j].m; fi;
  od;
  if Length(V) <> nv then Error("new variable"); fi;
  if Length(rows) = 0 then ker := IdentityMat(nv); else ker := NullspaceIntMat(M); fi; if IsBound(DEBUG) then Print("nv ", nv, " rows ", Length(rows), " eq ", Number(rows, r -> r.m = 0), " rank ", RankMat(M), " dims ", DimensionsMat(M), "\n"); fi;
  bad := 0; VV := 0;
  for vec in ker do
    tau := function(key) local p; p := Position(V, key); if p = fail then return 0; fi; return vec[p]; end;
    U := Product(Concatenation(List([1..s], i -> List([i+1..s], j -> Comm(Y[i], x1[j])^(tau(["u", i, j])*q(i,j))))), One(Q));
    gen := Product(Concatenation(List([1..s], i -> List([1..t], k ->
       Product(List([k+1..t], l -> Comm(x2[l], x2[k])^b[i][l]), One(Q))^tau(["v", i, k])))), One(Q));
    W := Product(Concatenation(List([1..s], i -> Concatenation(List([i..s], j -> List([j..s], k ->
       Comm(Comm(Y[i], x1[j]), x1[k])^tau(["w", i, j, k])))))), One(Q));
    if gen <> One(Q) then VV := VV + 1; fi;
    if U * gen * W <> One(Q) then bad := bad + 1; fi;
  od;
  return rec(s := s, d := d, e := e, f := f, nker := Length(ker), bad := bad, Vnontriv := VV);
end;
