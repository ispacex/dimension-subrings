# Step-1 descendants by linear algebra on the p-cover.  See README.md,
# "Search through the p-cover".  Needs lib.g (MS_PClass, MS_MJ, MS_MonoInvolution).
#
# For a parent R (2-group of class <= 3) let R* = PqPCover(R), M its p-multiplicator (the last
# MultiplicatorRank pcgs elements of R*), N = P_c(R*) the nucleus (c = p-class of R).  Every step-1
# immediate descendant of R is R*/U for a hyperplane U of M with N not in U, and the candidate
# conditions of the lemma that concern n (M/U = <n>) are linear in U:
#   class <= 3          <=>  gamma_4(R*) <= U
#   n in gamma_3(Q)     <=>  M ∩ gamma_3(R*) not in U
#   n in M_5(Q)         <=>  M ∩ M_5(R*) not in U   (M_JK, JK = 4 for the D_4 search).
# A hyperplane is the kernel of a nonzero functional f on M = GF(2)^m; f vanishes on gamma_4(R*),
# so f = a * Y with Y a basis of the annihilator of gamma_4(R*) and a in GF(2)^k.  Each remaining
# condition reads "a not in ker P_X" with P_X = X * Y^T.

MC_Gamma := function(G, i)
  local L;
  L := LowerCentralSeriesOfGroup(G);
  if Length(L) < i then return TrivialSubgroup(G); fi;
  return L[i];
end;;

# Rows spanning the subgroup S <= M as vectors of GF(2)^m.
MC_Vecs := function(pcs, n, m, S)
  local v;
  v := List(GeneratorsOfGroup(S), x -> ExponentsOfPcElement(pcs, x){[n + 1 .. n + m]} * Z(2));
  v := Filtered(v, x -> not IsZero(x));
  if v = [] then return []; fi;
  return BaseMat(v);
end;;

# Number of a in GF(2)^k outside ker P_1 ∪ ... ∪ ker P_r (P_i given as lists of rows of length k).
MC_CountOutside := function(k, Ps)
  local tot, sub, rows, r, s;
  tot := 0;
  for sub in Combinations([1 .. Length(Ps)]) do
    rows := Concatenation(List(sub, i -> Ps[i]));
    if rows = [] then r := 0; else r := RankMat(rows); fi;
    s := (-1)^Length(sub);
    tot := tot + s * 2^(k - r);
  od;
  return tot;
end;;

# The linear data of a parent.  Returns a record with the cover, M, the annihilator basis Y and the
# three condition matrices, plus the count of admissible hyperplanes; times in ms per stage.
MC_Data := function(R)
  local t, Rs, pcs, n, m, M, c, G4, A, B, N, Y, PA, PB, PN, k, rec_, tm;
  tm := rec();
  t := Runtime();
  # ../pq2048/pcover.g, when read, may replace pq (PC_Cover); otherwise as before
  if IsBound(PC_Cover) then Rs := ValueGlobal("PC_Cover")(R); else Rs := PqPCover(R); fi;
  tm.cover := Runtime() - t; t := Runtime();
  pcs := Pcgs(Rs);
  n := Length(Pcgs(R));
  m := Length(pcs) - n;
  M := SubgroupNC(Rs, pcs{[n + 1 .. n + m]});
  c := MS_PClass(R);
  G4 := MC_Vecs(pcs, n, m, MC_Gamma(Rs, 4));
  A := MC_Vecs(pcs, n, m, Intersection(M, MC_Gamma(Rs, 3)));
  B := MC_Vecs(pcs, n, m, Intersection(M, MS_MJ(Rs)));
  N := MC_Vecs(pcs, n, m, PCentralSeries(Rs, 2)[c + 1]);
  if G4 = [] then Y := IdentityMat(m, GF(2));
  else Y := NullspaceMat(TransposedMat(G4)); fi;   # rows y with G4 * y^T = 0
  k := Length(Y);
  if k = 0 or A = [] or B = [] or N = [] then
    PA := []; PB := []; PN := [];
  else
    PA := A * TransposedMat(Y); PB := B * TransposedMat(Y); PN := N * TransposedMat(Y);
  fi;
  tm.linear := Runtime() - t;
  rec_ := rec(Rs := Rs, pcs := pcs, n := n, m := m, M := M, Y := Y, k := k,
              PA := PA, PB := PB, PN := PN, tm := tm);
  if k = 0 or A = [] or B = [] or N = [] or IsZero(PA) or IsZero(PB) or IsZero(PN) then
    rec_.count := 0;
  else
    rec_.count := MC_CountOutside(k, [PA, PB, PN]);
  fi;
  return rec_;
end;;

# All a in GF(2)^k outside ker P_A ∪ ker P_B ∪ ker P_N, as functionals f = a * Y on M.
MC_Functionals := function(r)
  local res, a, TA, TB, TN, V;
  res := [];
  if r.count = 0 then return res; fi;
  TA := TransposedMat(r.PA); TB := TransposedMat(r.PB); TN := TransposedMat(r.PN);
  V := GF(2)^r.k;
  for a in V do
    if IsZero(a * TA) or IsZero(a * TB) or IsZero(a * TN) then continue; fi;
    Add(res, a * r.Y);
  od;
  return res;
end;;

