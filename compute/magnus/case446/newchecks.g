# -------- Direct checks of the identities in notes/case_b.md --------

# Full names for the components of (B), (D), (F). Exact conditions can be extracted
# from TaharaConds using its documented order: A, B, C, D, E, F.
GroupConds := function(T, V, which)
  local drop;
  drop := Difference(["A", "B", "C", "D", "E", "F"], [which]);
  return TaharaConds(T, V, rec(drop := drop));
end;

# D2 conditions are removed from (D) leaving D1 untouched.
PartDConds := function(T, V)
  local conds, wanted, out, i, j, k, position;
  conds := GroupConds(T, V, "D"); wanted := []; out := []; position := 0;
  for i in [1..T.s] do for k in [1..T.t] do
    position := position + 1; Add(wanted, "D1");
    for j in [i+1..T.s] do position := position + 1; Add(wanted, "D2"); od;
  od; od;
  if Length(wanted) <> Length(conds) then Error("D condition indexing"); fi;
  return [position, wanted, conds];
end;

# precise implementation of D1/F1 selection (generic, with index verification)
CondsCtl := function(T, V, mode)
  local keepC, out, Dall, pd, Fall, wanted, p, i, l, k;
  if mode <> "dropF1" then
    if mode = "dropA" then return TaharaConds(T, V, rec(drop := ["A"])); fi;
    if mode = "dropB" then return TaharaConds(T, V, rec(drop := ["B"])); fi;
    if mode = "dropD" then return TaharaConds(T, V, rec(drop := ["D"])); fi;
    if mode = "dropE" then return TaharaConds(T, V, rec(drop := ["E"])); fi;
    if mode = "full" then return TaharaConds(T, V, rec(drop := [])); fi;
    out := [];
    Append(out, GroupConds(T, V, "A"));
    if mode = "weakB" then Append(out, List(GroupConds(T, V, "B"), x -> [x[1], 3]));
    else Append(out, GroupConds(T, V, "B")); fi;
    Append(out, GroupConds(T, V, "C"));
    pd := PartDConds(T, V);
    if mode = "weakD2" then
      for p in [1..Length(pd[3])] do
        if pd[2][p] = "D2" then Add(out, [pd[3][p][1], 3]); else Add(out, pd[3][p]); fi;
      od;
    elif mode = "dropD1" then
      for p in [1..Length(pd[3])] do if pd[2][p] = "D2" then Add(out, pd[3][p]); fi; od;
    else Append(out, pd[3]); fi;
    Append(out, GroupConds(T, V, "E"));
    Append(out, GroupConds(T, V, "F"));
    return out;
  fi;
  out := [];
  for keepC in ["A", "B", "C", "D", "E"] do Append(out, GroupConds(T, V, keepC)); od;
  Fall := GroupConds(T, V, "F"); wanted := [];
  for k in [1..T.t] do
    Add(wanted, "F1");
    for l in [k+1..T.t] do Add(wanted, "F2"); od;
  od;
  if Length(Fall) <> Length(wanted) then Error("F condition indexing"); fi;
  for p in [1..Length(Fall)] do if wanted[p] = "F2" then Add(out, Fall[p]); fi; od;
  return out;
end;

