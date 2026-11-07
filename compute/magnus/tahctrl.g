# MATH-444: negative controls of the Tahara solver on the first NCTRL records of h2old.py: with a group of
# conditions dropped, <g(tau)> must become nontrivial (and the full system must give 1).
Read("tahara61.g");
WordOf := function(F, e) local g, w, i; g := GeneratorsOfGroup(F); w := One(F);
  for i in [1, 3 .. Length(e) - 1] do w := w * g[e[i]]^e[i+1]; od; return w; end;
for r in RECS{[1..Minimum(NCTRL, Length(RECS))]} do
  F := FreeGroup(r.k); G := F / List(r.rels, e -> WordOf(F, e));
  P := Image(EpimorphismPGroup(G, 3, r.pclass + 1));
  T := TaharaData(P, fail); V := TaharaVars(T);
  res := [];
  for drop in [[], ["A"], ["B"], ["C"], ["D"], ["E"], ["F"], ["C","E"], ["A","C","E"], ["B","C","E"],
               ["C","D","E"], ["C","E","F"], ["A","B","C","D","E","F"]] do
    lat := TaharaLattice(T, V, TaharaConds(T, V, rec(drop := drop)));
    D := Subgroup(P, List(lat, tau -> TaharaGen(T, V, tau).g));
    Add(res, [drop, Log(Size(D), 3), IsSubgroup(LowerCentralSeriesOfGroup(P)[4], D)]);
  od;
  Print(r.id, " ", res, "\n");
od;
QUIT;
