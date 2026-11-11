# lib446.g -- tm test of the case (b) note on groups with gamma_4 = C_9,
# in the adapted basis of star444.g (TaharaData / AdaptedX1 / StarFactors / TaharaLattice).
# Reads tahara61.g from the tree.  No anupq: groups built with EpimorphismPGroup (OneC9).
# A watch timer stops the job gracefully at the end of its budget.

if not IsBound(MODE) then Error("set MODE, NG, KS, TOPS, OUT first"); fi;
ROOTDIR := DirectoryCurrent();;   # the tree root; OUT is resolved against it
if not IsBound(NEEDNOTH2) then NEEDNOTH2 := false; fi;
if not IsBound(EXTRAW) then EXTRAW := [2, 3, 3, 4]; fi;
if not IsBound(MAXV) then MAXV := 1200; fi;
if not IsBound(TRIALS) then TRIALS := 40; fi;
if not IsBound(BIGLAT) then BIGLAT := 4000; fi;
if not IsBound(WATCH) then WATCH := 700; fi;
Read("tahara61.g");

STARTTIME := Runtime();
OUTFILE := OUT;
OUTS := OutputTextFile(OUTFILE, false);
if OUTS = fail then Error("cannot open OUT"); fi;
SetPrintFormattingStatus(OUTS, false);
StopAll := function(msg)
  Print("STOP: ", msg, "\n");
  CloseStream(OUTS);
  SaveWorkspace("stop.wsp");
end;
CheckWatch := function()
  if Runtime() - STARTTIME > WATCH * 1000 then StopAll("time budget reached"); fi;
end;
emit := function(s) WriteAll(OUTS, s); WriteAll(OUTS, "\n"); end;

RW := function(F, wt)
  local g, c, i;
  g := GeneratorsOfGroup(F); c := Random(g);
  for i in [2..wt] do c := Comm(c, Random(g)); od;
  return c^Random([1, 2]);
end;

W5 := function(F)
  local g, L, i;
  g := GeneratorsOfGroup(F); L := List(g, x -> x);
  for i in [2..5] do L := Concatenation(List(L, c -> List(g, y -> Comm(c, y)))); od;
  return Filtered(L, c -> c <> One(F));
end;

PQClass := function(ord)
  local lg;
  lg := Reversed(SortedList(List(ord, d -> LogInt(d, 3))));
  return lg[1] + 3 * lg[2] + 1;
end;

LogExp := function(H, N) if Size(H) = Size(N) then return 0; fi; return Log(Exponent(H / N), 3); end;

# Random relators: g_i^ord_i = a product of 0..extraw[1] random commutators whose weights are drawn from extraw{[2,3]},
# plus up to k+2 relators of weights from extraw.  NB: with the default EXTRAW = [2,3,3,4] the power words have
# weight 3 only, so Y_i = x_i^d(i) lies in gamma_3 for the original generators (Ybar_i = 0 in L_2); this is why
# omega(cbar, Ybar_h), A and B are trivial in the groups of the original run.  EXTRAW = [2,2,3,4] allows weight 2.
RandP := function(F, g, ord, pqc, extraw)
  local k, rels, Fp, epi, P0, L0, P, L;
  k := Length(g);
  rels := List([1..k], i -> g[i]^ord[i] / Product(List([1..Random([0..extraw[1]])],
    j -> RW(F, Random(extraw{[2, 3]}))), One(F)));
  Append(rels, List([1..Random([0..k+2])], j -> Product(List([1..Random([1..2])],
    t -> RW(F, Random(extraw))), One(F))));
  Fp := F / Concatenation(rels, W5(F));
  epi := EpimorphismPGroup(Fp, 3, pqc);
  P0 := Image(epi);
  L0 := LowerCentralSeriesOfGroup(P0);
  if Length(L0) >= 5 then P := Image(NaturalHomomorphismByNormalSubgroup(P0, L0[5])); else P := P0; fi;
  L := LowerCentralSeriesOfGroup(P);
  return [P, Length(L) - 1 = 4 and SortedList(AbelianInvariants(P)) = SortedList(ord)];