# Theorem 1 / Proposition 2, original pair vs reduced pair. The t-part is checked separately.
ThmPairs := function(T, V, tau)
  local out, i, h, m, n, q, c, ti, th, omi, omh, orig, reduced, tpart;
  out := rec(n1 := 0, bad1 := 0, tbad := 0, n2 := 0, bad2 := 0);
  for i in [1..T.s] do for h in [i+1..T.s] do
    out.n1 := out.n1 + 1;
    m := T.d[i]; n := T.d[h]; q := QuoInt(n, m); c := Comm(T.x1[i], T.x1[h]);
    ti := Comm(Comm(c, T.x1[i]), T.x1[i]); th := Comm(Comm(c, T.x1[h]), T.x1[h]);
    omi := Comm(c, T.Y[i]); omh := Comm(c, T.Y[h]);
    orig := (Comm(T.x1[i]^n, T.x1[h]) * Comm(T.x1[h]^n, T.x1[i])) ^ tau[V.idx.u[i][h]];
    reduced := (omi^q * omh^(-1))^(QuoInt(n - 1, 2) * tau[V.idx.u[i][h]]);
    if not orig = reduced then out.bad1 := out.bad1 + 1; fi;
    tpart := (ti * th^(-1))^(-n * (n * n - 1) / 12 * tau[V.idx.u[i][h]]);
    if not IsOne(tpart) then out.tbad := out.tbad + 1; fi;
  od; od;
  for h in [1..T.s] do for i in [h+1..T.s] do
    out.n2 := out.n2 + 1;
    orig := Comm(Comm(T.Y[h], T.x1[i]), T.x1[i])^(-tau[V.idx.u[h][i]] * QuoInt(T.d[i], T.d[h]));
    reduced := Comm(Comm(T.x1[h], T.x1[i]), T.Y[i])^(-tau[V.idx.u[h][i]]);
    if not orig = reduced then out.bad2 := out.bad2 + 1; fi;
  od; od;
  return out;
end;

# Direct identity of Corollary 3. No coordinate arithmetic and no cube helper.
Cor3Check := function(T, V, lat)
  local out, is339, x, Y2, Y3, A, B, omA, omB, tau, u, U, w, d;
  out := rec(is339 := false, n := 0, bad := 0, A3bad := 0, unondiv3 := 0,
             omegaA := 0, omegaB := 0, gbad := 0, Rbad := 0, thm2bad := 0);
  is339 := T.s = 3 and T.d = [3, 9, 9]; out.is339 := is339;
  if is339 then
    x := T.x1; Y2 := T.Y[2]; Y3 := T.Y[3];
    A := Comm(Comm(Y2, x[3]), x[2]); B := Comm(Comm(Y3, x[2]), x[3]);
    omA := Comm(Comm(x[2], x[3]), Y2); omB := Comm(Comm(x[3], x[2]), Y3);
    if not A = omA then out.omegaA := 1; fi;
    if not B = omB then out.omegaB := 1; fi;
    if not B = Comm(Comm(x[2], x[3]), Y3)^(-1) then out.omegaB := out.omegaB + 2; fi;
  fi;
  for tau in lat do
    out.n := out.n + 1;
    d := TaharaGen(T, V, tau).g; if not IsOne(d) then out.gbad := out.gbad + 1; fi;
    if not d^2 = ResidualOK(T, V, tau) then out.thm2bad := out.thm2bad + 1; fi;
    if is339 then
      u := tau[V.idx.u[2][3]]; w := tau[V.idx.w[2][3][3]];
      if w + tau[V.idx.wp[2][3][3]] <> 4 * u then out.A3bad := out.A3bad + 1; fi;
      if u mod 3 <> 0 then
        out.unondiv3 := out.unondiv3 + 1;
      else
        U := u / 3;
        if not d^2 = A^(12 * U) * B^(w + 3 * U) then out.bad := out.bad + 1; fi;
      fi;
    fi;
  od;
  return out;
end;

MergeChecks := function(T, V, lat)
  local out, tau, p;
  out := Cor3Check(T, V, lat);
  out.t1n := 0; out.t1bad := 0; out.tpartbad := 0; out.t2n := 0; out.t2bad := 0;
  out.starbad := 0; out.factorbad := 0;
  for tau in lat do
    p := ThmPairs(T, V, tau);
    out.t1n := out.t1n + p.n1; out.t1bad := out.t1bad + p.bad1;
    out.tpartbad := out.tpartbad + p.tbad;
    out.t2n := out.t2n + p.n2; out.t2bad := out.t2bad + p.bad2;
    if not TaharaGen(T, V, tau).g^2 = StarRHS(T, V, tau) then out.starbad := out.starbad + 1; fi;
    if not TermsOK(T, V, tau) then out.factorbad := out.factorbad + 1; fi;
  od;
  return out;
end;

