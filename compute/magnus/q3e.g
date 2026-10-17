# MATH-127 q3: the equation (E) of the wiki page versus the nucleus, for the 7824 groups of type (5,2,1).
# For P (order 3^8, rank 5, type (5,2,1)) the paper part proves: if P has a step-1 descendant then
#   (N1) |Z(P) ∩ gamma_2(P)| = 9, (N2) gamma_2(P) is elementary abelian, (N3) P^3 <= Z(P), and
#   (E)  the linear system below has a solution with c <> 0.
# Notation: w generates gamma_3, v in Z ∩ gamma_2 \ gamma_3, u in gamma_2 \ Z; [u,y] = w^f(y);
# [y,x] = u^a v^b w^*; x^3 = v^alpha(x) w^beta(x).  Unknowns eta_1..eta_d, mu_u, mu_v, c; equations,
# for all x in P/gamma_2 and y in a basis:
#   alpha(x) eta(y) + c beta(x) f(y) + mu_u a + mu_v b + c f(x)^2 a = 0.
# Output per id: id, logN, N1, N2, N3, E.  (The explicit family is checked by q3.g.)
LoadPackage("sglppow"); LoadPackage("anupq");
LogN := function(P)
  local S;
  S := PqPCover(P);
  return LogInt(Size(PCentralSeries(S, 3)[Length(PCentralSeries(P, 3))]), 3);
end;
CondE := function(P)
  local L, G2, G3, Z2, w, v, u, els, crd, Crd, f, gens, d, tup, xs, x, y, j, A, row, cx, cy, ab, al, be, ns, F;
  F := GF(3);
  L := LowerCentralSeriesOfGroup(P); G2 := L[2]; G3 := L[3];
  Z2 := Intersection(Centre(P), G2);
  if Size(Z2) <> 9 then return [false, false, false, false]; fi;
  if not IsElementaryAbelian(G2) then return [true, false, false, false]; fi;
  if not IsSubgroup(Z2, Agemo(P, 3)) then return [true, true, false, false]; fi;
  w := First(GeneratorsOfGroup(G3), g -> g <> One(P));
  v := First(Elements(Z2), g -> not g in G3);
  u := First(Elements(G2), g -> not g in Z2);
  els := []; crd := [];
  for tup in Tuples([0..2], 3) do
    Add(els, u^tup[1] * v^tup[2] * w^tup[3]); Add(crd, tup);
  od;
  Crd := g -> crd[Position(els, g)];
  f := y -> Crd(Comm(u, y))[3];
  gens := MinimalGeneratingSet(P); d := Length(gens);
  A := [];
  for tup in Tuples([0..2], d) do
    x := Product([1..d], i -> gens[i]^tup[i]);
    cx := Crd(x^3); al := cx[2]; be := cx[3];
    if cx[1] <> 0 then Error("x^3 not in Z2"); fi;
    for j in [1..d] do
      y := gens[j];
      ab := Crd(Comm(y, x));
      row := List([1..d], i -> 0); row[j] := al;
      Append(row, [ab[1], ab[2], be * f(y) + f(x)^2 * ab[1]]);
      Add(A, row * One(F));
    od;
  od;
  ns := NullspaceMat(TransposedMat(A));
  return [true, true, true, ForAny(ns, z -> z[d + 3] <> Zero(F))];
end;
Q3E := function(shard, nshard)
  local lg, id, P, r, n;
  lg := OutputTextFile(LOG, false); SetPrintFormattingStatus(lg, false);
  for id in [1387558 .. 1395381] do
    if id mod nshard <> shard then continue; fi;
    P := SmallGroup(3^8, id);
    n := LogN(P); r := CondE(P);
    WriteAll(lg, Concatenation(String(id), ",", String(n), ",",
      JoinStringsWithSeparator(List(r, b -> String(b)), ","), "\n"));
  od;
  WriteAll(lg, Concatenation("shard ", String(shard), " done\n"));
  CloseStream(lg);
end;
if IsBound(SHARD) then Q3E(SHARD, NSHARD); fi;
QUIT;
