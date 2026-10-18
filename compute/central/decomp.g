## MATH-186: all splittings Q = H'∘E of the 386 candidates Q of orders 64..512, and which
## proved statement covers each.  Here E = <a,b>Z(Q) with a, b not commuting, a^2, b^2 in Z(Q)
## and conjugacy classes of size 2; then H' = C_Q(E) and Q = H'E, H' ∩ E = Z(Q) (wiki page of
## MATH-186, §2).  For each two-generated E0 = <a,b> inside E:
##   |Z(E0)| = 2 (D8, Q8): Theorem A needs t = [a,b] in gamma_2(H');
##   |Z(E0)| > 2 (M_{2^{k+2}}): Theorem B needs t in gamma_2(H'), then
##     "C"  Theorem C: some g in H' with c = g^-2 s, c^(2^k) in gamma_(k+2)(H') for all k;
##     "R"  else Lemma R: a maximal subgroup M of H' with s not in M and g in M with g^4 = s^2.
## Prints one line per candidate and a tally.
Read(Concatenation(ROOT, "/compute/central/common.g"));
Good := function(c, L) local k, x; x := c; k := 0;
  while x <> One(c) do if k + 2 > Length(L) or not x in L[k+2] then return false; fi; x := x^2; k := k + 1; od;
  return true; end;;
Bump := function(r, key) if not IsBound(r.(key)) then r.(key) := 0; fi; r.(key) := r.(key) + 1; end;;
tally := rec();
for o in [64, 128, 256, 512] do
  for pr in Candidates(o) do
    Q := PcGroupCode(pr[2], o);
    if MS_MonoInvolution(Q) = fail then Bump(tally, "not_candidate"); continue; fi;
    Z := Centre(Q);
    T := Filtered(List(RightTransversal(Q, Z), x -> x),
      x -> not x in Z and x^2 in Z and Size(ConjugacyClass(Q, x)) = 2);
    Es := []; info := [];
    for a in T do for b in T do
      if Comm(a, b) = One(Q) then continue; fi;
      E := ClosureGroup(Z, [a, b]);
      i := Position(Es, E);
      if i = fail then
        Add(Es, E); i := Length(Es);
        Hp := Centralizer(Q, E);
        Add(info, rec(Hp := Hp, L := LowerCentralSeriesOfGroup(Hp), Phi := FrattiniSubgroup(Hp),
          split := Size(Hp) * Size(E) / Size(Z) = Size(Q), cases := []));
      fi;
      I := info[i];
      t := Comm(a, b);
      E0 := Subgroup(Q, [a, b]); ZE0 := Centre(E0);
      if not (t in Z and Order(t) = 2 and IsCyclic(ZE0)) then Add(I.cases, "bad"); continue; fi;
      if Size(ZE0) = 2 then
        case := [IdGroup(E0), t in I.L[2], "A"];
      else
        s := MinimalGeneratingSet(ZE0)[1];
        if ForAny(AsList(I.Hp), g -> Good(g^-2 * s, I.L)) then cov := "C";
        elif ForAny(MaximalSubgroups(I.Hp), M -> not s in M and ForAny(AsList(M), g -> g^4 = s^2)) then cov := "R";
        else cov := "none"; fi;
        case := [IdGroup(E0), t in I.L[2], s in I.Phi, cov];
      fi;
      if not case in I.cases then Add(I.cases, case); fi;
    od; od;
    if Es = [] then Bump(tally, Concatenation("o", String(o), "_nosplit")); continue; fi;
    for I in info do
      Bump(tally, Concatenation("o", String(o), "_E_split_", String(I.split)));
      for case in I.cases do
        if case = "bad" then Bump(tally, "bad"); continue; fi;
        Bump(tally, Concatenation("case_", String(case[1]), "_tg2_", String(case[2]), "_",
          JoinStringsWithSeparator(List(case{[3..Length(case)]}, String), "_")));
      od;
      Bump(tally, Concatenation("E_covered_", String(ForAny(I.cases, c -> c <> "bad" and c[Length(c)] <> "none"
        and c[2]))));
    od;
    Bump(tally, Concatenation("o", String(o), "_splits"));
    Print(o, " ", pr[1], " ", Size(Z), " ", List(info, I -> [Size(I.Hp), I.split, I.cases]), "\n");
  od;
od;
for k in SortedList(RecNames(tally)) do Print(k, " ", tally.(k), "\n"); od;
Print("DONE\n");
QUIT;