# ======================================================================================================
# Substantive checks (review of #145).  Every identity is counted as rec(n, lhs, rhs, bad): n comparisons,
# lhs / rhs = how many times that side is <> 1, bad = how many times lhs <> rhs.  A claim "X = 1" is counted
# with rhs = 1, so there lhs = bad.  Names containing "_ctl" are NEGATIVE CONTROLS: the same comparison with one
# sign or exponent of the formula changed, or on a lattice without one condition that the derivation uses;
# there bad > 0 shows that the check can fail.
# ======================================================================================================

Cmp := function(S, name, lhs, rhs)
  local r;
  if not IsBound(S.(name)) then S.(name) := rec(n := 0, lhs := 0, rhs := 0, bad := 0); fi;
  r := S.(name); r.n := r.n + 1;
  if not IsOne(lhs) then r.lhs := r.lhs + 1; fi;
  if not IsOne(rhs) then r.rhs := r.rhs + 1; fi;
  if lhs <> rhs then r.bad := r.bad + 1; fi;
end;

AddCnt := function(G, S)
  local nm, f;
  for nm in RecNames(S) do
    if not IsBound(G.(nm)) then G.(nm) := rec(n := 0, lhs := 0, rhs := 0, bad := 0); fi;
    for f in ["n", "lhs", "rhs", "bad"] do G.(nm).(f) := G.(nm).(f) + S.(nm).(f); od;
  od;
end;

HNFl := function(M) if M = [] then return []; fi; return Filtered(HermiteNormalFormIntegerMat(M), r -> not IsZero(r)); end;

# The conditions of TaharaConds tagged by sub-condition (in TaharaConds' order); verified against TaharaConds.
TaggedConds := function(T, V)
  local s, t, out, tags, part, i, j, k, l;
  s := T.s; t := T.t; out := [];
  part := function(letter, tg)
    local cs, p;
    cs := GroupConds(T, V, letter);
    if Length(cs) <> Length(tg) then Error("tag count ", letter); fi;
    for p in [1..Length(cs)] do Add(out, [tg[p][1], tg[p][2], cs[p]]); od;
  end;
  tags := [];
  for i in [1..s] do Add(tags, ["A1", [i]]); od;
  for i in [1..s] do for j in [i+1..s] do
    Add(tags, ["A2", [i, j]]); Add(tags, ["A3", [i, j]]);
    for k in [j+1..s] do Add(tags, ["A4", [i, j, k]]); od;
  od; od;
  part("A", tags);
  tags := [];
  for i in [1..s] do for k in [1..t] do Add(tags, ["B", [i, k]]); od; od;
  part("B", tags);
  tags := [];
  for i in [1..s] do for j in [i+1..s] do
    Append(tags, [["C", [i, j]], ["C", [i, j]], ["C", [i, j]]]);
    for k in [j+1..s] do Append(tags, [["C", [i, j, k]], ["C", [i, j, k]], ["C", [i, j, k]]]); od;
  od; od;
  part("C", tags);
  tags := [];
  for i in [1..s] do for k in [1..t] do
    Add(tags, ["D1", [i, k]]);
    for j in [i+1..s] do Add(tags, ["D2", [i, j, k]]); od;
  od; od;
  part("D", tags);
  tags := [];
  for i in [1..s] do for l in [1..T.u] do Add(tags, ["E", [i, l]]); od; od;
  part("E", tags);
  tags := [];
  for k in [1..t] do Add(tags, ["F1", [k]]); for l in [k+1..t] do Add(tags, ["F2", [k, l]]); od; od;
  part("F", tags);
  if List(out, x -> x[3]) <> TaharaConds(T, V, rec(drop := [])) then Error("tagged conditions"); fi;
  return out;
end;

SelConds := function(TC, keep) return List(Filtered(TC, x -> x[1] in keep), x -> x[3]); end;

# (c1) of wiki 891 Sec. 4: 3 | u_ij when d(i) = d(j), i < j
C1Rows := function(T, V)
  local r, i, j;
  r := [];
  for i in [1..T.s] do for j in [i+1..T.s] do
    if T.d[i] = T.d[j] then Add(r, [[[V.idx.u[i][j], 1]], 3]); fi;
  od; od;
  return r;
