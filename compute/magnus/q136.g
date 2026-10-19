# MATH-136: the exact non-terminality criterion for p-groups of type (d,2,1) (wiki: child of page 689).
# P: p odd, P/gamma_2 elementary of rank d, |gamma_2/gamma_3| = p^2, |gamma_3| = p.  Notation:
#   w generates gamma_3, v in Z(P) ∩ gamma_2 \ gamma_3, u in gamma_2 \ Z(P); x_1..x_d a minimal generating set;
#   [u,x_i] = w^f_i;  x_i^p = v^alpha_i w^beta_i;  [x_i,x_j] = u^om1(i,j) v^om2(i,j) w^om3(i,j)  ([a,b] = a^-1 b^-1 a b).
# Unknowns (tails of a step-1 descendant Q, z central of order p):
#   eta_i ([v,x_i] = z^eta_i), sigma_i ([u,x_i] = w^f_i z^sigma_i), mu_u (u^p = z^mu_u), mu_v (v^p = z^mu_v),
#   c ([w,x_i] = z^(c f_i)).
#   (E) for all i, j (i = j included):
#       alpha_j eta_i + c beta_j f_i + mu_u om1(i,j) + mu_v om2(i,j) + [p = 3] c f_j^2 om1(i,j) = 0;
#   (J) for i < j < k, summed over the cyclic shifts of (i,j,k):
#       om1(i,j) sigma_k + om2(i,j) eta_k + c om3(i,j) f_k = 0.
# Theorem D (wiki): under N1-N3, P has a step-1 descendant  <=>  (E)+(J) has a solution with c <> 0.
#
# Columns: id, logN (ANUPQ: PqPCover), logN (GAP's own p-quotient, EpimorphismPGroup of F/[R,F]R^p),
#   N1, N2, N3, Eall (E for all x in P/gamma_2, as on page 689), Egen, J, E+J, E+J without the om3 term
#   (negative control), cert (E+J solution -> FromTheLeftCollector: confluent, |Q| = p|P|, gamma_4(Q) <> 1,
#   Q -> P a homomorphism onto), negcert (an E-only solution with sigma = 0 when E+J fails: "true" would mean
#   that the collector is confluent with gamma_4 <> 1; "-" when not applicable).
LoadPackage("anupq"); LoadPackage("polycyclic");
if not IsBound(PR) then PR := 3; fi;

Q136LogNAnupq := function(P)
  local S;
  S := PqPCover(P);
  return LogInt(Size(PCentralSeries(S, PR)[4]), PR);
end;

Q136LogNGap := function(P, gens)
  local iso, FP, F, fg, rels, G2, S;
  iso := IsomorphismFpGroupByGenerators(P, gens);
  FP := Image(iso); F := FreeGroupOfFpGroup(FP); fg := GeneratorsOfGroup(F);
  rels := RelatorsOfFpGroup(FP);
  G2 := F / Concatenation(Concatenation(List(rels, r -> List(fg, g -> Comm(r, g)))), List(rels, r -> r^PR));
  S := Image(EpimorphismPGroup(G2, PR, 4));
  return LogInt(Size(PCentralSeries(S, PR)[4]), PR);
end;

Q136Sol := function(A, n)
  # a solution with c = 1, or fail
  local ns, z;
  if A = [] then z := List([1..n], i -> Zero(GF(PR))); z[n] := One(GF(PR)); return z; fi;
  ns := NullspaceMat(TransposedMat(A));
  z := First(ns, z -> z[n] <> Zero(GF(PR)));
  if z = fail then return fail; fi;
  return z / z[n];
end;

