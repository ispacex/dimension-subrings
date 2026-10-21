## D5-31 §6: the centres of the candidates H (orders 64..512) — size, cyclicity,
## whether the involution is in gamma_3, and for an element s of order 4 in Z(H)
## whether s is in gamma_2(H) and in Phi(H).  Job kimmy/tm/20261018-075032-m183-zcent2-11bce88.
Read(Concatenation(ROOT, "/compute/central/common.g"));
tally := rec();
for o in [64, 128, 256, 512] do
  for pr in Candidates(o) do
    H := PcGroupCode(pr[2], o); nH := MS_MonoInvolution(H);
    if nH = fail then continue; fi;
    ZH := Centre(H); L := LowerCentralSeriesOfGroup(H);
    key := Concatenation("o", String(o), "_Z", String(Size(ZH)), "_cyc", String(IsCyclic(ZH)), "_ning3_", String(nH in L[3]));
    if Size(ZH) >= 4 then
      s := First(AsList(ZH), x -> Order(x) = 4);
      key := Concatenation(key, "_s_in_g2_", String(s in L[2]), "_s_in_Phi_", String(s in FrattiniSubgroup(H)));
    fi;
    if not IsBound(tally.(key)) then tally.(key) := 0; fi;
    tally.(key) := tally.(key) + 1;
  od;
od;
for k in RecNames(tally) do Print(k, " ", tally.(k), "\n"); od;
Print("DONE\n");
QUIT;
