# MATH-39: quotients of Rips's group (Tahara 1978, k=2, l=0) with D_4 != 1 (= gamma_4, class 3).
# D_4(Q) <= D_3(Q) = gamma_3(Q), so D_4(Q) is found by testing every element of gamma_3(Q)
# with the truncated Magnus algebra (../pq1024/latb/magnus_pres.py, Howell form mod 2^E).
# Random descent over sections: from X, try every maximal subgroup and X/<z> for every z of order 2
# in Z(X); move to a random one with D_4 != 1; stop at a local minimum (no such neighbour).
# Subgroups: D_4(H) <= D_4(X) cap H, so a subgroup step can only keep elements of D_4(X); a quotient
# step can also create new ones. Neighbours with D_4 = 1 are not entered (heuristic, not exhaustive).
Read("tah.g");
Read("../pq1024/latb/export_pres.g");
if not IsBound(NWALK) then NWALK := 5; fi;
if not IsBound(SEED) then SEED := 1; fi;
if not IsBound(WORK) then WORK := "."; fi;
if not IsBound(PY) then PY := "python3"; fi;
Reset(GlobalMersenneTwister, SEED);
Read("d4lib.g");
G := TahGroup(2,0);; P := Image(EpimorphismPGroup(G, 2, 60));;
dP := D4Orders([P])[1];
Print("start: ", Desc(P, dP), "\n");
best := infinity;; seen := [];;
for walk in [1..NWALK] do
  S := P; dS := dP; path := [];
  while true do
    zs := Filtered(AsList(Omega(Center(S), 2, 1)), z -> z <> One(S));
    Ns := Concatenation(List(MaximalSubgroups(S), H -> Image(IsomorphismPcGroup(H))),
                        List(zs, z -> Image(NaturalHomomorphismByNormalSubgroup(S, Subgroup(S, [z])))));
    ds := D4Orders(Ns);
    good := Filtered([1..Length(Ns)], i -> ds[i][1] > 1);
    Add(path, [Log(Size(S),2), Length(Ns), Length(good)]);
    if good = [] then break; fi;
    i := Random(good); S := Ns[i]; dS := ds[i];
  od;
  Print("walk ", walk, ": local min ", Desc(S, dS), "\n   path [log2|S|, #nbrs, #good]: ", path, "\n");
  Add(seen, Log(Size(S),2));
  if Size(S) < best then best := Size(S); bestS := S; fi;
od;
Print("local minima log2 orders: ", Collected(seen), "\n");
if IsBound(SAVE) then PrintTo(SAVE, "BestPcPres := ", GapInputPcGroup(bestS, "B"), ";\n"); fi;
