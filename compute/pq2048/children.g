# Step-1 descendants without PqDescendants: V*/U over the orbits of Aut(V) on the allowable
# hyperplanes U of the multiplicator with gamma_4(V*) <= U (the children of class <= 3, the only
# ones the walk looks at).  See README.md, "Step-1 children without pq".
# Needs ../pq1024/lib.g, ../pq1024/cover.g (MC_Vecs, MC_Gamma, MC_AutMats, MC_Quotient), pcover.g.
#
# CH_Step1(V) -> the list of children (pc groups of order 2|V|, one per isomorphism class), or
#   fail when the space of functionals has dimension k > CH_KMAX (default 22): then the caller uses
#   PqDescendants.
# CH_Desc(V, s) -> CH_Step1(V) when OWNDESC and s = 1 and it does not fail, else MS_Desc(V, s).
#   OWNDESC defaults to the environment variable PQ2048_OWNDESC (1 = on).
if not IsBound(CH_KMAX) then CH_KMAX := 22; fi;
if not IsBound(OWNDESC) then
  OWNDESC := IsBound(GAPInfo.SystemEnvironment.PQ2048_OWNDESC)
             and GAPInfo.SystemEnvironment.PQ2048_OWNDESC = "1";
fi;

CH_Step1 := function(V)
  local Rs, pcs, n, m, M, c, N, G4, Y, k, P, r, mats, A, gens, seen, res, x, a, orb, b, f, tot,
        need, done;
  Rs := PC_Cover(V);
  pcs := Pcgs(Rs);
  n := Length(Pcgs(V));
  m := Length(pcs) - n;
  if m = 0 then return []; fi;
  M := SubgroupNC(Rs, pcs{[n + 1 .. n + m]});
  c := MS_PClass(V);
  N := MC_Vecs(pcs, n, m, PCentralSeries(Rs, 2)[c + 1]);
  if N = [] then return []; fi;                         # terminal: no descendants at all
  G4 := MC_Vecs(pcs, n, m, MC_Gamma(Rs, 4));
  if G4 = [] then Y := IdentityMat(m, GF(2));
  else Y := NullspaceMat(TransposedMat(G4)); fi;       # basis of the functionals vanishing on G4
  k := Length(Y);
  if k = 0 then return []; fi;
  if k > CH_KMAX then return fail; fi;
  P := Y * TransposedMat(N);                           # f = a Y is allowable iff a P <> 0
  if IsZero(P) then return []; fi;
  r := rec(Rs := Rs, pcs := pcs, n := n, m := m, M := M);
  # the action of Aut(V) on functionals f of M (f -> f T), carried to the coordinates a of f = a Y
  mats := MC_AutMats(r);
  gens := List(mats, T -> List(Y * T, row -> SolutionMat(Y, row)));
  gens := Filtered(gens, g -> g <> IdentityMat(k, GF(2)));
  for b in gens do ConvertToMatrixRep(b, 2); od;
  if gens <> [] then A := Group(gens); fi;
  tot := 2 ^ k;
  seen := BlistList([1 .. tot], []);
  res := [];
  # the allowable a (a P <> 0) number 2^k - 2^(k - rank P); stop once their orbits cover them all
  need := tot - 2 ^ (k - RankMat(P));
  done := 0;
  for x in [1 .. tot - 1] do
    if done = need then break; fi;
    if seen[x + 1] then continue; fi;
    # the vector with NumberFFVector(a, 2) = x: the first coordinate is the most significant bit
    a := CoefficientsQadic(x, 2);
    a := Reversed(Concatenation(a, ListWithIdenticalEntries(k - Length(a), 0))) * Z(2);
    ConvertToVectorRep(a, 2);
    if IsZero(a * P) then seen[x + 1] := true; continue; fi;
    if gens = [] then orb := [a]; else orb := Orbit(A, a, OnRight); fi;
    for b in orb do seen[NumberFFVector(b, 2) + 1] := true; od;
    done := done + Length(orb);
    f := a * Y;
    Add(res, MC_Quotient(r, f).Q);
  od;
  return res;
end;;

CH_Desc := function(V, s)
  local res;
  if OWNDESC and s = 1 then
    res := CH_Step1(V);
    if res <> fail then return res; fi;
  fi;
  return MS_Desc(V, s);
end;;
