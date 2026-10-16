# Shared helpers for export.g and filter_metab3.g.
DS_LevelsOf := function(G, elts)
  local lcs, lev, i, k;
  lcs := LowerCentralSeriesOfGroup(G);   # lcs[1] = G, ..., lcs[cls+1] = 1
  lev := [];
  for i in [1..Length(elts)] do
    k := 1;
    while k < Length(lcs) and elts[i] in lcs[k+1] do k := k + 1; od;
    lev[i] := k;
  od;
  return lev;
end;;

DS_RightAct := function(elts, x)
  return List(elts, e -> PositionSorted(elts, e*x) - 1);
end;;

DS_Line := function(n, i, H, elts)
  local gens, pc;
  gens := MinimalGeneratingSet(H);
  pc := AsList(Pcgs(H));
  return Concatenation(
    "{\"order\":", String(n), ",\"id\":", String(i), ",\"p\":", String(PrimePGroup(H)),
    ",\"cls\":", String(NilpotencyClassOfGroup(H)),
    ",\"dl\":", String(DerivedLength(H)),
    ",\"one\":", String(Position(elts, One(H)) - 1),
    ",\"gens\":", String(List(gens, x -> DS_RightAct(elts, x))),
    ",\"pcgs\":", String(List(pc, x -> DS_RightAct(elts, x))),
    ",\"lev\":", String(DS_LevelsOf(H, elts)));
end;;
