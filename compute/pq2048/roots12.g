# The elementary abelian roots in the estimate for 2^LOGQ (README, "Estimate for 2^12"): the vertices of
# order 2^(LOGQ-2) (level a) whose tree parent is the root 2^D itself, i.e. the groups of order 2^(LOGQ-2),
# rank D and 2-class 2.  For LOGQ = 11 they are the library groups of order 512 (tree.g, LIBROOT) and
# sample12.g samples them as ordinary vertices; for LOGQ = 12 they have order 1024, outside SmallGroups,
# and PqDescendants of the root (GL(D,2) acting) does not finish (m40-est12-roots).  So they are sampled
# here as quotients of the p-cover.
#
# R = PqPCover(2^D), M its multiplicator (dim m = D(D+1)/2), W = R' (dim w = D(D-1)/2) <= M.  The step-s
# descendants of 2^D, s = LOGQ-2-D, are R/U for the subspaces U <= M of codimension s (every one is
# allowable: the nucleus is M), up to GL(D,2).  V = R/U has V' = (W+U)/U and Phi(V) = M/U, so V_ab is
# elementary iff W + U = M: exactly those Theorem A drops (order 2^(LOGQ-2), class 2, 2-class 2).
# With u = m - s and i = dim(U ∩ W), the number of U with a given i is
#   2^((w-i)(u-i)) [w over i]_2 [m-w over u-i]_2,
# and W + U = M iff i = w + u - m.  The survivors (i > w + u - m) are counted exactly; a uniform survivor
# is drawn by drawing i with these weights, a uniform i-subspace A of W, a uniform (u-i)-subspace of a
# complement C of W and a uniform lift of each basis vector by W.
# The number of isomorphism classes is sum over U of 1/|orbit| = (#U / |GL|) E[|Stab(U)|]; it is taken as
# #U / |GL| (stabilisers trivial), a lower bound that is close when #U >> |GL| (D >= 5).
#
# Each drawn V goes through the filters of tree.g at level a ((Г_N) p5b of prune.g) and, if kept, is
# expanded by its step 1 to the leaves exactly as in sample12.g (SA_Expand: Theorem B, Tahara, TIGHT,
# (Г_N)), with up to M3 parents timed by MC_Data.
# Input: D, LOGQ, NS (samples), SEED, OUTFILE (appended), [M3 = 2].
# Output: a line {"D","s","m","w","total","surv","gl"} (counts as strings), then per sample a line
#   {"start":j} and {"j","i","kept",["steps","ms_steps","by","cov"],"ms_build","ms_keep"}.
SA_NORUN := true;;
if not IsBound(M3) then M3 := 2; fi;
M2 := 0;;
Read("sample12.g");
RT_RS := RandomSource(IsMersenneTwister, SEED);;

RT_GB := function(n, k)   # Gaussian binomial [n over k]_2
  local r, j;
  if k < 0 or k > n then return 0; fi;
  r := 1;
  for j in [0 .. k - 1] do r := r * (2 ^ (n - j) - 1) / (2 ^ (j + 1) - 1); od;
  return r;
end;;

RT_RandVec := function(rows)  # uniform element of the span of the independent rows
  local v, r;
  v := Zero(rows[1]);
  for r in rows do if Random(RT_RS, [0, 1]) = 1 then v := v + r; fi; od;
  return v;
end;;

RT_RandSub := function(rows, k)  # rows of a uniform k-dim subspace of the span of the independent rows
  local res, v;
  res := [];
  while Length(res) < k do
    v := RT_RandVec(rows);
    if RankMat(Concatenation(res, [v])) > Length(res) then Add(res, v); fi;
  od;
  return res;
end;;

RT_Run := function()
  local E, R, pcs, n, m, Mb, W, w, s, u, imin, counts, total, surv, gl, i, x, j, A, C, Bbar, U, gens,
        hom, V, t0, t1, kept, e, resP, cov, out, cum, all;
  s := LOGQ - 2 - D;
  E := ElementaryAbelianGroup(2 ^ D);
  R := PqPCover(E);
  pcs := Pcgs(R);
  n := D; m := Length(pcs) - n;
  W := MC_Vecs(pcs, n, m, DerivedSubgroup(R));
  w := Length(W);
  u := m - s;
  imin := w + u - m;   # W + U = M iff i = imin (Theorem A)
  counts := List([0 .. Minimum(w, u)], i -> 2 ^ ((w - i) * (u - i)) * RT_GB(w, i) * RT_GB(m - w, u - i));
  total := Sum(counts);
  surv := Sum([imin + 2 .. Length(counts)], k -> counts[k]);  # i = k - 1 > imin
  gl := Product([0 .. D - 1], k -> 2 ^ D - 2 ^ k);
  FileString(OUTFILE, Concatenation("{\"D\":", String(D), ",\"s\":", String(s), ",\"m\":", String(m),
    ",\"w\":", String(w), ",\"total\":\"", String(total), "\",\"surv\":\"", String(surv),
    "\",\"gl\":\"", String(gl), "\"}\n"), true);
  # a complement C of W in M
  Mb := IdentityMat(m, GF(2));
  C := [];
  for x in Mb do
    if RankMat(Concatenation(W, C, [x])) > w + Length(C) then Add(C, x); fi;
  od;
  for j in [1 .. NS] do
    FileString(OUTFILE, Concatenation("{\"start\":", String(j), "}\n"), true);
    t0 := SA_Rt();
    # i > imin with weights counts[i+1]
    x := Random(RT_RS, 1, surv);
    i := imin + 1; cum := counts[i + 1];
    while x > cum do i := i + 1; cum := cum + counts[i + 1]; od;
    if i > 0 then A := RT_RandSub(W, i); else A := []; fi;
    Bbar := RT_RandSub(C, u - i);
    U := Concatenation(A, List(Bbar, b -> b + RT_RandVec(W)));
    gens := List(U, v -> PcElementByExponentsNC(pcs, Concatenation(ListWithIdenticalEntries(n, 0), IntVecFFE(v))));
    if gens = [] then hom := IdentityMapping(R);
    else hom := NaturalHomomorphismByNormalSubgroupNC(R, SubgroupNC(R, gens)); fi;
    V := Image(hom);
    V := PcGroupCode(CodePcGroup(V), Size(V));
    t1 := SA_Rt();
    if Size(V) <> 2 ^ (LOGQ - 2) or RankPGroup(V) <> D or MS_PClass(V) <> 2
       or ForAll(AbelianInvariants(V), y -> y = 2) then
      Error("roots12: bad quotient");
    fi;
    kept := PR_Data(V, LOGQ).p5b;
    out := Concatenation("{\"j\":", String(j), ",\"i\":", String(i), ",\"kept\":", String(kept),
      ",\"ab\":", SA_J(AbelianInvariants(V)), ",\"ms_build\":", String(t1 - t0), ",\"ms_keep\":", String(SA_Rt() - t1));
    if kept then
      resP := rec(seen := 0, items := [], cap := M3);
      e := SA_Expand(V, [SA_LB], rec(seen := 0, items := [], cap := 0), resP);
      cov := SA_Cov(resP, "r");
      out := Concatenation(out, ",\"steps\":", SA_J(e.steps), ",\"ms_steps\":", String(e.ms_steps),
        ",\"by\":", SA_ByJ(e.by), ",\"np\":", String(resP.seen), ",\"cov\":[", JoinStringsWithSeparator(cov, ","), "]");
    fi;
    FileString(OUTFILE, Concatenation(out, "}\n"), true);
  od;
end;;
RT_Run();
QUIT;