end;

# Lattices with exactly the conditions each derivation uses (and controls without one of them):
#   star    : (B), (D2), (E), (F2)                      -- identity (star), wiki 891 Sec. 3
#   starNoE : (B), (D2), (F2)                           -- control: (E) dropped
#   thm2    : (B), (D2), (E), (F2), (c1)                -- Theorem 2: 2g = R(tau) (the t-part of T1 needs (c1))
#   cor3    : (B), (D2), (E), (F2), (c1), (A3)_{2,3}    -- Corollary 3, type [3,9,9] only
#   starNoD2, starNoF2                                  -- controls: (D2) / (F2) dropped
NewLattices := function(T, V, TC)
  local L, base, A323, B3, D23;
  base := SelConds(TC, ["B", "D2", "E", "F2"]);
  L := rec();
  L.star := TaharaLattice(T, V, base);
  L.starNoE := TaharaLattice(T, V, SelConds(TC, ["B", "D2", "F2"]));
  L.thm2 := TaharaLattice(T, V, Concatenation(base, C1Rows(T, V)));
  L.starNoD2 := TaharaLattice(T, V, SelConds(TC, ["B", "E", "F2"]));
  L.starNoF2 := TaharaLattice(T, V, SelConds(TC, ["B", "D2", "E"]));
  # the algebraic steps after (star), on nearly free tau:
  #   c1   : (c1) only                                   -- (star) RHS = R(tau) (Theorem 2 minus (star))
  #   free : no condition                                -- control for c1
  L.c1 := TaharaLattice(T, V, C1Rows(T, V));
  L.free := IdentityMat(V.n);
  if T.s = 3 and T.d = [3, 9, 9] then
    A323 := List(Filtered(TC, x -> x[1] = "A3" and x[2] = [2, 3]), x -> x[3]);
    L.cor3 := TaharaLattice(T, V, Concatenation(base, C1Rows(T, V), A323));
    # R(tau) = A^(12U) B^(w+3U) (Corollary 3 minus Theorem 2) uses (c1), (c2), (c3), (A3)_{2,3}; (c2) and (c3)
    # follow from (B) mod 3 and (D2) mod 3 in the adapted basis
    B3 := List(SelConds(TC, ["B"]), x -> [x[1], 3]); D23 := List(SelConds(TC, ["D2"]), x -> [x[1], 3]);
    L.cor3w := TaharaLattice(T, V, Concatenation(C1Rows(T, V), B3, D23, A323));
    L.cor3wNoA3 := TaharaLattice(T, V, Concatenation(C1Rows(T, V), B3, D23));
    L.cor3wNoB3 := TaharaLattice(T, V, Concatenation(C1Rows(T, V), D23, A323));
    L.cor3wNoD23 := TaharaLattice(T, V, Concatenation(C1Rows(T, V), B3, A323));
  fi;
  return L;
end;

# (star) right side with the factors of one kind (T1..T5) inverted: a negative control
# (F = StarFactors(T, V, tau))
FlipProd := function(T, F, kind)
  return Product(List(F, function(f)
    if f[1]{[1, 2]} = kind then return f[2]^-1; fi; return f[2]; end), One(T.P));
end;

# T2 = prod_{h<i} [Y_h,x_i,x_i]^(-u_hi q_hi) and its claimed form prod_{h<i} omega(cbar_hi, Ybar_i)^(-u_hi)
T2Sides := function(T, V, tau)
  local x, Y, d, l, r, h, i, u;
  x := T.x1; Y := T.Y; d := T.d; l := One(T.P); r := One(T.P);
  for h in [1..T.s] do for i in [h+1..T.s] do
    u := tau[V.idx.u[h][i]];
    l := l * Comm(Comm(Y[h], x[i]), x[i])^(-u * QuoInt(d[i], d[h]));
    r := r * Comm(Comm(x[h], x[i]), Y[i])^(-u);
  od; od;
  return [l, r];
