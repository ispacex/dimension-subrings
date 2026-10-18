## MATH-186: all splittings Q = H'∘E of the 386 candidates Q of orders 64..512, and which
## proved statement covers each (wiki page of MATH-186, §2-§4).  E = <a,b>Z(Q) with a, b not
## commuting, a^2, b^2 in Z(Q) and conjugacy classes of size 2; then H' = C_Q(E), Q = H'E and
## H' ∩ E = Z(Q).  For each two-generated E0 = <a,b> inside E:
##   |Z(E0)| = 2 (D8, Q8): "A", Theorem A, needs t = [a,b] in gamma_2(H');
##   |Z(E0)| > 2 (M_{2^{k+2}}): Theorem B needs t in gamma_2(H'), then
##     "C"  Theorem C: some g in H' with c = g^-2 s, c^(2^k) in gamma_(k+2)(H') for all k;
##     "R"  else Lemma R: a maximal subgroup M of H' with s not in M and g in M with g^4 = s^2;
##     "none" otherwise.
## A case is [IdGroup(E0), t in gamma_2(H'), (for M: s in Phi(H')), cover].  A candidate is
## covered when one of its E has a case with t in gamma_2(H') and cover <> "none".
## Each candidate line gives the order, the parent id, the line in pairs_pruned_<order>.txt and |Z(Q)|.
## Names are lower case: Z, E, EQ are bound in GAP.
Read(Concatenation(ROOT, "/compute/central/common.g"));
Good := function(c, L) local k, x; x := c; k := 0;
  while x <> One(c) do if k + 2 > Length(L) or not x in L[k+2] then return false; fi; x := x^2; k := k + 1; od;
  return true; end;;
Bump := function(r, key) if not IsBound(r.(key)) then r.(key) := 0; fi; r.(key) := r.(key) + 1; end;;

Analyse := function(q)
  local zq, tset, es, info, a, b, esub, i, hp, inf, t, e0, ze0, s, cov, case;
  zq := Centre(q);
  tset := Filtered(List(RightTransversal(q, zq), x -> x),
    x -> not x in zq and x^2 in zq and Size(ConjugacyClass(q, x)) = 2);
  es := []; info := [];
  for a in tset do for b in tset do
    if Comm(a, b) = One(q) then continue; fi;
    esub := ClosureGroup(zq, [a, b]);
    i := Position(es, esub);
    if i = fail then
      Add(es, esub); i := Length(es);
      hp := Centralizer(q, esub);
      Add(info, rec(hp := hp, lcs := LowerCentralSeriesOfGroup(hp), phi := FrattiniSubgroup(hp),
        split := Size(hp) * Size(esub) / Size(zq) = Size(q), cases := []));
    fi;
    inf := info[i];
    t := Comm(a, b);
    e0 := Subgroup(q, [a, b]); ze0 := Centre(e0);
    if not (t in zq and Order(t) = 2 and IsCyclic(ze0)) then case := "bad";
    elif Size(ze0) = 2 then case := [IdGroup(e0), t in inf.lcs[2], "A"];
    else
      s := MinimalGeneratingSet(ze0)[1];
      if ForAny(AsList(inf.hp), g -> Good(g^-2 * s, inf.lcs)) then cov := "C";
      elif ForAny(MaximalSubgroups(inf.hp), m -> not s in m and ForAny(AsList(m), g -> g^4 = s^2)) then cov := "R";
      else cov := "none"; fi;
      case := [IdGroup(e0), t in inf.lcs[2], s in inf.phi, cov];
    fi;
    if not case in inf.cases then Add(inf.cases, case); fi;
  od; od;
  for inf in info do
    inf.covered := ForAny(inf.cases, c -> c <> "bad" and c[2] and c[Length(c)] <> "none");
    inf.coveredAC := ForAny(inf.cases, c -> c <> "bad" and c[2] and c[Length(c)] in ["A", "C"]);
  od;
  return info;
end;;

Show := function(label, info)
  Print(label, " ", List(info, inf -> [Size(inf.hp), inf.split, inf.cases]), "\n"); end;;

## sanity: known groups, no candidate filter
Print("sanity\n");
Show("32#49 (D8∘D8: 20 E, cover A)", Analyse(SmallGroup(32, 49)));
Show("32#50 (D8∘Q8: E0 in {D8, Q8}, cover A)", Analyse(SmallGroup(32, 50)));
Show("16#13 (D8∘C4: H' = Z = C4, t not in gamma_2(H'), negative control)", Analyse(SmallGroup(16, 13)));
Print("D8 x M16 / <(z, a^4)> = D8 o_<c> M16: expect an M16 case with s not in Phi\n");
d8 := DihedralGroup(8);; m16 := SmallGroup(16, 6);; dd := DirectProduct(d8, m16);
x := Image(Embedding(dd, 1), MinimalGeneratingSet(Centre(d8))[1])
   * Image(Embedding(dd, 2), MinimalGeneratingSet(Centre(m16))[1])^2;
gl := Image(NaturalHomomorphismByNormalSubgroup(dd, Subgroup(dd, [x])));
Print("  order ", Size(gl), " id ", IdGroup(gl), " centre ", IdGroup(Centre(gl)), "\n");
Show("  D8 o_<c> M16", Analyse(gl));

tally := rec();
for o in [64, 128, 256, 512] do
  cands := Candidates(o);
  for line in [1 .. Length(cands)] do
    pr := cands[line];
    q := PcGroupCode(pr[2], o);
    if MS_MonoInvolution(q) = fail then Bump(tally, "not_candidate"); continue; fi;
    info := Analyse(q);
    if info = [] then Bump(tally, Concatenation("o", String(o), "_nosplit")); continue; fi;
    for inf in info do
      Bump(tally, Concatenation("E_split_", String(inf.split)));
      for case in inf.cases do
        if case = "bad" then Bump(tally, "bad"); continue; fi;
        Bump(tally, Concatenation("case_", String(case[1]), "_tg2_", String(case[2]), "_",
          JoinStringsWithSeparator(List(case{[3..Length(case)]}, String), "_")));
      od;
      Bump(tally, Concatenation("E_covered_", String(inf.covered)));
    od;
    Bump(tally, Concatenation("o", String(o), "_splits_covered_", String(ForAny(info, inf -> inf.covered)),
      "_byAC_", String(ForAny(info, inf -> inf.coveredAC)),
      "_properglue_", String(ForAny(info, inf -> ForAny(inf.cases, c -> Length(c) = 4 and not c[3])))));
    Show(Concatenation(String(o), " ", String(pr[1]), " line ", String(line), " |Z|=", String(Size(Centre(q)))), info);
  od;
od;
for k in SortedList(RecNames(tally)) do Print(k, " ", tally.(k), "\n"); od;
Print("DONE\n");
QUIT;