end;

CutP := function(P, G4, u)
  local ig, o, e, lam, C, c, f;
  ig := IndependentGeneratorsOfAbelianGroup(G4); o := List(ig, Order);
  e := IndependentGeneratorExponents(G4, u);
  if ForAll([1..Length(ig)], r -> o[r] < 9 or e[r] mod 3 = 0) then return fail; fi;
  repeat lam := List(o, x -> Random(Filtered([0..8], l -> (l * x) mod 9 = 0))); until (lam * e) mod 3 <> 0;
  C := CyclicGroup(IsPcGroup, 9); c := MinimalGeneratingSet(C)[1];
  f := GroupHomomorphismByImages(G4, C, ig, List(lam, l -> c^l));
  return NaturalHomomorphismByNormalSubgroupNC(P, Kernel(f));
end;

# ---- AdaptedX1, InSpan, Extend, F3 copied verbatim from compute/magnus/star444.g (main == 841f7c0 for this file);
# the 841f7c0 tahara61.g does not contain them.
F3 := GF(3);
InSpan := function(B, v) if B = [] then return IsZero(v); fi; return SolutionMat(B, v) <> fail; end;
Extend := function(B, cands)   # add vectors of cands to B keeping independence, return the added ones
  local added, v, BB;
  added := []; BB := ShallowCopy(B);
  for v in cands do if not InSpan(BB, v) then Add(BB, v); Add(added, v); fi; od;
  return added;
end;

# adapted uniqueness basis of P/gamma_2: z_i = (d(i)/3) xbar_i, basis of Omega_1 compatible with the height
# flag V_j and with K = ker Pbar (Pbar(z) = (lift of z)^3 mod gamma_2^3 gamma_3, in L2/3L2).
AdaptedX1 := function(P, L)
  local hab, A, ig, n, m, lifts, B2, pv, Pb, Kb, J, j, Vj, Kj, Bv, Bh, C1, D, z, xs, ds, perm, y, r;
  hab := NaturalHomomorphismByNormalSubgroup(P, L[2]); A := Image(hab);
  ig := IndependentGeneratorsOfAbelianGroup(A); n := List(ig, Order); m := Length(ig);
  lifts := List(ig, a -> PreImagesRepresentative(hab, a));
  B2 := LayerBasis(L, 2);
  pv := function(w) return List(B2.coords(w), x -> x * One(F3)); end;
  Pb := List([1..m], r -> pv((lifts[r]^(n[r] / 3))^3));
  Kb := NullspaceMat(Pb);          # rows: basis of ker Pbar in the coordinates of the v_r
  J := Maximum(List(n, x -> Log(x, 3))) - 1;
  Bv := []; Bh := [];
  for j in [J, J-1 .. 0] do
    Vj := List(Filtered([1..m], r -> n[r] >= 3^(j+1)), r -> IdentityMat(m, F3)[r]);
    if Kb = [] then Kj := []; else Kj := SumIntersectionMat(Vj, Kb)[2]; fi;
    C1 := Extend(Filtered(Bv, v -> Kb <> [] and InSpan(Kb, v)), Kj);
    D := Extend(Concatenation(Bv, C1), Vj);
    for z in Concatenation(C1, D) do Add(Bv, z); Add(Bh, j); od;
  od;
  if Length(Bv) <> m then Error("adapted basis"); fi;
  # x with 3^j xbar = z, d = 3^(j+1)
  xs := []; ds := [];
  for r in [1..m] do
    y := Product(List([1..m], s -> lifts[s]^(IntFFE(Bv[r][s]) * n[s] / 3^(Bh[r] + 1))), One(P));
    Add(xs, y); Add(ds, 3^(Bh[r] + 1));
  od;
  perm := Sortex(ds);
  return Permuted(xs, perm);
end;