# the pc presentation of Q from a solution s = (eta, sigma, mu_u, mu_v, c)
Q136Cert := function(P, gens, u, v, w, f, Crd, s)
  local d, n, p, coll, W, i, j, ab, cx, e, Q, qg, hom;
  d := Length(gens); p := PR; n := d + 4;
  e := List(s, IntFFE);
  W := function(l)
    local r, k;
    r := [];
    for k in [1, 3 .. Length(l) - 1] do
      if l[k + 1] mod p <> 0 then Append(r, [l[k], l[k + 1] mod p]); fi;
    od;
    return r;
  end;
  coll := FromTheLeftCollector(n);
  for i in [1..n] do SetRelativeOrder(coll, i, p); od;
  for i in [1..d] do
    cx := Crd(gens[i]^p);
    SetPower(coll, i, W([d + 2, cx[2], d + 3, cx[3]]));
    SetConjugate(coll, d + 1, i, W([d + 1, 1, d + 3, f(gens[i]), d + 4, e[d + i]]));
    SetConjugate(coll, d + 2, i, W([d + 2, 1, d + 4, e[i]]));
    SetConjugate(coll, d + 3, i, W([d + 3, 1, d + 4, e[2 * d + 3] * f(gens[i])]));
    for j in [i + 1 .. d] do
      ab := Crd(Comm(gens[j], gens[i]));
      SetConjugate(coll, j, i, W([j, 1, d + 1, ab[1], d + 2, ab[2], d + 3, ab[3]]));
    od;
  od;
  SetPower(coll, d + 1, W([n, e[2 * d + 1]]));
  SetPower(coll, d + 2, W([n, e[2 * d + 2]]));
  UpdatePolycyclicCollector(coll);
  if not IsConfluent(coll) then return false; fi;
  Q := PcpGroupByCollector(coll);
  if Size(Q) <> p * Size(P) then return false; fi;
  if Size(LowerCentralSeriesOfGroup(Q)[4]) = 1 then return false; fi;
  qg := List([1..n], i -> PcpElementByGenExpList(coll, [i, 1]));
  hom := GroupHomomorphismByImages(Q, P, qg, Concatenation(gens, [u, v, w, One(P)]));
  return hom <> fail and Size(Image(hom)) = Size(P);
end;