end;

# the t-part of T1: prod_{i<h} (t(c;x_i,x_i) t(c;x_h,x_h)^-1)^(-n(n^2-1)/12 u_ih), c = [x_i,x_h], n = d(h)
TpartSum := function(T, V, tau)
  local x, d, r, i, h, c, n;
  x := T.x1; d := T.d; r := One(T.P);
  for i in [1..T.s] do for h in [i+1..T.s] do
    c := Comm(x[i], x[h]); n := d[h];
    r := r * (Comm(Comm(c, x[i]), x[i]) * Comm(Comm(c, x[h]), x[h])^-1)^(-n * (n^2 - 1) / 12 * tau[V.idx.u[i][h]]);
  od; od;
  return r;
end;

# Group identities, no tau (a coefficient u only multiplies the exponent, so u = 1 per pair covers all u)
PairChecks := function(T, S)
  local s, d, x, Y, i, h, g, a, b, m, n, q, c, ti, th, omi, omh, coef, k, base, lhs, Pi, om, A, B;
  s := T.s; d := T.d; x := T.x1; Y := T.Y;
  for i in [1..s] do for h in [i+1..s] do        # T1: (Delta) and its t-part (Kimi item 3)
    m := d[i]; n := d[h]; q := n / m; c := Comm(x[i], x[h]);
    ti := Comm(Comm(c, x[i]), x[i]); th := Comm(Comm(c, x[h]), x[h]);
    omi := Comm(c, Y[i]); omh := Comm(c, Y[h]);
    coef := n * (n^2 - 1) / 12;
    lhs := Comm(x[i]^n, x[h]) * Comm(x[h]^n, x[i]);
    Cmp(S, "delta", lhs, (omi^q * omh^-1)^((n - 1) / 2) * (ti * th^-1)^(-coef));
    Cmp(S, "delta_ctl_tsign", lhs, (omi^q * omh^-1)^((n - 1) / 2) * (ti * th^-1)^coef);
    Cmp(S, "delta_ctl_half", lhs, (omi^q * omh^-1)^((n + 1) / 2) * (ti * th^-1)^(-coef));
    base := ti * th^-1;
    Cmp(S, "tpart_base", base, One(T.P));               # the t-value that the coefficient must kill
    if m < n then k := 1; else k := 3; fi;               # k = 3: (c1), 3 | u_ih when d(i) = d(h)
    Cmp(S, "tpart", base^(coef * k), One(T.P));
    Cmp(S, "tpart_ctl_coef3", base^(coef * k / 3), One(T.P));   # one factor 3 less in the coefficient
    if m = n then Cmp(S, "tpart_ctl_noc1", base^coef, One(T.P)); fi;   # u = 1, (c1) violated
  od; od;
  for h in [1..s] do for i in [h+1..s] do        # T2: Proposition 1 and the T2 formula per pair (Kimi item 4)
    m := d[h]; n := d[i]; q := n / m; c := Comm(x[h], x[i]);
    ti := Comm(Comm(c, x[i]), x[i]); Pi := Comm(Comm(Y[h], x[i]), x[i]); om := Comm(c, Y[i]);
    Cmp(S, "prop1", Pi^q, om * ti^(-n * (n - m) / 2));
    Cmp(S, "prop1_ctl_inv", Pi^q, om^-1 * ti^(-n * (n - m) / 2));
    Cmp(S, "t2pair", Pi^q, om);
    Cmp(S, "t2pair_ctl_inv", Pi^q, om^-1);
  od; od;
  for g in [1..s] do for i in [1..s] do if g <> i then for h in [1..s] do   # wiki 891 Sec. 5 formula
    c := Comm(x[g], x[i]); lhs := Comm(Comm(Y[g], x[i]), x[h]);
    Cmp(S, "y3", lhs, Comm(c, x[h])^d[g]);
    Cmp(S, "y3_ctl_inv", lhs, Comm(c, x[h])^(-d[g]));
    if d[g] = d[h] then
      Cmp(S, "y3om", lhs, Comm(c, Y[h]));
      Cmp(S, "y3om_ctl_inv", lhs, Comm(c, Y[h])^-1);
    fi;
  od; fi; od; od;
  for a in [1..s] do for b in [a+1..s] do for h in [1..s] do
    Cmp(S, "omega_cY", Comm(Comm(x[a], x[b]), Y[h]), One(T.P));   # how often omega(cbar_ab, Ybar_h) <> 1
  od; od; od;
  if s = 3 and d = [3, 9, 9] then                 # Corollary 3: A, B as omega values
    c := Comm(x[2], x[3]);
    A := Comm(Comm(Y[2], x[3]), x[2]); B := Comm(Comm(Y[3], x[2]), x[3]);
    Cmp(S, "A_omega", A, Comm(c, Y[2]));
    Cmp(S, "A_omega_ctl_inv", A, Comm(c, Y[2])^-1);
    Cmp(S, "B_omega", B, Comm(c, Y[3])^-1);
    Cmp(S, "B_omega_ctl_inv", B, Comm(c, Y[3]));
  fi;
