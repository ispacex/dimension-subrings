# lib450.g -- MATH-450: gamma_4 = C_9 for Q_ab types other than [3,9,9].
# Reads case446/lib446.g (groups OneC9, adapted basis AdaptedX1, Tahara data/lattices from tahara61.g) and
# case446/newchecks.g (TaggedConds, SelConds, C1Rows, HNFl, ResidualParts).
#
# The residual R(tau) of Theorem 2 (wiki 891 Sec. 10.2) lies in gamma_4 = C_9 and is linear in tau, so it is a vector
# r in (Z/9)^n with R(tau) = r . tau mod 9 (discrete log in gamma_4 = <z>).  RVec builds r; RVecB keeps only the terms
# all of whose indices lie in B = { i : d(i) >= 9 } (the "big" indices).  Claims tested (wiki 891 Sec. 11):
#   (red)  R = R_B on the weak lattice W = (c1) + (B) mod 3 + (D2) mod 3  [terms with an index of d = 3 vanish]
#   (two)  |B| <= 2  ==>  R = 0 on W                                          [Theorem 11.1]
#   (obs)  |B| >= 3: R on W, and on W with (B) / (D2) / (A) / (E) exact added -- where the (c1)-(c3) argument stops.
# Every check is counted as rec(n, ne) (vectors, vectors with R <> 0) per lattice; controls are lattices without one
# of the conditions the argument uses.

Read("case446/lib446.g");
Read("case446/newchecks.g");

BigIdx := function(T) return Filtered([1..T.s], i -> T.d[i] >= 9); end;

# discrete log in the cyclic group gamma_4 = <z> of order 9
G4Log := function(T)
  local G4, z, pw;
  G4 := T.L[4];
  if Size(G4) <> 9 or not IsCyclic(G4) then Error("gamma_4 is not C_9"); fi;
  z := MinimalGeneratingSet(G4)[1]; pw := List([0..8], k -> z^k);
  return function(e)
    local p;
    p := Position(pw, e);
    if p = fail then Error("not in gamma_4"); fi;
    return p - 1;
  end;
end;

# r with R(tau) = r . tau (mod 9); keep(i,...) decides which terms are kept (all: true)
RVecKeep := function(T, V, lg, keep)
  local s, X, x, Y, d, r, i, h, g, j, k, oi, oh, add;
  s := T.s; X := V.idx; x := T.x1; Y := T.Y; d := T.d; r := List([1..V.n], v -> 0);
  add := function(col, val) r[col] := (r[col] + val) mod 9; end;
  for i in [1..s] do for h in [i+1..s] do if keep([i, h]) then
    oi := lg(Comm(Comm(x[i], x[h]), Y[i])); oh := lg(Comm(Comm(x[i], x[h]), Y[h]));
    add(X.u[i][h], QuoInt(d[h] - 1, 2) * (QuoInt(d[h], d[i]) * oi - oh));      # T1 (omega part)
    add(X.u[i][h], -oh);                                                        # T2 (pair h<i renamed i<h)
  fi; od; od;
  for i in [1..s] do for g in [i+1..s] do for h in [g..s] do if keep([i, g, h]) then
    add(X.wp[i][g][h], -lg(Comm(Comm(Y[g], x[i]), x[h])));                      # T3
  fi; od; od; od;
  for j in [1..s] do for k in [j+1..s] do for h in [k+1..s] do if keep([j, k, h]) then
    add(X.wpp[j][k][h], -lg(Comm(Y[h], Comm(x[j], x[k]))));                     # T4
  fi; od; od; od;
  return r;
end;

RVec := function(T, V, lg) return RVecKeep(T, V, lg, l -> true); end;
RVecB := function(T, V, lg)
  local B; B := BigIdx(T);
  return RVecKeep(T, V, lg, l -> IsSubset(B, l));
end;

# sanity: r . tau agrees with ResidualParts (lib446) on the given vectors
RVecSanity := function(T, V, lg, r, taus)
  local tau, P, bad;
  bad := 0;
  for tau in taus do
    P := ResidualParts(T, V, tau);
    if lg(P.T1 * P.T2 * P.T3 * P.T4) <> (r * tau) mod 9 then bad := bad + 1; fi;
  od;
  return bad;
end;

NeCount := function(lat, r) return Number(lat, tau -> (r * tau) mod 9 <> 0); end;

# structure of omega / t on the big indices: how often values of order 9 occur
OmegaStruct := function(T, lg)
  local B, x, Y, out, a, b, a2, b2, h, c, v;
  B := BigIdx(T); x := T.x1; Y := T.Y;
  out := rec(cc9 := 0, cc := 0, cY9 := 0, cY := 0, tY9 := 0, tY := 0);
  for a in B do for b in Filtered(B, y -> y > a) do
    for a2 in B do for b2 in Filtered(B, y -> y > a2) do
      if [a, b] < [a2, b2] then
        v := lg(Comm(Comm(x[a], x[b]), Comm(x[a2], x[b2])));
        if v <> 0 then out.cc := out.cc + 1; fi;
        if v mod 3 <> 0 then out.cc9 := out.cc9 + 1; fi;
      fi;
    od; od;
    for h in B do
      v := lg(Comm(Comm(x[a], x[b]), Y[h]));
      if v <> 0 then out.cY := out.cY + 1; fi;
      if v mod 3 <> 0 then out.cY9 := out.cY9 + 1; fi;
    od;
  od; od;
  for a in B do for b in B do if a <> b then for h in B do
    v := lg(Comm(Comm(Y[a], x[b]), x[h]));
    if v <> 0 then out.tY := out.tY + 1; fi;
    if v mod 3 <> 0 then out.tY9 := out.tY9 + 1; fi;
  od; fi; od; od;
  return out;
end;

Mod3 := function(cs) return List(cs, x -> [x[1], 3]); end;

# lattices: W = (c1) + (B) mod 3 + (D2) mod 3 and its strengthenings / controls
Lattices450 := function(T, V, TC)
  local c1, B, B3, D2, D23, A, E, F2, L;
  c1 := C1Rows(T, V); B := SelConds(TC, ["B"]); B3 := Mod3(B);
  D2 := SelConds(TC, ["D2"]); D23 := Mod3(D2);
  A := SelConds(TC, ["A1", "A2", "A3", "A4"]); E := SelConds(TC, ["E"]); F2 := SelConds(TC, ["F2"]);
  L := rec();
  L.W := TaharaLattice(T, V, Concatenation(c1, B3, D23));
  L.WnoB3 := TaharaLattice(T, V, Concatenation(c1, D23));          # control: no (c2)
  L.WnoD23 := TaharaLattice(T, V, Concatenation(c1, B3));          # control: no (c3)
  L.Wnoc1 := TaharaLattice(T, V, Concatenation(B3, D23));          # control: no (c1)
  L.WB := TaharaLattice(T, V, Concatenation(c1, B, D23));          # (B) exact
  L.WD2 := TaharaLattice(T, V, Concatenation(c1, B3, D2));         # (D2) exact
  L.WBD2 := TaharaLattice(T, V, Concatenation(c1, B, D2));         # both exact
  L.WBD2A := TaharaLattice(T, V, Concatenation(c1, B, D2, A));     # + (A)
  L.thm2 := TaharaLattice(T, V, Concatenation(c1, B, D2, E, F2));  # Theorem 2's conditions: 2g = R here
  L.thm2A := TaharaLattice(T, V, Concatenation(c1, B, D2, E, F2, A));
  L.full := TaharaLattice(T, V, TaharaConds(T, V, rec(drop := [])));
  return L;
end;
