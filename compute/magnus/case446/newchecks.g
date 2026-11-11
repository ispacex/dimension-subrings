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

AddStats := function(S, C)
  S.n := S.n + C.n;
  S.bad := S.bad + C.bad; S.A3bad := S.A3bad + C.A3bad;
  S.unondiv3 := S.unondiv3 + C.unondiv3;
  S.omegaA := S.omegaA + C.omegaA; S.omegaB := S.omegaB + C.omegaB;
  S.gbad := S.gbad + C.gbad; S.thm2bad := S.thm2bad + C.thm2bad;
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
