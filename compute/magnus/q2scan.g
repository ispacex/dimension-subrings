# D5-27 (2): check of Proposition 3 (p = 3): if |gamma_3/gamma_4| = 3 and gamma_2/gamma_3
# needs at most 2 generators (r <= 2), then [gamma_2, gamma_2] <= gamma_5.
# Also counts the groups of class >= 4 by (class, rank d, log_3 of the lower central factors, r)
# and how many of them are non-metabelian.
# Usage (GAP, package sglppow for 3^8):  Read("q2scan.g"); Q2Scan(3^7, 1, NrSmallGroups(3^7));
# Output: VIOLATION lines (expected: none), a RANGE line, TYPE lines
#   "TYPE n c<class>_d<rank>_<type>_r<r> total=.. nonmet=..".
Q2Scan := function(n, lo, hi)
  local i, G, L, c, ty, r, d, nm, viol, tab, key, nmtab, prem, t0;
  viol := 0; prem := 0; tab := rec(); nmtab := rec(); t0 := Runtime();
  for i in [lo..hi] do
    G := SmallGroup(n, i);
    L := LowerCentralSeriesOfGroup(G);
    c := Length(L) - 1;
    if c >= 4 then
      ty := List([1..c], k -> LogInt(Index(L[k], L[k+1]), 3));
      r := LogInt(Index(L[2], ClosureGroup(L[3], List(GeneratorsOfGroup(L[2]), x -> x^3))), 3);
      nm := not IsTrivial(DerivedSubgroup(L[2]));
      if ty[3] = 1 and r <= 2 then
        prem := prem + 1;
        if not IsSubgroup(L[5], DerivedSubgroup(L[2])) then
          viol := viol + 1;
          Print("VIOLATION ", n, " ", i, " ", ty, "\n");
        fi;
      fi;
      d := RankPGroup(G);
      key := Concatenation("c", String(c), "_d", String(d), "_", JoinStringsWithSeparator(List(ty, String), ""), "_r", String(r));
      if not IsBound(tab.(key)) then tab.(key) := 0; nmtab.(key) := 0; fi;
      tab.(key) := tab.(key) + 1;
      if nm then nmtab.(key) := nmtab.(key) + 1; fi;
    fi;
  od;
  Print("RANGE ", n, " ", lo, "..", hi, " premise=", prem, " violations=", viol, " time=", Runtime()-t0, "\n");
  for key in RecNames(tab) do
    Print("TYPE ", n, " ", key, " total=", tab.(key), " nonmet=", nmtab.(key), "\n");
  od;
end;
