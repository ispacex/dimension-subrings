## D5-31: the condition of Theorem C (wiki 702) on the candidates with Z(H) = C_4.
## For each generator s of Z(H) and each g in H: is c = g^-2 s such that c^(2^k) in gamma_(k+2)(H)
## for all k?  Prints [s in gamma_2, number of good g, collected orders of c] per s.
## Job kimmy/tm/20261018-092230-m184-gsearch-11bce88: 95 of 95 pass; the 17 with s not in gamma_2
## all have a g with c = 1 (s = g^2).
Read(Concatenation(ROOT, "/compute/central/common.g"));
Good := function(c, L) local k, x; x := c; k := 0;
  while x <> One(c) do if k + 2 > Length(L) or not x in L[k+2] then return false; fi; x := x^2; k := k + 1; od;
  return true; end;;
tally := rec();
for o in [64, 128, 256, 512] do
  for pr in Candidates(o) do
    H := PcGroupCode(pr[2], o); nH := MS_MonoInvolution(H);
    if nH = fail then continue; fi;
    ZH := Centre(H); if Size(ZH) <> 4 then continue; fi;
    L := LowerCentralSeriesOfGroup(H);
    res := List(Filtered(AsList(ZH), x -> Order(x) = 4), function(s) local gs;
      gs := Filtered(AsList(H), g -> Good(g^-2 * s, L));
      return [s in L[2], Length(gs), Collected(List(gs, g -> Order(g^-2 * s)))]; end);
    key := Concatenation("o", String(o), "_sg2_", String(res[1][1]), "_ok_", String(ForAll(res, r -> r[2] > 0)));
    if not IsBound(tally.(key)) then tally.(key) := 0; fi;
    tally.(key) := tally.(key) + 1;
    Print(o, " ", pr[1], " ", res, "\n");
  od;
od;
for k in RecNames(tally) do Print(k, " ", tally.(k), "\n"); od;
Print("DONE\n");
QUIT;
