## Referee check for MATH-183 (independent of m183/*.py).
## For Q = H o_C E compares, for n = 2..nmax,
##   ring(n):  Z[H] cap Delta_Q^n  =  Delta_H^n      (what the projection proof actually yields)
##   grp(n):   D_n(Q)              =  D_n(H)
## Lattices: exact HNF over Z (HermiteNormalFormIntegerMat), coordinates = elements.
SetPrintFormattingStatus("*stdout*", false);

NZ := M -> Filtered(M, r -> not IsZero(r));

Glue := function(H, zH, E, zE)
  local P, e1, e2, hom, Q, iso;
  P := DirectProduct(H, E); e1 := Embedding(P, 1); e2 := Embedding(P, 2);
  hom := NaturalHomomorphismByNormalSubgroup(P,
           Subgroup(P, [Image(e1, zH) * Image(e2, zE)^-1]));
  Q := Image(hom); iso := IsomorphismPcGroup(Q);
  hom := CompositionMapping(iso, hom);
  return rec(Q := Image(hom), H := Image(hom, Image(e1, H)));
end;

# Delta^1..Delta^nmax of Z[G] in coordinates els (a list of the elements of G)
DeltaPowers := function(G, els, nmax)
  local N, gens, T, D, out, rows, b, t, w, i, j, v;
  N := Length(els);
  gens := MinimalGeneratingSet(G);
  T := List(gens, x -> List(els, g -> Position(els, g * x)));
  D := [];
  for i in [1 .. N] do
    if els[i] <> One(G) then
      v := ListWithIdenticalEntries(N, 0); v[i] := 1; v[Position(els, One(G))] := -1; Add(D, v);
    fi;
  od;
  D := NZ(HermiteNormalFormIntegerMat(D)); out := [D];
  for j in [2 .. nmax] do
    rows := [];
    for b in D do
      for t in T do
        w := ListWithIdenticalEntries(N, 0);
        for i in [1 .. N] do if b[i] <> 0 then w[t[i]] := w[t[i]] + b[i]; fi; od;
        Add(rows, w - b);
      od;
    od;
    D := NZ(HermiteNormalFormIntegerMat(rows)); Add(out, D);
  od;
  return out;
end;

Dsub := function(G, els, Dn)   # elements g with g-1 in the lattice Dn
  local one, N;
  N := Length(els); one := Position(els, One(G));
  return Filtered(els, function(g) local v; if g = One(G) then return true; fi;
      v := ListWithIdenticalEntries(N, 0); v[Position(els, g)] := 1; v[one] := -1;
      return SolutionIntMat(Dn, v) <> fail; end);
end;

Compare := function(label, H, zH, E, zE, nmax)
  local r, Q, HQ, elsH, rest, els, DQ, DH, res, n, M, nH, I, ring, grp, DnQ, DnH, gH, z2;
  r := Glue(H, zH, E, zE); Q := r.Q; HQ := r.H;
  elsH := AsSSortedList(HQ);
  rest := Filtered(AsSSortedList(Q), g -> not g in HQ);
  els := Concatenation(rest, elsH);          # non-H coordinates first
  DQ := DeltaPowers(Q, els, nmax);
  DH := DeltaPowers(HQ, elsH, nmax);
  nH := Length(elsH);
  res := [];
  for n in [2 .. nmax] do
    M := DQ[n];        # HNF in coordinates (rest, elsH)
    I := List(Filtered(M, row -> IsZero(row{[1 .. Length(rest)]})), row -> row{[Length(rest) + 1 .. Length(els)]});
    I := NZ(HermiteNormalFormIntegerMat(I));
    ring := I = DH[n];
    DnQ := Dsub(Q, els, DQ[n]); DnH := Dsub(HQ, elsH, DH[n]);
    grp := Set(DnQ) = Set(DnH);
    Add(res, Concatenation(String(n), ":", String(ring)[1..1], String(grp)[1..1],
        "(", String(Length(DnQ)), "/", String(Length(DnH)), ")"));
  od;
  gH := LowerCentralSeriesOfGroup(H);
  Print(label, " |Q|=", Size(Q), " res ", JoinStringsWithSeparator(res, " "), "\n");
end;

D8 := DihedralGroup(IsPcGroup, 8); Q8 := QuaternionGroup(IsPcGroup, 8);
C4 := CyclicGroup(IsPcGroup, 4); C8 := CyclicGroup(IsPcGroup, 8);
M16 := SmallGroup(16, 6);
cE := E -> First(AsList(Centre(E)), x -> Order(x) = 2);
a16 := First(AsList(M16), x -> Order(x) = 8 and not x in Centre(M16));
Assert(0, IdGroup(M16) = [16, 6] and Size(Centre(M16)) = 4 and a16^2 in Centre(M16));
u4 := First(AsList(C4), x -> Order(x) = 4); r8 := First(AsList(C8), x -> Order(x) = 8);

for ord in ORDERS do
  for id in [1 .. NumberSmallGroups(ord)] do
    H := SmallGroup(ord, id); Z := Centre(H); L := LowerCentralSeriesOfGroup(H);
    Phi := FrattiniSubgroup(H);
    g3 := function(x) if Length(L) >= 3 then return x in L[3]; else return x = One(H); fi; end;
    for t in Filtered(AsList(Z), x -> Order(x) = 2) do
      tag := Concatenation("H=", String([ord, id]), " t in g2:", String(t in L[2])[1..1],
                           " g3:", String(g3(t))[1..1]);
      if (t in L[2]) or ord <= SMALLALL then
        Compare(Concatenation("D8 ", tag), H, t, D8, cE(D8), NMAX(ord));
        Compare(Concatenation("Q8 ", tag), H, t, Q8, cE(Q8), NMAX(ord));
        Compare(Concatenation("C4 ", tag), H, t, C4, u4^2, NMAX(ord));
      fi;
    od;
    for s in Filtered(AsList(Z), x -> Order(x) = 4) do
      if ord <= SMALLM then
        tag := Concatenation("H=", String([ord, id]), " s in g2:", String(s in L[2])[1..1],
               " Phi:", String(s in Phi)[1..1], " t=s^2 in g2:", String(s^2 in L[2])[1..1],
               " g3:", String(g3(s^2))[1..1], " s square in Z:",
               String(ForAny(AsList(Z), z -> z^2 = s))[1..1]);
        Compare(Concatenation("M16 ", tag), H, s, M16, a16^2, NMAX(ord));
        Compare(Concatenation("C8/C4 ", tag), H, s, C8, r8^2, NMAX(ord));
      fi;
    od;
  od;
od;
Print("DONE\n");
QUIT;
