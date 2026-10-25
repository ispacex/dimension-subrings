# Review of MATH-403 / PR #107 (not for merge).  For each parent id in PARENTS (SmallGroup(3^K, id)):
# the p-cover test of dn39s.g (with the multiplier at pcgs positions K+1..), a check that M is central
# in S, then ALL step-1 immediate descendants (PqDescendants(P : StepSize := 1)) and, for each:
#   - the sieve of dn3.g / dn39.g (class >= 5, Q'' != 1, Z cyclic, soc <= Q'' ∩ M_{c+1});
#   - with R = last nontrivial term of the lower exponent-3 central series of Q (= M/U), the three
#     flags R <= Q'', R <= M_6(Q), class(Q) >= 5, to check each implication of the parent test
#     (M ∩ S'' = 1 => no R <= Q''; M ∩ M_6(S) = 1 => no R <= M_6(Q); gamma_5(S) <= M and = 1 => class < 5).
# One CSV line per parent to OUT.csv; survivors' invariants (k, n, kz, lcs) to OUT.jsonl.
LoadPackage("anupq"); if K = 8 then LoadPackage("sglppow"); fi;
SetPrintFormattingStatus("*stdout*", false);
RV := function(pid, f, js)
  local P, d, c, S, M, N, L, W, J, A, B, C, inM, pass, cent, D, G, LG, cG, DD, Z, JG, MG, soc, z, kz,
        R, PC, nd, nsv, nR2, nR6, nC5, nall, viol;
  P := SmallGroup(3^K, pid);
  d := RankPGroup(P); c := NilpotencyClassOfGroup(P);
  S := PqPCover(P);
  M := Subgroup(S, Pcgs(S){[K + 1 .. Length(Pcgs(S))]});
  N := PCentralSeries(S, 3)[Length(PCentralSeries(P, 3))];
  if Size(S) / Size(M) <> Size(P) or not IsElementaryAbelian(M) or not IsSubgroup(M, N) then
    Error("RV: unexpected p-cover at ", pid); fi;
  cent := IsSubgroup(Centre(S), M);
  L := LowerCentralSeriesOfGroup(S);
  if Length(L) >= 5 then W := L[5]; else W := TrivialSubgroup(S); fi;
  J := JenningsSeries(S);
  if Length(J) >= 6 then B := Intersection(M, J[6]); else B := TrivialSubgroup(S); fi;
  A := Intersection(M, DerivedSubgroup(DerivedSubgroup(S)));
  C := Intersection(M, W); inM := IsSubgroup(M, W);
  pass := not IsTrivial(N) and not IsTrivial(A) and not IsTrivial(B) and (not inM or not IsTrivial(C));
  D := PqDescendants(P : StepSize := 1);
  nd := Length(D); nsv := 0; nR2 := 0; nR6 := 0; nC5 := 0; nall := 0; viol := 0;
  for G in D do
    if Size(G) <> 3 * Size(P) then Error("RV: descendant of wrong order at ", pid); fi;
    LG := LowerCentralSeriesOfGroup(G); cG := Length(LG) - 1;
    DD := DerivedSubgroup(DerivedSubgroup(G));
    JG := JenningsSeries(G);
    PC := PCentralSeries(G, 3); R := PC[Length(PC) - 1];
    if Size(R) <> 3 then Error("RV: last p-central term not of order 3 at ", pid); fi;
    if IsSubgroup(DD, R) then nR2 := nR2 + 1; fi;
    if Length(JG) >= 6 and IsSubgroup(JG[6], R) then nR6 := nR6 + 1; fi;
    if cG >= 5 then nC5 := nC5 + 1; fi;
    if IsSubgroup(DD, R) and Length(JG) >= 6 and IsSubgroup(JG[6], R) and cG >= 5 then nall := nall + 1; fi;
    # the sieve, as in dn39.g
    if cG < 5 or IsTrivial(DD) then continue; fi;
    Z := Centre(G);
    if not IsCyclic(Z) then continue; fi;
    soc := Omega(Z, 3, 1);
    if soc <> R then viol := viol + 1; fi;   # cyclic centre => soc = R
    if Length(JG) >= cG + 1 then MG := JG[cG + 1]; else MG := TrivialSubgroup(G); fi;
    if not IsSubgroup(Intersection(DD, MG), soc) then continue; fi;
    nsv := nsv + 1;
    z := First(GeneratorsOfGroup(soc), x -> x <> One(G));
    kz := Number(LG, H -> z in H);
    WriteAll(js, Concatenation("{\"id\":\"", String(pid), "\",\"K\":", String(K + 1), ",\"k\":", String(RankPGroup(G)),
      ",\"n\":", String(cG + 1), ",\"kz\":", String(kz),
      ",\"lcs\":", String(List([1..cG], i -> AbelianInvariants(LG[i] / LG[i+1]))), "}\n"));
  od;
  WriteAll(f, Concatenation(JoinStringsWithSeparator(List([pid, d, c, Log(Size(M), 3), Log(Size(N), 3),
    Log(Size(A), 3), Log(Size(B), 3), Log(Size(C), 3), inM, cent, pass, nd, nR2, nR6, nC5, nall, nsv, viol], String), ","), "\n"));
end;;
RVRun := function(parents)
  local f, js, pid, t;
  f := OutputTextFile(Concatenation(OUT, ".csv"), false); SetPrintFormattingStatus(f, false);
  js := OutputTextFile(Concatenation(OUT, ".jsonl"), false); SetPrintFormattingStatus(js, false);
  t := Runtime();
  for pid in parents do RV(pid, f, js); od;
  CloseStream(f); CloseStream(js);
  Print("RVDONE parents=", Length(parents), " sec=", Int((Runtime() - t) / 1000), "\n");
end;;
if not IsBound(PARENTS) then
  # all SmallGroup(3^K, .) of rank 2..5, class >= 4 in ids FROM..TO
  PARENTS := Filtered([FROM .. Minimum(TO, NrSmallGroups(3^K))], function(i) local G, d;
    G := SmallGroup(3^K, i); d := RankPGroup(G);
    return d >= 2 and d <= 5 and NilpotencyClassOfGroup(G) >= 4; end);
fi;
RVRun(PARENTS);
QUIT;
