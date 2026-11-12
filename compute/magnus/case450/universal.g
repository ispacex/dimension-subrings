# universal.g -- GAP port of universal.sage (MATH-450, wiki 891 Sec. 11): the "universal model" check for a type d.
# Set before reading: DT (the type, sorted list of powers of 3), DROP (list of strings, controls), OUTF (file).
# See universal.sage for the statement; the two implementations are compared on the 3-generator types.
if not IsBound(DROP) then DROP := []; fi;
s := Length(DT);; MM := 9;;
ch := function(i, r) return Binomial(DT[i], r); end;;
qq := function(i, j) return DT[j] / DT[i]; end;;
nz := function(l) return Minimum(List(l, k -> DT[k])); end;;

VARS := [];;
newvar := function(k) Add(VARS, k); return Length(VARS); end;;
U := List([1..s], i -> []);; W := List([1..s], i -> List([1..s], j -> []));;
Wp := List([1..s], i -> List([1..s], j -> []));; Wpp := List([1..s], i -> List([1..s], j -> []));;
for i in [1..s] do for j in [i+1..s] do U[i][j] := newvar(["u", i, j]); od; od;
for i in [1..s] do for j in [1..s] do for k in [1..s] do
  if i <= j and j <= k then W[i][j][k] := newvar(["w", i, j, k]); fi;
  if i < j and j <= k then Wp[i][j][k] := newvar(["wp", i, j, k]); fi;
  if i <= j and j < k then Wpp[i][j][k] := newvar(["wpp", i, j, k]); fi;
od; od; od;
NV := Length(VARS);;
SIX := [];; SK := [];;
for g in [1..s] do for i in [g+1..s] do for h in [1..s] do Add(SK, [g, i, h]); od; od; od;
NSG := Length(SK);;
sigpos := function(g, i, h) return Position(SK, [g, i, h]); end;;
# a linear form = list of [coordinate, coefficient]
sig := function(g, i, h)
  if g = i then return []; fi;
  if g < i then return [[sigpos(g, i, h), 1]]; fi;
  return [[sigpos(i, g, h), -1]];
end;;
scl := function(f, c) return List(f, x -> [x[1], x[2] * c]); end;;
tau := function(g, i, h) if g = i then return []; fi; return scl(sig(g, i, h), DT[g] / nz([g, i, h])); end;;
om := function(g, i, h) if g = i then return []; fi; return scl(sig(g, i, h), DT[h] / nz([g, i, h])); end;;

# R as a bilinear matrix RB[var][sigma coordinate]
RB := NullMat(NV, NSG);;
addR := function(v, f, c) local x; for x in f do RB[v][x[1]] := (RB[v][x[1]] + c * x[2]) mod MM; od; end;;
for i in [1..s] do for h in [i+1..s] do
  addR(U[i][h], om(i, h, i), (DT[h] - 1) / 2 * qq(i, h));
  addR(U[i][h], om(i, h, h), -(DT[h] - 1) / 2 - 1);
od; od;
for i in [1..s] do for g in [i+1..s] do for h in [g..s] do addR(Wp[i][g][h], tau(g, i, h), -1); od; od; od;
for j in [1..s] do for k in [j+1..s] do for h in [k+1..s] do addR(Wpp[j][k][h], om(j, k, h), 1); od; od; od;

# conditions: [form, modulus]
TCONDS := [];;
if not "A" in DROP then
  for i in [1..s] do Add(TCONDS, [[[W[i][i][i], 1]], 0]); od;
  for i in [1..s] do for j in [i+1..s] do
    Add(TCONDS, [[[U[i][j], qq(i, j) * ch(i, 2)], [W[i][i][j], DT[i]], [Wpp[i][i][j], DT[j]]], 0]);
    Add(TCONDS, [[[U[i][j], -ch(j, 2)], [W[i][j][j], DT[i]], [Wp[i][j][j], DT[j]]], 0]);
    for k in [j+1..s] do Add(TCONDS, [[[W[i][j][k], DT[i]], [Wp[i][j][k], DT[j]], [Wpp[i][j][k], DT[k]]], 0]); od;
  od; od;