Q136Check := function(P)
  local L, G2, G3, Z2, w, v, u, els, crd, Crd, f, gens, d, tup, x, i, j, k, t, t0, n, row,
        Eall, Egen, J, J0, om, cyc, F, s, cert, neg;
  F := GF(PR);
  gens := MinimalGeneratingSet(P); d := Length(gens);
  L := LowerCentralSeriesOfGroup(P); G2 := L[2]; G3 := L[3];
  Z2 := Intersection(Centre(P), G2);
  if Size(Z2) <> PR^2 then return [gens, false, false, false, false, false, false, false, false, "-", "-"]; fi;
  if not IsElementaryAbelian(G2) then return [gens, true, false, false, false, false, false, false, false, "-", "-"]; fi;
  if not IsSubgroup(Z2, Agemo(P, PR)) then return [gens, true, true, false, false, false, false, false, false, "-", "-"]; fi;
  w := First(GeneratorsOfGroup(G3), g -> g <> One(P));
  v := First(Elements(Z2), g -> not g in G3);
  u := First(Elements(G2), g -> not g in Z2);
  els := []; crd := [];
  for tup in Tuples([0..PR - 1], 3) do
    Add(els, u^tup[1] * v^tup[2] * w^tup[3]); Add(crd, tup);
  od;
  Crd := g -> crd[Position(els, g)];
  f := y -> Crd(Comm(u, y))[3];
  n := 2 * d + 3;
  # (E) for the pair (x, y), y = gens[jy]; om(i,j) for (x, y) = (x_j, x_i) is the coordinate vector of [y, x]
  row := function(x, y, jy)
    local r, cx, ab;
    cx := Crd(x^PR);
    if cx[1] <> 0 then Error("x^p not in Z2"); fi;
    ab := Crd(Comm(y, x));
    r := List([1..n], i -> 0);
    r[jy] := cx[2];
    r[2 * d + 1] := ab[1]; r[2 * d + 2] := ab[2];
    r[n] := cx[3] * f(y);
    if PR = 3 then r[n] := r[n] + f(x)^2 * ab[1]; fi;
    return r * One(F);
  end;
  Eall := [];
  for tup in Tuples([0..PR - 1], d) do
    x := Product([1..d], i -> gens[i]^tup[i]);
    for j in [1..d] do Add(Eall, row(x, gens[j], j)); od;
  od;
  Egen := [];
  for i in [1..d] do for j in [1..d] do Add(Egen, row(gens[i], gens[j], j)); od; od;
  J := []; J0 := [];
  for tup in Combinations([1..d], 3) do
    t := List([1..n], i -> 0); t0 := List([1..n], i -> 0);
    for cyc in [[1,2,3], [2,3,1], [3,1,2]] do
      i := tup[cyc[1]]; j := tup[cyc[2]]; k := tup[cyc[3]];
      om := Crd(Comm(gens[i], gens[j]));
      t[d + k] := t[d + k] + om[1]; t0[d + k] := t0[d + k] + om[1];
      t[k] := t[k] + om[2]; t0[k] := t0[k] + om[2];
      t[n] := t[n] + om[3] * f(gens[k]);
    od;
    Add(J, t * One(F)); Add(J0, t0 * One(F));
  od;
  s := Q136Sol(Concatenation(Egen, J), n);
  cert := "-"; neg := "-";
  if s <> fail then
    cert := Q136Cert(P, gens, u, v, w, f, Crd, s);
  else
    s := Q136Sol(Egen, n);
    if s <> fail then
      for i in [d + 1 .. 2 * d] do s[i] := Zero(F); od;
      neg := Q136Cert(P, gens, u, v, w, f, Crd, s);
    fi;
  fi;
  return [gens, true, true, true, Q136Sol(Eall, n) <> fail, Q136Sol(Egen, n) <> fail, Q136Sol(J, n) <> fail,
          Q136Sol(Concatenation(Egen, J), n) <> fail, Q136Sol(Concatenation(Egen, J0), n) <> fail, cert, neg];
end;

Q136Line := function(id, P)
  local r;
  r := Q136Check(P);
  return Concatenation(String(id), ",", String(Q136LogNAnupq(P)), ",", String(Q136LogNGap(P, r[1])), ",",
    JoinStringsWithSeparator(List(r{[2 .. Length(r)]}, String), ","), "\n");
end;

# MODE "block": SmallGroup(3^8, 1387558..1395381), the 7824 groups of type (5,2,1);
# MODE "p7": all groups of order PR^7 of type (4,2,1) with P/gamma_2 elementary.
Q136Run := function(shard, nshard)
  local lg, ids, id, P, Lc;
  lg := OutputTextFile(LOG, false); SetPrintFormattingStatus(lg, false);
  if MODE = "block" then ids := [1387558 .. 1395381]; else ids := [1 .. NrSmallGroups(PR^7)]; fi;
  for id in ids do
    if id mod nshard <> shard then continue; fi;
    if MODE = "block" then
      P := SmallGroup(3^8, id);
    else
      P := SmallGroup(PR^7, id);
      if RankPGroup(P) <> 4 then continue; fi;
      Lc := LowerCentralSeriesOfGroup(P);
      if not (Length(Lc) = 4 and Index(Lc[1], Lc[2]) = PR^4 and Index(Lc[2], Lc[3]) = PR^2
              and Size(Lc[3]) = PR) then continue; fi;
    fi;
    WriteAll(lg, Q136Line(id, P));
  od;
  WriteAll(lg, Concatenation("shard ", String(shard), " done\n"));
  CloseStream(lg);
end;
if IsBound(SHARD) then
  if MODE = "block" then LoadPackage("sglppow"); fi;
  Q136Run(SHARD, NSHARD);
fi;
QUIT;
