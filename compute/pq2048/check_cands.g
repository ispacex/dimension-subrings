# Control of Theorems 1 and 2 (README.ru.md «Сверка»): on every candidate Q (class 3, cyclic
# centre, its involution in gamma_3 ∩ M_5, 2-class >= 4, |P_c(Q)| = 2) check
#   (Г)   for Q itself and for every Q/P_j(Q), j = 2..c   (Theorem 1),
#   (Г_N) with N = log2|Q| for every Q/P_j(Q), j = 2..c  (Theorem 2; j = c is the parent R).
# P_1 = Q, P_{i+1} = [P_i, Q] P_i^2 (GAP's PCentralSeries(Q, 2)[i]); the 2-class c: P_c <> 1 = P_{c+1}.
# Any failure is printed as FAIL and counted in "fail"; it would mean a mistake in a proof or code.
# It also records the slack of the conditions and of some unproved ones (README.ru.md «Не доказано»):
#   "r2_minus_d"   max of rank(gamma_2(V)) - d(V) over all these V (Q included);
#   "r23_minus_d"  max of rank(gamma_2(V)/gamma_3(V)) - d(V);
#   "rz_minus_rmax" max of rank(gamma_2/(gamma_2 ∩ Z)) - min(d, d(d-1)/2);
#   "bud_slack"    min of N - log2(2|gamma_2(V)|^2/|K|) over the proper quotients (>= 0 by Theorem 2);
#   "r2R_minus_d"  max of rank(gamma_2(R)) - d over the parents R only.
# Input: either NN, IDFROM, IDTO (SmallGroups, candidates found by MS_MonoInvolution) or CODES
# (a list of [code, order] of pc groups, e.g. made from desc1c.g output); STATFILE.
Read("../pq1024/lib.g");
Read("prune.g");
CC_Max := function(a, b) if a = fail then return b; fi; return Maximum(a, b); end;;
CC_Min := function(a, b) if a = fail then return b; fi; return Minimum(a, b); end;;
CC_Run := function()
  local S, check, groups, i, G, P, t0, out, k, nm;
  S := rec(cands := 0, quotients := 0, fail := 0, by_rank := [],
           r2_minus_d := fail, r23_minus_d := fail, rz_minus_rmax := fail, bud_slack := fail,
           r2R_minus_d := fail);
  check := function(Q, id)
    local P, c, N, j, V, r, L, r23;
    if NilpotencyClassOfGroup(Q) <> 3 or MS_MonoInvolution(Q) = fail then
      Print("NOT A CANDIDATE ", id, "\n"); S.fail := S.fail + 1; return;
    fi;
    P := PCentralSeries(Q, 2);
    c := Length(P) - 1;
    if c < 4 or Size(P[c]) <> 2 then Print("NOT A CANDIDATE ", id, "\n"); S.fail := S.fail + 1; return; fi;
    S.cands := S.cands + 1;
    k := RankPGroup(Q);
    if not IsBound(S.by_rank[k]) then S.by_rank[k] := 0; fi;
    S.by_rank[k] := S.by_rank[k] + 1;
    N := PR_Log2(Size(Q));
    # j = 0 is Q itself (Theorem 1 only), j = 2..c the quotients Q/P_j(Q)
    for j in Concatenation([0], [2 .. c]) do
      if j = 0 then V := Q; else V := Q / P[j]; fi;
      S.quotients := S.quotients + 1;
      r := PR_Data(V, N);
      if not r.p5 then Print("FAIL (G) ", id, " j=", j, "\n"); S.fail := S.fail + 1; fi;
      if j > 0 and not r.p5b then Print("FAIL (G_N) ", id, " j=", j, "\n"); S.fail := S.fail + 1; fi;
      if r.cls >= 2 then
        L := LowerCentralSeriesOfGroup(V);
        if r.cls = 3 then r23 := Length(AbelianInvariants(L[2] / L[3])); else r23 := r.r2; fi;
        S.r2_minus_d := CC_Max(S.r2_minus_d, r.r2 - r.d);
        S.r23_minus_d := CC_Max(S.r23_minus_d, r23 - r.d);
        S.rz_minus_rmax := CC_Max(S.rz_minus_rmax, r.rz - r.rmax);
        if j = c then S.r2R_minus_d := CC_Max(S.r2R_minus_d, r.r2 - r.d); fi;
      fi;
      if j > 0 and r.p5 then S.bud_slack := CC_Min(S.bud_slack, N - r.bud); fi;
    od;
  end;
  t0 := Runtime();
  if IsBound(CODES) then
    for i in [1 .. Length(CODES)] do check(PcGroupCode(CODES[i][1], CODES[i][2]), i); od;
  else
    for i in [IDFROM .. Minimum(IDTO, NrSmallGroups(NN))] do
      G := SmallGroup(NN, i);
      if NilpotencyClassOfGroup(G) <> 3 then continue; fi;
      P := PCentralSeries(G, 2);
      if Length(P) - 1 < 4 or Size(P[Length(P) - 1]) <> 2 then continue; fi;
      if MS_MonoInvolution(G) = fail then continue; fi;
      check(G, i);
    od;
  fi;
  out := OutputTextFile(STATFILE, false); SetPrintFormattingStatus(out, false);
  WriteAll(out, "{");
  for nm in ["cands", "quotients", "fail", "r2_minus_d", "r23_minus_d", "rz_minus_rmax", "bud_slack", "r2R_minus_d"] do
    WriteAll(out, Concatenation("\"", nm, "\":", String(S.(nm)), ","));
  od;
  WriteAll(out, Concatenation("\"by_rank\":", ReplacedString(String(List([1..Length(S.by_rank)],
    i -> function() if IsBound(S.by_rank[i]) then return S.by_rank[i]; fi; return 0; end())), " ", ""),
    ",\"gap_ms\":", String(Runtime() - t0), "}\n"));
  CloseStream(out);
end;;
CC_Run();
QUIT;