fi;
if not "C" in DROP then
  for i in [1..s] do for j in [i+1..s] do
    Add(TCONDS, [[[U[i][j], qq(i, j) * ch(i, 3)], [W[i][i][j], ch(i, 2)]], DT[i]]);
    Add(TCONDS, [[[W[i][j][j], ch(i, 2)], [Wpp[i][i][j], ch(j, 2)]], DT[i]]);
    Add(TCONDS, [[[U[i][j], -ch(j, 3)], [Wp[i][j][j], ch(j, 2)]], DT[i]]);
    for k in [j+1..s] do
      Add(TCONDS, [[[W[i][j][k], ch(i, 2)]], DT[i]]); Add(TCONDS, [[[Wp[i][j][k], ch(j, 2)]], DT[i]]);
      Add(TCONDS, [[[Wpp[i][j][k], ch(k, 2)]], DT[i]]);
    od;
  od; od;
fi;
# vectors (h -> form) that must lie in K_e
KV := [];;
if not "B" in DROP then
  for i in [1..s] do
    Add(KV, [List([1..s], function(h)
      if i < h then return [[U[i][h], 1]]; elif h < i then return [[U[h][i], -qq(h, i)]]; fi; return []; end),
      Gcd(9, DT[i])]);
  od;
fi;
if not "D2" in DROP then
  for i in [1..s] do for j in [i+1..s] do
    Add(KV, [List([1..s], function(h)
      if h <= i then return [[W[h][i][j], 1]]; elif h <= j then return [[Wp[i][h][j], 1]]; fi;
      return [[Wpp[i][j][h], 1]]; end), Gcd(9, DT[i])]);
  od; od;
fi;
if not "D1" in DROP then
  for i in [1..s] do
    Add(KV, [List([1..s], function(h) if h <= i then return [[W[h][i][i], 1]]; fi; return [[Wpp[i][i][h], 1]]; end),
      Gcd(9, DT[i])]);
  od;
fi;

# generators of { x in Z^n : form(x) = 0 mod m } plus 9 Z^n
Lat := function(conds, n)
  local nsl, Mx, sl, j, c, x, ns;
  nsl := Number(conds, c -> c[2] <> 0);
  if conds = [] then return IdentityMat(n); fi;
  Mx := NullMat(n + nsl, Length(conds)); sl := n;
  for j in [1..Length(conds)] do
    c := conds[j];
    for x in c[1] do Mx[x[1]][j] := Mx[x[1]][j] + x[2]; od;
    if c[2] <> 0 then sl := sl + 1; Mx[sl][j] := -c[2]; fi;
  od;
  ns := List(NullspaceIntMat(Mx), v -> v{[1..n]});
  return Concatenation(ns, 9 * IdentityMat(n));
end;;

# phi with phi . v = 0 mod 9 for all rows v of L
Perp := function(L)
  local m, Mx, i, j;
  m := Length(L);
  Mx := NullMat(s + m, m);
  for i in [1..s] do for j in [1..m] do Mx[i][j] := L[j][i]; od; od;
  for j in [1..m] do Mx[s + j][j] := -9; od;
  return List(NullspaceIntMat(Mx), v -> v{[1..s]});
end;;

KCondRows := function(Kp)
  local rows, kv, phi, f, h, x;
  rows := [];
  for kv in KV do
    if kv[2] = 1 then continue; fi;
    for phi in Kp.(String(kv[2])) do
      f := [];
      for h in [1..s] do for x in kv[1][h] do Add(f, [x[1], phi[h] * x[2]]); od; od;
      Add(rows, [f, 9]);
    od;
  od;
  return rows;
end;;