# The centre of Q = R*/ker f, by linear algebra.  Zt/M = Z(R); for a lift x of z in Z(R) the map
# g -> [x,g] is a homomorphism R* -> M, so x is central mod U iff f vanishes on [x, g] for the
# generators g; the order of x mod U is e (the order of z) or 2e as f(x^e) = 0 or 1.
MC_CentreData := function(r)
  local Rs, pcs, n, m, hom, Zr, L, data, x, e, gens, vec;
  Rs := r.Rs; pcs := r.pcs; n := r.n; m := r.m;
  vec := y -> ExponentsOfPcElement(pcs, y){[n + 1 .. n + m]} * Z(2);
  hom := NaturalHomomorphismByNormalSubgroupNC(Rs, r.M);
  Zr := Centre(Image(hom));
  gens := MinimalGeneratingSet(Rs);
  data := [];
  for x in AsList(Zr) do
    e := Order(x);
    x := PreImagesRepresentative(hom, x);
    Add(data, rec(e := e, comm := List(gens, g -> vec(Comm(x, g))), pow := vec(x^e)));
  od;
  return rec(data := data, size := Size(Zr));
end;;

MC_CyclicCentre := function(cd, f)
  local ZU, s;
  ZU := Filtered(cd.data, x -> ForAll(x.comm, v -> IsZero(v * f)));
  s := Length(ZU);
  if s = 1 then return true; fi;
  return ForAny(ZU, x -> x.e = s and not IsZero(x.pow * f));
end;;

# Q = R*/ker f as a pc group, with n the image of M (its involution M/U).
MC_Quotient := function(r, f)
  local U, hom, n0;
  U := List(NullspaceMat(TransposedMat([f])), v -> PcElementByExponentsNC(r.pcs,
         Concatenation(ListWithIdenticalEntries(r.n, 0), IntVecFFE(v))));
  if U = [] then U := TrivialSubgroup(r.Rs); else U := SubgroupNC(r.Rs, U); fi;
  hom := NaturalHomomorphismByNormalSubgroupNC(r.Rs, U);
  n0 := r.pcs[r.n + PositionProperty(f, x -> not IsZero(x))];
  return rec(f := f, Q := Image(hom), n := Image(hom, n0));
end;;

# The candidates of the lemma among the step-1 descendants of R, without isomorphism reduction:
# a list of rec(f, Q, n) (Q a pc group of order 2|R|, n its central involution); r := MC_Data(R).
MC_Candidates := function(r, withgroups)
  local res, cd, f;
  res := [];
  if r.count = 0 then return res; fi;
  cd := MC_CentreData(r);
  for f in MC_Functionals(r) do
    if not MC_CyclicCentre(cd, f) then continue; fi;
    if withgroups then
      Add(res, MC_Quotient(r, f));
    else
      Add(res, rec(f := f));
    fi;
  od;
  return res;
end;;

# A complete isomorphism invariant of a p-group (pc group): its standard presentation (ANUPQ), as
# IsPqIsomorphicPGroup compares it, but computed once per group so that a list is reduced by sets.
MC_IsoKey := function(G)
  local p, S;
  p := PrimePGroup(G);
  S := PqStandardPresentation(PqFpGroupPcGroup(G) : Prime := p, ClassBound := PClassPGroup(G));
  return [Size(G), List(RelatorsOfFpGroup(S), ExtRepOfObj)];
end;;

# The action of Aut(R) on the functionals of M.  R' = R*/M; an automorphism a of R' lifts to an
# endomorphism a* of R* (images of the generators lifted arbitrarily: R* = F/[K,F]K^p is the
# p-cover on the same generators, so the lift is a well-defined automorphism and its restriction
# to M does not depend on the choice).  a* maps U to U a*, the functional f with kernel U to
# f a*^-1; the matrices returned act on row vectors f by OnRight.  Two allowable U give
# isomorphic descendants iff they lie in one orbit (O'Brien 1990), so the orbits of the
# candidate functionals are the candidates up to isomorphism.
MC_AutMats := function(r)
  local hom, Rp, A, gens, mats, a, imgs, ast, mat, vec;
  vec := y -> ExponentsOfPcElement(r.pcs, y){[r.n + 1 .. r.n + r.m]} * Z(2);
  hom := NaturalHomomorphismByNormalSubgroupNC(r.Rs, r.M);
  Rp := Image(hom);
  A := AutomorphismGroupPGroup(Rp);
  gens := MinimalGeneratingSet(r.Rs);
  mats := [];
  # autpgrp's record: generators as glAutos and agAutos
  for a in Concatenation(A.glAutos, A.agAutos) do
    imgs := List(gens, g -> PreImagesRepresentative(hom, Image(a, Image(hom, g))));
    ast := GroupHomomorphismByImagesNC(r.Rs, r.Rs, gens, imgs);
    mat := List([1 .. r.m], j -> vec(Image(ast, r.pcs[r.n + j])));   # rows: images of the basis
    Add(mats, TransposedMat(mat^-1));                                 # f -> f * (mat^-1)^T
  od;
  return mats;
end;;

# Orbit representatives of a list of functionals under MC_AutMats (the list is a union of orbits:
# the linear conditions and the centre test are invariant).
MC_OrbitReps := function(r, fs)
  local mats, G, reps, seen, f, orb;
  if Length(fs) <= 1 then return fs; fi;
  mats := MC_AutMats(r);
  if mats = [] then return fs; fi;
  G := Group(mats);
  reps := []; seen := [];
  for f in fs do
    if f in seen then continue; fi;
    orb := Orbit(G, f, OnRight);
    UniteSet(seen, orb);
    Add(reps, f);
  od;
  return reps;
end;;