OneC9 := function(ab, extraw, trials)
  local k, pqc, F, g, trial, r, P, L, DD, A3, u, c, x, v, hom, Pb, ub, Lb, Ob, U, P9;
  k := Length(ab); pqc := PQClass(ab);
  F := FreeGroup(k); g := GeneratorsOfGroup(F);
  for trial in [1..trials] do
    CheckWatch();
    r := RandP(F, g, ab, pqc, extraw);
    P := r[1];
    if not r[2] then continue; fi;
    L := LowerCentralSeriesOfGroup(P);
    if LogExp(L[2], L[3]) < 2 then continue; fi;
    DD := DerivedSubgroup(L[2]);
    if IsTrivial(DD) then continue; fi;
    A3 := Agemo(L[4], 3, 2);
    u := fail;
    for c in [1..50] do x := Random(L[4]); if not x in A3 and (c > 25 or x in DD) then u := x; break; fi; od;
    if u = fail then continue; fi;
    hom := CutP(P, L[4], u);
    if hom = fail then continue; fi;
    Pb := Image(hom); ub := Image(hom, u)^3;
    while true do
      Ob := Omega(Centre(Pb), 3, 1);
      if Size(Ob) = 3 then break; fi;
      U := Subgroup(Pb, [ub]);
      repeat v := Random(Ob); until not v in U;
      hom := hom * NaturalHomomorphismByNormalSubgroup(Pb, NormalClosure(Pb, Subgroup(Pb, [v])));
      Pb := Image(hom); ub := Image(hom, u)^3;
    od;
    Lb := LowerCentralSeriesOfGroup(Pb);
    if Length(Lb) - 1 <> 4 or Size(Lb[4]) <> 9 or not IsCyclic(Lb[4]) then continue; fi;
    if SortedList(AbelianInvariants(Pb)) <> SortedList(ab) then continue; fi;
    if NEEDNOTH2 then
      P9 := Subgroup(Pb, Concatenation(List(GeneratorsOfGroup(Lb[2]), a -> a^9), GeneratorsOfGroup(Lb[4])));
      if Size(P9) = Size(Lb[4]) then continue; fi;
    fi;
    return Pb;
  od;
  return fail;
end;

TermsOK := function(T, V, tau)
  local f;
  for f in StarFactors(T, V, tau) do if not IsOne(f[2]) then return false; fi; od;
  return true;
end;

# ---- StarFactors, StarRHS copied verbatim from compute/magnus/star444.g (same file at main)
# the factors of (*) for tau; returns a list of [name, element]
StarFactors := function(T, V, tau)
  local s, X, x, Y, d, F, i, h, g, j, k, q, R;
  s := T.s; X := V.idx; x := T.x1; Y := T.Y; d := T.d; F := [];
  q := function(i, j) return QuoInt(d[j], d[i]); end;
  for i in [1..s] do for h in [i+1..s] do
    Add(F, [Concatenation("T1 ", String([d[i], d[h]])), (Comm(x[i]^d[h], x[h]) * Comm(x[h]^d[h], x[i]))^tau[X.u[i][h]]]);
  od; od;
  for h in [1..s] do for i in [h+1..s] do
    Add(F, [Concatenation("T2 ", String([d[h], d[i]])), Comm(Comm(Y[h], x[i]), x[i])^(-tau[X.u[h][i]] * q(h, i))]);
  od; od;
  for i in [1..s] do for g in [i+1..s] do for h in [g..s] do
    Add(F, [Concatenation("T3 ", String([d[i], d[g], d[h]])), Comm(Comm(Y[g], x[i]), x[h])^(-tau[X.wp[i][g][h]])]);
  od; od; od;
  for j in [1..s] do for k in [j+1..s] do for h in [k+1..s] do
    Add(F, [Concatenation("T4 ", String([d[j], d[k], d[h]])), Comm(Y[h], Comm(x[j], x[k]))^(-tau[X.wpp[j][k][h]])]);
  od; od; od;
  for i in [1..s] do
    R := Product(List([1..T.t], k -> T.x2[k]^tau[X.v[i][k]]), One(T.P));
    Add(F, [Concatenation("T5 ", String([d[i]])), Comm(Comm(R, x[i]), x[i])^(-Binomial(d[i], 2))]);
  od;
  return F;