SigRows := function(Kg)
  local rows, c, m, n, e, gens, v, f, h, g, i;
  rows := [];
  if not "J" in DROP then
    for c in Combinations([1..s], 3) do
      Add(rows, [Concatenation(sig(c[1], c[2], c[3]), sig(c[2], c[3], c[1]), sig(c[3], c[1], c[2])), MM]);
    od;
  fi;
  for m in [1..s] do for n in [1..s] do
    e := Gcd(9, DT[m], DT[n]);
    if "Kt" in DROP then gens := e * IdentityMat(s); else gens := Kg.(String(e)); fi;
    for v in gens do
      f := []; for h in [1..s] do Append(f, scl(tau(h, m, n), v[h])); od;
      Add(rows, [f, MM]);
    od;
  od; od;
  for g in [1..s] do for i in [g+1..s] do
    e := Gcd(9, DT[g], DT[i]);
    if "Ko" in DROP then gens := e * IdentityMat(s); else gens := Kg.(String(e)); fi;
    for v in gens do
      f := []; for h in [1..s] do Append(f, scl(om(g, i, h), v[h])); od;
      Add(rows, [f, MM]);
    od;
  od; od;
  return rows;
end;;

InLat := function(H, v)   # H: HNF rows (upper triangular, positive diagonal)
  local x, j, acc, i;
  x := [];
  for j in [1..s] do
    acc := v[j] - Sum([1..j-1], i -> x[i] * H[i][j]);
    if acc mod H[j][j] <> 0 then return false; fi;
    x[j] := acc / H[j][j];
  od;
  return true;
end;;

AllK9 := function(Aset)
  local out, Nset, pos, diag, off, H, i, j, p, ok, h, k, e;
  out := []; Nset := Difference([1..s], Aset);
  pos := Filtered(Cartesian([1..s], [1..s]), p -> p[1] < p[2]);
  for diag in Tuples([1, 3, 9], s) do
    if ForAny(Aset, h -> diag[h] = 1) or ForAny(Nset, h -> diag[h] = 9) then continue; fi;
    for off in Cartesian(List(pos, p -> [0..diag[p[2]] - 1])) do
      H := NullMat(s, s);
      for i in [1..s] do H[i][i] := diag[i]; od;
      for p in [1..Length(pos)] do H[pos[p][1]][pos[p][2]] := off[p]; od;
      if ForAny([1..s], i -> ForAny(Aset, h -> H[i][h] mod 3 <> 0)) then continue; fi;
      if not ForAll([1..s], k -> InLat(H, 9 * IdentityMat(s)[k])) then continue; fi;
      if not ForAll(Nset, h -> InLat(H, 3 * IdentityMat(s)[h])) then continue; fi;
      Add(out, H);
    od;
  od;
  return out;
end;;

TBASE := TCONDS;;
total := 0;; nbad := 0;; nfree := 0;; EXS := [];;
for r in [0..s] do for Aset in Combinations([1..s], r) do
  K3 := List([1..s], i -> List([1..s], function(j) if i = j and i in Aset then return 3; elif i = j then return 1; fi;
    return 0; end));
  for K9 in AllK9(Aset) do
    total := total + 1;
    Kg := rec(); Kg.("1") := IdentityMat(s); Kg.("3") := K3; Kg.("9") := K9;
    Kp := rec(); Kp.("3") := Perp(K3); Kp.("9") := Perp(K9);
    lam := Lat(Concatenation(TBASE, KCondRows(Kp)), NV);
    sg := Lat(SigRows(Kg), NSG);
    if ForAny(sg, y -> ForAny(y, a -> a mod 9 <> 0)) then nfree := nfree + 1; fi;
    # bilinear check: lam * RB * sg^T = 0 mod 9
    P := lam * RB * TransposedMat(sg);
    if ForAny(P, row -> ForAny(row, a -> a mod 9 <> 0)) then
      nbad := nbad + 1;
      if Length(EXS) < 3 then Add(EXS, [Aset, K9]); fi;
    fi;
  od;
od; od;
res := Concatenation("TYPE ", String(DT), " drop=", String(DROP), " cases=", String(total), " sigma_nonzero=",
  String(nfree), " FAILING=", String(nbad), " examples=", String(EXS));
Print(res, "\n");
if IsBound(OUTF) then PrintTo(OUTF, res, "\n"); fi;