end;

# tau identities on the lattices of NewLattices (all on a generating set; both sides are additive in tau)
LatticeChecks := function(T, V, L, S)
  local tau, g2, P, F, t2, x, A, B, u, U, w, wp, X, CorR;
  X := V.idx;
  for tau in L.star do
    g2 := TaharaGen(T, V, tau).g^2;
    F := StarFactors(T, V, tau);
    Cmp(S, "star", g2, Product(List(F, f -> f[2]), One(T.P)));
    Cmp(S, "star_ctl_flipT1", g2, FlipProd(T, F, "T1"));
    Cmp(S, "star_ctl_flipT2", g2, FlipProd(T, F, "T2"));
    Cmp(S, "star_ctl_flipT3", g2, FlipProd(T, F, "T3"));
    Cmp(S, "star_ctl_flipT4", g2, FlipProd(T, F, "T4"));
    t2 := T2Sides(T, V, tau);
    Cmp(S, "t2sum", t2[1], t2[2]);
    Cmp(S, "t2sum_ctl_inv", t2[1], t2[2]^-1);
    Cmp(S, "tpartsum_ctl_noc1", TpartSum(T, V, tau), One(T.P));
    P := ResidualParts(T, V, tau);
    Cmp(S, "thm2_ctl_noc1", g2, P.T1 * P.T2 * P.T3 * P.T4);
  od;
  for tau in L.starNoE do
    g2 := TaharaGen(T, V, tau).g^2;
    Cmp(S, "star_ctl_noE", g2, StarRHS(T, V, tau));
  od;
  for tau in L.starNoD2 do Cmp(S, "star_ctl_noD2", TaharaGen(T, V, tau).g^2, StarRHS(T, V, tau)); od;
  for tau in L.starNoF2 do Cmp(S, "star_ctl_noF2", TaharaGen(T, V, tau).g^2, StarRHS(T, V, tau)); od;
  # Theorem 2 minus (star): (star) RHS = R(tau) for every tau with (c1) (items 3, 4 and T5 = 1)
  for tau in L.c1 do
    F := StarFactors(T, V, tau); g2 := Product(List(F, f -> f[2]), One(T.P));
    P := ResidualParts(T, V, tau);
    Cmp(S, "rhsR", g2, P.T1 * P.T2 * P.T3 * P.T4);
    Cmp(S, "rhsR_ctl_flipT1", g2, P.T1^-1 * P.T2 * P.T3 * P.T4);
    Cmp(S, "rhsR_ctl_flipT2", g2, P.T1 * P.T2^-1 * P.T3 * P.T4);
    Cmp(S, "rhsR_ctl_flipT3", g2, P.T1 * P.T2 * P.T3^-1 * P.T4);
    Cmp(S, "rhsR_ctl_flipT4", g2, P.T1 * P.T2 * P.T3 * P.T4^-1);
    t2 := T2Sides(T, V, tau);
    Cmp(S, "t2sum_c1", t2[1], t2[2]);
    Cmp(S, "t2sum_c1_ctl_inv", t2[1], t2[2]^-1);
    Cmp(S, "tpartsum_c1", TpartSum(T, V, tau), One(T.P));
  od;
  for tau in L.free do
    F := StarFactors(T, V, tau); g2 := Product(List(F, f -> f[2]), One(T.P));
    P := ResidualParts(T, V, tau);
    Cmp(S, "rhsR_ctl_noc1", g2, P.T1 * P.T2 * P.T3 * P.T4);
    Cmp(S, "tpartsum_ctl_free", TpartSum(T, V, tau), One(T.P));
    t2 := T2Sides(T, V, tau);                      # the T2 formula needs no condition on tau
    Cmp(S, "t2sum_free", t2[1], t2[2]);
    Cmp(S, "t2sum_free_ctl_inv", t2[1], t2[2]^-1);
  od;
  for tau in L.thm2 do
    g2 := TaharaGen(T, V, tau).g^2;
    P := ResidualParts(T, V, tau);
    Cmp(S, "thm2", g2, P.T1 * P.T2 * P.T3 * P.T4);
    Cmp(S, "thm2_ctl_flipT1", g2, P.T1^-1 * P.T2 * P.T3 * P.T4);
    Cmp(S, "thm2_ctl_flipT2", g2, P.T1 * P.T2^-1 * P.T3 * P.T4);
    Cmp(S, "thm2_ctl_flipT3", g2, P.T1 * P.T2 * P.T3^-1 * P.T4);
    Cmp(S, "tpartsum", TpartSum(T, V, tau), One(T.P));
  od;
  if IsBound(L.cor3) then
    x := T.x1;
    A := Comm(Comm(T.Y[2], x[3]), x[2]); B := Comm(Comm(T.Y[3], x[2]), x[3]);
    for tau in L.cor3 do
      u := tau[X.u[2][3]]; w := tau[X.w[2][3][3]]; wp := tau[X.wp[2][3][3]];
      if u mod 3 <> 0 or w + wp <> 4 * u then Error("cor3 lattice"); fi;
      U := u / 3;
      g2 := TaharaGen(T, V, tau).g^2;
      Cmp(S, "cor3", g2, A^(12 * U) * B^(w + 3 * U));
      Cmp(S, "cor3_ctl_flipB", g2, A^(12 * U) * B^(-(w + 3 * U)));
    od;
    for tau in L.thm2 do                          # (A3) not imposed
      u := tau[X.u[2][3]]; w := tau[X.w[2][3][3]]; U := u / 3;
      Cmp(S, "cor3_ctl_noA3", TaharaGen(T, V, tau).g^2, A^(12 * U) * B^(w + 3 * U));
    od;
    # Corollary 3 minus Theorem 2: R(tau) = A^(12U) B^(w+3U) on (c1), (B) mod 3, (D2) mod 3, (A3)_{2,3}
    CorR := function(tau, name, flip)
      local P, u, w;
      u := tau[X.u[2][3]]; w := tau[X.w[2][3][3]];
      P := ResidualParts(T, V, tau);
      Cmp(S, name, P.T1 * P.T2 * P.T3 * P.T4, A^(12 * (u / 3)) * B^(flip * (w + u)));
    end;
    for tau in L.cor3w do
      CorR(tau, "cor3R", 1); CorR(tau, "cor3R_ctl_flipB", -1);
    od;
    for tau in L.cor3wNoA3 do CorR(tau, "cor3R_ctl_noA3", 1); od;
    for tau in L.cor3wNoB3 do CorR(tau, "cor3R_ctl_noB3", 1); od;
    # wider lattice, (D2) mod 3 (hence (c3)) not imposed: a positive test where the sides can be <> 1
    for tau in L.cor3wNoD23 do
      CorR(tau, "cor3R_wide_noD23", 1); CorR(tau, "cor3R_wide_noD23_ctl_flipB", -1);
    od;
  fi;
end;