end;

StarRHS := function(T, V, tau) return Product(List(StarFactors(T, V, tau), f -> f[2]), One(T.P)); end;

# T1*T2*T3*T4 with Theorem 1 (containing (n-1)/2) and Proposition 2 [Theorem 2 of the note]: the residual R(tau),
# returned by parts (T1 only its omega part: the t-part is dropped; T2 by the omega formula; T5 dropped)
ResidualParts := function(T, V, tau)
  local s, X, x, Y, d, T1e, T2e, T3e, T4e, i, h, g, j, kk, oi, oh;
  s := T.s; X := V.idx; x := T.x1; Y := T.Y; d := T.d;
  T1e := One(T.P); T2e := One(T.P); T3e := One(T.P); T4e := One(T.P);
  for i in [1..s] do for h in [i+1..s] do
    oi := Comm(Comm(x[i], x[h]), Y[i]);
    oh := Comm(Comm(x[i], x[h]), Y[h]);
    T1e := T1e * (oi^(QuoInt(d[h], d[i]) * tau[X.u[i][h]]) * oh^(-tau[X.u[i][h]]))^(QuoInt(d[h] - 1, 2));
  od; od;
  for h in [1..s] do for i in [h+1..s] do
    T2e := T2e * Comm(Comm(x[h], x[i]), Y[i])^(-tau[X.u[h][i]]);
  od; od;
  for i in [1..s] do for g in [i+1..s] do for h in [g..s] do
    T3e := T3e * Comm(Comm(Y[g], x[i]), x[h])^(-tau[X.wp[i][g][h]]);
  od; od; od;
  for j in [1..s] do for kk in [j+1..s] do for h in [kk+1..s] do
    T4e := T4e * Comm(Y[h], Comm(x[j], x[kk]))^(-tau[X.wpp[j][kk][h]]);
  od; od; od;
  return rec(T1 := T1e, T2 := T2e, T3 := T3e, T4 := T4e);
end;

ResidualOK := function(T, V, tau)
  local p;
  p := ResidualParts(T, V, tau);
  return p.T1 * p.T2 * p.T3 * p.T4;
end;

# (Delta) and Proposition 1 for every pair of x1's (all orders, every group with gamma_4^9 = 1)
DeltaChecks := function(T)
  local s, d, x, i, h, m, n, q, c, Delta, rhs, ti, th, omi, omh, Pi, bad;
  s := T.s; d := T.d; x := T.x1; bad := 0;
  for i in [1..s] do for h in [i+1..s] do
    m := d[i]; n := d[h]; q := QuoInt(n, m); c := Comm(x[i], x[h]);
    Delta := Comm(x[i]^n, x[h]) * Comm(x[h]^n, x[i]);
    ti := Comm(Comm(c, x[i]), x[i]); th := Comm(Comm(c, x[h]), x[h]);
    omi := Comm(c, x[i]^m); omh := Comm(c, x[h]^n);
    rhs := (omi^q * omh^(-1))^(QuoInt(n - 1, 2)) * (ti * th^(-1))^(-n * (n^2 - 1) / 12);
    if not Delta = rhs then bad := bad + 1; fi;
  od; od;
  for h in [1..s] do for i in [h+1..s] do
    m := d[h]; n := d[i]; q := QuoInt(n, m); c := Comm(x[h], x[i]);
    Pi := Comm(Comm(x[h]^m, x[i]), x[i]);
    ti := Comm(Comm(c, x[i]), x[i]);
    if not Pi^q = Comm(c, x[i]^n) * ti^(-n * (n - m) / 2) then bad := bad + 1; fi;
  od; od;
  return bad;
end;
